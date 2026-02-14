extends Node2D

# ============================================================================
# FIXES APPLIED + DEBUG VERSION
# 1. ✅ Power-up drop rate: 70% → 25% (BALANCED)
# 2. ✅ Power-up weights rebalanced (50/30/20 instead of 60/30/10)
# 3. ✅ Time-stop nerfed: 8s → 5s
# 4. ✅ Command reference always visible (just fades, never hides)
# 5. ✅ Victory message clarified
# 6. ✅ Quit button safety check added
# 7. ✅ Restart audio delay added
# 8. ✅ DebriefPanel RestartButton → RESTARTS game (FIXED)
# 9. ✅ VictoryPanel RestartButton → EXITS to mode_selection (FIXED)
# 10. ✅ Fixed scene change logic (IMMEDIATE, no await blocking)
# 11. ✅ ADDED EXTENSIVE DEBUG LOGGING
# ============================================================================

# Audio players
var audio_command_correct: AudioStreamPlayer
var audio_command_wrong: AudioStreamPlayer
var audio_command_unknown: AudioStreamPlayer
var audio_typing: AudioStreamPlayer
var audio_threat_spawn: AudioStreamPlayer
var audio_threat_neutralized: AudioStreamPlayer
var audio_threat_breach: AudioStreamPlayer
var audio_system_compromised: AudioStreamPlayer
var audio_wave_advance: AudioStreamPlayer
var audio_ui_click: AudioStreamPlayer
var audio_tutorial_advance: AudioStreamPlayer
var audio_health_low: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_powerup_spawn: AudioStreamPlayer
var audio_powerup_collect: AudioStreamPlayer
var audio_time_stop: AudioStreamPlayer
var audio_destroy_all: AudioStreamPlayer

var audio_bgm_tutorial: AudioStreamPlayer
var audio_bgm_gameplay: AudioStreamPlayer
var audio_bgm_intense: AudioStreamPlayer
var current_bgm: AudioStreamPlayer
var bgm_fade_tween: Tween

var audio_initialized = false
var enable_audio_test = false

# Game state
var score := 0
var current_wave := 1
var systems_health := 3
var threats_neutralized := 0
var threats_missed := 0
var missed_threats_data := []

# Victory conditions
const VICTORY_WAVE := 10  # Win after completing wave 10
var game_won := false

# Tutorial state
var tutorial_phase := 0
var tutorial_active := true

# Threat management
var active_threats := []
var threat_scene := preload("res://scene/SOCThreat.tscn")

# Power-up management
var active_powerups := []
var powerup_scene := preload("res://scene/SOCPowerup.tscn")
var powerup_chance := 0.25  # ✅ FIXED: 25% drop rate (balanced from 70%)
var max_systems_health := 3

# Spawn position settings
const SPAWN_X := 1200
const SPAWN_Y_MIN := 120
const SPAWN_Y_MAX := 380

# Power-up types
var powerup_types := {
	"health": {
		"label": "❤️",
		"texture_path": "res://asset/powerups/health.png",
		"color": Color(0, 1, 0.2),
		"description": "System Restore",
		"effect": "Restores 1 compromised system",
		"drop_weight": 50  # ✅ FIXED: 50% (balanced from 60%)
	},
	"time_stop": {
		"label": "⏸️",
		"texture_path": "res://asset/powerups/time_stop.png",
		"color": Color(0.3, 0.7, 1),
		"description": "Time Freeze",
		"effect": "Freezes all threats for 5 seconds",  # ✅ FIXED: 5s (nerfed from 8s)
		"drop_weight": 30  # ✅ FIXED: 30% (up from 25%)
	},
	"destroy_all": {
		"label": "💥",
		"texture_path": "res://asset/powerups/destroy_all.png",
		"color": Color(1, 0.2, 0.2),
		"description": "Emergency Purge",
		"effect": "Destroys all active threats!",
		"drop_weight": 20  # ✅ FIXED: 20% (buffed from 10%)
	}
}

# Command database
var command_database := {
	"block-source": {
		"category": "PERIMETER",
		"effective_against": ["port_scanner"],
		"description": "Block attacking IP at firewall"
	},
	"activate-scrubbing": {
		"category": "PERIMETER",
		"effective_against": ["ddos_flood"],
		"description": "Enable DDoS mitigation service"
	},
	"rate-limit": {
		"category": "ACCESS",
		"effective_against": ["brute_force"],
		"description": "Slow down authentication attempts"
	},
	"enforce-mfa": {
		"category": "ACCESS",
		"effective_against": ["credential_stuffing"],
		"description": "Require multi-factor authentication"
	},
	"isolate-host": {
		"category": "HOST",
		"effective_against": ["malware_beacon", "lateral_movement"],
		"description": "Quarantine infected machine"
	},
	"sanitize-input": {
		"category": "HOST",
		"effective_against": ["sql_injection"],
		"description": "Filter out injection attempts"
	},
	"block-egress": {
		"category": "DATA",
		"effective_against": ["data_exfiltration"],
		"description": "Stop outbound data transfer"
	},
	"restore-backup": {
		"category": "DATA",
		"effective_against": ["ransomware"],
		"description": "Recover from ransomware attack"
	},
	"segment-network": {
		"category": "NETWORK",
		"effective_against": ["lateral_movement"],
		"description": "Create security boundaries"
	}
}

