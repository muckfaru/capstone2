extends Node2D

# ============================================================================
# CIPHER DEFENSE TERMINAL — Lesson 4.2: AES (Advanced Encryption Standard)
# Re-themed from SOC Incident Command. Gameplay mechanics unchanged.
# Type the correct encryption defense command to fix crypto vulnerabilities.
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

# GameMode multiplayer
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

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

# Command database — encryption defense commands
var command_database := {
	"enforce-aes256": {
		"category": "ALGORITHM",
		"effective_against": ["weak_key"],
		"description": "Upgrade to AES-256 key strength"
	},
	"upgrade-cipher": {
		"category": "ALGORITHM",
		"effective_against": ["des_legacy"],
		"description": "Replace deprecated cipher with AES"
	},
	"switch-to-cbc": {
		"category": "MODE",
		"effective_against": ["ecb_pattern"],
		"description": "Use CBC mode to hide data patterns"
	},
	"enable-gcm": {
		"category": "MODE",
		"effective_against": ["no_authentication"],
		"description": "Enable authenticated encryption (AEAD)"
	},
	"rotate-keys": {
		"category": "KEY MGMT",
		"effective_against": ["key_reuse"],
		"description": "Enforce regular key rotation schedule"
	},
	"use-hsm": {
		"category": "KEY MGMT",
		"effective_against": ["plaintext_keys"],
		"description": "Store keys in Hardware Security Module"
	},
	"randomize-iv": {
		"category": "IV/NONCE",
		"effective_against": ["iv_reuse"],
		"description": "Generate random IV per encryption"
	},
	"add-hmac": {
		"category": "AUTH",
		"effective_against": ["padding_oracle"],
		"description": "Add HMAC to prevent padding oracle"
	},
	"enforce-tls": {
		"category": "TRANSPORT",
		"effective_against": ["plaintext_transit"],
		"description": "Encrypt data in transit with TLS"
	}
}

