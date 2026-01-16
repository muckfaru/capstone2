extends Control

# ============================================
# CYBERSECURITY FUNDAMENTALS - TEXT-BASED
# Interactive scenarios instead of diagrams
# ============================================

enum Section {
	INTRO,
	CIA_CONFIDENTIALITY,
	CIA_INTEGRITY,
	CIA_AVAILABILITY,
	THREAT_MODEL,
	QUIZ,
	COMPLETE
}

var current_section = Section.INTRO
var score := 0
var quiz_answers := {}

# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/SectionLabel
@onready var content_label: RichTextLabel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var interaction_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/InteractionPanel
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup

# CMD typing animation variables
var typing_speed := 0.02
var current_text := ""
var target_text := ""
var typing_tween: Tween = null

# Quiz data
var quiz_questions := [
	{
		"question": "What does CONFIDENTIALITY mean in cybersecurity?",
		"options": [
			"Keeping data SECRET from unauthorized people",
			"Making sure data is not changed",
			"Keeping services online and accessible"
		],
		"correct": 0,
		"explanation": "Confidentiality = keeping secrets! Like encrypting passwords so hackers can't read them."
	},
	{
		"question": "A hacker changes the price on your e-commerce website from $100 to $1. What is violated?",
		"options": ["Confidentiality", "Integrity", "Availability"],
		"correct": 1,
		"explanation": "Integrity = data accuracy! The price was MODIFIED (tampered with), so integrity is broken."
	},
	{
		"question": "Your school's website is down because of too much traffic. Which principle is violated?",
		"options": ["Confidentiality", "Integrity", "Availability"],
		"correct": 2,
		"explanation": "Availability = service is accessible! When a website is DOWN or UNREACHABLE, availability is violated."
	},
	{
		"question": "What is a VULNERABILITY in cybersecurity?",
		"options": [
			"A hacker or attacker",
			"A weakness that can be exploited",
			"A type of malware"
		],
		"correct": 1,
		"explanation": "Vulnerability = a WEAKNESS! Like using 'password123' or not updating your software - these are exploitable weaknesses."
	},
	{
		"question": "You have multiple backup servers. One crashes but your website still works. What protects AVAILABILITY?",
		"options": [
			"Encryption",
			"Redundancy (backup systems)",
			"Firewalls"
		],
		"correct": 1,
		"explanation": "Redundancy = having backups! Multiple servers mean if one fails, others keep the service running. That's availability!"
	}
]

var current_quiz_index := 0


func _ready() -> void:
	print("🛡️ Cybersecurity Fundamentals Ready")
	
	quiz_panel.visible = false
	interaction_panel.visible = false
	quiz_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	_setup_cmd_interface()
	_start_section(Section.INTRO)


func _setup_cmd_interface() -> void:
	var content_panel = $WindowDialog/VBox/ContentPanel
	
	# CMD-style background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.15, 0.35, 0.15, 1)
	content_panel.add_theme_stylebox_override("panel", style)
	
	var scroll_container = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll
	
	# Scrollbar styling (CMD theme)
	var scrollbar_style = StyleBoxFlat.new()
	scrollbar_style.bg_color = Color(0.1, 0.15, 0.1, 0.5)
	scroll_container.add_theme_stylebox_override("scroll", scrollbar_style)
	
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.4, 0.85, 0.4, 0.6)
	grabber_style.corner_radius_top_left = 4
	grabber_style.corner_radius_top_right = 4
	grabber_style.corner_radius_bottom_left = 4
	grabber_style.corner_radius_bottom_right = 4
	scroll_container.add_theme_stylebox_override("grabber", grabber_style)
	
	var grabber_hover_style = StyleBoxFlat.new()
	grabber_hover_style.bg_color = Color(0.5, 0.9, 0.5, 0.8)
	grabber_hover_style.corner_radius_top_left = 4
	grabber_hover_style.corner_radius_top_right = 4
	grabber_hover_style.corner_radius_bottom_left = 4
	grabber_hover_style.corner_radius_bottom_right = 4
	scroll_container.add_theme_stylebox_override("grabber_highlight", grabber_hover_style)
	
	# Style RichTextLabel for CMD look
	content_label.add_theme_color_override("default_color", Color(0.4, 0.85, 0.4, 1))
	content_label.add_theme_font_size_override("normal_font_size", 16)
	
	var mono_font = load("res://asset/fonts/CONSOLA.TTF")
	if not mono_font:
		mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		content_label.add_theme_font_override("normal_font", mono_font)
		content_label.add_theme_font_override("bold_font", mono_font)
		content_label.add_theme_font_override("italics_font", mono_font)
		content_label.add_theme_font_override("bold_italics_font", mono_font)
		content_label.add_theme_font_override("mono_font", mono_font)
	
	_style_cmd_buttons()


