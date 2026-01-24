extends Control

# Game State
enum GameState {
	STORY,
	WAITING_INPUT,
	ENCRYPTING,
	TRANSMITTING,
	INTERCEPTED,
	DECRYPTING,
	SUCCESS,
	FAILURE
}

# Level Configuration
const LEVEL_DATA = {
	1: {
		"title": "LEVEL 1: BASIC ENCRYPTION",
		"story": "[center][color=cyan]ACT 1: THE BREACH[/color]\n\n\"Welcome to the Security Operations Center.\nWe've detected unauthorized network access.\n\nYour job: ensure all outgoing data is encrypted\nbefore transmission.\n\n[color=yellow]Remember, attackers are watching.[/color][/center]",
		"messages": ["HELLO WORLD"],
		"key_hint": "ALPHA",
		"time_limit": 0,
		"required_transmissions": 1,
		"show_key": true
	},
	2: {
		"title": "LEVEL 2: MANUAL KEY ENTRY",
		"story": "[center][color=cyan]CONTINUING...[/color]\n\n\"Good work. Now you're on your own.\nChoose a strong encryption key.\n\n[color=red]Weak keys will be cracked![/color][/center]",
		"messages": ["TRANSFER FUNDS", "AGENT STATUS OK", "MEETING AT 1400"],
		"key_hint": "",
		"time_limit": 60,
		"required_transmissions": 3,
		"show_key": false
	},
	3: {
		"title": "LEVEL 3: MULTI-TRANSMISSION",
		"story": "[center][color=cyan]ACT 2: ESCALATION[/color]\n\n\"We've identified persistent attackers using\nbrute force techniques.\n\nThey're trying to crack weak keys in real-time.\n\n[color=yellow]Use the SAME strong key for all transmissions.[/color][/center]",
		"messages": [
			"PROJECT PHOENIX ACTIVATED",
			"SATELLITE LINK ESTABLISHED",
			"ENCRYPTION PROTOCOL DELTA",
			"MISSION CRITICAL DATA SENT",
			"STANDBY FOR CONFIRMATION"
		],
		"key_hint": "",
		"time_limit": 45,
		"required_transmissions": 5,
		"show_key": false
	},
	4: {
		"title": "LEVEL 4: KEY EXPOSURE CRISIS",
		"story": "[center][color=cyan]ACT 3: CRISIS[/color]\n\n[color=red]ALERT! ALERT! ALERT![/color]\n\n\"One of our workstations may have been compromised.\nThe encryption key could be exposed.\n\nYou need to act fast—change the key\nor risk total data breach!\"\n\n[color=yellow]Choose wisely.[/color][/center]",
		"messages": [
			"CLASSIFIED INTEL PACKAGE ALPHA",
			"EXECUTIVE FINANCIAL RECORDS",
			"PERSONNEL DATABASE BACKUP"
		],
		"key_hint": "",
		"time_limit": 30,
		"required_transmissions": 3,
		"show_key": false,
		"key_exposure_event": true
	},
	5: {
		"title": "LEVEL 5: HIGH-SECURITY OPERATION",
		"story": "[center][color=cyan]ACT 4: FINAL STAND[/color]\n\n\"This is it. We're transmitting the client's\nmost sensitive financial records.\n\nEvery attacker on the darknet is targeting\nthis transmission.\n\n[color=red]Encrypt perfectly, or the company faces\na $50 million lawsuit.[/color]\n\nGood luck.[/center]",
		"messages": [
			"CLIENT PORTFOLIO COMPLETE DATASET",
			"MERGER ACQUISITION DETAILS CONFIDENTIAL",
			"CRYPTOCURRENCY WALLET MASTER KEYS",
			"BOARD MEETING STRATEGIC DOCUMENTS",
			"INTELLECTUAL PROPERTY FULL ARCHIVE",
			"EMPLOYEE SOCIAL SECURITY NUMBERS",
			"BANKING API AUTHENTICATION TOKENS",
			"SECURITY AUDIT VULNERABILITY REPORT",
			"CUSTOMER PAYMENT INFORMATION DATABASE",
			"EXECUTIVE COMPENSATION PRIVATE RECORDS"
		],
		"key_hint": "X7K9-QM3L-PP8W",
		"time_limit": 20,
		"required_transmissions": 10,
		"show_key": true,
		"advanced_attacks": true
	}
}

