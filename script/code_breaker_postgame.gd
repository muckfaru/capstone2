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

var _victory_sound: AudioStreamPlayer
var _defeat_sound: AudioStreamPlayer
var _card_whoosh_sound: AudioStreamPlayer
var _stat_beep_sound: AudioStreamPlayer
var _badge_appear_sound: AudioStreamPlayer
var _comeback_sound: AudioStreamPlayer
var _button_hover_sound: AudioStreamPlayer
var _button_click_sound: AudioStreamPlayer
var _xp_count_sound: AudioStreamPlayer

# Add these shader references
var _glow_border_shader: Shader
var _scanline_shader: Shader
var _holographic_shader: Shader
var _energy_wave_shader: Shader
var _neon_glow_shader: Shader


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

	_load_shaders()
	_setup_audio_nodes()

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

	# Debug: Print panel info before applying shaders
	_debug_print_panel_info()

	# Wait multiple frames for UI to fully settle and render
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Apply shaders AFTER UI is fully ready
	_apply_shaders()

	# Persist match history (permissions-safe user doc field)
	_save_recent_match_best_effort()
	# Award XP to Firestore total_xp
	_award_total_xp_best_effort()
	
	# Connect button
	_back_button.pressed.connect(_on_back_to_landing_pressed)
	_back_button.mouse_entered.connect(_on_button_hover)
	
	# Animate in
	_animate_in()


func _load_shaders() -> void:
	"""Load all shader resources"""
	# Try multiple possible shader directory paths
	var possible_paths = [
		"res://shader/",
		"res://shaders/",
		"res://fx_shaders/",
		"res://game_shaders/"
	]
	
	var shader_path = ""
	for path in possible_paths:
		if DirAccess.dir_exists_absolute(path):
			shader_path = path
			print("[PostGame] 📁 Found shader directory at: " + shader_path)
			break
	
	if shader_path == "":
		print("[PostGame] ⚠️ No shader directory found! Tried: " + str(possible_paths))
		print("[PostGame] ℹ️ Shaders will not be applied, but the scene will still work")
		return
	
	# Check if shaders exist before loading
	# Use the simpler border glow shader (better for thin strips)
	if ResourceLoader.exists(shader_path + "border_glow_simple.gdshader"):
		_glow_border_shader = load(shader_path + "border_glow_simple.gdshader")
		print("[PostGame] ✅ Loaded border_glow_simple shader")
	elif ResourceLoader.exists(shader_path + "glow_border.gdshader"):
		_glow_border_shader = load(shader_path + "glow_border.gdshader")
		print("[PostGame] ✅ Loaded glow_border shader (fallback)")
	else:
		print("[PostGame] ⚠️ No glow border shader found at: " + shader_path)
	
	if ResourceLoader.exists(shader_path + "scanline.gdshader"):
		_scanline_shader = load(shader_path + "scanline.gdshader")
		print("[PostGame] ✅ Loaded scanline shader")
	else:
		print("[PostGame] ⚠️ scanline.gdshader not found at: " + shader_path)
	
	if ResourceLoader.exists(shader_path + "holographic_glitch.gdshader"):
		_holographic_shader = load(shader_path + "holographic_glitch.gdshader")
		print("[PostGame] ✅ Loaded holographic shader")
	else:
		print("[PostGame] ⚠️ holographic_glitch.gdshader not found at: " + shader_path)
	
	if ResourceLoader.exists(shader_path + "energy_wave.gdshader"):
		_energy_wave_shader = load(shader_path + "energy_wave.gdshader")
		print("[PostGame] ✅ Loaded energy_wave shader")
	else:
		print("[PostGame] ⚠️ energy_wave.gdshader not found at: " + shader_path)
	
	if ResourceLoader.exists(shader_path + "neon_glow.gdshader"):
		_neon_glow_shader = load(shader_path + "neon_glow.gdshader")
		print("[PostGame] ✅ Loaded neon_glow shader")
	else:
		print("[PostGame] ⚠️ neon_glow.gdshader not found at: " + shader_path)
	
	print("[PostGame] 📦 Shader loading complete")