# Threat types — cryptographic vulnerabilities
var threat_types := {
	# ── Wave 1-3 threats (Beginner) ──
	"weak_key": {
		"name": "Weak Key (56-bit)",
		"visual": "🔑",
		"color": Color(0.8, 0.8, 0.2),
		"description": "56-bit key — brute-forceable",
		"speed": 30.0,
		"impact": "Encryption cracked in hours",
		"tutorial_hint": "This system uses a weak 56-bit key (DES-level).\nUpgrade to AES with a 256-bit key.",
		"correct_command": "enforce-aes256",
		"wave_unlock": 1
	},
	"ecb_pattern": {
		"name": "ECB Mode Leak",
		"visual": "📊",
		"color": Color(1.0, 0.5, 0.0),
		"description": "ECB mode leaking patterns",
		"speed": 35.0,
		"impact": "Data patterns exposed",
		"tutorial_hint": "ECB encrypts identical blocks the same way.\nSwitch to CBC mode where each block depends on the previous.",
		"correct_command": "switch-to-cbc",
		"wave_unlock": 1
	},
	"des_legacy": {
		"name": "Legacy DES",
		"visual": "⚠️",
		"color": Color(1.0, 0.2, 0.2),
		"description": "Deprecated DES still active",
		"speed": 40.0,
		"impact": "Cipher broken — data exposed",
		"tutorial_hint": "DES was cracked in 1999 and retired in 2005.\nReplace it with AES to meet modern standards.",
		"correct_command": "upgrade-cipher",
		"wave_unlock": 1
	},
	# ── Wave 2-4 threats ──
	"no_authentication": {
		"name": "No Auth Tag",
		"visual": "🔓",
		"color": Color(0.3, 0.5, 1.0),
		"description": "Encryption without authentication",
		"speed": 25.0,
		"impact": "Ciphertext tampered undetected",
		"tutorial_hint": "Encryption alone doesn't prove data integrity.\nEnable GCM mode for authenticated encryption.",
		"correct_command": "enable-gcm",
		"wave_unlock": 2
	},
	"iv_reuse": {
		"name": "IV Reuse",
		"visual": "🔄",
		"color": Color(0.8, 0.2, 0.8),
		"description": "Same IV used for every message",
		"speed": 32.0,
		"impact": "First blocks reveal patterns",
		"tutorial_hint": "Reusing the IV lets attackers compare ciphertexts.\nGenerate a fresh random IV for every encryption.",
		"correct_command": "randomize-iv",
		"wave_unlock": 2
	},
	# ── Wave 3-5 threats ──
	"key_reuse": {
		"name": "Key Never Rotated",
		"visual": "🗝️",
		"color": Color(0.9, 0.6, 0.2),
		"description": "Same key used for 3+ years",
		"speed": 38.0,
		"impact": "Years of data compromised if leaked",
		"tutorial_hint": "Old keys increase risk of compromise.\nRotate encryption keys on a regular schedule.",
		"correct_command": "rotate-keys",
		"wave_unlock": 3
	},
	"plaintext_transit": {
		"name": "No Transit Encryption",
		"visual": "📡",
		"color": Color(0.6, 0.6, 0.2),
		"description": "Data sent over plain HTTP",
		"speed": 36.0,
		"impact": "Credentials intercepted on network",
		"tutorial_hint": "Data in transit without TLS can be sniffed by anyone.\nEnforce TLS/HTTPS for all communications.",
		"correct_command": "enforce-tls",
		"wave_unlock": 3
	},
	# ── Wave 4-6 threats ──
	"padding_oracle": {
		"name": "Padding Oracle",
		"visual": "🧩",
		"color": Color(1.0, 0.3, 0.3),
		"description": "Padding errors reveal plaintext",
		"speed": 45.0,
		"impact": "Full decryption via error leaks",
		"tutorial_hint": "Padding error messages let attackers decrypt data byte-by-byte.\nAdd HMAC authentication before decryption.",
		"correct_command": "add-hmac",
		"wave_unlock": 4
	},
	"plaintext_keys": {
		"name": "Keys in Plain Text",
		"visual": "📄",
		"color": Color(0.7, 0.3, 0.9),
		"description": "Encryption keys stored unprotected",
		"speed": 42.0,
		"impact": "All encrypted data exposed",
		"tutorial_hint": "Keys stored in config files can be stolen easily.\nUse a Hardware Security Module (HSM) for key storage.",
		"correct_command": "use-hsm",
		"wave_unlock": 4
	},
	# ── Wave 5-7 threats ──
	"weak_prng": {
		"name": "Weak PRNG",
		"visual": "🎲",
		"color": Color(0.9, 0.4, 0.6),
		"description": "Predictable random number generator",
		"speed": 40.0,
		"impact": "Keys and IVs can be predicted",
		"tutorial_hint": "A weak PRNG makes keys guessable.\nUse a cryptographically secure random number generator.",
		"correct_command": "randomize-iv",
		"wave_unlock": 5
	},
	"cert_expired": {
		"name": "Expired Certificate",
		"visual": "📜",
		"color": Color(0.8, 0.6, 0.1),
		"description": "TLS certificate expired 6 months ago",
		"speed": 38.0,
		"impact": "Man-in-the-middle attacks possible",
		"tutorial_hint": "Expired certificates break the trust chain.\nEnforce TLS with valid, updated certificates.",
		"correct_command": "enforce-tls",
		"wave_unlock": 5
	},
	"triple_des_slow": {
		"name": "3DES Still Active",
		"visual": "🐢",
		"color": Color(0.6, 0.4, 0.2),
		"description": "Triple DES — slow and deprecated",
		"speed": 35.0,
		"impact": "Vulnerable to Sweet32 birthday attack",
		"tutorial_hint": "3DES is deprecated and slow (3x DES operations).\nUpgrade to AES for speed and security.",
		"correct_command": "upgrade-cipher",
		"wave_unlock": 5
	},
	# ── Wave 6-8 threats ──
	"cbc_bit_flip": {
		"name": "CBC Bit-Flip Attack",
		"visual": "🔀",
		"color": Color(1.0, 0.15, 0.5),
		"description": "Attacker flipping ciphertext bits to alter plaintext",
		"speed": 44.0,
		"impact": "Encrypted data silently modified",
		"tutorial_hint": "CBC mode without authentication allows bit-flipping.\nEnable GCM mode for authenticated encryption.",
		"correct_command": "enable-gcm",
		"wave_unlock": 6
	},
	"hardcoded_key": {
		"name": "Hardcoded Key in Source",
		"visual": "💻",
		"color": Color(0.5, 0.8, 0.3),
		"description": "AES key embedded in application code",
		"speed": 42.0,
		"impact": "Anyone with source code can decrypt",
		"tutorial_hint": "Keys in source code get leaked via repos.\nUse a Hardware Security Module (HSM) for key storage.",
		"correct_command": "use-hsm",
		"wave_unlock": 6
	},
	"static_salt": {
		"name": "Static Salt",
		"visual": "🧂",
		"color": Color(0.7, 0.7, 0.3),
		"description": "Same salt used for all password hashes",
		"speed": 36.0,
		"impact": "Rainbow table attacks succeed",
		"tutorial_hint": "Static salts let attackers precompute hashes.\nGenerate a unique random value for each operation.",
		"correct_command": "randomize-iv",
		"wave_unlock": 6
	},
	# ── Wave 7-10 threats (Advanced) ──
	"downgrade_attack": {
		"name": "Protocol Downgrade",
		"visual": "⬇️",
		"color": Color(1.0, 0.2, 0.6),
		"description": "Attacker forcing TLS 1.0 instead of 1.3",
		"speed": 48.0,
		"impact": "Old protocol vulnerabilities exploited",
		"tutorial_hint": "TLS 1.0 has known vulnerabilities.\nEnforce modern TLS to prevent downgrade attacks.",
		"correct_command": "enforce-tls",
		"wave_unlock": 7
	},
	"key_derivation_weak": {
		"name": "Weak Key Derivation",
		"visual": "⚗️",
		"color": Color(0.4, 0.9, 0.8),
		"description": "MD5 used to derive encryption keys",
		"speed": 46.0,
		"impact": "Keys easily brute-forced from password",
		"tutorial_hint": "MD5 is too fast for key derivation — easy to brute-force.\nEnforce AES-256 with a proper KDF like PBKDF2.",
		"correct_command": "enforce-aes256",
		"wave_unlock": 7
	},
	"replay_attack": {
		"name": "Replay Attack",
		"visual": "🔁",
		"color": Color(0.9, 0.3, 0.9),
		"description": "Old encrypted messages replayed by attacker",
		"speed": 50.0,
		"impact": "Duplicate transactions executed",
		"tutorial_hint": "Without nonces, old messages can be replayed.\nAdd HMAC authentication to include timestamps and nonces.",
		"correct_command": "add-hmac",
		"wave_unlock": 8
	},
}

