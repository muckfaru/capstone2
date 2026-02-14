extends Control

# ============================================================================
# AUDIO PLAYERS - Dynamically created
# ============================================================================
var audio_success: AudioStreamPlayer
var audio_fail: AudioStreamPlayer
var audio_notification_info: AudioStreamPlayer
var audio_notification_warning: AudioStreamPlayer
var audio_notification_error: AudioStreamPlayer
var audio_ui_click: AudioStreamPlayer
var audio_ui_type: AudioStreamPlayer
var audio_encrypt_start: AudioStreamPlayer
var audio_encrypt_success: AudioStreamPlayer
var audio_decrypt_start: AudioStreamPlayer
var audio_decrypt_success: AudioStreamPlayer
var audio_decrypt_fail: AudioStreamPlayer
var audio_police_alert: AudioStreamPlayer
var audio_police_scan: AudioStreamPlayer
var audio_police_crack: AudioStreamPlayer
var audio_police_safe: AudioStreamPlayer
var audio_message_send: AudioStreamPlayer
var audio_message_receive: AudioStreamPlayer
var audio_heart_loss: AudioStreamPlayer
var audio_level_complete: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_victory: AudioStreamPlayer

# Background music
var audio_bgm_tutorial: AudioStreamPlayer
var audio_bgm_main: AudioStreamPlayer
var current_bgm: AudioStreamPlayer
var bgm_fade_tween: Tween

# Game state
enum GameMode { TUTORIAL, PLAYING }
enum ChatState { PLAYER_CREATING_KEY, WAITING_BOSS, READING_MESSAGE, TYPING_REPLY, SENDING, POLICE_CHECKING }
var current_mode = GameMode.TUTORIAL
var current_state = ChatState.PLAYER_CREATING_KEY

var current_level = 1
var max_levels = 5
var score = 0
var hearts_remaining = 4
var tutorial_step = 0

# Track key usage and patterns
var used_keys = []
var consecutive_similar_keys = 0
var key_strength_history = []
var recent_boss_messages = []
var recent_player_replies = []
var max_recent_messages = 5

# Custom Key Encryption
var encryption_key = ""
var boss_encrypted_message = ""
var boss_decrypted_message = ""
var player_message = ""
var player_encrypted_message = ""
@onready var quit_btn: Button = $TopBar/Quitbtn

# Message index
var message_index = 0
var messages_per_level = 3

# Mission-specific boss messages
var boss_messages_by_mission = {
	1: [
		"Meet me at pier 9 tonight",
		"Package delivered successfully",
		"Payment confirmed",
		"New contact in the morning",
		"Everything looks clear"
	],
	2: [
		"New target: Victor Morales",
		"Surveillance team spotted",
		"Change safe house now",
		"Police are getting close",
		"Asset secured successfully"
	],
	3: [
		"Eliminate the witness",
		"Document retrieval urgent",
		"Transfer complete by midnight",
		"They know about the pier",
		"Switch to backup protocol"
	],
	4: [
		"Abort mission immediately",
		"Extract at 0200 hours",
		"Target has been relocated",
		"Federal agents involved now",
		"Burn the safe house"
	],
	5: [
		"Burn all evidence",
		"Final job. Disappear after",
		"Prepare extraction plan B",
		"This is your last assignment",
		"Leave the country tonight"
	]
}

var player_replies_by_mission = {
	1: [
		"Understood boss",
		"Package confirmed",
		"Payment received",
		"Contact established",
		"All clear on my end"
	],
	2: [
		"Target acquired",
		"Surveillance evaded",
		"Moving to new location",
		"Staying under the radar",
		"Asset in custody"
	],
	3: [
		"Witness neutralized",
		"Documents secured",
		"Transfer initiated",
		"Situation handled",
		"Protocol activated"
	],
	4: [
		"Mission aborted",
		"En route to extraction",
		"New position acquired",
		"Understood. Moving fast",
		"Safe house abandoned"
	],
	5: [
		"Everything burned",
		"Copy that boss",
		"Plan B ready",
		"Getting out now",
		"This is goodbye"
	]
}

# Police AI
var police_common_keys = ["123", "ABC", "KEY", "PASS", "SAFE", "CODE", "LOCK", "HIDE", "BOSS", "KILL"]
var police_learned_patterns = []
var police_crack_multiplier = 1.0

# UI References
@onready var phone_screen = $PhoneContainer/PhoneScreen
@onready var chat_display = $PhoneContainer/PhoneScreen/ChatScrollContainer/ChatDisplay
@onready var key_creation_panel = $PhoneContainer/PhoneScreen/KeyCreationPanel
@onready var key_input = $PhoneContainer/PhoneScreen/KeyCreationPanel/KeyInput
@onready var create_key_button = $PhoneContainer/PhoneScreen/KeyCreationPanel/CreateKeyButton
@onready var incoming_message = $PhoneContainer/PhoneScreen/IncomingMessagePanel
@onready var encrypted_text = $PhoneContainer/PhoneScreen/IncomingMessagePanel/EncryptedText
@onready var decrypt_button = $PhoneContainer/PhoneScreen/IncomingMessagePanel/DecryptButton
@onready var decrypted_text = $PhoneContainer/PhoneScreen/IncomingMessagePanel/DecryptedText
@onready var decrypt_key_input = $PhoneContainer/PhoneScreen/IncomingMessagePanel/KeyInput
@onready var reply_panel = $PhoneContainer/PhoneScreen/ReplyPanel
@onready var reply_text = $PhoneContainer/PhoneScreen/ReplyPanel/ReplyText
@onready var send_button = $PhoneContainer/PhoneScreen/ReplyPanel/SendButton
@onready var police_panel = $PolicePanel
@onready var police_status = $PolicePanel/PoliceStatus
@onready var cracking_bar = $PolicePanel/CrackingBar
@onready var police_text = $PolicePanel/PoliceText
@onready var police_attempts = $PolicePanel/PoliceAttempts
@onready var hearts_container = $HeartsContainer
@onready var level_label = $TopBar/LevelLabel
@onready var score_label = $TopBar/ScoreLabel
@onready var tutorial_panel = $TutorialPanel
@onready var tutorial_title = $TutorialPanel/TutorialTitle
@onready var tutorial_text = $TutorialPanel/TutorialText
@onready var tutorial_continue = $TutorialPanel/ContinueButton
@onready var encryption_demo = $EncryptionDemoPanel
@onready var demo_process = $EncryptionDemoPanel/ProcessDisplay
@onready var game_over_panel = $GameOverPanel
@onready var victory_panel = $VictoryPanel
@onready var current_key_display = $CurrentKeyDisplay
@onready var current_key_label = $CurrentKeyDisplay/KeyLabel

