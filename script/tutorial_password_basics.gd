extends Control

# UI References
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/SectionLabel
@onready var content_text: RichTextLabel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentText
@onready var interactive_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/InteractivePanel
@onready var interactive_content: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/InteractivePanel/MarginContainer/InteractiveContent
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var term_popup: PanelContainer = $DarkOverlay/TermPopup
@onready var term_title: Label = $DarkOverlay/TermPopup/VBox/TermTitle
@onready var term_definition: Label = $DarkOverlay/TermPopup/VBox/TermDefinition
@onready var term_close_btn: Button = $DarkOverlay/TermPopup/VBox/CloseBtn
@onready var dark_overlay: ColorRect = $DarkOverlay

# Game State
enum GameState { BRIEFING, PASSWORD_BUILD, BATTLE, VICTORY, DEFEAT }
var current_state: GameState = GameState.BRIEFING
var current_wave := 0
var waves := []

# Battle System
var player_password := ""
var player_health := 100.0
var bot_health := 100.0
var attack_timer := 0.0
var attack_interval := 0.5  # Bot attacks every 0.5 seconds
var player_score := 0
var battle_active := false
var attempts_shown := 0

# Fake password attempts for realistic display
var common_attempts := [
	"password", "123456", "admin", "qwerty", "letmein", 
	"welcome", "monkey", "dragon", "master", "sunshine",
	"password123", "12345678", "abc123", "iloveyou", "admin123",
	"Password1", "Welcome1", "Qwerty123", "P@ssword", "Admin@123"
]

# Password Strength Metrics
var password_strength := 0  # 0-100
var unlocked_features := {
	"lowercase": true,  # Always available
	"uppercase": false,
	"numbers": false,
	"special": false,
	"length_12": false,
	"length_16": false
}

# Cybersecurity Terms Dictionary
var terms := {
	"Password": "A secret word or phrase used to prove your identity when accessing a computer, website, or account. Think of it like a key to your digital house.",
	"Strong Password": "A password that is hard for others (and computers) to guess. It should be long (12+ characters), use different types of characters (ABC, 123, !@#), and avoid common words.",
	"Weak Password": "A password that is easy to guess, like '123456', 'password', or your birthday. Hackers can crack these in seconds using computers.",
	"Hacker": "A person who tries to break into computers or accounts without permission. They use special tools and tricks to steal information or cause damage.",
	"Brute Force Attack": "When a hacker's computer tries thousands or millions of password combinations automatically until it finds the right one. Longer passwords take exponentially longer to crack.",
	"Dictionary Attack": "When hackers use a list of common words (like a dictionary) to guess your password. That's why 'apple123' or 'football' are bad passwords.",
	"Pattern Attack": "When hackers look for keyboard patterns like 'qwerty', '12345', or 'asdfgh'. These are incredibly common and easy to crack.",
	"Personal Info Attack": "Hackers use information about you (birthday, pet names, favorite things) to guess your password. Never use personal details!",
	"Rainbow Table": "A massive pre-computed database of password hashes. Makes cracking hashed passwords much faster, but useless against strong, unique passwords.",
	"Character": "Any single letter, number, or symbol in your password. For example, 'A', '7', and '!' are each one character.",
	"Special Characters": "Symbols like !@#$%^&*() that aren't letters or numbers. They make passwords exponentially harder to guess.",
	"Password Manager": "A secure app that remembers all your passwords for you, so you only need to remember ONE master password."
}


func _ready() -> void:
	_initialize_waves()
	_start_wave(current_wave)
	_setup_signals()
	back_button.disabled = false  # Enable back button on first screen
	print("✅ Password Fortress Defender Ready!")


func _process(delta: float) -> void:
	if current_state == GameState.BATTLE and battle_active:
		_update_battle(delta)


func _setup_signals() -> void:
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	term_close_btn.pressed.connect(_close_term_popup)


