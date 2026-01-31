extends Control

# Game state management
enum Phase {
	INTRO,
	SYMMETRIC_PROBLEM,
	ASYMMETRIC_CONCEPT,
	KEY_GENERATION,
	PUBLIC_KEY_SHARE,
	ENCRYPTION_DEMO,
	DECRYPTION_DEMO,
	COMPLETE_EXCHANGE,
	REAL_WORLD,
	QUIZ
}

var current_phase: Phase = Phase.INTRO
var score: int = 0
var player_understanding: Dictionary = {}

# Visual elements for animation
var animation_playing: bool = false
var current_step: int = 0

# Node references
@onready var title_label = $MainContainer/HeaderPanel/VBox/TitleLabel
@onready var phase_title = $MainContainer/HeaderPanel/VBox/PhaseTitle
@onready var instruction_text = $MainContainer/ContentArea/LeftPanel/InstructionPanel/InstructionScroll/InstructionText
@onready var visual_area = $MainContainer/ContentArea/CenterPanel/VisualArea
@onready var info_panel = $MainContainer/ContentArea/RightPanel/InfoPanel/InfoScroll/InfoText
@onready var btn_container = $MainContainer/BottomPanel/ButtonContainer
@onready var progress_bar = $MainContainer/HeaderPanel/VBox/ProgressBar
@onready var glossary_panel = $GlossaryPanel
@onready var hint_label = $HintPanel/HintLabel

# Buttons
@onready var btn_next = $MainContainer/BottomPanel/ButtonContainer/BtnNext
@onready var btn_try_action = $MainContainer/BottomPanel/ButtonContainer/BtnTryAction
@onready var btn_show_hint = $MainContainer/BottomPanel/ButtonContainer/BtnShowHint
@onready var btn_glossary = $MainContainer/BottomPanel/ButtonContainer/BtnGlossary

# Visual nodes (created dynamically)
var alice_node: PanelContainer
var bob_node: PanelContainer
var eve_node: PanelContainer
var message_node: PanelContainer
var key_nodes: Dictionary = {}

