extends Node

# ============================================
# TUTORIAL MANAGER (Autoload Singleton)
# Tracks tutorial completion, XP, and game unlocks
# ============================================

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

# XP thresholds for game unlocks
const XP_THRESHOLDS := {
	"akashic_tcg": 0,        # Always unlocked (beginner game)
	"code_breaker": 50,     # Requires 500 XP (intermediate)
	"game_3": 1500           # Future game (advance)
}

# Rank system (like League of Legends)
const RANK_THRESHOLDS := [
	{"name": "Iron", "min_xp": 0, "max_xp": 199, "color": Color(0.5, 0.5, 0.5), "icon": "res://asset/rankicon/IRON.png"},
	{"name": "Bronze", "min_xp": 200, "max_xp": 399, "color": Color(0.8, 0.5, 0.2), "icon": "res://asset/rankicon/BRONZE.png"},
	{"name": "Silver", "min_xp": 400, "max_xp": 699, "color": Color(0.75, 0.75, 0.75), "icon": "res://asset/rankicon/SILVER.png"},
	{"name": "Gold", "min_xp": 700, "max_xp": 1099, "color": Color(1, 0.843, 0), "icon": "res://asset/rankicon/GOLD.png"},
	{"name": "Platinum", "min_xp": 1100, "max_xp": 1599, "color": Color(0.4, 0.8, 0.7), "icon": "res://asset/rankicon/PLATINUM.png"},
	{"name": "Diamond", "min_xp": 1600, "max_xp": 2299, "color": Color(0.5, 0.7, 1), "icon": "res://asset/rankicon/DIAMOND.png"},
	{"name": "Master", "min_xp": 2300, "max_xp": 3199, "color": Color(0.8, 0.3, 0.8), "icon": "res://asset/rankicon/MASTER.png"},
	{"name": "Grandmaster", "min_xp": 3200, "max_xp": 4499, "color": Color(1, 0.2, 0.2), "icon": "res://asset/rankicon/GRAND MASTER.png"},
	{"name": "Challenger", "min_xp": 4500, "max_xp": 999999, "color": Color(0, 1, 1), "icon": "res://asset/rankicon/CHALLENGER.png"}
]

# Tutorial completion data (loaded from Firestore)
var completed_tutorials: Dictionary = {}
var completed_minigames: Dictionary = {}  # Track minigame first-time completions
var attempted_minigames: Dictionary = {}  # Track any minigame where XP was earned (even on loss)
var total_xp: int = 0
var unlocked_games: Array[String] = ["akashic_tcg"]  # TCG always unlocked
var data_has_loaded: bool = false  # Track if Firestore data has been loaded
var pending_rank_up: Dictionary = {}
signal xp_updated(new_xp: int)
signal game_unlocked(game_name: String)
signal rank_up(new_rank: Dictionary)
signal data_loaded()
signal save_completed()  # Emitted when Firestore save finishes


# -------------------------
# RESET DATA (Called on logout)
# -------------------------
func reset_data() -> void:
	print("[TutorialManager] 🔄 Resetting all data...")
	completed_tutorials.clear()
	completed_minigames.clear()
	attempted_minigames.clear()
	total_xp = 0
	unlocked_games = ["akashic_tcg"]  # Reset to default
	data_has_loaded = false  # Reset loaded flag
	print("[TutorialManager] ✅ Data reset complete")


# -------------------------
# GET RANK BASED ON XP
# -------------------------
func get_rank(xp: int = -1) -> Dictionary:
	var current_xp := xp if xp >= 0 else total_xp
	
	for rank in RANK_THRESHOLDS:
		if current_xp >= rank["min_xp"] and current_xp <= rank["max_xp"]:
			var progress: float = 0.0
			if rank["max_xp"] != 999999:
				var xp_in_rank: int = current_xp - int(rank["min_xp"])
				var xp_needed: int = int(rank["max_xp"]) - int(rank["min_xp"]) + 1
				progress = (float(xp_in_rank) / float(xp_needed)) * 100.0
			else:
				progress = 100.0  # Max rank
			
			return {
				"name": rank["name"],
				"icon": rank["icon"],
				"color": rank["color"],
				"min_xp": rank["min_xp"],
				"max_xp": rank["max_xp"],
				"current_xp": current_xp,
				"progress": progress,
				"xp_to_next": rank["max_xp"] - current_xp + 1 if rank["max_xp"] != 999999 else 0
			}
	
	# Fallback (should never happen)
	return RANK_THRESHOLDS[0]


