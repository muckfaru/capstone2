extends Control

# ==========================================
# CIPHER SHIELD - Symmetric Encryption Game
# ==========================================

# Signals
signal encryption_completed(success: bool)
signal transmission_intercepted(data_compromised: bool)
signal decryption_attempted(key_correct: bool)
signal security_breach()

# Game State
enum GameState {
	WAITING_FOR_MESSAGE,
	ENCRYPTING,
	TRANSMITTING,
	INTERCEPTED,
	DECRYPTING,
	SUCCESS,
	FAILED
}

var current_state: GameState = GameState.WAITING_FOR_MESSAGE

# Data variables
var current_message: String = ""
var encryption_key: String = ""
var encrypted_data: String = ""
var is_encrypted: bool = false

# Game variables
var security_score: int = 0
var messages_protected: int = 0
var interceptions_blocked: int = 0
var level: int = 1
var messages_to_complete: int = 3
var current_message_index: int = 0

# Message pools for different levels
var level_messages = {
	1: ["HELLO", "TEST", "SECURE"],
	2: ["TRANSFER FUNDS", "CONFIDENTIAL DATA", "SECURITY KEY", "PATIENT RECORDS", "LAUNCH CODE"],
	3: ["MERGER ANNOUNCEMENT", "FINANCIAL REPORT Q3", "EMPLOYEE SALARIES", "CUSTOMER DATABASE"],
	4: ["CLASSIFIED INTEL", "NUCLEAR CODES", "PRESIDENTIAL BRIEFING"],
}

# Timer for transmission
var transmission_timer: float = 0.0
var transmission_duration: float = 3.0

# Visual state
var is_transmitting: bool = false
var packet_position: float = 0.0

# Interception
var interception_chance: float = 0.0
var interception_triggered: bool = false

# Node references (will be set in _ready)
@onready var plaintext_label = $SenderPanel/VBox/PlaintextLabel
@onready var encrypted_label = $ReceiverPanel/VBox/EncryptedLabel
@onready var key_input = $KeyControls/VBox/KeyInput
@onready var key_strength_bar = $KeyControls/VBox/KeyStrengthBar
@onready var encrypt_button = $KeyControls/VBox/EncryptButton
@onready var decrypt_button = $KeyControls/VBox/DecryptButton
@onready var generate_key_button = $KeyControls/VBox/GenerateKeyButton
@onready var score_label = $SecurityDashboard/ScoreLabel
@onready var status_label = $SecurityDashboard/StatusLabel
@onready var integrity_meter = $SecurityDashboard/IntegrityMeter
@onready var data_packet = $TransmissionChannel/DataPacket
@onready var interceptor_alert = $TransmissionChannel/InterceptorAlert
@onready var attacker_view = $AttackerView
@onready var stolen_data_label = $AttackerView/VBox/StolenDataLabel
@onready var level_label = $LevelInfo/LevelLabel
@onready var objective_label = $LevelInfo/ObjectiveLabel
@onready var transmission_channel = $TransmissionChannel

func _ready():
	# Connect signals
	encryption_completed.connect(_on_encryption_complete)
	transmission_intercepted.connect(_on_interception)
	decryption_attempted.connect(_on_decrypt_result)
	security_breach.connect(_on_security_breach)
	
	# Connect button signals
	encrypt_button.pressed.connect(_on_encrypt_button_pressed)
	decrypt_button.pressed.connect(_on_decrypt_button_pressed)
	generate_key_button.pressed.connect(_on_generate_key_button_pressed)
	key_input.text_changed.connect(_on_key_input_text_changed)
	
	# Initialize game
	initialize_level()
	load_next_message()
	update_ui()

func _process(delta):
	if is_transmitting:
		transmission_timer += delta
		packet_position = (transmission_timer / transmission_duration)
		
		# Update packet position
		data_packet.position.x = lerp(50.0, 750.0, packet_position)
		
		# Check for interception midway
		if packet_position >= 0.5 and not interception_triggered and randf() < interception_chance:
			interception_triggered = true
			trigger_interception()
		
		# Transmission complete
		if transmission_timer >= transmission_duration:
			complete_transmission()