# Phase content
var phase_data = {
	Phase.INTRO: {
		"title": "Welcome to Asymmetric Cryptography!",
		"instruction": """🎓 <b>What You'll Learn:</b>

In this interactive tutorial, you'll discover:

• Why sending secrets is dangerous
• How public and private keys work together
• The mathematical magic behind encryption
• Real-world applications (HTTPS, SSH, Bitcoin)

<b>Meet Our Characters:</b>
👩 <b>Alice</b> - Wants to send a secret message
👨 <b>Bob</b> - Wants to receive it safely
👁️ <b>Eve</b> - An eavesdropper watching the network

Click <b>Next</b> to begin!""",
		"info": """<b>💡 What is Cryptography?</b>

Cryptography is the science of keeping information secret and secure.

<b>Two Main Types:</b>

🔑 <b>Symmetric</b>: One key for both locking and unlocking (like a house key)

🔐 <b>Asymmetric</b>: Two keys - public key locks, private key unlocks (like a mailbox)

We'll explore why asymmetric is revolutionary!""",
		"action_text": ""
	},
	
	Phase.SYMMETRIC_PROBLEM: {
		"title": "The Problem: How Do You Share a Secret Key?",
		"instruction": """❌ <b>The Symmetric Encryption Problem</b>

Imagine Alice wants to send Bob a secret message using a shared key (like a password).

<b>The Catch-22:</b>
1. They need the SAME key to encrypt/decrypt
2. But how do they agree on the key?
3. If they send it over the network, Eve can steal it!

This is called the <b>Key Distribution Problem</b>.

Click <b>"Try Sending Key"</b> to see what happens!""",
		"info": """🔐 <b>Symmetric Encryption</b>

Uses ONE key for both encryption and decryption.

<b>Example:</b>
Key = "SECRET123"
Message = "Hello"
Encrypted = "XjK9mP"

To decrypt, you need the same key!

<b>The Problem:</b>
How do Alice and Bob agree on "SECRET123" without Eve seeing it?

This problem existed for centuries until asymmetric cryptography was invented in the 1970s!""",
		"action_text": "Try Sending Key"
	},
	
	Phase.ASYMMETRIC_CONCEPT: {
		"title": "The Solution: Two Keys Instead of One!",
		"instruction": """✨ <b>The Brilliant Idea</b>

What if we used TWO different keys?

🔑 <b>Public Key</b> (like a padlock)
   • Anyone can use it to LOCK a box
   • Can be shared openly with everyone
   • Eve can see it - doesn't matter!

🔐 <b>Private Key</b> (like the only key to the padlock)
   • Only ONE person has it
   • Only this key can UNLOCK the box
   • Must be kept SECRET forever

<b>The Magic:</b>
What one key locks, only the other can unlock!

Click <b>"See Visual Analogy"</b> to understand this better.""",
		"info": """🎯 <b>Key Concept</b>

<b>Public Key:</b>
Think of it as a padlock you give to everyone. Anyone can snap it shut on a box, but once locked, only YOU can open it.

<b>Private Key:</b>
The physical key to that padlock. You keep this in your pocket forever.

<b>Why It's Secure:</b>
Even if Eve has your public key (padlock), she can't open boxes locked with it. She needs the private key!

<b>Mathematical Foundation:</b>
Based on "one-way functions" - easy to do one direction, nearly impossible to reverse without the secret.""",
		"action_text": "See Visual Analogy"
	},
	
	Phase.KEY_GENERATION: {
		"title": "Step 1: Bob Generates His Key Pair",
		"instruction": """🔧 <b>Creating the Key Pair</b>

Bob needs to create his two keys:

1️⃣ <b>Generate Private Key</b>
   • Random, extremely large number
   • Must be kept absolutely secret
   • Never shared with anyone, ever

2️⃣ <b>Calculate Public Key</b>
   • Mathematically derived from private key
   • Uses special one-way math (RSA, ECC)
   • Safe to share with the world

<b>Important:</b> You can't calculate the private key from the public key - that's the mathematical magic!

Click <b>"Generate Bob's Keys"</b> to create them!""",
		"info": """🔬 <b>The Math (Simplified)</b>

<b>Real Algorithm (RSA):</b>
1. Pick two huge prime numbers
2. Multiply them together (easy)
3. Trying to factor them back (nearly impossible!)

<b>Example:</b>
Private: Two primes (p=61, q=53)
Public: Their product (n=3233)

Finding p and q from 3233 is easy here, but with 2048-bit numbers, it would take billions of years!

<b>Analogy:</b>
Mixing paint colors is easy.
Unmixing them back? Impossible!""",
		"action_text": "Generate Bob's Keys"
	},
	
	Phase.PUBLIC_KEY_SHARE: {
		"title": "Step 2: Bob Shares His Public Key",
		"instruction": """📢 <b>Public Key Distribution</b>

Now Bob sends his PUBLIC key to Alice over the network.

<b>What Eve Sees:</b>
👁️ Eve intercepts Bob's public key
👁️ She copies it, examines it, tries to break it

<b>Why Bob Doesn't Care:</b>
✅ The public key is DESIGNED to be public
✅ It can only LOCK messages, not unlock them
✅ Without the private key, it's useless for decryption

Think of it like Bob publishing his address. Everyone knows where to send mail, but only Bob can open his mailbox!

Click <b>"Bob Sends Public Key"</b> to watch!""",
		"info": """📡 <b>Public Key Infrastructure</b>

In the real world:
• Public keys are shared in certificates
• Websites broadcast them (HTTPS)
• SSH servers announce them
• Bitcoin addresses are derived from them

<b>Eve's Perspective:</b>
She has Bob's public key now.
She can:
  ✅ Encrypt messages to Bob (but why would she?)
  ❌ Read messages encrypted for Bob
  ❌ Pretend to be Bob
  ❌ Decrypt anything

The public key gives her NO attack power!""",
		"action_text": "Bob Sends Public Key"
	},
	
	Phase.ENCRYPTION_DEMO: {
		"title": "Step 3: Alice Encrypts Her Message",
		"instruction": """🔒 <b>Encryption Process</b>

Alice has Bob's public key. Now she can send him a secret!

<b>Alice's Process:</b>

1️⃣ Write her message: "Meet at noon"

2️⃣ Encrypt using Bob's PUBLIC key
   Message + Bob's Public Key = Encrypted Blob

3️⃣ The message is now scrambled gibberish
   Original: "Meet at noon"
   Encrypted: "XjK9mP2Lq7Wz..."

<b>Key Point:</b> Even Alice can't decrypt this anymore! Only Bob's private key can unlock it.

Click <b>"Encrypt Message"</b> to see the transformation!""",
		"info": """🔐 <b>How Encryption Works</b>

<b>The Formula:</b>
Encrypted = Message ^ PublicKey mod n

(This is simplified RSA)

<b>What Happens:</b>
The message is mathematically transformed using the public key. The result looks like random garbage.

<b>One-Way Function:</b>
Going forward (encrypting) is easy.
Going backward (decrypting) without the private key is computationally infeasible.

<b>Security:</b>
Even with the world's fastest supercomputers, breaking this encryption would take longer than the age of the universe!""",
		"action_text": "Encrypt Message"
	},
	
	Phase.DECRYPTION_DEMO: {
		"title": "Step 4: Bob Decrypts the Message",
		"instruction": """🔓 <b>Decryption Process</b>

The encrypted message reaches Bob. Eve has seen it too, but she can't read it.

<b>Bob's Process:</b>

1️⃣ Receives: "XjK9mP2Lq7Wz..." (encrypted blob)

2️⃣ Uses his PRIVATE key to decrypt
   Encrypted + Bob's Private Key = Original Message

3️⃣ Reads: "Meet at noon"

<b>Eve's Frustration:</b>
👁️ Eve has: The encrypted message, Bob's public key
❌ Eve lacks: Bob's private key
❌ Result: She sees only gibberish

Click <b>"Bob Decrypts"</b> to reveal the message!""",
		"info": """🔓 <b>How Decryption Works</b>

<b>The Formula:</b>
Message = Encrypted ^ PrivateKey mod n

<b>Mathematical Magic:</b>
The private key "undoes" what the public key did. They're mathematically paired.

<b>Why Eve Can't Decrypt:</b>
She would need to:
1. Factor a huge number (2048 bits)
2. Solve the discrete logarithm problem
3. Break one-way mathematical functions

Even with all computers on Earth, this would take billions of years!

<b>Security Guarantee:</b>
Only Bob's private key can decrypt messages encrypted with his public key.""",
		"action_text": "Bob Decrypts"
	},
	
	Phase.COMPLETE_EXCHANGE: {
		"title": "The Complete Secure Exchange",
		"instruction": """🎉 <b>Putting It All Together</b>

Let's review the complete process:

1️⃣ <b>Bob generates</b> his key pair (public + private)

2️⃣ <b>Bob shares</b> his public key openly (Eve sees it ✓)

3️⃣ <b>Alice encrypts</b> with Bob's public key

4️⃣ <b>Alice sends</b> encrypted message (Eve sees gibberish)

5️⃣ <b>Bob decrypts</b> with his private key

6️⃣ <b>Success!</b> Secure communication achieved

<b>The Beauty:</b>
No secret key was ever shared! Eve saw everything except Bob's private key.

Click <b>"See Full Animation"</b> to watch the entire process!""",
		"info": """✅ <b>Why This Works</b>

<b>What Eve Saw:</b>
• Bob's public key ✓
• Encrypted message ✓
• Network traffic ✓

<b>What Eve Didn't See:</b>
• Bob's private key ✗
• Original message ✗

<b>The Breakthrough:</b>
Alice and Bob communicated securely without ever meeting to exchange a secret key!

<b>Practical Use:</b>
This solves the key distribution problem. It's why you can safely:
• Buy things online
• Use online banking
• Send private emails
• Access work VPNs""",
		"action_text": "See Full Animation"
	},
	
	Phase.REAL_WORLD: {
		"title": "Real-World Applications",
		"instruction": """🌍 <b>Where You Use This Every Day</b>

Asymmetric cryptography powers modern security:

🌐 <b>HTTPS</b> - Secure websites
   When you see the padlock in your browser, asymmetric crypto is protecting you!

🔑 <b>SSH</b> - Secure remote access
   Connect to servers securely without passwords

💰 <b>Bitcoin & Cryptocurrencies</b>
   Your wallet address is your public key!

✉️ <b>Email Encryption (PGP)</b>
   Send encrypted emails

📱 <b>Signal/WhatsApp</b>
   End-to-end encryption uses this

Click <b>"Learn More"</b> for details!""",
		"info": """💡 <b>Hybrid Cryptography</b>

In practice, websites use BOTH:

1️⃣ <b>Asymmetric</b> - To share a session key
   (Slow but solves key distribution)

2️⃣ <b>Symmetric</b> - To encrypt actual data
   (Fast but needs a shared key)

<b>Example (HTTPS):</b>
• Browser gets website's public key
• Browser encrypts random session key
• Both use session key for fast symmetric encryption

<b>Best of Both Worlds:</b>
✅ Secure key exchange (asymmetric)
✅ Fast data encryption (symmetric)

This is how your browser secures your passwords, credit cards, and personal data!""",
		"action_text": "Learn More"
	},
	
	Phase.QUIZ: {
		"title": "Test Your Understanding!",
		"instruction": """📝 <b>Quick Quiz</b>

Answer these questions to test your knowledge:

<b>Q1:</b> Can Eve decrypt a message encrypted with Bob's public key?
   A) Yes, if she has the public key
   B) No, she needs Bob's private key
   C) Yes, with enough computing power in 5 minutes

<b>Q2:</b> What can you do with someone's public key?
   A) Decrypt their messages
   B) Encrypt messages TO them
   C) Steal their identity

<b>Q3:</b> Why is the private key called "private"?
   A) It's embarrassing
   B) It must never be shared with anyone
   C) It's encrypted

Click an answer to continue!""",
		"info": """🎓 <b>Key Takeaways</b>

<b>Public Key:</b>
• Like a padlock or mailbox
• Share it with everyone
• Used to ENCRYPT messages TO you
• Useless for decryption

<b>Private Key:</b>
• Like the only key to your house
• Never share it with anyone
• Used to DECRYPT messages FOR you
• Must be kept absolutely secret

<b>The Revolution:</b>
Before 1970s: Impossible to communicate securely without meeting first
After: Secure communication with strangers across the internet!""",
		"action_text": "Take Quiz"
	}
}

