extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")
 

# UI References (match Code Breaker postgame design)
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_xp: Label = $HostCard/HostXP
@onready var _host_time: Label = $HostCard/HostTime
@onready var _host_cards_used: OptionButton = $HostCard/HostPowerups
@onready var _host_winner_badge: Label = $HostCard/WinnerBadge

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_xp: Label = $ClientCard/ClientXP
@onready var _client_time: Label = $ClientCard/ClientTime
@onready var _client_cards_used: OptionButton = $ClientCard/ClientPowerups
@onready var _client_winner_badge: Label = $ClientCard/WinnerBadge

@onready var _host_card_node: NinePatchRect = $HostCard
@onready var _client_card_node: NinePatchRect = $ClientCard

@onready var _room_time_label: Label = $RoomTimeLabel

@onready var _back_button: Button = $BackToLandingButton

var _room_id: String = ""
var _player_id: String = ""
var _winner_id: String = ""
var _reason: String = ""
var _lobby_server_url: String = ""
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}

var _ended_at_unix: int = 0
var _host_cards_used_ids: Array = []
var _client_cards_used_ids: Array = []

var _host_si: int = 0
var _client_si: int = 0
var _duration_s: int = 0

const XP_WIN := 200
const XP_LOSE := 0
const TOTAL_DECK_CARDS := 25

const _SFX_VICTORY: AudioStream = preload("res://asset/audio/akashic sfx/player victory.wav")
const _SFX_DEFEAT: AudioStream = preload("res://asset/audio/akashic sfx/player defeat.wav")

var _outcome_sfx_player: AudioStreamPlayer = null
var _outcome_sfx_played: bool = false

const COLOR_WINNER := Color(1, 0.84, 0, 1)
const COLOR_LOSER := Color(1, 0.36, 0.43, 1)
const COLOR_XP_WIN := Color(0, 1, 0.5, 1)
const COLOR_XP_LOSE := Color(0.8, 0.8, 0.8, 1)

func _ready() -> void:
	# Postgame means the session is over; don't attempt to auto-resume.
	_TGCSess.clear_session()

	var init: Dictionary = {}
	if get_tree().has_meta("tgc_postgame_init"):
		init = get_tree().get_meta("tgc_postgame_init")
		get_tree().set_meta("tgc_postgame_init", null)

	_room_id = str(init.get("room_id", ""))
	_player_id = str(init.get("player_id", ""))
	_winner_id = str(init.get("winner_id", ""))
	_reason = str(init.get("reason", ""))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_ended_at_unix = int(init.get("ended_at_unix", 0))
	_host_cards_used_ids = init.get("host_cards_used", [])
	_client_cards_used_ids = init.get("client_cards_used", [])
	_host_si = int(init.get("host_si", 0))
	_client_si = int(init.get("client_si", 0))
	_duration_s = int(init.get("duration_s", 0))

	_setup_ui()
	_play_outcome_sfx()
	_save_recent_match_best_effort()
	_award_total_xp_best_effort()
	_back_button.pressed.connect(_on_back_to_landing_pressed)
	_animate_in()


func _award_total_xp_best_effort() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	if _host_data.is_empty() or _client_data.is_empty():
		return
	if _winner_id.strip_edges() == "" or _player_id.strip_edges() == "":
		return

	# Determine local outcome. winner_id may be a Firebase uid OR arena player_id; handle both.
	var local_won := false
	if _winner_id == Auth.current_local_id:
		local_won = true
	elif _winner_id == _player_id:
		local_won = true

	# Award CyberCoins for PvP win
	if local_won and CyberCoinManager:
		CyberCoinManager.award_pvp_win("Akashic TCG")

	var delta_xp: int = XP_WIN if local_won else XP_LOSE
	if delta_xp == 0:
		return

	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])

	var http_get := HTTPRequest.new()
	http_get.timeout = 10.0
	get_tree().root.add_child(http_get)
	var done := {"ok": false}

	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		done["ok"] = true
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[TGC PostGame] ⚠️ total_xp GET failed: %d\n%s" % [code, err_text])
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
				print("[TGC PostGame] ✅ total_xp updated: %d -> %d" % [current_xp, new_xp])
			else:
				var err_text2: String = body2.get_string_from_utf8() if body2.size() > 0 else ""
				print("[TGC PostGame] ⚠️ total_xp PATCH failed: %d\n%s" % [code2, err_text2])
		)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	)

	var req_err: int = http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		http_get.queue_free()
		print("[TGC PostGame] ⚠️ total_xp GET request() failed immediately: %d" % req_err)
		return

	var start_ms := Time.get_ticks_msec()
	while not done["ok"] and is_inside_tree() and Time.get_ticks_msec() - start_ms < 1500:
		await get_tree().process_frame