# Cipher symbols for visual encryption
const CIPHER_SYMBOLS = ["◊", "∆", "§", "ℵ", "⊗", "∇", "⊕", "≈", "∞", "⊛", "⊘", "⊙", "※", "⊚", "⊝", "⊞"]

# State variables
var current_state = GameState.STORY
var current_level = 1
var security_score = 0
var plaintext_message = ""
var encrypted_data = ""
var encryption_key = ""
var stored_key = ""
var attempts_remaining = 3
var current_message_index = 0
var successful_transmissions = 0
var time_remaining = 0
var key_exposed = false

# Node references
@onready var story_panel = $StoryPanel
@onready var game_ui = $GameUI
@onready var story_text = $StoryPanel/StoryText
@onready var level_label = $GameUI/TopBar/LevelLabel
@onready var score_label = $GameUI/TopBar/ScoreLabel
@onready var timer_label = $GameUI/TopBar/TimerLabel
@onready var message_label = $GameUI/PlaintextPanel/MessageLabel
@onready var key_input = $GameUI/PlaintextPanel/KeyInput
@onready var cipher_label = $GameUI/EncryptedPanel/CipherLabel
@onready var lock_icon = $GameUI/EncryptedPanel/LockIcon
@onready var intercept_label = $GameUI/AttackerPanel/InterceptLabel
@onready var attacker_face = $GameUI/AttackerPanel/AttackerFace
@onready var encrypt_button = $GameUI/ControlButtons/EncryptButton
@onready var transmit_button = $GameUI/ControlButtons/TransmitButton
@onready var decrypt_button = $GameUI/ControlButtons/DecryptButton
@onready var feedback_label = $GameUI/FeedbackLabel
@onready var security_meter = $GameUI/SecurityMeter
@onready var security_label = $GameUI/SecurityMeter/SecurityLabel
@onready var transmission_timer = $GameUI/TransmissionTimer
@onready var level_timer = $GameUI/LevelTimer
@onready var flash_overlay = $GameUI/FlashOverlay

func _ready():
	story_panel.visible = true
	game_ui.visible = false
	load_level_story(current_level)

func load_level_story(level: int):
	var level_info = LEVEL_DATA[level]
	story_text.text = level_info["story"]

func _on_continue_button_pressed():
	if current_state == GameState.STORY:
		story_panel.visible = false
		game_ui.visible = true
		start_level(current_level)

func start_level(level: int):
	current_level = level
	var level_info = LEVEL_DATA[level]
	
	level_label.text = level_info["title"]
	current_message_index = 0
	successful_transmissions = 0
	key_exposed = false
	attempts_remaining = 3
	
	# Set up timer if level has time limit
	if level_info["time_limit"] > 0:
		time_remaining = level_info["time_limit"]
		level_timer.wait_time = level_info["time_limit"]
		level_timer.start()
		transmission_timer.start()
	else:
		timer_label.text = "TIME: UNLIMITED"
	
	# Pre-fill key for tutorial/advanced levels
	if level_info["show_key"]:
		key_input.text = level_info["key_hint"]
	else:
		key_input.text = ""
	
	load_next_message()
	update_ui()
	current_state = GameState.WAITING_INPUT

func load_next_message():
	var level_info = LEVEL_DATA[current_level]
	if current_message_index < level_info["messages"].size():
		plaintext_message = level_info["messages"][current_message_index]
		message_label.text = plaintext_message
		cipher_label.text = "[AWAITING ENCRYPTION]"
		lock_icon.visible = false
		encrypted_data = ""
		
		encrypt_button.disabled = false
		transmit_button.disabled = true
		decrypt_button.disabled = true
		
		intercept_label.text = "[Monitoring network traffic...]"
		attacker_face.text = "👤"
		
		show_feedback("", Color.WHITE)
	else:
		level_complete()

