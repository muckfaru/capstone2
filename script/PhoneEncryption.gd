extends Control

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

# NEW: Track key usage and patterns
var used_keys = []  # Keys already used this game
var consecutive_similar_keys = 0  # How many similar keys in a row
var key_strength_history = []  # Track strength of keys used
# NEW: Track recently used messages to avoid repetition
var recent_boss_messages = []
var recent_player_replies = []
var max_recent_messages = 5  # Remember last 5 messages

# Custom Key Encryption
var encryption_key = ""
var boss_encrypted_message = ""
var boss_decrypted_message = ""
var player_message = ""
var player_encrypted_message = ""

# Message index
var message_index = 0
var messages_per_level = 3

# Mission-specific boss messages
var boss_messages_by_mission = {
	1: [  # Mission 1 - Introduction/Simple jobs
		"Meet me at pier 9 tonight",
		"Package delivered successfully",
		"Payment confirmed",
		"New contact in the morning",
		"Everything looks clear"
	],
	2: [  # Mission 2 - Things get serious
		"New target: Victor Morales",
		"Surveillance team spotted",
		"Change safe house now",
		"Police are getting close",
		"Asset secured successfully"
	],
	3: [  # Mission 3 - High stakes
		"Eliminate the witness",
		"Document retrieval urgent",
		"Transfer complete by midnight",
		"They know about the pier",
		"Switch to backup protocol"
	],
	4: [  # Mission 4 - Critical operations
		"Abort mission immediately",
		"Extract at 0200 hours",
		"Target has been relocated",
		"Federal agents involved now",
		"Burn the safe house"
	],
	5: [  # Mission 5 - Final mission
		"Burn all evidence",
		"Final job. Disappear after",
		"Prepare extraction plan B",
		"This is your last assignment",
		"Leave the country tonight"
	]
}

var player_replies_by_mission = {
	1: [  # Mission 1 - Professional
		"Understood boss",
		"Package confirmed",
		"Payment received",
		"Contact established",
		"All clear on my end"
	],
	2: [  # Mission 2 - Alert
		"Target acquired",
		"Surveillance evaded",
		"Moving to new location",
		"Staying under the radar",
		"Asset in custody"
	],
	3: [  # Mission 3 - Tense
		"Witness neutralized",
		"Documents secured",
		"Transfer initiated",
		"Situation handled",
		"Protocol activated"
	],
	4: [  # Mission 4 - Urgent
		"Mission aborted",
		"En route to extraction",
		"New position acquired",
		"Understood. Moving fast",
		"Safe house abandoned"
	],
	5: [  # Mission 5 - Final
		"Everything burned",
		"Copy that boss",
		"Plan B ready",
		"Getting out now",
		"This is goodbye"
	]
}

# NEW: Enhanced police AI
var police_common_keys = ["123", "ABC", "KEY", "PASS", "SAFE", "CODE", "LOCK", "HIDE", "BOSS", "KILL"]
var police_learned_patterns = []  # Police learn from your patterns
var police_crack_multiplier = 1.0  # Increases if you repeat patterns

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

func _ready():
	# Ensure victory panel exists and is hidden
	if victory_panel:
		victory_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false
	start_tutorial()

# ============================================================================
# TUTORIAL SYSTEM
# ============================================================================

func start_tutorial():
	current_mode = GameMode.TUTORIAL
	tutorial_step = 0
	tutorial_panel.visible = true
	phone_screen.visible = false
	police_panel.visible = false
	encryption_demo.visible = false
	
	show_tutorial_step()

func show_tutorial_step():
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
			tutorial_continue.text = ""
		
		3:
			tutorial_title.text = "👮 THE ENEMY: ADAPTIVE AI"
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
	tutorial_step += 1
	
	if tutorial_step >= 4:
		tutorial_panel.visible = false
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
	start_level(1)

func start_level(level: int):
	current_level = level
	message_index = 0
	encryption_key = ""
	
	level_label.text = "MISSION %d" % level
	update_ui()
	
	clear_chat()

	# Mission-specific introduction messages
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
	
	add_system_message("🔑 Create your encryption key (3-6 characters):")
	
	# Show key creation panel
	key_creation_panel.visible = true
	incoming_message.visible = false
	reply_panel.visible = false
	
	key_input.text = ""
	key_input.editable = true
	create_key_button.disabled = false
	create_key_button.text = ""
	key_input.grab_focus()