func _ready():
	setup_ui()
	load_phase(Phase.INTRO)
	glossary_panel.visible = false
	$HintPanel.visible = false

func setup_ui():
	# Create visual area nodes
	create_character_nodes()
	
	# Connect buttons
	btn_next.pressed.connect(_on_next_pressed)
	btn_try_action.pressed.connect(_on_try_action_pressed)
	btn_show_hint.pressed.connect(_on_show_hint_pressed)
	btn_glossary.pressed.connect(_on_glossary_pressed)
	$GlossaryPanel/CloseButton.pressed.connect(func(): glossary_panel.visible = false)

func create_character_nodes():
	# Clear visual area
	for child in visual_area.get_children():
		child.queue_free()
	
	# Create a grid layout for characters
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	visual_area.add_child(grid)
	
	# Create Alice
	alice_node = create_character_panel("👩 Alice", "Sender", Color(0.3, 0.6, 0.9))
	grid.add_child(alice_node)
	
	# Create Network
	var network_node = create_character_panel("🌐 Network", "Public (Eve watches)", Color(0.9, 0.6, 0.3))
	grid.add_child(network_node)
	
	# Create Bob
	bob_node = create_character_panel("👨 Bob", "Receiver", Color(0.3, 0.9, 0.6))
	grid.add_child(bob_node)
	
	# Create Eve below
	eve_node = create_character_panel("👁️ Eve", "Eavesdropper", Color(0.9, 0.3, 0.3))
	visual_area.add_child(eve_node)

