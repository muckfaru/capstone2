extends Control

# ============================================
# CIPHER WHEEL - Interactive Caesar Cipher Tutorial
# Visual drag-and-drop learning for beginners
# ============================================

enum Phase {
	INTRO,
	LEARN_WHEEL,
	PRACTICE_MODE,
	CHALLENGE_MODE,
	RANSOMWARE_EXPLANATION,
	COMPLETE
}

var current_phase = Phase.INTRO
var score := 0
var max_score := 350  # Total possible score
var practice_completed := 0
var challenge_attempts := 0
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0
var _highest_phase_reached := 0  # Track progress for partial XP

# Cipher wheel state
var current_shift := 3
var is_dragging := false
var drag_start_angle := 0.0
var wheel_rotation := 0.0

# Practice messages (easy - shift 3)
var practice_messages := [
	{"plain": "HELLO", "encrypted": "KHOOR", "key": 3},
	{"plain": "WORLD", "encrypted": "ZRUOG", "key": 3},
	{"plain": "CODE", "encrypted": "FRGH", "key": 3}
]
var current_practice_index := 0

# Challenge messages (increasing difficulty with different shift keys)
var challenge_messages := [
	# Easy: Shift 3
	{"plain": "SAFE", "encrypted": "VDIH", "key": 3},
	{"plain": "SECRET", "encrypted": "VHFUHW", "key": 3},
	# Medium: Shift 5
	{"plain": "GUARD", "encrypted": "LZFWI", "key": 5},
	{"plain": "VIRUS", "encrypted": "ANWZX", "key": 5},
	# Hard: Shift 7
	{"plain": "HACK", "encrypted": "OHJR", "key": 7},
	{"plain": "FIREWALL", "encrypted": "MPYLDHSS", "key": 7},
]
var current_challenge_index := 0

# Alphabet for reference
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Node references
@onready var section_label = $WindowDialog/VBox/TitleBar/MarginContainer/VBoxContainer/SectionLabel
@onready var content_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var cipher_type_label = $WindowDialog/VBox/TitleBar/MarginContainer/VBoxContainer/CipherTypeLabel
@onready var next_button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton

# Interactive panels
@onready var wheel_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel
@onready var practice_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/PracticePanel
@onready var challenge_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel

# Wheel elements
@onready var shift_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/ShiftLabel
@onready var alphabet_reference = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/AlphabetReference
@onready var visual_demo = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/VisualDemo
@onready var alphabet_container = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/VisualDemo/MarginContainer/VBox/AlphabetContainer
@onready var demo_result_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/VisualDemo/MarginContainer/VBox/ResultLabel
@onready var demo_example_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/WheelPanel/VBox/VisualDemo/MarginContainer/VBox/ExampleLabel

# Practice elements
@onready var practice_encrypted_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/PracticePanel/VBox/EncryptedLabel
@onready var practice_slots_container = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/PracticePanel/VBox/SlotsContainer
@onready var practice_hint_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/PracticePanel/VBox/HintLabel

# Challenge elements
@onready var challenge_encrypted_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/EncryptedLabel
@onready var challenge_input = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/AnswerInput
@onready var challenge_submit = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/SubmitButton
@onready var challenge_feedback = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/FeedbackLabel


func _ready() -> void:
	print("🔐 Cipher Wheel Tutorial Ready")
	
	# Detect multiplayer game mode
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[GameMode] Encryption Basics running in multiplayer game mode (room: %s)" % _gamemode_room_code)
	
	# Wait for nodes to be ready
	await get_tree().process_frame
	
	# Hide all interactive panels initially
	if wheel_panel:
		wheel_panel.visible = false
	if practice_panel:
		practice_panel.visible = false
	if challenge_panel:
		challenge_panel.visible = false
	if visual_demo:
		visual_demo.visible = false
	
	# Connect buttons
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if challenge_submit:
		challenge_submit.pressed.connect(_on_challenge_submit)
	
	# Start tutorial
	_start_phase(Phase.INTRO)