func _initialize_waves() -> void:
	waves = [
		# WAVE 0: Welcome & Tutorial
		{
			"wave_num": 0,
			"title": "🏰 WELCOME TO PASSWORD FORTRESS DEFENDER",
			"enemy_name": "Tutorial",
			"state": GameState.BRIEFING,
			"content": """[center][b][color=cyan]MISSION BRIEFING[/color][/b][/center]

Welcome, Security Cadet! You've been recruited to defend the Digital Fortress against an army of password-cracking bots!

[b]YOUR MISSION:[/b]
🛡️ Build strong [color=blue][url=Password]passwords[/url][/color] to defend against waves of attacks
⚔️ Each wave brings a new type of [color=blue][url=Hacker]hacker[/url][/color] attack
🎯 Learn WHY passwords fail and HOW to stop them
🏆 Earn unlocks to build even stronger defenses

[b]HOW TO PLAY:[/b]
1️⃣ [color=yellow]BRIEFING[/color] - Learn about the incoming attack
2️⃣ [color=yellow]BUILD[/color] - Create a password strong enough to defend
3️⃣ [color=yellow]BATTLE[/color] - Watch your defense hold (or crumble!)
4️⃣ [color=yellow]VICTORY[/color] - Unlock new password weapons!

[color=red][b]WARNING:[/b][/color] Each attack gets smarter and more powerful!

Are you ready to defend the fortress? Click NEXT to face your first enemy! →""",
			"interactive": false
		},
		
		# WAVE 1: Dictionary Attack
		{
			"wave_num": 1,
			"title": "⚔️ WAVE 1: DICTIONARY ATTACK BOT",
			"enemy_name": "Dictionary Bot",
			"bot_power": 30,
			"attack_speed": 0.8,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: DICTIONARY ATTACK BOT[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
📖 Uses a list of 10,000+ common passwords
💨 Tries 100 passwords per second
🎯 Targets: "password", "123456", "welcome", "qwerty"

[b]HOW [color=blue][url=Dictionary Attack]DICTIONARY ATTACKS[/url][/color] WORK:[/b]
Imagine a robot flipping through a dictionary trying every word as your password. It also tries:
• Common names (john, sarah, mike)
• Simple words (love, happy, football)
• Easy patterns (abc123, password1)

[color=yellow][b]REAL-WORLD STATS:[/b][/color]
• 80% of people use dictionary words
• "123456" is still the #1 most used password
• Average crack time: INSTANT (less than 1 second!)

[b]HOW TO DEFEND:[/b]
✅ Use at least 8 [color=blue][url=Character]characters[/url][/color]
✅ Mix uppercase and lowercase letters
✅ Don't use real dictionary words
✅ Add numbers and symbols

[color=green]Click NEXT to build your defense! →[/color]""",
			"interactive": false,
			"min_length": 8,
			"requires": ["lowercase"],
			"recommended": ["uppercase", "numbers"]
		},
		
		# WAVE 2: Brute Force Attack
		{
			"wave_num": 2,
			"title": "⚔️ WAVE 2: BRUTE FORCE ATTACK BOT",
			"enemy_name": "Brute Force Bot",
			"bot_power": 50,
			"attack_speed": 0.6,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: BRUTE FORCE ATTACK BOT[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
💪 Tries EVERY possible character combination
🚀 Tests 1,000,000 passwords per second
🎯 Never gives up until it cracks your password

[b]HOW [color=blue][url=Brute Force Attack]BRUTE FORCE ATTACKS[/url][/color] WORK:[/b]
Think of a bike lock with numbers 0-9. A brute force attack tries:
0000, 0001, 0002... 9998, 9999

With passwords, it tries:
a, b, c... aa, ab, ac... aaa, aab... until it finds yours!

[color=yellow][b]CRACK TIME EXAMPLES:[/b][/color]
• 6 characters (lowercase only): 2 seconds
• 8 characters (lowercase + uppercase): 1 hour
• 10 characters (letters + numbers): 3 weeks
• 12 characters (letters + numbers + symbols): 34,000 YEARS!

[b]HOW TO DEFEND:[/b]
✅ Use at least 12 [color=blue][url=Character]characters[/url][/color] (CRITICAL!)
✅ Mix uppercase, lowercase, numbers, AND [color=blue][url=Special Characters]special characters[/url][/color]
✅ More length = exponentially stronger!

[color=red][b]UNLOCK EARNED:[/b][/color] You can now use UPPERCASE letters!

[color=green]Click NEXT to build an unbreakable defense! →[/color]""",
			"interactive": false,
			"min_length": 12,
			"requires": ["lowercase", "uppercase", "numbers"],
			"recommended": ["special"]
		},
		
		# WAVE 3: Pattern Attack
		{
			"wave_num": 3,
			"title": "⚔️ WAVE 3: PATTERN RECOGNITION BOT",
			"enemy_name": "Pattern Bot",
			"bot_power": 60,
			"attack_speed": 0.5,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: PATTERN RECOGNITION BOT[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
🧠 AI-powered pattern detection
⌨️ Looks for keyboard patterns and sequences
🎯 Targets: "qwerty", "12345", "asdfgh", "abc123"

[b]HOW [color=blue][url=Pattern Attack]PATTERN ATTACKS[/url][/color] WORK:[/b]
Hackers know humans are lazy! We type patterns on the keyboard:
• Rows: qwertyuiop, asdfghjkl
• Columns: 1qaz, 2wsx, 3edc
• Sequences: 123456, abcdef
• Repeating: aaaaaa, 111111

[color=yellow][b]SURPRISING FACTS:[/b][/color]
• "qwerty" is the 4th most common password
• 15% of passwords are keyboard patterns
• Adding "123" to a word doesn't help!

[b]HOW TO DEFEND:[/b]
✅ Avoid keyboard rows/columns
✅ Don't use sequential numbers or letters
✅ Mix characters randomly throughout
✅ Use [color=blue][url=Special Characters]special characters[/url][/color] between letters

[color=red][b]UNLOCK EARNED:[/b][/color] You can now use NUMBERS!

[color=green]Click NEXT to outsmart the AI! →[/color]""",
			"interactive": false,
			"min_length": 12,
			"requires": ["lowercase", "uppercase", "numbers"],
			"recommended": ["special"]
		},
		
		# WAVE 4: Personal Info Attack
		{
			"wave_num": 4,
			"title": "⚔️ WAVE 4: PERSONAL INFO SNIPER BOT",
			"enemy_name": "Social Engineer Bot",
			"bot_power": 70,
			"attack_speed": 0.4,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: PERSONAL INFO SNIPER BOT[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
🕵️ Scrapes your social media profiles
🎂 Uses your birthday, pet names, favorite things
🎯 Targets: "john2010", "fluffy123", "soccer2024"

[b]HOW [color=blue][url=Personal Info Attack]PERSONAL INFO ATTACKS[/url][/color] WORK:[/b]
Hackers research YOU before attacking:
• Facebook: Your birthday, pet names, school
• Instagram: Your hobbies, favorite bands
• LinkedIn: Your job, education
• Twitter: Your interests, favorite sports teams

Then they try passwords like:
• YourName + Birthday: "sarah1995"
• Pet + Year: "max2020"
• Hobby + Number: "soccer7"

[color=yellow][b]SCARY STATS:[/b][/color]
• 50% of people use personal info in passwords
• Average person has 100+ facts online
• Hackers can crack these in minutes

[b]HOW TO DEFEND:[/b]
✅ NEVER use your name, birthday, or pet names
✅ Don't use info from your social media
✅ Use random, unrelated words + symbols
✅ Think: "Would a stranger know this about me?"

[color=red][b]UNLOCK EARNED:[/b][/color] You can now use SPECIAL CHARACTERS (!@#$%)!

[color=green]Click NEXT to become invisible! →[/color]""",
			"interactive": false,
			"min_length": 14,
			"requires": ["lowercase", "uppercase", "numbers", "special"],
			"recommended": []
		},
		
		# WAVE 5: Rainbow Table Attack
		{
			"wave_num": 5,
			"title": "⚔️ WAVE 5: RAINBOW TABLE ASSASSIN",
			"enemy_name": "Rainbow Table Bot",
			"bot_power": 85,
			"attack_speed": 0.3,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: RAINBOW TABLE ASSASSIN[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
🌈 Uses pre-computed hash databases
⚡ Can crack billions of passwords instantly
🎯 Targets: Weak passwords with common patterns

[b]HOW [color=blue][url=Rainbow Table]RAINBOW TABLE ATTACKS[/url][/color] WORK:[/b]
When websites store passwords, they "hash" them (encrypt):
• "password" → "5f4dcc3b5aa765d61d8327deb882cf99"
• "123456" → "e10adc3949ba59abbe56e057f20f883e"

Hackers create MASSIVE databases with billions of pre-cracked hashes. Instead of guessing, they just LOOK UP your password's hash!

[color=yellow][b]TECHNICAL REALITY:[/b][/color]
• Rainbow tables contain 100+ billion hashes
• Can crack simple passwords in milliseconds
• Only unique, complex passwords survive

[b]HOW TO DEFEND:[/b]
✅ Use 16+ [color=blue][url=Character]characters[/url][/color] (rainbow tables can't pre-compute that many!)
✅ Maximum randomness and complexity
✅ Every character type (aAbB12!@)
✅ Truly unique - never reused anywhere

[color=red][b]UNLOCK EARNED:[/b][/color] Extended length limit (16+ chars)!

[color=green]Click NEXT to face the ultimate defense! →[/color]""",
			"interactive": false,
			"min_length": 16,
			"requires": ["lowercase", "uppercase", "numbers", "special"],
			"recommended": []
		},
		
		# WAVE 6: AI-Powered Attack
		{
			"wave_num": 6,
			"title": "⚔️ WAVE 6: AI-POWERED MEGA BOT",
			"enemy_name": "AI Neural Network",
			"bot_power": 95,
			"attack_speed": 0.2,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=red]🤖 INCOMING THREAT: AI-POWERED MEGA BOT[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
🧠 Machine learning password predictor
🎯 Learns from millions of leaked passwords
⚡ Adapts and evolves during attacks

[b]HOW MODERN AI ATTACKS WORK:[/b]
The bot has analyzed 15 BILLION leaked passwords and learned:
• Common substitutions (a→@, e→3, o→0)
• Popular phrases and how people modify them
• Psychological patterns humans use
• Language-specific password habits

It predicts your NEXT character based on previous ones!

Example: You type "Pass" → AI predicts "word123" (90% chance)

[color=yellow][b]2025 REALITY:[/b][/color]
• AI can crack 80% of "modified" passwords
• "P@ssw0rd!" is instantly detected
• Human patterns = predictable to AI

[b]HOW TO DEFEND:[/b]
✅ Think BEYOND human patterns
✅ Use completely random character placement
✅ Mix unrelated words + symbols + numbers
✅ Example: "7!Moon$Carpet#3Piano@"

[color=green]Click NEXT to prove you're smarter than AI! →[/color]""",
			"interactive": false,
			"min_length": 16,
			"requires": ["lowercase", "uppercase", "numbers", "special"],
			"recommended": []
		},
		
		# WAVE 7: FINAL BOSS - Quantum Computer
		{
			"wave_num": 7,
			"title": "🔥 FINAL BOSS: QUANTUM SUPERCOMPUTER",
			"enemy_name": "Quantum Processor",
			"bot_power": 100,
			"attack_speed": 0.1,
			"state": GameState.BRIEFING,
			"content": """[center][b][color=purple]⚡ FINAL BOSS: QUANTUM SUPERCOMPUTER ⚡[/color][/b][/center]

[b]ENEMY ANALYSIS:[/b]
⚛️ Quantum computing technology
🌌 Processes infinite possibilities simultaneously
💀 The ultimate password destroyer

[b]THE QUANTUM THREAT:[/b]
Regular computers try passwords one at a time:
password1 → password2 → password3...

[color=purple]QUANTUM computers try ALL passwords AT ONCE![/color]

They use "quantum superposition" to exist in multiple states, testing millions of passwords SIMULTANEOUSLY.

[color=yellow][b]THE FUTURE IS HERE:[/b][/color]
• Google's quantum computer: 100 million times faster
• Can crack encryption that would take regular computers 10,000 years
• Expected to break current encryption by 2030

[b]HOW TO DEFEND:[/b]
✅ Maximum length (20+ characters)
✅ Complete randomness
✅ Every character type multiple times
✅ Basically unguessable by any means

[b][color=cyan]BONUS TIP:[/b][/color] Use a [color=blue][url=Password Manager]Password Manager[/url][/color] to generate TRUE random passwords!

[color=red][b]THIS IS IT![/b][/color] Can you create a password strong enough to stop a quantum computer?

[color=green]Click NEXT for the ultimate challenge! →[/color]""",
			"interactive": false,
			"min_length": 20,
			"requires": ["lowercase", "uppercase", "numbers", "special"],
			"recommended": []
		},
		
		# FINAL SCREEN: Congratulations
		{
			"wave_num": 8,
			"title": "🏆 FORTRESS DEFENDER - MISSION COMPLETE!",
			"enemy_name": "Victory",
			"state": GameState.BRIEFING,
			"content": """[center][b][color=green]🎉 CONGRATULATIONS, FORTRESS DEFENDER! 🎉[/color][/b][/center]

You've successfully defended the Digital Fortress against ALL password-cracking attacks!

[b]🏅 WHAT YOU'VE MASTERED:[/b]
✅ [color=blue][url=Dictionary Attack]Dictionary Attacks[/url][/color] - Beat common word lists
✅ [color=blue][url=Brute Force Attack]Brute Force Attacks[/url][/color] - Made passwords exponentially harder
✅ [color=blue][url=Pattern Attack]Pattern Attacks[/url][/color] - Outsmarted keyboard patterns
✅ Personal Info Attacks - Protected your digital identity
✅ [color=blue][url=Rainbow Table]Rainbow Tables[/url][/color] - Used unique, long passwords
✅ AI-Powered Attacks - Thought beyond human patterns
✅ Quantum Computing - Prepared for the future!

[b]🎯 YOUR TOTAL SCORE: [SCORE_PLACEHOLDER][/b]

[b][color=cyan]REAL-WORLD PASSWORD TIPS:[/color][/b]
1️⃣ Use a [color=blue][url=Password Manager]Password Manager[/url][/color] (1Password, Bitwarden, LastPass)
2️⃣ Never reuse passwords across sites
3️⃣ Change passwords if you suspect a breach
4️⃣ Enable 2-Factor Authentication (2FA) everywhere
5️⃣ Minimum 12 characters for regular accounts
6️⃣ Minimum 16 characters for important accounts (email, banking)

[color=yellow][b]PASSWORD STRENGTH FORMULA:[/b][/color]
Length > Complexity > Everything Else

A 16-character password with only lowercase is stronger than an 8-character password with everything!

[b]Remember:[/b] You're now a certified [color=green]Password Fortress Defender[/color]!
Share your knowledge and help others stay safe online! 🛡️

[color=green]Click BACK TO MENU to return to the tutorial hub →[/color]""",
			"interactive": false
		}
	]


func _start_wave(wave_index: int) -> void:
	if wave_index < 0 or wave_index >= waves.size():
		return
	
	var wave: Dictionary = waves[wave_index]
	current_state = wave.state
	section_label.text = wave.title
	content_text.clear()
	
	# Replace score placeholder in final wave
	var content_to_show: String = wave.content
	if wave_index == waves.size() - 1:
		content_to_show = content_to_show.replace("[SCORE_PLACEHOLDER]", str(player_score))
	
	content_text.append_text(content_to_show)
	
	# Clear previous interactive content
	for child in interactive_content.get_children():
		child.queue_free()
	
	interactive_panel.visible = false
	
	# Update button states - keep back button enabled on wave 0 to allow exit
	back_button.disabled = false
	
	if wave_index == waves.size() - 1:
		next_button.text = "BACK TO MENU"
	elif wave.get("state") == GameState.BRIEFING and wave_index > 0:
		next_button.text = "BUILD DEFENSE →"
	else:
		next_button.text = "NEXT →"


func _generate_password_guess(wave: Dictionary, attempt_num: int) -> String:
	var wave_num: int = wave.get("wave_num", 1)
	var guess := ""
	
	match wave_num:
		1:  # Dictionary Attack - try common passwords
			guess = common_attempts[randi() % common_attempts.size()]
		2:  # Brute Force - systematic combinations
			guess = _generate_brute_force_guess(attempt_num)
		3:  # Pattern Attack - keyboard patterns
			guess = _generate_pattern_guess(attempt_num)
		4, 5, 6, 7:  # Advanced attacks - smarter guessing
			guess = _generate_smart_guess(attempt_num)
		_:
			guess = common_attempts[randi() % common_attempts.size()]
	
	return guess


func _generate_brute_force_guess(attempt: int) -> String:
	# Systematic brute force (simplified)
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
	var length: int = min(4 + int(attempt / 10.0), 12)
	var result := ""
	for i in range(length):
		result += chars[(attempt + i) % chars.length()]
	return result


func _generate_pattern_guess(attempt: int) -> String:
	# Keyboard patterns
	var patterns := ["qwerty", "asdfgh", "zxcvbn", "123456", "qwerty123", 
					 "asdf1234", "1qaz2wsx", "qwertyuiop", "12345678"]
	return patterns[attempt % patterns.size()] + str(randi() % 100)


func _generate_smart_guess(attempt: int) -> String:
	# Mix of strategies - tries to adapt
	if attempt % 3 == 0:
		return common_attempts[randi() % common_attempts.size()]
	elif attempt % 3 == 1:
		return _generate_brute_force_guess(attempt)
	else:
		return _generate_pattern_guess(attempt)


func _calculate_match_percentage(actual_password: String, guess: String) -> float:
	# Calculate how close the guess is to the actual password
	if actual_password == guess:
		return 100.0  # Perfect match!
	
	var matches := 0
	var max_len: int = max(actual_password.length(), guess.length())
	var min_len: int = min(actual_password.length(), guess.length())
	
	# Check character-by-character matches
	for i in range(min_len):
		if actual_password[i] == guess[i]:
			matches += 2  # Correct position = 2 points
		elif guess.contains(actual_password[i]):
			matches += 1  # Contains character = 1 point
	
	# Length similarity bonus
	if actual_password.length() == guess.length():
		matches += 2
	
	var percentage := (float(matches) / float(max_len * 2)) * 100.0
	return clamp(percentage, 0.0, 100.0)


func _format_guess_display(actual_password: String, guess: String) -> String:
	# Format guess with matched characters highlighted
	var result := "[color=#999999]'"
	
	for i in range(guess.length()):
		if i < actual_password.length() and actual_password[i] == guess[i]:
			# Exact match at this position
			result += "[color=#ff0000]" + guess[i] + "[/color][color=#999999]"
		elif actual_password.contains(guess[i]):
			# Character exists but wrong position
			result += "[color=#ff9900]" + guess[i] + "[/color][color=#999999]"
		else:
			result += guess[i]
	
	result += "'[/color]"
	return result


func _generate_fake_hash() -> String:
	var chars := "0123456789abcdef"
	var hash_str := ""
	for i in range(32):
		hash_str += chars[randi() % chars.length()]
	return hash_str


func _advance_to_next_wave() -> void:
	# Clean up battle UI
	for child in interactive_content.get_children():
		child.queue_free()
	interactive_panel.visible = false
	content_text.visible = true
	next_button.visible = true
	
	# Move to next wave
	current_wave += 1
	if current_wave < waves.size():
		_start_wave(current_wave)
	else:
		# Game complete
		get_tree().change_scene_to_file("res://scene/landing.tscn")


func _on_next_pressed() -> void:
	var wave: Dictionary = waves[current_wave]
	
	# If final wave, return to menu
	if current_wave == waves.size() - 1:
		get_tree().change_scene_to_file("res://scene/landing.tscn")
		return
	
	# If defeated, retry the same wave
	if current_state == GameState.DEFEAT:
		_enter_password_build_phase()
		return
	
	# If in briefing of a combat wave, go to password building
	if wave.get("state") == GameState.BRIEFING and current_wave > 0 and current_wave < waves.size() - 1:
		_enter_password_build_phase()
	else:
		# Otherwise advance to next wave
		current_wave += 1
		_start_wave(current_wave)


func _on_back_pressed() -> void:
	# Only allow going back on the first wave (tutorial intro)
	if current_wave == 0:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	elif current_state == GameState.DEFEAT:
		# If defeated, go back to the current wave's briefing to try again
		content_text.visible = true
		interactive_panel.visible = false
		next_button.visible = true
		battle_active = false
		_start_wave(current_wave)  # Reload current wave's briefing
	elif current_state == GameState.PASSWORD_BUILD or current_state == GameState.BATTLE:
		# If in password build or battle phase, go back to the current wave's briefing
		content_text.visible = true
		interactive_panel.visible = false
		next_button.visible = true
		battle_active = false
		_start_wave(current_wave)  # Reload current wave's briefing
	elif current_wave > 0:
		# Otherwise go to previous wave
		current_wave -= 1
		_start_wave(current_wave)


func _enter_password_build_phase() -> void:
	current_state = GameState.PASSWORD_BUILD
	var wave: Dictionary = waves[current_wave]
	
	section_label.text = "🛠️ BUILD YOUR DEFENSE - " + wave.enemy_name
	# Hide content_text to give interactive panel full space
	content_text.visible = false
	content_text.clear()
	
	# Clear previous interactive content to prevent duplicates
	for child in interactive_content.get_children():
		child.queue_free()
	
	interactive_panel.visible = true
	_setup_password_builder(wave)
	
	# Hide the main NEXT button since we have a START BATTLE button in the interactive panel
	next_button.visible = false


func _format_requirements(reqs: Array) -> String:
	var formatted := []
	for req in reqs:
		match req:
			"lowercase": formatted.append("lowercase letters (abc)")
			"uppercase": formatted.append("UPPERCASE LETTERS (ABC)")
			"numbers": formatted.append("numbers (123)")
			"special": formatted.append("special characters (!@#)")
	return ", ".join(formatted)


func _format_unlocks() -> String:
	var unlocks := []
	if unlocked_features.lowercase: unlocks.append("✅ Lowercase Letters")
	if unlocked_features.uppercase: unlocks.append("✅ Uppercase Letters")
	if unlocked_features.numbers: unlocks.append("✅ Numbers")
	if unlocked_features.special: unlocks.append("✅ Special Characters")
	return "\n".join(unlocks)


func _setup_password_builder(wave: Dictionary) -> void:
	# Set dark theme for interactive panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)  # Dark background
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.8, 0.9, 0.5)  # Cyan border
	interactive_panel.add_theme_stylebox_override("panel", style)
	
	# Add header with requirements
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	header.text = "REQUIREMENTS: %d+ chars | %s" % [
		wave.get("min_length", 8),
		_format_requirements(wave.get("requires", []))
	]
	interactive_content.add_child(header)
	
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	interactive_content.add_child(spacer1)
	
	var input := LineEdit.new()
	input.name = "PasswordInput"
	input.placeholder_text = "Enter your fortress password..."
	input.custom_minimum_size = Vector2(0, 45)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))  # Cyan text
	input.add_theme_color_override("font_placeholder_color", Color(0.0, 0.6, 0.7, 0.6))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_width_top = 1
	input_style.border_width_bottom = 1
	input_style.border_color = Color(0.0, 0.8, 0.9, 0.3)
	input.add_theme_stylebox_override("normal", input_style)
	input.secret_character = "*"
	input.text_changed.connect(_on_password_build_changed.bind(wave))
	interactive_content.add_child(input)
	
	var strength_bar := ProgressBar.new()
	strength_bar.name = "StrengthBar"
	strength_bar.custom_minimum_size = Vector2(0, 30)
	strength_bar.max_value = 100
	strength_bar.value = 0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	strength_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.0, 0.9, 1.0, 1.0)  # Cyan
	strength_bar.add_theme_stylebox_override("fill", bar_fill)
	interactive_content.add_child(strength_bar)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	interactive_content.add_child(spacer2)
	
	var strength_label := Label.new()
	strength_label.name = "StrengthLabel"
	strength_label.text = "Password Strength: NOT SET"
	strength_label.add_theme_font_size_override("font_size", 16)
	strength_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))  # Cyan
	strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interactive_content.add_child(strength_label)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	interactive_content.add_child(spacer3)
	
	var criteria_label := Label.new()
	criteria_label.name = "CriteriaLabel"
	criteria_label.add_theme_font_size_override("font_size", 14)
	criteria_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 0.9))  # Cyan
	criteria_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	interactive_content.add_child(criteria_label)
	
	var spacer4 := Control.new()
	spacer4.custom_minimum_size = Vector2(0, 15)
	interactive_content.add_child(spacer4)
	
	var battle_button := Button.new()
	battle_button.name = "BattleButton"
	battle_button.text = "⚔️ START BATTLE"
	battle_button.custom_minimum_size = Vector2(0, 50)
	battle_button.add_theme_font_size_override("font_size", 20)
	battle_button.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))  # Cyan
	battle_button.add_theme_color_override("font_disabled_color", Color(0.0, 0.5, 0.6, 0.4))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.4, 0.5, 0.3)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.0, 0.8, 0.9, 0.5)
	battle_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.0, 0.5, 0.6, 0.5)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(0.0, 0.9, 1.0, 0.8)
	battle_button.add_theme_stylebox_override("hover", btn_hover)
	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.1, 0.1, 0.15, 0.5)  # Very dim
	btn_disabled.border_width_left = 2
	btn_disabled.border_width_right = 2
	btn_disabled.border_width_top = 2
	btn_disabled.border_width_bottom = 2
	btn_disabled.border_color = Color(0.0, 0.3, 0.4, 0.3)  # Very dim cyan
	battle_button.add_theme_stylebox_override("disabled", btn_disabled)
	battle_button.disabled = true
	battle_button.pressed.connect(_start_battle.bind(wave))
	interactive_content.add_child(battle_button)


