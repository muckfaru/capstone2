@tool
extends Control

# This post-game screen intentionally reuses the Code Breaker postgame UI scene
# (via scene inheritance) to keep the same visual design.

@onready var _title_label: Label = $TitleLabel

# Cards are at root level in parent scene (code_breaker_postgame.tscn)
@onready var _host_card: NinePatchRect = $HostCard
@onready var _client_card: NinePatchRect = $ClientCard
var _client2_card: NinePatchRect = null  # Created at runtime by duplicating ClientCard

@onready var _cards_container: Control = get_node_or_null("NinePatchRect/pstpnl") as Control

@onready var _back_button: Button = $BackToLandingButton

# Host fields (access via card reference for clarity)
func _get_host_username() -> Label: return _host_card.get_node("HostUsername") as Label
func _get_host_status() -> Label: return _host_card.get_node("HostStatus") as Label
func _get_host_wave() -> Label: return _host_card.get_node("HostXP") as Label
func _get_host_time() -> Label: return _host_card.get_node("HostTime") as Label
func _get_host_score() -> Label: return _host_card.get_node("HostPowerups") as Label
func _get_host_wpm() -> Label: return _host_card.get_node("HostWPM") as Label
func _get_host_accuracy() -> Label: return _host_card.get_node("HostAccuracy") as Label
func _get_host_streak() -> Label: return _host_card.get_node("HostWrongSubmissions") as Label

# Game init data
var _init: Dictionary = {}
var _relay_client: Node = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_title_label.text = "DEFUSE THE TROJAN"
		_reparent_cards_to_panel()
		_create_styled_client2_card()
		_hide_unused_stat_rows()
		return

	# Pull init payload
	if get_tree().has_meta("defuse_trojan_postgame_init"):
		_init = get_tree().get_meta("defuse_trojan_postgame_init")
		get_tree().set_meta("defuse_trojan_postgame_init", null)

	_title_label.text = "DEFUSE THE TROJAN"

	var relay_any = _init.get("relay_client", null)
	if relay_any != null and is_instance_valid(relay_any):
		_relay_client = relay_any
		if _relay_client.get_parent() == get_tree().root:
			_relay_client.get_parent().remove_child(_relay_client)
			add_child(_relay_client)
	else:
		_relay_client = null

	_back_button.pressed.connect(_on_back_pressed)

	_reparent_cards_to_panel()
	_create_styled_client2_card()
	_hide_unused_stat_rows()
	_apply_results()


func _reparent_cards_to_panel() -> void:
	var panel := get_node_or_null("NinePatchRect/pstpnl") as Control
	if not panel:
		push_warning("[DefuseTrojanPostgame] pstpnl panel not found")
		return
	
	# Reparent HostCard to panel
	if is_instance_valid(_host_card) and _host_card.get_parent() != panel:
		_host_card.get_parent().remove_child(_host_card)
		panel.add_child(_host_card)
	
	# Reparent ClientCard to panel  
	if is_instance_valid(_client_card) and _client_card.get_parent() != panel:
		_client_card.get_parent().remove_child(_client_card)
		panel.add_child(_client_card)


func _create_styled_client2_card() -> void:
	# Safety check - _client_card must exist
	if not is_instance_valid(_client_card):
		push_warning("[DefuseTrojanPostgame] _client_card is null, cannot create ClientCard2")
		return
	
	# Remove any existing ClientCard2
	if _client2_card and is_instance_valid(_client2_card):
		_client2_card.queue_free()
		_client2_card = null
	
	# Create a styled duplicate of ClientCard
	_client2_card = _client_card.duplicate() as NinePatchRect
	_client2_card.name = "ClientCard2"
	_client2_card.visible = true
	
	# Add to same parent as other cards
	var parent := _client_card.get_parent()
	if parent:
		parent.add_child(_client2_card)
	else:
		add_child(_client2_card)
	
	# Set placeholder text for Player 3
	var uname = _client2_card.get_node_or_null("ClientUsername") as Label
	if uname:
		uname.text = "Player 3"
	
	# Now reposition all 3 cards for proper layout
	_layout_three_cards_manual()


func _get_cards_container() -> Control:
	if _cards_container != null:
		return _cards_container
	return self


func _layout_three_cards_manual() -> void:
	# This is called during card creation - full layout happens in _layout_cards_for_player_count()
	pass