func _setup_audio_nodes() -> void:
	"""Setup audio nodes programmatically if not in scene"""
	if not has_node("VictorySound"):
		_victory_sound = AudioStreamPlayer.new()
		_victory_sound.name = "VictorySound"
		_victory_sound.bus = "SFX"
		_victory_sound.volume_db = 0.0  # 100% volume
		add_child(_victory_sound)
	
	if not has_node("DefeatSound"):
		_defeat_sound = AudioStreamPlayer.new()
		_defeat_sound.name = "DefeatSound"
		_defeat_sound.bus = "SFX"
		_defeat_sound.volume_db = 0.0  # 100% volume
		add_child(_defeat_sound)
	
	if not has_node("CardWhooshSound"):
		_card_whoosh_sound = AudioStreamPlayer.new()
		_card_whoosh_sound.name = "CardWhooshSound"
		_card_whoosh_sound.bus = "SFX"
		_card_whoosh_sound.volume_db = -3.0  # ~70% volume
		add_child(_card_whoosh_sound)
	
	if not has_node("StatBeepSound"):
		_stat_beep_sound = AudioStreamPlayer.new()
		_stat_beep_sound.name = "StatBeepSound"
		_stat_beep_sound.bus = "SFX"
		_stat_beep_sound.volume_db = -6.0  # ~50% volume
		add_child(_stat_beep_sound)
	
	if not has_node("BadgeAppearSound"):
		_badge_appear_sound = AudioStreamPlayer.new()
		_badge_appear_sound.name = "BadgeAppearSound"
		_badge_appear_sound.bus = "SFX"
		_badge_appear_sound.volume_db = -2.0  # ~80% volume
		add_child(_badge_appear_sound)
	
	if not has_node("ComebackSound"):
		_comeback_sound = AudioStreamPlayer.new()
		_comeback_sound.name = "ComebackSound"
		_comeback_sound.bus = "SFX"
		_comeback_sound.volume_db = -1.0  # ~90% volume
		add_child(_comeback_sound)
	
	if not has_node("ButtonHoverSound"):
		_button_hover_sound = AudioStreamPlayer.new()
		_button_hover_sound.name = "ButtonHoverSound"
		_button_hover_sound.bus = "SFX"
		_button_hover_sound.volume_db = -8.0  # ~40% volume
		add_child(_button_hover_sound)
	
	if not has_node("ButtonClickSound"):
		_button_click_sound = AudioStreamPlayer.new()
		_button_click_sound.name = "ButtonClickSound"
		_button_click_sound.bus = "SFX"
		_button_click_sound.volume_db = -4.0  # ~60% volume
		add_child(_button_click_sound)
	
	if not has_node("XPCountSound"):
		_xp_count_sound = AudioStreamPlayer.new()
		_xp_count_sound.name = "XPCountSound"
		_xp_count_sound.bus = "SFX"
		_xp_count_sound.volume_db = -6.0  # ~50% volume
		add_child(_xp_count_sound)
	
	_load_audio_files()

func _load_audio_files() -> void:
	"""Load audio files into AudioStreamPlayers"""
	# Define audio file paths
	var audio_files = {
		"victory": "res://asset/audio/victory.mp3",
		"defeat": "res://asset/audio/defeat.mp3",
		"whoosh": "res://asset/audio/whoosh.mp3",
		"beep": "res://asset/audio/beep.mp3",
		"badge_appear": "res://asset/audio/badge_appear.mp3",
		"fire_ignite": "res://asset/audio/fire_ignite.mp3",
		"ui_hover": "res://asset/audio/ui_hover.mp3",
		"ui_click": "res://asset/audio/ui_click.mp3",
		"xp_count": "res://asset/audio/xp_count.mp3"
	}
	
	# Try to load each file, skip if not found
	if ResourceLoader.exists(audio_files["victory"]):
		_victory_sound.stream = load(audio_files["victory"])
	
	if ResourceLoader.exists(audio_files["defeat"]):
		_defeat_sound.stream = load(audio_files["defeat"])
	
	if ResourceLoader.exists(audio_files["whoosh"]):
		_card_whoosh_sound.stream = load(audio_files["whoosh"])
	
	if ResourceLoader.exists(audio_files["beep"]):
		_stat_beep_sound.stream = load(audio_files["beep"])
	
	if ResourceLoader.exists(audio_files["badge_appear"]):
		_badge_appear_sound.stream = load(audio_files["badge_appear"])
	
	if ResourceLoader.exists(audio_files["fire_ignite"]):
		_comeback_sound.stream = load(audio_files["fire_ignite"])
	
	if ResourceLoader.exists(audio_files["ui_hover"]):
		_button_hover_sound.stream = load(audio_files["ui_hover"])
	
	if ResourceLoader.exists(audio_files["ui_click"]):
		_button_click_sound.stream = load(audio_files["ui_click"])
	
	if ResourceLoader.exists(audio_files["xp_count"]):
		_xp_count_sound.stream = load(audio_files["xp_count"])
	
	print("[PostGame] ✅ Audio files loaded (available files only)")

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
	
	# Update leaderboard stats (wins/losses)
	var is_win := result_text == "WIN"
	_update_cb_leaderboard_stats(is_win)


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
	# REMOVED: Custom background card logic (CardCosmetics.apply_card_background)
	# The cards will now use the default style from the scene file
	
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
	_host_status.text = "☠️ DEFEATED" if not host_won else "👑 VICTORY"
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
	_client_status.text = "☠️ DEFEATED" if not client_won else "👑 VICTORY"
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
	"""Cyberpunk-themed animation with enhanced effects"""
	# Play victory/defeat sound based on result
	_play_result_sound()
	
	# Get card references
	var host_card = $HostCard
	var client_card = $ClientCard
	
	# Store original positions
	var host_original_x = host_card.position.x
	var client_original_x = client_card.position.x
	
	# Setup initial states for both cards
	host_card.modulate.a = 0.0
	host_card.position.x = host_original_x - 400
	host_card.scale = Vector2(0.85, 0.85)
	
	client_card.modulate.a = 0.0
	client_card.position.x = client_original_x + 400
	client_card.scale = Vector2(0.85, 0.85)
	
	# Ensure both cards are visible
	host_card.visible = true
	client_card.visible = true
	
	# Host card animation
	var host_tween = create_tween()
	host_tween.set_parallel(true)
	host_tween.set_ease(Tween.EASE_OUT)
	host_tween.set_trans(Tween.TRANS_BACK)
	
	if _card_whoosh_sound.stream:
		_card_whoosh_sound.play()
	
	host_tween.tween_property(host_card, "modulate:a", 1.0, 0.6)
	host_tween.tween_property(host_card, "position:x", host_original_x, 0.7)
	host_tween.tween_property(host_card, "scale", Vector2(1.0, 1.0), 0.6)
	
	# Client card animation - slight delay
	await get_tree().create_timer(0.15).timeout
	
	var client_tween = create_tween()
	client_tween.set_parallel(true)
	client_tween.set_ease(Tween.EASE_OUT)
	client_tween.set_trans(Tween.TRANS_BACK)
	
	if _card_whoosh_sound.stream:
		_card_whoosh_sound.play()
	
	client_tween.tween_property(client_card, "modulate:a", 1.0, 0.6)
	client_tween.tween_property(client_card, "position:x", client_original_x, 0.7)
	client_tween.tween_property(client_card, "scale", Vector2(1.0, 1.0), 0.6)
	
	# Wait for both animations to complete
	await client_tween.finished
	
	# Animate stats with staggered reveal
	_animate_stats_reveal()
	
	# Winner badge animation - slight delay after first stats appear
	await get_tree().create_timer(0.3).timeout
	
	if _host_winner_badge.visible:
		if _badge_appear_sound.stream:
			_badge_appear_sound.play()
		_animate_winner_badge(_host_winner_badge)
	if _client_winner_badge.visible:
		if _badge_appear_sound.stream:
			_badge_appear_sound.play()
		_animate_winner_badge(_client_winner_badge)
	
	# Comeback badge animation - dramatic pause before fire
	if _host_comeback_badge and _host_comeback_badge.visible:
		await get_tree().create_timer(0.2).timeout
		if _comeback_sound.stream:
			_comeback_sound.play()
		_animate_comeback_badge(_host_comeback_badge)
	if _client_comeback_badge and _client_comeback_badge.visible:
		await get_tree().create_timer(0.2).timeout
		if _comeback_sound.stream:
			_comeback_sound.play()
		_animate_comeback_badge(_client_comeback_badge)
	
	# Button fade in with glow
	var button = _back_button
	button.modulate.a = 0.0
	button.scale = Vector2(0.8, 0.8)
	var button_tween = create_tween()
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.set_trans(Tween.TRANS_ELASTIC)
	button_tween.tween_property(button, "modulate:a", 1.0, 0.4)
	button_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.5)