func _on_password_build_changed(new_text: String, wave: Dictionary) -> void:
	player_password = new_text
	var strength_bar: ProgressBar = interactive_content.get_node("StrengthBar")
	var strength_label: Label = interactive_content.get_node("StrengthLabel")
	var criteria_label: Label = interactive_content.get_node("CriteriaLabel")
	var battle_button: Button = interactive_content.get_node("BattleButton")
	
	# Analyze password
	var length := new_text.length()
	var has_upper := false
	var has_lower := false
	var has_num := false
	var has_spec := false
	
	for c in new_text:
		if c >= 'A' and c <= 'Z': has_upper = true
		elif c >= 'a' and c <= 'z': has_lower = true
		elif c >= '0' and c <= '9': has_num = true
		elif c in "!@#$%^&*()_+-=[]{}|;:,.<>?": has_spec = true
	
	# Calculate strength
	var strength := 0
	if length >= 8: strength += 20
	if length >= 12: strength += 20
	if length >= 16: strength += 20
	if has_lower: strength += 10
	if has_upper: strength += 10
	if has_num: strength += 10
	if has_spec: strength += 10
	
	password_strength = strength
	strength_bar.value = strength
	
	# Update color (only cyan variations)
	if strength < 40:
		strength_label.add_theme_color_override("font_color", Color(0.0, 0.5, 0.6, 1.0))  # Dim cyan
		strength_label.text = "Password Strength: WEAK (Getting Hacked!)"
	elif strength < 70:
		strength_label.add_theme_color_override("font_color", Color(0.0, 0.7, 0.8, 1.0))  # Medium cyan
		strength_label.text = "Password Strength: OKAY (Might Hold...)"
	elif strength < 90:
		strength_label.add_theme_color_override("font_color", Color(0.0, 0.85, 0.95, 1.0))  # Bright cyan
		strength_label.text = "Password Strength: GOOD (Looking Strong!)"
	else:
		strength_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))  # Pure cyan
		strength_label.text = "Password Strength: EXCELLENT (Fortress Secured!)"
	
	# Check requirements
	var min_length: int = wave.get("min_length", 8)
	var requires: Array = wave.get("requires", [])
	var criteria_text := ""
	var meets_requirements := true
	
	if length >= min_length:
		criteria_text += "✅ Length (%d/%d)\n" % [length, min_length]
	else:
		criteria_text += "❌ Length (%d/%d)\n" % [length, min_length]
		meets_requirements = false
	
	for req in requires:
		match req:
			"lowercase":
				if has_lower:
					criteria_text += "✅ Lowercase letters\n"
				else:
					criteria_text += "❌ Lowercase letters\n"
					meets_requirements = false
			"uppercase":
				if has_upper:
					criteria_text += "✅ Uppercase letters\n"
				else:
					criteria_text += "❌ Uppercase letters\n"
					meets_requirements = false
			"numbers":
				if has_num:
					criteria_text += "✅ Numbers\n"
				else:
					criteria_text += "❌ Numbers\n"
					meets_requirements = false
			"special":
				if has_spec:
					criteria_text += "✅ Special characters\n"
				else:
					criteria_text += "❌ Special characters\n"
					meets_requirements = false
	
	criteria_label.text = criteria_text
	battle_button.disabled = !meets_requirements