# ============================================================================
# AUDIO INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 Phone Encryption Game - Loading Audio System...")
	
	# CHECK AUDIO BUS CONFIGURATION
	_check_audio_bus_setup()
	
	# LOAD AUDIO FILES
	_load_audio_files()
	
	# Initialize UI
	if victory_panel:
		victory_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false
	
	# Connect buttons
	quit_btn.pressed.connect(_on_quit_pressed)
	connect_button_sounds(quit_btn)
	connect_button_sounds(create_key_button)
	connect_button_sounds(decrypt_button)
	connect_button_sounds(tutorial_continue)
	
	# Start tutorial (this will play the first sounds when appropriate)
	start_tutorial()

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
	
	# Success/Correct sounds - Moderate volume for positive feedback
	audio_success = _create_audio_player([
		sfx_path + "westcorrect.mp3",
		sfx_path + "chrisiex1-correct-156911.mp3",
	], "Master", -8.0)
	
	# Fail/Error sounds - Slightly louder for attention
	audio_fail = _create_audio_player([
		sfx_path + "westerror.mp3",
		sfx_path + "wrong.mp3",
	], "Master", -6.0)
	
	# Notification sounds - Subtle
	audio_notification_info = _create_audio_player([
		sfx_path + "notification_info.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)
	
	audio_notification_warning = _create_audio_player([
		sfx_path + "notification_warning.mp3",
		sfx_path + "error_buzz.mp3",
	], "Master", -8.0)
	
	audio_notification_error = _create_audio_player([
		sfx_path + "otification_error.mp3",
		sfx_path + "error_buzz.mp3",
	], "Master", -6.0)
	
	# UI sounds - Very subtle, shouldn't be distracting
	audio_ui_click = _create_audio_player([
		sfx_path + "westclick.mp3",
	], "Master", -18.0)
	
	audio_ui_type = _create_audio_player([
		sfx_path + "keyboard_type.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -22.0)
	
	# Encryption sounds - Moderate
	audio_encrypt_start = _create_audio_player([
		sfx_path + "encryption_start.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)
	
	audio_encrypt_success = _create_audio_player([
		sfx_path + "encryption_success.mp3",
		sfx_path + "westcorrect.mp3",
	], "Master", -8.0)
	
	audio_decrypt_start = _create_audio_player([
		sfx_path + "decryption_start.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)
	
	audio_decrypt_success = _create_audio_player([
		sfx_path + "decryption_success.mp3",
		sfx_path + "westcorrect.mp3",
	], "Master", -8.0)
	
	audio_decrypt_fail = _create_audio_player([
		sfx_path + "error_buzz.mp3",
		sfx_path + "wrong.mp3",
	], "Master", -6.0)
	
	# Police sounds - These should be more prominent/alarming
	audio_police_alert = _create_audio_player([
		sfx_path + "police_alert.mp3",
		sfx_path + "notification_warning.mp3",
	], "Master", -4.0)
	
	audio_police_scan = _create_audio_player([
		sfx_path + "scanner_beep.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -16.0)
	
	audio_police_crack = _create_audio_player([
		sfx_path + "alarm_danger.mp3",
		sfx_path + "error_buzz.mp3",
	], "Master", -3.0)
	
	audio_police_safe = _create_audio_player([
		sfx_path + "safe_beep.mp3",
		sfx_path + "westcorrect.mp3",
	], "Master", -8.0)
	
	# Message sounds - Subtle notification style
	audio_message_send = _create_audio_player([
		sfx_path + "message_send.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -12.0)
	
	audio_message_receive = _create_audio_player([
		sfx_path + "message_receive.mp3",
		sfx_path + "notification_info.mp3",
	], "Master", -10.0)
	
	# Game state sounds - Important moments should be more prominent
	audio_heart_loss = _create_audio_player([
		sfx_path + "heart_break.mp3",
		sfx_path + "error_buzz.mp3",
	], "Master", -4.0)
	
	audio_level_complete = _create_audio_player([
		sfx_path + "mission_complete.mp3",
		sfx_path + "combo_low.mp3",
	], "Master", -6.0)
	
	audio_game_over = _create_audio_player([
		sfx_path + "westgame_over.mp3",
	], "Master", -2.0)
	
	audio_victory = _create_audio_player([
		sfx_path + "victory_fanfare.mp3",
		sfx_path + "combo_low.mp3",
	], "Master", -3.0)
	
	# Background Music - Should be ambient, not overpowering
	audio_bgm_tutorial = _create_music_player([
		sfx_path + "tutorial_calm.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
	], "Master", -20.0)
	
	audio_bgm_main = _create_music_player([
		sfx_path + "westernbg.mp3",
	], "Master", -18.0)
	
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
				
				# Set looping based on audio type
				if audio_stream is AudioStreamMP3:
					audio_stream.loop = true
				elif audio_stream is AudioStreamOggVorbis:
					audio_stream.loop = true
				elif audio_stream is AudioStreamWAV:
					audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				
				# Store target volume in metadata for later use
				player.set_meta("target_volume", volume_db)
				
				return player
	
	print("⚠️  Background music not found")
	return player

func _play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0, base_pitch: float = 1.0) -> void:
	"""Play a sound effect with optional pitch variation - IMMEDIATE playback"""
	if not sfx_player or not sfx_player.stream:
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = base_pitch
	
	sfx_player.play()

func _play_bgm(bgm_player: AudioStreamPlayer, fade_in_duration: float = 2.0):
	"""Play background music with fade in"""
	if not bgm_player or not bgm_player.stream:
		return
	
	# Fade out current BGM if playing
	if current_bgm and current_bgm.playing and current_bgm != bgm_player:
		await _fade_out_bgm(1.0)
	
	current_bgm = bgm_player
	var target_volume = bgm_player.get_meta("target_volume", -18.0)
	
	# Start playing from beginning
	bgm_player.volume_db = -80.0
	bgm_player.play()
	
	# Fade in
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(bgm_player, "volume_db", target_volume, fade_in_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	print("🎵 Playing BGM with fade in to " + str(target_volume) + " dB")

func _fade_out_bgm(duration: float = 1.5):
	"""Fade out current background music"""
	if not current_bgm or not current_bgm.playing:
		return
	
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(current_bgm, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await bgm_fade_tween.finished
	current_bgm.stop()
	print("🎵 BGM faded out and stopped")

func connect_button_sounds(button: Button):
	"""Connect hover and click sounds to a button"""
	if button and not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)
		button.pressed.connect(_on_button_press)

func _on_button_hover():
	"""Play subtle hover sound"""
	_play_sfx(audio_ui_click, 0.1, 0.7)

func _on_button_press():
	"""Play button click sound"""
	_play_sfx(audio_ui_click, 0.05, 1.0)

# ============================================================================
# TUTORIAL SYSTEM
# ============================================================================

func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	_play_sfx(audio_ui_click, 0, 1.0)
	await _fade_out_bgm(0.5)
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func start_tutorial():
	current_mode = GameMode.TUTORIAL
	tutorial_step = 0
	tutorial_panel.visible = true
	phone_screen.visible = false
	police_panel.visible = false
	encryption_demo.visible = false
	
	# Play tutorial BGM
	_play_bgm(audio_bgm_tutorial, 2.0)
	
	show_tutorial_step()

func show_tutorial_step():
	# Only play sound on step changes, not initial load
	if tutorial_step > 0:
		_play_sfx(audio_ui_click, 0, 1.0)
	
	match tutorial_step:
		0:
			tutorial_title.text = "CLASSIFIED BRIEFING"
			tutorial_text.text = """Agent, you've been recruited for a dangerous job.

You're a professional hitman working for a criminal organization.

Your missions are simple: follow orders, stay silent, eliminate targets.

But there's a problem...

POLICE ARE WATCHING.

Every message you send is intercepted.
Every word is analyzed.
They're trying to catch you.

Your only defense: ENCRYPTION.

Are you ready to learn how to stay hidden?"""
			tutorial_continue.text = ""
		
		1:
			_play_sfx(audio_encrypt_start, 0, 1.0)
			tutorial_title.text = "ENCRYPTION: YOUR SHIELD"
			tutorial_text.text = """The police can read every message you send.

Unless... you ENCRYPT it.

ENCRYPTION transforms your message into gibberish.
Only someone with the SECRET KEY can decode it.

[Example:]
Your message: "KILL THE TARGET"
With key "XYZ": "KIMN VKG VDTIGT"

Police see the encrypted version - meaningless letters.
But your boss has the key and can decode it perfectly.

This is how you'll survive.
This is how you'll stay free.

Ready to see how it works?"""
			tutorial_continue.text = ""
		
		2:
			tutorial_title.text = "How YOU Control Security"
			tutorial_text.text = """Here's how it works:

1. YOU create secret key (e.g., "XYZ")
2. Your message gets encrypted with your key
3. Boss receives encrypted message
4. Boss uses YOUR key to decrypt it
5. Boss replies using SAME key
6. YOU must remember YOUR key to decrypt!

[CRITICAL RULES:]
✗ DON'T reuse the same key
✗ DON'T use similar patterns (ABC, ABD, ABE)
✗ DON'T use simple keys (123, AAA)

✓ DO use unique, random keys
✓ DO change your strategy each time
✓ DO memorize your keys perfectly

Wrong key = Wrong decryption = LOSE HEART!"""
			tutorial_continue.text = "I"
		
		3:
			_play_sfx(audio_police_alert, 0, 1.0)
			tutorial_title.text = "THE ENEMY: ADAPTIVE Police"
			tutorial_text.text = """The police have LEARNING AI that adapts to YOU.

THEY LEARN YOUR PATTERNS:
- If you use "ABC" then "ABD", they'll try "ABE"
- If you reuse keys, they prioritize testing them
- They analyze key length, characters, sequences
- Each cracked key teaches them MORE

YOUR STRATEGY:
✓ Be UNPREDICTABLE (don't follow patterns)
✓ Use VARIED key lengths (3-6 chars)
✓ Mix letters AND numbers creatively
✓ NEVER reuse a key

YOU HAVE 4 LIVES: ❤️❤️❤️❤️

LOSE A LIFE IF:
✗ Police crack your key
✗ You use the WRONG key to decrypt
✗ You reuse a previous key (instant detection!)

The AI gets smarter as you play.
Stay unpredictable to survive.

Ready for your first mission?"""
			tutorial_continue.text = ""

func _on_tutorial_continue_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	tutorial_step += 1
	
	if tutorial_step >= 4:
		_play_sfx(audio_notification_info, 0, 1.0)
		tutorial_panel.visible = false
		# Transition from tutorial to main game BGM
		await _fade_out_bgm(1.0)
		await get_tree().create_timer(0.5).timeout
		start_game()
	else:
		show_tutorial_step()

# ============================================================================
# MAIN GAME
# ============================================================================

func start_game():
	current_mode = GameMode.PLAYING
	phone_screen.visible = true
	police_panel.visible = true
	current_key_display.visible = false
	
	# Play main game BGM
	_play_bgm(audio_bgm_main, 2.0)
	_play_sfx(audio_notification_info, 0, 1.0)
	
	start_level(1)

func start_level(level: int):
	current_level = level
	message_index = 0
	encryption_key = ""
	
	level_label.text = "MISSION %d" % level
	update_ui()
	
	clear_chat()
	
	# Play level start sound
	if level > 1:
		_play_sfx(audio_level_complete, 0, 1.0)
	else:
		_play_sfx(audio_notification_info, 0, 1.0)

	match level:
		1:
			add_system_message("🎯 MISSION 1: INITIATION")
			add_system_message("Your first assignment. Keep it simple.")
		2:
			add_system_message("🎯 MISSION 2: ESCALATION")
			add_system_message("Police are watching. Be more careful.")
		3:
			add_system_message("🎯 MISSION 3: HIGH STAKES")
			add_system_message("Things are getting dangerous. Stay sharp.")
		4:
			add_system_message("🎯 MISSION 4: CRITICAL")
			add_system_message("Federal involvement confirmed. Maximum security required.")
		5:
			add_system_message("🎯 MISSION 5: ENDGAME")
			add_system_message("Final mission. After this, you disappear forever.")

	add_system_message("Create a NEW encryption key!")
	
	await get_tree().create_timer(1.5).timeout
	player_create_encryption_key()

func player_create_encryption_key():
	current_state = ChatState.PLAYER_CREATING_KEY
	
	_play_sfx(audio_notification_info, 0, 1.0)
	add_system_message("🔑 Create your encryption key (3-6 characters):")
	
	key_creation_panel.visible = true
	incoming_message.visible = false
	reply_panel.visible = false
	
	key_input.text = ""
	key_input.editable = true
	create_key_button.disabled = false
	create_key_button.text = ""
	key_input.grab_focus()
	
	# Connect text changed signal for typing sound
	if not key_input.text_changed.is_connected(_on_key_input_text_changed):
		key_input.text_changed.connect(_on_key_input_text_changed)

func _on_key_input_text_changed(_new_text: String):
	"""Play typing sound when user types"""
	_play_sfx(audio_ui_type, 0.2, 1.0)

func _on_create_key_button_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	
	var entered_key = key_input.text.strip_edges().to_upper()
	
	# Basic validation
	if entered_key.length() < 3:
		_play_sfx(audio_notification_error, 0, 1.0)
		show_notification("❌ Key must be at least 3 characters!")
		return
	
	if entered_key.length() > 6:
		_play_sfx(audio_notification_error, 0, 1.0)
		show_notification("❌ Key must be 6 characters or less!")
		return
	
	# Check valid characters
	var valid = true
	for ch in entered_key:
		var code = ch.unicode_at(0)
		if not ((code >= 65 and code <= 90) or (code >= 48 and code <= 57)):
			valid = false
			break
	
	if not valid:
		_play_sfx(audio_notification_error, 0, 1.0)
		show_notification("❌ Key must contain only letters and numbers!")
		return
	
	# Check if key was already used
	if entered_key in used_keys:
		_play_sfx(audio_police_crack, 0, 1.0)
		show_notification("🚨 KEY REUSED! Police detected pattern!")
		add_system_message("⚠️ Police cracked it instantly - they were watching for reused keys!")
		lose_heart()
		if hearts_remaining <= 0:
			return
		await get_tree().create_timer(2.0).timeout
		return
	
	# Check key strength
	var strength = calculate_key_strength(entered_key)
	
	if strength < 0.3:
		_play_sfx(audio_notification_warning, 0, 1.0)
		show_notification("⚠️ Weak key! Police will crack this easily!")
		add_system_message("💡 Tip: Mix letters & numbers, avoid patterns like ABC or 123")
	
	# Check for similar patterns
	if is_similar_to_previous_keys(entered_key):
		_play_sfx(audio_police_alert, 0, 1.0)
		show_notification("🚨 PATTERN DETECTED! Police are learning your style!")
		consecutive_similar_keys += 1
		police_crack_multiplier += 0.3
	else:
		consecutive_similar_keys = 0
		police_crack_multiplier = max(1.0, police_crack_multiplier - 0.1)
	
	# Accept the key
	encryption_key = entered_key
	used_keys.append(entered_key)
	key_strength_history.append(strength)
	
	_play_sfx(audio_encrypt_success, 0, 1.0)
	
	key_input.editable = false
	create_key_button.disabled = true
	
	add_system_message("✅ Encryption key created!")
	add_system_message("⚠️ REMEMBER YOUR KEY! You'll need it to decrypt!")
	
	if strength < 0.3:
		add_system_message("⚠️ Your key is weak - police crack chance: HIGH")
	elif strength < 0.6:
		add_system_message("✓ Your key is moderate - police crack chance: MEDIUM")
	else:
		_play_sfx(audio_success, 0, 1.0)
		add_system_message("✓ Your key is strong - police crack chance: LOW")
	
	current_key_display.visible = false
	
	await get_tree().create_timer(2.0).timeout
	
	key_creation_panel.visible = false
	send_encrypted_message_to_boss()

func calculate_key_strength(key: String) -> float:
	var strength = 0.0
	
	strength += (key.length() - 3) * 0.15
	
	var has_letter = false
	var has_number = false
	var unique_chars = {}
	
	for ch in key:
		unique_chars[ch] = true
		var code = ch.unicode_at(0)
		if code >= 65 and code <= 90:
			has_letter = true
		elif code >= 48 and code <= 57:
			has_number = true
	
	if has_letter and has_number:
		strength += 0.3
	
	strength += (float(unique_chars.size()) / key.length()) * 0.2
	
	if is_sequential(key):
		strength -= 0.4
	
	if is_repeating(key):
		strength -= 0.3
	
	if key in police_common_keys:
		strength = 0.0
	
	return clamp(strength, 0.0, 1.0)

func is_sequential(key: String) -> bool:
	if key.length() < 3:
		return false
	
	for i in range(key.length() - 2):
		var c1 = key[i].unicode_at(0)
		var c2 = key[i + 1].unicode_at(0)
		var c3 = key[i + 2].unicode_at(0)
		
		if c2 == c1 + 1 and c3 == c2 + 1:
			return true
	
	return false

func is_repeating(key: String) -> bool:
	var prev_char = ""
	var repeat_count = 1
	
	for ch in key:
		if ch == prev_char:
			repeat_count += 1
			if repeat_count >= 3:
				return true
		else:
			repeat_count = 1
		prev_char = ch
	
	if key.length() >= 4:
		var half = key.length() / 2
		var first_half = key.substr(0, half)
		var second_half = key.substr(half, half)
		if first_half == second_half:
			return true
	
	return false

func is_similar_to_previous_keys(key: String) -> bool:
	if used_keys.size() == 0:
		return false
	
	var recent_keys = used_keys.slice(max(0, used_keys.size() - 3), used_keys.size())
	
	for prev_key in recent_keys:
		if key.length() == prev_key.length():
			var same_chars = 0
			for i in range(key.length()):
				if i < prev_key.length() and key[i] == prev_key[i]:
					same_chars += 1
			
			if float(same_chars) / key.length() >= 0.6:
				return true
		
		if key.length() == prev_key.length():
			var diff_count = 0
			for i in range(key.length()):
				if i < prev_key.length() and key[i] != prev_key[i]:
					diff_count += 1
			
			if diff_count <= 1:
				return true
	
	return false

func send_encrypted_message_to_boss():
	_play_sfx(audio_encrypt_start, 0, 1.0)
	add_system_message("📤 Sending encrypted message to boss...")
	
	var initial_message = "Ready for orders"
	var encrypted = encrypt_xor(initial_message, encryption_key)
	
	await get_tree().create_timer(0.5).timeout
	_play_sfx(audio_message_send, 0, 1.0)
	
	add_player_message("🔒 " + encrypted)
	score += 20
	update_ui()
	
	await get_tree().create_timer(1.5).timeout
	
	police_intercept_player_key()

func get_unique_message(message_pool_dict: Dictionary, mission_level: int, recent_list: Array) -> String:
	var message_pool = message_pool_dict.get(mission_level, message_pool_dict[1])
	var available_messages = []
	
	for msg in message_pool:
		if msg not in recent_list:
			available_messages.append(msg)
	
	if available_messages.size() == 0:
		recent_list.clear()
		available_messages = message_pool.duplicate()
	
	var selected = available_messages[randi() % available_messages.size()]
	
	recent_list.append(selected)
	if recent_list.size() > max_recent_messages:
		recent_list.pop_front()
	
	return selected

func police_intercept_player_key():
	_play_sfx(audio_police_alert, 0, 1.0)
	
	police_panel.modulate = Color.WHITE
	police_status.text = "INTERCEPTED!"
	police_text.text = "Adaptive analyzing..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	var test_keys = generate_police_test_keys()
	
	var key_strength = calculate_key_strength(encryption_key)
	var base_crack_chance = 0.1 + (0.15 * current_level)
	
	if key_strength < 0.3:
		base_crack_chance += 0.4
	elif key_strength < 0.6:
		base_crack_chance += 0.2
	
	base_crack_chance *= police_crack_multiplier
	
	for i in range(test_keys.size()):
		var test_key = test_keys[i]
		
		# Play scanning sound
		_play_sfx(audio_police_scan, 0.1, 1.0)
		
		police_attempts.text = "AI Testing: %s..." % test_key
		cracking_bar.value = (float(i + 1) / test_keys.size()) * 100
		await get_tree().create_timer(0.4).timeout
		
		if test_key == encryption_key:
			if randf() < base_crack_chance:
				# CRACKED!
				_play_sfx(audio_police_crack, 0, 1.0)
				
				police_status.text = "💀 KEY CRACKED!"
				police_text.text = "AI learned your pattern!"
				police_attempts.text = "Discovered: " + encryption_key
				police_panel.modulate = Color.RED
				
				police_learned_patterns.append(encryption_key)
				
				show_notification("Police cracked your key!")
				lose_heart()
				
				await get_tree().create_timer(3.0).timeout
				
				if hearts_remaining <= 0:
					return
				
				police_panel.modulate = Color.WHITE
				police_status.text = "MONITORING"
				police_text.text = "learning patterns..."
				police_attempts.text = ""
				cracking_bar.value = 0
				
				add_system_message("⚠️ Create a DIFFERENT, UNPREDICTABLE key!")
				await get_tree().create_timer(1.0).timeout
				player_create_encryption_key()
				return
	
	# Safe!
	_play_sfx(audio_police_safe, 0, 1.0)
	
	police_status.text = "ENCRYPTION SECURE"
	police_text.text = "AI couldn't crack it"
	police_attempts.text = "Pattern unrecognized"
	police_panel.modulate = Color.GREEN
	
	var bonus = int(key_strength * 100)
	_play_sfx(audio_success, 0, 1.0)
	show_notification("Key secure! Bonus: +%d" % bonus)
	score += 50 + bonus
	update_ui()
	
	await get_tree().create_timer(2.0).timeout
	
	police_panel.modulate = Color.WHITE
	police_status.text = "MONITORING"
	police_text.text = "Analyzing patterns..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	receive_boss_message()

func generate_police_test_keys() -> Array:
	var test_keys = []
	
	test_keys.append_array(police_common_keys.duplicate())
	test_keys.append_array(police_learned_patterns.duplicate())
	
	for prev_key in used_keys:
		if prev_key.length() > 0:
			var variant = prev_key.substr(0, prev_key.length() - 1)
			var last_char = prev_key[prev_key.length() - 1]
			var code = last_char.unicode_at(0)
			variant += char(code + 1)
			test_keys.append(variant)
		
		if prev_key.length() > 0:
			var variant2 = prev_key.substr(0, prev_key.length() - 1)
			var last_char2 = prev_key[prev_key.length() - 1]
			var code2 = last_char2.unicode_at(0)
			variant2 += char(code2 - 1)
			test_keys.append(variant2)
	
	var unique_keys = {}
	for key in test_keys:
		unique_keys[key] = true
	
	test_keys = unique_keys.keys()
	test_keys.shuffle()
	
	if test_keys.size() > 12:
		test_keys = test_keys.slice(0, 12)
	
	return test_keys

func receive_boss_message():
	message_index += 1
	current_state = ChatState.WAITING_BOSS
	
	_play_sfx(audio_notification_info, 0, 1.0)
	add_system_message("📩 Boss is sending encrypted reply...")
	
	await get_tree().create_timer(1.0).timeout
	
	boss_decrypted_message = get_unique_message(boss_messages_by_mission, current_level, recent_boss_messages)
	boss_encrypted_message = encrypt_xor(boss_decrypted_message, encryption_key)
	
	_play_sfx(audio_message_receive, 0, 1.0)
	
	incoming_message.visible = true
	key_creation_panel.visible = false
	reply_panel.visible = false
	
	encrypted_text.text = "🔒 " + boss_encrypted_message
	decrypted_text.text = ""
	decrypted_text.visible = false
	decrypt_button.disabled = false
	decrypt_button.text = "	"
	decrypt_key_input.text = ""
	decrypt_key_input.editable = true
	
	add_system_message("🔐 Encrypted message received!")
	add_system_message("💡 Enter YOUR key to decrypt!")
	
	current_state = ChatState.READING_MESSAGE
	decrypt_key_input.grab_focus()
	
	# Connect typing sound for decrypt input
	if not decrypt_key_input.text_changed.is_connected(_on_decrypt_input_text_changed):
		decrypt_key_input.text_changed.connect(_on_decrypt_input_text_changed)

func _on_decrypt_input_text_changed(_new_text: String):
	"""Play typing sound when user types in decrypt field"""
	_play_sfx(audio_ui_type, 0.2, 1.0)

func _on_decrypt_button_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	
	var entered_key = decrypt_key_input.text.strip_edges().to_upper()
	
	if entered_key == "":
		_play_sfx(audio_notification_error, 0, 1.0)
		show_notification("❌ Enter your encryption key!")
		return
	
	_play_sfx(audio_decrypt_start, 0, 1.0)
	
	var decrypted = decrypt_xor(boss_encrypted_message, entered_key)
	
	if entered_key == encryption_key:
		# Correct!
		_play_sfx(audio_decrypt_success, 0, 1.0)
		
		decrypted_text.text = "✅ " + decrypted
		decrypted_text.visible = true
		decrypted_text.modulate = Color.GREEN
		decrypt_button.disabled = true
		decrypt_key_input.editable = false
		
		add_boss_message(decrypted)
		score += 100
		update_ui()
		
		await get_tree().create_timer(1.5).timeout
		show_reply_options()
	else:
		# Wrong key!
		_play_sfx(audio_decrypt_fail, 0, 1.0)
		
		decrypted_text.text = "❌ WRONG KEY! Got gibberish: " + decrypted
		decrypted_text.visible = true
		decrypted_text.modulate = Color.RED
		show_notification("⚠️ Wrong key! Boss doesn't recognize you!")
		
		lose_heart()
		
		if hearts_remaining <= 0:
			return
		
		await get_tree().create_timer(2.0).timeout
		decrypted_text.visible = false
		decrypt_key_input.text = ""

func show_reply_options():
	incoming_message.visible = false
	reply_panel.visible = true
	
	player_message = get_unique_message(player_replies_by_mission, current_level, recent_player_replies)
	reply_text.text = player_message
	send_button.disabled = false
	send_button.visible = true
	
	_play_sfx(audio_ui_type, 0, 0.8)
	add_system_message("📝 Sending encrypted reply...")
	
	current_state = ChatState.TYPING_REPLY
	
	await get_tree().create_timer(1.5).timeout
	_on_send_button_pressed()

func _on_send_button_pressed():
	if send_button.disabled:
		return
	
	_play_sfx(audio_encrypt_start, 0, 1.0)
	
	player_encrypted_message = encrypt_xor(player_message, encryption_key)
	
	send_button.disabled = true
	
	await get_tree().create_timer(0.5).timeout
	_play_sfx(audio_message_send, 0, 1.0)
	
	add_player_message("🔒 " + player_encrypted_message)
	
	score += 30
	update_ui()
	
	current_state = ChatState.SENDING
	
	await get_tree().create_timer(1.0).timeout
	
	police_intercept_reply()

func police_intercept_reply():
	current_state = ChatState.POLICE_CHECKING
	
	_play_sfx(audio_police_alert, 0, 1.0)
	
	police_panel.modulate = Color.WHITE
	police_status.text = "🚨 INTERCEPTED REPLY!"
	police_text.text = "Cross-referencing..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	var key_strength = calculate_key_strength(encryption_key)
	var base_crack_chance = 0.15 + (0.1 * current_level)
	
	if key_strength < 0.3:
		base_crack_chance += 0.3
	elif key_strength < 0.6:
		base_crack_chance += 0.15
	
	base_crack_chance *= police_crack_multiplier
	
	var test_keys = generate_police_test_keys()
	
	for i in range(test_keys.size()):
		var test_key = test_keys[i]
		
		_play_sfx(audio_police_scan, 0.15, 1.0)
		
		police_attempts.text = "AI Testing: %s..." % test_key
		cracking_bar.value = (float(i + 1) / test_keys.size()) * 100
		await get_tree().create_timer(0.4).timeout
		
		if test_key == encryption_key:
			if randf() < base_crack_chance:
				# CRACKED!
				_play_sfx(audio_police_crack, 0, 1.0)
				
				var decrypted = decrypt_xor(player_encrypted_message, encryption_key)
				police_status.text = "💀 MESSAGE CRACKED!"
				police_text.text = "Success!"
				police_attempts.text = "Decrypted: \"%s\"" % decrypted
				police_panel.modulate = Color.RED
				
				police_learned_patterns.append(encryption_key)
				
				show_notification("Police cracked your message!")
				lose_heart()
				
				await get_tree().create_timer(3.0).timeout
				
				if hearts_remaining <= 0:
					return
				
				police_panel.modulate = Color.WHITE
				police_status.text = "MONITORING"
				police_text.text = "Checking..."
				police_attempts.text = ""
				cracking_bar.value = 0
				
				check_level_progress()
				return
	
	# Safe!
	_play_sfx(audio_police_safe, 0, 1.0)
	
	cracking_bar.value = 100
	police_status.text = "STILL SECURE"
	police_text.text = "Police defeated"
	police_attempts.text = "Pattern too complex"
	police_panel.modulate = Color.GREEN
	
	var bonus = int(key_strength * 150)
	_play_sfx(audio_success, 0, 1.0)
	show_notification("Message secure! Bonus: +%d" % bonus)
	score += 100 + bonus
	update_ui()
	
	await get_tree().create_timer(2.0).timeout
	
	police_panel.modulate = Color.WHITE
	police_status.text = "MONITORING"
	police_text.text = "Checking..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	check_level_progress()

func check_level_progress():
	if hearts_remaining <= 0:
		return
	
	if message_index >= messages_per_level:
		complete_level()
	else:
		reply_panel.visible = false
		current_key_display.visible = false
		await get_tree().create_timer(1.0).timeout
		_play_sfx(audio_notification_info, 0, 1.0)
		add_system_message("🔄 Next message - NEW UNIQUE key required!")
		await get_tree().create_timer(1.0).timeout
		player_create_encryption_key()

func complete_level():
	_play_sfx(audio_level_complete, 0, 1.0)
	
	match current_level:
		1:
			add_system_message("✅ MISSION 1 COMPLETE!")
			add_system_message("The boss is impressed. More work coming.")
		2:
			add_system_message("✅ MISSION 2 COMPLETE!")
			add_system_message("Police suspicion growing. Stay vigilant.")
		3:
			add_system_message("✅ MISSION 3 COMPLETE!")
			add_system_message("You're in deep now. No turning back.")
		4:
			add_system_message("✅ MISSION 4 COMPLETE!")
			add_system_message("One final job remains. Make it count.")
		5:
			add_system_message("✅ ALL MISSIONS COMPLETE!")

	score += 200
	update_ui()
	
	await get_tree().create_timer(2.0).timeout
	
	if current_level >= max_levels:
		victory()
	else:
		start_level(current_level + 1)

# ============================================================================
# XOR ENCRYPTION/DECRYPTION
# ============================================================================

func encrypt_xor(text: String, key: String) -> String:
	if key.length() == 0:
		return text
	
	var result = ""
	var key_index = 0
	
	for i in range(text.length()):
		var ch = text[i]
		var code = ch.unicode_at(0)
		
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			var is_upper = (code >= 65 and code <= 90)
			var base = 65 if is_upper else 97
			
			var key_ch = key[key_index % key.length()]
			var key_code = key_ch.unicode_at(0)
			var key_val = 0
			
			if key_code >= 65 and key_code <= 90:
				key_val = key_code - 65
			elif key_code >= 48 and key_code <= 57:
				key_val = key_code - 48
			
			var char_val = code - base
			var encrypted_val = (char_val + key_val) % 26
			var encrypted_code = encrypted_val + base
			result += char(encrypted_code)
			
			key_index += 1
		else:
			result += ch
	
	return result

func decrypt_xor(text: String, key: String) -> String:
	if key.length() == 0:
		return text
	
	var result = ""
	var key_index = 0
	
	for i in range(text.length()):
		var ch = text[i]
		var code = ch.unicode_at(0)
		
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			var is_upper = (code >= 65 and code <= 90)
			var base = 65 if is_upper else 97
			
			var key_ch = key[key_index % key.length()]
			var key_code = key_ch.unicode_at(0)
			var key_val = 0
			
			if key_code >= 65 and key_code <= 90:
				key_val = key_code - 65
			elif key_code >= 48 and key_code <= 57:
				key_val = key_code - 48
			
			var char_val = code - base
			var decrypted_val = (char_val - key_val + 26) % 26
			var decrypted_code = decrypted_val + base
			result += char(decrypted_code)
			
			key_index += 1
		else:
			result += ch
	
	return result

# ============================================================================
# UI HELPER FUNCTIONS - NOW USING RICHTEXTLABEL WITH BBCODE
# ============================================================================

func clear_chat():
	chat_display.clear()

func add_system_message(text: String):
	chat_display.append_text("[center][color=#9999b3]⚙️ " + text + "[/color][/center]\n")
	await get_tree().create_timer(0.05).timeout
	chat_display.scroll_to_line(chat_display.get_line_count())

func add_player_message(text: String):
	chat_display.append_text("[right][color=#4db8ff]YOU: " + text + "[/color][/right]\n")
	await get_tree().create_timer(0.05).timeout
	chat_display.scroll_to_line(chat_display.get_line_count())

func add_boss_message(text: String):
	chat_display.append_text("[color=#ff4d4d]BOSS: " + text + "[/color]\n")
	await get_tree().create_timer(0.05).timeout
	chat_display.scroll_to_line(chat_display.get_line_count())

func show_notification(text: String):
	var notif = Label.new()
	notif.text = text
	notif.position = Vector2(get_viewport_rect().size.x / 2 - 150, 100)
	notif.size = Vector2(300, 50)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notif.add_theme_color_override("font_color", Color(1, 1, 0))
	notif.add_theme_font_size_override("font_size", 18)
	add_child(notif)
	
	await get_tree().create_timer(2.5).timeout
	notif.queue_free()

func update_ui():
	score_label.text = "💵 $%d" % score
	level_label.text = "MISSION %d" % current_level
	
	for i in range(hearts_container.get_child_count()):
		var heart = hearts_container.get_child(i)
		if i < hearts_remaining:
			heart.modulate = Color.WHITE
		else:
			heart.modulate = Color(0.3, 0.3, 0.3)

func lose_heart():
	_play_sfx(audio_heart_loss, 0, 1.0)
	hearts_remaining -= 1
	update_ui()
	
	if hearts_remaining <= 0:
		game_over()

func game_over():
	_play_sfx(audio_game_over, 0, 1.0)
	await _fade_out_bgm(2.0)
	
	add_system_message("💀 GAME OVER - ALL LIVES LOST!")
	
	# ✅ AWARD PARTIAL XP ON LOSS (Based on performance)
	var missions_xp = current_level * 8  # 8 XP per mission reached (vs 10 on win)
	var score_xp = int((float(score) / 1000.0) * 15)  # Up to 15 XP from score (vs 30 on win)
	var diversity_xp = int((used_keys.size() / 20.0) * 10)  # Up to 10 XP from key diversity (vs 20 on win)
	var partial_xp = missions_xp + score_xp + diversity_xp
	
	print("[Crypt Contract] 💀 Game Over - Awarding partial XP:")
	print("  Mission XP: %d (mission %d)" % [missions_xp, current_level])
	print("  Score XP: %d (score %d)" % [score_xp, score])
	print("  Diversity XP: %d (%d keys)" % [diversity_xp, used_keys.size()])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Award XP but DON'T mark as completed
	TutorialManager.add_xp(partial_xp, "Crypt Contract (Attempt)")
	
	await get_tree().create_timer(2.0).timeout
	
	game_over_panel.visible = true
	
	var final_score = score
	var messages_sent = message_index
	
	$GameOverPanel/GameOverText.text = """The police cracked your encryption!

You've been arrested for conspiracy and murder.

📊 FINAL STATS:
💰 Score: %d
📨 Messages Sent: %d
🎯 Mission Reached: %d / %d
🏆 XP Earned: +%d

The AI learned your patterns.
You need to be more UNPREDICTABLE!

Tips:
✓ Never reuse keys
✓ Avoid patterns (ABC, 123, etc.)
✓ Mix letters & numbers creatively
✓ Stay random and unpredictable""" % [final_score, messages_sent, current_level, max_levels, partial_xp]

func victory():
	if not victory_panel:
		return
	
	_play_sfx(audio_victory, 0, 1.0)
	await _fade_out_bgm(2.0)
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var base_xp = 50  # Base XP for completing all missions
	var mission_xp = current_level * 10  # 10 XP per mission completed
	var score_xp = int((score / 1000.0) * 30)  # Up to 30 XP from score
	var key_diversity_xp = int((used_keys.size() / 20.0) * 20)  # Up to 20 XP for using diverse keys
	var total_xp_earned = base_xp + mission_xp + score_xp + key_diversity_xp
	
	print("[Crypt Contract] 🎉 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Mission XP: %d (missions %d)" % [mission_xp, current_level])
	print("  Score XP: %d (score %d)" % [score_xp, score])
	print("  Key Diversity XP: %d (%d keys)" % [key_diversity_xp, used_keys.size()])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("crypt_contract", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	
	victory_panel.visible = true
	
	var final_score = score
	var total_keys = used_keys.size()
	
	$VictoryPanel/VictoryText.text = """🎉 CONGRATULATIONS! 🎉

You completed ALL missions without getting caught!

📊 FINAL STATS:
💰 Final Score: %d
🔑 Total Keys Created: %d
🎯 Missions Completed: %d / %d

You outsmarted the police AI by staying:
✓ UNPREDICTABLE
✓ CREATIVE
✓ VIGILANT

You're a true master of encryption!

The organization is impressed.
Your services are no longer needed... for now.""" % [final_score, total_keys, max_levels, max_levels]

func _on_retry_button_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	
	hearts_remaining = 4
	score = 0
	current_level = 1
	message_index = 0
	used_keys.clear()
	consecutive_similar_keys = 0
	key_strength_history.clear()
	police_crack_multiplier = 1.0
	police_learned_patterns.clear()
	recent_boss_messages.clear()
	recent_player_replies.clear()
	game_over_panel.visible = false
	
	start_tutorial()

func _on_quit_button_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	await _fade_out_bgm(0.5)
	get_tree().change_scene_to_file("res://scene/2ndloading.tscn")