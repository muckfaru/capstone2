extends Control

# ============================================
# NETWORK DEFENSE SIMULATOR - FIXED AUDIO
# ============================================

enum GamePhase {
	INTRO,
	IP_DEFENSE,
	PORT_SCANNER,
	PROTOCOL_GUARDIAN,
	FINAL_BOSS,
	VICTORY
}

enum ConnectionType {
	SAFE,
	THREAT
}

@onready var point_lights = [
	$TextureRect/PointLight2D,
	$TextureRect/PointLight2D2,
	$TextureRect/PointLight2D3,
	$TextureRect/PointLight2D4
]

# ============================================
# AUDIO PLAYERS - Dynamically created
# ============================================
var sfx_correct: AudioStreamPlayer
var sfx_wrong: AudioStreamPlayer
var sfx_combo_low: AudioStreamPlayer
var sfx_combo_medium: AudioStreamPlayer
var sfx_combo_high: AudioStreamPlayer
var sfx_shield_lost: AudioStreamPlayer
var sfx_powerup: AudioStreamPlayer
var sfx_phase_complete: AudioStreamPlayer
var sfx_game_over: AudioStreamPlayer
var sfx_victory: AudioStreamPlayer
var sfx_ui_click: AudioStreamPlayer
var music_gameplay: AudioStreamPlayer
var music_boss: AudioStreamPlayer
var music_victory: AudioStreamPlayer

# Background Music Settings - FIXED
const BGM_NORMAL_VOLUME := -20.0  # Balanced volume
const BGM_FADE_OUT_VOLUME := -40.0
const BGM_CROSSFADE_DURATION := 1.5

# Track current playing music
var current_music: AudioStreamPlayer = null

var current_phase = GamePhase.INTRO
var score := 0
var combo := 0
var multiplier := 1.0
var shields := 5
var max_shields := 5
var xp_earned := 0
var wave_number := 1
var connections_handled := 0
var time = 0.0
var base_energy = 1.0
var flicker_speed = 5.0
var flicker_amount = 0.2

# Power-ups
var hint_tokens := 3
var time_freeze_available := true
var auto_filter_charges := 2

# Timers
var phase_timer := 0.0
var spawn_timer := 0.0
var spawn_interval := 2.0
var is_paused := false
var is_frozen := false
var freeze_duration := 0.0
var is_game_over := false

# Active connections on screen
var active_connections := []

@onready var quit_btn: Button = $TextureRect/Quit

# Challenge data
var ip_challenges := [
	{"text": "192.168.1.100", "type": ConnectionType.SAFE, "category": "private", "hint": "192.168 = Home network"},
	{"text": "10.0.0.50", "type": ConnectionType.SAFE, "category": "private", "hint": "10.x = Company network"},
	{"text": "45.33.32.156:4444", "type": ConnectionType.THREAT, "category": "backdoor", "hint": "Port 4444 = BACKDOOR!"},
	{"text": "172.16.5.20", "type": ConnectionType.SAFE, "category": "private", "hint": "172.16-31 = Private"},
	{"text": "8.8.8.8:53", "type": ConnectionType.SAFE, "category": "dns", "hint": "Google DNS"},
	{"text": "203.45.67.89:31337", "type": ConnectionType.THREAT, "category": "hacker", "hint": "31337 = Elite hacker port"},
]

var port_challenges := [
	{"text": "192.168.1.100:80", "type": ConnectionType.SAFE, "hint": "Port 80 = HTTP"},
	{"text": "45.33.32.156:443", "type": ConnectionType.SAFE, "hint": "Port 443 = HTTPS"},
	{"text": "203.45.12.34:4444", "type": ConnectionType.THREAT, "hint": "4444 = TROJAN"},
	{"text": "8.8.8.8:22", "type": ConnectionType.SAFE, "hint": "Port 22 = SSH"},
	{"text": "45.67.89.12:1337", "type": ConnectionType.THREAT, "hint": "1337 = Malware"},
]

var protocol_challenges := [
	{"text": "HTTPS", "type": ConnectionType.SAFE, "hint": "Encrypted web"},
	{"text": "HTTP", "type": ConnectionType.THREAT, "hint": "No encryption!"},
	{"text": "SSH", "type": ConnectionType.SAFE, "hint": "Secure shell"},
	{"text": "FTP", "type": ConnectionType.THREAT, "hint": "Plain text transfer"},
	{"text": "Telnet", "type": ConnectionType.THREAT, "hint": "Sends passwords plain!"},
]

