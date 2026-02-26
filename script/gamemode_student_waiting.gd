extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# GameMode Student Room Screen
# ═══════════════════════════════════════════════════════════════════════════════
# Students see the same Room Panel as teachers but without Start button.
# Shows the game name, player list, and waits for teacher to start.
# Uses TeacherRoomPanel in student mode.
# ═══════════════════════════════════════════════════════════════════════════════

var _room_code: String = ""
var _lobby_url: String = ""
var _game_scene: String = ""
var _game_name: String = ""
var _room_panel: Control = null

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

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Load and instantiate TeacherRoomPanel
	var panel_scene := load("res://scene/TeacherRoomPanel.tscn")
	if panel_scene:
		_room_panel = panel_scene.instantiate()
		add_child(_room_panel)
		
		# Connect signals
		_room_panel.game_started.connect(_on_game_started)
		_room_panel.lobby_closed.connect(_on_back_pressed)

		# Show in student mode (hides Start button, shows waiting message)
		_room_panel.show_lobby_student_mode(
			_room_code,
			_game_name if not _game_name.is_empty() else "Game Mode",
			_game_scene,
			_lobby_url,
			10
		)
	else:
		push_error("[GameMode] Failed to load TeacherRoomPanel.tscn")
		get_tree().change_scene_to_file("res://scene/landing.tscn")

func _on_game_started(data: Dictionary) -> void:
	# Teacher started the game
	var scene_path: String = data.get("game_scene", _game_scene)
	if scene_path.is_empty():
		scene_path = "res://scene/tutorial_cyber_fundamentals.tscn"

	# Set meta for the game to know it's in multiplayer mode
	get_tree().set_meta("gamemode_room_code", _room_code)
	get_tree().set_meta("gamemode_lobby_url", _lobby_url)
	get_tree().set_meta("gamemode_start_time_ms", Time.get_ticks_msec())

	print("[GameMode] Game started! Launching: %s" % scene_path)

	# Brief delay for visual feedback
	await get_tree().create_timer(0.8).timeout

	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("[GameMode] Scene not found: %s" % scene_path)
		get_tree().change_scene_to_file("res://scene/landing.tscn")

func _on_back_pressed() -> void:
	# Return to landing/mode selection
	get_tree().change_scene_to_file("res://scene/landing.tscn")