# -------------------------
# SAVE TUTORIAL RESULT
# -------------------------
func save_tutorial_result(tutorial_id: String, score: int, max_score: int) -> void:
		print("[TutorialManager] ========== SAVE TUTORIAL RESULT ==========")
		print("[TutorialManager] Tutorial ID: %s" % tutorial_id)
		print("[TutorialManager] Score: %d / %d" % [score, max_score])
		
		# Check if already completed
		if completed_tutorials.has(tutorial_id):
			print("[TutorialManager] ⚠️ Tutorial already completed! No XP awarded.")
			save_completed.emit()
			return
		
		var percentage: float = (float(score) / float(max_score)) * 100.0
		var passed: bool = percentage >= 70.0
		var xp_earned: int = 0
		
		# Calculate XP based on performance
		if percentage >= 90.0:
			xp_earned = 200
		elif percentage >= 80.0:
			xp_earned = 150
		elif percentage >= 70.0:
			xp_earned = 100
		elif percentage >= 50.0:
			xp_earned = 50
		else:
			xp_earned = 0
		
		print("📊 Tutorial Result: %s | Score: %d/%d (%.1f%%) | XP: +%d" % [tutorial_id, score, max_score, percentage, xp_earned])
		
		# ✅ Get old rank BEFORE adding XP
		var old_rank := get_rank(total_xp)
		print("[TutorialManager] Old rank: %s (XP: %d)" % [old_rank["name"], total_xp])
		
		# Update local cache
		completed_tutorials[tutorial_id] = {
			"score": score,
			"max_score": max_score,
			"percentage": percentage,
			"passed": passed,
			"xp_earned": xp_earned,
			"timestamp": Time.get_unix_time_from_system()
		}
		
		# ✅ Add XP
		total_xp += xp_earned
		print("[TutorialManager] New XP: %d (+%d)" % [total_xp, xp_earned])

		# Award CyberCoins: tutorial completion + XP conversion
		if xp_earned > 0 and CyberCoinManager:
			CyberCoinManager.award_tutorial_coins(tutorial_id)
			CyberCoinManager.award_xp_conversion(xp_earned, tutorial_id)
		
		# ✅ Check for rank up
		var new_rank := get_rank(total_xp)
		print("[TutorialManager] New rank: %s" % new_rank["name"])
		
		if new_rank["name"] != old_rank["name"]:
			print("[TutorialManager] 🎉 RANK UP DETECTED! %s → %s" % [old_rank["name"], new_rank["name"]])
			
			# ✅ STORE the rank-up to show later
			pending_rank_up = {
				"old_rank": old_rank,
				"new_rank": new_rank,
				"timestamp": Time.get_unix_time_from_system()
			}
			print("[TutorialManager] ✅ Rank-up stored in pending_rank_up")
		
		# Emit XP update signal for UI
		xp_updated.emit(total_xp)
		
		# Check for game unlocks
		_check_game_unlocks()
		
		# Save to Firestore
		_save_to_firestore()


func check_pending_rank_up() -> Dictionary:
		"""Check if there's a pending rank-up notification to show"""
		if pending_rank_up.is_empty():
			print("[TutorialManager] No pending rank-up")
			return {}
		
		print("[TutorialManager] ✅ Found pending rank-up: %s → %s" % [
			pending_rank_up["old_rank"]["name"], 
			pending_rank_up["new_rank"]["name"]
		])
		
		# Return and clear
		var result = pending_rank_up.duplicate()
		pending_rank_up = {}  # Clear it
		return result

