extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")
 

# UI References
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_xp: Label = $HostCard/HostXP
@onready var _host_time: Label = $HostCard/HostTime
@onready var _host_powerups: Label = $HostCard/HostPowerups
@onready var _host_winner_badge: Label = $HostCard/WinnerBadge
@onready var _host_wpm_label: Label = $HostCard/HostWPM
@onready var _host_accuracy_label: Label = $HostCard/HostAccuracy
@onready var _host_wrong_submissions_label: Label = $HostCard/HostWrongSubmissions
@onready var _host_avg_time_label: Label = $HostCard/HostAvgTime
@onready var _host_fastest_time_label: Label = $HostCard/HostFastestTime
@onready var _host_damage_stats_label: Label = $HostCard/HostDamageStats
@onready var _host_comeback_badge: Label = $HostCard/HostComebackBadge

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_xp: Label = $ClientCard/ClientXP
@onready var _client_time: Label = $ClientCard/ClientTime
@onready var _client_powerups: Label = $ClientCard/ClientPowerups
@onready var _client_winner_badge: Label = $ClientCard/WinnerBadge
@onready var _client_wpm_label: Label = $ClientCard/ClientWPM
@onready var _client_accuracy_label: Label = $ClientCard/ClientAccuracy
@onready var _client_wrong_submissions_label: Label = $ClientCard/ClientWrongSubmissions
@onready var _client_avg_time_label: Label = $ClientCard/ClientAvgTime
@onready var _client_fastest_time_label: Label = $ClientCard/ClientFastestTime
@onready var _client_damage_stats_label: Label = $ClientCard/ClientDamageStats
@onready var _client_comeback_badge: Label = $ClientCard/ClientComebackBadge

@onready var _host_card_node: NinePatchRect = $HostCard
@onready var _client_card_node: NinePatchRect = $ClientCard

@onready var _back_button: Button = $BackToLandingButton

# Game data
var _room_id: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _lobby_server_url: String = ""

# Game results
var _winner_id: String = ""
var _host_score: int = 0
var _client_score: int = 0
var _host_health: int = 0
var _client_health: int = 0
var _game_duration: float = 0.0
var _host_powerups_used: int = 0
var _client_powerups_used: int = 0
var _result_unknown: bool = false

# Colors
const COLOR_WINNER := Color(1, 0.84, 0, 1)  # Gold
const COLOR_LOSER := Color(1, 0.36, 0.43, 1)  # Pink-red
const COLOR_XP_WIN := Color(0, 1, 0.5, 1)  # Green
const COLOR_XP_LOSE := Color(0.8, 0.8, 0.8, 1)  # Grey

const XP_WINNER := 200
const XP_LOSER := 0

var _host_wpm: float = 0.0
var _client_wpm: float = 0.0
var _host_accuracy: float = 0.0
var _client_accuracy: float = 0.0
var _host_wrong_submissions: int = 0
var _client_wrong_submissions: int = 0
var _host_avg_snippet_time: float = 0.0
var _client_avg_snippet_time: float = 0.0
var _host_fastest_snippet: float = 0.0
var _client_fastest_snippet: float = 0.0
var _host_damage_dealt: int = 0
var _client_damage_dealt: int = 0
var _host_damage_taken: int = 0
var _client_damage_taken: int = 0
var _host_comeback: bool = false
var _client_comeback: bool = false

