extends Node

# ============================================
# DATA VS NETWORK SECURITY - AUDIO MANAGER
# Laboratory-Themed Sound System
# ============================================

class_name DataNetworkAudioManager

# ============================================
# AUDIO PLAYERS - Organized by Category
# ============================================

# UI & Navigation
var sfx_ui_click: AudioStreamPlayer
var sfx_ui_hover: AudioStreamPlayer
var sfx_page_turn: AudioStreamPlayer
var sfx_tutorial_complete: AudioStreamPlayer

# Card/Attack Interaction
var sfx_card_spawn: AudioStreamPlayer
var sfx_card_pickup: AudioStreamPlayer
var sfx_card_drag: AudioStreamPlayer
var sfx_card_hover_zone: AudioStreamPlayer
var sfx_card_timeout: AudioStreamPlayer

# Correct Answers
var sfx_correct_data: AudioStreamPlayer
var sfx_correct_network: AudioStreamPlayer
var sfx_combo_2: AudioStreamPlayer
var sfx_combo_5: AudioStreamPlayer
var sfx_combo_10: AudioStreamPlayer

# Wrong Answers
var sfx_wrong_drop: AudioStreamPlayer
var sfx_system_damage: AudioStreamPlayer
var sfx_shield_break: AudioStreamPlayer
var sfx_game_over: AudioStreamPlayer

# Wave & Progress
var sfx_wave_complete: AudioStreamPlayer
var sfx_wave_start: AudioStreamPlayer
var sfx_wave_transition: AudioStreamPlayer

# CIA Triad Specific
var sfx_confidentiality_damage: AudioStreamPlayer
var sfx_integrity_damage: AudioStreamPlayer
var sfx_availability_damage: AudioStreamPlayer

# Special Effects
var sfx_zone_highlight: AudioStreamPlayer
var sfx_zone_shake: AudioStreamPlayer
var sfx_score_increase: AudioStreamPlayer
var sfx_victory_fanfare: AudioStreamPlayer

# Feedback Popups
var sfx_feedback_appear: AudioStreamPlayer
var sfx_feedback_disappear: AudioStreamPlayer

# Background Music
var music_gameplay: AudioStreamPlayer
var music_intense: AudioStreamPlayer
var music_victory: AudioStreamPlayer
var ambient_lab: AudioStreamPlayer

# ============================================
# AUDIO SETTINGS
# ============================================
const SFX_VOLUME := -8.0
const UI_VOLUME := -10.0
const MUSIC_VOLUME := -12.0
const AMBIENT_VOLUME := -18.0

const MUSIC_FADE_DURATION := 1.5
const MUSIC_FADE_OUT_VOLUME := -40.0

# Track current music
var current_music: AudioStreamPlayer = null
var is_dragging_card := false

# ============================================
# INITIALIZATION
# ============================================
func _ready() -> void:
	print("🎵 [Audio Manager] Initializing Data vs Network Security Audio System...")
	
	# Fix audio bus
	_fix_audio_bus()
	
	# Load all audio files
	_load_all_audio()
	
	print("✅ [Audio Manager] Audio system ready!")


func _fix_audio_bus() -> void:
	"""Ensure Master bus is at proper volume"""
	var master_bus_index = AudioServer.get_bus_index("Master")
	var current_volume = AudioServer.get_bus_volume_db(master_bus_index)
	
	if current_volume < -10.0:
		print("[Audio Manager] Adjusting Master bus from %.1f dB to 0 dB" % current_volume)
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)