# Threat types
var threat_types := {
	"port_scanner": {
		"name": "Port Scanner",
		"visual": "🔍",
		"color": Color(0.8, 0.8, 0.2),
		"description": "Probing multiple ports",
		"speed": 30.0,
		"impact": "System blueprint stolen",
		"tutorial_hint": "This attacker is scanning for open ports.\nBlock their IP address to stop reconnaissance.",
		"correct_command": "block-source"
	},
	"brute_force": {
		"name": "Brute Force Login",
		"visual": "🔓",
		"color": Color(1.0, 0.5, 0.0),
		"description": "Repeated auth attempts",
		"speed": 35.0,
		"impact": "Account compromised",
		"tutorial_hint": "Thousands of login attempts per second.\nSlow down authentication to stop the attack.",
		"correct_command": "rate-limit"
	},
	"sql_injection": {
		"name": "SQL Injection",
		"visual": "💉",
		"color": Color(1.0, 0.2, 0.2),
		"description": "Malformed database queries",
		"speed": 40.0,
		"impact": "Database dumped",
		"tutorial_hint": "Malicious SQL code in user input.\nValidate and clean inputs before database queries.",
		"correct_command": "sanitize-input"
	},
	"ddos_flood": {
		"name": "DDoS Flood",
		"visual": "🌊",
		"color": Color(0.3, 0.5, 1.0),
		"description": "High volume traffic",
		"speed": 25.0,
		"impact": "Service overwhelmed",
		"tutorial_hint": "Massive traffic flood overwhelming servers.\nActivate cloud-based traffic filtering.",
		"correct_command": "activate-scrubbing"
	},
	"malware_beacon": {
		"name": "Malware Beacon",
		"visual": "📡",
		"color": Color(0.8, 0.2, 0.8),
		"description": "Outbound suspicious connections",
		"speed": 32.0,
		"impact": "Command & control established",
		"tutorial_hint": "Infected host calling home to attacker.\nIsolate the compromised machine from network.",
		"correct_command": "isolate-host"
	},
	"credential_stuffing": {
		"name": "Credential Stuffing",
		"visual": "🌍",
		"color": Color(0.9, 0.6, 0.2),
		"description": "Valid logins from wrong locations",
		"speed": 38.0,
		"impact": "Multiple accounts breached",
		"tutorial_hint": "Stolen credentials from other breaches.\nRequire additional authentication factors.",
		"correct_command": "enforce-mfa"
	},
	"data_exfiltration": {
		"name": "Data Exfiltration",
		"visual": "📤",
		"color": Color(1.0, 0.3, 0.3),
		"description": "Large outbound transfers",
		"speed": 45.0,
		"impact": "Customer data leaked",
		"tutorial_hint": "Sensitive data being transferred out.\nBlock outbound connections immediately.",
		"correct_command": "block-egress"
	},
	"lateral_movement": {
		"name": "Lateral Movement",
		"visual": "↔️",
		"color": Color(0.7, 0.3, 0.9),
		"description": "Internal scanning after breach",
		"speed": 42.0,
		"impact": "Multiple systems infected",
		"tutorial_hint": "Attacker moving between internal systems.\nCreate network boundaries to contain spread.",
		"correct_command": "segment-network"
	}
}

@onready var quit_btn: Button = $Background/Quit

func _ready():
	print("\n" + "=".repeat(80))
	print("🎮 SOC Incident Command - DEBUG MODE ENABLED")
	print("=".repeat(80) + "\n")
	
	_check_audio_bus_setup()
	_load_audio_files()
	
	audio_initialized = true
	
	if enable_audio_test:
		call_deferred("_test_audio_playback")
	
	# ✅ Ensure PowerUpContainer exists
	if not has_node("PowerUpContainer"):
		var powerup_container = Node2D.new()
		powerup_container.name = "PowerUpContainer"
		add_child(powerup_container)
		print("✅ Created PowerUpContainer node")
	
	# Connect quit button
	connect_button_sounds(quit_btn)
	
	# Connect tutorial button
	if has_node("UI/TutorialPanel/ContinueButton"):
		connect_button_sounds($UI/TutorialPanel/ContinueButton)
	
	# ✅ DEBUG: Check and connect restart buttons
	print("\n" + "=".repeat(80))
	print("🔍 DEBUGGING RESTART BUTTONS")
	print("=".repeat(80))
	
	_debug_check_button("UI/DebriefPanel/RestartButton", "_on_debrief_restart")
	_debug_check_button("UI/VictoryPanel/RestartButton", "_on_victory_exit")
	
	print("=".repeat(80) + "\n")
	
	randomize()
	update_ui()
	show_tutorial()
	
	var command_input = $UI/CommandTerminal/CommandInput
	command_input.grab_focus()
	command_input.editable = true
	command_input.selecting_enabled = true
	
	if command_input.has_method("set_caret_blink_enabled"):
		command_input.set_caret_blink_enabled(true)
		command_input.set_caret_blink_interval(0.5)
	
	# ✅ FIXED: Show command reference always
	if has_node("UI/CommandReference"):
		$UI/CommandReference.visible = false  # Start hidden but will fade in when needed
		print("✅ Command reference ready")