# Node references
@onready var phase_label: Label = $UI/TopBar/PhaseLabel
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var combo_label: Label = $UI/TopBar/ComboLabel
@onready var shield_container: HBoxContainer = $UI/TopBar/ShieldContainer
@onready var timer_label: Label = $UI/TopBar/TimerLabel

@onready var connection_spawn: Node2D = $GameArea/ConnectionSpawn
@onready var allow_zone: Area2D = $GameArea/AllowZone
@onready var block_zone: Area2D = $GameArea/BlockZone

@onready var hint_button: Button = $UI/PowerUps/HintButton
@onready var freeze_button: Button = $UI/PowerUps/FreezeButton
@onready var auto_button: Button = $UI/PowerUps/AutoButton

@onready var intro_panel: Panel = $UI/IntroPanel
@onready var victory_panel: Panel = $UI/VictoryPanel

# Preload connection scene
const CONNECTION_SCENE = preload("res://scene/network_connection.tscn")

# Debug
var debug_mode := true


func _ready() -> void:
	print("🎮 Network Defense Simulator - FIXED Audio System Loading...")
	
	# Fix audio bus first
	_fix_audio_bus()
	
	# Load all audio files
	_load_audio_files()
	
	if debug_mode:
		print("DEBUG MODE: Press SPACE to manually spawn a connection")
	
	# Connect signals
	allow_zone.area_entered.connect(_on_allow_zone_entered)
	block_zone.area_entered.connect(_on_block_zone_entered)
	quit_btn.pressed.connect(_on_quit_pressed)
	hint_button.pressed.connect(_use_hint)
	freeze_button.pressed.connect(_use_time_freeze)
	auto_button.pressed.connect(_use_auto_filter)
	
	# Connect UI button sounds
	_setup_button_sounds()
	
	_update_ui()
	_start_phase(GamePhase.INTRO)
	
	# Start background music with delay to ensure everything is loaded
	await get_tree().create_timer(0.1).timeout
	_play_music_for_phase(current_phase)


# ============================================
# AUDIO BUS FIX
# ============================================
func _fix_audio_bus() -> void:
	"""Fix the Master audio bus volume if it's too low"""
	var master_bus_index = AudioServer.get_bus_index("Master")
	var current_volume = AudioServer.get_bus_volume_db(master_bus_index)
	
	print("[DEBUG] Current Master bus volume: ", current_volume, " dB")
	
	if current_volume < -10.0:
		print("[WARNING] Master bus volume is TOO LOW (", current_volume, " dB)")
		print("[FIX] Setting Master bus to 0 dB (normal volume)")
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)
		print("[DEBUG] New Master bus volume: ", AudioServer.get_bus_volume_db(master_bus_index), " dB")


