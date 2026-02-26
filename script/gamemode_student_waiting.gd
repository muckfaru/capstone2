extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# GameMode Student Waiting Screen
# ═══════════════════════════════════════════════════════════════════════════════
# Students see this after joining a Game Mode room.
# Polls the server every 3 seconds to check if the teacher has started the game.
# Once status is "active", transitions to the game.
# ═══════════════════════════════════════════════════════════════════════════════

var _room_code: String = ""
var _lobby_url: String = ""
var _game_scene: String = ""
var _game_name: String = ""
var _poll_timer: Timer = null

var title_label: Label = null
var status_label: Label = null
var game_label: Label = null
var code_label: Label = null
var dots_label: Label = null

var _dot_count: int = 0

func _ready() -> void:
	# Read meta passed from join flow
	_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
	_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
	_game_name = str(get_tree().get_meta("gamemode_game_name", ""))
	_game_scene = str(get_tree().get_meta("gamemode_game_scene", ""))

	if _room_code.is_empty():
		push_error("[GameMode] No room code set. Returning to landing.")
		get_tree().change_scene_to_file("res://scene/landing.tscn")
		return

	# Build UI dynamically since we don't have a .tscn yet
	_build_ui()

	# Start polling
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll_server)

	# Animate dots
	var dot_timer := Timer.new()
	dot_timer.wait_time = 0.5
	dot_timer.autostart = true
	add_child(dot_timer)
	dot_timer.timeout.connect(_animate_dots)

	# Immediate first poll
	_poll_server()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)

	var center := CenterContainer.new()
	center.name = "CenterPanel"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 350)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.04, 0.08, 0.18, 0.95)
	panel_sb.border_color = Color(0, 0.85, 1, 0.7)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🎮 Game Mode"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0, 1, 1))
	title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title_label)

	# Game name
	game_label = Label.new()
	game_label.name = "GameLabel"
	game_label.text = _game_name if not _game_name.is_empty() else "Cybersecurity Fundamentals"
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_label.add_theme_color_override("font_color", Color(0.5, 1, 0.8))
	game_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(game_label)

	# Room code
	code_label = Label.new()
	code_label.name = "CodeLabel"
	code_label.text = "Room: %s" % _room_code
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	code_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(code_label)

	# Status
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Waiting for teacher to start the game"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status_label)

	# Dots animation
	dots_label = Label.new()
	dots_label.name = "DotsLabel"
	dots_label.text = "..."
	dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots_label.add_theme_color_override("font_color", Color(0, 1, 1, 0.7))
	dots_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(dots_label)

func _animate_dots() -> void:
	_dot_count = (_dot_count + 1) % 4
	if dots_label:
		dots_label.text = ".".repeat(_dot_count + 1)

func _poll_server() -> void:
	if _lobby_url.is_empty() or _room_code.is_empty():
		return
	var url := _lobby_url + "/api/gamemode/%s/info" % _room_code
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
		var status: String = data.get("status", "waiting")
		var players_arr: Array = data.get("players", [])
		if status_label:
			status_label.text = "Waiting for teacher to start (%d players joined)" % players_arr.size()
		if status == "active":
			_start_game(data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _start_game(data: Dictionary) -> void:
	# Stop polling
	if _poll_timer:
		_poll_timer.queue_free()
		_poll_timer = null

	# Determine game scene
	var scene_path: String = data.get("game_scene", _game_scene)
	if scene_path.is_empty():
		scene_path = "res://scene/tutorial_cyber_fundamentals.tscn"

	# Set meta for the game to know it's in multiplayer mode
	get_tree().set_meta("gamemode_room_code", _room_code)
	get_tree().set_meta("gamemode_lobby_url", _lobby_url)
	get_tree().set_meta("gamemode_start_time_ms", Time.get_ticks_msec())

	print("[GameMode] Game started! Launching: %s" % scene_path)
	if status_label:
		status_label.text = "Game starting..."

	# Brief delay for visual feedback
	await get_tree().create_timer(0.5).timeout

	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("[GameMode] Scene not found: %s" % scene_path)
		get_tree().change_scene_to_file("res://scene/landing.tscn")