func _start_phase(phase: Phase) -> void:
	current_phase = phase
	
	# Hide all panels safely
	if wheel_panel:
		wheel_panel.visible = false
	if practice_panel:
		practice_panel.visible = false
	if challenge_panel:
		challenge_panel.visible = false
	if visual_demo:
		visual_demo.visible = false
	if alphabet_reference:
		alphabet_reference.visible = true
	
	if next_button:
		next_button.disabled = false
	
	match phase:
		Phase.INTRO:
			section_label.text = "🔐 Introduction to Caesar Cipher"
			cipher_type_label.text = "Cryptography Type: SUBSTITUTION CIPHER"
			content_label.text = """WELCOME TO CIPHER WHEEL!

Learn the CAESAR CIPHER - one of the oldest encryption methods!

🎯 WHAT IS A CAESAR CIPHER?
A cipher that shifts each letter by a fixed number.

📝 SIMPLE EXAMPLE:
Let's encrypt the letter "H" with SHIFT = 3

H → Move 3 steps forward → K

Think of it like counting:
H (start) → I (1) → J (2) → K (3) ✓

🔑 THE SECRET KEY:
The "shift number" (3) is the SECRET KEY!
Without the key, messages look like gibberish.

Click NEXT to see it in action →"""

		Phase.LEARN_WHEEL:
			section_label.text = "Phase 1: Watch How Shifting Works"
			cipher_type_label.text = "Caesar Cipher - Visual Demo"
			content_label.text = """SEE THE SHIFT IN ACTION!

Watch how we encrypt "H" → "K" by shifting 3 steps:

The box below will move through the alphabet to show you!

🎯 PAY ATTENTION TO:
• Starting letter (H)
• Count 3 steps forward
• Landing letter (K)

This is ENCRYPTION (plaintext → ciphertext)

To DECRYPT, you do the OPPOSITE:
K → Count 3 steps BACKWARD → H

Watch the animation below →"""
			
			wheel_panel.visible = true
			visual_demo.visible = true
			alphabet_reference.visible = false
			_update_alphabet_display()
			_play_shift_animation()

		Phase.PRACTICE_MODE:
			section_label.text = "Phase 2: Practice Decryption"
			cipher_type_label.text = "Caesar Cipher - Decrypt Practice"
			
			if current_practice_index >= practice_messages.size():
				# Practice complete
				content_label.text = """✅ PRACTICE COMPLETE!

You've successfully decrypted all practice messages!

You now understand:
• How Caesar Cipher shifts letters
• How to decrypt by shifting BACKWARDS
• The importance of knowing the key

Ready for a challenge? Click NEXT →"""
				next_button.disabled = false
			else:
				var msg = practice_messages[current_practice_index]
				content_label.text = """DECRYPT THIS MESSAGE!

The message below was encrypted with Caesar Cipher (Key = 3).

📝 TASK:
Decrypt by shifting each letter BACKWARDS by 3.

Example: K → H, O → L

💡 TIP: Use the alphabet reference to help you!"""
				
				practice_panel.visible = true
				wheel_panel.visible = true
				alphabet_reference.visible = true
				_update_alphabet_display()
				_setup_practice_message(msg)
				next_button.disabled = true

		Phase.CHALLENGE_MODE:
			_highest_phase_reached = max(_highest_phase_reached, 3)
			section_label.text = "Phase 3: Decryption Challenge"
			cipher_type_label.text = "Caesar Cipher - Timed Challenge"
			
			if current_challenge_index >= challenge_messages.size():
				# Challenge complete
				score += 100
				content_label.text = """🎉 CHALLENGE COMPLETE!

You've mastered Caesar Cipher decryption with multiple shift keys!

Score: +100 points

Click NEXT to learn about modern encryption →"""
				next_button.disabled = false
			else:
				var msg = challenge_messages[current_challenge_index]
				var difficulty := "EASY"
				if msg["key"] >= 7:
					difficulty = "🔴 HARD"
				elif msg["key"] >= 5:
					difficulty = "🟡 MEDIUM"
				else:
					difficulty = "🟢 EASY"
				
				current_shift = msg["key"]
				content_label.text = """⚡ DECRYPTION CHALLENGE! [%s]

Challenge %d of %d

Decrypt this message as fast as you can!

🎯 Instructions:
1. Look at the encrypted message
2. Type the decrypted answer
3. Click SUBMIT

🔑 Key = %d (shift backwards by %d)

💡 Use the alphabet reference below!""" % [difficulty, current_challenge_index + 1, challenge_messages.size(), msg["key"], msg["key"]]
				
				challenge_panel.visible = true
				wheel_panel.visible = true
				alphabet_reference.visible = true
				_update_alphabet_display()
				_setup_challenge_message(msg)
				challenge_feedback.text = ""
				next_button.disabled = true

		Phase.RANSOMWARE_EXPLANATION:
			section_label.text = "Phase 4: Real-World Application"
			cipher_type_label.text = "Modern Encryption vs Caesar Cipher"
			content_label.text = """🚨 HOW RANSOMWARE USES ENCRYPTION

Caesar Cipher is EASY to break:
• Only 26 possible keys (A-Z)
• Can try all keys in seconds (Brute Force Attack)
• Not secure for real data!

🔒 MODERN RANSOMWARE USES AES-256:
• 2^256 possible keys (340 undecillion combinations!)
• Would take billions of years to brute force
• Mathematically impossible to crack without the key

⚠️ RANSOMWARE ATTACK PROCESS:
1. Malware encrypts all your files with AES-256
2. Deletes the key from your computer
3. Attacker demands payment for the key
4. Even if you pay, they might not give you the key!

🛡️ YOUR BEST DEFENSE:
✓ Regular backups (daily)
✓ Offline backups (disconnected from network)
✓ Cloud + local copies
✓ Never pay the ransom!

With backups, you can restore your files WITHOUT the key!

Click NEXT to complete the tutorial →"""

		Phase.COMPLETE:
			section_label.text = "🎓 Tutorial Complete!"
			cipher_type_label.text = "Caesar Cipher - Mastered!"
			content_label.text = """🎉 CONGRATULATIONS!

You've completed the Caesar Cipher tutorial!

✅ What You Learned:
• How substitution ciphers work
• Caesar Cipher encryption/decryption
• The importance of the encryption key
• Why modern encryption is unbreakable
• How ransomware exploits encryption
• Why backups are critical

📊 Final Score: %d points

🔐 REMEMBER:
• Encryption protects YOUR data (good!)
• Ransomware uses encryption against you (bad!)
• Always maintain backups!

Click FINISH to return to menu →""" % score
			
			if _is_gamemode:
				next_button.text = "SUBMIT & FINISH"
			else:
				next_button.text = "FINISH"