func _ready() -> void:
	print("[PostGame] Scene initialized")
	
	# Get init data from arena
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_postgame_init"):
		init = get_tree().get_meta("code_breaker_postgame_init")
		get_tree().set_meta("code_breaker_postgame_init", null)
	
	_room_id = str(init.get("room_id", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	
	_winner_id = str(init.get("winner_id", ""))
	_host_score = int(init.get("host_score", 0))
	_client_score = int(init.get("client_score", 0))
	_host_health = int(init.get("host_health", 0))
	_client_health = int(init.get("client_health", 0))
	_game_duration = float(init.get("game_duration", 0.0))
	_host_powerups_used = int(init.get("host_powerups_used", 0))
	_client_powerups_used = int(init.get("client_powerups_used", 0))
	_result_unknown = bool(init.get("result_unknown", false))
	
	print("[PostGame] 🎮 Init data:")
	print("  Winner: %s" % _winner_id)
	print("  Host Score: %d | Client Score: %d" % [_host_score, _client_score])
	print("  Host Health: %d | Client Health: %d" % [_host_health, _client_health])
	print("  Game Duration: %.2fs" % _game_duration)
	
	# Adopt relay_client if needed
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)
		print("[PostGame] ✅ Adopted relay client from root")
	
	# Load analytics data BEFORE setup UI
	_host_wpm = float(init.get("host_wpm", 0.0))
	_client_wpm = float(init.get("client_wpm", 0.0))
	_host_accuracy = float(init.get("host_accuracy", 0.0))
	_client_accuracy = float(init.get("client_accuracy", 0.0))
	_host_wrong_submissions = int(init.get("host_wrong_submissions", 0))
	_client_wrong_submissions = int(init.get("client_wrong_submissions", 0))
	_host_avg_snippet_time = float(init.get("host_avg_snippet_time", 0.0))
	_client_avg_snippet_time = float(init.get("client_avg_snippet_time", 0.0))
	_host_fastest_snippet = float(init.get("host_fastest_snippet", 0.0))
	_client_fastest_snippet = float(init.get("client_fastest_snippet", 0.0))
	_host_damage_dealt = int(init.get("host_damage_dealt", 0))
	_client_damage_dealt = int(init.get("client_damage_dealt", 0))
	_host_damage_taken = int(init.get("host_damage_taken", 0))
	_client_damage_taken = int(init.get("client_damage_taken", 0))
	_host_comeback = bool(init.get("host_comeback", false))
	_client_comeback = bool(init.get("client_comeback", false))
	
	print("[PostGame] 📊 Analytics loaded:")
	print("  Host WPM: %.1f | Client WPM: %.1f" % [_host_wpm, _client_wpm])
	print("  Host Accuracy: %.1f%% | Client Accuracy: %.1f%%" % [_host_accuracy, _client_accuracy])
	
	# Setup UI with results
	_setup_ui()
	# Persist match history (permissions-safe user doc field)
	_save_recent_match_best_effort()
	# Award XP to Firestore total_xp
	_award_total_xp_best_effort()
	
	# Connect button
	_back_button.pressed.connect(_on_back_to_landing_pressed)
	
	# Animate in
	_animate_in()

func _award_total_xp_best_effort() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	if _result_unknown:
		return
	if _host_data.is_empty() or _client_data.is_empty():
		return

	# Decide win/loss for this device. Prefer winner_id == Auth uid, but fall back to arena player_id.
	var local_won := false
	if _winner_id != "" and _winner_id == Auth.current_local_id:
		local_won = true
	elif _player_id != "" and _winner_id != "" and _winner_id == _player_id:
		local_won = true

	var delta_xp: int = XP_WINNER if local_won else XP_LOSER
	if delta_xp == 0:
		return

	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])

	# GET current total_xp
	var http_get := HTTPRequest.new()
	http_get.timeout = 10.0
	get_tree().root.add_child(http_get)
	var done := {"ok": false}

	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		done["ok"] = true
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[PostGame] ⚠️ total_xp GET failed: %d\n%s" % [code, err_text])
			return

		var doc = JSON.parse_string(body.get_string_from_utf8())
		var current_xp: int = 0
		if typeof(doc) == TYPE_DICTIONARY and doc.has("fields"):
			var fields: Dictionary = doc.get("fields", {})
			if fields.has("total_xp"):
				current_xp = int(_from_firestore_value(fields["total_xp"]))

		var new_xp: int = maxi(0, current_xp + delta_xp)
		var patch_url := "%s?updateMask.fieldPaths=total_xp" % user_doc_url
		var http_patch := HTTPRequest.new()
		http_patch.timeout = 10.0
		get_tree().root.add_child(http_patch)
		var payload := {
			"fields": {
				"total_xp": {"integerValue": str(new_xp)}
			}
		}
		http_patch.request_completed.connect(func(_r2, code2, _h2, body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[PostGame] ✅ total_xp updated: %d -> %d" % [current_xp, new_xp])
			else:
				var err_text2: String = body2.get_string_from_utf8() if body2.size() > 0 else ""
				print("[PostGame] ⚠️ total_xp PATCH failed: %d\n%s" % [code2, err_text2])
		)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	)

	var req_err: int = http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		http_get.queue_free()
		print("[PostGame] ⚠️ total_xp GET request() failed immediately: %d" % req_err)
		return

	var start_ms := Time.get_ticks_msec()
	while not done["ok"] and is_inside_tree() and Time.get_ticks_msec() - start_ms < 1500:
		await get_tree().process_frame