func _layout_cards_for_player_count(player_count: int) -> void:
	# Panel size: 1032 x 480 (pstpnl)
	# Original card size is 400x400 (internal Panel)
	# We SCALE the cards to fit, since resizing NinePatchRect doesn't resize children
	const PANEL_WIDTH := 1032.0
	const PANEL_HEIGHT := 480.0
	const ORIGINAL_CARD_WIDTH := 400.0
	const ORIGINAL_CARD_HEIGHT := 400.0
	const SPACING := 15.0
	
	if player_count <= 1:
		# Solo mode - center single card, no scaling needed
		var scale_factor := 1.0
		var scaled_width := ORIGINAL_CARD_WIDTH * scale_factor
		var start_x := (PANEL_WIDTH - scaled_width) / 2.0
		var start_y := (PANEL_HEIGHT - ORIGINAL_CARD_HEIGHT) / 2.0
		
		if is_instance_valid(_host_card):
			_host_card.scale = Vector2(scale_factor, scale_factor)
			_host_card.position = Vector2(start_x, start_y)
		if is_instance_valid(_client_card):
			_client_card.visible = false
		if is_instance_valid(_client2_card):
			_client2_card.visible = false
			
	elif player_count == 2:
		# 2 players - scale down slightly to fit both
		var scale_factor := 0.9
		var scaled_width := ORIGINAL_CARD_WIDTH * scale_factor
		var scaled_height := ORIGINAL_CARD_HEIGHT * scale_factor
		var total_width := (scaled_width * 2.0) + SPACING
		var start_x := (PANEL_WIDTH - total_width) / 2.0
		var start_y := (PANEL_HEIGHT - scaled_height) / 2.0
		
		if is_instance_valid(_host_card):
			_host_card.scale = Vector2(scale_factor, scale_factor)
			_host_card.position = Vector2(start_x, start_y)
		if is_instance_valid(_client_card):
			var client_x := start_x + scaled_width + SPACING
			_client_card.scale = Vector2(scale_factor, scale_factor)
			_client_card.position = Vector2(client_x, start_y)
		if is_instance_valid(_client2_card):
			_client2_card.visible = false
			
	else:
		# 3 players - scale down to fit all 3
		# Available width per card = (1032 - 2*15) / 3 = 334
		# Scale factor = 334 / 400 = 0.835 -> use 0.8 for safety
		var scale_factor := 0.8
		var scaled_width := ORIGINAL_CARD_WIDTH * scale_factor  # 320
		var scaled_height := ORIGINAL_CARD_HEIGHT * scale_factor  # 320
		var total_width := (scaled_width * 3.0) + (SPACING * 2.0)  # 320*3 + 30 = 990
		var start_x := (PANEL_WIDTH - total_width) / 2.0  # (1032-990)/2 = 21
		var start_y := (PANEL_HEIGHT - scaled_height) / 2.0  # (480-320)/2 = 80
		
		if is_instance_valid(_host_card):
			_host_card.scale = Vector2(scale_factor, scale_factor)
			_host_card.position = Vector2(start_x, start_y)
		if is_instance_valid(_client_card):
			var client_x := start_x + scaled_width + SPACING
			_client_card.scale = Vector2(scale_factor, scale_factor)
			_client_card.position = Vector2(client_x, start_y)
		if is_instance_valid(_client2_card):
			var client2_x := start_x + (scaled_width * 2.0) + (SPACING * 2.0)
			_client2_card.scale = Vector2(scale_factor, scale_factor)
			_client2_card.position = Vector2(client2_x, start_y)


func _hide_unused_stat_rows() -> void:
	# We only show: MODE, WAVE, TIME, SCORE, WPM, ACCURACY, STREAK.
	# Hide unused rows on host card
	for node_name in ["HostAvgTime", "HostFastestTime", "HostDamageStats", "HostComebackBadge"]:
		var n = _host_card.get_node_or_null(node_name)
		if n:
			n.visible = false
	# Hide unused rows on client card
	for node_name in ["ClientAvgTime", "ClientFastestTime", "ClientDamageStats", "ClientComebackBadge"]:
		var n = _client_card.get_node_or_null(node_name)
		if n:
			n.visible = false
	if _client2_card:
		for node_name in ["ClientAvgTime", "ClientFastestTime", "ClientDamageStats", "ClientComebackBadge"]:
			var n2 = _client2_card.get_node_or_null(node_name)
			if n2:
				n2.visible = false