# ============================================
# LOAD ALL AUDIO FILES
# ============================================
func _load_all_audio() -> void:
	var sfx_path = "res://asset/labsfx/"
	var music_path = "res://asset/labmusic/"
	
	print("\n=== LOADING LABORATORY AUDIO ===")
	
	# ===== UI & NAVIGATION =====
	print("\n🖱️ UI & Navigation Sounds:")
	sfx_ui_click = _create_sfx([
		sfx_path + "ui_click.mp3",
		sfx_path + "click.mp3",
		sfx_path + "button.mp3"
	], UI_VOLUME)
	
	sfx_ui_hover = _create_sfx([
		sfx_path + "ui_hover.mp3",
		sfx_path + "hover.mp3"
	], UI_VOLUME - 5.0)
	
	sfx_page_turn = _create_sfx([
		sfx_path + "page_turn.mp3",
		sfx_path + "turn.mp3",
		sfx_path + "swoosh.mp3"
	], UI_VOLUME)
	
	sfx_tutorial_complete = _create_sfx([
		sfx_path + "tutorial_complete.mp3",
		sfx_path + "startup.mp3",
		sfx_path + "power_up.mp3"
	], SFX_VOLUME)
	
	# ===== CARD INTERACTIONS =====
	print("\n🃏 Card Interaction Sounds:")
	sfx_card_spawn = _create_sfx([
		sfx_path + "card_spawn.mp3",
		sfx_path + "spawn.mp3",
		sfx_path + "alert.mp3",
		sfx_path + "warning.mp3"
	], SFX_VOLUME)
	
	sfx_card_pickup = _create_sfx([
		sfx_path + "card_pickup.mp3",
		sfx_path + "pickup.mp3",
		sfx_path + "grab.mp3"
	], SFX_VOLUME - 3.0)
	
	sfx_card_drag = _create_sfx([
		sfx_path + "card_drag.mp3",
		sfx_path + "drag.mp3",
		sfx_path + "slide.mp3"
	], SFX_VOLUME - 8.0)
	
	sfx_card_hover_zone = _create_sfx([
		sfx_path + "card_hover_zone.mp3",
		sfx_path + "hover_zone.mp3",
		sfx_path + "zone_hover.mp3"
	], SFX_VOLUME - 5.0)
	
	sfx_card_timeout = _create_sfx([
		sfx_path + "card_timeout.mp3",
		sfx_path + "timeout.mp3",
		sfx_path + "expire.mp3",
		sfx_path + "alarm.mp3"
	], SFX_VOLUME + 2.0)
	
	# ===== CORRECT ANSWERS =====
	print("\n✅ Correct Answer Sounds:")
	sfx_correct_data = _create_sfx([
		sfx_path + "correct_data.mp3",
		sfx_path + "data_correct.mp3",
		sfx_path + "lock.mp3",
		sfx_path + "secure.mp3"
	], SFX_VOLUME)
	
	sfx_correct_network = _create_sfx([
		sfx_path + "correct_network.mp3",
		sfx_path + "network_correct.mp3",
		sfx_path + "connected.mp3",
		sfx_path + "firewall.mp3"
	], SFX_VOLUME)
	
	sfx_combo_2 = _create_sfx([
		sfx_path + "combo_2.mp3",
		sfx_path + "combo_low.mp3",
		sfx_path + "combo1.mp3"
	], SFX_VOLUME + 2.0)
	
	sfx_combo_5 = _create_sfx([
		sfx_path + "combo_5.mp3",
		sfx_path + "combo_medium.mp3",
		sfx_path + "combo2.mp3"
	], SFX_VOLUME + 4.0)
	
	sfx_combo_10 = _create_sfx([
		sfx_path + "combo_10.mp3",
		sfx_path + "combo_high.mp3",
		sfx_path + "combo3.mp3",
		sfx_path + "combo_max.mp3"
	], SFX_VOLUME + 6.0)
	
	# ===== WRONG ANSWERS =====
	print("\n❌ Wrong Answer Sounds:")
	sfx_wrong_drop = _create_sfx([
		sfx_path + "wrong_drop.mp3",
		sfx_path + "wrong.mp3",
		sfx_path + "error.mp3",
		sfx_path + "buzz.mp3"
	], SFX_VOLUME)
	
	sfx_system_damage = _create_sfx([
		sfx_path + "system_damage.mp3",
		sfx_path + "damage.mp3",
		sfx_path + "hit.mp3",
		sfx_path + "shock.mp3"
	], SFX_VOLUME + 2.0)
	
	sfx_shield_break = _create_sfx([
		sfx_path + "shield_break.mp3",
		sfx_path + "break.mp3",
		sfx_path + "shatter.mp3"
	], SFX_VOLUME + 3.0)
	
	sfx_game_over = _create_sfx([
		sfx_path + "game_over.mp3",
		sfx_path + "fail.mp3",
		sfx_path + "shutdown.mp3"
	], SFX_VOLUME + 5.0)
	
	# ===== WAVE PROGRESS =====
	print("\n🌊 Wave Progress Sounds:")
	sfx_wave_complete = _create_sfx([
		sfx_path + "wave_complete.mp3",
		sfx_path + "complete.mp3",
		sfx_path + "success.mp3"
	], SFX_VOLUME + 3.0)
	
	sfx_wave_start = _create_sfx([
		sfx_path + "wave_start.mp3",
		sfx_path + "start.mp3",
		sfx_path + "initialize.mp3"
	], SFX_VOLUME)
	
	sfx_wave_transition = _create_sfx([
		sfx_path + "wave_transition.mp3",
		sfx_path + "transition.mp3",
		sfx_path + "process.mp3"
	], SFX_VOLUME - 2.0)
	
	# ===== CIA TRIAD SPECIFIC =====
	print("\n🔐 CIA Triad Damage Sounds:")
	sfx_confidentiality_damage = _create_sfx([
		sfx_path + "confidentiality_damage.mp3",
		sfx_path + "data_leak.mp3",
		sfx_path + "leak.mp3"
	], SFX_VOLUME)
	
	sfx_integrity_damage = _create_sfx([
		sfx_path + "integrity_damage.mp3",
		sfx_path + "corruption.mp3",
		sfx_path + "glitch.mp3"
	], SFX_VOLUME)
	
	sfx_availability_damage = _create_sfx([
		sfx_path + "availability_damage.mp3",
		sfx_path + "disconnect.mp3",
		sfx_path + "offline.mp3"
	], SFX_VOLUME)
	
	# ===== SPECIAL EFFECTS =====
	print("\n✨ Special Effects:")
	sfx_zone_highlight = _create_sfx([
		sfx_path + "zone_highlight.mp3",
		sfx_path + "highlight.mp3",
		sfx_path + "chime.mp3"
	], SFX_VOLUME - 3.0)
	
	sfx_zone_shake = _create_sfx([
		sfx_path + "zone_shake.mp3",
		sfx_path + "shake.mp3",
		sfx_path + "clang.mp3"
	], SFX_VOLUME)
	
	sfx_score_increase = _create_sfx([
		sfx_path + "score_increase.mp3",
		sfx_path + "points.mp3",
		sfx_path + "coin.mp3"
	], SFX_VOLUME - 5.0)
	
	sfx_victory_fanfare = _create_sfx([
		sfx_path + "victory_fanfare.mp3",
		sfx_path + "victory.mp3",
		sfx_path + "win.mp3"
	], SFX_VOLUME + 5.0)
	
	# ===== FEEDBACK POPUPS =====
	print("\n💬 Feedback Popup Sounds:")
	sfx_feedback_appear = _create_sfx([
		sfx_path + "feedback_appear.mp3",
		sfx_path + "popup.mp3",
		sfx_path + "notify.mp3"
	], SFX_VOLUME - 3.0)
	
	sfx_feedback_disappear = _create_sfx([
		sfx_path + "feedback_disappear.mp3",
		sfx_path + "dismiss.mp3",
		sfx_path + "close.mp3"
	], SFX_VOLUME - 5.0)
	
	# ===== BACKGROUND MUSIC =====
	print("\n🎵 Background Music:")
	music_gameplay = _create_music([
		music_path + "gameplay.ogg",
		music_path + "gameplay.mp3",
		music_path + "game.ogg"
	], MUSIC_VOLUME)
	
	music_intense = _create_music([
		music_path + "intense.ogg",
		music_path + "intense.mp3",
		music_path + "boss.ogg"
	], MUSIC_VOLUME + 2.0)
	
	music_victory = _create_music([
		music_path + "victory.ogg",
		music_path + "victory.mp3",
		music_path + "win.ogg"
	], MUSIC_VOLUME + 4.0)
	
	ambient_lab = _create_music([
		music_path + "lab_ambient_loop.ogg",
		music_path + "ambient.ogg",
		music_path + "background.ogg"
	], AMBIENT_VOLUME)
	
	print("===============================\n")