func _save_recent_match_best_effort() -> void:
	# Only save when we have enough info.
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	if _result_unknown:
		return
	if _host_data.is_empty() or _client_data.is_empty():
		return

	var my_uid := Auth.current_local_id
	var host_id: String = str(_host_data.get("player_id", ""))
	var client_id: String = str(_client_data.get("player_id", ""))

	# Determine if this device is host or client (best-effort).
	# Prefer _player_id when available.
	var i_am_host := false
	if _player_id != "":
		i_am_host = _player_id == host_id
	elif my_uid != "":
		i_am_host = my_uid == host_id

	var opponent_username := str(_client_data.get("username", "")) if i_am_host else str(_host_data.get("username", ""))
	if opponent_username == "":
		# Fallback using UI labels
		opponent_username = _client_username.text if i_am_host else _host_username.text

	var winner_id := _winner_id
	var result_text := "WIN" if winner_id == my_uid else "LOSE"
	# If winner_id matches host/client id but not my_uid, try _player_id.
	if _player_id != "" and winner_id == _player_id:
		result_text = "WIN"
	elif _player_id != "" and winner_id != "" and winner_id != _player_id:
		result_text = "LOSE"

	var my_score := _host_score if i_am_host else _client_score
	var opp_score := _client_score if i_am_host else _host_score
	var duration_s: int = int(_game_duration)
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)

	var entry := {
		"game_type": "code_breaker",
		"timestamp": now_ms,
		"result": result_text,
		"opponent": opponent_username,
		"my_score": my_score,
		"opp_score": opp_score,
		"duration_s": duration_s,
		"time_ended": _format_time(_game_duration),
		"room_id": _room_id,
		"host_id": host_id,
		"client_id": client_id,
		"winner_id": winner_id
	}

	_append_recent_match_to_user_doc(entry)