@onready var quit_btn: Button = $Background/Quit

func _ready():
	print("\n" + "=".repeat(80))
	print("🔐 Cipher Defense Terminal - AES Encryption Defense")
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
	
	# ✅ GameMode detection
	if get_tree().has_meta("gamemode_room_code"):
		_is_gamemode = true
		_gamemode_room_code = get_tree().get_meta("gamemode_room_code")
		_gamemode_lobby_url = get_tree().get_meta("gamemode_lobby_url")
		_gamemode_start_time_ms = get_tree().get_meta("gamemode_start_time_ms")
		print("[Cipher Defense] 🔐 GameMode detected — room: %s" % _gamemode_room_code)
		if quit_btn:
			quit_btn.visible = false
	
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
	if _is_gamemode:
		return  # Block quitting in GameMode
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
		"[b]Welcome to Cipher Defense Terminal[/b]\n\nYou are a cryptography security analyst. Encryption vulnerabilities will approach your data systems from the right side of the screen.\n\nYour job: Type the correct defensive command to fix each vulnerability before it reaches your systems.",
		"[b]How Vulnerabilities Work[/b]\n\nEach vulnerability has:\n• A visual indicator (emoji)\n• A description of the crypto weakness\n• A specific defense command that fixes it\n\nWrong commands won't work - you need to match the correct encryption fix to each vulnerability type.",
		"[b]Your First Vulnerability[/b]\n\nA [color=yellow]Weak Key (56-bit)[/color] will appear soon.\nIt means the system uses a key that's too short to resist brute-force.\n\nThe correct command is: [color=cyan]enforce-aes256[/color]\n\nType it in the terminal at the bottom when the vulnerability appears."
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
	# Build available threats based on wave_unlock
	var available_threats := []
	for threat_id in threat_types.keys():
		var wave_req = threat_types[threat_id].get("wave_unlock", 1)
		if wave_req <= current_wave:
			available_threats.append(threat_id)
	
	if available_threats.is_empty():
		available_threats = ["weak_key", "ecb_pattern", "des_legacy"]
	
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
	
	if not command_database.has(command):
		_play_sfx(audio_command_unknown, 0, 1.0)
		show_feedback("✗ UNKNOWN COMMAND - Check reference panel", Color.RED)
		return
	
	var cmd_data = command_database[command]
	
	# ✅ SMART TARGETING: Find the most urgent (closest to breach) threat that matches this command
	var best_match = null
	var best_x := INF  # Lower x = closer to breach = more urgent
	
	for threat in active_threats:
		if not is_instance_valid(threat):
			continue
		if threat.threat_type in cmd_data.effective_against:
			if threat.position.x < best_x:
				best_x = threat.position.x
				best_match = threat
	
	if best_match:
		handle_success(best_match, command, cmd_data)
	else:
		# Command is valid but doesn't match any active threat — show helpful hint
		var nearest_threat = _get_most_urgent_threat()
		if nearest_threat:
			var threat_data = threat_types[nearest_threat.threat_type]
			handle_wrong_command(nearest_threat, command, cmd_data, threat_data)
		else:
			_play_sfx(audio_command_wrong, 0, 1.0)
			show_feedback("✗ No matching threat on screen", Color.ORANGE)