# ============================================
# AUDIO PLAYER CREATION
# ============================================
func _create_sfx(file_paths: Array, volume_db: float) -> AudioStreamPlayer:
	"""Create AudioStreamPlayer for sound effects"""
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("  ✅ " + file_path.get_file())
				return player
	
	print("  ⚠️  Optional: " + file_paths[0].get_file())
	return player


func _create_music(file_paths: Array, volume_db: float) -> AudioStreamPlayer:
	"""Create looping AudioStreamPlayer for music"""
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				
				# Enable looping
				if audio_stream is AudioStreamOggVorbis:
					audio_stream.loop = true
				elif audio_stream is AudioStreamMP3:
					audio_stream.loop = true
				
				print("  ✅ " + file_path.get_file())
				return player
	
	print("  ⚠️  Optional: " + file_paths[0].get_file())
	return player


# ============================================
# PLAY SOUND EFFECTS
# ============================================
func play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0) -> void:
	"""Play a sound effect with optional pitch variation"""
	if not sfx_player or not sfx_player.stream:
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = 1.0
	
	sfx_player.play()


# ============================================
# SPECIFIC SOUND FUNCTIONS
# ============================================

# UI Sounds
func play_ui_click() -> void:
	play_sfx(sfx_ui_click)

func play_ui_hover() -> void:
	play_sfx(sfx_ui_hover)

