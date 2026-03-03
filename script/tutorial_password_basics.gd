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
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup

# GameMode multiplayer
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

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
var attack_interval := 0.5
var player_score := 0
var battle_active := false
var attempts_shown := 0
var completed_waves := []

# CMD Interface
var typing_speed := 0.015
var current_text := ""
var target_text := ""
var typing_tween: Tween = null
var cursor_blink_tween: Tween = null
var cursor_label: Label = null
var cmd_prefix_label: Label = null

# Fake password attempts
var common_attempts := [
	"password", "123456", "admin", "qwerty", "letmein", 
	"welcome", "monkey", "dragon", "master", "sunshine",
	"password123", "12345678", "abc123", "iloveyou", "admin123",
	"Password1", "Welcome1", "Qwerty123", "P@ssword", "Admin@123"
]

# Password Strength Metrics
var password_strength := 0
var unlocked_features := {
	"lowercase": true,
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
	_setup_cmd_interface()
	_setup_signals()
	_start_wave(current_wave)
	print("✅ Password Fortress Defender Ready!")
	
	# GameMode detection
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[GameMode] Password Fortress running in game mode (room: %s)" % _gamemode_room_code)
		# Hide close button in GameMode
		var close_btn = get_node_or_null("WindowDialog/VBox/TitleBar/MarginContainer/HBox/CloseButton")
		if close_btn:
			close_btn.visible = false

func _process(delta: float) -> void:
	if current_state == GameState.BATTLE and battle_active:
		_update_battle(delta)

func _setup_cmd_interface() -> void:
	var content_panel = $WindowDialog/VBox/ContentPanel
	
	# CMD-style background (pure black like terminal)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.15, 0.35, 0.15, 1)
	content_panel.add_theme_stylebox_override("panel", style)
	
	# Setup content text with CMD styling (green text on black)
	content_text.add_theme_color_override("default_color", Color(0.4, 0.85, 0.4, 1))
	content_text.add_theme_font_size_override("normal_font_size", 17)
	
	var mono_font = load("res://asset/fonts/CONSOLA.TTF")
	if not mono_font:
		mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		content_text.add_theme_font_override("normal_font", mono_font)
	
	_style_cmd_buttons()

func _style_cmd_buttons() -> void:
	# Style NEXT button - green CMD style
	var next_style = StyleBoxFlat.new()
	next_style.bg_color = Color(0.08, 0.18, 0.08, 1)
	next_style.border_color = Color(0.4, 0.85, 0.4, 1)
	next_style.border_width_left = 2
	next_style.border_width_top = 2
	next_style.border_width_right = 2
	next_style.border_width_bottom = 2
	next_button.add_theme_stylebox_override("normal", next_style)
	next_button.add_theme_stylebox_override("hover", next_style)
	next_button.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
	next_button.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.6, 1))
	
	# Style BACK button - red CMD style
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.18, 0.08, 0.08, 1)
	back_style.border_color = Color(0.85, 0.4, 0.4, 1)
	back_style.border_width_left = 2
	back_style.border_width_top = 2
	back_style.border_width_right = 2
	back_style.border_width_bottom = 2
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.add_theme_stylebox_override("hover", back_style)
	back_button.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5, 1))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.6, 1))