# Helper: get the threat closest to breaching (leftmost position)
func _get_most_urgent_threat():
	var best = null
	var best_x := INF
	for threat in active_threats:
		if is_instance_valid(threat) and threat.position.x < best_x:
			best_x = threat.position.x
			best = threat
	return best

func handle_success(threat, _command: String, cmd_data: Dictionary):
	_play_sfx(audio_command_correct, 0.1, 1.0)
	
	score += 100
	threats_neutralized += 1
	
	# ✅ FIX: Neutralize and remove threat BEFORE any awaits to prevent freed-instance error
	active_threats.erase(threat)
	var threat_pos = threat.position
	if is_instance_valid(threat):
		threat.neutralize()
	
	# Spawn powerup after threat is safely handled
	if randf() < powerup_chance:
		spawn_powerup(threat_pos)
		
		var powerup_hint = Label.new()
		powerup_hint.text = "💊 Power-up spawned!"
		powerup_hint.modulate = Color(0, 1, 0.5)
		powerup_hint.position = threat_pos + Vector2(0, -50)
		add_child(powerup_hint)
		
		var tween = create_tween()
		tween.tween_property(powerup_hint, "position:y", powerup_hint.position.y - 30, 1.0)
		tween.parallel().tween_property(powerup_hint, "modulate:a", 0.0, 1.0)
		await tween.finished
		powerup_hint.queue_free()
	
	var feedback = "[color=lime]✓ THREAT NEUTRALIZED[/color]\n"
	feedback += cmd_data.description
	show_feedback(feedback, Color.GREEN)
	
	update_ui()
	
	if threats_neutralized % 5 == 0:
		advance_wave()