func _append_recent_match_to_user_doc(entry: Dictionary) -> void:
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	if uid == "" or token == "":
		return

	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])

	# 1) GET existing recent_matches
	var http_get := HTTPRequest.new()
	http_get.timeout = 10.0
	get_tree().root.add_child(http_get)
	var done := {"ok": false}

	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		done["ok"] = true
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[PostGame] ⚠️ recent_matches GET failed: %d\n%s" % [code, err_text])
			return

		var doc = JSON.parse_string(body.get_string_from_utf8())
		var recent: Array = []
		if typeof(doc) == TYPE_DICTIONARY and doc.has("fields"):
			var fields: Dictionary = doc.get("fields", {})
			if fields.has("recent_matches"):
				recent = _from_firestore_value(fields["recent_matches"])
				if typeof(recent) != TYPE_ARRAY:
					recent = []

		recent.append(entry)
		recent.sort_custom(func(a, b):
			return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0))
		)
		if recent.size() > 20:
			recent = recent.slice(0, 20)

		# 2) PATCH back
		var payload := {
			"fields": {
				"recent_matches": _to_firestore_value(recent)
			}
		}
		var patch_url := "%s?updateMask.fieldPaths=recent_matches" % user_doc_url
		var http_patch := HTTPRequest.new()
		http_patch.timeout = 10.0
		get_tree().root.add_child(http_patch)
		http_patch.request_completed.connect(func(_r2, code2, _h2, body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[PostGame] ✅ recent_matches updated in users/%s" % uid)
			else:
				var err_text2: String = body2.get_string_from_utf8() if body2.size() > 0 else ""
				print("[PostGame] ⚠️ recent_matches PATCH failed: %d\n%s" % [code2, err_text2])
		)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	)

	var req_err: int = http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		http_get.queue_free()
		print("[PostGame] ⚠️ recent_matches GET request() failed immediately: %d" % req_err)
		return

	# Best-effort wait (don't block scene)
	var start_ms := Time.get_ticks_msec()
	while not done["ok"] and is_inside_tree() and Time.get_ticks_msec() - start_ms < 1500:
		await get_tree().process_frame


func _to_firestore_value(value) -> Dictionary:
	if value == null:
		return {"nullValue": "NULL_VALUE"}
	if value is String:
		return {"stringValue": value}
	if value is int:
		return {"integerValue": str(value)}
	if value is float:
		return {"doubleValue": value}
	if value is bool:
		return {"booleanValue": value}
	if value is Array:
		var values: Array = []
		for item in value:
			values.append(_to_firestore_value(item))
		return {"arrayValue": {"values": values}}
	if value is Dictionary:
		var map_fields: Dictionary = {}
		for k in value.keys():
			map_fields[str(k)] = _to_firestore_value(value[k])
		return {"mapValue": {"fields": map_fields}}
	return {"stringValue": str(value)}


func _from_firestore_value(v) -> Variant:
	if typeof(v) != TYPE_DICTIONARY:
		return null
	if v.has("stringValue"):
		return str(v["stringValue"])
	if v.has("integerValue"):
		return int(str(v["integerValue"]))
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	if v.has("nullValue"):
		return null
	if v.has("arrayValue"):
		var out: Array = []
		var av = v.get("arrayValue", {})
		var values = av.get("values", [])
		if typeof(values) == TYPE_ARRAY:
			for item in values:
				out.append(_from_firestore_value(item))
		return out
	if v.has("mapValue"):
		var mv = v.get("mapValue", {})
		var f = mv.get("fields", {})
		var out_d: Dictionary = {}
		if typeof(f) == TYPE_DICTIONARY:
			for k in f.keys():
				out_d[str(k)] = _from_firestore_value(f[k])
		return out_d
	return null