func initialize_level():
	match level:
		1:
			messages_to_complete = 3
			interception_chance = 0.0
			status_label.text = "LEVEL 1: BASIC TRAINING"
		2:
			messages_to_complete = 5
			interception_chance = 0.5
			status_label.text = "LEVEL 2: FIRST INTERCEPTION"
		3:
			messages_to_complete = 5
			interception_chance = 0.6
			status_label.text = "LEVEL 3: KEY STRENGTH MATTERS"
		_:
			messages_to_complete = 3
			interception_chance = 0.4
			status_label.text = "LEVEL " + str(level)
	
	current_message_index = 0
	level_label.text = "LEVEL " + str(level)
	objective_label.text = "Protect " + str(messages_to_complete) + " messages"

func load_next_message():
	# Get message pool for current level
	var messages = level_messages.get(level, level_messages[1])
	
	if current_message_index >= messages_to_complete:
		level_complete()
		return
	
	# Load random message from pool
	current_message = messages[randi() % messages.size()]
	plaintext_label.text = "[color=white][b]" + current_message + "[/b][/color]"
	encrypted_label.text = "[color=gray][i]Waiting for decryption...[/i][/color]"
	
	# Reset state
	is_encrypted = false
	encryption_key = ""
	encrypted_data = ""
	key_input.text = ""
	key_input.editable = true
	
	# Reset transmission
	is_transmitting = false
	transmission_timer = 0.0
	packet_position = 0.0
	interception_triggered = false
	data_packet.visible = false
	interceptor_alert.visible = false
	attacker_view.visible = false
	
	# Update buttons
	encrypt_button.disabled = false
	decrypt_button.disabled = true
	
	current_state = GameState.WAITING_FOR_MESSAGE
	update_ui()

# ==========================================
# ENCRYPTION/DECRYPTION LOGIC
# ==========================================

func encrypt_message(plaintext: String, key: String) -> String:
	# Simple XOR-based encryption simulation
	var encrypted = ""
	for i in range(plaintext.length()):
		var char_code = plaintext.unicode_at(i)
		var key_char = key.unicode_at(i % key.length())
		var encrypted_code = (char_code + key_char) % 256
		encrypted += get_symbol_for_code(encrypted_code)
	return encrypted

func decrypt_message(ciphertext: String, input_key: String) -> String:
	# Reverse the encryption using the provided key
	var decrypted = ""
	for i in range(ciphertext.length()):
		var symbol = ciphertext[i]
		var encrypted_code = get_code_for_symbol(symbol)
		var key_char = input_key.unicode_at(i % input_key.length())
		var char_code = (encrypted_code - key_char + 256) % 256
		decrypted += char(char_code)
	return decrypted

func get_symbol_for_code(code: int) -> String:
	# Convert to visual encrypted symbols
	var symbols = ["⬡", "◆", "◈", "⬢", "◉", "⬣", "◇", "⬟", "◊", "⬠", "◈", "⬤", "◐", "◑", "◒", "◓"]
	return symbols[code % symbols.size()]

func get_code_for_symbol(symbol: String) -> int:
	# Reverse mapping
	var symbols = ["⬡", "◆", "◈", "⬢", "◉", "⬣", "◇", "⬟", "◊", "⬠", "◈", "⬤", "◐", "◑", "◒", "◓"]
	var idx = symbols.find(symbol)
	return idx if idx != -1 else 0

# ==========================================
# KEY MANAGEMENT
# ==========================================

func evaluate_key_strength(key: String) -> float:
	if key.length() == 0:
		return 0.0
	
	var score = 0.0
	
	# Length bonus (max 50 points)
	score += min(key.length() * 6, 50)
	
	# Mixed case bonus
	if key != key.to_lower() and key != key.to_upper():
		score += 20
	
	# Contains numbers
	var has_number = false
	for c in key:
		if c.is_valid_int():
			has_number = true
			break
	if has_number:
		score += 15
	
	# Contains special characters
	var has_special = false
	for c in key:
		if not c.is_valid_identifier():
			has_special = true
			break
	if has_special:
		score += 15
	
	return clamp(score, 0, 100)