# -------------------------
# CHECK GAME UNLOCKS
# -------------------------
func _check_game_unlocks() -> void:
	for game_name in XP_THRESHOLDS.keys():
		if game_name in unlocked_games:
			continue  # Already unlocked
		
		if total_xp >= XP_THRESHOLDS[game_name]:
			unlocked_games.append(game_name)
			call_deferred("_emit_game_unlock", game_name)
			print("🎉 GAME UNLOCKED:", game_name.to_upper())

func _emit_game_unlock(game_name: String) -> void:
	game_unlocked.emit(game_name)


# -------------------------
# CHECK IF GAME IS UNLOCKED
# -------------------------
func is_game_unlocked(game_name: String) -> bool:
	return game_name in unlocked_games


# -------------------------
# SAVE TO FIRESTORE
# -------------------------
func _save_to_firestore() -> void:
	print("[TutorialManager] ========== SAVING TO FIRESTORE ==========")
	print("[TutorialManager] Auth UID: %s" % Auth.current_local_id)
	print("[TutorialManager] Auth Token: %s" % ("EXISTS" if Auth.current_id_token != "" else "MISSING"))
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot save tutorial result: No auth state")
		call_deferred("emit_signal", "save_completed")
		return
	
	# Build ALL tutorial fields to avoid overwriting existing ones
	var tutorial_fields := {}
	for tid in completed_tutorials.keys():
		var tut = completed_tutorials[tid]
		tutorial_fields[tid] = {
			"mapValue": {
				"fields": {
					"score": {"integerValue": tut["score"]},
					"max_score": {"integerValue": tut["max_score"]},
					"percentage": {"doubleValue": tut["percentage"]},
					"passed": {"booleanValue": tut["passed"]},
					"xp_earned": {"integerValue": tut["xp_earned"]},
					"timestamp": {"integerValue": int(tut["timestamp"])}
				}
			}
		}
	
	# Use updateMask to update top-level fields only
	var url: String = "%s/users/%s?updateMask.fieldPaths=total_xp&updateMask.fieldPaths=unlocked_games&updateMask.fieldPaths=tutorials" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	# Build complete document with ALL tutorials
	var body := {
		"fields": {
			"total_xp": {"integerValue": total_xp},
			"unlocked_games": {
				"arrayValue": {
					"values": unlocked_games.map(func(g): return {"stringValue": g})
				}
			},
			"tutorials": {
				"mapValue": {
					"fields": tutorial_fields
				}
			}
		}
	}
	
	print("[TutorialManager] 💾 Saving %d completed tutorials, Total XP: %d" % [completed_tutorials.size(), total_xp])
	
	# Debug: Print tutorial IDs being saved
	print("[TutorialManager] Tutorial IDs in save: %s" % completed_tutorials.keys())
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		var text: String = body_response.get_string_from_utf8()
		
		if code == 200:
			print("[TutorialManager] ✅ Tutorial result saved to Firestore | Total XP: %d | Tutorials: %d" % [total_xp, completed_tutorials.size()])
		else:
			push_error("[TutorialManager] ❌ Failed to save tutorial result (%s): %s" % [code, text])
		
		# ✅ Defer signal emission
		call_deferred("emit_signal", "save_completed")
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()
		call_deferred("emit_signal", "save_completed")