func _on_encrypt_button_pressed():
	var key = key_input.text
	
	# Validate key length
	if key.length() < 6:
		show_feedback("⚠ Key too short! Minimum 6 characters required.", Color.RED)
		flash_screen(Color.RED)
		return
	
	# Check key strength (simple check)
	if current_level >= 2 and is_weak_key(key):
		show_feedback("⚠ WARNING: Weak key detected! Consider using stronger key.", Color.YELLOW)
	
	# Store the key
	encryption_key = key
	stored_key = key
	
	# Encrypt the message
	encrypted_data = encrypt_message(plaintext_message, encryption_key)
	
	# Animate encryption
	animate_encryption()
	
	# Update UI
	cipher_label.text = encrypted_data
	lock_icon.visible = true
	
	security_score += 100
	update_ui()
	
	encrypt_button.disabled = true
	transmit_button.disabled = false
	
	show_feedback("✓ Data encrypted successfully. Ready to transmit.", Color.GREEN)
	
	current_state = GameState.ENCRYPTING

func _on_transmit_button_pressed():
	current_state = GameState.TRANSMITTING
	transmit_button.disabled = true
	
	# Animate transmission
	show_feedback("📡 Transmitting encrypted data...", Color.CYAN)
	
	await get_tree().create_timer(1.0).timeout
	
	# Attacker intercepts
	intercept_label.text = "INTERCEPTED: " + encrypted_data
	attacker_face.text = "😡"
	
	await get_tree().create_timer(1.0).timeout
	
	# Attacker tries to decrypt without key
	intercept_label.text = "[ATTEMPTING DECRYPTION...]\n" + encrypted_data + "\n[UNREADABLE - NO KEY AVAILABLE]"
	attacker_face.text = "😤"
	
	security_score += 50
	update_ui()
	
	await get_tree().create_timer(1.5).timeout
	
	# Check for key exposure event (Level 4)
	if LEVEL_DATA[current_level].get("key_exposure_event", false) and successful_transmissions == 1:
		trigger_key_exposure_event()
		return
	
	# Now decrypt
	decrypt_button.disabled = false
	show_feedback("🔓 Recipient attempting decryption. Verify with correct key.", Color.YELLOW)
	current_state = GameState.DECRYPTING

func _on_decrypt_button_pressed():
	var input_key = key_input.text
	
	# Validate key match
	if input_key == stored_key:
		# Successful decryption
		animate_decryption()
		
		await get_tree().create_timer(1.0).timeout
		
		cipher_label.text = plaintext_message
		cipher_label.modulate = Color(0.5, 1.0, 0.5)
		
		show_feedback("✓ DECRYPTION SUCCESS! Message verified: \"" + plaintext_message + "\"", Color.GREEN)
		
		security_score += 150
		successful_transmissions += 1
		update_ui()
		
		await get_tree().create_timer(2.0).timeout
		
		current_message_index += 1
		load_next_message()
	else:
		# Failed decryption
		attempts_remaining -= 1
		flash_screen(Color.RED)
		
		cipher_label.text = "█▓▒░CORRUPTED DATA░▒▓█"
		cipher_label.modulate = Color(1.0, 0.2, 0.2)
		
		if attempts_remaining > 0:
			show_feedback("✗ INCORRECT KEY! Data corrupted. " + str(attempts_remaining) + " attempts remaining.", Color.RED)
			security_score -= 25
			update_ui()
		else:
			show_feedback("✗ NO ATTEMPTS REMAINING! Message permanently lost.", Color.RED)
			await get_tree().create_timer(2.0).timeout
			mission_failed("All decryption attempts exhausted")

func encrypt_message(message: String, key: String) -> String:
	var result = ""
	for i in range(message.length()):
		var char_code = message.unicode_at(i)
		var key_char = key.unicode_at(i % key.length())
		var encrypted_index = (char_code + key_char) % CIPHER_SYMBOLS.size()
		result += CIPHER_SYMBOLS[encrypted_index]
	return result

func is_weak_key(key: String) -> bool:
	# Simple weakness checks
	if key.length() < 8:
		return true
	if key.to_lower() in ["password", "123456", "qwerty", "abc123"]:
		return true
	# Check if all same character
	var first_char = key[0]
	var all_same = true
	for c in key:
		if c != first_char:
			all_same = false
			break
	return all_same

func animate_encryption():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cipher_label, "modulate", Color(1.0, 0.8, 0.3), 0.5)
	tween.tween_property(lock_icon, "modulate:a", 1.0, 0.5)
	tween.tween_property(lock_icon, "rotation", deg_to_rad(360), 0.5)