func _start_battle(wave: Dictionary) -> void:
	current_state = GameState.BATTLE
	battle_active = true
	player_health = 100.0
	bot_health = 100.0
	attack_timer = 0.0
	attempts_shown = 0
	
	section_label.text = "⚔️ BATTLE IN PROGRESS - " + wave.enemy_name
	# Clear content text completely to prevent stretching
	content_text.clear()
	content_text.visible = false  # Hide the content area during battle
	
	# Clear builder UI
	for child in interactive_content.get_children():
		child.queue_free()
	
	interactive_panel.visible = true
	
	# Create battle UI with dark theme
	var player_health_label := Label.new()
	player_health_label.name = "PlayerHealthLabel"
	player_health_label.text = "🛡️ YOUR DEFENSE: 100%"
	player_health_label.add_theme_font_size_override("font_size", 18)
	player_health_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))  # Cyan
	interactive_content.add_child(player_health_label)
	
	var player_health_bar := ProgressBar.new()
	player_health_bar.name = "PlayerHealthBar"
	player_health_bar.max_value = 100
	player_health_bar.value = 100
	player_health_bar.custom_minimum_size = Vector2(0, 25)
	var p_bar_bg := StyleBoxFlat.new()
	p_bar_bg.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	player_health_bar.add_theme_stylebox_override("background", p_bar_bg)
	var p_bar_fill := StyleBoxFlat.new()
	p_bar_fill.bg_color = Color(0.0, 0.9, 1.0, 1.0)  # Cyan
	player_health_bar.add_theme_stylebox_override("fill", p_bar_fill)
	interactive_content.add_child(player_health_bar)
	
	var bot_health_label := Label.new()
	bot_health_label.name = "BotHealthLabel"
	bot_health_label.text = "🤖 BOT ATTACK POWER: 100%"
	bot_health_label.add_theme_font_size_override("font_size", 18)
	bot_health_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 1.0))  # Gray
	interactive_content.add_child(bot_health_label)
	
	var bot_health_bar := ProgressBar.new()
	bot_health_bar.name = "BotHealthBar"
	bot_health_bar.max_value = 100
	bot_health_bar.value = 100
	bot_health_bar.custom_minimum_size = Vector2(0, 25)
	var b_bar_bg := StyleBoxFlat.new()
	b_bar_bg.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	bot_health_bar.add_theme_stylebox_override("background", b_bar_bg)
	var b_bar_fill := StyleBoxFlat.new()
	b_bar_fill.bg_color = Color(0.3, 0.3, 0.35, 1.0)  # Dark gray
	bot_health_bar.add_theme_stylebox_override("fill", b_bar_fill)
	interactive_content.add_child(bot_health_bar)
	
	var attempts_label := Label.new()
	attempts_label.name = "AttemptsLabel"
	attempts_label.text = "Attack attempts: 0"
	attempts_label.add_theme_font_size_override("font_size", 14)
	attempts_label.add_theme_color_override("font_color", Color(0.0, 0.7, 0.8, 0.8))  # Cyan
	interactive_content.add_child(attempts_label)
	
	var log_label := RichTextLabel.new()
	log_label.name = "LogLabel"
	log_label.custom_minimum_size = Vector2(0, 200)
	log_label.add_theme_font_size_override("mono_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.0, 0.9, 1.0, 0.9))  # Cyan
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.0, 0.0, 0.0, 0.95)  # Pure black like terminal
	log_style.border_width_left = 1
	log_style.border_width_right = 1
	log_style.border_width_top = 1
	log_style.border_width_bottom = 1
	log_style.border_color = Color(0.0, 0.8, 0.9, 0.5)
	log_style.content_margin_left = 8
	log_style.content_margin_right = 8
	log_style.content_margin_top = 8
	log_style.content_margin_bottom = 8
	log_label.add_theme_stylebox_override("normal", log_style)
	log_label.scroll_following = true
	log_label.bbcode_enabled = true
	# Add terminal header
	log_label.append_text("[color=#00ff00]> INITIALIZING DEFENSE SYSTEM...[/color]\n")
	log_label.append_text("[color=#00ff00]> PASSWORD HASH: %s[/color]\n" % _generate_fake_hash())
	log_label.append_text("[color=#ffff00]> WARNING: ATTACK DETECTED![/color]\n")
	log_label.append_text("[color=#00ffff]> MONITORING ATTEMPTS...\n\n[/color]")
	interactive_content.add_child(log_label)
	
	next_button.visible = false


