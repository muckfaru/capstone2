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

# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/SectionLabel
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var demo_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel
@onready var plaintext_input: LineEdit = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/InputHBox/PlaintextInput
@onready var key_input: SpinBox = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/KeyHBox/KeyInput
@onready var encrypt_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/KeyHBox/EncryptButton
@onready var result_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DemoPanel/VBox/ResultLabel
@onready var challenge_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel
@onready var answer_input: LineEdit = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/AnswerInput
@onready var submit_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ChallengePanel/VBox/InputHBox/SubmitButton
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton

# Challenge data
var challenge_encrypted := "WKLV LV VHFUHW"
var challenge_key := 3


func _ready() -> void:
	print("🔐 Encryption Basics Tutorial Ready")
	
	challenge_panel.visible = false
	demo_panel.visible = false
	
	# Connect encrypt button (not in scene file)
	encrypt_button.pressed.connect(_on_encrypt_pressed)
	
	_start_phase(Phase.INTRO)


func _start_phase(phase: Phase) -> void:
	current_phase = phase
	challenge_panel.visible = false
	demo_panel.visible = false
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
			demo_panel.visible = true
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

Type the decrypted message below (use capital letters):"""
			challenge_panel.visible = true
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


func _on_encrypt_pressed() -> void:
	var plaintext = plaintext_input.text.to_upper()
	var shift = int(key_input.value)
	var encrypted = caesar_encrypt(plaintext, shift)
	result_label.text = "Encrypted: " + encrypted
	result_label.add_theme_color_override("font_color", Color(0, 0.6, 0))


func _on_submit_pressed() -> void:
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
		
		await get_tree().create_timer(2.0).timeout
		content_label.add_theme_color_override("font_color", Color.BLACK)
		_start_phase(Phase.RANSOMWARE_EXPLANATION)
	else:
		score -= 10
		content_label.text += "\n\n❌ Wrong. Hint: Shift each letter BACKWARDS by 3. Try again!"
		content_label.add_theme_color_override("font_color", Color(0.8, 0, 0))
		
		if attempts >= 3:
			content_label.text += "\n\nAnswer: " + correct_answer + "\n(Shift backwards: W→T, K→H, etc.)"
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
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				tutorial_mgr.save_tutorial_result("intermediate_encryption", score, 200)
			
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