# ============================================
# LOAD ALL AUDIO FILES - FIXED
# ============================================
func _load_audio_files() -> void:
	print("\n=== LOADING AUDIO FILES (FIXED) ===")
	
	var sfx_path = "res://asset/minigamessoundsfx/"
	var music_path = "res://asset/minigamessoundsfx/"
	
	# CORE Sound Effects
	sfx_correct = _create_audio_player([
		sfx_path + "chrisiex1-correct-156911.mp3",
		sfx_path + "correct.mp3"
	], "Master", -5.0)
	
	sfx_wrong = _create_audio_player([
		sfx_path + "wrong.mp3",
		sfx_path + "error.mp3"
	], "Master", -5.0)
	
	sfx_ui_click = _create_audio_player([
		sfx_path + "ui_clicka.mp3",
		sfx_path + "click.mp3"
	], "Master", -8.0)
	
	# COMBO Sound Effects
	print("\n🎵 Loading COMBO sound tiers:")
	
	sfx_combo_low = _create_audio_player([
		sfx_path + "combo_low.mp3",
		sfx_path + "combo1.mp3",
		sfx_path + "combo.mp3"
	], "Master", 0.0)
	
	sfx_combo_medium = _create_audio_player([
		sfx_path + "combo_medium.mp3",
		sfx_path + "combo2.mp3",
		sfx_path + "combo.mp3"
	], "Master", 2.0)
	
	sfx_combo_high = _create_audio_player([
		sfx_path + "combo_high.mp3",
		sfx_path + "combo3.mp3",
		sfx_path + "combo_max.mp3",
		sfx_path + "combo.mp3"
	], "Master", 3.0)
	
	# Optional SFX
	sfx_shield_lost = _create_audio_player([
		sfx_path + "shield_lost.mp3",
		sfx_path + "damage.mp3"
	], "Master", -5.0)
	
	sfx_powerup = _create_audio_player([
		sfx_path + "powerup.mp3",
		sfx_path + "power.mp3"
	], "Master", -5.0)
	
	sfx_phase_complete = _create_audio_player([
		sfx_path + "phase_complete.mp3",
		sfx_path + "level_up.mp3"
	], "Master", 0.0)
	
	sfx_game_over = _create_audio_player([
		sfx_path + "game_over.mp3",
		sfx_path + "fail.mp3"
	], "Master", 0.0)
	
	sfx_victory = _create_audio_player([
		sfx_path + "victory.mp3",
		sfx_path + "win.mp3"
	], "Master", 2.0)
	
	# ============================================
	# MUSIC - FIXED LOOPING SYSTEM
	# ============================================
	print("\n🎼 Loading BACKGROUND MUSIC:")
	
	music_gameplay = _create_looping_music([
		music_path + "gameplay.ogg",
		music_path + "gameplay.mp3"
	], BGM_NORMAL_VOLUME)
	
	music_boss = _create_looping_music([
		music_path + "boss.ogg",
		music_path + "boss.mp3"
	], BGM_NORMAL_VOLUME + 2.0)
	
	music_victory = _create_looping_music([
		music_path + "victory.ogg",
		music_path + "victory.mp3"
	], BGM_NORMAL_VOLUME + 4.0)
	
	print("===========================\n")


func _create_audio_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	"""Create AudioStreamPlayer for SFX"""
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("✅ Loaded: " + file_path.get_file())
				return player
	
	print("⚠️  Optional sound not found: " + file_paths[0].get_file())
	return player


func _create_looping_music(file_paths: Array, volume_db: float) -> AudioStreamPlayer:
	"""Create AudioStreamPlayer for LOOPING MUSIC - FIXED"""
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				
				# CRITICAL FIX: Enable looping for different audio formats
				if audio_stream is AudioStreamOggVorbis:
					audio_stream.loop = true
					print("✅ Loaded LOOPING OGG: " + file_path.get_file())
				elif audio_stream is AudioStreamMP3:
					audio_stream.loop = true
					print("✅ Loaded LOOPING MP3: " + file_path.get_file())
				else:
					print("⚠️  WARNING: Unknown audio format for: " + file_path.get_file())
				
				# Connect to finished signal for manual looping fallback
				if not audio_stream is AudioStreamOggVorbis and not audio_stream is AudioStreamMP3:
					player.finished.connect(func(): 
						if player == current_music:
							player.play()
					)
				
				return player
	
	print("⚠️  Music not found: " + file_paths[0].get_file())
	return player


# ============================================
# MUSIC PLAYBACK - FIXED CROSSFADE SYSTEM
# ============================================
func _play_music_for_phase(phase: GamePhase) -> void:
	"""Switch background music with smooth crossfade - FIXED"""
	print("[MUSIC] Switching to phase: ", GamePhase.keys()[phase])
	
	# Determine target music
	var target_music: AudioStreamPlayer = null
	match phase:
		GamePhase.INTRO, GamePhase.IP_DEFENSE, GamePhase.PORT_SCANNER, GamePhase.PROTOCOL_GUARDIAN:
			target_music = music_gameplay
		GamePhase.FINAL_BOSS:
			target_music = music_boss
		GamePhase.VICTORY:
			target_music = music_victory
	
	# If same music is already playing, do nothing
	if target_music == current_music and current_music and current_music.playing:
		print("[MUSIC] Already playing correct music, skipping")
		return
	
	# Crossfade to new music
	await _crossfade_music(current_music, target_music)
	current_music = target_music