func _style_cmd_buttons() -> void:
	# Style NEXT button
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
	
	# Style BACK button
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


func _type_text(text: String) -> void:
	if typing_tween:
		typing_tween.kill()
	
	content_label.clear()
	current_text = ""
	target_text = text
	
	typing_tween = create_tween()
	
	# Type character by character
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			if i < target_text.length():
				current_text += target_text[i]
				content_label.clear()
				content_label.append_text(current_text + "█")  # Add cursor while typing
		)
		
		# Vary typing speed for realism
		var delay = typing_speed
		if i < text.length():
			if text[i] == '\n':
				delay = 0.1  # Pause at newlines
			elif text[i] == ' ':
				delay = 0.01  # Faster for spaces
		
		typing_tween.tween_interval(delay)
	
	# Remove cursor when done
	typing_tween.tween_callback(func():
		content_label.clear()
		content_label.append_text(current_text)
	)


func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
	interaction_panel.visible = false
	content_label.visible = true
	
	next_button.disabled = false
	back_button.disabled = false
	next_button.text = "NEXT"
	
	var section_text: String
	
	match section:
		Section.INTRO:
			section_label.text = "What is Cybersecurity?"
			section_text = """[color=#5fd35f]C:\\CYBERSECURITY\\TUTORIAL>[/color] [color=#ffff99]start_intro.exe[/color]

[b]WELCOME TO CYBERSECURITY FUNDAMENTALS[/b]

Cybersecurity = Protecting computers, networks, and data from attacks.

Before learning about malware and hacking techniques, you need to understand the FOUNDATION:

[color=#5fd35f]📋 The CIA Triad[/color] - 3 core principles of security:
   • Confidentiality 
   • Integrity
   • Availability

[color=#5fd35f]🎯 Threat Model[/color] - Understanding attackers:
   • What is a Threat?
   • What is a Vulnerability?
   • What is Risk?

This is the framework ALL cybersecurity professionals use!

[color=#ffff99]Press NEXT to learn the CIA Triad →[/color]"""
		
		Section.CIA_CONFIDENTIALITY:
			section_label.text = "CIA Triad - Part 1: Confidentiality"
			section_text = """[color=#5fd35f]C:\\SECURITY\\CIA>[/color] [color=#ffff99]learn_confidentiality.exe[/color]

[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]
[b]CONFIDENTIALITY = KEEPING SECRETS[/b]
[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]

[color=#ffffff]Confidentiality means only authorized people can access information.[/color]

[color=#ffaa55]Real-World Examples:[/color]
   ✓ Your password (only you should know it)
   ✓ Medical records (only you and your doctor)
   ✓ Credit card numbers (only you and the bank)
   ✓ Company secrets (trade secrets, financial data)

[color=#ffaa55]How it's protected:[/color]
   🔐 Encryption (scrambles data so hackers can't read it)
   🔑 Access controls (passwords, permissions, badges)
   👤 Authentication (proving who you are - fingerprint, face ID)

[color=#ff5555]Confidentiality BREACH Example:[/color]
   ❌ Hacker steals customer database with emails/passwords
   ❌ Employee accidentally emails sensitive files to wrong person
   ❌ Someone reads your private messages without permission

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]SCENARIO: Email Encryption[/b]

Imagine sending a secret message:
[color=#888888]Without Encryption:[/color] "My password is hunter2" → [color=#ff5555]Anyone can read it![/color]
[color=#55ff55]With Encryption:[/color] "X9#mK2$pL@4nR" → [color=#55ff55]Only recipient can decode it![/color]

This is how HTTPS protects your web browsing!
[color=#5fd35f]──────────────────────────────────────────[/color]"""
		
		Section.CIA_INTEGRITY:
			section_label.text = "CIA Triad - Part 2: Integrity"
			section_text = """[color=#5fd35f]C:\\SECURITY\\CIA>[/color] [color=#ffff99]learn_integrity.exe[/color]

[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]
[b]INTEGRITY = PREVENTING TAMPERING[/b]
[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]

[color=#ffffff]Integrity means data is accurate, authentic, and hasn't been modified by unauthorized people.[/color]

[color=#ffaa55]Real-World Examples:[/color]
   ✓ Bank account balance (must be exact, no unauthorized changes)
   ✓ Software downloads (no hidden malware injected)
   ✓ Medical prescriptions (correct dosage, not tampered)
   ✓ Website content (not defaced by hackers)

[color=#ffaa55]How it's protected:[/color]
   📝 Digital signatures (proves who created/modified data)
   🔍 Checksums/hashes (detects if file was changed)
   📚 Version control (tracks all modifications)
   🔒 Access controls (limits who can edit)

[color=#ff5555]Integrity BREACH Example:[/color]
   ❌ Hacker changes price from $100 to $1 on shopping site
   ❌ Malware modifies your downloaded software
   ❌ Attacker edits news article to spread fake information

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]SCENARIO: File Hash Verification[/b]

You download a file: [color=#55ff55]important_document.pdf[/color]

Original hash: [color=#ffff99]a3f9b2c1e5d8[/color]
Your download hash: [color=#ffff99]a3f9b2c1e5d8[/color] ✅ [color=#55ff55]MATCH! File is authentic[/color]

If a hacker modified it:
Modified hash: [color=#ff5555]x7k9m2n4p6q8[/color] ❌ [color=#ff5555]MISMATCH! File tampered![/color]

This is how antivirus software detects malware!
[color=#5fd35f]──────────────────────────────────────────[/color]"""
		
		Section.CIA_AVAILABILITY:
			section_label.text = "CIA Triad - Part 3: Availability"
			section_text = """[color=#5fd35f]C:\\SECURITY\\CIA>[/color] [color=#ffff99]learn_availability.exe[/color]

[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]
[b]AVAILABILITY = KEEPING SERVICES RUNNING[/b]
[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]

[color=#ffffff]Availability means systems and data are accessible when needed.[/color]

[color=#ffaa55]Real-World Examples:[/color]
   ✓ Website is online 24/7 (not crashed)
   ✓ Email server responds quickly (not slow)
   ✓ Hospital systems work during emergencies
   ✓ ATM machines dispense cash when you need it

[color=#ffaa55]How it's protected:[/color]
   🔄 Redundancy (backup servers - if one fails, others work)
   ⚖️ Load balancing (distribute traffic across servers)
   🛡️ DDoS protection (block massive attack traffic)
   💾 Disaster recovery plans (backups and restore procedures)

[color=#ff5555]Availability BREACH Example:[/color]
   ❌ DDoS attack floods website with fake traffic → site crashes
   ❌ Ransomware encrypts all files → can't access data
   ❌ Server hardware failure → service goes offline

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]SCENARIO: Server Redundancy[/b]

Your website runs on 3 servers:

[color=#55ff55]Server 1:[/color] ✅ Online - Handling 100 requests/sec
[color=#55ff55]Server 2:[/color] ✅ Online - Handling 100 requests/sec
[color=#55ff55]Server 3:[/color] ✅ Online - Handling 100 requests/sec

[color=#ffaa55]⚠️ Server 2 crashes![/color]

[color=#55ff55]Server 1:[/color] ✅ Online - Now handling 150 requests/sec
[color=#ff5555]Server 2:[/color] ❌ OFFLINE - Restarting...
[color=#55ff55]Server 3:[/color] ✅ Online - Now handling 150 requests/sec

[color=#55ff55]✓ Website still works! Users don't even notice![/color]
[color=#5fd35f]──────────────────────────────────────────[/color]"""
		
		Section.THREAT_MODEL:
			section_label.text = "Understanding Threats, Vulnerabilities, and Risks"
			section_text = """[color=#5fd35f]C:\\SECURITY\\THREAT>[/color] [color=#ffff99]threat_model.exe[/color]

[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]
[b]THREAT MODEL = HOW RISKS HAPPEN[/b]
[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]

[color=#ffaa55]⚠️ THREAT[/color] = A potential danger (like a hacker)
[color=#ff5555]🔓 VULNERABILITY[/color] = A weakness that can be exploited (like weak password)
[color=#ff3333]☠️ RISK[/color] = Likelihood of threat exploiting vulnerability

[b]FORMULA:[/b] [color=#ffaa55]THREAT[/color] + [color=#ff5555]VULNERABILITY[/color] = [color=#ff3333]RISK[/color]

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]EXAMPLE 1: Weak Password[/b]

[color=#ffaa55]THREAT:[/color] Hacker with password cracking tools
[color=#ff5555]VULNERABILITY:[/color] Your password is "password123"
[color=#ff3333]RISK:[/color] HIGH - Hacker will easily crack your account!

[color=#55ff55]✓ FIX:[/color] Use strong password like "T7$mK9#pL2@xR4!"
[color=#55ff55]RESULT:[/color] RISK = LOW - Password very hard to crack

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]EXAMPLE 2: Outdated Software[/b]

[color=#ffaa55]THREAT:[/color] Malware exploiting known software bugs
[color=#ff5555]VULNERABILITY:[/color] You haven't updated software in 2 years
[color=#ff3333]RISK:[/color] HIGH - Malware can exploit old bugs!

[color=#55ff55]✓ FIX:[/color] Install latest software updates
[color=#55ff55]RESULT:[/color] RISK = LOW - Bugs are patched

[color=#5fd35f]──────────────────────────────────────────[/color]
[b]EXAMPLE 3: No Backups[/b]

[color=#ffaa55]THREAT:[/color] Ransomware that encrypts your files
[color=#ff5555]VULNERABILITY:[/color] No backup copies of important files
[color=#ff3333]RISK:[/color] HIGH - You'll lose everything if attacked!

[color=#55ff55]✓ FIX:[/color] Regular backups to external drive/cloud
[color=#55ff55]RESULT:[/color] RISK = LOW - Can restore from backup

[color=#5fd35f]──────────────────────────────────────────[/color]"""
		
		Section.QUIZ:
			section_label.text = "Knowledge Check - CIA Triad Quiz"
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
			content_label.visible = false
			quiz_panel.visible = true
			back_button.disabled = true
			_show_quiz_question()
			return
		
		Section.COMPLETE:
			content_label.visible = true
			section_label.text = "Fundamentals Mastered!"
			section_text = """[color=#5fd35f]C:\\CYBERSECURITY>[/color] [color=#ffff99]tutorial_complete.exe[/color]

[b][color=#55ff55]═══════════════════════════════════════════[/color][/b]
[b]🎉 CONGRATULATIONS![/b]
[b][color=#55ff55]═══════════════════════════════════════════[/color][/b]

You now understand cybersecurity fundamentals:

[color=#55ff55]✓ CIA Triad:[/color]
   • [b]Confidentiality[/b] (keeping secrets)
   • [b]Integrity[/b] (preventing tampering)
   • [b]Availability[/b] (keeping services running)

[color=#55ff55]✓ Threat Modeling:[/color]
   • [b]Threats[/b] (potential dangers)
   • [b]Vulnerabilities[/b] (weaknesses)
   • [b]Risks[/b] (likelihood × impact)

[color=#ffff99]Quiz Score: %d/%d correct[/color]

[color=#5fd35f]──────────────────────────────────────────[/color]
These concepts apply to EVERYTHING in cybersecurity:
   🔐 Password security → [b]Confidentiality[/b]
   🔍 Malware detection → [b]Integrity[/b]
   🛡️ DDoS defense → [b]Availability[/b]

[b]You're now ready for technical tutorials![/b]

[color=#55ff55]Press FINISH to return to menu →[/color]""" % [score, quiz_questions.size()]
			next_button.text = "FINISH"
			next_button.disabled = false
	
	if not section_text.is_empty():
		_type_text(section_text)