func _update_battle(delta: float) -> void:
	if !battle_active:
		return
	
	attack_timer += delta
	var wave: Dictionary = waves[current_wave]
	var bot_attack_speed: float = wave.get("attack_speed", 0.5)
	
	if attack_timer >= bot_attack_speed:
		attack_timer = 0.0
		_process_bot_attack(wave)


func _process_bot_attack(wave: Dictionary) -> void:
	attempts_shown += 1
	
	var player_health_bar: ProgressBar = interactive_content.get_node("PlayerHealthBar")
	var player_health_label: Label = interactive_content.get_node("PlayerHealthLabel")
	var bot_health_bar: ProgressBar = interactive_content.get_node("BotHealthBar")
	var bot_health_label: Label = interactive_content.get_node("BotHealthLabel")
	var attempts_label: Label = interactive_content.get_node("AttemptsLabel")
	var log_label: RichTextLabel = interactive_content.get_node("LogLabel")
	
	# Bot tries to guess password
	var guess := _generate_password_guess(wave, attempts_shown)
	var match_percentage := _calculate_match_percentage(player_password, guess)
	
	# Limit log to last 15 messages to prevent UI stretching
	var log_text := log_label.text
	var lines := log_text.split("\n")
	if lines.size() > 20:
		log_label.clear()
		# Keep header
		log_label.append_text("[color=#00ffff]> MONITORING ATTEMPTS...\n\n[/color]")
		for i in range(max(0, lines.size() - 15), lines.size()):
			log_label.append_text(lines[i] + "\n")
	
	# Show the attempt
	var timestamp := "[%02d:%02d:%02d]" % [randi() % 24, randi() % 60, randi() % 60]
	log_label.append_text("[color=#666666]%s[/color] " % timestamp)
	log_label.append_text("[color=#ff6666]ATTEMPT #%d:[/color] " % attempts_shown)
	
	# Show guess with matched characters highlighted
	var display_guess := _format_guess_display(player_password, guess)
	log_label.append_text("%s " % display_guess)
	
	# Calculate damage based on match percentage
	var damage_to_player := 0.0
	if match_percentage == 100.0:
		# EXACT MATCH - Password cracked!
		damage_to_player = 100.0  # Instant defeat
		log_label.append_text("[color=#ff0000]CRACKED! PASSWORD MATCHED![/color]\n")
	elif match_percentage >= 80.0:
		# Very close - high damage
		damage_to_player = 15.0
		log_label.append_text("[color=#ff3333]CRITICAL HIT! %d%% MATCH | DAMAGE -%.1f%%[/color]\n" % [int(match_percentage), damage_to_player])
	elif match_percentage >= 50.0:
		# Getting warmer - medium damage
		damage_to_player = 8.0
		log_label.append_text("[color=#ff6666]CLOSE! %d%% MATCH | DAMAGE -%.1f%%[/color]\n" % [int(match_percentage), damage_to_player])
	elif match_percentage >= 30.0:
		# Some matches - low damage
		damage_to_player = 3.0
		log_label.append_text("[color=#ff9966]PARTIAL MATCH %d%% | DAMAGE -%.1f%%[/color]\n" % [int(match_percentage), damage_to_player])
	else:
		# Way off - no damage
		damage_to_player = 0.0
		log_label.append_text("[color=#33ff33]FAILED %d%% | DEFENSE HOLDING[/color]\n" % int(match_percentage))
	
	player_health -= damage_to_player
	player_health = max(0, player_health)
	
	# Bot loses strength over time (gets tired)
	var bot_fatigue := 2.0 if match_percentage < 30.0 else 0.5
	bot_health -= bot_fatigue
	bot_health = max(0, bot_health)
	if bot_fatigue > 1.0:
		log_label.append_text("[color=#00ffff]> Bot losing effectiveness...[/color]\n")
	
	# Update UI
	player_health_bar.value = player_health
	player_health_label.text = "🛡️ YOUR DEFENSE: %d%%" % int(player_health)
	
	if player_health < 30:
		player_health_label.add_theme_color_override("font_color", Color(0.0, 0.5, 0.6, 1.0))  # Dim cyan
	elif player_health < 60:
		player_health_label.add_theme_color_override("font_color", Color(0.0, 0.7, 0.8, 1.0))  # Medium cyan
	
	bot_health_bar.value = bot_health
	bot_health_label.text = "🤖 BOT ATTACK POWER: %d%%" % int(bot_health)
	
	attempts_label.text = "Attack attempts: %d" % attempts_shown
	
	# Check win/loss conditions
	if player_health <= 0 or match_percentage == 100.0:
		_end_battle(false, wave)
	elif bot_health <= 0 or attempts_shown >= 50:  # Max 50 attacks or bot defeated
		_end_battle(true, wave)