func create_character_panel(char_name: String, role: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 150)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var role_label = Label.new()
	role_label.text = role
	role_label.add_theme_font_size_override("font_size", 14)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	vbox.add_child(name_label)
	vbox.add_child(role_label)
	panel.add_child(vbox)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func load_phase(phase: Phase):
	current_phase = phase
	var data = phase_data[phase]
	
	phase_title.text = data["title"]
	instruction_text.text = data["instruction"]
	info_panel.text = data["info"]
	
	# Update progress bar
	progress_bar.value = (float(phase) / float(Phase.QUIZ)) * 100
	
	# Show/hide action button
	if data["action_text"] != "":
		btn_try_action.visible = true
		btn_try_action.text = data["action_text"]
	else:
		btn_try_action.visible = false
	
	# Update next button
	if phase == Phase.QUIZ:
		btn_next.text = "Finish"
	else:
		btn_next.text = "Next →"
	
	# Phase-specific setup
	setup_phase_visuals(phase)

func setup_phase_visuals(phase: Phase):
	# Clear previous animations
	for child in visual_area.get_children():
		if child.has_meta("animation"):
			child.queue_free()
	
	match phase:
		Phase.INTRO:
			show_intro_visual()
		Phase.KEY_GENERATION:
			show_key_generation_visual()
		Phase.PUBLIC_KEY_SHARE:
			show_public_key_visual()
		Phase.ENCRYPTION_DEMO:
			show_encryption_visual()
		Phase.DECRYPTION_DEMO:
			show_decryption_visual()