func play_page_turn() -> void:
	play_sfx(sfx_page_turn)

func play_tutorial_complete() -> void:
	play_sfx(sfx_tutorial_complete)

# Card Interactions
func play_card_spawn() -> void:
	play_sfx(sfx_card_spawn, 0.05)

func play_card_pickup() -> void:
	play_sfx(sfx_card_pickup)

func play_card_drag_start() -> void:
	"""Start playing drag sound (looping)"""
	if sfx_card_drag and sfx_card_drag.stream and not is_dragging_card:
		is_dragging_card = true
		# Note: For looping drag sound, you'd need to set up the audio file to loop
		# or call this repeatedly in _process while dragging

func play_card_drag_stop() -> void:
	"""Stop drag sound"""
	if sfx_card_drag and sfx_card_drag.playing:
		is_dragging_card = false
		var tween = create_tween()
		tween.tween_property(sfx_card_drag, "volume_db", -40.0, 0.2)
		tween.tween_callback(sfx_card_drag.stop)
		tween.tween_callback(func(): sfx_card_drag.volume_db = SFX_VOLUME - 8.0)

func play_card_hover_zone() -> void:
	play_sfx(sfx_card_hover_zone)

func play_card_timeout() -> void:
	play_sfx(sfx_card_timeout)

# Correct Answers
func play_correct_data() -> void:
	play_sfx(sfx_correct_data, 0.08)

func play_correct_network() -> void:
	play_sfx(sfx_correct_network, 0.08)

func play_combo_sound(combo_count: int) -> void:
	"""Play appropriate combo sound based on streak"""
	if combo_count >= 10:
		play_sfx(sfx_combo_10, 0.1)
		print("[Audio] 🔥🔥🔥 MEGA COMBO x%d!" % combo_count)
	elif combo_count >= 5:
		play_sfx(sfx_combo_5, 0.08)
		print("[Audio] 🔥🔥 COMBO x%d!" % combo_count)
	elif combo_count >= 2:
		play_sfx(sfx_combo_2, 0.05)
		print("[Audio] 🔥 Combo x%d" % combo_count)

# Wrong Answers
func play_wrong_drop() -> void:
	play_sfx(sfx_wrong_drop)

func play_system_damage() -> void:
	play_sfx(sfx_system_damage, 0.05)

func play_shield_break() -> void:
	play_sfx(sfx_shield_break)

func play_game_over() -> void:
	play_sfx(sfx_game_over)

# Wave Progress
func play_wave_complete() -> void:
	play_sfx(sfx_wave_complete)

func play_wave_start() -> void:
	play_sfx(sfx_wave_start)

func play_wave_transition() -> void:
	play_sfx(sfx_wave_transition)