func _animate_stats_reveal() -> void:
	"""Staggered animation for stat labels"""
	var stat_labels = [
		_host_wpm_label, _host_accuracy_label, _host_wrong_submissions_label,
		_host_avg_time_label, _host_fastest_time_label, _host_damage_stats_label,
		_client_wpm_label, _client_accuracy_label, _client_wrong_submissions_label,
		_client_avg_time_label, _client_fastest_time_label, _client_damage_stats_label
	]
	
	var delay = 0.0
	for label in stat_labels:
		if label and label.visible:
			label.modulate.a = 0.0
			label.scale = Vector2(0.8, 0.8)
			
			await get_tree().create_timer(delay).timeout
			
			# Play beep sound with slight pitch variation
			if _stat_beep_sound.stream:
				_stat_beep_sound.pitch_scale = randf_range(0.95, 1.05)
				_stat_beep_sound.play()
			
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_property(label, "modulate:a", 1.0, 0.2)
			tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
			
			delay += 0.04  # Faster stagger for snappier reveal

func _animate_winner_badge(badge: Label) -> void:
	"""Pulsing glow animation for winner badge"""
	# Initial pop-in
	badge.scale = Vector2(0.0, 0.0)
	badge.rotation_degrees = -15
	
	var pop_tween = create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_ELASTIC)
	pop_tween.tween_property(badge, "scale", Vector2(1.2, 1.2), 0.6)
	pop_tween.tween_property(badge, "rotation_degrees", 0.0, 0.6)
	await pop_tween.finished
	
	# Continuous pulse
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.8)
	pulse_tween.tween_property(badge, "scale", Vector2(1.2, 1.2), 0.8)
	
	# Subtle rotation wiggle
	var wiggle_tween = create_tween()
	wiggle_tween.set_loops()
	wiggle_tween.tween_property(badge, "rotation_degrees", 5, 0.4)
	wiggle_tween.tween_property(badge, "rotation_degrees", -5, 0.4)

func _animate_comeback_badge(badge: Label) -> void:
	"""Fiery intense animation for comeback badge"""
	badge.modulate = Color(1, 0.5, 0, 0)
	badge.scale = Vector2(0.5, 0.5)
	
	var appear_tween = create_tween()
	appear_tween.set_parallel(true)
	appear_tween.set_ease(Tween.EASE_OUT)
	appear_tween.set_trans(Tween.TRANS_EXPO)
	appear_tween.tween_property(badge, "modulate:a", 1.0, 0.4)
	appear_tween.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.5)
	
	await appear_tween.finished
	
	# Continuous intense pulse
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(badge, "scale", Vector2(1.1, 1.1), 0.3)
	pulse_tween.tween_property(badge, "scale", Vector2(0.95, 0.95), 0.3)

func _format_time(seconds: float) -> String:
	"""Format seconds to M:SS format"""
	var mins = int(seconds / 60.0)
	var secs = int(seconds) % 60
	return "%dm %ds" % [mins, secs]