func show_intro_visual():
	# Simple welcome visual
	pass

func show_key_generation_visual():
	# Add visual representation of keys to Bob's panel
	if bob_node and bob_node.get_child_count() > 0:
		var vbox = bob_node.get_child(0) as VBoxContainer
		
		# Clear old keys
		for child in vbox.get_children():
			if child.has_meta("key"):
				child.queue_free()
		
		var private_key = Label.new()
		private_key.text = "🔐 Private Key\n(Secret!)"
		private_key.add_theme_font_size_override("font_size", 12)
		private_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		private_key.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
		private_key.set_meta("key", true)
		
		var public_key = Label.new()
		public_key.text = "🔑 Public Key\n(Shareable)"
		public_key.add_theme_font_size_override("font_size", 12)
		public_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		public_key.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
		public_key.set_meta("key", true)
		
		vbox.add_child(private_key)
		vbox.add_child(public_key)

func show_public_key_visual():
	# Show public key being transmitted
	pass

func show_encryption_visual():
	# Show encryption process
	pass

func show_decryption_visual():
	# Show decryption process
	pass

func _on_next_pressed():
	if current_phase == Phase.QUIZ:
		show_completion()
	else:
		var next_phase = current_phase + 1
		if next_phase <= Phase.QUIZ:
			load_phase(next_phase)

func _on_try_action_pressed():
	match current_phase:
		Phase.SYMMETRIC_PROBLEM:
			animate_symmetric_failure()
		Phase.ASYMMETRIC_CONCEPT:
			show_padlock_analogy()
		Phase.KEY_GENERATION:
			animate_key_generation()
		Phase.PUBLIC_KEY_SHARE:
			animate_public_key_sharing()
		Phase.ENCRYPTION_DEMO:
			animate_encryption()
		Phase.DECRYPTION_DEMO:
			animate_decryption()
		Phase.COMPLETE_EXCHANGE:
			animate_full_process()
		Phase.REAL_WORLD:
			show_real_world_examples()
		Phase.QUIZ:
			show_quiz()

func animate_symmetric_failure():
	var message = create_message_node("🔑 Symmetric Key: SECRET123", Color(1, 0.5, 0.5))
	visual_area.add_child(message)
	
	var tween = create_tween()
	tween.tween_property(message, "position", Vector2(300, 200), 1.0)
	await tween.finished
	
	# Eve steals it
	var stolen = Label.new()
	stolen.text = "👁️ Eve: I stole the key!"
	stolen.add_theme_font_size_override("font_size", 18)
	stolen.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	eve_node.get_child(0).add_child(stolen)