# CIA Triad Damage
func play_cia_damage(cia_type: String) -> void:
	"""Play specific CIA triad damage sound"""
	match cia_type:
		"C":
			play_sfx(sfx_confidentiality_damage)
		"I":
			play_sfx(sfx_integrity_damage)
		"A":
			play_sfx(sfx_availability_damage)
		_:
			play_sfx(sfx_system_damage)

# Special Effects
func play_zone_highlight() -> void:
	play_sfx(sfx_zone_highlight)

func play_zone_shake() -> void:
	play_sfx(sfx_zone_shake)

func play_score_increase() -> void:
	play_sfx(sfx_score_increase, 0.15)

func play_victory_fanfare() -> void:
	play_sfx(sfx_victory_fanfare)

# Feedback Popups
func play_feedback_appear() -> void:
	play_sfx(sfx_feedback_appear)

func play_feedback_disappear() -> void:
	play_sfx(sfx_feedback_disappear)


# ============================================
# MUSIC CONTROL
# ============================================
func play_music(music_type: String) -> void:
	"""Play background music with crossfade"""
	var target_music: AudioStreamPlayer = null
	
	match music_type:
		"gameplay":
			target_music = music_gameplay
		"intense":
			target_music = music_intense
		"victory":
			target_music = music_victory
		"ambient":
			target_music = ambient_lab
	
	if not target_music:
		print("[Audio] ⚠️  Unknown music type: " + music_type)
		return
	
	# If same music is already playing, do nothing
	if target_music == current_music and current_music and current_music.playing:
		return
	
	# Crossfade
	await _crossfade_music(current_music, target_music)
	current_music = target_music


func _crossfade_music(old_music: AudioStreamPlayer, new_music: AudioStreamPlayer) -> void:
	"""Smooth crossfade between music tracks"""
	
	# Fade out old music
	if old_music and old_music.playing:
		var fade_out = create_tween()
		fade_out.tween_property(old_music, "volume_db", MUSIC_FADE_OUT_VOLUME, MUSIC_FADE_DURATION)
		await fade_out.finished
		old_music.stop()
		# Reset volume for next time
		if old_music == music_gameplay:
			old_music.volume_db = MUSIC_VOLUME
		elif old_music == music_intense:
			old_music.volume_db = MUSIC_VOLUME + 2.0
		elif old_music == music_victory:
			old_music.volume_db = MUSIC_VOLUME + 4.0
		elif old_music == ambient_lab:
			old_music.volume_db = AMBIENT_VOLUME
	
	# Fade in new music
	if new_music and new_music.stream:
		var target_volume = new_music.volume_db
		new_music.volume_db = MUSIC_FADE_OUT_VOLUME
		new_music.play()
		
		var fade_in = create_tween()
		fade_in.tween_property(new_music, "volume_db", target_volume, MUSIC_FADE_DURATION)
		
		print("[Audio] 🎵 Now playing: " + new_music.stream.resource_path.get_file())


func stop_all_music() -> void:
	"""Stop all music with fade out"""
	for music in [music_gameplay, music_intense, music_victory, ambient_lab]:
		if music and music.playing:
			var tween = create_tween()
			tween.tween_property(music, "volume_db", MUSIC_FADE_OUT_VOLUME, 0.5)
			tween.tween_callback(music.stop)
	
	current_music = null


func pause_music() -> void:
	"""Pause current music"""
	if current_music and current_music.playing:
		current_music.stream_paused = true


func resume_music() -> void:
	"""Resume current music"""
	if current_music:
		current_music.stream_paused = false


# ============================================
# VOLUME CONTROL
# ============================================
func set_master_volume(volume_db: float) -> void:
	"""Set master volume"""
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, volume_db)


func mute_all() -> void:
	"""Mute all audio"""
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, true)


func unmute_all() -> void:
	"""Unmute all audio"""
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, false)


# ============================================
# HELPER FUNCTIONS
# ============================================
func is_music_playing() -> bool:
	"""Check if any music is currently playing"""
	return current_music != null and current_music.playing


func get_current_music_name() -> String:
	"""Get name of currently playing music"""
	if not current_music or not current_music.stream:
		return "None"
	return current_music.stream.resource_path.get_file()