func _save_recent_match_best_effort() -> void:
	# Persist into users/<uid>.recent_matches (match_history collection may be rules-blocked).
	if not Engine.has_singleton("Auth"):
		return
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	if _host_data.is_empty() or _client_data.is_empty():
		return

	var my_uid := Auth.current_local_id
	var host_id: String = str(_host_data.get("player_id", ""))
	var client_id: String = str(_client_data.get("player_id", ""))

	# Determine perspective (prefer local arena-assigned _player_id).
	var i_am_host := false
	if _player_id != "":
		i_am_host = _player_id == host_id
	elif my_uid != "":
		i_am_host = my_uid == host_id

	var opponent_username := str(_client_data.get("username", "")) if i_am_host else str(_host_data.get("username", ""))
	if opponent_username == "":
		opponent_username = _client_username.text if i_am_host else _host_username.text

	var winner_id := _winner_id
	var result_text := "WIN" if winner_id == my_uid else "LOSE"
	# If winner_id matches arena _player_id (not Firebase uid), still treat that as win for this device.
	if _player_id != "" and winner_id == _player_id:
		result_text = "WIN"
	elif _player_id != "" and winner_id != "" and winner_id != _player_id:
		result_text = "LOSE"

	var my_score := _host_si if i_am_host else _client_si
	var opp_score := _client_si if i_am_host else _host_si
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var ended_at_unix := _ended_at_unix
	if ended_at_unix <= 0:
		ended_at_unix = int(Time.get_unix_time_from_system())

	var entry := {
		"game_type": "akashic_tcg",
		"timestamp": now_ms,
		"result": result_text,
		"opponent": opponent_username,
		"my_score": int(my_score),
		"opp_score": int(opp_score),
		"duration_s": int(_duration_s),
		"time_ended": _format_time(int(_duration_s)),
		"room_id": _room_id,
		"host_id": host_id,
		"client_id": client_id,
		"winner_id": winner_id,
		"ended_at_unix": ended_at_unix,
	}

	_append_recent_match_to_user_doc(entry)
	
	# Update leaderboard stats (wins/losses)
	var is_win := result_text == "WIN"
	_update_akashic_leaderboard_stats(is_win)


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

	var http_get := HTTPRequest.new()
	http_get.timeout = 10.0
	get_tree().root.add_child(http_get)
	var done := {"ok": false}

	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		done["ok"] = true
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[TGC PostGame] ⚠️ recent_matches GET failed: %d\n%s" % [code, err_text])
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
				print("[TGC PostGame] ✅ recent_matches updated in users/%s" % uid)
			else:
				var err_text2: String = body2.get_string_from_utf8() if body2.size() > 0 else ""
				print("[TGC PostGame] ⚠️ recent_matches PATCH failed: %d\n%s" % [code2, err_text2])
		)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	)

	var req_err: int = http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		http_get.queue_free()
		print("[TGC PostGame] ⚠️ recent_matches GET request() failed immediately: %d" % req_err)
		return

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
		return str(v.get("stringValue", ""))
	if v.has("integerValue"):
		return int(str(v.get("integerValue", "0")))
	if v.has("doubleValue"):
		return float(v.get("doubleValue", 0.0))
	if v.has("booleanValue"):
		return bool(v.get("booleanValue", false))
	if v.has("nullValue"):
		return null
	if v.has("arrayValue"):
		var arr: Array = []
		var av_val: Variant = v.get("arrayValue", {})
		var av: Dictionary = av_val if typeof(av_val) == TYPE_DICTIONARY else {}
		if av.has("values"):
			var values_val: Variant = av.get("values", [])
			var values: Array = values_val if typeof(values_val) == TYPE_ARRAY else []
			for item in values:
				arr.append(_from_firestore_value(item))
		return arr
	if v.has("mapValue"):
		var mv_val: Variant = v.get("mapValue", {})
		var mv: Dictionary = mv_val if typeof(mv_val) == TYPE_DICTIONARY else {}
		var out: Dictionary = {}
		if mv.has("fields"):
			var fields_val: Variant = mv.get("fields", {})
			var fields: Dictionary = fields_val if typeof(fields_val) == TYPE_DICTIONARY else {}
			for k in fields.keys():
				out[str(k)] = _from_firestore_value(fields[k])
		return out
	return null


func _format_time(seconds: int) -> String:
	var s: int = maxi(0, seconds)
	var m: int = int(s / 60.0)
	var sec: int = s % 60
	return "%dm %ds" % [m, sec]