func _crossfade_music(old_music: AudioStreamPlayer, new_music: AudioStreamPlayer) -> void:
	"""Smooth crossfade between two music tracks - FIXED"""
	
	# Fade out old music
	if old_music and old_music.playing:
		print("[MUSIC] Fading out old track...")
		var fade_out = create_tween()
		fade_out.tween_property(old_music, "volume_db", BGM_FADE_OUT_VOLUME, BGM_CROSSFADE_DURATION)
		await fade_out.finished
		old_music.stop()
		old_music.volume_db = BGM_NORMAL_VOLUME  # Reset for next use
	
	# Start new music
	if new_music and new_music.stream:
		print("[MUSIC] Fading in new track: ", new_music.stream.resource_path.get_file())
		
		# Start at low volume
		var target_volume = new_music.volume_db
		new_music.volume_db = BGM_FADE_OUT_VOLUME
		new_music.play()
		
		# Fade in
		var fade_in = create_tween()
		fade_in.tween_property(new_music, "volume_db", target_volume, BGM_CROSSFADE_DURATION)
		
		print("[MUSIC] ✅ Now playing: ", new_music.stream.resource_path.get_file())
		print("[MUSIC] Volume: ", target_volume, " dB | Looping: ", _is_looping(new_music.stream))


func _is_looping(stream) -> bool:
	"""Check if audio stream is set to loop"""
	if stream is AudioStreamOggVorbis:
		return stream.loop
	elif stream is AudioStreamMP3:
		return stream.loop
	return false


# ============================================
# SOUND HELPER FUNCTIONS
# ============================================
func _setup_button_sounds() -> void:
	"""Connect click sounds to all buttons"""
	var buttons = [
		hint_button, 
		freeze_button, 
		auto_button, 
		quit_btn,
		intro_panel.get_node("VBox/StartButton"),
		victory_panel.get_node("VBox/ButtonContainer/RetryButton"),
		victory_panel.get_node("VBox/ButtonContainer/FinishButton")
	]
	
	for button in buttons:
		if button:
			button.pressed.connect(_on_button_click)


func _on_button_click() -> void:
	"""Play click sound"""
	_play_sfx(sfx_ui_click)


func _play_combo_sound(combo_count: int) -> void:
	"""Play combo sound based on current combo level"""
	var sfx_to_play: AudioStreamPlayer = null
	var pitch_var := 0.0
	
	if combo_count >= 10:
		sfx_to_play = sfx_combo_high
		pitch_var = 0.15
		print("[COMBO SFX] 🔥🔥🔥 MEGA COMBO x%d!" % combo_count)
	elif combo_count >= 5:
		sfx_to_play = sfx_combo_medium
		pitch_var = 0.10
		print("[COMBO SFX] 🔥🔥 COMBO x%d!" % combo_count)
	elif combo_count >= 3:
		sfx_to_play = sfx_combo_low
		pitch_var = 0.05
		print("[COMBO SFX] 🔥 Combo x%d" % combo_count)
	else:
		return
	
	# Add pitch variation based on exact combo
	var extra_pitch = (combo_count % 5) * 0.02
	_play_sfx(sfx_to_play, pitch_var, 1.0 + extra_pitch)


func _play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0, base_pitch: float = 1.0) -> void:
	"""Play a sound effect with optional pitch variation"""
	if not sfx_player or not sfx_player.stream:
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = base_pitch
	
	sfx_player.play()


# ============================================
# CONNECTION DRAG EVENTS
# ============================================
func on_connection_drag_started() -> void:
	pass


func on_connection_drag_ended() -> void:
	pass


func on_connection_entered_zone(zone_name: String) -> void:
	pass


# ============================================
# GAME LOGIC
# ============================================

func _on_quit_pressed() -> void:
	"""Return to mode selection with music fadeout"""
	print("[Network Defense] Quit button pressed...")
	
	if current_music and current_music.playing:
		var tween = create_tween()
		tween.tween_property(current_music, "volume_db", BGM_FADE_OUT_VOLUME, 0.5)
		await tween.finished
		current_music.stop()
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if debug_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("DEBUG: Manually spawning connection")
			_spawn_connection()


