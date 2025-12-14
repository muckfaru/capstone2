extends Control

# ============================================
# ENCRYPTION BASICS - Caesar Cipher Lab
# Teaches encryption concepts through hands-on practice
# Explains how ransomware uses encryption
# ============================================

enum Phase {
	INTRO,
	ENCRYPT_DEMO,
	DECRYPT_CHALLENGE,
	RANSOMWARE_EXPLANATION,
	COMPLETE
}

var current_phase = Phase.INTRO
var score := 0
var attempts := 0

# Challenge data
var challenge_encrypted := "WKLV LV VHFUHW"
var challenge_key := 3


func _ready() -> void:
	print("🔐 Encryption Basics Tutorial Ready")
	
	# Hide panels initially
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel"):
		$WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel.visible = false
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel"):
		$WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel.visible = false
	
	# Connect buttons
	_connect_buttons()
	
	_start_phase(Phase.INTRO)


func _connect_buttons() -> void:
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/KeyHBox/EncryptButton"):
		var encrypt_btn = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/KeyHBox/EncryptButton
		if not encrypt_btn.pressed.is_connected(_on_encrypt_pressed):
			encrypt_btn.pressed.connect(_on_encrypt_pressed)
	
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/SubmitButton"):
		var submit_btn = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/SubmitButton
		if not submit_btn.pressed.is_connected(_on_submit_pressed):
			submit_btn.pressed.connect(_on_submit_pressed)
	
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton"):
		var next_btn = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
		if not next_btn.pressed.is_connected(_on_next_pressed):
			next_btn.pressed.connect(_on_next_pressed)
	
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton"):
		var back_btn = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)


func _start_phase(phase: Phase) -> void:
	current_phase = phase
	
	# Safely hide panels
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel"):
		$WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel.visible = false
	if has_node("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel"):
		$WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel.visible = false
	
	var section_label = $WindowDialog/VBox/TitleBar/MarginContainer/SectionLabel
	var content_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
	var next_button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
	
	next_button.disabled = false
	
	match phase:
		Phase.INTRO:
			section_label.text = "Introduction to Encryption"
			content_label.text = """WHAT IS ENCRYPTION?

Encryption transforms readable text (plaintext) into unreadable code (ciphertext).
Only someone with the KEY can decrypt it back to readable form.

Example:
• Original message: "HELLO"
• Encrypted: "KHOOR"
• Without the key, this looks like random letters!

This is how ransomware locks your files - it encrypts them and holds the key hostage.

Click NEXT to see how it works →"""
		
		Phase.ENCRYPT_DEMO:
			section_label.text = "Phase 1: Encryption Demo"
			content_label.text = """CAESAR CIPHER DEMO

We'll use a simple cipher where each letter shifts by a number (the KEY).

Try it below:
1. Enter a message in the box
2. Set the shift key (default 3)
3. Click ENCRYPT to see it scrambled!

Without knowing the key, the encrypted message looks like gibberish."""
			
			var demo_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel
			demo_panel.visible = true
			
			var plaintext_input = demo_panel.get_node("VBox/InputHBox/PlaintextInput")
			var key_input = demo_panel.get_node("VBox/KeyHBox/KeyInput")
			var result_label = demo_panel.get_node("VBox/ResultLabel")
			
			plaintext_input.text = "HELLO WORLD"
			key_input.value = 3
			result_label.text = "Click ENCRYPT to see result"
		
		Phase.DECRYPT_CHALLENGE:
			section_label.text = "Phase 2: Decryption Challenge"
			content_label.text = """YOUR TURN! TRY DECRYPTING

I encrypted a message using Caesar Cipher with key = 3.

Encrypted Message: WKLV LV VHFUHW

To decrypt, shift each letter BACKWARDS by 3.
Example: W → T, K → H, L → I
Example: in Alpabet: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z you need to count backwards 3 letters W->T

Type the decrypted message below (use capital letters):"""
			
			var challenge_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel
			challenge_panel.visible = true
			
			var answer_input = challenge_panel.get_node("VBox/InputHBox/AnswerInput")
			var submit_button = challenge_panel.get_node("VBox/InputHBox/SubmitButton")
			
			answer_input.text = ""
			answer_input.editable = true
			submit_button.disabled = false
			next_button.disabled = true
		
		Phase.RANSOMWARE_EXPLANATION:
			section_label.text = "Phase 3: How Ransomware Uses Encryption"
			content_label.text = """WHY RANSOMWARE IS SO DANGEROUS

Caesar Cipher was EASY to crack - only 26 possible keys to try!

But modern ransomware uses AES-256 encryption:
• 2^256 possible keys (more than atoms in the universe!)
• Would take billions of years to try all keys
• Mathematically impossible to crack without the key

When ransomware encrypts your files:
1. Uses AES-256 (unbreakable encryption)
2. Deletes the key from your computer
3. Attacker keeps the only copy of the key
4. Demands payment to give you the key back

WHY BACKUPS ARE CRITICAL:
You can't decrypt without the key, but you can restore from backup!
Never pay the ransom - criminals may not give you the key anyway.

Your Defense:
• Daily backups = Your files safe
• Air-gapped backups (offline)
• Cloud + local copies"""
		
		Phase.COMPLETE:
			section_label.text = "Encryption Mastered!"
			content_label.text = """🎉 CONGRATULATIONS!

You now understand:
✓ How encryption transforms data
✓ Why keys are critical for decryption
✓ How ransomware exploits encryption
✓ Why AES-256 is unbreakable
✓ Why backups are your best defense

Score: %d/200 points

Remember: Encryption is GOOD for security (protects your data),
but BAD when attackers use it against you (ransomware).

Always keep backups!""" % score
			next_button.text = "FINISH"
			next_button.disabled = false
			print("[TUTORIAL] Section COMPLETE set - FINISH button enabled")