func show_padlock_analogy():
	var dialog = AcceptDialog.new()
	dialog.dialog_text = """🔒 Padlock Analogy:

1. Bob gives everyone a padlock (public key)
2. Alice puts her message in a box and locks it with Bob's padlock
3. Alice sends the locked box over the network
4. Eve can see the box, but can't open it (no key!)
5. Only Bob has the key to his padlock (private key)
6. Bob unlocks the box and reads the message

The magic: Even though Eve has identical padlocks, she can't open boxes locked by others!"""
	dialog.title = "Visual Analogy"
	add_child(dialog)
	dialog.popup_centered()

func animate_key_generation():
	show_key_generation_visual()
	
	var feedback = Label.new()
	feedback.text = "✅ Bob's keys generated!\n🔐 Private: Kept secret\n🔑 Public: Ready to share"
	feedback.add_theme_font_size_override("font_size", 16)
	feedback.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	visual_area.add_child(feedback)
	feedback.position = Vector2(50, 400)

func animate_public_key_sharing():
	var message = create_message_node("🔑 Bob's Public Key", Color(0.5, 1, 0.5))
	visual_area.add_child(message)
	message.position = bob_node.position + Vector2(0, 100)
	
	var tween = create_tween()
	tween.tween_property(message, "position", alice_node.position + Vector2(0, 100), 1.5)
	await tween.finished
	
	# Show Eve also got it
	var eve_copy = create_message_node("🔑 (Eve copied it)", Color(1, 0.7, 0.5))
	visual_area.add_child(eve_copy)
	eve_copy.position = message.position
	
	var tween2 = create_tween()
	tween2.tween_property(eve_copy, "position", eve_node.position + Vector2(0, -50), 1.0)

func animate_encryption():
	var plaintext = create_message_node("📝 Meet at noon", Color(1, 1, 0.7))
	visual_area.add_child(plaintext)
	plaintext.position = alice_node.position + Vector2(0, 100)
	
	await get_tree().create_timer(1.0).timeout
	
	# Transform to encrypted
	plaintext.queue_free()
	var encrypted = create_message_node("🔒 Xj9K2mP7qWz...", Color(0.5, 0.9, 0.5))
	visual_area.add_child(encrypted)
	encrypted.position = alice_node.position + Vector2(0, 100)

func animate_decryption():
	var encrypted = create_message_node("🔒 Xj9K2mP7qWz...", Color(0.7, 0.7, 0.7))
	visual_area.add_child(encrypted)
	encrypted.position = bob_node.position + Vector2(0, 100)
	
	await get_tree().create_timer(1.0).timeout
	
	# Transform to plaintext
	encrypted.queue_free()
	var plaintext = create_message_node("📝 Meet at noon", Color(0.5, 1, 0.5))
	visual_area.add_child(plaintext)
	plaintext.position = bob_node.position + Vector2(0, 100)
	
	# Show Eve frustrated
	var frustrated = Label.new()
	frustrated.text = "❌ Can't decrypt!"
	frustrated.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	eve_node.get_child(0).add_child(frustrated)

func animate_full_process():
	# Play complete animation sequence
	show_key_generation_visual()
	await get_tree().create_timer(1.0).timeout
	await animate_public_key_sharing()
	await get_tree().create_timer(1.0).timeout
	await animate_encryption()
	await get_tree().create_timer(1.0).timeout
	# Move message across network
	await get_tree().create_timer(1.0).timeout
	await animate_decryption()