# NEW: Enhanced key validation with pattern detection
func _on_create_key_button_pressed():
	var entered_key = key_input.text.strip_edges().to_upper()
	
	# Basic validation
	if entered_key.length() < 3:
		show_notification("❌ Key must be at least 3 characters!")
		return
	
	if entered_key.length() > 6:
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
		show_notification("❌ Key must contain only letters and numbers!")
		return
	
	# NEW: Check if key was already used
	if entered_key in used_keys:
		show_notification("🚨 KEY REUSED! Police detected pattern!")
		add_system_message("⚠️ Police cracked it instantly - they were watching for reused keys!")
		lose_heart()
		if hearts_remaining <= 0:
			return
		await get_tree().create_timer(2.0).timeout
		return
	
	# NEW: Check key strength
	var strength = calculate_key_strength(entered_key)
	
	if strength < 0.3:
		show_notification("⚠️ Weak key! Police will crack this easily!")
		add_system_message("💡 Tip: Mix letters & numbers, avoid patterns like ABC or 123")
		# Don't reject, but warn
	
	# NEW: Check for similar patterns
	if is_similar_to_previous_keys(entered_key):
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
	
	key_input.editable = false
	create_key_button.disabled = true
	
	add_system_message("✅ Encryption key created!")
	add_system_message("⚠️ REMEMBER YOUR KEY! You'll need it to decrypt!")
	
	if strength < 0.3:
		add_system_message("⚠️ Your key is weak - police crack chance: HIGH")
	elif strength < 0.6:
		add_system_message("✓ Your key is moderate - police crack chance: MEDIUM")
	else:
		add_system_message("✓ Your key is strong - police crack chance: LOW")
	
	current_key_display.visible = false
	
	await get_tree().create_timer(2.0).timeout
	
	key_creation_panel.visible = false
	send_encrypted_message_to_boss()

# NEW: Calculate key strength (0.0 to 1.0)
func calculate_key_strength(key: String) -> float:
	var strength = 0.0
	
	# Length bonus
	strength += (key.length() - 3) * 0.15  # Max 0.45 for length 6
	
	# Character variety
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
	
	# Unique characters bonus
	strength += (float(unique_chars.size()) / key.length()) * 0.2
	
	# Check for common patterns (penalty)
	if is_sequential(key):
		strength -= 0.4
	
	if is_repeating(key):
		strength -= 0.3
	
	# Check against common keys
	if key in police_common_keys:
		strength = 0.0
	
	return clamp(strength, 0.0, 1.0)

# NEW: Check if key is sequential (ABC, 123, etc.)
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

# NEW: Check if key has repeating patterns (AAA, 111, ABAB)
func is_repeating(key: String) -> bool:
	# Check for same character repeated
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
	
	# Check for pattern repetition (ABAB)
	if key.length() >= 4:
		var half = key.length() / 2
		var first_half = key.substr(0, half)
		var second_half = key.substr(half, half)
		if first_half == second_half:
			return true
	
	return false

# NEW: Check if key is similar to previous keys
func is_similar_to_previous_keys(key: String) -> bool:
	if used_keys.size() == 0:
		return false
	
	# Check last 3 keys
	var recent_keys = used_keys.slice(max(0, used_keys.size() - 3), used_keys.size())
	
	for prev_key in recent_keys:
		# Check if same length and mostly same characters
		if key.length() == prev_key.length():
			var same_chars = 0
			for i in range(key.length()):
				if i < prev_key.length() and key[i] == prev_key[i]:
					same_chars += 1
			
			# If 60%+ characters are in same position, it's similar
			if float(same_chars) / key.length() >= 0.6:
				return true
		
		# Check if it's just one character different
		if key.length() == prev_key.length():
			var diff_count = 0
			for i in range(key.length()):
				if i < prev_key.length() and key[i] != prev_key[i]:
					diff_count += 1
			
			if diff_count <= 1:
				return true
	
	return false

func send_encrypted_message_to_boss():
	add_system_message("📤 Sending encrypted message to boss...")
	
	var initial_message = "Ready for orders"
	var encrypted = encrypt_xor(initial_message, encryption_key)
	
	add_player_message("🔒 " + encrypted)
	score += 20
	update_ui()
	
	await get_tree().create_timer(1.5).timeout
	
	police_intercept_player_key()
# NEW: Get a random message that hasn't been used recently
# NEW: Get a random message that hasn't been used recently (mission-specific)
func get_unique_message(message_pool_dict: Dictionary, mission_level: int, recent_list: Array) -> String:
	# Get messages for current mission
	var message_pool = message_pool_dict.get(mission_level, message_pool_dict[1])
	var available_messages = []
	
	# Find messages not recently used
	for msg in message_pool:
		if msg not in recent_list:
			available_messages.append(msg)
	
	# If all messages were recently used, clear history and use any
	if available_messages.size() == 0:
		recent_list.clear()
		available_messages = message_pool.duplicate()
	
	# Pick random from available
	var selected = available_messages[randi() % available_messages.size()]
	
	# Track this message
	recent_list.append(selected)
	if recent_list.size() > max_recent_messages:
		recent_list.pop_front()  # Remove oldest
	
	return selected