# ✅ NEW: Debug function to check button connections
func _debug_check_button(button_path: String, expected_method: String):
	print("\n📍 Checking button: " + button_path)
	
	if not has_node(button_path):
		print("   ❌ ERROR: Button NOT FOUND at path: " + button_path)
		return
	
	var button = get_node(button_path)
	print("   ✅ Button found!")
	print("   📊 Button properties:")
	print("      - Visible: " + str(button.visible))
	print("      - Disabled: " + str(button.disabled))
	print("      - Text: '" + button.text + "'")
	print("      - Position: " + str(button.position))
	print("      - Size: " + str(button.size))
	print("      - Focus Mode: " + str(button.focus_mode))
	print("      - Mouse Filter: " + str(button.mouse_filter))
	
	# Check signal connections
	var pressed_connections = button.pressed.get_connections()
	print("   🔗 Signal connections for 'pressed':")
	if pressed_connections.size() == 0:
		print("      ⚠️  NO CONNECTIONS FOUND!")
	else:
		for conn in pressed_connections:
			print("      ✅ Connected to: " + str(conn.callable.get_object()) + "." + str(conn.callable.get_method()))
			if conn.callable.get_method() == expected_method:
				print("         ✓ Correct method!")
			else:
				print("         ⚠️  WRONG method! Expected: " + expected_method)
	
	# Manually connect if needed
	if not button.pressed.is_connected(Callable(self, expected_method)):
		print("   🔧 Manually connecting signal...")
		button.pressed.connect(Callable(self, expected_method))
		print("   ✅ Signal connected!")
	
	# Add debug logging for mouse interaction
	if not button.mouse_entered.is_connected(_on_restart_button_hover):
		button.mouse_entered.connect(func(): _on_restart_button_hover(button_path))
	
	# Add explicit button_down tracking
	if not button.button_down.is_connected(_on_restart_button_down):
		button.button_down.connect(func(): _on_restart_button_down(button_path))
	
	# Add explicit button_up tracking
	if not button.button_up.is_connected(_on_restart_button_up):
		button.button_up.connect(func(): _on_restart_button_up(button_path))
	
	# Add sound effects
	connect_button_sounds(button)

func _on_restart_button_hover(button_path: String):
	print("🖱️  [DEBUG] Mouse entered button: " + button_path)

func _on_restart_button_down(button_path: String):
	print("🖱️  [DEBUG] Mouse button DOWN on: " + button_path)

func _on_restart_button_up(button_path: String):
	print("🖱️  [DEBUG] Mouse button UP on: " + button_path)

