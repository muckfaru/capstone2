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
	"code_breaker": 500,     # Requires 500 XP (intermediate)
	"game_3": 1500           # Future game (advance)
}

# Rank system (like League of Legends)
const RANK_THRESHOLDS := [
	{"name": "Iron", "min_xp": 0, "max_xp": 199, "color": Color(0.5, 0.5, 0.5), "icon": "res://asset/icons/IRON.png"},
	{"name": "Bronze", "min_xp": 200, "max_xp": 399, "color": Color(0.8, 0.5, 0.2), "icon": "res://asset/icons/BRONZE.png"},
	{"name": "Silver", "min_xp": 400, "max_xp": 699, "color": Color(0.75, 0.75, 0.75), "icon": "res://asset/icons/SILVER.png"},
	{"name": "Gold", "min_xp": 700, "max_xp": 1099, "color": Color(1, 0.843, 0), "icon": "res://asset/icons/GOLD.png"},
	{"name": "Platinum", "min_xp": 1100, "max_xp": 1599, "color": Color(0.4, 0.8, 0.7), "icon": "res://asset/icons/PLATINUM.png"},
	{"name": "Diamond", "min_xp": 1600, "max_xp": 2299, "color": Color(0.5, 0.7, 1), "icon": "res://asset/icons/DIAMOND.png"},
	{"name": "Master", "min_xp": 2300, "max_xp": 3199, "color": Color(0.8, 0.3, 0.8), "icon": "res://asset/icons/MASTER.png"},
	{"name": "Grandmaster", "min_xp": 3200, "max_xp": 4499, "color": Color(1, 0.2, 0.2), "icon": "res://asset/icons/GRAND MASTER.png"},
	{"name": "Challenger", "min_xp": 4500, "max_xp": 999999, "color": Color(0, 1, 1), "icon": "res://asset/icons/CHALLENGER.png"}
]

# Tutorial completion data (loaded from Firestore)
var completed_tutorials: Dictionary = {}
var total_xp: int = 0
var unlocked_games: Array[String] = ["akashic_tcg"]  # TCG always unlocked
var data_has_loaded: bool = false  # Track if Firestore data has been loaded

signal xp_updated(new_xp: int)
signal game_unlocked(game_name: String)
signal rank_up(new_rank: Dictionary)
signal data_loaded()
signal save_completed()  # NEW: Emitted when Firestore save finishes


# -------------------------
# RESET DATA (Called on logout)
# -------------------------
func reset_data() -> void:
	print("[TutorialManager] 🔄 Resetting all data...")
	completed_tutorials.clear()
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
		var existing = completed_tutorials[tutorial_id]
		print("[TutorialManager] Previous: %.1f%% | New: %.1f%%" % [existing["percentage"], (float(score) / float(max_score)) * 100.0])
		save_completed.emit()
		return
	
	var percentage: float = (float(score) / float(max_score)) * 100.0
	var passed: bool = percentage >= 70.0
	var xp_earned: int = 0
	
	print("[TutorialManager] Percentage: %.1f%% | Passed: %s" % [percentage, "YES" if passed else "NO"])
	
	# Calculate XP based on performance (more generous)
	if percentage >= 90.0:
		xp_earned = 200  # Excellent (A)
	elif percentage >= 80.0:
		xp_earned = 150  # Good (B)
	elif percentage >= 70.0:
		xp_earned = 100  # Pass (C)
	elif percentage >= 50.0:
		xp_earned = 50   # Below passing, but attempted (D)
	else:
		xp_earned = 0    # Failed (F)
	
	print("📊 Tutorial Result: %s | Score: %d/%d (%.1f%%) | XP: +%d" % [tutorial_id, score, max_score, percentage, xp_earned])
	
	# Get old rank before XP increase
	var old_rank := get_rank(total_xp)
	
	# Update local cache
	completed_tutorials[tutorial_id] = {
		"score": score,
		"max_score": max_score,
		"percentage": percentage,
		"passed": passed,
		"xp_earned": xp_earned,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	total_xp += xp_earned
	xp_updated.emit(total_xp)
	
	# Get new rank and check for rank up
	var new_rank := get_rank(total_xp)
	if new_rank["name"] != old_rank["name"]:
		rank_up.emit(new_rank)
		print("🎉 RANK UP! %s → %s %s" % [old_rank["name"], new_rank["icon"], new_rank["name"]])
	
	# Check for game unlocks
	_check_game_unlocks()
	
	# Save to Firestore
	_save_to_firestore()


# -------------------------
# CHECK GAME UNLOCKS
# -------------------------
func _check_game_unlocks() -> void:
	for game_name in XP_THRESHOLDS.keys():
		if game_name in unlocked_games:
			continue  # Already unlocked
		
		if total_xp >= XP_THRESHOLDS[game_name]:
			unlocked_games.append(game_name)
			game_unlocked.emit(game_name)
			print("🎉 GAME UNLOCKED:", game_name.to_upper())


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
		save_completed.emit()
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
		
		# Emit save_completed signal regardless of success/failure
		save_completed.emit()
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()
		save_completed.emit()  # Emit even on immediate failure


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