func _show_quiz_question() -> void:
	if current_quiz_index >= quiz_questions.size():
		_start_section(Section.COMPLETE)
		return
	
	quiz_panel.visible = true
	var q = quiz_questions[current_quiz_index]
	quiz_question.text = "Q%d: %s" % [current_quiz_index + 1, q["question"]]
	quiz_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	for child in option_container.get_children():
		child.queue_free()
	
	for i in range(q["options"].size()):
		var button = Button.new()
		button.text = q["options"][i]
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_on_quiz_option_selected.bind(i))
		option_container.add_child(button)
	
	next_button.disabled = true
	back_button.disabled = true


func _on_quiz_option_selected(option_index: int) -> void:
	var q = quiz_questions[current_quiz_index]
	var correct = (option_index == q["correct"])
	
	for button in option_container.get_children():
		button.disabled = true
	
	if correct:
		score += 1
		quiz_question.text += "\n\n✅ CORRECT! " + q["explanation"]
		quiz_question.add_theme_color_override("font_color", Color(0, 0.8, 0))
	else:
		quiz_question.text += "\n\n❌ WRONG! " + q["explanation"]
		quiz_question.add_theme_color_override("font_color", Color(0.8, 0, 0))
	
	quiz_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	await get_tree().create_timer(3.0).timeout
	quiz_question.add_theme_color_override("font_color", Color.WHITE)
	
	current_quiz_index += 1
	_show_quiz_question()


