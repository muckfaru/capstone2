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

# Tutorial completion data (loaded from Firestore)
var completed_tutorials: Dictionary = {}
var total_xp: int = 0
var unlocked_games: Array[String] = ["akashic_tcg"]  # TCG always unlocked

signal xp_updated(new_xp: int)
signal game_unlocked(game_name: String)


# -------------------------
# SAVE TUTORIAL RESULT
# -------------------------
func save_tutorial_result(tutorial_id: String, score: int, max_score: int) -> void:
	var percentage: float = (float(score) / float(max_score)) * 100.0
	var passed: bool = percentage >= 70.0
	var xp_earned: int = 0
	
	# Calculate XP based on performance
	if passed:
		if percentage >= 90.0:
			xp_earned = 200  # Excellent
		elif percentage >= 80.0:
			xp_earned = 150  # Good
		else:
			xp_earned = 100  # Pass
	
	print("📊 Tutorial Result: %s | Score: %d/%d (%.1f%%) | XP: +%d" % [tutorial_id, score, max_score, percentage, xp_earned])
	
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
	
	# Check for game unlocks
	_check_game_unlocks()
	
	# Save to Firestore
	_save_to_firestore(tutorial_id, score, max_score, percentage, passed, xp_earned)


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
func _save_to_firestore(tutorial_id: String, score: int, max_score: int, percentage: float, passed: bool, xp_earned: int) -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot save tutorial result: No auth state")
		return
	
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	# Build nested tutorial data
	var tutorial_data := {
		"mapValue": {
			"fields": {
				tutorial_id: {
					"mapValue": {
						"fields": {
							"score": {"integerValue": score},
							"max_score": {"integerValue": max_score},
							"percentage": {"doubleValue": percentage},
							"passed": {"booleanValue": passed},
							"xp_earned": {"integerValue": xp_earned},
							"timestamp": {"integerValue": int(Time.get_unix_time_from_system())}
						}
					}
				}
			}
		}
	}
	
	var body := {
		"fields": {
			"tutorials": tutorial_data,
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
		var text: String = body_response.get_string_from_utf8()
		
		if code == 200:
			print("✅ Tutorial result saved to Firestore")
		else:
			push_error("❌ Failed to save tutorial result (%s): %s" % [code, text])
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()


# -------------------------
# LOAD USER DATA FROM FIRESTORE
# -------------------------
func load_user_data() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ Cannot load user data: No auth state")
		return
	
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			print("⚠️ User data not found, using defaults")
			return
		
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("fields"):
			return
		
		var fields: Dictionary = json["fields"]
		
		# Load total XP
		if fields.has("total_xp") and fields["total_xp"].has("integerValue"):
			total_xp = int(fields["total_xp"]["integerValue"])
			print("📊 Loaded XP:", total_xp)
		
		# Load unlocked games
		if fields.has("unlocked_games") and fields["unlocked_games"].has("arrayValue"):
			var arr = fields["unlocked_games"]["arrayValue"].get("values", [])
			unlocked_games.clear()
			for val in arr:
				if val.has("stringValue"):
					unlocked_games.append(val["stringValue"])
			print("🎮 Unlocked games:", unlocked_games)
		
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
			print("📚 Loaded %d completed tutorials" % completed_tutorials.size())
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to load user data: %s" % err)
		http.queue_free()