func _setup_ui() -> void:
	"""Setup UI with game results"""
	var host_bg := str(_host_data.get("card_bg", ""))
	var client_bg := str(_client_data.get("card_bg", ""))
	# If we learned cosmetics via relay, use them as a fallback for either player.
	if Auth:
		if host_bg.strip_edges() == "":
			host_bg = Auth.get_remote_card_bg(str(_host_data.get("player_id", "")))
		if client_bg.strip_edges() == "":
			client_bg = Auth.get_remote_card_bg(str(_client_data.get("player_id", "")))
	if Auth and Auth.current_card_bg_path.strip_edges() != "":
		if host_bg.strip_edges() == "" and str(_host_data.get("player_id", "")) == Auth.current_local_id:
			host_bg = Auth.current_card_bg_path
		if client_bg.strip_edges() == "" and str(_client_data.get("player_id", "")) == Auth.current_local_id:
			client_bg = Auth.current_card_bg_path
	CardCosmetics.apply_card_background(_host_card_node, host_bg)
	CardCosmetics.apply_card_background(_client_card_node, client_bg)

	# Determine winners and losers based on winner_id
	var host_player_id: String = str(_host_data.get("player_id", ""))
	var client_player_id: String = str(_client_data.get("player_id", ""))

	# Default: hide badges until explicitly shown
	_host_winner_badge.visible = false
	_client_winner_badge.visible = false

	# If we don't know the winner (reconnect-after-finished path), show a neutral result.
	if _result_unknown or _winner_id == "" or (host_player_id != "" and client_player_id != "" and _winner_id != host_player_id and _winner_id != client_player_id):
		_host_username.text = str(_host_data.get("username", "Host"))
		_client_username.text = str(_client_data.get("username", "Client"))

		_host_status.text = "🏁 MATCH ENDED"
		_client_status.text = "🏁 MATCH ENDED"
		_host_status.add_theme_color_override("font_color", COLOR_WINNER)
		_client_status.add_theme_color_override("font_color", COLOR_WINNER)

		_host_xp.text = "XP: +0"
		_client_xp.text = "XP: +0"
		_host_xp.add_theme_color_override("font_color", COLOR_XP_LOSE)
		_client_xp.add_theme_color_override("font_color", COLOR_XP_LOSE)

		_host_time.text = "Time: %s" % _format_time(_game_duration)
		_client_time.text = "Time: %s" % _format_time(_game_duration)
		_host_powerups.text = "Power-ups: %d" % _host_powerups_used
		_client_powerups.text = "Power-ups: %d" % _client_powerups_used
		return
	
	print("[PostGame] DEBUG - Winner ID: %s" % _winner_id)
	print("[PostGame] DEBUG - Host Player ID: %s" % host_player_id)
	print("[PostGame] DEBUG - Client Player ID: %s" % client_player_id)
	
	var host_won: bool = _winner_id == host_player_id
	var client_won: bool = _winner_id == client_player_id
	
	print("[PostGame] DEBUG - Host Won: %s | Client Won: %s" % [host_won, client_won])
	
	# Host Card
	_host_username.text = str(_host_data.get("username", "Host"))
	_host_status.text = "❌ DEFEATED" if not host_won else "VICTORY"
	_host_status.add_theme_color_override("font_color", COLOR_WINNER if host_won else COLOR_LOSER)
	
	var host_xp = XP_WINNER if host_won else XP_LOSER
	_host_xp.text = "XP: +%d" % host_xp
	_host_xp.add_theme_color_override("font_color", COLOR_XP_WIN if host_won else COLOR_XP_LOSE)
	
	_host_time.text = "Time: %s" % _format_time(_game_duration)
	_host_powerups.text = "Power-ups: %d" % _host_powerups_used
	
	# Host Analytics
	if _host_wpm_label:
		_host_wpm_label.text = "WPM: %.1f" % _host_wpm
		_host_wpm_label.visible = true
	if _host_accuracy_label:
		_host_accuracy_label.text = "Accuracy: %.1f%%" % _host_accuracy
		_host_accuracy_label.visible = true
	if _host_wrong_submissions_label:
		_host_wrong_submissions_label.text = "Wrong: %d" % _host_wrong_submissions
		_host_wrong_submissions_label.visible = true
	if _host_avg_time_label:
		_host_avg_time_label.text = "Avg Time: %.2fs" % _host_avg_snippet_time
		_host_avg_time_label.visible = true
	if _host_fastest_time_label:
		_host_fastest_time_label.text = "Fastest: %.2fs" % _host_fastest_snippet
		_host_fastest_time_label.visible = true
	if _host_damage_stats_label:
		_host_damage_stats_label.text = "Dmg: %d/%d" % [_host_damage_dealt, _host_damage_taken]
		_host_damage_stats_label.visible = true
	if _host_comeback_badge and _host_comeback:
		_host_comeback_badge.text = "🔥 COMEBACK"
		_host_comeback_badge.visible = true
	
	if host_won:
		_host_winner_badge.visible = true
	
	# Client Card
	_client_username.text = str(_client_data.get("username", "Client"))
	_client_status.text = "❌ DEFEATED" if not client_won else "✅ VICTORY"
	_client_status.add_theme_color_override("font_color", COLOR_WINNER if client_won else COLOR_LOSER)
	
	var client_xp = XP_WINNER if client_won else XP_LOSER
	_client_xp.text = "XP: +%d" % client_xp
	_client_xp.add_theme_color_override("font_color", COLOR_XP_WIN if client_won else COLOR_XP_LOSE)
	
	_client_time.text = "Time: %s" % _format_time(_game_duration)
	_client_powerups.text = "Power-ups: %d" % _client_powerups_used
	
	# Client Analytics
	if _client_wpm_label:
		_client_wpm_label.text = "WPM: %.1f" % _client_wpm
		_client_wpm_label.visible = true
	if _client_accuracy_label:
		_client_accuracy_label.text = "Accuracy: %.1f%%" % _client_accuracy
		_client_accuracy_label.visible = true
	if _client_wrong_submissions_label:
		_client_wrong_submissions_label.text = "Wrong: %d" % _client_wrong_submissions
		_client_wrong_submissions_label.visible = true
	if _client_avg_time_label:
		_client_avg_time_label.text = "Avg Time: %.2fs" % _client_avg_snippet_time
		_client_avg_time_label.visible = true
	if _client_fastest_time_label:
		_client_fastest_time_label.text = "Fastest: %.2fs" % _client_fastest_snippet
		_client_fastest_time_label.visible = true
	if _client_damage_stats_label:
		_client_damage_stats_label.text = "Dmg: %d/%d" % [_client_damage_dealt, _client_damage_taken]
		_client_damage_stats_label.visible = true
	if _client_comeback_badge and _client_comeback:
		_client_comeback_badge.text = "🔥 COMEBACK"
		_client_comeback_badge.visible = true
	
	if client_won:
		_client_winner_badge.visible = true