func _apply_results() -> void:
	var mode := str(_init.get("mode", "solo"))
	var duration_ms := int(_init.get("duration_ms", 0))
	var wave_reached := int(_init.get("wave_reached", 1))

	var players: Array = _init.get("players", [])
	var stats_by_pid: Dictionary = _init.get("stats_by_player_id", {})
	var player_count := players.size()
	
	# Save match history to Firestore
	_save_match_history_to_firestore(mode, duration_ms, wave_reached, players, stats_by_pid)

	# Host card
	if player_count >= 1:
		_apply_card(_host_card, true, players[0], mode, duration_ms, wave_reached, stats_by_pid)
	else:
		_get_host_username().text = "Player"
		_get_host_status().text = "MODE: %s" % mode.to_upper()
		_get_host_wave().text = "WAVE: %d" % wave_reached
		_get_host_time().text = "TIME: %s" % _format_duration(duration_ms)
		_get_host_score().text = "SCORE: 0"
		_get_host_wpm().text = "WPM: 0.0"
		_get_host_accuracy().text = "ACC: 0.0%"
		_get_host_streak().text = "STREAK: 0"

	# Client card 1
	if player_count >= 2:
		_client_card.visible = true
		_apply_card(_client_card, false, players[1], mode, duration_ms, wave_reached, stats_by_pid)
	else:
		_client_card.visible = false

	# Client card 2
	if _client2_card:
		if player_count >= 3:
			_client2_card.visible = true
			_apply_card(_client2_card, false, players[2], mode, duration_ms, wave_reached, stats_by_pid)
		else:
			_client2_card.visible = false
	
	# Re-layout cards based on visible player count
	_layout_cards_for_player_count(player_count)


func _apply_card(card: NinePatchRect, is_host: bool, player: Dictionary, mode: String, duration_ms: int, wave_reached: int, stats_by_pid: Dictionary) -> void:
	var pid := str(player.get("player_id", ""))
	var uname := str(player.get("username", "Player"))
	var st: Dictionary = stats_by_pid.get(pid, {})

	var score := int(st.get("score", 0))
	var wpm := float(st.get("wpm", 0.0))
	var acc := float(st.get("accuracy_pct", 0.0))
	var streak := int(st.get("longest_streak", 0))

	if is_host:
		(card.get_node("HostUsername") as Label).text = uname
		(card.get_node("HostStatus") as Label).text = "MODE: %s" % mode.to_upper()
		(card.get_node("HostXP") as Label).text = "WAVE: %d" % wave_reached
		(card.get_node("HostTime") as Label).text = "TIME: %s" % _format_duration(duration_ms)
		(card.get_node("HostPowerups") as Label).text = "SCORE: %d" % score
		(card.get_node("HostWPM") as Label).text = "WPM: %.1f" % wpm
		(card.get_node("HostAccuracy") as Label).text = "ACC: %.1f%%" % acc
		(card.get_node("HostWrongSubmissions") as Label).text = "STREAK: %d" % streak
		var badge = card.get_node_or_null("WinnerBadge")
		if badge:
			badge.visible = false
	else:
		(card.get_node("ClientUsername") as Label).text = uname
		(card.get_node("ClientStatus") as Label).text = "MODE: %s" % mode.to_upper()
		(card.get_node("ClientXP") as Label).text = "WAVE: %d" % wave_reached
		(card.get_node("ClientTime") as Label).text = "TIME: %s" % _format_duration(duration_ms)
		(card.get_node("ClientPowerups") as Label).text = "SCORE: %d" % score
		(card.get_node("ClientWPM") as Label).text = "WPM: %.1f" % wpm
		(card.get_node("ClientAccuracy") as Label).text = "ACC: %.1f%%" % acc
		(card.get_node("ClientWrongSubmissions") as Label).text = "STREAK: %d" % streak
		var badge2 = card.get_node_or_null("WinnerBadge")
		if badge2:
			badge2.visible = false


func _format_duration(duration_ms: int) -> String:
	var total_seconds := int(round(duration_ms / 1000.0))
	if total_seconds < 0:
		total_seconds = 0
	var minutes: int = int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	return "%dm %02ds" % [minutes, seconds]


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")

# === Match History Firestore Integration ===