func _on_back_to_landing_pressed() -> void:
	"""Handle back to landing button press"""
	print("[PostGame] 🔙 Back to Landing pressed")
	
	# Play click sound
	if _button_click_sound.stream:
		_button_click_sound.play()
		await get_tree().create_timer(0.1).timeout  # Wait for sound
	
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

func _apply_shaders() -> void:
	"""Apply shaders to UI elements based on game state"""
	var host_player_id: String = str(_host_data.get("player_id", ""))
	var client_player_id: String = str(_client_data.get("player_id", ""))
	var host_won: bool = _winner_id == host_player_id
	var client_won: bool = _winner_id == client_player_id
	
	print("[PostGame] 🎨 Starting shader application...")
	print("[PostGame] Host won: %s | Client won: %s" % [host_won, client_won])
	
	# CRITICAL: Make the white areas transparent/dark first
	_fix_white_backgrounds()
	
	# Apply effects to Panel2 for host (the BORDER panel)
	var host_border = _host_card_node.get_node_or_null("Panel2")
	if host_border:
		host_border.visible = true
		
		if host_won and _glow_border_shader:
			# Create ColorRect overlay for shader (Panels don't render shaders properly)
			_create_shader_overlay(host_border, _glow_border_shader, {
				"glow_color": Color(0.0, 0.82, 1.0),  # Cyan/blue to match host theme
				"pulse_speed": 3.0,
				"glow_intensity": 3.0,
				"rainbow_mode": false,
				"particle_speed": 2.5
			}, "WINNER")
			print("[PostGame] ✅ Applied WINNER glow border to host Panel2 (RAINBOW MODE)")
		elif _scanline_shader:
			_create_shader_overlay(host_border, _scanline_shader, {
				"scanline_count": 150.0,
				"scanline_intensity": 0.3,
				"scan_speed": 2.0
			}, "LOSER")
			print("[PostGame] ✅ Applied scanline to host Panel2")
	else:
		print("[PostGame] ⚠️ WARNING: Host Panel2 not found!")
	
	# Apply effects to inner panel (Panel33) for host
	var host_inner = _host_card_node.get_node_or_null("Panel33")
	if host_inner:
		host_inner.visible = true
		
		if host_won and _glow_border_shader:
			# Winner gets glow border on inner panel too
			_create_shader_overlay(host_inner, _glow_border_shader, {
				"glow_color": Color(0.0, 0.82, 1.0),  # Cyan/blue to match host theme
				"pulse_speed": 2.5,
				"glow_intensity": 2.0,
				"rainbow_mode": false,
				"particle_speed": 2.0
			}, "WINNER INNER")
			print("[PostGame] ✅ Applied WINNER glow border to host Panel33 (inner)")
		elif _scanline_shader:
			# Loser gets scanline
			_create_shader_overlay(host_inner, _scanline_shader, {
				"scanline_count": 150.0,
				"scanline_intensity": 0.3,
				"scan_speed": 2.0
			}, "LOSER INNER")
			print("[PostGame] ✅ Applied scanline to host Panel33 (inner)")
	
	# Apply effects to Panel22 for client (the BORDER panel)
	var client_border = _client_card_node.get_node_or_null("Panel22")
	if client_border:
		client_border.visible = true
		
		if client_won and _glow_border_shader:
			# Create ColorRect overlay for shader
			_create_shader_overlay(client_border, _glow_border_shader, {
				"glow_color": Color(1.0, 0.0, 0.3),  # Red/pink to match client theme
				"pulse_speed": 3.0,
				"glow_intensity": 3.0,
				"rainbow_mode": false,
				"particle_speed": 2.5
			}, "WINNER")
			print("[PostGame] ✅ Applied WINNER glow border to client Panel22 (RAINBOW MODE)")
		elif _scanline_shader:
			_create_shader_overlay(client_border, _scanline_shader, {
				"scanline_count": 150.0,
				"scanline_intensity": 0.3,
				"scan_speed": 2.0
			}, "LOSER")
			print("[PostGame] ✅ Applied scanline to client Panel22")
	else:
		print("[PostGame] ⚠️ WARNING: Client Panel22 not found!")
	
	# Apply effects to inner panel (Panel3) for client
	var client_inner = _client_card_node.get_node_or_null("Panel3")
	if client_inner:
		client_inner.visible = true
		
		if client_won and _glow_border_shader:
			# Winner gets glow border on inner panel too
			_create_shader_overlay(client_inner, _glow_border_shader, {
				"glow_color": Color(1.0, 0.0, 0.3),  # Red/pink to match client theme
				"pulse_speed": 2.5,
				"glow_intensity": 2.0,
				"rainbow_mode": false,
				"particle_speed": 2.0
			}, "WINNER INNER")
			print("[PostGame] ✅ Applied WINNER glow border to client Panel3 (inner)")
		elif _scanline_shader:
			# Loser gets scanline
			_create_shader_overlay(client_inner, _scanline_shader, {
				"scanline_count": 150.0,
				"scanline_intensity": 0.3,
				"scan_speed": 2.0
			}, "LOSER INNER")
			print("[PostGame] ✅ Applied scanline to client Panel3 (inner)")
	
	# Apply color-based effects to labels (instead of shaders)
	_apply_label_effects(host_won, client_won)
	
	print("[PostGame] ✅ All visual effects applied")
	print("[PostGame] 💡 TIP: Winner panels should have RAINBOW GLOW effect!")