func _update_alphabet_display() -> void:
	var plaintext_alphabet = ""
	var cipher_alphabet = ""
	
	for i in range(26):
		var plain_char = char(65 + i)  # A-Z
		var cipher_char = _caesar_shift(plain_char, current_shift)
		
		plaintext_alphabet += plain_char + " "
		cipher_alphabet += cipher_char + " "
	
	alphabet_reference.text = "Plaintext:  " + plaintext_alphabet + "\n"
	alphabet_reference.text += "Encrypted:  " + cipher_alphabet
	shift_label.text = "🔑 Shift Key: " + str(current_shift) + " (A→" + _caesar_shift("A", current_shift) + ", B→" + _caesar_shift("B", current_shift) + ", C→" + _caesar_shift("C", current_shift) + "...)"


func _play_shift_animation() -> void:
	"""Animate the shift from H to K"""
	if not alphabet_container:
		return
	
	# Clear any existing children
	for child in alphabet_container.get_children():
		child.queue_free()
	
	demo_result_label.text = ""
	demo_example_label.text = "Example: Encrypting \"H\" with shift 3"
	
	# Create alphabet display
	var alphabet_hbox = HBoxContainer.new()
	alphabet_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	alphabet_container.add_child(alphabet_hbox)
	
	# Add alphabet letters
	var letter_labels = []
	for i in range(26):
		var letter = char(65 + i)  # A-Z
		var label = Label.new()
		label.text = letter
		label.add_theme_font_size_override("font_size", 16)  # Reduced from 24
		label.custom_minimum_size = Vector2(28, 40)  # Reduced from 40x60
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Highlight H and K
		if letter == "H":
			label.add_theme_color_override("font_color", Color(0, 0.6, 1))  # Blue for start
		elif letter == "K":
			label.add_theme_color_override("font_color", Color(0, 0.8, 0))  # Green for end
		else:
			label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		
		alphabet_hbox.add_child(label)
		letter_labels.append(label)
	
	# Create moving highlight box
	var highlight_box = ColorRect.new()
	highlight_box.color = Color(1, 0.8, 0, 0.3)  # Transparent yellow
	highlight_box.size = Vector2(28, 40)  # Match label size
	alphabet_container.add_child(highlight_box)
	
	await get_tree().process_frame
	
	# Validate nodes before accessing positions
	if not is_instance_valid(alphabet_container) or letter_labels.size() < 11:
		return
	
	# Get position of H (index 7)
	var h_label = letter_labels[7]
	if not is_instance_valid(h_label):
		return
	var start_pos = h_label.global_position - alphabet_container.global_position
	
	# Position box on H
	highlight_box.position = start_pos
	
	# Animate to K (index 10)
	var k_label = letter_labels[10]
	if not is_instance_valid(k_label):
		return
	var end_pos = k_label.global_position - alphabet_container.global_position
	
	# Step-by-step animation
	demo_result_label.text = "Starting at: H"
	await get_tree().create_timer(1.0).timeout
	
	# Move through I, J, K
	var steps = ["I", "J", "K"]
	for step_idx in range(3):
		var target_idx = 7 + step_idx + 1  # H=7, I=8, J=9, K=10
		var target_label = letter_labels[target_idx]
		
		# Validate node before accessing position
		if not is_instance_valid(target_label) or not is_instance_valid(alphabet_container) or not is_instance_valid(highlight_box):
			return
		
		var target_pos = target_label.global_position - alphabet_container.global_position
		
		# Animate movement
		var tween = create_tween()
		tween.tween_property(highlight_box, "position", target_pos, 0.5)
		await tween.finished
		
		demo_result_label.text = "Step %d: %s" % [step_idx + 1, steps[step_idx]]
		await get_tree().create_timer(0.8).timeout
	
	# Final result
	demo_result_label.text = "✓ Result: H → K (shifted 3 steps!)"
	demo_result_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
	
	# Highlight the path
	for i in range(7, 11):  # H to K
		if is_instance_valid(letter_labels[i]):
			letter_labels[i].add_theme_color_override("font_color", Color(1, 0.6, 0))
	
	await get_tree().create_timer(2.0).timeout
	
	# Show decryption example
	demo_example_label.text = "Now watch DECRYPTION: \"K\" → \"H\" (backwards)"
	demo_result_label.text = "Shift 3 steps BACKWARD"
	
	await get_tree().create_timer(1.5).timeout
	
	# Animate backwards
	for step_idx in range(2, -1, -1):  # 2, 1, 0
		var target_idx = 7 + step_idx  # K=10 to H=7
		var target_label = letter_labels[target_idx]
		
		# Validate node before accessing position
		if not is_instance_valid(target_label) or not is_instance_valid(alphabet_container) or not is_instance_valid(highlight_box):
			return
		var target_pos = target_label.global_position - alphabet_container.global_position
		
		var tween = create_tween()
		tween.tween_property(highlight_box, "position", target_pos, 0.5)
		await tween.finished
		
		await get_tree().create_timer(0.5).timeout
	
	demo_result_label.text = "✓ Decrypted: K → H (original message!)"
	demo_result_label.add_theme_color_override("font_color", Color(0, 0.6, 1))