func _on_encrypt_pressed() -> void:
	var demo_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel
	var plaintext_input = demo_panel.get_node("VBox/InputHBox/PlaintextInput")
	var key_input = demo_panel.get_node("VBox/KeyHBox/KeyInput")
	var result_label = demo_panel.get_node("VBox/ResultLabel")
	
	var plaintext = plaintext_input.text.to_upper()
	var shift = int(key_input.value)
	var encrypted = caesar_encrypt(plaintext, shift)
	result_label.text = "Encrypted: " + encrypted
	result_label.add_theme_color_override("font_color", Color(0, 0.6, 0))


func _on_submit_pressed() -> void:
	var challenge_panel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel
	var answer_input = challenge_panel.get_node("VBox/InputHBox/AnswerInput")
	var submit_button = challenge_panel.get_node("VBox/InputHBox/SubmitButton")
	var content_label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
	
	var user_answer = answer_input.text.strip_edges().to_upper()
	attempts += 1
	
	# Decrypt the challenge
	var correct_answer = caesar_decrypt(challenge_encrypted, challenge_key)
	
	if user_answer == correct_answer:
		score += 100
		content_label.text += "\n\n✅ CORRECT! You decrypted it!"
		content_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
		answer_input.editable = false
		submit_button.disabled = true
		
		print("[Encryption] ✅ Correct answer! Score: %d" % score)
		
		await get_tree().create_timer(2.0).timeout
		content_label.add_theme_color_override("font_color", Color.BLACK)
		_start_phase(Phase.RANSOMWARE_EXPLANATION)
	else:
		score -= 10
		content_label.text += "\n\n❌ Wrong. Hint: Shift each letter BACKWARDS by 3. Try again!"
		content_label.add_theme_color_override("font_color", Color(0.8, 0, 0))
		
		print("[Encryption] ❌ Wrong answer. Score: %d | Attempts: %d" % [score, attempts])
		
		if attempts >= 3:
			score = max(score, 50)  # Give minimum 50 points for trying
			content_label.text += "\n\nAnswer: " + correct_answer + "\n(Shift backwards: W→T, K→H, etc.)"
			print("[Encryption] Max attempts reached. Giving 50 points minimum. Score: %d" % score)
			await get_tree().create_timer(3.0).timeout
			content_label.add_theme_color_override("font_color", Color.BLACK)
			_start_phase(Phase.RANSOMWARE_EXPLANATION)


func caesar_encrypt(text: String, shift: int) -> String:
	var result = ""
	for c in text:
		if c == " ":
			result += " "
		elif c.to_upper() >= "A" and c.to_upper() <= "Z":
			var base = "A".unicode_at(0)
			var shifted = (c.to_upper().unicode_at(0) - base + shift) % 26
			result += char(base + shifted)
		else:
			result += c
	return result


func caesar_decrypt(text: String, shift: int) -> String:
	return caesar_encrypt(text, 26 - shift)  # Decrypt = encrypt with reverse shift


func _on_next_pressed() -> void:
	match current_phase:
		Phase.INTRO:
			_start_phase(Phase.ENCRYPT_DEMO)
		Phase.ENCRYPT_DEMO:
			_start_phase(Phase.DECRYPT_CHALLENGE)
		Phase.RANSOMWARE_EXPLANATION:
			_start_phase(Phase.COMPLETE)
		Phase.COMPLETE:
			print("[TUTORIAL] FINISH button pressed!")
			print("[TUTORIAL] Final Score: %d / Max: 100" % score)
			
			# Don't save if score is negative or zero
			if score <= 0:
				print("[TUTORIAL] ⚠️ Score too low (%d), not saving. Redirecting to landing..." % score)
				get_tree().change_scene_to_file("res://scene/landing.tscn")
				return
			
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				print("[TUTORIAL] TutorialManager found, saving result...")
				tutorial_mgr.save_tutorial_result("beginner_encryption", score, 100)
				
				# Wait for Firestore save to complete before navigating
				print("[TUTORIAL] Waiting for Firestore save to complete...")
				await tutorial_mgr.save_completed
				print("[TUTORIAL] Save confirmed, navigating to landing...")
			else:
				push_error("[TUTORIAL] TutorialManager not found!")
			
			# Return to landing page
			get_tree().change_scene_to_file("res://scene/landing.tscn")


func _on_back_pressed() -> void:
	match current_phase:
		Phase.INTRO:
			# First phase - exit to mode selection
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Phase.ENCRYPT_DEMO:
			_start_phase(Phase.INTRO)
		Phase.DECRYPT_CHALLENGE:
			_start_phase(Phase.ENCRYPT_DEMO)
		Phase.RANSOMWARE_EXPLANATION:
			# Reset challenge and go back
			attempts = 0
			_start_phase(Phase.DECRYPT_CHALLENGE)
		Phase.COMPLETE:
			_start_phase(Phase.RANSOMWARE_EXPLANATION)