func _play_outcome_sfx() -> void:
	if _outcome_sfx_played:
		return
	_outcome_sfx_played = true
	if _winner_id.strip_edges() == "" or _player_id.strip_edges() == "":
		return
	if _outcome_sfx_player == null or not is_instance_valid(_outcome_sfx_player):
		_outcome_sfx_player = AudioStreamPlayer.new()
		add_child(_outcome_sfx_player)
	var local_won: bool = (_winner_id == _player_id)
	_outcome_sfx_player.stream = _SFX_VICTORY if local_won else _SFX_DEFEAT
	_outcome_sfx_player.play()


func _setup_ui() -> void:
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

	var host_pid: String = str(_host_data.get("player_id", ""))
	var client_pid: String = str(_client_data.get("player_id", ""))
	var host_won: bool = (_winner_id != "" and _winner_id == host_pid)
	var client_won: bool = (_winner_id != "" and _winner_id == client_pid)

	_host_winner_badge.visible = false
	_client_winner_badge.visible = false

	_host_username.text = str(_host_data.get("username", "Host"))
	_client_username.text = str(_client_data.get("username", "Client"))

	_host_status.text = ("✅ VICTORY" if host_won else "❌ DEFEATED")
	_client_status.text = ("✅ VICTORY" if client_won else "❌ DEFEATED")
	_host_status.add_theme_color_override("font_color", COLOR_WINNER if host_won else COLOR_LOSER)
	_client_status.add_theme_color_override("font_color", COLOR_WINNER if client_won else COLOR_LOSER)

	# EXP rules (per your spec): winner +200, loser -50
	var host_xp_delta: int = XP_WIN if host_won else XP_LOSE
	var client_xp_delta: int = XP_WIN if client_won else XP_LOSE
	_host_xp.text = "EXP: %s%d" % ["+" if host_xp_delta >= 0 else "", host_xp_delta]
	_client_xp.text = "EXP: %s%d" % ["+" if client_xp_delta >= 0 else "", client_xp_delta]
	_host_xp.add_theme_color_override("font_color", COLOR_XP_WIN if host_won else COLOR_XP_LOSE)
	_client_xp.add_theme_color_override("font_color", COLOR_XP_WIN if client_won else COLOR_XP_LOSE)

	# Room + finish time
	_update_room_time_label()

	# Total cards (deck size) + dropdown list (cards used)
	_host_time.text = "Total Cards: %d" % TOTAL_DECK_CARDS
	_client_time.text = "Total Cards: %d" % TOTAL_DECK_CARDS
	_populate_cards_used_dropdown(_host_cards_used, _host_cards_used_ids)
	_populate_cards_used_dropdown(_client_cards_used, _client_cards_used_ids)

	if host_won:
		_host_winner_badge.visible = true
	if client_won:
		_client_winner_badge.visible = true


func _update_room_time_label() -> void:
	if _room_time_label == null:
		return
	var room_txt := (_room_id if _room_id != "" else "-")
	var time_txt := "-"
	var ended := _ended_at_unix
	if ended <= 0:
		ended = int(Time.get_unix_time_from_system())
	var dt := Time.get_datetime_dict_from_unix_time(ended)
	if typeof(dt) == TYPE_DICTIONARY and dt.has("hour"):
		time_txt = "%02d:%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0)), int(dt.get("second", 0))]
	_room_time_label.text = "Room: %s   |   Time: %s" % [room_txt, time_txt]


func _card_display_name(card_id: String) -> String:
	var id := card_id.strip_edges()
	match id:
		"mfa":
			return "MFA"
		"ids":
			return "IDS"
		"encryption":
			return "Encryption Key"
		"firewall":
			return "Firewall Shield"
		"antivirus":
			return "Antivirus Core"
		"phishing":
			return "Phishing"
		"virus":
			return "Virus"
		"trojan":
			return "Trojan Horse"
		"dos":
			return "DOS"
		"ddos":
			return "DDOS"
		_:
			return id.to_upper()


func _populate_cards_used_dropdown(dropdown: OptionButton, cards_used_ids: Array) -> void:
	if dropdown == null:
		return
	dropdown.clear()
	var total: int = cards_used_ids.size()
	dropdown.add_item("Cards Used (%d)" % total)
	if total <= 0:
		return
	# Aggregate counts so the dropdown stays readable.
	var counts: Dictionary = {}
	for v in cards_used_ids:
		var cid := str(v)
		if cid.strip_edges() == "":
			continue
		counts[cid] = int(counts.get(cid, 0)) + 1
	# Stable-ish order: display in the order they first appeared.
	var seen: Dictionary = {}
	for v in cards_used_ids:
		var cid := str(v)
		if cid.strip_edges() == "" or seen.has(cid):
			continue
		seen[cid] = true
		var n: int = int(counts.get(cid, 0))
		dropdown.add_item("%s x%d" % [_card_display_name(cid), n])