func _setup_practice_message(msg: Dictionary) -> void:
	practice_encrypted_label.text = "🔒 Encrypted: " + msg["encrypted"]
	practice_hint_label.text = "💡 Hint: Shift each letter BACKWARDS by " + str(msg["key"])
	
	# Clear previous slots
	for child in practice_slots_container.get_children():
		child.queue_free()
	
	# Create letter slots
	var slot_container = HBoxContainer.new()
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	practice_slots_container.add_child(slot_container)
	
	for i in range(msg["encrypted"].length()):
		var encrypted_char = msg["encrypted"][i]
		var decrypted_char = msg["plain"][i]
		
		var slot_button = Button.new()
		slot_button.text = encrypted_char + " → ?"
		slot_button.custom_minimum_size = Vector2(80, 60)
		slot_button.pressed.connect(_on_practice_slot_pressed.bind(i, decrypted_char, slot_button))
		slot_container.add_child(slot_button)


func _on_practice_slot_pressed(index: int, correct_answer: String, button: Button) -> void:
	# Show the answer when clicked
	var msg = practice_messages[current_practice_index]
	var encrypted_char = msg["encrypted"][index]
	var decrypted_char = msg["plain"][index]
	
	button.text = encrypted_char + " → " + decrypted_char
	button.modulate = Color(0.3, 1, 0.3)  # Green
	button.disabled = true
	
	# Check if all slots are revealed
	var all_revealed = true
	for child in button.get_parent().get_children():
		if not child.disabled:
			all_revealed = false
			break
	
	if all_revealed:
		practice_hint_label.text = "✅ CORRECT! \"" + msg["plain"] + "\" decrypted!"
		practice_hint_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
		score += 20
		practice_completed += 1
		
		await get_tree().create_timer(2.0).timeout
		
		current_practice_index += 1
		_start_phase(Phase.PRACTICE_MODE)