func _apply_holographic_to_stats() -> void:
	"""Apply holographic glitch effect to stat labels"""
	var stat_labels = [
		_host_wpm_label, _host_accuracy_label, _host_damage_stats_label,
		_client_wpm_label, _client_accuracy_label, _client_damage_stats_label
	]
	
	for label in stat_labels:
		if label and label.visible:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = _holographic_shader
			shader_material.set_shader_parameter("glitch_intensity", 0.3)
			shader_material.set_shader_parameter("glitch_color", Color(0.0, 1.0, 1.0))
			shader_material.set_shader_parameter("glitch_speed", 8.0)
			label.material = shader_material

func _apply_energy_wave(node: Label, energy_color: Color) -> void:
	"""Apply energy wave shader to a label"""
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _energy_wave_shader
	shader_material.set_shader_parameter("energy_color", energy_color)
	shader_material.set_shader_parameter("wave_speed", 5.0)
	shader_material.set_shader_parameter("wave_width", 0.3)
	shader_material.set_shader_parameter("wave_intensity", 0.6)
	node.material = shader_material

func _apply_neon_glow(node: Label, neon_color: Color) -> void:
	"""Apply neon glow shader to a label"""
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _neon_glow_shader
	shader_material.set_shader_parameter("neon_color", neon_color)
	shader_material.set_shader_parameter("glow_size", 0.02)
	shader_material.set_shader_parameter("glow_strength", 2.0)
	shader_material.set_shader_parameter("pulse_speed", 4.0)
	node.material = shader_material

func _play_result_sound() -> void:
	"""Play appropriate sound based on match result"""
	var my_uid := Auth.current_local_id
	var host_player_id: String = str(_host_data.get("player_id", ""))
	var i_am_host := false
	if _player_id != "":
		i_am_host = _player_id == host_player_id
	elif my_uid != "":
		i_am_host = my_uid == host_player_id
	
	var i_won := false
	if i_am_host and _winner_id == host_player_id:
		i_won = true
	elif not i_am_host and _winner_id != host_player_id:
		i_won = true
	
	if i_won and _victory_sound.stream:
		_victory_sound.play()
	elif not i_won and _defeat_sound.stream:
		_defeat_sound.play()

func _on_button_hover() -> void:
	"""Play sound when button is hovered"""
	if _button_hover_sound.stream:
		_button_hover_sound.play()

func _add_label_glow_effect(label: Label, glow_color: Color) -> void:
	"""Add a ColorRect behind label for shader effects"""
	if not label or not _neon_glow_shader:
		return
	
	# Create ColorRect as sibling (same parent)
	var glow_rect = ColorRect.new()
	glow_rect.name = label.name + "_Glow"
	glow_rect.color = glow_color
	glow_rect.z_index = label.z_index - 1
	
	# Match label size and position
	glow_rect.position = label.position - Vector2(10, 10)
	glow_rect.size = label.size + Vector2(20, 20)
	
	# Apply shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _neon_glow_shader
	shader_material.set_shader_parameter("neon_color", glow_color)
	shader_material.set_shader_parameter("glow_size", 0.02)
	shader_material.set_shader_parameter("glow_strength", 2.0)
	shader_material.set_shader_parameter("pulse_speed", 4.0)
	glow_rect.material = shader_material
	
	label.get_parent().add_child(glow_rect)
	glow_rect.move_to_front()
	label.move_to_front()

func _animate_label_glow(label: Label, glow_color: Color) -> void:
	"""Animate label color for glow effect"""
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	
	var bright_color = glow_color
	var dim_color = glow_color * 0.7
	
	pulse_tween.tween_property(label, "modulate", bright_color, 0.8)
	pulse_tween.tween_property(label, "modulate", dim_color, 0.8)


func _apply_label_effects(host_won: bool, client_won: bool) -> void:
	"""Apply color pulsing effects to labels since shaders don't work on Labels"""
	
	# Animate winner badges with color pulsing
	if _host_winner_badge.visible:
		_animate_label_pulse(_host_winner_badge, Color(1.0, 0.84, 0.0), 0.8)
	if _client_winner_badge.visible:
		_animate_label_pulse(_client_winner_badge, Color(1.0, 0.84, 0.0), 0.8)
	
	# Animate comeback badges with orange fire glow
	if _host_comeback_badge and _host_comeback_badge.visible:
		_animate_label_pulse(_host_comeback_badge, Color(1.0, 0.5, 0.0), 0.6)
	if _client_comeback_badge and _client_comeback_badge.visible:
		_animate_label_pulse(_client_comeback_badge, Color(1.0, 0.5, 0.0), 0.6)
	
	# Animate status labels with subtle glow
	if host_won:
		_animate_label_pulse(_host_status, Color(1.2, 1.0, 0.3), 1.2)
	if client_won:
		_animate_label_pulse(_client_status, Color(1.2, 1.0, 0.3), 1.2)
	
	# Add subtle cyan glow to stat labels
	_animate_stat_labels_subtle()

func _animate_label_pulse(label: Label, glow_color: Color, duration: float) -> void:
	"""Animate label with pulsing glow effect"""
	if not label:
		return
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	
	var bright_color = glow_color
	var dim_color = glow_color * 0.6
	
	pulse_tween.tween_property(label, "modulate", bright_color, duration)
	pulse_tween.tween_property(label, "modulate", dim_color, duration)