func handle_wrong_command(threat, _command: String, cmd_data: Dictionary, threat_data: Dictionary):
	_play_sfx(audio_command_wrong, 0.05, 1.0)
	
	var feedback = "[color=red]✗ INEFFECTIVE[/color]\n"
	
	if cmd_data.category == "ALGORITHM" and threat.threat_type in ["no_authentication", "iv_reuse"]:
		feedback += "Algorithm upgrades alone won't fix this. This vulnerability needs a mode or nonce fix."
	elif cmd_data.category == "MODE" and threat.threat_type in ["weak_key", "plaintext_keys"]:
		feedback += "Changing modes won't help — the key itself is the problem. Try key management commands."
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
	
	print("[Cipher Defense] 🏆 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Wave XP: %d (waves %d)" % [wave_xp, VICTORY_WAVE])
	print("  Accuracy XP: %d (accuracy %.1f%%)" % [accuracy_xp, accuracy])
	print("  Health XP: %d (health %d)" % [health_xp, systems_health])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("incident_commander", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	elif xp_awarded > 0:
		MinigameRewards.try_grant_rewards("incident_commander", score, xp_awarded, self)
	
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	
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
		victory_text += "Flawless execution! You are a master encryption analyst!"
	elif accuracy >= 80 and systems_health >= 2:
		victory_text += "[b][color=lime]🏆 EXCELLENT PERFORMANCE 🏆[/color][/b]\n"
		victory_text += "Outstanding work! All encryption systems are secure."
	elif accuracy >= 60:
		victory_text += "[b][color=cyan]✓ MISSION SUCCESS ✓[/color][/b]\n"
		victory_text += "Good work! The vulnerabilities have been patched."
	else:
		victory_text += "[b][color=orange]⚠ NARROW VICTORY ⚠[/color][/b]\n"
		victory_text += "You made it, but it was close. Keep practicing!"
	
	$UI/VictoryPanel/VictoryText.text = victory_text
	$UI/VictoryPanel.visible = true
	
	print("🏆 CIPHER DEFENSE VICTORY! Completed Wave " + str(VICTORY_WAVE))

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
	
	print("[Cipher Defense] 💀 Game Over - Awarding partial XP:")
	print("  Wave XP: %d (wave %d)" % [wave_xp, current_wave])
	print("  Accuracy XP: %d (%.1f%% accuracy)" % [accuracy_xp, accuracy])
	print("  Health XP: %d (%d health)" % [health_xp, systems_health])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Award XP but DON'T mark as completed
	TutorialManager.add_xp(partial_xp, "Cipher Defense Terminal (Attempt)")
	TutorialManager.mark_minigame_attempted("incident_commander", partial_xp)
	TutorialManager.mark_minigame_attempted("intermediate_incident_commander", partial_xp)
	
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	
	var debrief = "[b]ENCRYPTION DEFENSE FAILED[/b]\n\n"
	debrief += "Threats Neutralized: [color=lime]" + str(threats_neutralized) + "[/color]\n"
	debrief += "Threats Missed: [color=red]" + str(threats_missed) + "[/color]\n"
	debrief += "Final Score: " + str(score) + "\n"
	debrief += "[color=yellow]XP Earned: +" + str(partial_xp) + "[/color]\n\n"
	
	if missed_threats_data.size() > 0:
		debrief += "[color=yellow]UNPATCHED VULNERABILITIES:[/color]\n\n"
		for i in range(min(3, missed_threats_data.size())):
			var threat = missed_threats_data[i]
			debrief += "[color=red]• " + threat.name + "[/color]\n"
			debrief += "  Impact: " + threat.impact + "\n"
			debrief += "  Fix: [color=cyan]" + threat.correct_command + "[/color]\n\n"
	
	debrief += "\n[color=cyan]Press R or SPACE to restart[/color]"
	
	$UI/DebriefPanel/DebriefText.text = debrief
	$UI/DebriefPanel.visible = true
	
	print("💀 CIPHER DEFENSE FAILED - DebriefPanel displayed")

# ============================================================================
# ✅ BUTTON HANDLERS - WITH EXTENSIVE DEBUG LOGGING
# ============================================================================

# ✅ DebriefPanel RestartButton → RESTARTS the game
func _on_debrief_restart():
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	print("\n" + "=".repeat(80))
	print("🔄 [DEBUG] Cipher Defense RESTART button clicked!")
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
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	print("\n" + "=".repeat(80))
	print("🚪 [DEBUG] Cipher Defense EXIT button clicked!")
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
			if _is_gamemode:
				return  # Block ESC in GameMode
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


# ============================================
# GAMEMODE MULTIPLAYER
# ============================================

func _submit_gamemode_score(final_score: int, max_score: int) -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": final_score,
		"max_score": max_score,
		"time_taken_ms": time_taken_ms
	})

	print("[GameMode] Submitting score: %d/%d (time: %dms)" % [final_score, max_score, time_taken_ms])

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Score submitted → status %d" % code)
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")
