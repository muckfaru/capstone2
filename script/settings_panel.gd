extends Control

@onready var volume_slider: HSlider = $Window/Body/VolumeSlider
@onready var volume_value_label: Label = $Window/Body/VolumeValue
@onready var display_mode: OptionButton = $Window/Body/DisplayMode
@onready var apply_button: Button = $Window/Body/ApplyButton
@onready var close_button: Button = $Window/Body/CloseButton

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	# connect signals
	if volume_slider and not volume_slider.value_changed.is_connected(_on_volume_changed):
		volume_slider.value_changed.connect(_on_volume_changed)
	if apply_button and not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	_load_settings()

func _on_volume_changed(value: float) -> void:
	volume_value_label.text = "%d dB" % int(value)

func _on_apply_pressed() -> void:
	var vol_db = volume_slider.value
	var is_full = (display_mode.selected == 1)

	# Apply to BattleMusic if present
	var music = _find_node_by_name(get_tree().get_current_scene(), "BattleMusic")
	if music and music is AudioStreamPlayer:
		music.volume_db = vol_db

	# Persist settings
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_db", vol_db)
	cfg.set_value("display", "fullscreen", is_full)
	cfg.save(SETTINGS_PATH)

func _on_close_pressed() -> void:
	# Show menu if it exists
	var menu = _find_node_by_name(get_tree().get_current_scene(), "MenuPanel")
	if menu:
		menu.visible = true
	queue_free()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK:
		var vol = cfg.get_value("audio", "music_db", -5)
		var full = cfg.get_value("display", "fullscreen", false)
		volume_slider.value = float(vol)
		volume_value_label.text = "%d dB" % int(vol)
		display_mode.select(1 if full else 0)

		# Apply music volume immediately if present
		var music = _find_node_by_name(get_tree().get_current_scene(), "BattleMusic")
		if music and music is AudioStreamPlayer:
			music.volume_db = float(vol)


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