func _on_next_pressed() -> void:
	match current_section:
		Section.INTRO:
			_start_section(Section.CIA_CONFIDENTIALITY)
		Section.CIA_CONFIDENTIALITY:
			_start_section(Section.CIA_INTEGRITY)
		Section.CIA_INTEGRITY:
			_start_section(Section.CIA_AVAILABILITY)
		Section.CIA_AVAILABILITY:
			_start_section(Section.THREAT_MODEL)
		Section.THREAT_MODEL:
			_start_section(Section.QUIZ)
		Section.COMPLETE:
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				tutorial_mgr.save_tutorial_result("beginner_fundamentals", score * 50, quiz_questions.size() * 50)
				await tutorial_mgr.save_completed
				await get_tree().process_frame
				await get_tree().process_frame
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	match current_section:
		Section.INTRO:
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Section.CIA_CONFIDENTIALITY:
			_start_section(Section.INTRO)
		Section.CIA_INTEGRITY:
			_start_section(Section.CIA_CONFIDENTIALITY)
		Section.CIA_AVAILABILITY:
			_start_section(Section.CIA_INTEGRITY)
		Section.THREAT_MODEL:
			_start_section(Section.CIA_AVAILABILITY)
		Section.QUIZ:
			_start_section(Section.THREAT_MODEL)
		Section.COMPLETE:
			current_quiz_index = 0
			score = 0
			_start_section(Section.QUIZ)


func _on_close_button_pressed() -> void:
	confirm_overlay.visible = true
	confirm_popup.scale = Vector2.ZERO
	confirm_popup.pivot_offset = confirm_popup.size / 2
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(confirm_popup, "scale", Vector2.ONE, 0.3)


func _on_confirm_yes_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_confirm_no_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(confirm_popup, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	confirm_overlay.visible = false