func police_intercept_player_key():
	police_panel.modulate = Color.WHITE
	police_status.text = "🚨 INTERCEPTED!"
	police_text.text = "Adaptive AI analyzing..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	# NEW: Police use learned patterns + common keys
	var test_keys = generate_police_test_keys()
	
	var key_strength = calculate_key_strength(encryption_key)
	var base_crack_chance = 0.1 + (0.15 * current_level)
	
	# Adjust based on key strength
	if key_strength < 0.3:
		base_crack_chance += 0.4
	elif key_strength < 0.6:
		base_crack_chance += 0.2
	
	# Apply pattern multiplier
	base_crack_chance *= police_crack_multiplier
	
	for i in range(test_keys.size()):
		var test_key = test_keys[i]
		police_attempts.text = "AI Testing: %s..." % test_key
		cracking_bar.value = (float(i + 1) / test_keys.size()) * 100
		await get_tree().create_timer(0.4).timeout
		
		if test_key == encryption_key:
			if randf() < base_crack_chance:
				# CRACKED!
				police_status.text = "💀 KEY CRACKED!"
				police_text.text = "AI learned your pattern!"
				police_attempts.text = "Discovered: " + encryption_key
				police_panel.modulate = Color.RED
				
				# Police learn from this
				police_learned_patterns.append(encryption_key)
				
				show_notification("🚔 Police AI cracked your key!")
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
	police_status.text = "✅ ENCRYPTION SECURE"
	police_text.text = "AI couldn't crack it"
	police_attempts.text = "Pattern unrecognized"
	police_panel.modulate = Color.GREEN
	
	var bonus = int(key_strength * 100)
	show_notification("✅ Key secure! Bonus: +%d" % bonus)
	score += 50 + bonus
	update_ui()
	
	await get_tree().create_timer(2.0).timeout
	
	police_panel.modulate = Color.WHITE
	police_status.text = "MONITORING"
	police_text.text = "Analyzing patterns..."
	police_attempts.text = ""
	cracking_bar.value = 0
	
	receive_boss_message()

# NEW: Generate smart test keys based on player patterns
func generate_police_test_keys() -> Array:
	var test_keys = []
	
	# Start with common keys
	test_keys.append_array(police_common_keys.duplicate())
	
	# Add previously cracked keys
	test_keys.append_array(police_learned_patterns.duplicate())
	
	# Generate variations of previous player keys
	for prev_key in used_keys:
		# Try incrementing last character
		if prev_key.length() > 0:
			var variant = prev_key.substr(0, prev_key.length() - 1)
			var last_char = prev_key[prev_key.length() - 1]
			var code = last_char.unicode_at(0)
			variant += char(code + 1)
			test_keys.append(variant)
		
		# Try decrementing
		if prev_key.length() > 0:
			var variant2 = prev_key.substr(0, prev_key.length() - 1)
			var last_char2 = prev_key[prev_key.length() - 1]
			var code2 = last_char2.unicode_at(0)
			variant2 += char(code2 - 1)
			test_keys.append(variant2)
	
	# Remove duplicates and limit
	var unique_keys = {}
	for key in test_keys:
		unique_keys[key] = true
	
	test_keys = unique_keys.keys()
	test_keys.shuffle()
	
	# Limit to reasonable number
	if test_keys.size() > 12:
		test_keys = test_keys.slice(0, 12)
	
	return test_keys

func receive_boss_message():
	message_index += 1
	current_state = ChatState.WAITING_BOSS
	
	add_system_message("📩 Boss is sending encrypted reply...")
	
	await get_tree().create_timer(1.0).timeout
	
	boss_decrypted_message = get_unique_message(boss_messages_by_mission, current_level, recent_boss_messages)
	boss_encrypted_message = encrypt_xor(boss_decrypted_message, encryption_key)
	
	incoming_message.visible = true
	key_creation_panel.visible = false
	reply_panel.visible = false
	
	encrypted_text.text = "" + boss_encrypted_message
	decrypted_text.text = ""
	decrypted_text.visible = false
	decrypt_button.disabled = false
	decrypt_button.text = ""
	decrypt_key_input.text = ""
	decrypt_key_input.editable = true
	
	add_system_message("🔐 Encrypted message received!")
	add_system_message("💡 Enter YOUR key to decrypt!")
	
	current_state = ChatState.READING_MESSAGE
	decrypt_key_input.grab_focus()

func _on_decrypt_button_pressed():
	var entered_key = decrypt_key_input.text.strip_edges().to_upper()
	
	if entered_key == "":
		show_notification("❌ Enter your encryption key!")
		return
	
	var decrypted = decrypt_xor(boss_encrypted_message, entered_key)
	
	if entered_key == encryption_key:
		# Correct!
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
	
	add_system_message("📝 Sending encrypted reply...")
	
	current_state = ChatState.TYPING_REPLY
	
	await get_tree().create_timer(1.5).timeout
	_on_send_button_pressed()

