extends Node

const SETTINGS_PATH := "user://settings.cfg"

# Default volume set to 80 (approx -16 dB) so first-time users hear audio clearly.
# Previously was 50 which mapped to ~-40 dB and sounded almost muted.
var music_level: int = 80 # 1..100
var fullscreen: bool = false

func _enter_tree() -> void:
	# Apply as early as possible so onboarding scenes don't play at default volume
	# for a frame before settings are loaded.
	load_settings()
	apply_all()


func _ready() -> void:
	# Defensive re-apply (safe if called twice).
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# No settings file exists (first-time user). Save defaults now so they
		# persist immediately and apply_all() uses them.
		save_settings()
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
	# NOTE: We intentionally do NOT auto-apply display mode on startup.
	# This prevents the 2nd instance from going fullscreen when testing multiplayer.
	# Users can still toggle fullscreen manually via Settings panel.
	# apply_display_mode(fullscreen)


func _map_level_to_db(level: float) -> float:
	# Map 1-100 slider to -80 dB to +6 dB (allows boosting above unity)
	# 50 = ~-37 dB (quiet), 80 = ~-6 dB (normal), 100 = +6 dB (loud/boosted)
	var t: float = clampf((level - 1.0) / 99.0, 0.0, 1.0)
	return lerp(-80.0, 6.0, t)  # +6 dB max for louder audio


func apply_music_volume_db(vol_db: float) -> void:
	# The settings UI exposes a single "Volume" slider.
	# To keep onboarding audio consistent (story/3D/welcome/rewards), apply this
	# to the Master bus so it affects ALL audio.
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, vol_db)


func apply_display_mode(is_fullscreen: bool) -> void:
	var window := get_viewport().get_window()
	if window:
		window.mode = Window.MODE_FULLSCREEN if is_fullscreen else Window.MODE_WINDOWED
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