func _save_match_history_to_firestore(mode: String, duration_ms: int, wave_reached: int, players: Array, stats_by_pid: Dictionary) -> void:
	"""Save Defuse the Trojan match history to Firestore"""
	if not Auth or not Auth.current_id_token or Auth.current_id_token == "":
		print("[DefuseTrojanPostgame] ⚠️ No auth token, skipping match history save")
		return
	
	if players.size() == 0:
		print("[DefuseTrojanPostgame] ⚠️ No players data, skipping match history save")
		return
	
	print("[DefuseTrojanPostgame] 📝 Saving match history to Firestore...")
	
	# Generate unique match ID
	var now_unix_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var match_id := "%d_%s" % [now_unix_ms, Auth.current_local_id]
	
	# Build participant IDs array
	var participant_ids: Array = []
	var participant_usernames: Array = []
	for p in players:
		var pid := str(p.get("player_id", ""))
		var uname := str(p.get("username", "Player"))
		if pid != "":
			participant_ids.append(pid)
			participant_usernames.append(uname)
	
	# Build player stats for storage
	var player_stats: Dictionary = {}
	for pid in stats_by_pid.keys():
		var st: Dictionary = stats_by_pid[pid]
		player_stats[pid] = {
			"score": int(st.get("score", 0)),
			"wpm": float(st.get("wpm", 0.0)),
			"accuracy_pct": float(st.get("accuracy_pct", 0.0)),
			"longest_streak": int(st.get("longest_streak", 0))
		}
	
	# Find top scorer
	var top_score: int = 0
	var top_scorer_id: String = ""
	var top_scorer_name: String = ""
	for i in range(players.size()):
		var pid := str(players[i].get("player_id", ""))
		var uname := str(players[i].get("username", "Player"))
		var st: Dictionary = stats_by_pid.get(pid, {})
		var sc: int = int(st.get("score", 0))
		if sc > top_score:
			top_score = sc
			top_scorer_id = pid
			top_scorer_name = uname
	
	# Duration in seconds
	var duration_seconds := int(round(duration_ms / 1000.0))
	
	# Create match document
	var match_data := {
		"game_type": "defuse_trojan",
		"mode": mode,
		"wave_reached": wave_reached,
		"duration_s": duration_seconds,
		"duration_formatted": _format_duration(duration_ms),
		
		# Participants
		"participant_ids": participant_ids,
		"participant_usernames": participant_usernames,
		"player_count": players.size(),
		
		# Top scorer info
		"top_scorer_id": top_scorer_id,
		"top_scorer_name": top_scorer_name,
		"top_score": top_score,
		
		# Per-player stats
		"player_stats": player_stats,
		
		# Timestamps
		"created_at": now_unix_ms - duration_ms,
		"ended_at": now_unix_ms,
		"timestamp": now_unix_ms
	}
	
	# Create HTTP request
	var http := HTTPRequest.new()
	add_child(http)
	
	var firestore_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/match_history?documentId=%s" % match_id
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	])
	
	# Format payload for Firestore
	var payload := _format_firestore_payload(match_data)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		var response_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
		if code == 200 or code == 201:
			print("[DefuseTrojanPostgame] ✅ Match history saved! ID: %s" % match_id)
			# Also save to user's recent_matches
			_append_recent_match_to_user_doc(match_data)
			# Update leaderboard stats
			_update_leaderboard_stats(match_data.get("wave_reached", 1), match_data.get("top_score", 0))
		else:
			print("[DefuseTrojanPostgame] ⚠️ Failed to save match history: %d\n%s" % [code, response_text])
	)
	
	http.request(firestore_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))


func _append_recent_match_to_user_doc(match_data: Dictionary) -> void:
	"""Append this match to the user's recent_matches array in their user document"""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	
	print("[DefuseTrojanPostgame] 📝 Saving recent match to users/%s" % Auth.current_local_id)
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])
	
	# Load existing list
	var http_get := HTTPRequest.new()
	add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		
		if code != 200:
			print("[DefuseTrojanPostgame] ⚠️ Failed to load user doc for recent_matches")
			return
		
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			return
		var doc = json.get_data()
		var fields = doc.get("fields", {})
		
		# Get existing recent_matches or create empty array
		var recent: Array = []
		if fields.has("recent_matches"):
			recent = _from_firestore_value(fields["recent_matches"])
			if not recent is Array:
				recent = []
		
		# Create compact entry for this match
		var entry := {
			"game_type": "defuse_trojan",
			"mode": match_data.get("mode", "solo"),
			"wave_reached": match_data.get("wave_reached", 1),
			"score": match_data.get("top_score", 0),
			"duration_s": match_data.get("duration_s", 0),
			"timestamp": match_data.get("timestamp", 0),
			"player_count": match_data.get("player_count", 1)
		}
		
		# Add to front, keep max 20 entries
		recent.insert(0, entry)
		if recent.size() > 20:
			recent = recent.slice(0, 20)
		
		# Update user doc
		var http_patch := HTTPRequest.new()
		add_child(http_patch)
		
		var patch_url := "%s?updateMask.fieldPaths=recent_matches" % user_doc_url
		var patch_payload := {
			"fields": {
				"recent_matches": _to_firestore_value(recent)
			}
		}
		
		http_patch.request_completed.connect(func(_r2, code2, _h2, _body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[DefuseTrojanPostgame] ✅ Recent match appended to user doc")
			else:
				print("[DefuseTrojanPostgame] ⚠️ Failed to update recent_matches: %d" % code2)
		)
		
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(patch_payload))
	)
	
	http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)