func _setup_challenge_message(msg: Dictionary) -> void:
	challenge_encrypted_label.text = "🔒 " + msg["encrypted"]
	challenge_input.text = ""
	challenge_input.editable = true
	challenge_submit.disabled = false


func _on_challenge_submit() -> void:
	var msg = challenge_messages[current_challenge_index]
	var user_answer = challenge_input.text.strip_edges().to_upper()
	
	if user_answer == msg["plain"]:
		# Correct!
		challenge_feedback.text = "✅ CORRECT!"
		challenge_feedback.add_theme_color_override("font_color", Color(0, 0.8, 0))
		challenge_input.editable = false
		challenge_submit.disabled = true
		score += 30
		
		await get_tree().create_timer(1.5).timeout
		
		current_challenge_index += 1
		_start_phase(Phase.CHALLENGE_MODE)
	else:
		# Wrong
		challenge_feedback.text = "❌ Try again! Shift backwards by 3"
		challenge_feedback.add_theme_color_override("font_color", Color(0.8, 0, 0))
		challenge_attempts += 1
		
		if challenge_attempts >= 3:
			challenge_feedback.text = "💡 Answer: " + msg["plain"]
			challenge_feedback.add_theme_color_override("font_color", Color(1, 0.6, 0))
			score += 10  # Partial credit
			
			await get_tree().create_timer(3.0).timeout
			
			current_challenge_index += 1
			challenge_attempts = 0
			_start_phase(Phase.CHALLENGE_MODE)


func _caesar_shift(char: String, shift: int) -> String:
	if char.length() == 0:
		return ""
	
	var c = char.to_upper()
	if c < "A" or c > "Z":
		return char
	
	var base = "A".unicode_at(0)
	var shifted = (c.unicode_at(0) - base + shift) % 26
	return char(base + shifted)


func _on_next_pressed() -> void:
	match current_phase:
		Phase.INTRO:
			_start_phase(Phase.LEARN_WHEEL)
		Phase.LEARN_WHEEL:
			current_practice_index = 0
			_start_phase(Phase.PRACTICE_MODE)
		Phase.PRACTICE_MODE:
			current_challenge_index = 0
			challenge_attempts = 0
			_start_phase(Phase.CHALLENGE_MODE)
		Phase.CHALLENGE_MODE:
			_start_phase(Phase.RANSOMWARE_EXPLANATION)
		Phase.RANSOMWARE_EXPLANATION:
			_start_phase(Phase.COMPLETE)
		Phase.COMPLETE:
			print("[TUTORIAL] Final Score: %d" % score)
			
			# Always save — even with low score, award XP for effort
			# Check first-time before saving
			var _first_clear: bool = MinigameRewards.is_first_completion("advanced_encryption")
			
			# Save tutorial result with correct ID matching prerequisite system
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				tutorial_mgr.save_tutorial_result("advanced_encryption", score, max_score)
				await tutorial_mgr.save_completed
			
			# Show reward popup on first completion
			if _first_clear and not _is_gamemode:
				MinigameRewards.try_grant_rewards("advanced_encryption", score, score, self)
			
			if _is_gamemode:
				_submit_gamemode_score()
			else:
				get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	match current_phase:
		Phase.INTRO:
			if _is_gamemode:
				return  # Cannot quit during multiplayer game
			# Award partial XP if player made any progress before quitting
			if score > 0:
				var tutorial_mgr = get_node("/root/TutorialManager")
				if tutorial_mgr:
					tutorial_mgr.save_tutorial_result("advanced_encryption", score, max_score)
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Phase.LEARN_WHEEL:
			_start_phase(Phase.INTRO)
		Phase.PRACTICE_MODE:
			_start_phase(Phase.LEARN_WHEEL)
		Phase.CHALLENGE_MODE:
			_start_phase(Phase.PRACTICE_MODE)
		Phase.RANSOMWARE_EXPLANATION:
			_start_phase(Phase.CHALLENGE_MODE)
		Phase.COMPLETE:
			_start_phase(Phase.RANSOMWARE_EXPLANATION)


func _submit_gamemode_score() -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	# Encryption is time-only — send score as 0
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": 0,
		"max_score": 0,
		"time_taken_ms": time_taken_ms
	})
	
	if next_button:
		next_button.disabled = true
		next_button.text = "Submitting..."
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Time submitted: %dms → status %d" % [time_taken_ms, code])
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")
