extends Control

@onready var volume_slider: HSlider = $Window/Body/VolumeSlider
@onready var volume_value_label: Label = $Window/Body/VolumeValue
@onready var display_mode: OptionButton = $Window/Body/DisplayMode
@onready var apply_button: Button = $Window/Body/ApplyButton
@onready var close_button: Button = $Window/Body/CloseButton

const SETTINGS_PATH := "user://settings.cfg"

var _target_music: AudioStreamPlayer = null

func _ready() -> void:
	# connect signals
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	if apply_button and not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	# Ensure display mode options exist
	if display_mode and display_mode.get_item_count() == 0:
		display_mode.add_item("Windowed")
		display_mode.add_item("Fullscreen")

	_load_settings()

func _on_volume_changed(value: float) -> void:
	volume_value_label.text = "%d" % int(value)

func _map_level_to_db(level: float) -> float:
	var t = clamp((level - 1.0) / 99.0, 0.0, 1.0)
	return lerp(-80.0, 0.0, t)

func _on_close_pressed() -> void:
	print("🔙 Closing settings panel...")
	queue_free()
	
func _on_apply_pressed() -> void:
	var vol_level = int(volume_slider.value)
	var vol_db = _map_level_to_db(vol_level)
	var is_full = (display_mode.selected == 1)

	_apply_music_volume_db(vol_db)
	_apply_display_mode(is_full)

	# Persist settings (save integer 1..100)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_level", vol_level)
	cfg.set_value("display", "fullscreen", is_full)
	cfg.save(SETTINGS_PATH)
	
	print("✅ Settings applied: Volume=%d, Fullscreen=%s" % [vol_level, is_full])


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK:
		var vol_level = int(cfg.get_value("audio", "music_level", 50))
		var full = cfg.get_value("display", "fullscreen", false)
		volume_slider.value = float(vol_level)
		volume_value_label.text = "%d" % int(vol_level)
		display_mode.select(1 if full else 0)

		_apply_music_volume_db(_map_level_to_db(vol_level))
		_apply_display_mode(bool(full))
	else:
		# No settings yet; keep defaults but keep label in sync
		volume_value_label.text = "%d" % int(volume_slider.value)


func set_target_music(node: Node) -> void:
	if node and node is AudioStreamPlayer:
		_target_music = node


func _apply_music_volume_db(vol_db: float) -> void:
	# Apply to explicit target if set
	if _target_music and is_instance_valid(_target_music):
		_target_music.volume_db = vol_db
		return

	# Try common music node names across scenes
	var cs := get_tree().get_current_scene()
	var music: Node = null
	if cs:
		music = _find_node_by_name(cs, "BackgroundMusic")
		if not music:
			music = _find_node_by_name(cs, "BackgroundMusicPlayer") # Landing
		if not music:
			music = _find_node_by_name(cs, "BattleMusic")

	if music and music is AudioStreamPlayer:
		(music as AudioStreamPlayer).volume_db = vol_db


func _apply_display_mode(fullscreen: bool) -> void:
	# Prefer Window API (more reliable in Godot 4), fallback to DisplayServer
	var window := get_viewport().get_window()
	if window:
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _find_node_by_name(node: Node, target: String) -> Node:
	if node == null:
		return null
	if node.name == target:
		return node
	for child in node.get_children():
		if child is Node:
			var res = _find_node_by_name(child, target)
			if res:
				return res
	return null