func _animate_stat_labels_subtle() -> void:
	"""Add subtle pulsing to stat labels"""
	var stat_labels = [
		_host_wpm_label, _host_accuracy_label, _host_damage_stats_label,
		_client_wpm_label, _client_accuracy_label, _client_damage_stats_label
	]
	
	for label in stat_labels:
		if label and label.visible:
			var pulse_tween = create_tween()
			pulse_tween.set_loops()
			pulse_tween.set_ease(Tween.EASE_IN_OUT)
			pulse_tween.set_trans(Tween.TRANS_SINE)
			
			# Very subtle cyan shimmer
			var bright = Color(1.1, 1.1, 1.2)
			var dim = Color(0.95, 0.95, 1.0)
			
			pulse_tween.tween_property(label, "modulate", bright, 1.5)
			pulse_tween.tween_property(label, "modulate", dim, 1.5)

func _apply_glow_border(node: Node, glow_color: Color, enable_rainbow: bool = false) -> void:
	"""Apply glowing border shader to a node"""
	if not _glow_border_shader:
		print("[PostGame] ⚠️ Cannot apply glow border - shader not loaded")
		return
	
	if not node is Control and not node is Node2D:
		print("[PostGame] ⚠️ Cannot apply shader to node type: " + node.get_class())
		return
	
	# CRITICAL: Ensure the node can render shaders properly
	if node is Control:
		node.clip_contents = false  # Allow shader effects to show outside bounds
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _glow_border_shader
	
	# MAXIMUM VISIBILITY SETTINGS - You can't miss this!
	shader_material.set_shader_parameter("base_glow_color", glow_color)
	shader_material.set_shader_parameter("pulse_speed", 4.0)  # Faster pulse
	shader_material.set_shader_parameter("glow_width", 0.12)  # VERY WIDE glow
	shader_material.set_shader_parameter("glow_intensity", 5.0)  # MAXIMUM intensity
	shader_material.set_shader_parameter("rainbow_mode", enable_rainbow)
	shader_material.set_shader_parameter("particle_speed", 3.0)  # Faster particles
	shader_material.set_shader_parameter("particle_count", 30)  # MORE particles
	
	node.material = shader_material
	
	# Force node to render with shader
	if node is Control:
		node.queue_redraw()
		# Force size update to trigger shader
		node.size = node.size
		# Ensure node is in front
		node.z_as_relative = false
	
	var mode_text = " (RAINBOW MODE 🌈)" if enable_rainbow else ""
	print("[PostGame] 🌟 Glow border applied to %s with color %s%s" % [node.name, glow_color, mode_text])
	print("[PostGame]    ├─ ⚡ ULTRA SETTINGS: Width=0.12, Intensity=5.0, Particles=30")
	print("[PostGame]    ├─ 📍 Z-Index: %d, Visible: %s" % [node.z_index, node.visible])
	print("[PostGame]    └─ 📦 Material applied: %s" % ("YES" if node.material != null else "NO"))


func _apply_scanline(node: Node) -> void:
	"""Apply scanline shader to a node"""
	if not _scanline_shader:
		print("[PostGame] ⚠️ Cannot apply scanline - shader not loaded")
		return
	
	if not node is Control and not node is Node2D:
		print("[PostGame] ⚠️ Cannot apply shader to node type: " + node.get_class())
		return
	
	# CRITICAL: Ensure the node can render shaders properly
	if node is Control:
		node.clip_contents = false
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _scanline_shader
	shader_material.set_shader_parameter("scanline_count", 150.0)  # Reduced for clearer lines
	shader_material.set_shader_parameter("scanline_intensity", 0.4)  # Increased visibility
	shader_material.set_shader_parameter("scan_speed", 2.5)
	shader_material.set_shader_parameter("distortion_amount", 0.015)  # Fixed parameter name
	shader_material.set_shader_parameter("chromatic_aberration", 0.005)  # Increased for effect
	shader_material.set_shader_parameter("vignette_strength", 0.4)
	shader_material.set_shader_parameter("flicker_intensity", 0.08)  # Increased flicker
	node.material = shader_material
	
	# Force node to render with shader
	if node is Control:
		node.queue_redraw()
		# Force size update to trigger shader
		node.size = node.size
		# Ensure node is in front
		node.z_as_relative = false
	
	print("[PostGame] 📺 Scanline applied to %s (intensity: 0.4, count: 150)" % node.name)
	print("[PostGame]    ├─ 📍 Z-Index: %d, Visible: %s" % [node.z_index, node.visible])
	print("[PostGame]    └─ 📦 Material applied: %s" % ("YES" if node.material != null else "NO"))

func _create_label_shader_background(label: Label, shader: Shader, params: Dictionary) -> void:
	"""Create a ColorRect behind a label to apply shaders"""
	if not label or not shader:
		return
	
	# Create ColorRect
	var bg_rect = ColorRect.new()
	bg_rect.name = label.name + "_ShaderBG"
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.z_index = -1
	
	# Match label size and position
	bg_rect.position = label.position - Vector2(5, 5)
	bg_rect.size = label.size + Vector2(10, 10)
	bg_rect.color = Color(1, 1, 1, 0.3)
	
	# Apply shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	for param_name in params.keys():
		shader_material.set_shader_parameter(param_name, params[param_name])
	bg_rect.material = shader_material
	
	# Add to same parent
	label.get_parent().add_child(bg_rect)
	bg_rect.move_to_front()
	label.move_to_front()

