extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# GameMode Leaderboard
# ═══════════════════════════════════════════════════════════════════════════════
# Shows the leaderboard after a multiplayer game mode session.
# Polls the server every 5 seconds to update results.
# ═══════════════════════════════════════════════════════════════════════════════

var _room_code: String = ""
var _lobby_url: String = ""
var _poll_timer: Timer = null
var _leaderboard_vbox: VBoxContainer = null

func _ready() -> void:
	_room_code = str(get_tree().get_meta("gamemode_leaderboard_room_code", ""))
	_lobby_url = str(get_tree().get_meta("gamemode_leaderboard_lobby_url", ""))

	if _room_code.is_empty():
		push_error("[GameMode] No room code for leaderboard")
		get_tree().change_scene_to_file("res://scene/landing.tscn")
		return

	_build_ui()

	# Start polling
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 5.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll_results)

	# Immediate first poll
	_poll_results()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	canvas.add_child(margin)

	var panel := PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.04, 0.08, 0.18, 0.95)
	panel_sb.border_color = Color(0, 0.85, 1, 0.7)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_sb)
	margin.add_child(panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_top", 20)
	inner_margin.add_theme_constant_override("margin_left", 30)
	inner_margin.add_theme_constant_override("margin_right", 30)
	inner_margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(inner_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_margin.add_child(scroll)

	_leaderboard_vbox = VBoxContainer.new()
	_leaderboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_leaderboard_vbox)

	var loading := Label.new()
	loading.text = "Loading leaderboard..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_leaderboard_vbox.add_child(loading)

func _poll_results() -> void:
	if _lobby_url.is_empty() or _room_code.is_empty():
		return
	var url := _lobby_url + "/api/gamemode/%s/results" % _room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			return
		_update_leaderboard(data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _update_leaderboard(data: Dictionary) -> void:
	if not _leaderboard_vbox:
		return

	var leaderboard: Array = data.get("leaderboard", [])
	var game_name: String = data.get("game_name", "Game Mode")
	var room_name: String = data.get("room_name", "")

	# Clear
	for child in _leaderboard_vbox.get_children():
		child.queue_free()

	# Header
	var header := Label.new()
	header.text = "🏆 %s — Leaderboard" % game_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0, 1, 1))
	header.add_theme_font_size_override("font_size", 24)
	_leaderboard_vbox.add_child(header)

	if not room_name.is_empty():
		var room_lbl := Label.new()
		room_lbl.text = room_name
		room_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		room_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
		room_lbl.add_theme_font_size_override("font_size", 14)
		_leaderboard_vbox.add_child(room_lbl)

	# Spacer
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_leaderboard_vbox.add_child(gap)

	# Determine if this is a time-only game (Encryption has no score)
	var is_time_only: bool = game_name.to_lower().find("encryption") >= 0

	# Column header
	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 12)
	var columns: Array
	if is_time_only:
		columns = [["#", 40], ["Player", 0], ["Time", 100]]
	else:
		columns = [["#", 40], ["Player", 0], ["Score", 100], ["Time", 100]]
	for pair in columns:
		var lbl := Label.new()
		lbl.text = pair[0]
		if pair[1] > 0:
			lbl.custom_minimum_size = Vector2(pair[1], 0)
		else:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
		lbl.add_theme_font_size_override("font_size", 14)
		col_header.add_child(lbl)
	_leaderboard_vbox.add_child(col_header)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0, 0.85, 1, 0.3))
	_leaderboard_vbox.add_child(sep)

	# Rows
	for entry in leaderboard:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		# Rank
		var rank_lbl := Label.new()
		var rank_num: int = entry.get("rank", 0)
		var emoji := "🥇" if rank_num == 1 else ("🥈" if rank_num == 2 else ("🥉" if rank_num == 3 else "#%d" % rank_num))
		rank_lbl.text = emoji
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		rank_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(rank_lbl)

		# Player name
		var name_lbl := Label.new()
		var uname: String = str(entry.get("username", "???"))
		# Highlight current player
		if str(entry.get("player_id", "")) == Auth.current_local_id:
			name_lbl.text = "%s (You)" % uname
			name_lbl.add_theme_color_override("font_color", Color(0, 1, 1))
		else:
			name_lbl.text = uname
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(name_lbl)

		var finished: bool = entry.get("finished", false)

		# Score (hidden for time-only games like Encryption)
		if not is_time_only:
			var score_lbl := Label.new()
			if finished:
				score_lbl.text = "%d" % entry.get("score", 0)
			else:
				score_lbl.text = "playing..."
			score_lbl.custom_minimum_size = Vector2(100, 0)
			score_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5) if finished else Color(0.7, 0.7, 0.7))
			score_lbl.add_theme_font_size_override("font_size", 18)
			row.add_child(score_lbl)

		# Time
		var time_lbl := Label.new()
		if finished:
			var time_ms: int = entry.get("time_taken_ms", 0)
			@warning_ignore("integer_division")
			var secs := time_ms / 1000
			@warning_ignore("integer_division")
			var mins := secs / 60
			secs = secs % 60
			time_lbl.text = "%d:%02d" % [mins, secs]
		else:
			time_lbl.text = "playing..." if is_time_only else "—"
		time_lbl.custom_minimum_size = Vector2(100, 0)
		time_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3) if finished else Color(0.7, 0.7, 0.7))
		time_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(time_lbl)

		# Highlight row for current player
		if str(entry.get("player_id", "")) == Auth.current_local_id:
			var row_panel := PanelContainer.new()
			var row_sb := StyleBoxFlat.new()
			row_sb.bg_color = Color(0, 0.2, 0.3, 0.5)
			row_sb.set_corner_radius_all(6)
			row_panel.add_theme_stylebox_override("panel", row_sb)
			row_panel.add_child(row)
			_leaderboard_vbox.add_child(row_panel)
		else:
			_leaderboard_vbox.add_child(row)

	if leaderboard.is_empty():
		var empty := Label.new()
		empty.text = "No results yet..."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_leaderboard_vbox.add_child(empty)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_leaderboard_vbox.add_child(spacer)

	# Back to Landing button
	var back_btn := Button.new()
	back_btn.text = "← Back to Landing"
	back_btn.custom_minimum_size = Vector2(220, 48)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0, 0.5, 0.7, 0.9)
	back_sb.border_color = Color(0, 1, 1, 0.8)
	back_sb.set_border_width_all(2)
	back_sb.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", back_sb)
	back_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func():
		if _poll_timer:
			_poll_timer.queue_free()
			_poll_timer = null
		# Clean up meta
		if get_tree().has_meta("gamemode_room_code"):
			get_tree().remove_meta("gamemode_room_code")
		if get_tree().has_meta("gamemode_lobby_url"):
			get_tree().remove_meta("gamemode_lobby_url")
		if get_tree().has_meta("gamemode_start_time_ms"):
			get_tree().remove_meta("gamemode_start_time_ms")
		if get_tree().has_meta("gamemode_leaderboard_room_code"):
			get_tree().remove_meta("gamemode_leaderboard_room_code")
		if get_tree().has_meta("gamemode_leaderboard_lobby_url"):
			get_tree().remove_meta("gamemode_leaderboard_lobby_url")
		get_tree().change_scene_to_file("res://scene/landing.tscn")
	)
	_leaderboard_vbox.add_child(back_btn)