func _animate_in() -> void:
	"""Animate cards and results in"""
	# Fade in both cards with a slight bounce
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Host card animation
	var host_card = $HostCard
	host_card.modulate.a = 0.0
	tween.tween_property(host_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(host_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))
	
	# Client card animation
	var client_card = $ClientCard
	client_card.modulate.a = 0.0
	tween.tween_property(client_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(client_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))
	
	# Button animation
	var button = _back_button
	button.modulate.a = 0.0
	await tween.finished
	
	tween = create_tween()
	tween.tween_property(button, "modulate:a", 1.0, 0.3)

func _format_time(seconds: float) -> String:
	"""Format seconds to M:SS format"""
	var mins = int(seconds / 60.0)
	var secs = int(seconds) % 60
	return "%dm %ds" % [mins, secs]

func _on_back_to_landing_pressed() -> void:
	"""Handle back to landing button press"""
	print("[PostGame] 🔙 Back to Landing pressed")
	# Postgame means the session is over; don't attempt to auto-resume.
	_SessionStore.clear_session()
	
	# Clean up relay connection
	if _relay_client:
		if _relay_client.message_received.is_connected(_on_relay_message):
			_relay_client.message_received.disconnect(_on_relay_message)
		_relay_client.queue_free()
	
	# Clear postgame data
	get_tree().root.set_meta("code_breaker_lobby_init", null)
	get_tree().root.set_meta("arena_init", null)
	
	# Load landing
	var landing_scene := load("res://scene/landing.tscn")
	if landing_scene:
		get_tree().change_scene_to_packed(landing_scene)
	else:
		push_error("[PostGame] Failed to load landing scene!")

func _on_relay_message(data: Dictionary) -> void:
	"""Handle any relay messages (for future use like friend notifications)"""
	var msg_type = data.get("type", "")
	print("[PostGame] 📨 Received relay message: %s" % msg_type)