func _animate_in() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	var host_card := $HostCard
	host_card.modulate.a = 0.0
	tween.tween_property(host_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(host_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))

	var client_card := $ClientCard
	client_card.modulate.a = 0.0
	tween.tween_property(client_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(client_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))

	_back_button.modulate.a = 0.0
	await tween.finished

	tween = create_tween()
	tween.tween_property(_back_button, "modulate:a", 1.0, 0.3)


func _on_back_to_landing_pressed() -> void:
	await _leave_room_best_effort()
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)


func _leave_room_best_effort() -> void:
	# If we are already leaving the scene tree (or during shutdown), get_tree() can be null.
	if not is_inside_tree():
		return

	if _lobby_server_url == "" or _room_id == "" or _player_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	var done := {"ok": false}
	http.request_completed.connect(func(_r, _code, _h, _b):
		done["ok"] = true
		http.queue_free()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"player_id": _player_id}))
	var start_ms: int = Time.get_ticks_msec()
	while not done["ok"]:
		# Bail out quickly if the scene is being torn down.
		if not is_inside_tree():
			break
		# Best-effort only: don't block scene transitions forever.
		if Time.get_ticks_msec() - start_ms > 1500:
			break
		await get_tree().process_frame


func _update_akashic_leaderboard_stats(is_win: bool) -> void:
	"""Update user's Akashic TCG leaderboard stats (wins, losses, games played)"""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[TGC PostGame] ⚠️ Cannot update leaderboard stats - not logged in")
		return
	
	print("[TGC PostGame] 📊 Updating Akashic leaderboard stats: is_win=%s" % str(is_win))
	
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
			print("[TGC PostGame] ⚠️ Failed to GET user doc for Akashic leaderboard stats")
			return
		
		var doc = JSON.parse_string(body.get_string_from_utf8())
		if typeof(doc) != TYPE_DICTIONARY:
			return
		var fields = doc.get("fields", {})
		
		# Get existing stats
		var current_wins := 0
		var current_losses := 0
		var current_games := 0
		
		if fields.has("akashic_wins"):
			current_wins = int(_from_firestore_value(fields["akashic_wins"]))
		if fields.has("akashic_losses"):
			current_losses = int(_from_firestore_value(fields["akashic_losses"]))
		if fields.has("akashic_games_played"):
			current_games = int(_from_firestore_value(fields["akashic_games_played"]))
		
		# Calculate new values
		var new_wins := current_wins + (1 if is_win else 0)
		var new_losses := current_losses + (0 if is_win else 1)
		var new_games := current_games + 1
		
		print("[TGC PostGame] 📊 Akashic Stats update: wins %d→%d, losses %d→%d, games %d→%d" % [
			current_wins, new_wins,
			current_losses, new_losses,
			current_games, new_games
		])
		
		# PATCH the updated stats
		var http_patch := HTTPRequest.new()
		get_tree().root.add_child(http_patch)
		
		var patch_url := "%s?updateMask.fieldPaths=akashic_wins&updateMask.fieldPaths=akashic_losses&updateMask.fieldPaths=akashic_games_played" % user_doc_url
		var patch_payload := {
			"fields": {
				"akashic_wins": {"integerValue": str(new_wins)},
				"akashic_losses": {"integerValue": str(new_losses)},
				"akashic_games_played": {"integerValue": str(new_games)}
			}
		}
		
		http_patch.request_completed.connect(func(_r2, code2, _h2, _body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[TGC PostGame] ✅ Akashic Leaderboard stats updated!")
				# Also update RTDB leaderboard
				var lb_username: String = ""
				if fields.has("username"):
					lb_username = str(_from_firestore_value(fields["username"]))
				if lb_username == "":
					lb_username = "Player"
				_update_rtdb_leaderboard("akashic_tcg", uid, lb_username, {
					"wins": new_wins,
					"losses": new_losses,
					"games": new_games
				})
			else:
				print("[TGC PostGame] ⚠️ Failed to update Akashic leaderboard stats: %d" % code2)
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
			print("[TGC PostGame] ✅ RTDB Leaderboard updated for %s" % username)
		else:
			print("[TGC PostGame] ⚠️ RTDB Leaderboard update failed: HTTP %d" % code)
	)
	
	var hdr := PackedStringArray(["Content-Type: application/json"])
	http.request(url, hdr, HTTPClient.METHOD_PUT, JSON.stringify(entry))