func generate_random_key() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%"
	var key = ""
	for i in range(10):
		key += chars[randi() % chars.length()]
	return key

# ==========================================
# BUTTON HANDLERS
# ==========================================

func _on_encrypt_button_pressed():
	var key = key_input.text
	
	if key.length() < 4:
		show_error("Key too weak! Must be at least 4 characters.")
		return
	
	# Check key strength for level 3+
	if level >= 3:
		var strength = evaluate_key_strength(key)
		if strength < 60:
			show_error("Key too weak! Use longer keys with mixed case and numbers.")
			return
	
	# Encrypt the message
	encryption_key = key
	encrypted_data = encrypt_message(current_message, encryption_key)
	is_encrypted = true
	
	# Visual feedback
	animate_encryption()
	
	current_state = GameState.ENCRYPTING
	encrypt_button.disabled = true
	key_input.editable = false
	
	# Start transmission after brief delay
	await get_tree().create_timer(0.5).timeout
	start_transmission()
	
	encryption_completed.emit(true)

func _on_decrypt_button_pressed():
	var input_key = key_input.text
	
	if input_key.length() == 0:
		show_error("Enter the decryption key!")
		return
	
	current_state = GameState.DECRYPTING
	
	# Attempt decryption
	var result = decrypt_message(encrypted_data, input_key)
	
	# Check if decryption was successful
	if input_key == encryption_key:
		# Correct key
		animate_decryption_success(result)
		security_score += 100
		messages_protected += 1
		
		show_success("✓ DECRYPTION SUCCESSFUL!")
		decryption_attempted.emit(true)
		
		# Load next message after delay
		await get_tree().create_timer(2.0).timeout
		current_message_index += 1
		load_next_message()
	else:
		# Wrong key
		animate_decryption_failure()
		security_score -= 50
		
		show_error("✗ INVALID KEY - Data corrupted!")
		decryption_attempted.emit(false)
		
		# Allow retry
		await get_tree().create_timer(1.5).timeout
		decrypt_button.disabled = false

func _on_generate_key_button_pressed():
	key_input.text = generate_random_key()
	_on_key_input_text_changed(key_input.text)

func _on_key_input_text_changed(new_text: String):
	var strength = evaluate_key_strength(new_text)
	key_strength_bar.value = strength
	
	# Color code strength
	if strength < 40:
		key_strength_bar.modulate = Color(1, 0.2, 0.2)  # Red
	elif strength < 70:
		key_strength_bar.modulate = Color(1, 1, 0.2)  # Yellow
	else:
		key_strength_bar.modulate = Color(0.2, 1, 0.2)  # Green

# ==========================================
# TRANSMISSION & INTERCEPTION
# ==========================================

func start_transmission():
	is_transmitting = true
	transmission_timer = 0.0
	packet_position = 0.0
	interception_triggered = false
	
	data_packet.visible = true
	data_packet.position.x = 50
	
	current_state = GameState.TRANSMITTING

func complete_transmission():
	is_transmitting = false
	data_packet.visible = false
	
	# Show encrypted data at receiver
	encrypted_label.text = "[color=cyan][b]" + encrypted_data + "[/b][/color]"
	
	# Enable decryption
	decrypt_button.disabled = false
	key_input.editable = true
	key_input.text = ""
	
	status_label.text = "Enter decryption key"

func trigger_interception():
	interceptor_alert.visible = true
	attacker_view.visible = true
	
	if is_encrypted:
		# Data is encrypted - safe!
		stolen_data_label.text = "[color=cyan]" + encrypted_data + "[/color]\n\n[color=green]ENCRYPTED - UNREADABLE[/color]"
		show_feedback("⚠ INTERCEPTED! But data is encrypted - SAFE!", Color(1, 0.8, 0))
		interceptions_blocked += 1
		security_score += 50
		transmission_intercepted.emit(false)
	else:
		# Data is NOT encrypted - BREACH!
		stolen_data_label.text = "[color=white]" + current_message + "[/color]\n\n[color=red]UNENCRYPTED - STOLEN![/color]"
		show_feedback("🚨 SECURITY BREACH! Data stolen!", Color(1, 0, 0))
		security_score -= 200
		transmission_intercepted.emit(true)
		security_breach.emit()
		
		# Game over after delay
		await get_tree().create_timer(3.0).timeout
		game_over()