# -------------------------
# LOAD USER DATA FROM FIRESTORE
# -------------------------
func load_user_data() -> void:
	print("[TutorialManager] ========== LOAD USER DATA ==========")
	print("[TutorialManager] Current total_xp BEFORE load: %d" % total_xp)
	print("[TutorialManager] Auth UID: %s" % Auth.current_local_id)
	print("[TutorialManager] Auth Token: %s" % ("EXISTS" if Auth.current_id_token != "" else "MISSING"))
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot load user data: No auth state")
		data_loaded.emit()
		return
	
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		print("[TutorialManager] Firestore response code: %d" % code)
		
		if code != 200:
			print("⚠️ User data not found in Firestore, using defaults (XP=0)")
			# Reset to defaults if no data found
			total_xp = 0
			completed_tutorials.clear()
			unlocked_games = ["akashic_tcg"]
			data_has_loaded = true  # Mark as loaded even with defaults
			data_loaded.emit()
			return
		
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("fields"):
			push_error("❌ Failed to parse Firestore response")
			total_xp = 0
			data_has_loaded = true  # Mark as loaded even with error
			data_loaded.emit()
			return
		
		var fields: Dictionary = json["fields"]
		print("[TutorialManager] Firestore fields: ", fields.keys())
		
		# Load total XP
		if fields.has("total_xp") and fields["total_xp"].has("integerValue"):
			total_xp = int(fields["total_xp"]["integerValue"])
			print("[TutorialManager] ✅ Loaded XP: %d" % total_xp)
		else:
			print("[TutorialManager] ⚠️ No total_xp field found, defaulting to 0")
			total_xp = 0
		
		# Load unlocked games
		if fields.has("unlocked_games") and fields["unlocked_games"].has("arrayValue"):
			var arr = fields["unlocked_games"]["arrayValue"].get("values", [])
			unlocked_games.clear()
			for val in arr:
				if val.has("stringValue"):
					unlocked_games.append(val["stringValue"])
			print("[TutorialManager] 🎮 Unlocked games: %s" % unlocked_games)
		
		# Load tutorial data
		if fields.has("tutorials") and fields["tutorials"].has("mapValue"):
			var tutorials_map = fields["tutorials"]["mapValue"].get("fields", {})
			for tutorial_id in tutorials_map.keys():
				var tutorial_fields = tutorials_map[tutorial_id].get("mapValue", {}).get("fields", {})
				completed_tutorials[tutorial_id] = {
					"score": int(tutorial_fields.get("score", {}).get("integerValue", 0)),
					"max_score": int(tutorial_fields.get("max_score", {}).get("integerValue", 1)),
					"percentage": float(tutorial_fields.get("percentage", {}).get("doubleValue", 0.0)),
					"passed": bool(tutorial_fields.get("passed", {}).get("booleanValue", false)),
					"xp_earned": int(tutorial_fields.get("xp_earned", {}).get("integerValue", 0)),
					"timestamp": int(tutorial_fields.get("timestamp", {}).get("integerValue", 0))
				}
			print("[TutorialManager] 📚 Loaded %d completed tutorials" % completed_tutorials.size())
		
		# Load minigame data
		_load_minigame_data(fields)
		
		print("[TutorialManager] ========== LOAD COMPLETE ==========")
		print("[TutorialManager] Final total_xp: %d" % total_xp)
		
		# Mark data as loaded
		data_has_loaded = true
		
		# Emit signal that data is loaded
		data_loaded.emit()
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to load user data: %s" % err)
		http.queue_free()