func _on_send_button_pressed():
	if send_button.disabled:
		return
	
	player_encrypted_message = encrypt_xor(player_message, encryption_key)
	
	send_button.disabled = true
	add_player_message("" + player_encrypted_message)
	
	score += 30
	update_ui()
	
	current_state = ChatState.SENDING
	
	await get_tree().create_timer(1.0).timeout
	
	police_intercept_reply()

func police_intercept_reply():
	current_state = ChatState.POLICE_CHECKING
	
	police_panel.modulate = Color.WHITE
	police_status.text = "🚨 INTERCEPTED REPLY!"
	police_text.text = "AI Cross-referencing..."
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
		police_attempts.text = "AI Testing: %s..." % test_key
		cracking_bar.value = (float(i + 1) / test_keys.size()) * 100
		await get_tree().create_timer(0.4).timeout
		
		if test_key == encryption_key:
			if randf() < base_crack_chance:
				# CRACKED!
				var decrypted = decrypt_xor(player_encrypted_message, encryption_key)
				police_status.text = "💀 MESSAGE CRACKED!"
				police_text.text = "AI Success!"
				police_attempts.text = "Decrypted: \"%s\"" % decrypted
				police_panel.modulate = Color.RED
				
				police_learned_patterns.append(encryption_key)
				
				show_notification("🚔 Police AI cracked your message!")
				lose_heart()
				
				await get_tree().create_timer(3.0).timeout
				
				if hearts_remaining <= 0:
					return
				
				police_panel.modulate = Color.WHITE
				police_status.text = "👮 MONITORING"
				police_text.text = "AI learning..."
				police_attempts.text = ""
				cracking_bar.value = 0
				
				check_level_progress()
				return
	
	# Safe!
	cracking_bar.value = 100
	police_status.text = "✅ STILL SECURE"
	police_text.text = "AI defeated"
	police_attempts.text = "Pattern too complex"
	police_panel.modulate = Color.GREEN
	
	var bonus = int(key_strength * 150)
	show_notification("✅ Message secure! Bonus: +%d" % bonus)
	score += 100 + bonus
	update_ui()
	
	await get_tree().create_timer(2.0).timeout
	
	police_panel.modulate = Color.WHITE
	police_status.text = "👮 MONITORING"
	police_text.text = "AI adapting..."
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
		add_system_message("🔄 Next message - NEW UNIQUE key required!")
		await get_tree().create_timer(1.0).timeout
		player_create_encryption_key()

func complete_level():
	# Mission-specific completion messages
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
# UI HELPER FUNCTIONS
# ============================================================================

func clear_chat():
	for child in chat_display.get_children():
		child.queue_free()

func add_system_message(text: String):
	var label = Label.new()
	label.text = "⚙️ " + text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_display.add_child(label)
	await get_tree().create_timer(0.1).timeout
	chat_display.get_parent().scroll_vertical = int(chat_display.size.y)

func add_player_message(text: String):
	var label = Label.new()
	label.text = "YOU: " + text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_display.add_child(label)
	await get_tree().create_timer(0.1).timeout
	chat_display.get_parent().scroll_vertical = int(chat_display.size.y)

func add_boss_message(text: String):
	var label = Label.new()
	label.text = "BOSS: " + text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_display.add_child(label)
	await get_tree().create_timer(0.1).timeout
	chat_display.get_parent().scroll_vertical = int(chat_display.size.y)

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
	score_label.text = "💰 $%d" % score
	level_label.text = "MISSION %d" % current_level
	
	# Update hearts
	for i in range(hearts_container.get_child_count()):
		var heart = hearts_container.get_child(i)
		if i < hearts_remaining:
			heart.modulate = Color.WHITE
		else:
			heart.modulate = Color(0.3, 0.3, 0.3)

func lose_heart():
	hearts_remaining -= 1
	update_ui()
	
	if hearts_remaining <= 0:
		game_over()

func game_over():
	add_system_message("💀 GAME OVER - ALL LIVES LOST!")
	
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

The AI learned your patterns.
You need to be more UNPREDICTABLE!

Tips:
✓ Never reuse keys
✓ Avoid patterns (ABC, 123, etc.)
✓ Mix letters & numbers creatively
✓ Stay random and unpredictable""" % [final_score, messages_sent, current_level, max_levels]

func victory():
	if not victory_panel:
		return
	
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
	# Reset game state
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
	
	# Restart tutorial
	start_tutorial()

func _on_quit_button_pressed():
	# Return to main menu or quit
	get_tree().change_scene_to_file("res://scene/2ndloading.tscn")