extends Node2D

# Preload scenes
const ATTACK_CARD = preload("res://scene/AttackCard.tscn")
const FEEDBACK_POPUP = preload("res://scene/FeedbackPopup.tscn")
const VICTORY_SCREEN = preload("res://scene/VictoryScreen.tscn")

# ============================================
# AUDIO PLAYERS - Dynamically created
# ============================================
var audio_success: AudioStreamPlayer
var audio_fail: AudioStreamPlayer
var audio_spawn: AudioStreamPlayer
var audio_button_click: AudioStreamPlayer
var audio_card_drag: AudioStreamPlayer
var audio_card_pickup: AudioStreamPlayer
var audio_card_return: AudioStreamPlayer
var audio_combo: AudioStreamPlayer
var audio_wave_complete: AudioStreamPlayer
var audio_timeout: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_victory: AudioStreamPlayer
var audio_zone_hover: AudioStreamPlayer
var audio_tutorial_page: AudioStreamPlayer

# Background music
var audio_bgm: AudioStreamPlayer
var bgm_fade_tween: Tween

# GameMode multiplayer
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# Tutorial state
var current_tutorial_page = 0
var total_tutorial_pages = 4
var tutorial_completed = false

# Game state
var current_wave = 1
var total_waves = 8
var attacks_spawned = 0
var attacks_per_wave = [3, 4, 5, 5, 6, 7, 8, 10]
var time_per_attack = [5.0, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0] # Speeds up faster per wave
var score = 0
var combo = 0
var total_attacks = 0
var correct_attacks = 0
var data_correct = 0
var data_total = 0
var network_correct = 0
var network_total = 0

# Feedback timing control
var is_processing_feedback = false

# Attack database
var attack_database = []
var available_attacks = []
var attack_history = []

# References
@onready var attack_container = $CanvasLayer/AttackContainer
@onready var spawn_timer = $SpawnTimer
@onready var system_health = $CanvasLayer/SystemHealth
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var wave_label = $CanvasLayer/WaveLabel
@onready var data_zone = $CanvasLayer/DropZones/DataZone
@onready var network_zone = $CanvasLayer/DropZones/NetworkZone
@onready var quit_btn: Button = $TextureRect/Quit

# Tutorial references
@onready var tutorial_overlay = $TutorialOverlay
@onready var tutorial_page_title = $TutorialOverlay/ContentPanel/MarginContainer/VBox/PageContainer/PageTitle
@onready var tutorial_page_content = $TutorialOverlay/ContentPanel/MarginContainer/VBox/PageContainer/PageContent
@onready var tutorial_prev_btn = $TutorialOverlay/ContentPanel/MarginContainer/VBox/ButtonContainer/PrevButton
@onready var tutorial_next_btn = $TutorialOverlay/ContentPanel/MarginContainer/VBox/ButtonContainer/NextButton
@onready var tutorial_page_indicator = $TutorialOverlay/ContentPanel/MarginContainer/VBox/ButtonContainer/PageIndicator

# Tutorial pages data
var tutorial_pages = []

func _ready():
	print("🎮 Data vs Network Defense - Loading Audio System...")
	
	# GameMode detection
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[GameMode] Drop Zone Defender running in game mode (room: %s)" % _gamemode_room_code)
	
	# CHECK AUDIO BUS CONFIGURATION
	_check_audio_bus_setup()
	
	# LOAD AUDIO FIRST
	_load_audio_files()
	
	# TEST AUDIO IMMEDIATELY
	_test_audio_playback()
	
	setup_tutorial_pages()
	
	# Connect tutorial buttons
	tutorial_prev_btn.pressed.connect(_on_tutorial_prev_pressed)
	
	# Connect button sounds and hover effects
	connect_button_sounds(tutorial_prev_btn)
	connect_button_sounds(tutorial_next_btn)
	connect_button_sounds(quit_btn)
	
	# Show first tutorial page
	show_tutorial_page(0)
	
	load_attack_data()
	setup_zones()
	update_wave_label()
	spawn_timer.wait_time = time_per_attack[0]
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Hide quit button in GameMode
	if _is_gamemode:
		quit_btn.visible = false