# Then use it in _apply_shaders():
func _apply_label_shader_backgrounds() -> void:
	"""Add shader backgrounds to important labels"""
	if _host_winner_badge.visible and _neon_glow_shader:
		_create_label_shader_background(_host_winner_badge, _neon_glow_shader, {
			"neon_color": Color(1.0, 0.84, 0.0),
			"glow_size": 0.02,
			"glow_strength": 2.0,
			"pulse_speed": 4.0
		})
	
	if _client_winner_badge.visible and _neon_glow_shader:
		_create_label_shader_background(_client_winner_badge, _neon_glow_shader, {
			"neon_color": Color(1.0, 0.84, 0.0),
			"glow_size": 0.02,
			"glow_strength": 2.0,
			"pulse_speed": 4.0
		})
func _debug_print_panel_info() -> void:
	"""Debug function to print panel information"""
	print("[PostGame] 🔍 DEBUG: Checking panel nodes...")
	print("[PostGame] ═══════════════════════════════════════")
	
	# Check host card panels
	print("[PostGame] 📘 Host Card children:")
	for child in _host_card_node.get_children():
		var type_info = child.get_class()
		var visible_info = "✅ VISIBLE" if child.visible else "❌ HIDDEN"
		var shader_compatible = "🎨 SHADER OK" if (child is Panel or child is NinePatchRect or child is ColorRect) else "❌ NO SHADER"
		print("  ├─ %s" % child.name)
		print("  │  ├─ Type: %s" % type_info)
		print("  │  ├─ %s" % visible_info)
		print("  │  └─ %s" % shader_compatible)
	
	# Check client card panels
	print("[PostGame] 📕 Client Card children:")
	for child in _client_card_node.get_children():
		var type_info = child.get_class()
		var visible_info = "✅ VISIBLE" if child.visible else "❌ HIDDEN"
		var shader_compatible = "🎨 SHADER OK" if (child is Panel or child is NinePatchRect or child is ColorRect) else "❌ NO SHADER"
		print("  ├─ %s" % child.name)
		print("  │  ├─ Type: %s" % type_info)
		print("  │  ├─ %s" % visible_info)
		print("  │  └─ %s" % shader_compatible)
	
	# Check specific panels
	var host_panel33 = _host_card_node.get_node_or_null("Panel33")
	var client_panel3 = _client_card_node.get_node_or_null("Panel3")
	var host_panel2 = _host_card_node.get_node_or_null("Panel2")
	var client_panel22 = _client_card_node.get_node_or_null("Panel22")
	
	print("[PostGame] 🎯 Target panels status:")
	print("  ├─ Host Panel33: %s" % ("✅ FOUND" if host_panel33 else "❌ NOT FOUND"))
	print("  ├─ Host Panel2: %s" % ("✅ FOUND" if host_panel2 else "❌ NOT FOUND"))
	print("  ├─ Client Panel3: %s" % ("✅ FOUND" if client_panel3 else "❌ NOT FOUND"))
	print("  └─ Client Panel22: %s" % ("✅ FOUND" if client_panel22 else "❌ NOT FOUND"))
	print("[PostGame] ═══════════════════════════════════════")
	
func _create_shader_overlay(panel: Panel, shader: Shader, params: Dictionary, effect_name: String) -> void:
	"""Create border-only shader overlays (4 thin rectangles for each edge)"""
	if not panel or not shader:
		return
	
	# Clean up existing overlays
	for child in panel.get_children():
		if child.name.begins_with("ShaderOverlay"):
			child.queue_free()
	
	var border_width = 5  # Width of the border edge rectangles
	var panel_size = panel.size
	
	# Create 4 edge overlays (Top, Right, Bottom, Left)
	var edges = [
		{"name": "ShaderOverlayTop", "pos": Vector2(0, 0), "size": Vector2(panel_size.x, border_width)},
		{"name": "ShaderOverlayRight", "pos": Vector2(panel_size.x - border_width, 0), "size": Vector2(border_width, panel_size.y)},
		{"name": "ShaderOverlayBottom", "pos": Vector2(0, panel_size.y - border_width), "size": Vector2(panel_size.x, border_width)},
		{"name": "ShaderOverlayLeft", "pos": Vector2(0, 0), "size": Vector2(border_width, panel_size.y)}
	]
	
	for edge_data in edges:
		var overlay = ColorRect.new()
		overlay.name = edge_data["name"]
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 50  # Above panel content but not blocking everything
		
		overlay.position = edge_data["pos"]
		overlay.size = edge_data["size"]
		
		# Use a semi-transparent color for shader to work with
		overlay.color = Color(1.0, 1.0, 1.0, 0.8)  # White with good opacity for visibility
		
		# Create and apply shader material
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		
		# Apply all parameters
		for param_name in params.keys():
			shader_material.set_shader_parameter(param_name, params[param_name])
		
		overlay.material = shader_material
		
		# Add to panel
		panel.add_child(overlay)
		overlay.queue_redraw()
	
	print("[PostGame] 🎨 Created %s shader overlays (4 borders) on %s" % [effect_name, panel.name])