func _process(delta: float) -> void:
	# Flicker effect for PointLight2D
	time += delta * flicker_speed
	var noise = sin(time) * cos(time * 1.3) * sin(time * 1.7)
	
	for light in point_lights:
		if light:
			light.energy = base_energy + (noise * flicker_amount)
	
	if is_paused or is_game_over:
		return
	
	if is_frozen:
		freeze_duration -= delta
		if freeze_duration <= 0:
			is_frozen = false
			_resume_connections()
		return
	
	phase_timer += delta
	_update_timer_display()
	
	if current_phase in [GamePhase.IP_DEFENSE, GamePhase.PORT_SCANNER, GamePhase.PROTOCOL_GUARDIAN, GamePhase.FINAL_BOSS]:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_spawn_connection()


func _start_phase(phase: GamePhase) -> void:
	current_phase = phase
	phase_timer = 0.0
	spawn_timer = 0.0
	
	for conn in active_connections:
		if is_instance_valid(conn):
			conn.queue_free()
	active_connections.clear()
	
	if phase != GamePhase.INTRO and phase != GamePhase.VICTORY:
		_play_sfx(sfx_phase_complete)
	
	_play_music_for_phase(phase)
	
	match phase:
		GamePhase.INTRO:
			_show_intro()
		GamePhase.IP_DEFENSE:
			phase_label.text = "PHASE 1: IP Defense"
			spawn_interval = 2.5
			intro_panel.hide()
		GamePhase.PORT_SCANNER:
			phase_label.text = "PHASE 2: Port Scanner"
			spawn_interval = 2.0
			wave_number = 2
		GamePhase.PROTOCOL_GUARDIAN:
			phase_label.text = "PHASE 3: Protocol Guardian"
			spawn_interval = 1.8
			wave_number = 3
		GamePhase.FINAL_BOSS:
			phase_label.text = "FINAL PHASE: APT Attack!"
			spawn_interval = 1.2
			wave_number = 4
		GamePhase.VICTORY:
			_show_victory()


func _show_intro() -> void:
	intro_panel.show()
	var intro_text = intro_panel.get_node("VBox/IntroText")
	intro_text.text = """Your company's network is under attack!
The security team is offline.

YOU are the last line of defense.

🎯 MISSION:
• ALLOW safe connections (drag to green zone)
• BLOCK threats (drag to red zone)
• Protect your shields
• Build combos for bonus points

Press START to defend the network!"""


func _show_victory() -> void:
	victory_panel.show()
	var victory_text = victory_panel.get_node("VBox/VictoryText")
	var title_label = victory_panel.get_node("VBox/TitleLabel")
	var retry_button = victory_panel.get_node("VBox/ButtonContainer/RetryButton")
	var finish_button = victory_panel.get_node("VBox/ButtonContainer/FinishButton")
	
	_play_sfx(sfx_victory)
	
	retry_button.visible = true
	finish_button.visible = true
	
	title_label.text = "MISSION COMPLETE"
	title_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	
	xp_earned = score + (combo * 10)
	if shields == max_shields:
		xp_earned += 100
	
	var star_rating = _calculate_stars()
	var stars = "⭐".repeat(star_rating)
	
	victory_text.text = """🎉 NETWORK SECURED! 🎉

%s

Final Score: %d
Max Combo: %d
Shields Remaining: %d/%d

XP Earned: +%d XP

You've mastered network defense!""" % [stars, score, combo, shields, max_shields, xp_earned]


func _show_game_over() -> void:
	victory_panel.show()
	var victory_text = victory_panel.get_node("VBox/VictoryText")
	var title_label = victory_panel.get_node("VBox/TitleLabel")
	var retry_button = victory_panel.get_node("VBox/ButtonContainer/RetryButton")
	var finish_button = victory_panel.get_node("VBox/ButtonContainer/FinishButton")
	
	_play_sfx(sfx_game_over)
	
	retry_button.visible = true
	finish_button.visible = false
	
	title_label.text = "NETWORK BREACHED!"
	title_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	
	var star_rating = _calculate_stars()
	var stars = "⭐".repeat(star_rating) if star_rating > 0 else "💔"
	
	victory_text.text = """🚨 SHIELDS DEPLETED 🚨

%s

Final Score: %d
Max Combo: %d
Connections Handled: %d

The network has been compromised.
Try again to improve your defense!""" % [stars, score, combo, connections_handled]


