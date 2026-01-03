extends Node

const SETTINGS_PATH := "user://settings.cfg"

var music_level: int = 50 # 1..100
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return

	music_level = int(cfg.get_value("audio", "music_level", music_level))
	music_level = clampi(music_level, 1, 100)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_level", clampi(music_level, 1, 100))
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func set_music_level(level: int) -> void:
	music_level = clampi(level, 1, 100)
	apply_music_volume_db(_map_level_to_db(music_level))
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_display_mode(fullscreen)
	save_settings()


func apply_all() -> void:
	apply_music_volume_db(_map_level_to_db(music_level))
	apply_display_mode(fullscreen)


func _map_level_to_db(level: float) -> float:
	var t: float = clampf((level - 1.0) / 99.0, 0.0, 1.0)
	return lerp(-80.0, 0.0, t)


func apply_music_volume_db(vol_db: float) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, vol_db)
		return
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, vol_db)


func apply_display_mode(is_fullscreen: bool) -> void:
	var window := get_viewport().get_window()
	if window:
		window.mode = Window.MODE_FULLSCREEN if is_fullscreen else Window.MODE_WINDOWED
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