# ============================================
# AUDIO BUS DIAGNOSTICS
# ============================================
func _check_audio_bus_setup():
	print("\n=== AUDIO BUS DIAGNOSTICS ===")
	
	var bus_count = AudioServer.bus_count
	print("Total audio buses: ", bus_count)
	
	for i in range(bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		var bus_volume = AudioServer.get_bus_volume_db(i)
		var is_muted = AudioServer.is_bus_mute(i)
		var is_solo = AudioServer.is_bus_solo(i)
		
		print("Bus #%d: %s | Volume: %s dB | Muted: %s | Solo: %s" % [i, bus_name, bus_volume, is_muted, is_solo])
		
		if bus_name == "Master":
			if is_muted:
				print("⚠️  WARNING: Master bus is MUTED! Unmuting it now...")
				AudioServer.set_bus_mute(i, false)
			if bus_volume < -20:
				print("⚠️  WARNING: Master bus volume is very low (", bus_volume, " dB)!")
				print("    Setting Master bus to 0 dB...")
				AudioServer.set_bus_volume_db(i, 0.0)
	
	print("=== END DIAGNOSTICS ===\n")

# ============================================
# LOAD ALL AUDIO FILES
# ============================================
func _load_audio_files() -> void:
	print("\n=== LOADING AUDIO FILES ===")
	
	var sfx_path = "res://asset/minigamessoundsfx/"
	
	# Balanced audio volumes for comfortable gameplay
	audio_success = _create_audio_player([
		sfx_path + "tama.mp3",
		sfx_path + "chrisiex1-correct-156911.mp3",
	], "Master", -5.0)  # Positive feedback, clear but not jarring
	
	audio_fail = _create_audio_player([
		sfx_path + "error buzz.mp3",
	], "Master", -3.0)  # Slightly louder for alert, but not painful
	
	# Use ui_clicka as fallback for all missing sounds
	audio_spawn = _create_audio_player([
		sfx_path + "spawn.mp3",
		sfx_path + "spawn1.mp3",  # FALLBACK
	], "Master", -8.0)  # Subtle notification
	
	audio_button_click = _create_audio_player([
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)  # Very subtle UI feedback
	
	audio_card_drag = _create_audio_player([
		sfx_path + "card_drag.mp3",
		sfx_path + "ui_clicksa.mp3",  # FALLBACK
	], "Master", -15.0)  # Very quiet, continuous action
	
	audio_card_pickup = _create_audio_player([
		sfx_path + "card_drag.mp3",
		sfx_path + "card_drag.mp3",  # FALLBACK
	], "Master", -10.0)  # Quiet but noticeable
	
	audio_card_return = _create_audio_player([
		sfx_path + "card_drag.mp3",
		sfx_path + "ui_clicka.mp3",  # FALLBACK
	], "Master", -12.0)  # Very subtle
	
	audio_combo = _create_audio_player([
		sfx_path + "combo.mp3",
		sfx_path + "combo_low.mp3",
		sfx_path + "corrects.mp3",  # FALLBACK
	], "Master", -2.0)  # Exciting moment, slightly louder
	
	audio_wave_complete = _create_audio_player([
		sfx_path + "wave_complete.mp3",
		sfx_path + "combo_low.mp3",  # FALLBACK
		sfx_path + "corrects.mp3",  # FALLBACK
	], "Master", 0.0)  # Achievement sound, clear and satisfying
	
	audio_timeout = _create_audio_player([
		sfx_path + "timeout.mp3",
		sfx_path + "wrong.mp3",  # FALLBACK
	], "Master", -2.0)  # Important alert, needs attention
	
	audio_game_over = _create_audio_player([
		sfx_path + "game_over.mp3",
	], "Master", 2.0)  # Major event, prominent but not painful
	
	audio_victory = _create_audio_player([
		sfx_path + "victory.mp3",
		sfx_path + "game_over.mp3",  # FALLBACK (will sound different but better than silence)
		sfx_path + "combo_low.mp3",  # FALLBACK
	], "Master", 3.0)  # Celebration, loudest sound but still reasonable
	
	audio_zone_hover = _create_audio_player([
		sfx_path + "card_drag.mp3",
		sfx_path + "ui_clicka.mp3",  # FALLBACK
	], "Master", -15.0)  # Very subtle hover feedback
	
	audio_tutorial_page = _create_audio_player([
		sfx_path + "card_drag.mp3",
		sfx_path + "ui_clicksa.mp3",  # FALLBACK
	], "Master", -8.0)  # Gentle page turn sound
	
	# Background Music - looping with fade transitions
	audio_bgm = _create_music_player([
		"res://asset/minigamessoundsfx/dtvsntbgsfx.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
		sfx_path + "bgm.mp3",
		sfx_path + "music.mp3",
	], "Master", -15.0)  # Subtle background music
	
	print("=== AUDIO LOADING COMPLETE ===\n")

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
				print("✅ Loaded: " + file_path.get_file() + " (Volume: " + str(volume_db) + " dB)")
				return player
	
	print("⚠️  Optional sound not found: " + file_paths[0].get_file())
	return player


func _create_music_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	"""Create AudioStreamPlayer for background music with looping"""
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = -80.0  # Start silent for fade in
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("🎵 Loaded BGM: " + file_path.get_file() + " (Target Volume: " + str(volume_db) + " dB)")
				
				# Connect to handle looping with fade transitions
				player.finished.connect(_on_bgm_finished.bind(volume_db))
				
				# Auto-play with fade in (call after a frame to ensure everything is ready)
				call_deferred("_start_bgm", player, volume_db)
				
				return player
	
	print("⚠️  Background music not found, game will play without music")
	return player


func _start_bgm(player: AudioStreamPlayer, target_volume: float):
	"""Start background music with fade in"""
	if player and player.stream:
		player.play()
		print("🎵 Starting background music playback...")
		_fade_in_bgm(target_volume)


func _on_bgm_finished(target_volume: float):
	"""Handle background music loop with fade transition"""
	if audio_bgm and audio_bgm.stream:
		# Fade out current playback
		await _fade_out_bgm()
		
		# Small pause between loops (optional, for smoother transition)
		await get_tree().create_timer(0.1).timeout
		
		# Restart from beginning
		audio_bgm.play()
		
		# Fade back in
		_fade_in_bgm(target_volume)


func _fade_in_bgm(target_volume: float, duration: float = 2.0):
	"""Fade in background music"""
	if not audio_bgm or not audio_bgm.stream:
		return
	
	# Cancel any existing fade tween
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	print("🎵 Fading IN background music from " + str(audio_bgm.volume_db) + " dB to " + str(target_volume) + " dB over " + str(duration) + "s")
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(audio_bgm, "volume_db", target_volume, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func _fade_out_bgm(duration: float = 1.5):
	"""Fade out background music"""
	if not audio_bgm or not audio_bgm.stream:
		return
	
	# Cancel any existing fade tween
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	print("🎵 Fading OUT background music from " + str(audio_bgm.volume_db) + " dB to -80 dB over " + str(duration) + "s")
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(audio_bgm, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await bgm_fade_tween.finished


func _test_audio_playback():
	"""Test if audio is actually working"""
	print("\n=== TESTING AUDIO PLAYBACK ===")
	print("Playing test sound in 1 second...")
	await get_tree().create_timer(1.0).timeout
	
	if audio_success and audio_success.stream:
		print("🔊 PLAYING TEST SOUND: corrects.mp3 at adjusted volume")
		audio_success.play()
		
		# Check if it's actually playing
		await get_tree().create_timer(0.1).timeout
		if audio_success.playing:
			print("✅ Audio is PLAYING (playing=%s, stream_paused=%s)" % [audio_success.playing, audio_success.stream_paused])
		else:
			print("❌ Audio is NOT playing! Check your audio output device!")
	else:
		print("❌ Cannot test - audio_success is null")
	
	print("=== END AUDIO TEST ===\n")


func _play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0, base_pitch: float = 1.0) -> void:
	"""Play a sound effect with optional pitch variation"""
	if not sfx_player or not sfx_player.stream:
		print("⚠️  Cannot play SFX - player or stream is null")
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = base_pitch
	
	print("🔊 PLAYING SFX: " + sfx_player.stream.resource_path.get_file() + " | Volume: " + str(sfx_player.volume_db) + " dB | Pitch: " + str(sfx_player.pitch_scale))
	sfx_player.play()
	
	# Verify it's actually playing if we're still in the tree
	if not is_inside_tree():
		return
		
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.05).timeout
		if is_instance_valid(sfx_player) and not sfx_player.playing:
			print("⚠️  WARNING: Audio started but is NOT playing! (playing=%s)" % sfx_player.playing)


func connect_button_sounds(button: Button):
	"""Connect hover and click sounds to a button"""
	if button:
		button.mouse_entered.connect(_on_button_hover)
		button.pressed.connect(_on_button_press)


func _on_button_hover():
	"""Play subtle hover sound"""
	_play_sfx(audio_zone_hover, 0.1, 1.0)


func _on_button_press():
	"""Play button click sound"""
	_play_sfx(audio_button_click, 0.05, 1.0)


func setup_tutorial_pages():
	tutorial_pages = [
		{
			"title": "What is Cybersecurity?",
			"content": "[center]Cybersecurity protects computers, networks, and data from digital attacks.

In this game, you'll learn about [color=#00ff66]TWO main types of security[/color]:[/center]

[color=#5599ff]📁 DATA SECURITY[/color] - Protects information and files
[color=#ff5544]🌐 NETWORK SECURITY[/color] - Protects connections and traffic

[center]Let's learn about each one![/center]"
		},
		{
			"title": "📁 DATA SECURITY",
			"content": "[center][color=#5599ff]DATA Security protects INFORMATION stored on computers.[/color][/center]

[b]What is DATA?[/b]
- Files, documents, and databases
- Passwords and login credentials
- Photos, videos, and personal information
- Customer records and financial data

[b]Common DATA attacks:[/b]
[color=#ff4444]🔒 Ransomware[/color] - Locks your files and demands payment
[color=#ff4444]🦠 Viruses[/color] - Infect and steal data from your computer
[color=#ff4444]🔑 Password Theft[/color] - Steals login credentials
[color=#ff4444]💉 SQL Injection[/color] - Tricks databases to reveal information

[center][b]Remember: If it attacks FILES or INFORMATION, it's DATA security![/b][/center]"
		},
		{
			"title": "🌐 NETWORK SECURITY",
			"content": "[center][color=#ff5544]NETWORK Security protects CONNECTIONS between computers.[/color][/center]

[b]What is a NETWORK?[/b]
- Internet connections and WiFi
- Communication between devices
- Email and messaging traffic
- Website access and downloads

[b]Common NETWORK attacks:[/b]
[color=#ff4444]💥 DDoS[/color] - Floods servers with fake traffic
[color=#ff4444]📡 WiFi Jamming[/color] - Blocks wireless signals
[color=#ff4444]👤 Man-in-the-Middle[/color] - Eavesdrops on connections
[color=#ff4444]🎭 DNS Spoofing[/color] - Redirects you to fake websites

[center][b]Remember: If it attacks CONNECTIONS or TRAFFIC, it's NETWORK security![/b][/center]"
		},
		{
			"title": "🎮 How to Play",
			"content": "[center][b][color=#ffff44]Your Mission: Sort Cyber Attacks![/color][/b][/center]

[b]1. Attack Cards Will Appear[/b]
Each card shows a different cyber attack with a countdown timer.

[b]2. Drag Cards to the Correct Zone[/b]
[color=#5599ff]📁 DATA Zone[/color] - For attacks targeting files and information
[color=#ff5544]🌐 NETWORK Zone[/color] - For attacks targeting connections

[b]3. Watch the CIA Triad[/b]
Wrong answers damage your system health:
- [color=#5599ff]C[/color]onfidentiality - Information secrecy
- [color=#ffaa44]I[/color]ntegrity - Data accuracy
- [color=#44ff44]A[/color]vailability - System uptime

[b]4. Complete All Waves[/b]
Survive increasingly difficult waves of attacks!

[center][color=#00ff66]Think carefully! Speed and accuracy both matter![/color][/center]"
		}
	]

func show_tutorial_page(page_index: int):
	current_tutorial_page = page_index
	
	# Play page turn sound
	_play_sfx(audio_tutorial_page, 0.1, 1.0)
	
	var page_data = tutorial_pages[page_index]
	tutorial_page_title.text = page_data.title
	tutorial_page_content.text = page_data.content
	
	tutorial_page_indicator.text = "Page %d of %d" % [current_tutorial_page + 1, total_tutorial_pages]
	tutorial_prev_btn.disabled = (current_tutorial_page == 0)
	
	if current_tutorial_page < total_tutorial_pages - 1:
		tutorial_next_btn.text = "Next ▶"
		if tutorial_next_btn.is_connected("pressed", _on_tutorial_start_pressed):
			tutorial_next_btn.disconnect("pressed", _on_tutorial_start_pressed)
		if not tutorial_next_btn.is_connected("pressed", _on_tutorial_next_pressed):
			tutorial_next_btn.pressed.connect(_on_tutorial_next_pressed)
	else:
		tutorial_next_btn.text = "🚀 PLAY 🚀"
		if tutorial_next_btn.is_connected("pressed", _on_tutorial_next_pressed):
			tutorial_next_btn.disconnect("pressed", _on_tutorial_next_pressed)
		if not tutorial_next_btn.is_connected("pressed", _on_tutorial_start_pressed):
			tutorial_next_btn.pressed.connect(_on_tutorial_start_pressed)

func _on_tutorial_prev_pressed():
	if current_tutorial_page > 0:
		show_tutorial_page(current_tutorial_page - 1)

func _on_tutorial_next_pressed():
	if current_tutorial_page < total_tutorial_pages - 1:
		show_tutorial_page(current_tutorial_page + 1)

func _on_tutorial_start_pressed():
	await get_tree().create_timer(0.2).timeout
	
	tutorial_overlay.visible = false
	tutorial_completed = true
	spawn_timer.start()
	spawn_attack()

func load_attack_data():
	attack_database = get_default_attacks()
	update_available_attacks()
	print("[LOAD] Loaded ", attack_database.size(), " attacks from hardcoded data")

func _on_quit_pressed() -> void:
	if _is_gamemode:
		return  # Block quitting in GameMode
	await get_tree().create_timer(0.2).timeout
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	
func get_default_attacks():
	return [
		# ── Wave 1 attacks ──
		{"id": 1, "name": "Ransomware Encryption", "category": "data",
			"description": "Malware encrypting employee database files!",
			"icon": "📁🔒",
			"explanation": "Ransomware locks your DATA files. Think of it like someone putting a padlock on your filing cabinet. Use backups to recover!",
			"cia_impact": {"C": 15, "I": 10}, "wave_unlock": 1},
		{"id": 2, "name": "USB Virus", "category": "data",
			"description": "Infected USB drive copying files from computers!",
			"icon": "💾🦠",
			"explanation": "A virus on a USB stick steals DATA when plugged in. Like a thief copying files from your desk. Use antivirus protection!",
			"cia_impact": {"C": 18}, "wave_unlock": 1},
		{"id": 3, "name": "Password Theft", "category": "data",
			"description": "Keylogger recording usernames and passwords!",
			"icon": "🔑💀",
			"explanation": "Someone is stealing your login DATA. Like writing down passwords from your keyboard. Use strong unique passwords!",
			"cia_impact": {"C": 20}, "wave_unlock": 1},
		{"id": 4, "name": "DDoS Attack", "category": "network",
			"description": "1000+ bots flooding web server with traffic!",
			"icon": "🌐💥",
			"explanation": "Too many fake visitors crashing your NETWORK. Like thousands of people blocking a store entrance. Use traffic filters!",
			"cia_impact": {"A": 20}, "wave_unlock": 1},
		{"id": 5, "name": "WiFi Jamming", "category": "network",
			"description": "Signal blocker disrupting wireless connections!",
			"icon": "📡❌",
			"explanation": "Someone is blocking your WiFi NETWORK signals. Like jamming a radio frequency. Use wired connections as backup!",
			"cia_impact": {"A": 18}, "wave_unlock": 1},
		{"id": 6, "name": "Spam Email Flood", "category": "network",
			"description": "Millions of junk emails overloading mail server!",
			"icon": "📧🌊",
			"explanation": "Too many spam emails clogging your NETWORK email system. Like mailbox stuffing. Use spam filters!",
			"cia_impact": {"A": 15}, "wave_unlock": 1},
		# ── Wave 2 attacks ──
		{"id": 7, "name": "SQL Injection", "category": "data",
			"description": "Hacker inserting code to extract customer records!",
			"icon": "💉📊",
			"explanation": "Attacker tricks your database to reveal DATA. Like asking a trick question to get secret info. Validate all inputs!",
			"cia_impact": {"C": 20}, "wave_unlock": 2},
		{"id": 8, "name": "Insider Data Leak", "category": "data",
			"description": "Employee copying files to personal USB drive!",
			"icon": "💾🚨",
			"explanation": "Someone inside is stealing DATA files. Like an employee photocopying documents. Monitor file access!",
			"cia_impact": {"C": 18, "I": 5}, "wave_unlock": 2},
		{"id": 9, "name": "Cloud Storage Hack", "category": "data",
			"description": "Weak password exposed company cloud files!",
			"icon": "☁️🔓",
			"explanation": "Your online DATA storage was accessed. Like someone guessing your locker combination. Use 2-factor authentication!",
			"cia_impact": {"C": 22}, "wave_unlock": 2},
		{"id": 10, "name": "Man-in-the-Middle", "category": "network",
			"description": "Attacker intercepting unencrypted WiFi traffic!",
			"icon": "👤📡",
			"explanation": "Someone is eavesdropping on your NETWORK connection. Like tapping a phone line. Use encrypted connections (HTTPS)!",
			"cia_impact": {"C": 15}, "wave_unlock": 2},
		# ── Wave 3 attacks ──
		{"id": 11, "name": "Phishing Email", "category": "data",
			"description": "Fake email tricking employees into revealing login credentials!",
			"icon": "🎣📧",
			"explanation": "Phishing tricks you into giving away your DATA like passwords. Like a fake letter from your bank. Verify senders before clicking links!",
			"cia_impact": {"C": 18}, "wave_unlock": 3},
		{"id": 12, "name": "DNS Spoofing", "category": "network",
			"description": "Redirecting website traffic to a fake malicious server!",
			"icon": "🎭🌐",
			"explanation": "DNS Spoofing hijacks NETWORK routing to send you to fake sites. Like changing road signs to lead you astray. Use DNSSEC!",
			"cia_impact": {"I": 18, "C": 10}, "wave_unlock": 3},
		{"id": 13, "name": "Spyware Installation", "category": "data",
			"description": "Hidden software recording screen and keyboard activity!",
			"icon": "🕵️📸",
			"explanation": "Spyware silently steals your DATA by watching everything you do. Like a hidden camera in your office. Use anti-spyware tools!",
			"cia_impact": {"C": 22}, "wave_unlock": 3},
		{"id": 14, "name": "ARP Poisoning", "category": "network",
			"description": "Fake ARP replies redirecting local network traffic!",
			"icon": "🔀💻",
			"explanation": "ARP Poisoning tricks your local NETWORK into sending traffic to the attacker. Like rerouting mail to a wrong address. Use static ARP entries!",
			"cia_impact": {"C": 15, "I": 10}, "wave_unlock": 3},
		# ── Wave 4 attacks ──
		{"id": 15, "name": "Trojan Horse", "category": "data",
			"description": "Malicious program disguised as legitimate software!",
			"icon": "🐴💀",
			"explanation": "A Trojan hides inside normal-looking software to steal DATA. Like a gift box hiding a thief. Only download from trusted sources!",
			"cia_impact": {"C": 20, "I": 8}, "wave_unlock": 4},
		{"id": 16, "name": "Port Scanning", "category": "network",
			"description": "Attacker probing all open ports on your server!",
			"icon": "🔍🚪",
			"explanation": "Port scanning checks your NETWORK for weak entry points. Like a burglar testing every door and window. Close unused ports and use a firewall!",
			"cia_impact": {"C": 10}, "wave_unlock": 4},
		{"id": 17, "name": "Data Exfiltration", "category": "data",
			"description": "Sensitive files being uploaded to an external server!",
			"icon": "📤🚫",
			"explanation": "Data Exfiltration secretly moves DATA outside your organization. Like smuggling documents out of a secure building. Monitor outbound traffic!",
			"cia_impact": {"C": 25}, "wave_unlock": 4},
		{"id": 18, "name": "SYN Flood", "category": "network",
			"description": "Incomplete connection requests overwhelming the server!",
			"icon": "🌊🔗",
			"explanation": "A SYN Flood sends thousands of fake handshakes to crash your NETWORK server. Like starting calls but never answering. Use SYN cookies!",
			"cia_impact": {"A": 22}, "wave_unlock": 4},
		# ── Wave 5 attacks ──
		{"id": 19, "name": "Cryptojacking", "category": "data",
			"description": "Hidden crypto-mining malware consuming CPU resources!",
			"icon": "⛏️💻",
			"explanation": "Cryptojacking hijacks your system DATA processing to mine cryptocurrency. Like someone secretly using your electricity. Monitor CPU usage!",
			"cia_impact": {"A": 15, "I": 8}, "wave_unlock": 5},
		{"id": 20, "name": "Packet Sniffing", "category": "network",
			"description": "Capturing unencrypted data packets on the network!",
			"icon": "👃📦",
			"explanation": "Packet Sniffing reads NETWORK traffic like reading someone's mail. Like eavesdropping on a phone call. Encrypt all traffic with TLS!",
			"cia_impact": {"C": 20}, "wave_unlock": 5},
		{"id": 21, "name": "Worm Propagation", "category": "network",
			"description": "Self-replicating malware spreading across the network!",
			"icon": "🐛🌐",
			"explanation": "Worms spread through NETWORK connections without user action. Like a virus spreading through air vents. Patch systems and use firewalls!",
			"cia_impact": {"A": 18, "I": 12}, "wave_unlock": 5},
		{"id": 22, "name": "Database Corruption", "category": "data",
			"description": "Malicious queries altering financial records in the database!",
			"icon": "🗄️💥",
			"explanation": "Database corruption changes your stored DATA silently. Like someone altering entries in an accounting book. Use integrity checks and backups!",
			"cia_impact": {"I": 25}, "wave_unlock": 5},
		# ── Wave 6 attacks ──
		{"id": 23, "name": "Social Engineering Call", "category": "data",
			"description": "Attacker impersonating IT support to get passwords!",
			"icon": "📞🎭",
			"explanation": "Social engineering manipulates people to reveal DATA. Like a con artist pretending to be from the bank. Always verify caller identity!",
			"cia_impact": {"C": 22}, "wave_unlock": 6},
		{"id": 24, "name": "BGP Hijacking", "category": "network",
			"description": "Rerouting internet traffic through malicious servers!",
			"icon": "🛣️🚨",
			"explanation": "BGP Hijacking redirects NETWORK traffic at the internet backbone level. Like redirecting a highway to a dead end. Use RPKI validation!",
			"cia_impact": {"A": 20, "C": 12}, "wave_unlock": 6},
		{"id": 25, "name": "File Integrity Attack", "category": "data",
			"description": "System configuration files secretly modified!",
			"icon": "📝⚠️",
			"explanation": "Tampering with config DATA lets attackers control your system. Like changing the locks on someone's house. Use file integrity monitoring!",
			"cia_impact": {"I": 22, "C": 8}, "wave_unlock": 6},
		{"id": 26, "name": "VLAN Hopping", "category": "network",
			"description": "Attacker jumping between virtual network segments!",
			"icon": "🦘🔒",
			"explanation": "VLAN Hopping breaks through NETWORK segmentation barriers. Like climbing over walls between departments. Disable unused ports and use ACLs!",
			"cia_impact": {"C": 18}, "wave_unlock": 6},
		# ── Wave 7 attacks ──
		{"id": 27, "name": "Zero-Day Exploit", "category": "data",
			"description": "Exploiting an unknown vulnerability to steal classified files!",
			"icon": "🕳️💣",
			"explanation": "A Zero-Day exploits unknown flaws to access DATA before patches exist. Like finding a secret passage nobody knows about. Use behavioral detection!",
			"cia_impact": {"C": 25, "I": 12}, "wave_unlock": 7},
		{"id": 28, "name": "SSL Stripping", "category": "network",
			"description": "Downgrading HTTPS to HTTP to intercept web traffic!",
			"icon": "🔓🌐",
			"explanation": "SSL Stripping removes NETWORK encryption to read traffic. Like removing the seal on a letter. Force HSTS and check for HTTPS!",
			"cia_impact": {"C": 22}, "wave_unlock": 7},
		{"id": 29, "name": "Credential Stuffing", "category": "data",
			"description": "Using leaked passwords from other sites to break into accounts!",
			"icon": "🔐🔄",
			"explanation": "Credential Stuffing reuses stolen DATA passwords on other sites. Like trying the same key on every door. Use unique passwords and MFA!",
			"cia_impact": {"C": 20}, "wave_unlock": 7},
		{"id": 30, "name": "Botnet Command & Control", "category": "network",
			"description": "Infected computers receiving attack orders from a remote server!",
			"icon": "🤖🎮",
			"explanation": "Botnets use NETWORK connections to control infected machines. Like a puppet master pulling strings remotely. Block C2 traffic with DNS filtering!",
			"cia_impact": {"A": 20, "I": 10}, "wave_unlock": 7},
		# ── Wave 8 attacks ──
		{"id": 31, "name": "Advanced Persistent Threat", "category": "data",
			"description": "State-sponsored hackers silently exfiltrating data over months!",
			"icon": "🏴‍☠️🕰️",
			"explanation": "APTs are long-term DATA theft campaigns by advanced attackers. Like a mole inside your organization. Use threat hunting and anomaly detection!",
			"cia_impact": {"C": 28, "I": 15}, "wave_unlock": 8},
		{"id": 32, "name": "DNS Tunneling", "category": "network",
			"description": "Smuggling stolen data out through DNS query traffic!",
			"icon": "🚇🌐",
			"explanation": "DNS Tunneling hides DATA theft inside normal NETWORK DNS queries. Like smuggling notes inside regular mail. Monitor DNS traffic patterns!",
			"cia_impact": {"C": 22}, "wave_unlock": 8},
		{"id": 33, "name": "Supply Chain Attack", "category": "data",
			"description": "Compromised software update installing backdoors!",
			"icon": "📦🐍",
			"explanation": "Supply Chain attacks inject malware into trusted DATA updates. Like poisoning food at the factory. Verify software signatures and sources!",
			"cia_impact": {"C": 25, "I": 18}, "wave_unlock": 8},
		{"id": 34, "name": "DDoS Amplification", "category": "network",
			"description": "Using open DNS resolvers to amplify attack traffic 100x!",
			"icon": "📢💥",
			"explanation": "Amplification uses NETWORK services to multiply attack traffic. Like using a megaphone to make a whisper into a shout. Secure open resolvers!",
			"cia_impact": {"A": 28}, "wave_unlock": 8},
	]
	
func update_available_attacks():
	available_attacks.clear()
	for attack in attack_database:
		if attack.wave_unlock <= current_wave:
			available_attacks.append(attack)
	
	available_attacks.shuffle()
	print("[UPDATE] Wave ", current_wave, " has ", available_attacks.size(), " available attacks")

func setup_zones():
	data_zone.zone_dropped.connect(_on_zone_dropped)
	network_zone.zone_dropped.connect(_on_zone_dropped)

func get_random_attack():
	"""Get a random attack that hasn't been used recently"""
	if available_attacks.is_empty():
		print("[ERROR] No available attacks!")
		return null
	
	var fresh_attacks = []
	for attack in available_attacks:
		if not attack_history.has(attack.id):
			fresh_attacks.append(attack)
	
	if fresh_attacks.size() < 3 and attack_history.size() > 0:
		var entries_to_remove = min(3, attack_history.size())
		for i in range(entries_to_remove):
			attack_history.pop_front()
		
		fresh_attacks.clear()
		for attack in available_attacks:
			if not attack_history.has(attack.id):
				fresh_attacks.append(attack)
	
	if fresh_attacks.is_empty():
		attack_history.clear()
		fresh_attacks = available_attacks.duplicate()
	
	fresh_attacks.shuffle()
	var selected_attack = fresh_attacks[randi() % fresh_attacks.size()]
	
	attack_history.append(selected_attack.id)
	if attack_history.size() > 8:
		attack_history.pop_front()
	
	return selected_attack

func spawn_attack():
	if not tutorial_completed:
		return
		
	if attacks_spawned >= attacks_per_wave[current_wave - 1]:
		return
	
	# ONLY spawn one card at a time. If there's already a card, don't spawn another yet.
	if attack_container.get_child_count() > 0:
		return
		
	if available_attacks.is_empty():
		print("[ERROR] Cannot spawn - no available attacks!")
		return
	
	var attack_data = get_random_attack()
	if attack_data == null:
		return
	
	var card = ATTACK_CARD.instantiate()
	
	# Pass audio player reference to card
	card.game_manager = self
	
	card.attack_data = attack_data
	card.alert_number = total_attacks + 1
	card.time_limit = time_per_attack[current_wave - 1]
	
	card.position = Vector2(365, 100)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	card.card_expired.connect(_on_card_expired)
	
	attack_container.add_child(card)
	
	await get_tree().process_frame
	
	var tween = create_tween()
	tween.tween_property(card, "position:y", 280, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	attacks_spawned += 1
	total_attacks += 1
	
	if attack_data.category == "data":
		data_total += 1
	else:
		network_total += 1
	
	# Play spawn sound
	_play_sfx(audio_spawn, 0.1, 1.0)

func _on_spawn_timer_timeout():
	spawn_attack()

func _on_zone_dropped(card, zone_type):
	if is_processing_feedback:
		return
	
	is_processing_feedback = true
	
	print("[DROP] Card dropped in ", zone_type, " zone")
	
	var attack_data = card.attack_data
	var is_correct = (attack_data.category == zone_type)
	
	card.is_dragging = false
	card.set_process(false)
	
	# PLAY SOUND IMMEDIATELY BEFORE ANY ASYNC OPERATIONS
	if is_correct:
		print("🎯 CORRECT! Playing success sound NOW")
		_play_sfx(audio_success, 0.05, 1.0)
		await handle_correct_answer(attack_data, card)
	else:
		print("❌ WRONG! Playing fail sound NOW")
		_play_sfx(audio_fail, 0.05, 1.0)
		await handle_wrong_answer(attack_data, zone_type, card)
	
	# Wait a tiny bit to ensure sound starts playing
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(card):
		card.queue_free()
	
	await get_tree().process_frame
	
	is_processing_feedback = false
	
	if system_health.is_system_critical():
		return # Game over handles itself
		
	check_wave_completion()
	
	# Drop the next card if the wave is not fully spawned yet
	if attacks_spawned < attacks_per_wave[current_wave - 1]:
		spawn_timer.start(0.5) # Small delay before the next card drops
	
func handle_correct_answer(attack_data, card):
	correct_attacks += 1
	if attack_data.category == "data":
		data_correct += 1
	else:
		network_correct += 1
	
	var time_bonus = 0
	if card.time_remaining > card.time_limit * 0.75:
		time_bonus = 5
	
	combo += 1
	var combo_bonus = 0
	if combo >= 3:
		combo_bonus = int(combo * 2.5)
		_play_sfx(audio_combo, 0.1, 1.0)
	
	score += 10 + time_bonus + combo_bonus
	update_score_label()
	
	await show_feedback(true, attack_data.name + " neutralized!", attack_data.explanation)
	
	if attack_data.category == "data":
		data_zone.show_success_effect()
	else:
		network_zone.show_success_effect()

func handle_wrong_answer(attack_data, wrong_zone, _card):
	combo = 0
	score = max(0, score - 15)
	update_score_label()
	
	var cia_impact = attack_data.get("cia_impact", {})
	for cia_type in cia_impact.keys():
		system_health.reduce_cia(cia_type, cia_impact[cia_type])
	
	var wrong_category = "Network" if wrong_zone == "network" else "Data"
	var correct_category = "DATA" if attack_data.category == "data" else "NETWORK"
	var message = "Wrong! %s targets %s Security, not %s." % [attack_data.name, correct_category, wrong_category]
	await show_feedback(false, "MISROUTED ATTACK!", message + "\n\n" + attack_data.explanation)
	
	if wrong_zone == "data":
		data_zone.show_fail_effect()
	else:
		network_zone.show_fail_effect()
	
	if system_health.is_system_critical():
		game_over()

func _on_card_expired(card):
	if is_processing_feedback:
		return
		
	is_processing_feedback = true
	
	# Play timeout sound IMMEDIATELY
	print("⏰ TIMEOUT! Playing timeout sound NOW")
	_play_sfx(audio_timeout, 0, 1.0)
	
	var attack_data = card.attack_data
	combo = 0
	score = max(0, score - 20)
	update_score_label()
	
	var cia_impact = attack_data.get("cia_impact", {})
	for cia_type in cia_impact.keys():
		system_health.reduce_cia(cia_type, cia_impact[cia_type] * 1.5)
	
	card.set_process(false)
	
	await show_feedback(false, "⏱ TIMEOUT!", "Failed to respond! " + attack_data.name + " succeeded.\n\n" + attack_data.explanation)
	
	# Wait a tiny bit to ensure sound starts playing
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(card):
		card.queue_free()
	await get_tree().process_frame
	
	is_processing_feedback = false
	
	if system_health.is_system_critical():
		game_over()
	else:
		check_wave_completion()
		# Drop the next card if the wave is not fully spawned yet
		if attacks_spawned < attacks_per_wave[current_wave - 1]:
			spawn_timer.start(0.5) # Small delay before the next card drops

func check_wave_completion():
	if attacks_spawned >= attacks_per_wave[current_wave - 1]:
		await get_tree().process_frame
		if attack_container.get_child_count() == 0 and not is_processing_feedback:
			complete_wave()

func complete_wave():
	spawn_timer.stop()
	
	print("[Wave Complete] Wave ", current_wave, " finished")
	
	# Play wave complete sound IMMEDIATELY
	print("🌊 WAVE COMPLETE! Playing wave complete sound NOW")
	_play_sfx(audio_wave_complete, 0, 1.0)
	
	for child in attack_container.get_children():
		if child:
			child.queue_free()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	while attack_history.size() > 3:
		attack_history.pop_front()
	
	if current_wave >= total_waves:
		show_victory()
	else:
		current_wave += 1
		attacks_spawned = 0
		update_available_attacks()
		update_wave_label()
		
		spawn_timer.wait_time = time_per_attack[current_wave - 1]
		
		await get_tree().create_timer(1.5).timeout
		await show_feedback(true, "WAVE %d COMPLETE!" % (current_wave - 1), "Get ready for wave %d..." % current_wave)
		await get_tree().create_timer(1.5).timeout
		
		if attack_container.get_child_count() > 0:
			for child in attack_container.get_children():
				child.queue_free()
			await get_tree().process_frame
		
		spawn_timer.start()
		await get_tree().create_timer(0.5).timeout
		spawn_attack()

func show_feedback(is_success, title, message):
	# Pause active cards while feedback is showing
	for child in attack_container.get_children():
		if child and "is_paused" in child:
			child.is_paused = true
			
	# Remove any existing feedback popup to prevent pile-up
	for child in $CanvasLayer.get_children():
		if child.has_method("setup") and (child is Panel or child is PanelContainer):
			child.queue_free()
	await get_tree().process_frame
	var popup = FEEDBACK_POPUP.instantiate()
	$CanvasLayer.add_child(popup)
	popup.setup(is_success, title, message)
	await get_tree().create_timer(2.5).timeout
	
	# Resume active cards after feedback closes
	if is_instance_valid(attack_container):
		for child in attack_container.get_children():
			if child and "is_paused" in child:
				child.is_paused = false

func show_victory():
	spawn_timer.stop()
	
	# Fade out background music
	_fade_out_bgm(2.0)
	
	# Play victory sound IMMEDIATELY
	print("🏆 VICTORY! Playing victory sound NOW")
	_play_sfx(audio_victory, 0, 1.0)
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var accuracy = int((float(correct_attacks) / float(total_attacks)) * 100) if total_attacks > 0 else 0
	var base_xp = 150  # Base XP for completion
	var performance_xp = int((score / 1000.0) * 150)  # Up to 150 XP from score
	var accuracy_xp = int((accuracy / 100.0) * 100)  # Up to 100 XP from accuracy
	var total_xp_earned = base_xp + performance_xp + accuracy_xp
	
	print("[Drop Zone Defender] 🎉 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Performance XP: %d (from score %d)" % [performance_xp, score])
	print("  Accuracy XP: %d (from accuracy %d%%)" % [accuracy_xp, accuracy])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("drop_zone_defender", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	elif xp_awarded > 0:
		MinigameRewards.try_grant_rewards("drop_zone_defender", score, xp_awarded, self)
	
	# In GameMode, submit score and go to leaderboard
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	
	var victory = VICTORY_SCREEN.instantiate()
	$CanvasLayer.add_child(victory)
	
	# Pass audio reference to victory screen
	victory.game_manager = self
	
	await victory.ready
	
	victory.setup(score, accuracy, data_correct, data_total, network_correct, network_total)

func game_over():
	spawn_timer.stop()
	
	# Fade out background music
	_fade_out_bgm(2.0)
	
	# Play game over sound IMMEDIATELY
	print("💀 GAME OVER! Playing game over sound NOW")
	_play_sfx(audio_game_over, 0, 1.0)
	
	# ✅ AWARD PARTIAL XP ON LOSS (Based on performance)
	var performance_xp = int((float(score) / 1000.0) * 100)  # Up to 100 XP from score
	var attempts_xp = min(correct_attacks * 5, 50)  # Up to 50 XP from correct attempts
	var partial_xp = performance_xp + attempts_xp
	
	print("[Drop Zone Defender] 💀 Game Over - Awarding partial XP:")
	print("  Performance XP: %d (score %d)" % [performance_xp, score])
	print("  Attempts XP: %d (%d correct)" % [attempts_xp, correct_attacks])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Only award partial XP and mark as attempted if NOT already fully completed
	if not TutorialManager.completed_minigames.has("drop_zone_defender"):
		# Award XP but DON'T mark as completed (score = 0 signals incomplete)
		TutorialManager.add_xp(partial_xp, "Drop Zone Defender (Attempt)")
		
		# Mark as attempted so prerequisite system can unlock the next game
		# Use both the minigame ID and the tutorial ID (prerequisite system uses tutorial IDs)
		TutorialManager.mark_minigame_attempted("drop_zone_defender", partial_xp)
		TutorialManager.mark_minigame_attempted("beginner_drop_zone", partial_xp)
	else:
		print("  ⚠️ Replay - Game already completed. No partial XP awarded.")
	
	# In GameMode, submit score and go to leaderboard (no retry)
	if _is_gamemode:
		await show_feedback(false, "SYSTEM COMPROMISED!", "CIA Triad integrity lost. Mission failed.\n\nSubmitting your score...")
		await get_tree().create_timer(1.5).timeout
		_submit_gamemode_score(score, 500)
		return
	
	await show_feedback(false, "SYSTEM COMPROMISED!", "CIA Triad integrity lost. Mission failed.\n\n+%d XP for effort!\n\nBetter luck next time!" % partial_xp)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()

func update_score_label():
	score_label.text = "SCORE: %d" % score
	if combo >= 3:
		score_label.text += " 🔥x%d" % combo

func update_wave_label():
	wave_label.text = "WAVE %d/%d" % [current_wave, total_waves]

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_gamemode:
			return  # Block ESC quit in GameMode
		_on_quit_pressed()

# Public method for cards to play sounds
func play_card_pickup_sound():
	print("🎴 CARD PICKUP! Playing pickup sound NOW")
	_play_sfx(audio_card_pickup, 0.15, 1.1)

func play_card_drag_sound():
	print("🎴 CARD DRAG! Playing drag sound NOW")
	_play_sfx(audio_card_drag, 0.1, 1.0)

func play_card_return_sound():
	print("🎴 CARD RETURN! Playing return sound NOW")
	_play_sfx(audio_card_return, 0.1, 0.9)


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