func _calculate_stars() -> int:
	if shields >= 5 and combo >= 10:
		return 3
	elif shields >= 3 and combo >= 5:
		return 2
	else:
		return 1


func _spawn_connection() -> void:
	var challenge_data
	match current_phase:
		GamePhase.IP_DEFENSE:
			challenge_data = ip_challenges[randi() % ip_challenges.size()]
		GamePhase.PORT_SCANNER:
			challenge_data = port_challenges[randi() % port_challenges.size()]
		GamePhase.PROTOCOL_GUARDIAN:
			challenge_data = protocol_challenges[randi() % protocol_challenges.size()]
		GamePhase.FINAL_BOSS:
			var all_challenges = ip_challenges + port_challenges + protocol_challenges
			challenge_data = all_challenges[randi() % all_challenges.size()]
		_:
			if debug_mode:
				challenge_data = ip_challenges[0]
			else:
				return
	
	var connection = CONNECTION_SCENE.instantiate()
	connection_spawn.add_child(connection)
	
	var spawn_x = randf_range(-200, 200)
	connection.position = Vector2(spawn_x, -50)
	
	connection.set_data(challenge_data)
	connection.destroyed.connect(_on_connection_destroyed)
	
	if connection.has_signal("drag_started"):
		connection.drag_started.connect(on_connection_drag_started)
	if connection.has_signal("drag_ended"):
		connection.drag_ended.connect(on_connection_drag_ended)
	
	active_connections.append(connection)
	
	if current_phase != GamePhase.INTRO:
		connections_handled += 1
		if connections_handled >= 10:
			connections_handled = 0
			_advance_phase()


func _advance_phase() -> void:
	match current_phase:
		GamePhase.IP_DEFENSE:
			_start_phase(GamePhase.PORT_SCANNER)
		GamePhase.PORT_SCANNER:
			_start_phase(GamePhase.PROTOCOL_GUARDIAN)
		GamePhase.PROTOCOL_GUARDIAN:
			_start_phase(GamePhase.FINAL_BOSS)
		GamePhase.FINAL_BOSS:
			_start_phase(GamePhase.VICTORY)


func _on_allow_zone_entered(area: Area2D) -> void:
	var connection = area
	if not is_instance_valid(connection):
		return
	
	if connection.has_method("is_dragging"):
		if not connection.is_dragging():
			return
		
		_process_decision(connection, "allow")


func _on_block_zone_entered(area: Area2D) -> void:
	var connection = area
	if not is_instance_valid(connection):
		return
	
	if connection.has_method("is_dragging"):
		if not connection.is_dragging():
			return
		
		_process_decision(connection, "block")


func _process_decision(connection, decision: String) -> void:
	if not is_instance_valid(connection):
		return
	
	var is_correct = false
	
	if decision == "allow" and connection.connection_type == ConnectionType.SAFE:
		is_correct = true
	elif decision == "block" and connection.connection_type == ConnectionType.THREAT:
		is_correct = true
	
	var conn_position = connection.global_position
	
	if is_correct:
		_handle_correct(conn_position)
	else:
		_handle_wrong(conn_position)
	
	active_connections.erase(connection)
	connection.call_deferred("queue_free")


func _handle_correct(position: Vector2) -> void:
	combo += 1
	
	if combo >= 10:
		multiplier = 3.0
	elif combo >= 5:
		multiplier = 2.0
	elif combo >= 3:
		multiplier = 1.5
	else:
		multiplier = 1.0
	
	var points = int(10 * multiplier)
	score += points
	
	if combo >= 3:
		_play_combo_sound(combo)
	else:
		_play_sfx(sfx_correct, 0.1)
	
	_show_floating_text(position, "+%d" % points, Color.GREEN)
	_play_success_effect(position)
	
	_update_ui()


func _handle_wrong(position: Vector2) -> void:
	combo = 0
	multiplier = 1.0
	shields -= 1
	
	_play_sfx(sfx_wrong)
	await get_tree().create_timer(0.1).timeout
	_play_sfx(sfx_shield_lost)
	
	_show_floating_text(position, "BREACH!", Color.RED)
	_play_error_effect(position)
	_screen_shake()
	
	_update_ui()
	
	if shields <= 0:
		_game_over()