func _fix_white_backgrounds() -> void:
	"""Fix the large white areas in the card backgrounds"""
	print("[PostGame] 🎨 Fixing white background areas...")
	
	# Create dark overlay for host card
	var host_overlay = ColorRect.new()
	host_overlay.name = "DarkOverlay"
	host_overlay.color = Color(0.03, 0.03, 0.08, 0.95)  # Very dark blue-ish
	host_overlay.z_index = -100  # FAR behind everything to not interfere with shaders
	host_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire card area (the white section)
	host_overlay.position = Vector2(0, 50)  # Start below username
	host_overlay.size = Vector2(400, 350)  # Cover the white area
	
	_host_card_node.add_child(host_overlay)
	_host_card_node.move_child(host_overlay, 0)  # Move to very back
	
	print("[PostGame] ✅ Added dark overlay to host card (z-index: -100)")
	
	# Create dark overlay for client card  
	var client_overlay = ColorRect.new()
	client_overlay.name = "DarkOverlay"
	client_overlay.color = Color(0.08, 0.02, 0.03, 0.95)  # Very dark red-ish
	client_overlay.z_index = -100  # FAR behind everything
	client_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	client_overlay.position = Vector2(0, 50)
	client_overlay.size = Vector2(400, 350)
	
	_client_card_node.add_child(client_overlay)
	_client_card_node.move_child(client_overlay, 0)  # Move to very back
	
	print("[PostGame] ✅ Added dark overlay to client card (z-index: -100)")


func _update_cb_leaderboard_stats(is_win: bool) -> void:
	"""Update user's Code Breaker leaderboard stats (wins, losses, games played)"""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[PostGame] ⚠️ Cannot update leaderboard stats - not logged in")
		return
	
	print("[PostGame] 📊 Updating CB leaderboard stats: is_win=%s" % str(is_win))
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])
	
	# First GET current stats
	var http_get := HTTPRequest.new()
	get_tree().root.add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		
		if code != 200:
			print("[PostGame] ⚠️ Failed to GET user doc for CB leaderboard stats")
			return
		
		var doc = JSON.parse_string(body.get_string_from_utf8())
		if typeof(doc) != TYPE_DICTIONARY:
			return
		var fields = doc.get("fields", {})
		
		# Get existing stats
		var current_wins := 0
		var current_losses := 0
		var current_games := 0
		
		if fields.has("cb_wins"):
			current_wins = int(_from_firestore_value(fields["cb_wins"]))
		if fields.has("cb_losses"):
			current_losses = int(_from_firestore_value(fields["cb_losses"]))
		if fields.has("cb_games_played"):
			current_games = int(_from_firestore_value(fields["cb_games_played"]))
		
		# Calculate new values
		var new_wins := current_wins + (1 if is_win else 0)
		var new_losses := current_losses + (0 if is_win else 1)
		var new_games := current_games + 1
		
		print("[PostGame] 📊 CB Stats update: wins %d→%d, losses %d→%d, games %d→%d" % [
			current_wins, new_wins,
			current_losses, new_losses,
			current_games, new_games
		])
		
		# PATCH the updated stats
		var http_patch := HTTPRequest.new()
		get_tree().root.add_child(http_patch)
		
		var patch_url := "%s?updateMask.fieldPaths=cb_wins&updateMask.fieldPaths=cb_losses&updateMask.fieldPaths=cb_games_played" % user_doc_url
		var patch_payload := {
			"fields": {
				"cb_wins": {"integerValue": str(new_wins)},
				"cb_losses": {"integerValue": str(new_losses)},
				"cb_games_played": {"integerValue": str(new_games)}
			}
		}
		
		http_patch.request_completed.connect(func(_r2, code2, _h2, _body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[PostGame] ✅ CB Leaderboard stats updated!")
				# Also update RTDB leaderboard
				var lb_username: String = ""
				if fields.has("username"):
					lb_username = str(_from_firestore_value(fields["username"]))
				if lb_username == "":
					lb_username = "Player"
				_update_rtdb_leaderboard("code_breaker", uid, lb_username, {
					"wins": new_wins,
					"losses": new_losses,
					"games": new_games
				})
			else:
				print("[PostGame] ⚠️ Failed to update CB leaderboard stats: %d" % code2)
		)
		
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(patch_payload))
	)
	
	http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)


func _update_rtdb_leaderboard(game_type: String, uid: String, username: String, stats: Dictionary) -> void:
	"""Update leaderboard entry in RTDB"""
	var token := Auth.current_id_token
	if token == "":
		return
	
	# Calculate sort_key
	var sort_key: int = int(stats.get("wins", 0))
	
	var entry := {
		"username": username,
		"sort_key": sort_key,
		"wins": stats.get("wins", 0),
		"losses": stats.get("losses", 0),
		"games": stats.get("games", 0)
	}
	
	var url := "https://capstone-823dc-default-rtdb.firebaseio.com/leaderboards/%s/%s.json?auth=%s" % [
		game_type, uid, token
	]
	
	var http := HTTPRequest.new()
	get_tree().root.add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[PostGame] ✅ RTDB Leaderboard updated for %s" % username)
		else:
			print("[PostGame] ⚠️ RTDB Leaderboard update failed: HTTP %d" % code)
	)
	
	var hdr := PackedStringArray(["Content-Type: application/json"])
	http.request(url, hdr, HTTPClient.METHOD_PUT, JSON.stringify(entry))