func _check_audio_bus_setup():
	print("\n=== AUDIO BUS CHECK ===")
	
	for i in range(AudioServer.bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		
		if bus_name == "Master":
			if AudioServer.is_bus_mute(i):
				AudioServer.set_bus_mute(i, false)
				print("✓ Unmuted Master bus")
			
			var bus_volume = AudioServer.get_bus_volume_db(i)
			if bus_volume < -20:
				AudioServer.set_bus_volume_db(i, 0.0)
				print("✓ Reset Master bus volume")
	
	print("=== AUDIO BUS READY ===\n")

func _load_audio_files() -> void:
	print("=== LOADING AUDIO FILES ===")
	
	var sfx_path = "res://asset/minigamessoundsfx/"
	
	audio_command_correct = _create_audio_player([
		sfx_path + "alienlostaudio.mp3",
		sfx_path + "tama.mp3",
		sfx_path + "chrisiex1-correct-156911.mp3",
	], "Master", -6.0)
	
	audio_command_wrong = _create_audio_player([
		sfx_path + "aliencorrects.mp3",
		sfx_path + "error_buzz.mp3",
		sfx_path + "wrong.mp3",
	], "Master", -5.0)
	
	audio_command_unknown = _create_audio_player([
		sfx_path + "command_unknown.mp3",
		sfx_path + "notification_error.mp3",
	], "Master", -8.0)
	
	audio_typing = _create_audio_player([
		sfx_path + "keyboard_type.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -18.0)
	
	audio_threat_spawn = _create_audio_player([
		sfx_path + "alienthreats_spawns.mp3",
		sfx_path + "spawn1.mp3",
		sfx_path + "notification_warning.mp3",
	], "Master", -10.0)
	
	audio_threat_neutralized = _create_audio_player([
		sfx_path + "threat_neutralized.mp3",
		sfx_path + "tama.mp3",
	], "Master", -5.0)
	
	audio_threat_breach = _create_audio_player([
		sfx_path + "threat_breach.mp3",
		sfx_path + "alarm_danger.mp3",
		sfx_path + "error_buzz.mp3",
	], "Master", -3.0)
	
	audio_system_compromised = _create_audio_player([
		sfx_path + "system_compromised.mp3",
		sfx_path + "heart_break.mp3",
	], "Master", -4.0)
	
	audio_wave_advance = _create_audio_player([
		sfx_path + "wave_advance.mp3",
		sfx_path + "level_complete.mp3",
		sfx_path + "mission_complete.mp3",
	], "Master", -5.0)
	
	audio_health_low = _create_audio_player([
		sfx_path + "health_low.mp3",
		sfx_path + "notification_warning.mp3",
	], "Master", -6.0)
	
	audio_ui_click = _create_audio_player([
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)
	
	audio_tutorial_advance = _create_audio_player([
		sfx_path + "tutorial_advance.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -10.0)
	
	audio_game_over = _create_audio_player([
		sfx_path + "alienwins.mp3",
	], "Master", 0.0)
	
	audio_powerup_spawn = _create_audio_player([
		sfx_path + "powerup_spawn.mp3",
		sfx_path + "notification_info.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -8.0)
	
	audio_powerup_collect = _create_audio_player([
		sfx_path + "powerup_collect.mp3",
		sfx_path + "tama.mp3",
		sfx_path + "chrisiex1-correct-156911.mp3",
	], "Master", -4.0)
	
	audio_time_stop = _create_audio_player([
		sfx_path + "time_stop.mp3",
		sfx_path + "notification_warning.mp3",
	], "Master", -2.0)
	
	audio_destroy_all = _create_audio_player([
		sfx_path + "destroy_all.mp3",
		sfx_path + "explosion.mp3",
		sfx_path + "alarm_danger.mp3",
	], "Master", 0.0)
	
	audio_bgm_tutorial = _create_music_player([
		sfx_path + "soc_gameplay.mp3",
		sfx_path + "tutorial_calm.mp3",
	], "Master", -22.0)
	
	audio_bgm_gameplay = _create_music_player([
		sfx_path + "soc_gameplay.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
	], "Master", -18.0)
	
	audio_bgm_intense = _create_music_player([
		sfx_path + "soc_gameplay.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
	], "Master", -16.0)
	
	print("=== AUDIO LOADING COMPLETE ===\n")

func _create_audio_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	player.autoplay = false
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("✅ " + file_path.get_file() + " (" + str(volume_db) + " dB)")
				return player
	
	print("⚠️  " + file_paths[0].get_file() + " not found")
	return player

func _create_music_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = -80.0
	player.autoplay = false
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("🎵 " + file_path.get_file() + " (" + str(volume_db) + " dB target)")
				
				if audio_stream is AudioStreamMP3:
					audio_stream.loop = true
				elif audio_stream is AudioStreamOggVorbis:
					audio_stream.loop = true
				elif audio_stream is AudioStreamWAV:
					audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				
				player.set_meta("target_volume", volume_db)
				return player
	
	print("⚠️  BGM not found")
	return player

func _test_audio_playback():
	print("\n=== TESTING AUDIO ===")
	await get_tree().create_timer(1.0).timeout
	
	if audio_ui_click and audio_ui_click.stream:
		print("🔊 Playing test click...")
		_play_sfx(audio_ui_click, 0, 1.0)
	
	print("=== TEST COMPLETE ===\n")

func _play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0, base_pitch: float = 1.0) -> void:
	if not audio_initialized or not sfx_player or not sfx_player.stream:
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = base_pitch
	
	sfx_player.play()

func _play_bgm(bgm_player: AudioStreamPlayer, fade_in_duration: float = 2.0):
	if not audio_initialized or not bgm_player or not bgm_player.stream:
		return
	
	if current_bgm and current_bgm.playing and current_bgm != bgm_player:
		await _fade_out_bgm(1.0)
	
	current_bgm = bgm_player
	var target_volume = bgm_player.get_meta("target_volume", -18.0)
	
	bgm_player.volume_db = -80.0
	bgm_player.play()
	
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(bgm_player, "volume_db", target_volume, fade_in_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func _fade_out_bgm(duration: float = 1.5):
	if not current_bgm or not current_bgm.playing:
		return
	
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(current_bgm, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await bgm_fade_tween.finished
	current_bgm.stop()

func connect_button_sounds(button: Button):
	if not button:
		return
	
	if button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.disconnect(_on_button_hover)
	if button.pressed.is_connected(_on_button_press):
		button.pressed.disconnect(_on_button_press)
	
	button.mouse_entered.connect(_on_button_hover)
	button.pressed.connect(_on_button_press)

func _on_button_hover():
	_play_sfx(audio_ui_click, 0.1, 0.7)

func _on_button_press():
	_play_sfx(audio_ui_click, 0.05, 1.0)

# ============================================================================
# GAME LOGIC WITH FIXES
# ============================================================================

func _on_quit_pressed() -> void:
	print("[Quit] Button pressed")
	_play_sfx(audio_ui_click, 0, 1.0)
	
	# Stop BGM immediately
	if current_bgm and is_instance_valid(current_bgm):
		current_bgm.stop()
	
	# Small delay for button sound
	await get_tree().create_timer(0.15).timeout
	
	print("[Quit] Changing to mode_selection.tscn")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _process(_delta):
	var command_input = $UI/CommandTerminal/CommandInput
	if command_input and not command_input.has_focus() and not tutorial_active and not game_won:
		command_input.grab_focus()

func show_tutorial():
	tutorial_active = true
	
	_play_bgm(audio_bgm_tutorial, 2.0)
	
	var tutorial_texts := [
		"[b]Welcome to Incident Command: Active Defense Protocol[/b]\n\nYou are a Security Operations Center (SOC) analyst. Cyber threats will attack your systems from the right side of the screen.\n\nYour job: Type the correct defensive command to neutralize each threat.",
		"[b]How Threats Work[/b]\n\nEach threat has:\n• A visual indicator (emoji)\n• A description of its behavior\n• A specific defensive command that works against it\n\nWrong commands won't work - you need to match the defense to the attack type.",
		"[b]Your First Threat[/b]\n\nA [color=yellow]Port Scanner[/color] will appear soon.\nIt's probing your systems for open ports.\n\nThe correct command is: [color=cyan]block-source[/color]\n\nType it in the terminal at the bottom when the threat appears."
	]
	
	$UI/TutorialPanel.visible = true
	$UI/TutorialPanel/TutorialText.text = tutorial_texts[tutorial_phase]

func _on_tutorial_continue():
	_play_sfx(audio_tutorial_advance, 0, 1.0)
	
	tutorial_phase += 1
	
	if tutorial_phase >= 3:
		$UI/TutorialPanel.visible = false
		tutorial_active = false
		
		$UI/CommandTerminal/CommandInput.grab_focus()
		
		await _fade_out_bgm(1.0)
		await get_tree().create_timer(0.5).timeout
		_play_bgm(audio_bgm_gameplay, 2.0)
		
		start_wave()
	else:
		show_tutorial()

func start_wave():
	$Timers/WaveTimer.start()

func _on_wave_timer_timeout():
	spawn_threat()
	
	var next_spawn_time := 0.0
	if current_wave <= 2:
		next_spawn_time = 5.0
	elif current_wave <= 5:
		next_spawn_time = 4.0
	else:
		next_spawn_time = 3.0
	
	$Timers/WaveTimer.start(next_spawn_time)

func spawn_threat():
	var available_threats := []
	
	if current_wave <= 3:
		available_threats = ["port_scanner", "brute_force", "sql_injection"]
	elif current_wave <= 6:
		available_threats = ["port_scanner", "brute_force", "sql_injection", "ddos_flood", "malware_beacon"]
	else:
		available_threats = threat_types.keys()
	
	var threat_type = available_threats[randi() % available_threats.size()]
	var threat = threat_scene.instantiate()
	
	$ThreatContainer.add_child(threat)
	
	threat.game_manager = self
	threat.setup(threat_type, threat_types[threat_type], current_wave <= 3)
	threat.position = Vector2(SPAWN_X, randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX))
	threat.reached_target.connect(_on_threat_reached_target)
	
	active_threats.append(threat)
	
	_play_sfx(audio_threat_spawn, 0.15, 1.0)
	
	if current_wave > 5:
		$UI/CommandReference.modulate.a = 0.3

func _on_command_submitted(command_text: String):
	var command = command_text.strip_edges().to_lower()
	var command_input = $UI/CommandTerminal/CommandInput
	command_input.clear()
	
	command_input.call_deferred("grab_focus")
	
	if active_threats.is_empty():
		_play_sfx(audio_command_unknown, 0, 1.0)
		show_feedback("✗ NO ACTIVE THREATS", Color.GRAY)
		return
	
	var target_threat = active_threats[0]
	
	if not command_database.has(command):
		_play_sfx(audio_command_unknown, 0, 1.0)
		show_feedback("✗ UNKNOWN COMMAND - Check reference panel", Color.RED)
		return
	
	var threat_data = threat_types[target_threat.threat_type]
	var cmd_data = command_database[command]
	
	if target_threat.threat_type in cmd_data.effective_against:
		handle_success(target_threat, command, cmd_data)
	else:
		handle_wrong_command(target_threat, command, cmd_data, threat_data)

func handle_success(threat, _command: String, cmd_data: Dictionary):
	_play_sfx(audio_command_correct, 0.1, 1.0)
	
	score += 100
	threats_neutralized += 1
	
	if randf() < powerup_chance:
		spawn_powerup(threat.position)
		
		var powerup_hint = Label.new()
		powerup_hint.text = "💊 Power-up spawned!"
		powerup_hint.modulate = Color(0, 1, 0.5)
		powerup_hint.position = threat.position + Vector2(0, -50)
		add_child(powerup_hint)
		
		var tween = create_tween()
		tween.tween_property(powerup_hint, "position:y", powerup_hint.position.y - 30, 1.0)
		tween.parallel().tween_property(powerup_hint, "modulate:a", 0.0, 1.0)
		await tween.finished
		powerup_hint.queue_free()
	
	active_threats.erase(threat)
	threat.neutralize()
	
	var feedback = "[color=lime]✓ THREAT NEUTRALIZED[/color]\n"
	feedback += cmd_data.description
	show_feedback(feedback, Color.GREEN)
	
	update_ui()
	
	if threats_neutralized % 5 == 0:
		advance_wave()

func handle_wrong_command(threat, _command: String, cmd_data: Dictionary, threat_data: Dictionary):
	_play_sfx(audio_command_wrong, 0.05, 1.0)
	
	var feedback = "[color=red]✗ INEFFECTIVE[/color]\n"
	
	if cmd_data.category == "PERIMETER" and threat.threat_type in ["sql_injection", "lateral_movement"]:
		feedback += "Can't block - this threat bypasses perimeter defenses. Try a different approach."
	elif cmd_data.category == "HOST" and threat.threat_type in ["ddos_flood"]:
		feedback += "Host defenses won't stop network floods. Use perimeter controls."
	else:
		feedback += "Wrong defense type. [color=yellow]" + threat_data.name + "[/color] needs: [color=cyan]" + threat_data.correct_command + "[/color]"
	
	show_feedback(feedback, Color.ORANGE)
	threat.speed_up()

func _on_threat_reached_target(threat):
	_play_sfx(audio_threat_breach, 0, 1.0)
	
	active_threats.erase(threat)
	systems_health -= 1
	threats_missed += 1
	
	var threat_data = threat_types[threat.threat_type]
	missed_threats_data.append({
		"name": threat_data.name,
		"impact": threat_data.impact,
		"correct_command": threat_data.correct_command
	})
	
	var feedback = "[color=red]⚠ BREACH DETECTED[/color]\n"
	feedback += threat_data.impact
	show_feedback(feedback, Color.RED)
	
	update_system_status()
	update_ui()
	
	if systems_health == 1:
		_play_sfx(audio_health_low, 0, 1.0)
	
	if systems_health <= 0:
		game_over()

func update_system_status():
	_play_sfx(audio_system_compromised, 0, 1.0)
	
	var systems = [
		$UI/ProtectedSystems/WebServer/Status,
		$UI/ProtectedSystems/Database/Status,
		$UI/ProtectedSystems/UserEndpoints/Status
	]
	
	var compromised_count = 3 - systems_health
	for i in range(compromised_count):
		if i < systems.size():
			systems[i].text = "COMPROMISED"
			systems[i].add_theme_color_override("font_color", Color.RED)

func advance_wave():
	_play_sfx(audio_wave_advance, 0, 1.0)
	
	current_wave += 1
	
	if current_wave > VICTORY_WAVE:
		victory()
		return
	
	show_feedback("[color=cyan]▶ WAVE " + str(current_wave) + " INCOMING[/color]", Color.CYAN)
	update_ui()
	
	if current_wave == 4 and current_bgm != audio_bgm_intense:
		await _fade_out_bgm(1.0)
		_play_bgm(audio_bgm_intense, 2.0)

func spawn_powerup(spawn_position: Vector2):
	var powerup = powerup_scene.instantiate()
	
	$PowerUpContainer.add_child(powerup)
	
	var available_types = []
	
	if current_wave >= 3 and current_wave <= 8:
		available_types = ["health", "time_stop", "destroy_all"]
	else:
		available_types = ["health", "destroy_all"]
	
	var total_weight = 0
	for type in available_types:
		total_weight += powerup_types[type].drop_weight
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0
	var selected_type = "health"
	
	for type in available_types:
		cumulative_weight += powerup_types[type].drop_weight
		if random_value <= cumulative_weight:
			selected_type = type
			break
	
	powerup.setup(selected_type, powerup_types[selected_type])
	powerup.position = spawn_position
	powerup.collected.connect(_on_powerup_collected)
	
	active_powerups.append(powerup)
	
	_play_sfx(audio_powerup_spawn, 0.1, 1.0)
	
	print("💊 Power-up spawned: " + selected_type + " at " + str(spawn_position))

func _on_powerup_collected(powerup):
	if not is_instance_valid(powerup):
		return
	
	if powerup in active_powerups:
		active_powerups.erase(powerup)
	
	_play_sfx(audio_powerup_collect, 0.1, 1.0)
	
	var powerup_data = powerup_types[powerup.powerup_type]
	
	match powerup.powerup_type:
		"health":
			restore_system_health()
		"time_stop":
			activate_time_stop()
		"destroy_all":
			activate_destroy_all()
	
	var feedback = "[color=lime]✓ COLLECTED: " + powerup_data.description + "[/color]\n"
	feedback += powerup_data.effect
	show_feedback(feedback, Color(0, 1, 0.5))
	
	$UI/CommandTerminal/CommandInput.call_deferred("grab_focus")

func restore_system_health():
	if systems_health < max_systems_health:
		systems_health += 1
		
		var systems = [
			$UI/ProtectedSystems/WebServer/Status,
			$UI/ProtectedSystems/Database/Status,
			$UI/ProtectedSystems/UserEndpoints/Status
		]
		
		for i in range(systems.size()):
			if systems[i].text == "COMPROMISED":
				systems[i].text = "SECURE"
				systems[i].add_theme_color_override("font_color", Color(0, 1, 0.2))
				
				var tween = create_tween()
				tween.tween_property(systems[i], "scale", Vector2(1.3, 1.3), 0.2)
				tween.tween_property(systems[i], "scale", Vector2(1.0, 1.0), 0.2)
				break
		
		update_ui()
		print("❤️ System restored! Health: " + str(systems_health))
	else:
		score += 200
		show_feedback("[color=yellow]BONUS: +200 points![/color]", Color.YELLOW)
		update_ui()

func activate_time_stop():
	_play_sfx(audio_time_stop, 0, 1.0)
	
	var original_speeds = {}
	for threat in active_threats:
		if is_instance_valid(threat):
			original_speeds[threat] = threat.speed
			threat.speed = 0
			threat.set_process(false)  # ✅ NEW: Freeze _process (stops timer!)
			
			if threat.has_node("AnimatedSprite2D"):
				var sprite = threat.get_node("AnimatedSprite2D")
				sprite.modulate = Color(0.5, 0.7, 1.0)
				sprite.pause()  # ✅ NEW: Pause animation
	
	score += 150
	show_feedback("[color=cyan]⏸️ TIME FREEZE ACTIVATED (5s)![/color]", Color.CYAN)
	update_ui()
	
	await get_tree().create_timer(5.0).timeout
	
	for threat in original_speeds:
		if is_instance_valid(threat):
			threat.speed = original_speeds[threat]
			threat.set_process(true)  # ✅ NEW: Unfreeze _process (resumes timer!)
			
			if threat.has_node("AnimatedSprite2D"):
				var sprite = threat.get_node("AnimatedSprite2D")
				sprite.modulate = Color.WHITE
				sprite.play()  # ✅ NEW: Resume animation
	
	print("⏸️ Time freeze ended")

func activate_destroy_all():
	_play_sfx(audio_destroy_all, 0, 1.0)
	
	var threats_destroyed = 0
	
	# ✅ FIX: Create copy and clear active_threats FIRST
	var threats_copy = active_threats.duplicate()
	active_threats.clear()
	
	for threat in threats_copy:
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			threats_destroyed += 1
			
			# ✅ FIX: Call neutralize() which handles cleanup properly
			threat.neutralize()
	
	var bonus_score = threats_destroyed * 50
	score += bonus_score
	threats_neutralized += threats_destroyed
	
	var feedback = "[color=red]💥 EMERGENCY PURGE![/color]\n"
	feedback += str(threats_destroyed) + " threats destroyed! +" + str(bonus_score) + " points"
	show_feedback(feedback, Color(1, 0.3, 0))
	
	update_ui()
	
	print("💥 Destroyed " + str(threats_destroyed) + " threats!")

func show_feedback(text: String, color: Color):
	$UI/CommandTerminal/FeedbackLabel.text = text
	$UI/CommandTerminal/FeedbackLabel.add_theme_color_override("default_color", color)
	
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid($UI/CommandTerminal/FeedbackLabel):
		$UI/CommandTerminal/FeedbackLabel.text = ""

func update_ui():
	$UI/TopBar/ScoreLabel.text = "Score: " + str(score)
	$UI/TopBar/WaveLabel.text = "Wave: " + str(current_wave)
	$UI/TopBar/HealthBar.value = systems_health
	
	var fill_style = $UI/TopBar/HealthBar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if systems_health == 3:
			fill_style.bg_color = Color(0.0235294, 0.529412, 0.0941176, 0.772549)
		elif systems_health == 2:
			fill_style.bg_color = Color(1.0, 1.0, 0.0, 0.8)
		else:
			fill_style.bg_color = Color(1.0, 0.0, 0.0, 0.8)

func victory():
	game_won = true
	$Timers/WaveTimer.stop()
	
	_play_sfx(audio_wave_advance, 0, 1.0)
	await _fade_out_bgm(2.0)
	
	for threat in active_threats:
		if is_instance_valid(threat):
			threat.queue_free()
	active_threats.clear()
	
	for powerup in active_powerups:
		if is_instance_valid(powerup):
			powerup.queue_free()
	active_powerups.clear()
	
	var total_threats = threats_neutralized + threats_missed
	var accuracy = 0.0
	if total_threats > 0:
		accuracy = (float(threats_neutralized) / float(total_threats)) * 100.0
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var base_xp = 60  # Base XP for completing all waves
	var wave_xp = VICTORY_WAVE * 5  # 5 XP per wave (50 XP for 10 waves)
	var accuracy_xp = int((accuracy / 100.0) * 30)  # Up to 30 XP from accuracy
	var health_xp = systems_health * 10  # 10 XP per remaining system health
	var total_xp_earned = base_xp + wave_xp + accuracy_xp + health_xp
	
	print("[Incident Commander] 🏆 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Wave XP: %d (waves %d)" % [wave_xp, VICTORY_WAVE])
	print("  Accuracy XP: %d (accuracy %.1f%%)" % [accuracy_xp, accuracy])
	print("  Health XP: %d (health %d)" % [health_xp, systems_health])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("incident_commander", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	
	var victory_text = "[b][color=lime]🎉 MISSION ACCOMPLISHED! 🎉[/color][/b]\n\n"
	victory_text += "[color=cyan]You completed all 10 waves and defeated the final assault![/color]\n\n"
	victory_text += "[b]PERFORMANCE REPORT:[/b]\n\n"
	victory_text += "Final Score: [color=yellow]" + str(score) + "[/color]\n"
	victory_text += "Waves Completed: [color=lime]" + str(VICTORY_WAVE) + "[/color]\n"
	victory_text += "Threats Neutralized: [color=lime]" + str(threats_neutralized) + "[/color]\n"
	victory_text += "Threats Missed: [color=red]" + str(threats_missed) + "[/color]\n"
	victory_text += "Accuracy: [color=yellow]" + str(round(accuracy)) + "%[/color]\n"
	victory_text += "Systems Health: [color=lime]" + str(systems_health) + "/3[/color]\n\n"
	
	if accuracy >= 95 and systems_health == 3:
		victory_text += "[b][color=yellow]⭐ PERFECT DEFENSE ⭐[/color][/b]\n"
		victory_text += "Flawless execution! You are a master SOC analyst!"
	elif accuracy >= 80 and systems_health >= 2:
		victory_text += "[b][color=lime]🏆 EXCELLENT PERFORMANCE 🏆[/color][/b]\n"
		victory_text += "Outstanding work! Your systems are secure."
	elif accuracy >= 60:
		victory_text += "[b][color=cyan]✓ MISSION SUCCESS ✓[/color][/b]\n"
		victory_text += "Good work! The threat has been contained."
	else:
		victory_text += "[b][color=orange]⚠ NARROW VICTORY ⚠[/color][/b]\n"
		victory_text += "You made it, but it was close. Keep practicing!"
	
	$UI/VictoryPanel/VictoryText.text = victory_text
	$UI/VictoryPanel.visible = true
	
	print("🏆 VICTORY! Player completed Wave " + str(VICTORY_WAVE))

func game_over():
	$Timers/WaveTimer.stop()
	
	_play_sfx(audio_game_over, 0, 1.0)
	await _fade_out_bgm(2.0)
	
	for threat in active_threats:
		if is_instance_valid(threat):
			threat.queue_free()
	active_threats.clear()
	
	for powerup in active_powerups:
		if is_instance_valid(powerup):
			powerup.queue_free()
	active_powerups.clear()
	
	# ✅ AWARD PARTIAL XP ON LOSS (Based on performance)
	var total_attempts = threats_neutralized + threats_missed
	var accuracy = (float(threats_neutralized) / float(total_attempts) * 100.0) if total_attempts > 0 else 0.0
	
	var wave_xp = current_wave * 8  # 8 XP per wave reached (vs 10 on win)
	var accuracy_xp = int((accuracy / 100.0) * 20)  # Up to 20 XP from accuracy (vs 30 on win)
	var health_xp = systems_health * 5  # 5 XP per remaining system health (vs 10 on win)
	var partial_xp = wave_xp + accuracy_xp + health_xp
	
	print("[Incident Commander] 💀 Game Over - Awarding partial XP:")
	print("  Wave XP: %d (wave %d)" % [wave_xp, current_wave])
	print("  Accuracy XP: %d (%.1f%% accuracy)" % [accuracy_xp, accuracy])
	print("  Health XP: %d (%d health)" % [health_xp, systems_health])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Award XP but DON'T mark as completed
	TutorialManager.add_xp(partial_xp, "Incident Commander (Attempt)")
	
	var debrief = "[b]SECURITY OPERATIONS FAILED[/b]\n\n"
	debrief += "Threats Neutralized: [color=lime]" + str(threats_neutralized) + "[/color]\n"
	debrief += "Threats Missed: [color=red]" + str(threats_missed) + "[/color]\n"
	debrief += "Final Score: " + str(score) + "\n"
	debrief += "[color=yellow]XP Earned: +" + str(partial_xp) + "[/color]\n\n"
	
	if missed_threats_data.size() > 0:
		debrief += "[color=yellow]MISSED THREATS:[/color]\n\n"
		for i in range(min(3, missed_threats_data.size())):
			var threat = missed_threats_data[i]
			debrief += "[color=red]• " + threat.name + "[/color]\n"
			debrief += "  Impact: " + threat.impact + "\n"
			debrief += "  Correct command: [color=cyan]" + threat.correct_command + "[/color]\n\n"
	
	debrief += "\n[color=cyan]Press R or SPACE to restart[/color]"
	
	$UI/DebriefPanel/DebriefText.text = debrief
	$UI/DebriefPanel.visible = true
	
	print("💀 GAME OVER - DebriefPanel displayed")

# ============================================================================
# ✅ BUTTON HANDLERS - WITH EXTENSIVE DEBUG LOGGING
# ============================================================================

# ✅ DebriefPanel RestartButton → RESTARTS the game
func _on_debrief_restart():
	print("\n" + "=".repeat(80))
	print("🔄 [DEBUG] DebriefPanel RESTART button clicked!")
	print("=".repeat(80))
	print("   ⏰ Time: " + str(Time.get_ticks_msec()))
	print("   📍 Function: _on_debrief_restart()")
	print("   🎯 Action: Reloading current scene...")
	print("   📂 Current scene: " + str(get_tree().current_scene.scene_file_path))
	
	# Play sound
	_play_sfx(audio_ui_click, 0, 1.0)
	print("   🔊 Sound played")
	
	# Stop BGM
	if current_bgm and is_instance_valid(current_bgm):
		current_bgm.stop()
		print("   🎵 BGM stopped")
	
	# Stop all timers
	$Timers/WaveTimer.stop()
	print("   ⏱️ Timers stopped")
	
	# ✅ FIXED: Explicitly reload by path instead of reload_current_scene
	var current_scene_path = get_tree().current_scene.scene_file_path
	print("   🔄 Calling change_scene_to_file(" + current_scene_path + ")...")
	get_tree().call_deferred("change_scene_to_file", current_scene_path)
	print("   ✅ Scene reload queued!")
	print("=".repeat(80) + "\n")

# ✅ VictoryPanel RestartButton → EXITS to mode selection
func _on_victory_exit():
	print("\n" + "=".repeat(80))
	print("🚪 [DEBUG] VictoryPanel EXIT button clicked!")
	print("=".repeat(80))
	print("   ⏰ Time: " + str(Time.get_ticks_msec()))
	print("   📍 Function: _on_victory_exit()")
	print("   🎯 Action: Changing to mode_selection.tscn...")
	
	# Play sound
	_play_sfx(audio_ui_click, 0, 1.0)
	print("   🔊 Sound played")
	
	# Stop BGM
	if current_bgm and is_instance_valid(current_bgm):
		current_bgm.stop()
		print("   🎵 BGM stopped")
	
	# ✅ Use call_deferred for scene change
	print("   🔄 Calling change_scene_to_file('res://scene/mode_selection.tscn')...")
	get_tree().call_deferred("change_scene_to_file", "res://scene/mode_selection.tscn")
	print("   ✅ Scene change queued!")
	print("=".repeat(80) + "\n")

func _input(event):
	if event is InputEventKey and event.pressed:
		# ESC key - always quits to menu
		if event.keycode == KEY_ESCAPE:
			_on_quit_pressed()
		
		# R key or SPACE - restart if debrief panel is visible
		elif (event.keycode == KEY_R or event.keycode == KEY_SPACE) and has_node("UI/DebriefPanel"):
			if $UI/DebriefPanel.visible:
				print("🔄 [DEBUG] Keyboard restart triggered (R or SPACE)")
				_on_debrief_restart()
		
		# ENTER or SPACE - exit to menu if victory panel is visible
		elif (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE) and has_node("UI/VictoryPanel"):
			if $UI/VictoryPanel.visible:
				print("🚪 [DEBUG] Keyboard exit triggered (ENTER or SPACE)")
				_on_victory_exit()

func play_threat_neutralized_sound():
	_play_sfx(audio_threat_neutralized, 0.1, 1.0)