func _game_over() -> void:
	print("Game Over - No shields remaining")
	is_game_over = true
	
	for conn in active_connections:
		if is_instance_valid(conn) and conn.has_method("freeze"):
			conn.freeze()
	
	_show_game_over()


func _show_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.global_position = pos
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", pos.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _play_success_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.color = Color.GREEN
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


func _play_error_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.color = Color.RED
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.initial_velocity_min = 150
	particles.initial_velocity_max = 250
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


func _screen_shake() -> void:
	var original_pos = position
	var tween = create_tween()
	for i in range(4):
		tween.tween_property(self, "position", original_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)


func _use_hint() -> void:
	if hint_tokens <= 0 or is_game_over:
		return
	
	hint_tokens -= 1
	_play_sfx(sfx_powerup)
	
	if active_connections.size() > 0:
		var conn = active_connections[0]
		if is_instance_valid(conn) and conn.has_method("show_hint"):
			conn.show_hint()
	_update_ui()


func _use_time_freeze() -> void:
	if not time_freeze_available or is_game_over:
		return
	
	time_freeze_available = false
	is_frozen = true
	freeze_duration = 5.0
	
	_play_sfx(sfx_powerup)
	
	for conn in active_connections:
		if is_instance_valid(conn) and conn.has_method("freeze"):
			conn.freeze()
	
	_update_ui()


func _resume_connections() -> void:
	for conn in active_connections:
		if is_instance_valid(conn) and conn.has_method("unfreeze"):
			conn.unfreeze()


func _use_auto_filter() -> void:
	if auto_filter_charges <= 0 or is_game_over:
		return
	
	auto_filter_charges -= 1
	_play_sfx(sfx_powerup)
	
	var handled = 0
	var to_remove = []
	
	for conn in active_connections:
		if is_instance_valid(conn) and conn.connection_type == ConnectionType.SAFE and handled < 3:
			var pos = conn.global_position
			to_remove.append(conn)
			_handle_correct(pos)
			handled += 1
	
	for conn in to_remove:
		active_connections.erase(conn)
		conn.call_deferred("queue_free")
	
	_update_ui()


func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	combo_label.text = "Combo: x%d (%.1fx)" % [combo, multiplier]
	
	for i in range(shield_container.get_child_count()):
		shield_container.get_child(i).queue_free()
	
	for i in range(max_shields):
		var shield_icon = Label.new()
		shield_icon.text = "🛡️" if i < shields else "💔"
		shield_icon.add_theme_font_size_override("font_size", 20)
		shield_container.add_child(shield_icon)
	
	hint_button.text = "💡 %d" % hint_tokens
	hint_button.disabled = hint_tokens <= 0 or is_game_over
	
	freeze_button.text = "⏸️ %s" % ("1" if time_freeze_available else "Used")
	freeze_button.disabled = not time_freeze_available or is_game_over
	
	auto_button.text = "🤖 %d" % auto_filter_charges
	auto_button.disabled = auto_filter_charges <= 0 or is_game_over


func _update_timer_display() -> void:
	var minutes = int(phase_timer) / 60
	var seconds = int(phase_timer) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_connection_destroyed(connection) -> void:
	if not is_instance_valid(connection):
		active_connections.erase(connection)
		return
	
	if connection.connection_type == ConnectionType.THREAT:
		shields -= 1
		combo = 0
		_play_sfx(sfx_shield_lost)
		_update_ui()
	
	active_connections.erase(connection)


func _on_start_button_pressed() -> void:
	_start_phase(GamePhase.IP_DEFENSE)


func _on_retry_button_pressed() -> void:
	victory_panel.hide()
	is_game_over = false
	score = 0
	combo = 0
	multiplier = 1.0
	shields = max_shields
	hint_tokens = 3
	time_freeze_available = true
	auto_filter_charges = 2
	connections_handled = 0
	wave_number = 1
	xp_earned = 0
	
	for conn in active_connections:
		if is_instance_valid(conn):
			conn.queue_free()
	active_connections.clear()
	
	_update_ui()
	_start_phase(GamePhase.IP_DEFENSE)


func _on_finish_button_pressed() -> void:
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.save_tutorial_result("network_defense", xp_earned, xp_earned)
		if tutorial_mgr.has_signal("save_completed"):
			await tutorial_mgr.save_completed
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