func animate_decryption():
	var tween = create_tween()
	tween.tween_property(cipher_label, "modulate", Color(0.5, 1.0, 0.5), 0.5)
	tween.tween_property(lock_icon, "modulate:a", 0.0, 0.5)

func flash_screen(color: Color):
	flash_overlay.color = color
	flash_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.3)
	await tween.finished
	flash_overlay.visible = false
	flash_overlay.modulate.a = 1.0

func show_feedback(text: String, color: Color):
	feedback_label.text = text
	feedback_label.modulate = color

func update_ui():
	score_label.text = "SCORE: " + str(security_score)
	security_meter.value = min(security_score, 1000)
	security_label.text = "SECURITY: " + str(int((security_meter.value / 1000.0) * 100)) + "%"

func _on_transmission_timer_timeout():
	if LEVEL_DATA[current_level]["time_limit"] > 0:
		time_remaining -= 1
		timer_label.text = "TIME: " + str(time_remaining) + "s"
		
		if time_remaining <= 10:
			timer_label.modulate = Color.RED

func _on_level_timer_timeout():
	if encrypted_data == "":
		# Time expired, data sent unencrypted
		show_feedback("⏰ TIME EXPIRED! Data auto-transmitted UNENCRYPTED!", Color.RED)
		intercept_label.text = "INTERCEPTED PLAINTEXT: " + plaintext_message
		attacker_face.text = "😈"
		security_score -= 500
		update_ui()
		await get_tree().create_timer(2.0).timeout
		mission_failed("Unencrypted data exposed due to timeout")

func trigger_key_exposure_event():
	show_feedback("🚨 SECURITY ALERT: KEY MAY BE COMPROMISED! 🚨", Color.RED)
	flash_screen(Color.RED)
	
	await get_tree().create_timer(2.0).timeout
	
	key_exposed = true
	intercept_label.text = "[KEY INTERCEPTED: " + stored_key + "]\n\nAttackers now have your encryption key!\nAll future messages will be compromised!"
	attacker_face.text = "😈"
	
	show_feedback("⚠ Change your key immediately or all data will be exposed!", Color.YELLOW)
	
	# Give player chance to change key
	key_input.text = ""
	encrypt_button.disabled = false
	decrypt_button.disabled = true
	current_state = GameState.WAITING_INPUT

func level_complete():
	var level_info = LEVEL_DATA[current_level]
	
	if successful_transmissions >= level_info["required_transmissions"]:
		show_feedback("🎉 LEVEL " + str(current_level) + " COMPLETE! All data secured!", Color.GREEN)
		security_score += 500
		update_ui()
		
		await get_tree().create_timer(3.0).timeout
		
		if current_level < LEVEL_DATA.size():
			current_level += 1
			current_state = GameState.STORY
			story_panel.visible = true
			game_ui.visible = false
			load_level_story(current_level)
		else:
			game_victory()
	else:
		mission_failed("Insufficient successful transmissions")

func mission_failed(reason: String):
	show_feedback("💀 MISSION FAILED: " + reason, Color.RED)
	flash_screen(Color.RED)
	
	await get_tree().create_timer(3.0).timeout
	
	# Reset level
	start_level(current_level)

func game_victory():
	story_text.text = "[center][color=green]MISSION COMPLETE![/color]\n\n[color=cyan]\"Transmission complete. All data arrived\nencrypted and secure.\n\nThe attackers got nothing but gibberish.\n\nYou've proven that proper symmetric encryption,\nwith strong keys kept secret,\nis an impenetrable shield.\"[/color]\n\n[color=yellow]FINAL SCORE: " + str(security_score) + "[/color]\n\nYou are now a certified encryption specialist.\n\n[color=lime]SecureComm Industries thanks you for your service.[/color][/center]"
	
	story_panel.visible = true
	game_ui.visible = false
	$StoryPanel/ContinueButton.text = "PLAY AGAIN"
	$StoryPanel/ContinueButton.pressed.disconnect(_on_continue_button_pressed)
	$StoryPanel/ContinueButton.pressed.connect(restart_game)

func restart_game():
	get_tree().reload_current_scene()