func show_real_world_examples():
	var examples = """🌍 Real-World Uses:

🌐 HTTPS - Every time you visit a secure website
🔑 SSH - Connecting to servers securely
💰 Bitcoin - Your wallet IS a key pair!
✉️ PGP Email - Encrypted email
📱 Signal/WhatsApp - End-to-end encryption
🏦 Banking Apps - Secure transactions
☁️ VPNs - Encrypted tunnels
📦 Software Signing - Verify authentic updates"""
	
	var dialog = AcceptDialog.new()
	dialog.dialog_text = examples
	dialog.title = "You Use This Every Day!"
	add_child(dialog)
	dialog.popup_centered()

func show_quiz():
	# Show quiz dialog
	var quiz_dialog = ConfirmationDialog.new()
	quiz_dialog.dialog_text = """Quick Check:

Q: Can Eve decrypt messages with Bob's public key?

A) Yes
B) No - only Bob's private key can decrypt"""
	quiz_dialog.title = "Quiz Question 1/3"
	add_child(quiz_dialog)
	quiz_dialog.confirmed.connect(func(): 
		score += 1
		show_quiz_q2()
	)
	quiz_dialog.canceled.connect(func(): show_quiz_q2())
	quiz_dialog.popup_centered()

func show_quiz_q2():
	var quiz_dialog = ConfirmationDialog.new()
	quiz_dialog.dialog_text = """Q: What can you do with someone's public key?

A) Decrypt their messages
B) Encrypt messages TO them (correct!)"""
	quiz_dialog.title = "Quiz Question 2/3"
	add_child(quiz_dialog)
	quiz_dialog.confirmed.connect(func(): show_quiz_q3())
	quiz_dialog.canceled.connect(func(): 
		score += 1
		show_quiz_q3()
	)
	quiz_dialog.popup_centered()

func show_quiz_q3():
	var quiz_dialog = ConfirmationDialog.new()
	quiz_dialog.dialog_text = """Q: Why must the private key stay secret?

A) It's the only key that can decrypt messages
B) It's embarrassing"""
	quiz_dialog.title = "Quiz Question 3/3"
	add_child(quiz_dialog)
	quiz_dialog.confirmed.connect(func(): 
		score += 1
		show_completion()
	)
	quiz_dialog.canceled.connect(func(): show_completion())
	quiz_dialog.popup_centered()

func show_completion():
	var completion = AcceptDialog.new()
	completion.dialog_text = """🎉 Congratulations!

You've mastered Asymmetric Cryptography!

Score: %d/3

Key Concepts Learned:
✅ Public vs Private Keys
✅ One-way mathematical functions
✅ Secure key exchange
✅ Real-world applications

You now understand the foundation of modern internet security!""" % score
	completion.title = "Tutorial Complete!"
	add_child(completion)
	completion.confirmed.connect(func(): get_tree().quit())
	completion.popup_centered()

func create_message_node(text: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.set_meta("animation", true)
	
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _on_show_hint_pressed():
	var hints = {
		Phase.INTRO: "This is just an introduction. Click Next when ready!",
		Phase.SYMMETRIC_PROBLEM: "Think about how you'd share a password with someone you've never met.",
		Phase.ASYMMETRIC_CONCEPT: "Remember: Public key = padlock everyone can close. Private key = the only key that opens it.",
		Phase.KEY_GENERATION: "The private key is generated first, then the public key is calculated from it.",
		Phase.PUBLIC_KEY_SHARE: "It's OK if Eve sees the public key - she still can't decrypt anything!",
		Phase.ENCRYPTION_DEMO: "Only Bob's private key can decrypt this. Even Alice can't decrypt it anymore!",
		Phase.DECRYPTION_DEMO: "The mathematical relationship between the keys makes this possible.",
		Phase.COMPLETE_EXCHANGE: "Notice how no secret was ever shared - yet secure communication happened!",
		Phase.REAL_WORLD: "Every HTTPS website uses this to protect your passwords and credit cards.",
		Phase.QUIZ: "Think carefully about what each key can and cannot do."
	}
	
	hint_label.text = "💡 Hint: " + hints[current_phase]
	$HintPanel.visible = true
	
	await get_tree().create_timer(4.0).timeout
	$HintPanel.visible = false

func _on_glossary_pressed():
	glossary_panel.visible = !glossary_panel.visible