func _type_text(text: String) -> void:
	if typing_tween:
		typing_tween.kill()
	
	target_text = text
	current_text = ""
	content_text.clear()
	
	typing_tween = create_tween()
	
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			if i < target_text.length():
				current_text += target_text[i]
				content_text.clear()
				content_text.append_text(current_text + "█")
		)
		var delay = typing_speed
		if i < text.length() and text[i] == '\n':
			delay = 0.05
		typing_tween.tween_interval(delay)
	
	typing_tween.tween_callback(func():
		content_text.clear()
		content_text.append_text(current_text)
	)

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
			"content": """[color=#00ff00]> SYSTEM INITIALIZING...[/color]
[color=#00ff00]> LOADING PASSWORD DEFENSE PROTOCOL...[/color]
[color=#ffff00]> STATUS: READY[/color]

[color=#00ffff]========================================[/color]
[color=#00ffff]  PASSWORD FORTRESS DEFENDER v1.0[/color]
[color=#00ffff]========================================[/color]

[color=#ffffff]Welcome, Security Cadet![/color]

[color=#ffff00]MISSION BRIEFING:[/color]
You've been recruited to defend the Digital Fortress against password-cracking bots!

[color=#ffff00]YOUR OBJECTIVES:[/color]
• Build strong passwords to defend against waves of attacks
• Learn WHY passwords fail and HOW to stop them
• Earn unlocks to build even stronger defenses
• Achieve the highest security score possible

[color=#ffff00]HOW TO PLAY:[/color]
1. [color=#00ffff]BRIEFING[/color] - Learn about the incoming attack
2. [color=#00ffff]BUILD[/color] - Create a password strong enough to defend
3. [color=#00ffff]BATTLE[/color] - Watch your defense hold (or crumble!)
4. [color=#00ffff]VICTORY[/color] - Unlock new password weapons!

[color=#ff0000]WARNING:[/color] Each attack gets smarter and more powerful!

[color=#00ff00]> Press NEXT to face your first enemy...[/color]""",
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
			"content": """[color=#ff0000]> THREAT DETECTED![/color]
[color=#ff0000]> ANALYZING ENEMY...[/color]

[color=#00ffff]========================================[/color]
[color=#ff0000]  ENEMY: DICTIONARY ATTACK BOT[/color]
[color=#00ffff]========================================[/color]

[color=#ffff00]ENEMY SPECIFICATIONS:[/color]
• Database: 10,000+ common passwords
• Attack Speed: 100 passwords/second
• Target List: "password", "123456", "welcome", "qwerty"

[color=#ffff00]ATTACK METHOD:[/color]
Imagine a robot flipping through a dictionary trying every word as your password. It also tries:
• Common names (john, sarah, mike)
• Simple words (love, happy, football)
• Easy patterns (abc123, password1)

[color=#ffff00]REAL-WORLD STATISTICS:[/color]
• 80% of people use dictionary words
• "123456" is STILL the #1 most used password
• Average crack time: INSTANT (< 1 second!)

[color=#ffff00]DEFENSE REQUIREMENTS:[/color]
• Minimum 8 characters
• Mix uppercase and lowercase letters
• Don't use real dictionary words
• Add numbers and symbols

[color=#00ff00]> Press NEXT to build your defense...[/color]""",
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
			"content": """[color=#ff0000]> NEW THREAT DETECTED![/color]
[color=#ff0000]> THREAT LEVEL: ELEVATED[/color]

[color=#00ffff]========================================[/color]
[color=#ff0000]  ENEMY: BRUTE FORCE ATTACK BOT[/color]
[color=#00ffff]========================================[/color]

[color=#ffff00]ENEMY SPECIFICATIONS:[/color]
• Method: Tries EVERY possible combination
• Attack Speed: 1,000,000 passwords/second
• Persistence: Never stops until success

[color=#ffff00]ATTACK METHOD:[/color]
Think of a bike lock with numbers 0-9. Brute force tries:
0000, 0001, 0002... 9998, 9999

With passwords it tries:
a, b, c... aa, ab, ac... aaa, aab... until it finds yours!

[color=#ffff00]CRACK TIME EXAMPLES:[/color]
• 6 chars (lowercase only): 2 seconds
• 8 chars (lowercase + uppercase): 1 hour
• 10 chars (letters + numbers): 3 weeks
• 12 chars (letters + numbers + symbols): 34,000 YEARS!

[color=#ffff00]DEFENSE REQUIREMENTS:[/color]
• Minimum 12 characters (CRITICAL!)
• Mix uppercase, lowercase, numbers, AND symbols
• More length = exponentially stronger!

[color=#00ff00]> UNLOCK EARNED: UPPERCASE letters enabled![/color]
[color=#00ff00]> Press NEXT to build an unbreakable defense...[/color]""",
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
			"content": """[color=#ff0000]> ADVANCED THREAT DETECTED![/color]
[color=#ff0000]> AI-POWERED ATTACK INCOMING[/color]

[color=#00ffff]========================================[/color]
[color=#ff0000]  ENEMY: PATTERN RECOGNITION BOT[/color]
[color=#00ffff]========================================[/color]

[color=#ffff00]ENEMY SPECIFICATIONS:[/color]
• AI-powered pattern detection
• Keyboard pattern recognition
• Target List: "qwerty", "12345", "asdfgh", "abc123"

[color=#ffff00]ATTACK METHOD:[/color]
Hackers know humans are lazy! We type patterns on the keyboard:
• Rows: qwertyuiop, asdfghjkl
• Columns: 1qaz, 2wsx, 3edc
• Sequences: 123456, abcdef
• Repeating: aaaaaa, 111111

[color=#ffff00]SURPRISING STATISTICS:[/color]
• "qwerty" is the 4th most common password
• 15% of passwords are keyboard patterns
• Adding "123" to a word doesn't help!

[color=#ffff00]DEFENSE REQUIREMENTS:[/color]
• Avoid keyboard rows/columns
• Don't use sequential numbers or letters
• Mix characters randomly throughout
• Use special characters between letters

[color=#00ff00]> UNLOCK EARNED: NUMBERS enabled![/color]
[color=#00ff00]> Press NEXT to outsmart the AI...[/color]""",
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
			"content": """[color=#ff0000]> CRITICAL THREAT DETECTED![/color]
[color=#ff0000]> SOCIAL ENGINEERING ATTACK[/color]

[color=#00ffff]========================================[/color]
[color=#ff0000]  ENEMY: PERSONAL INFO SNIPER BOT[/color]
[color=#00ffff]========================================[/color]

[color=#ffff00]ENEMY SPECIFICATIONS:[/color]
• Data Source: Social media scraping
• Intelligence: Uses birthday, pet names, hobbies
• Target Examples: "john2010", "fluffy123", "soccer2024"

[color=#ffff00]ATTACK METHOD:[/color]
Hackers research YOU before attacking:
• Facebook: Your birthday, pet names, school
• Instagram: Your hobbies, favorite bands
• LinkedIn: Your job, education
• Twitter: Your interests, favorite sports teams

Then they try passwords like:
• YourName + Birthday: "sarah1995"
• Pet + Year: "max2020"
• Hobby + Number: "soccer7"

[color=#ffff00]SCARY STATISTICS:[/color]
• 50% of people use personal info in passwords
• Average person has 100+ facts online
• Hackers can crack these in minutes

[color=#ffff00]DEFENSE REQUIREMENTS:[/color]
• NEVER use your name, birthday, or pet names
• Don't use info from your social media
• Use random, unrelated words + symbols
• Think: "Would a stranger know this about me?"

[color=#00ff00]> UNLOCK EARNED: SPECIAL CHARACTERS (!@#$%) enabled![/color]
[color=#00ff00]> Press NEXT to become invisible...[/color]""",
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
			"content": """[color=#ff0000]> MAXIMUM THREAT LEVEL![/color]
[color=#ff0000]> RAINBOW TABLE ATTACK IMMINENT[/color]

[color=#00ffff]========================================[/color]
[color=#ff0000]  ENEMY: RAINBOW TABLE ASSASSIN[/color]
[color=#00ffff]========================================[/color]

[color=#ffff00]ENEMY SPECIFICATIONS:[/color]
• Database: Pre-computed hash tables
• Coverage: Billions of passwords
• Attack Speed: INSTANT lookup

[color=#ffff00]ATTACK METHOD:[/color]
When websites store passwords, they "hash" them (encrypt):
• "password" → "5f4dcc3b5aa765d61d8327deb882cf99"
• "123456" → "e10adc3949ba59abbe56e057f20f883e"

Hackers create MASSIVE databases with billions of pre-cracked hashes.
Instead of guessing, they just LOOK UP your password's hash!

[color=#ffff00]TECHNICAL REALITY:[/color]
• Rainbow tables contain 100+ billion hashes
• Can crack simple passwords in milliseconds
• Only unique, complex passwords survive

[color=#ffff00]DEFENSE REQUIREMENTS:[/color]
• Minimum 16+ characters (rainbow tables can't pre-compute that many!)
• Maximum randomness and complexity
• Every character type (aAbB12!@)
• Truly unique - never reused anywhere

[color=#00ff00]> UNLOCK EARNED: Extended length limit (16+ chars)![/color]
[color=#00ff00]> Press NEXT to face the ultimate defense...[/color]""",
			"interactive": false,
			"min_length": 16,
			"requires": ["lowercase", "uppercase", "numbers", "special"],
			"recommended": []
		},
		
		# FINAL SCREEN: Congratulations
		{
			"wave_num": 8,
			"title": "🏆 FORTRESS DEFENDER - MISSION COMPLETE!",
			"enemy_name": "Victory",
			"state": GameState.BRIEFING,
			"content": """[color=#00ff00]> ALL THREATS NEUTRALIZED[/color]
[color=#00ff00]> FORTRESS STATUS: SECURE[/color]

[color=#00ffff]========================================[/color]
[color=#00ff00]  MISSION COMPLETE - VICTORY![/color]
[color=#00ffff]========================================[/color]

[color=#ffffff]Congratulations, Fortress Defender![/color]

[color=#ffff00]SKILLS MASTERED:[/color]
• Dictionary Attacks - Beat common word lists
• Brute Force Attacks - Made passwords exponentially harder
• Pattern Attacks - Outsmarted keyboard patterns
• Personal Info Attacks - Protected your digital identity
• Rainbow Tables - Used unique, long passwords

[color=#ffff00]YOUR TOTAL SCORE: [SCORE_PLACEHOLDER] points[/color]

[color=#ffff00]REAL-WORLD PASSWORD TIPS:[/color]
1. Use a Password Manager (1Password, Bitwarden, LastPass)
2. Never reuse passwords across sites
3. Change passwords if you suspect a breach
4. Enable 2-Factor Authentication (2FA) everywhere
5. Minimum 12 characters for regular accounts
6. Minimum 16 characters for important accounts (email, banking)

[color=#00ff00]PASSWORD STRENGTH FORMULA:[/color]
Length > Complexity > Everything Else

A 16-character password with only lowercase is stronger than an 8-character password with everything!

[color=#00ff00]> You're now a certified Password Fortress Defender![/color]
[color=#00ff00]> Share your knowledge and help others stay safe online![/color]

[color=#00ff00]> Press BACK TO MENU to return...[/color]""",
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
	
	# Type the text with CMD effect
	_type_text(content_to_show)
	
	# Clear previous interactive content
	for child in interactive_content.get_children():
		child.queue_free()
	
	interactive_panel.visible = false
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
		1:
			guess = common_attempts[randi() % common_attempts.size()]
		2:
			guess = _generate_brute_force_guess(attempt_num)
		3:
			guess = _generate_pattern_guess(attempt_num)
		4, 5, 6, 7:
			guess = _generate_smart_guess(attempt_num)
		_:
			guess = common_attempts[randi() % common_attempts.size()]
	
	return guess

func _generate_brute_force_guess(attempt: int) -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
	var length: int = min(4 + int(attempt / 10.0), 12)
	var result := ""
	for i in range(length):
		result += chars[(attempt + i) % chars.length()]
	return result

func _generate_pattern_guess(attempt: int) -> String:
	var patterns := ["qwerty", "asdfgh", "zxcvbn", "123456", "qwerty123", 
					 "asdf1234", "1qaz2wsx", "qwertyuiop", "12345678"]
	return patterns[attempt % patterns.size()] + str(randi() % 100)

func _generate_smart_guess(attempt: int) -> String:
	if attempt % 3 == 0:
		return common_attempts[randi() % common_attempts.size()]
	elif attempt % 3 == 1:
		return _generate_brute_force_guess(attempt)
	else:
		return _generate_pattern_guess(attempt)

func _calculate_match_percentage(actual_password: String, guess: String) -> float:
	if actual_password == guess:
		return 100.0
	
	var matches := 0
	var max_len: int = max(actual_password.length(), guess.length())
	var min_len: int = min(actual_password.length(), guess.length())
	
	for i in range(min_len):
		if actual_password[i] == guess[i]:
			matches += 2
		elif guess.contains(actual_password[i]):
			matches += 1
	
	if actual_password.length() == guess.length():
		matches += 2
	
	var percentage := (float(matches) / float(max_len * 2)) * 100.0
	return clamp(percentage, 0.0, 100.0)

func _format_guess_display(actual_password: String, guess: String) -> String:
	var result := "[color=#666666]'"
	
	for i in range(guess.length()):
		if i < actual_password.length() and actual_password[i] == guess[i]:
			result += "[color=#ff0000]" + guess[i] + "[/color][color=#666666]"
		elif actual_password.contains(guess[i]):
			result += "[color=#ff9900]" + guess[i] + "[/color][color=#666666]"
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
	for child in interactive_content.get_children():
		child.queue_free()
	interactive_panel.visible = false
	content_text.visible = true
	next_button.visible = true
	
	current_wave += 1
	if current_wave < waves.size():
		_start_wave(current_wave)
	else:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _on_next_pressed() -> void:
	var wave: Dictionary = waves[current_wave]
	
	if current_wave == waves.size() - 1:
		print("[TUTORIAL] Password Basic completed!")
		print("[TUTORIAL] Final Score: %d" % player_score)
		
		var max_score := 200
		print("[TUTORIAL] Calculated Score: %d / Max: %d" % [player_score, max_score])
		
		if _is_gamemode:
			_submit_gamemode_score(player_score, max_score)
			return
		
		# Check first-time before saving
		var _first_clear: bool = MinigameRewards.is_first_completion("beginner_password")
		var tutorial_mgr = get_node("/root/TutorialManager")
		if tutorial_mgr:
			print("[TUTORIAL] TutorialManager found, saving result...")
			tutorial_mgr.save_tutorial_result("beginner_password", player_score, max_score)
			print("[TUTORIAL] Waiting for Firestore save to complete...")
			await tutorial_mgr.save_completed
			print("[TUTORIAL] Save confirmed, navigating to landing...")
		else:
			push_error("[TUTORIAL] TutorialManager not found!")
		
		# Show reward popup on first completion
		if _first_clear:
			MinigameRewards.try_grant_rewards("beginner_password", player_score, player_score, self)
		
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		return
	
	if current_state == GameState.DEFEAT:
		_enter_password_build_phase()
		return
	
	if wave.get("state") == GameState.BRIEFING and current_wave > 0 and current_wave < waves.size() - 1:
		_enter_password_build_phase()
	else:
		current_wave += 1
		_start_wave(current_wave)

func _on_back_pressed() -> void:
	if current_wave == 0:
		if _is_gamemode:
			return  # Block quitting in GameMode
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	elif current_state == GameState.DEFEAT or current_state == GameState.PASSWORD_BUILD or current_state == GameState.BATTLE:
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
		var wave_num = wave.get("wave_num", 0)
		var points: int = min(40, int(password_strength * 0.4))
		
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
		
		# 🛡️ ANTI-CHEAT: Only award points once per wave
		if wave_num not in completed_waves:
			player_score += points
			completed_waves.append(wave_num)
			log_label.append_text("[color=#ffff00]> REWARD: +%d points[/color]\n\n" % points)
		else:
			log_label.append_text("[color=#ffff00]> Wave already completed (0 points)[/color]\n")
			log_label.append_text("[color=#00ffff]> Great practice! Try the next wave for points.[/color]\n\n")
		
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

func _on_close_button_pressed() -> void:
	if _is_gamemode:
		return  # Block closing in GameMode
	# Show confirmation popup
	confirm_overlay.visible = true
	
	# Animate popup entrance
	confirm_popup.scale = Vector2.ZERO
	confirm_popup.pivot_offset = confirm_popup.size / 2
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(confirm_popup, "scale", Vector2.ONE, 0.3)

func _on_confirm_yes_pressed() -> void:
	if _is_gamemode:
		return  # Block quitting in GameMode
	# User confirmed - go back to mode selection
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _on_confirm_no_pressed() -> void:
	# User cancelled - hide popup with animation
	var tween := create_tween()
	tween.tween_property(confirm_popup, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	confirm_overlay.visible = false


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

	next_button.disabled = true
	next_button.text = "Submitting..."

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Score submitted: %d/%d (time: %dms) → status %d" % [final_score, max_score, time_taken_ms, code])
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")