func _format_firestore_payload(data: Dictionary) -> Dictionary:
	"""Convert data dictionary to Firestore document format"""
	var fields: Dictionary = {}
	for key in data.keys():
		fields[key] = _to_firestore_value(data[key])
	return {"fields": fields}


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
	# Fallback: stringify
	return {"stringValue": str(value)}


func _from_firestore_value(v) -> Variant:
	if v == null:
		return null
	if v.has("stringValue"):
		return v["stringValue"]
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	if v.has("nullValue"):
		return null
	if v.has("arrayValue"):
		var out: Array = []
		var arr = v["arrayValue"]
		if arr.has("values"):
			for item in arr["values"]:
				out.append(_from_firestore_value(item))
		return out
	if v.has("mapValue"):
		var out_d: Dictionary = {}
		var f = v["mapValue"].get("fields", {})
		for k in f.keys():
			out_d[str(k)] = _from_firestore_value(f[k])
		return out_d
	return null


func _update_leaderboard_stats(wave_reached: int, score: int) -> void:
	"""Update user's Defuse the Trojan leaderboard stats (best wave, high score, games played)"""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[DefuseTrojanPostgame] ⚠️ Cannot update leaderboard stats - not logged in")
		return
	
	print("[DefuseTrojanPostgame] 📊 Updating leaderboard stats: wave=%d, score=%d" % [wave_reached, score])
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var user_doc_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % uid
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	])
	
	# First GET current stats
	var http_get := HTTPRequest.new()
	add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		
		if code != 200:
			print("[DefuseTrojanPostgame] ⚠️ Failed to GET user doc for leaderboard stats")
			return
		
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			return
		var doc = json.get_data()
		var fields = doc.get("fields", {})
		
		# Get existing stats
		var current_best_wave := 0
		var current_high_score := 0
		var current_games_played := 0
		
		if fields.has("dt_best_wave"):
			current_best_wave = int(_from_firestore_value(fields["dt_best_wave"]))
		if fields.has("dt_high_score"):
			current_high_score = int(_from_firestore_value(fields["dt_high_score"]))
		if fields.has("dt_games_played"):
			current_games_played = int(_from_firestore_value(fields["dt_games_played"]))
		
		# Calculate new values
		var new_best_wave: int = max(current_best_wave, wave_reached)
		var new_high_score: int = max(current_high_score, score)
		var new_games_played: int = current_games_played + 1
		
		print("[DefuseTrojanPostgame] 📊 Stats update: best_wave %d→%d, high_score %d→%d, games %d→%d" % [
			current_best_wave, new_best_wave,
			current_high_score, new_high_score,
			current_games_played, new_games_played
		])
		
		# PATCH the updated stats
		var http_patch := HTTPRequest.new()
		add_child(http_patch)
		
		var patch_url := "%s?updateMask.fieldPaths=dt_best_wave&updateMask.fieldPaths=dt_high_score&updateMask.fieldPaths=dt_games_played" % user_doc_url
		var patch_payload := {
			"fields": {
				"dt_best_wave": {"integerValue": str(new_best_wave)},
				"dt_high_score": {"integerValue": str(new_high_score)},
				"dt_games_played": {"integerValue": str(new_games_played)}
			}
		}
		
		http_patch.request_completed.connect(func(_r2, code2, _h2, _body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[DefuseTrojanPostgame] ✅ Leaderboard stats updated!")
			else:
				print("[DefuseTrojanPostgame] ⚠️ Failed to update leaderboard stats: %d" % code2)
		)
		
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(patch_payload))
	)
	
	http_get.request(user_doc_url, headers, HTTPClient.METHOD_GET)