# -------------------------
# AWARD MINIGAME XP (First-time completion only)
# -------------------------
func award_minigame_xp(minigame_id: String, xp_amount: int, score: int = 0) -> int:
	"""Award XP for minigame completion - only on first completion. Returns actual XP awarded."""
	print("[TutorialManager] ========== AWARD MINIGAME XP ==========")
	print("[TutorialManager] Minigame: %s | Score: %d | Potential XP: %d" % [minigame_id, score, xp_amount])
	
	# Check if already completed
	if completed_minigames.has(minigame_id):
		print("[TutorialManager] ⚠️ Minigame already completed! No XP awarded (replay).")
		print("[TutorialManager] Previous best score: %d | This score: %d" % [completed_minigames[minigame_id]["score"], score])
		
		# Update best score if better
		if score > completed_minigames[minigame_id]["score"]:
			completed_minigames[minigame_id]["score"] = score
			completed_minigames[minigame_id]["timestamp"] = Time.get_unix_time_from_system()
			print("[TutorialManager] 🎯 New best score! Saving to Firestore...")
			_save_minigame_data()
		
		return 0  # No XP awarded
	
	# First time completion - award XP
	print("[TutorialManager] ✅ First completion! Awarding %d XP..." % xp_amount)
	
	# Record completion
	completed_minigames[minigame_id] = {
		"score": score,
		"xp_earned": xp_amount,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Award XP using existing system
	add_xp(xp_amount, minigame_id)

	# Award CyberCoins: minigame completion + XP conversion
	if CyberCoinManager:
		CyberCoinManager.award_minigame_coins(minigame_id)
		CyberCoinManager.award_xp_conversion(xp_amount, minigame_id)

	# Also mark as attempted (redundant but consistent)
	if not attempted_minigames.has(minigame_id):
		attempted_minigames[minigame_id] = {"xp_earned": xp_amount, "timestamp": Time.get_unix_time_from_system()}

	# Save to Firestore
	_save_minigame_data()
	
	return xp_amount


# -------------------------
# MARK MINIGAME AS ATTEMPTED (even on loss, if XP was earned)
# -------------------------
func mark_minigame_attempted(minigame_id: String, xp_earned: int = 0) -> void:
	"""Mark a minigame as attempted (even if player lost). Enables prerequisite unlocking."""
	if attempted_minigames.has(minigame_id):
		# Update cumulative XP
		attempted_minigames[minigame_id]["xp_earned"] = int(attempted_minigames[minigame_id].get("xp_earned", 0)) + xp_earned
		attempted_minigames[minigame_id]["timestamp"] = Time.get_unix_time_from_system()
	else:
		attempted_minigames[minigame_id] = {"xp_earned": xp_earned, "timestamp": Time.get_unix_time_from_system()}
	print("[TutorialManager] 🎮 Minigame '%s' marked as attempted (XP earned: %d)" % [minigame_id, xp_earned])
	_save_minigame_data()


# -------------------------
# CHECK IF MINIGAME WAS ATTEMPTED (earned any XP)
# -------------------------
func is_minigame_attempted(minigame_id: String) -> bool:
	return attempted_minigames.has(minigame_id) or completed_minigames.has(minigame_id)


# -------------------------
# ADD XP (For rewards, bonuses, etc.)
# -------------------------
func add_xp(amount: int, reason: String = "Bonus") -> void:
	print("[TutorialManager] ========== ADD XP ==========")
	print("[TutorialManager] 🎯 CALL STACK:")
	var stack = get_stack()
	for i in range(min(5, stack.size())):  # Show last 5 calls
		print("    [%d] %s:%d in %s()" % [i, stack[i]["source"], stack[i]["line"], stack[i]["function"]])
	
	print("[TutorialManager] Amount: +%d | Reason: %s" % [amount, reason])
	print("[TutorialManager] XP BEFORE: %d" % total_xp)
	
	if amount <= 0:
		push_warning("[TutorialManager] ⚠️ Cannot add negative or zero XP")
		return
	
	# Get old rank before XP increase
	var old_rank := get_rank(total_xp)
	
	# Add XP
	total_xp += amount
	
	print("[TutorialManager] XP AFTER: %d (+%d)" % [total_xp, amount])
	
	# ✅ DEFER signal emission to prevent UI conflicts
	call_deferred("_emit_xp_update", total_xp)
	
	# Get new rank and check for rank up
	var new_rank := get_rank(total_xp)
	if new_rank["name"] != old_rank["name"]:
		print("🎉 RANK UP! %s → %s %s" % [old_rank["name"], new_rank["icon"], new_rank["name"]])
		
		# ✅ STORE the rank-up to show later on mode selection screen
		pending_rank_up = {
			"old_rank": old_rank,
			"new_rank": new_rank,
			"timestamp": Time.get_unix_time_from_system()
		}
		print("[TutorialManager] ✅ Rank-up stored in pending_rank_up (will show on mode selection)")
		
		call_deferred("_emit_rank_up", new_rank)
	
	# Check for game unlocks
	_check_game_unlocks()
	
	# Save to Firestore (update total_xp only, don't touch tutorials)
	_save_xp_only()


# -------------------------
# SAVE ONLY XP TO F


# -------------------------
# SAVE MINIGAME DATA TO FIRESTORE
# -------------------------
func _save_minigame_data() -> void:
	print("[TutorialManager] 💾 Saving minigame data to Firestore...")
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot save minigame data: No auth state")
		return
	
	# Build minigame fields
	var minigame_fields := {}
	for mid in completed_minigames.keys():
		var mg = completed_minigames[mid]
		minigame_fields[mid] = {
			"mapValue": {
				"fields": {
					"score": {"integerValue": mg["score"]},
					"xp_earned": {"integerValue": mg["xp_earned"]},
					"timestamp": {"integerValue": int(mg["timestamp"])}
				}
			}
		}

	# Build attempted minigame fields
	var attempted_fields := {}
	for mid in attempted_minigames.keys():
		var am = attempted_minigames[mid]
		attempted_fields[mid] = {
			"mapValue": {
				"fields": {
					"xp_earned": {"integerValue": am.get("xp_earned", 0)},
					"timestamp": {"integerValue": int(am.get("timestamp", 0))}
				}
			}
		}

	var url: String = "%s/users/%s?updateMask.fieldPaths=minigames&updateMask.fieldPaths=attempted_minigames" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	var body := {
		"fields": {
			"minigames": {
				"mapValue": {
					"fields": minigame_fields
				}
			},
			"attempted_minigames": {
				"mapValue": {
					"fields": attempted_fields
				}
			}
		}
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		if code == 200:
			print("[TutorialManager] ✅ Minigame data saved to Firestore")
		else:
			var text: String = body_response.get_string_from_utf8()
			push_error("[TutorialManager] ❌ Failed to save minigame data (%s): %s" % [code, text])
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start minigame save request: %s" % err)
		http.queue_free()


# -------------------------
# LOAD MINIGAME DATA FROM FIRESTORE
# -------------------------
func _load_minigame_data(fields: Dictionary) -> void:
	"""Load minigame completion data from Firestore fields"""
	if fields.has("minigames") and fields["minigames"].has("mapValue"):
		var minigames_map = fields["minigames"]["mapValue"].get("fields", {})
		for minigame_id in minigames_map.keys():
			var minigame_fields = minigames_map[minigame_id].get("mapValue", {}).get("fields", {})
			completed_minigames[minigame_id] = {
				"score": int(minigame_fields.get("score", {}).get("integerValue", 0)),
				"xp_earned": int(minigame_fields.get("xp_earned", {}).get("integerValue", 0)),
				"timestamp": int(minigame_fields.get("timestamp", {}).get("integerValue", 0))
			}
		print("[TutorialManager] 🎮 Loaded %d completed minigames" % completed_minigames.size())

	# Load attempted minigames
	if fields.has("attempted_minigames") and fields["attempted_minigames"].has("mapValue"):
		var attempted_map = fields["attempted_minigames"]["mapValue"].get("fields", {})
		for minigame_id in attempted_map.keys():
			var am_fields = attempted_map[minigame_id].get("mapValue", {}).get("fields", {})
			attempted_minigames[minigame_id] = {
				"xp_earned": int(am_fields.get("xp_earned", {}).get("integerValue", 0)),
				"timestamp": int(am_fields.get("timestamp", {}).get("integerValue", 0))
			}
		print("[TutorialManager] 🎮 Loaded %d attempted minigames" % attempted_minigames.size())


# -------------------------
# SAVE ONLY XP TO FIRESTORE (No tutorial data)
# -------------------------
func _save_xp_only() -> void:
	print("[TutorialManager] 💾 Saving XP update to Firestore...")
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot save XP: No auth state")
		return
	
	var url: String = "%s/users/%s?updateMask.fieldPaths=total_xp&updateMask.fieldPaths=unlocked_games" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	var body := {
		"fields": {
			"total_xp": {"integerValue": total_xp},
			"unlocked_games": {
				"arrayValue": {
					"values": unlocked_games.map(func(g): return {"stringValue": g})
				}
			}
		}
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		if code == 200:
			print("[TutorialManager] ✅ XP saved to Firestore | Total XP: %d" % total_xp)
		else:
			var text: String = body_response.get_string_from_utf8()
			push_error("[TutorialManager] ❌ Failed to save XP (%s): %s" % [code, text])
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start XP save request: %s" % err)
		http.queue_free()