# ==========================================
# ANIMATIONS
# ==========================================

func animate_encryption():
	# Scramble animation
	var original_text = plaintext_label.text
	for i in range(10):
		var scrambled = ""
		for j in range(current_message.length()):
			scrambled += get_symbol_for_code(randi() % 256)
		plaintext_label.text = "[color=cyan]" + scrambled + "[/color]"
		await get_tree().create_timer(0.05).timeout
	
	# Final encrypted state
	plaintext_label.text = "[color=cyan][b]🔒 " + encrypted_data + "[/b][/color]"
	data_packet.modulate = Color(0.3, 0.8, 1.0)  # Cyan glow

func animate_decryption_success(decrypted_text: String):
	# Unscramble animation
	for i in range(10):
		var scrambled = ""
		for j in range(encrypted_data.length()):
			scrambled += get_symbol_for_code(randi() % 256)
		encrypted_label.text = "[color=white]" + scrambled + "[/color]"
		await get_tree().create_timer(0.05).timeout
	
	# Show decrypted message
	encrypted_label.text = "[color=green][b]🔓 " + decrypted_text + "[/b][/color]"

func animate_decryption_failure():
	# Glitch effect
	for i in range(8):
		var glitched = ""
		for j in range(encrypted_data.length()):
			if randf() < 0.5:
				glitched += ["#", "@", "%", "!", "?", "╬", "⚠"][randi() % 7]
			else:
				glitched += encrypted_data[j]
		encrypted_label.text = "[color=red]" + glitched + "[/color]"
		await get_tree().create_timer(0.08).timeout
	
	encrypted_label.text = "[color=red][b]⚠ CORRUPTED DATA[/b][/color]"

# ==========================================
# FEEDBACK & UI
# ==========================================

func show_success(message: String):
	status_label.text = message
	status_label.modulate = Color(0.2, 1, 0.2)
	await get_tree().create_timer(0.5).timeout
	status_label.modulate = Color(1, 1, 1)

func show_error(message: String):
	status_label.text = message
	status_label.modulate = Color(1, 0.2, 0.2)
	await get_tree().create_timer(0.5).timeout
	status_label.modulate = Color(1, 1, 1)

func show_feedback(message: String, color: Color):
	status_label.text = message
	status_label.modulate = color
	await get_tree().create_timer(1.5).timeout
	status_label.modulate = Color(1, 1, 1)

func update_ui():
	score_label.text = "SCORE: " + str(security_score)
	
	var integrity = clamp(100 - (current_message_index * 10), 0, 100)
	integrity_meter.value = integrity
	
	objective_label.text = "Protected: " + str(messages_protected) + "/" + str(messages_to_complete)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_encryption_complete(success: bool):
	if success:
		update_ui()

func _on_interception(data_compromised: bool):
	update_ui()

func _on_decrypt_result(key_correct: bool):
	update_ui()

func _on_security_breach():
	integrity_meter.value = 0

# ==========================================
# LEVEL MANAGEMENT
# ==========================================

func level_complete():
	show_success("🎉 LEVEL COMPLETE! All messages protected!")
	
	await get_tree().create_timer(2.0).timeout
	
	level += 1
	initialize_level()
	load_next_message()

func game_over():
	current_state = GameState.FAILED
	encrypt_button.disabled = true
	decrypt_button.disabled = true
	
	status_label.text = "💀 MISSION FAILED - RESTART LEVEL"
	
	await get_tree().create_timer(3.0).timeout
	
	# Reset level
	security_score = max(0, security_score - 300)
	messages_protected = 0
	interceptions_blocked = 0
	initialize_level()
	load_next_message()