func _end_battle(victory: bool, wave: Dictionary) -> void:
	battle_active = false
	
	var log_label: RichTextLabel = interactive_content.get_node("LogLabel")
	
	if victory:
		current_state = GameState.VICTORY
		var points := int(password_strength * 10) + (100 - attempts_shown)
		player_score += points
		
		# Clear old battle messages
		log_label.clear()
		log_label.append_text("\n")
		log_label.append_text("[color=#00ff00]========================================[/color]\n")
		log_label.append_text("[color=#00ff00]>  ATTACK TERMINATED                    [/color]\n")
		log_label.append_text("[color=#00ff00]>  STATUS: DEFENSE SUCCESSFUL           [/color]\n")
		log_label.append_text("[color=#00ff00]========================================[/color]\n\n")
		log_label.append_text("[color=#ffff00]> ANALYSIS:[/color]\n")
		log_label.append_text("[color=#00ffff]  - Total attempts: %d[/color]\n" % attempts_shown)
		log_label.append_text("[color=#00ffff]  - Password strength: %d%%[/color]\n" % int(password_strength))
		log_label.append_text("[color=#00ffff]  - Bot defeated: %s[/color]\n\n" % wave.enemy_name)
		log_label.append_text("[color=#ffff00]> REWARD: +%d points[/color]\n\n" % points)
		log_label.append_text("[color=#00ff00]> Advancing to next wave...[/color]\n")
		
		# Unlock new features based on wave
		match current_wave:
			1: unlocked_features.uppercase = true
			2: unlocked_features.numbers = true
			3: unlocked_features.special = true
		
		# Auto-advance to next wave after short delay
		await get_tree().create_timer(2.5).timeout
		if current_state == GameState.VICTORY:  # Still in victory state
			_advance_to_next_wave()
	else:
		current_state = GameState.DEFEAT
		# Clear old battle messages
		log_label.clear()
		log_label.append_text("\n")
		log_label.append_text("[color=#ff3333]========================================[/color]\n")
		log_label.append_text("[color=#ff3333]>  CRITICAL FAILURE                     [/color]\n")
		log_label.append_text("[color=#ff3333]>  STATUS: PASSWORD COMPROMISED         [/color]\n")
		log_label.append_text("[color=#ff3333]========================================[/color]\n\n")
		log_label.append_text("[color=#ffff00]> ANALYSIS:[/color]\n")
		log_label.append_text("[color=#ff6666]  - Cracked by: %s[/color]\n" % wave.enemy_name)
		log_label.append_text("[color=#ff6666]  - Password was too weak[/color]\n\n")
		log_label.append_text("[color=#00ffff]> TIP: Build a stronger password[/color]\n")
		log_label.append_text("[color=#00ffff]> Retry with better security...[/color]\n")
		
		next_button.visible = true
		next_button.text = "TRY AGAIN"


# Handle clickable terms
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var meta: Variant = content_text.get_meta_under_mouse()
			if meta and str(meta) in terms:
				_show_term_definition(str(meta))


func _show_term_definition(term: String) -> void:
	term_title.text = term
	term_definition.text = terms.get(term, "Definition not found.")
	dark_overlay.visible = true
	term_popup.visible = true


func _close_term_popup() -> void:
	dark_overlay.visible = false
	term_popup.visible = false
