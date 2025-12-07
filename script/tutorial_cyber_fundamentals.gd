extends Control

# ============================================
# CYBERSECURITY FUNDAMENTALS
# CIA Triad, Threat vs Vulnerability vs Risk
# Foundation concepts before diving into technical content
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
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var diagram_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel
@onready var diagram_text: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel/DiagramLabel
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup
@onready var simulation_overlay: ColorRect = $SimulationOverlay
@onready var simulation_popup: PanelContainer = $SimulationOverlay/SimulationPopup
@onready var sim_title: Label = $SimulationOverlay/SimulationPopup/VBox/TitleBar/HBox/Title
@onready var sim_close_btn: Button = $SimulationOverlay/SimulationPopup/VBox/TitleBar/HBox/CloseButton
@onready var tab_container: TabContainer = $SimulationOverlay/SimulationPopup/VBox/Content/TabContainer


# Interactive diagram components
var diagram_container: Control = null
var animation_tween: Tween = null

# CMD typing animation variables
var typing_speed := 0.015  # Seconds per character (faster for CMD feel)
var current_text := ""
var target_text := ""
var typing_tween: Tween = null
var cursor_blink_tween: Tween = null
var cursor_label: Label = null
var cmd_prefix_label: Label = null

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
	diagram_panel.visible = false
	quiz_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Setup CMD-style interface
	_setup_cmd_interface()
	
	_start_section(Section.INTRO)


func _setup_cmd_interface() -> void:
	var content_panel = $WindowDialog/VBox/ContentPanel
	
	# CMD-style background (softer black)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.15, 0.35, 0.15, 1)
	content_panel.add_theme_stylebox_override("panel", style)
	
	var scroll_container = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll
	
	# Scrollbar styling
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
	
	# Set text alignment BEFORE any restructuring
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1))
	content_label.add_theme_font_size_override("font_size", 17)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.custom_minimum_size = Vector2(690, 0)  # Fix: Set minimum width for autowrapping
	
	var mono_font = load("res://asset/fonts/CONSOLA.TTF")
	if not mono_font:
		mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		content_label.add_theme_font_override("font", mono_font)
	
	# NOW create the VBox for the command interface extras
	var scroll_content = scroll_container.get_child(0)
	if scroll_content and scroll_content != content_label:
		# VBox already exists, use it
		pass
	else:
		# Create new VBox and reorganize
		var content_vbox = VBoxContainer.new()
		content_vbox.add_theme_constant_override("separation", 5)
		
		# Add CMD prefix label
		cmd_prefix_label = Label.new()
		cmd_prefix_label.text = "C:\\CYBERSECURITY\\TUTORIAL>"
		cmd_prefix_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
		cmd_prefix_label.add_theme_font_size_override("font_size", 13)
		if mono_font:
			cmd_prefix_label.add_theme_font_override("font", mono_font)
		content_vbox.add_child(cmd_prefix_label)
		
		# Move content label to VBox
		var parent = content_label.get_parent()
		parent.remove_child(content_label)
		content_vbox.add_child(content_label)
		
		# Add cursor
		
		
		# Add command input
		var cmd_input = LineEdit.new()
		cmd_input.name = "CommandInput"
		cmd_input.placeholder_text = "Type 'next' to continue..."
		cmd_input.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
		cmd_input.add_theme_color_override("font_placeholder_color", Color(0.3, 0.6, 0.3, 0.6))
		cmd_input.add_theme_font_size_override("font_size", 14)
		if mono_font:
			cmd_input.add_theme_font_override("font", mono_font)
		
		var input_style = StyleBoxFlat.new()
		input_style.bg_color = Color(0.08, 0.12, 0.08, 1)
		input_style.border_color = Color(0.4, 0.85, 0.4, 0.5)
		input_style.border_width_left = 2
		input_style.border_width_top = 2
		input_style.border_width_right = 2
		input_style.border_width_bottom = 2
		cmd_input.add_theme_stylebox_override("normal", input_style)
		cmd_input.add_theme_stylebox_override("focus", input_style)
		
		content_vbox.add_child(cmd_input)
		cmd_input.text_submitted.connect(_on_command_entered)
		
		scroll_container.add_child(content_vbox)
	
	_start_cursor_blink()
	_style_cmd_buttons()

func _toggle_cmd_interface(visible: bool) -> void:
	if cmd_prefix_label:
		cmd_prefix_label.visible = visible
	if cursor_label:
		cursor_label.visible = visible
	
	# Try multiple possible paths for the CommandInput
	var cmd_input = get_node_or_null("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/VBoxContainer/CommandInput")
	
	if not cmd_input:
		# Try searching through all children recursively
		var scroll = get_node_or_null("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll")
		if scroll:
			for child in scroll.get_children():
				if child is VBoxContainer:
					cmd_input = child.find_child("CommandInput", false, false)
					if cmd_input:
						break
	
	if cmd_input:
		print("DEBUG: Found CommandInput! Setting visible to: ", visible)
		cmd_input.visible = visible
	else:
		print("DEBUG: CommandInput STILL not found - searching entire tree...")
		# Last resort - search the entire tree
		cmd_input = find_child("CommandInput", true, false)
		if cmd_input:
			print("DEBUG: Found CommandInput via find_child! Setting visible to: ", visible)
			cmd_input.visible = visible
		else:
			print("DEBUG: CommandInput does not exist anywhere in the scene tree!")

# Cursor blinking effect
func _start_cursor_blink() -> void:
	if cursor_blink_tween:
		cursor_blink_tween.kill()
	
	cursor_blink_tween = create_tween()
	cursor_blink_tween.set_loops()
	cursor_blink_tween.tween_property(cursor_label, "modulate:a", 0.0, 0.5)
	cursor_blink_tween.tween_property(cursor_label, "modulate:a", 1.0, 0.5)


# Handle typed commands
func _on_command_entered(command: String) -> void:
	var cmd = command.strip_edges().to_lower()
	var cmd_input = get_node_or_null("WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/VBoxContainer/CommandInput")
	
	if cmd_input:
		cmd_input.text = ""
	
	# Only allow commands on intro section
	if current_section != Section.INTRO:
		return
	
	if cmd == "next":
		_on_next_pressed()
	elif cmd == "back":
		_on_back_pressed()
	elif cmd == "help":
		# Show available commands
		var help_text = "\n> Available commands: next, back, help"
		content_label.text += help_text
	else:
		# Invalid command
		var error_text = "\n> Unknown command: '" + command + "'. Type 'help' for available commands."
		content_label.text += error_text


# Style buttons to match CMD theme
func _style_cmd_buttons() -> void:
	# Style NEXT button - softer green
	var next_style = StyleBoxFlat.new()
	next_style.bg_color = Color(0.08, 0.18, 0.08, 1)  # Darker muted green
	next_style.border_color = Color(0.4, 0.85, 0.4, 1)  # Softer green border
	next_style.border_width_left = 2
	next_style.border_width_top = 2
	next_style.border_width_right = 2
	next_style.border_width_bottom = 2
	next_button.add_theme_stylebox_override("normal", next_style)
	next_button.add_theme_stylebox_override("hover", next_style)
	next_button.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
	next_button.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.6, 1))
	
	# Style BACK button - softer red
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.18, 0.08, 0.08, 1)  # Darker muted red
	back_style.border_color = Color(0.85, 0.4, 0.4, 1)  # Softer red border
	back_style.border_width_left = 2
	back_style.border_width_top = 2
	back_style.border_width_right = 2
	back_style.border_width_bottom = 2
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.add_theme_stylebox_override("hover", back_style)
	back_button.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5, 1))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.6, 1))


# Modified typing animation function with CMD effect
# Modified typing animation function with CMD effect
func _type_text(text: String) -> void:
	if typing_tween:
		typing_tween.kill()
	
	target_text = text
	current_text = ""
	content_label.text = ""
	
	# Show cursor while typing
	if cursor_label:
		cursor_label.visible = true
	
	typing_tween = create_tween()
	
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			if i < target_text.length():
				current_text += target_text[i]
				content_label.text = current_text + "█"  # ← Add cursor to text
		)
		# Add slight variation to typing speed for realism
		var delay = typing_speed
		if i < text.length() and text[i] == '\n':
			delay = 0.1  # Pause at newlines
		typing_tween.tween_interval(delay)
	
	# Hide cursor after typing completes
	typing_tween.tween_callback(func():
		content_label.text = current_text  # ← Remove cursor from final text
		if cursor_label:
			cursor_label.visible = false
	)

# Modify _start_section to use typing animation
func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
	diagram_panel.visible = false
	content_label.visible = true
	
	_toggle_cmd_interface(section == Section.INTRO)
	next_button.disabled = false
	back_button.disabled = false
	next_button.text = "NEXT"
	
	# Hide buttons for INTRO section only
	if section == Section.INTRO:
		next_button.visible = false
		back_button.visible = false
	else:
		next_button.visible = true
		back_button.visible = true
	
	var section_text
	
	match section:
		Section.INTRO:
			section_label.text = "What is Cybersecurity?"
			section_text = """WELCOME TO CYBERSECURITY FUNDAMENTALS

Cybersecurity = Protecting computers, networks, and data from attacks.

Before learning about malware and hacking techniques, you need to understand the FOUNDATION:

📚 The CIA Triad - 3 core principles of security:
   • Confidentiality (keeping secrets)
   • Integrity (preventing tampering)
   • Availability (keeping services running)

🎯 Threat Model - Understanding attackers:
   • What is a Threat?
   • What is a Vulnerability?
   • What is Risk?

This is the framework ALL cybersecurity professionals use!

Type 'next' to learn the CIA Triad →"""
		
		Section.CIA_CONFIDENTIALITY:
			section_label.text = "CIA Triad - Part 1: Confidentiality"
			section_text = """CONFIDENTIALITY = KEEPING SECRETS

Confidentiality means only authorized people can access information.

Examples of Confidentiality:
   ✓ Passwords (only you should know yours)
   ✓ Medical records (only you and your doctor)
   ✓ Credit card numbers (only you and the bank)
   ✓ Company secrets (trade secrets, financial data)

How it's protected:
   • Encryption (scrambles data)
   • Access controls (passwords, permissions)
   • Authentication (proving who you are)

Confidentiality BREACH Example:
   ❌ Hacker steals customer database with emails/passwords
   ❌ Employee leaks company financial reports
   ❌ Someone reads your private messages

Watch how encryption protects your data! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_confidentiality_diagram()
		
		Section.CIA_INTEGRITY:
			section_label.text = "CIA Triad - Part 2: Integrity"
			section_text = """INTEGRITY = PREVENTING TAMPERING

Integrity means data is accurate, authentic, and hasn't been modified by unauthorized people.

Examples of Integrity:
   ✓ Bank account balance (must be exact)
   ✓ Software downloads (no hidden malware)
   ✓ Medical prescriptions (correct dosage)
   ✓ Website content (not defaced by hackers)

How it's protected:
   • Digital signatures (proves authenticity)
   • Checksums/hashes (detects changes)
   • Version control (tracks modifications)
   • Access controls (limits who can edit)

Integrity BREACH Example:
   ❌ Hacker changes your bank balance
   ❌ Malware injected into software update
   ❌ Attacker modifies website to spread misinformation

Click to see how hash detection works! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_integrity_diagram()
		
		Section.CIA_AVAILABILITY:
			section_label.text = "CIA Triad - Part 3: Availability"
			section_text = """AVAILABILITY = KEEPING SERVICES RUNNING

Availability means systems and data are accessible when needed.

Examples of Availability:
   ✓ Website is online 24/7
   ✓ Email server responds quickly
   ✓ Hospital systems work during emergencies
   ✓ ATM machines dispense cash

How it's protected:
   • Redundancy (backup servers)
   • Load balancing (distribute traffic)
   • DDoS protection (block attack traffic)
   • Disaster recovery plans

Availability BREACH Example:
   ❌ DDoS attack crashes website (too much traffic)
   ❌ Ransomware locks all files (can't access data)
   ❌ Server outage (hardware failure, power loss)

Watch redundancy in action! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_availability_diagram()
		
		Section.THREAT_MODEL:
			section_label.text = "Understanding Threats, Vulnerabilities, and Risks"
			content_label.visible = false
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_threat_model_diagram()
			
			# Show buttons
			next_button.visible = true
			back_button.visible = true
			return  # Skip typing for this section
		
		Section.QUIZ:
			section_label.text = "Knowledge Check - CIA Triad Quiz"
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
				content_label.visible = false
			quiz_panel.visible = true
			back_button.disabled = true
			_show_quiz_question()
			_toggle_cmd_interface(false)
			# Show buttons
			next_button.visible = true
			back_button.visible = true
			return  # Skip typing for quiz
		
		Section.COMPLETE:
			content_label.visible = true
			section_label.text = "Fundamentals Mastered!"
			section_text = """🎉 CONGRATULATIONS!

You now understand cybersecurity fundamentals:

✓ CIA Triad:
   • Confidentiality (keeping secrets)
   • Integrity (preventing tampering)
   • Availability (keeping services running)

✓ Threat Modeling:
   • Threats (potential dangers)
   • Vulnerabilities (weaknesses)
   • Risks (likelihood × impact)

Quiz Score: %d/%d correct

These concepts apply to EVERYTHING in cybersecurity:
   • Password security → Confidentiality
   • Malware detection → Integrity
   • DDoS defense → Availability

You're now ready for technical tutorials!""" % [score, quiz_questions.size()]
			next_button.text = "FINISH"
			next_button.disabled = false
	
	# Start typing animation
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
	
	# Clear previous options
	for child in option_container.get_children():
		child.queue_free()
	
	# Create option buttons
	for i in range(q["options"].size()):
		var button = Button.new()
		button.text = q["options"][i]
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_on_quiz_option_selected.bind(i))
		option_container.add_child(button)
	
	# Disable NEXT button until answer is selected
	next_button.disabled = true
	
	# Keep back button disabled during quiz
	back_button.disabled = true

func _on_quiz_option_selected(option_index: int) -> void:
	var q = quiz_questions[current_quiz_index]
	var correct = (option_index == q["correct"])
	
	# Disable all buttons
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
			print("[TUTORIAL] FINISH button pressed!")
			print("[TUTORIAL] Quiz Score: %d/%d" % [score, quiz_questions.size()])
			print("[TUTORIAL] Calculated Score: %d / Max: %d" % [score * 50, quiz_questions.size() * 50])
			
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				print("[TUTORIAL] TutorialManager found, saving result...")
				tutorial_mgr.save_tutorial_result("beginner_fundamentals", score * 50, quiz_questions.size() * 50)
				
				# Wait for Firestore save to complete before navigating
				print("[TUTORIAL] Waiting for Firestore save to complete...")
				await tutorial_mgr.save_completed
				print("[TUTORIAL] Save confirmed, navigating to landing...")
			else:
				push_error("[TUTORIAL] TutorialManager not found!")
			
			# Return to landing page
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	match current_section:
		Section.INTRO:
			# First section - exit to mode selection
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
			# From complete screen, go back to quiz start
			current_quiz_index = 0
			score = 0
			_start_section(Section.QUIZ)

# Interactive diagram creation functions

func _clear_diagram() -> void:
	if diagram_container:
		diagram_container.queue_free()
		diagram_container = null
	if animation_tween:
		animation_tween.kill()
		animation_tween = null

func _create_confidentiality_diagram() -> void:
	_clear_diagram()
	
	diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(680, 470)
	diagram_panel.add_child(diagram_container)
	
	# Add gradient background
	var background = ColorRect.new()
	background.custom_minimum_size = Vector2(680, 470)
	background.color = Color(0.12, 0.14, 0.18)  # Dark blue-gray background
	background.z_index = -1  # Keep background behind everything
	diagram_container.add_child(background)
	
	# Title panel with border (centered)
	var title_panel = PanelContainer.new()
	title_panel.position = Vector2(125, 10)
	title_panel.custom_minimum_size = Vector2(430, 50)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.1, 0.14)  # Darker background
	title_style.border_color = Color(0.3, 0.6, 0.9)  # Blue border
	title_style.border_width_left = 2
	title_style.border_width_right = 2
	title_style.border_width_top = 2
	title_style.border_width_bottom = 2
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 8
	title_style.corner_radius_bottom_right = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	diagram_container.add_child(title_panel)
	
	# Title label inside panel
	var title_label = Label.new()
	title_label.text = "CONFIDENTIALITY = KEEPING SECRETS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	var title_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if title_font:
		title_label.add_theme_font_override("font", title_font)
	title_panel.add_child(title_label)
	
	# Create user node (centered layout)
	var user = _create_device_node("👤 User\n(Sends Data)", Color(0.2, 0.5, 0.8), Vector2(70, 180))
	diagram_container.add_child(user)
	
	# Create encrypted data node (center) - dark green for better text contrast
	var encrypted_data = _create_device_node("🔒 Encrypted\n(Protected)", Color(0.15, 0.4, 0.25), Vector2(265, 180))
	diagram_container.add_child(encrypted_data)
	
	# Create server node (centered layout)
	var server = _create_device_node("💾 Server\n(Receives Data)", Color(0.2, 0.5, 0.8), Vector2(460, 180))
	diagram_container.add_child(server)
	
	# Create attacker node (trying to intercept)
	var attacker = _create_device_node("👿 Attacker\n(Can't Read!)", Color(0.8, 0.2, 0.3), Vector2(265, 80))
	diagram_container.add_child(attacker)
	
	# CMD-style status panel
	var status_panel = PanelContainer.new()
	status_panel.position = Vector2(10, 360)
	status_panel.custom_minimum_size = Vector2(660, 100)
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.05, 0.05, 0.08)  # Very dark background
	status_style.border_color = Color(0.2, 0.8, 0.3)  # Green border like CMD
	status_style.border_width_left = 2
	status_style.border_width_right = 2
	status_style.border_width_top = 2
	status_style.border_width_bottom = 2
	status_style.corner_radius_top_left = 4
	status_style.corner_radius_top_right = 4
	status_style.corner_radius_bottom_left = 4
	status_style.corner_radius_bottom_right = 4
	status_style.content_margin_left = 15
	status_style.content_margin_right = 15
	status_style.content_margin_top = 15
	status_style.content_margin_bottom = 15
	status_panel.add_theme_stylebox_override("panel", status_style)
	diagram_container.add_child(status_panel)
	
	var status_vbox = VBoxContainer.new()
	status_panel.add_child(status_vbox)
	
	# CMD prompt prefix
	var prompt_label = Label.new()
	prompt_label.text = "C:\\SECURITY\\MONITOR> "
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	var mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		prompt_label.add_theme_font_override("font", mono_font)
	status_vbox.add_child(prompt_label)
	
	# Status label that updates
	var status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	var status_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if status_font:
		status_label.add_theme_font_override("font", status_font)
	status_vbox.add_child(status_label)
	
	# Create data packet sprite (boy icon)
	var packet_sprite = Control.new()
	packet_sprite.position = Vector2(145, 210)
	diagram_container.add_child(packet_sprite)
	
	var packet_icon = load("res://asset/icons/boy.png")
	if packet_icon:
		var packet_texture = TextureRect.new()
		packet_texture.texture = packet_icon
		packet_texture.custom_minimum_size = Vector2(32, 32)
		packet_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		packet_sprite.add_child(packet_texture)
	else:
		var packet_rect = ColorRect.new()
		packet_rect.color = Color(0.3, 0.7, 0.9)
		packet_rect.custom_minimum_size = Vector2(24, 24)
		packet_sprite.add_child(packet_rect)
	
	# Data label that follows packet
	var data_label = Label.new()
	data_label.text = "📦 Data"
	data_label.position = Vector2(125, 190)
	data_label.add_theme_font_size_override("font_size", 13)
	data_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	diagram_container.add_child(data_label)
	
	# Animate packet flow with clear stages
	animation_tween = create_tween()
	animation_tween.set_loops()
	
	# Stage 1: User sends data
	animation_tween.tween_callback(func():
		status_label.text = "1️⃣ User sends data..."
		status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		data_label.text = "📦 Plain Data"
		data_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		user.modulate = Color(1.5, 1.5, 1.5)  # Brighten
	)
	animation_tween.tween_property(packet_sprite, "position", Vector2(340, 210), 1.5)
	animation_tween.set_parallel(true)
	animation_tween.tween_property(data_label, "position", Vector2(320, 190), 1.5)
	animation_tween.set_parallel(false)
	
	# Stage 2: Data gets encrypted
	animation_tween.tween_callback(func():
		status_label.text = "2️⃣ Data is ENCRYPTED - now protected! 🔒"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		data_label.text = "🔒 Encrypted"
		data_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		encrypted_data.modulate = Color(1.5, 1.5, 1.5)  # Flash bright
		user.modulate = Color(1.0, 1.0, 1.0)  # Reset
		
		# Attacker tries but fails
		attacker.modulate = Color(1.5, 0.5, 0.5)  # Try to attack
	)
	animation_tween.tween_interval(1.0)
	
	# Stage 3: Attacker fails
	animation_tween.tween_callback(func():
		status_label.text = "3️⃣ Attacker intercepts but CAN'T read encrypted data! ❌"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		attacker.modulate = Color(0.5, 0.15, 0.15)  # Attacker fails (dim)
	)
	animation_tween.tween_interval(1.5)
	
	# Stage 4: Data reaches server safely
	animation_tween.tween_callback(func():
		status_label.text = "4️⃣ Data reaches server SAFELY! ✅"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		data_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		encrypted_data.modulate = Color(1.0, 1.0, 1.0)  # Reset
		attacker.modulate = Color(0.8, 0.2, 0.3)  # Reset attacker
	)
	animation_tween.tween_property(packet_sprite, "position", Vector2(535, 210), 1.5)
	animation_tween.set_parallel(true)
	animation_tween.tween_property(data_label, "position", Vector2(515, 190), 1.5)
	animation_tween.set_parallel(false)
	
	# Stage 5: Server receives
	animation_tween.tween_callback(func():
		server.modulate = Color(1.5, 1.5, 1.5)  # Brighten
	)
	animation_tween.tween_interval(1.0)
	
	# Reset and loop
	animation_tween.tween_callback(func():
		server.modulate = Color(1.0, 1.0, 1.0)
		status_label.text = "♻️ Restarting demonstration..."
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		data_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		packet_sprite.position = Vector2(145, 210)
		data_label.position = Vector2(125, 190)
	)
	animation_tween.tween_interval(1.5)

func _create_integrity_diagram() -> void:
	_clear_diagram()
	
	diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(680, 470)
	diagram_panel.add_child(diagram_container)
	
	# Add dark background
	var background = ColorRect.new()
	background.custom_minimum_size = Vector2(680, 470)
	background.color = Color(0.12, 0.14, 0.18)
	background.z_index = -1
	diagram_container.add_child(background)
	
	# Title panel
	var title_panel = PanelContainer.new()
	title_panel.position = Vector2(125, 10)
	title_panel.custom_minimum_size = Vector2(430, 50)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.1, 0.14)
	title_style.border_color = Color(0.3, 0.6, 0.9)
	title_style.border_width_left = 2
	title_style.border_width_right = 2
	title_style.border_width_top = 2
	title_style.border_width_bottom = 2
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 8
	title_style.corner_radius_bottom_right = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	diagram_container.add_child(title_panel)
	
	var title_label = Label.new()
	title_label.text = "INTEGRITY = DATA IS ACCURATE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	var title_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if title_font:
		title_label.add_theme_font_override("font", title_font)
	title_panel.add_child(title_label)
	
	# Create file document panel
	var file_doc = _create_device_node("📄 Important\nDocument.pdf", Color(0.2, 0.5, 0.8), Vector2(265, 100))
	diagram_container.add_child(file_doc)
	
	# Hash display panel
	var hash_panel = PanelContainer.new()
	hash_panel.position = Vector2(200, 190)
	hash_panel.custom_minimum_size = Vector2(280, 60)
	var hash_style = StyleBoxFlat.new()
	hash_style.bg_color = Color(0.08, 0.1, 0.14)
	hash_style.border_color = Color(0.3, 1.0, 0.4)  # Green border
	hash_style.border_width_left = 2
	hash_style.border_width_right = 2
	hash_style.border_width_top = 2
	hash_style.border_width_bottom = 2
	hash_style.corner_radius_top_left = 6
	hash_style.corner_radius_top_right = 6
	hash_style.corner_radius_bottom_left = 6
	hash_style.corner_radius_bottom_right = 6
	hash_panel.add_theme_stylebox_override("panel", hash_style)
	diagram_container.add_child(hash_panel)
	
	var hash_vbox = VBoxContainer.new()
	hash_panel.add_child(hash_vbox)
	
	var hash_label = Label.new()
	hash_label.text = "🔑 Hash (Fingerprint)"
	hash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hash_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hash_label.add_theme_font_size_override("font_size", 13)
	hash_vbox.add_child(hash_label)
	
	var hash_value = Label.new()
	hash_value.text = "a3f9b2c1"
	hash_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hash_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	hash_value.add_theme_font_size_override("font_size", 16)
	var hash_font = load("res://asset/fonts/CONSOLA.TTF")
	if hash_font:
		hash_value.add_theme_font_override("font", hash_font)
	hash_vbox.add_child(hash_value)
	
	# Hacker icon (positioned right corner above CMD box)
	var hacker = Control.new()
	hacker.position = Vector2(590, 295)
	hacker.custom_minimum_size = Vector2(60, 60)
	diagram_container.add_child(hacker)
	
	var hacker_icon = load("res://asset/icons/hacker.png")
	if hacker_icon:
		var hacker_texture = TextureRect.new()
		hacker_texture.texture = hacker_icon
		hacker_texture.custom_minimum_size = Vector2(60, 60)
		hacker_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		hacker_texture.modulate = Color(0.5, 0.5, 0.5)  # Start dim
		hacker.add_child(hacker_texture)
	else:
		var hacker_label = Label.new()
		hacker_label.text = "👿"
		hacker_label.add_theme_font_size_override("font_size", 50)
		hacker_label.modulate = Color(0.5, 0.5, 0.5)
		hacker.add_child(hacker_label)
	
	# CMD-style status panel
	var status_panel = PanelContainer.new()
	status_panel.position = Vector2(10, 360)
	status_panel.custom_minimum_size = Vector2(660, 100)
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.05, 0.05, 0.08)
	status_style.border_color = Color(0.2, 0.8, 0.3)
	status_style.border_width_left = 2
	status_style.border_width_right = 2
	status_style.border_width_top = 2
	status_style.border_width_bottom = 2
	status_style.corner_radius_top_left = 4
	status_style.corner_radius_top_right = 4
	status_style.corner_radius_bottom_left = 4
	status_style.corner_radius_bottom_right = 4
	status_style.content_margin_left = 15
	status_style.content_margin_right = 15
	status_style.content_margin_top = 15
	status_style.content_margin_bottom = 15
	status_panel.add_theme_stylebox_override("panel", status_style)
	diagram_container.add_child(status_panel)
	
	var status_vbox = VBoxContainer.new()
	status_panel.add_child(status_vbox)
	
	var prompt_label = Label.new()
	prompt_label.text = "C:\\SECURITY\\MONITOR> "
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	var mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		prompt_label.add_theme_font_override("font", mono_font)
	status_vbox.add_child(prompt_label)
	
	var status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	var status_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if status_font:
		status_label.add_theme_font_override("font", status_font)
	status_vbox.add_child(status_label)
	
	# Animate the integrity check process
	animation_tween = create_tween()
	animation_tween.set_loops()
	
	# Stage 1: Original file with hash
	animation_tween.tween_callback(func():
		status_label.text = "1️⃣ Original file has unique hash (fingerprint)"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		file_doc.modulate = Color(1.5, 1.5, 1.5)
		hash_value.text = "a3f9b2c1"
		hash_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		if hacker.get_child_count() > 0:
			hacker.get_child(0).modulate = Color(0.5, 0.5, 0.5)  # Dim (inactive)
		var hash_style_green = StyleBoxFlat.new()
		hash_style_green.bg_color = Color(0.08, 0.1, 0.14)
		hash_style_green.border_color = Color(0.3, 1.0, 0.4)
		hash_style_green.border_width_left = 2
		hash_style_green.border_width_right = 2
		hash_style_green.border_width_top = 2
		hash_style_green.border_width_bottom = 2
		hash_style_green.corner_radius_top_left = 6
		hash_style_green.corner_radius_top_right = 6
		hash_style_green.corner_radius_bottom_left = 6
		hash_style_green.corner_radius_bottom_right = 6
		hash_panel.add_theme_stylebox_override("panel", hash_style_green)
	)
	animation_tween.tween_interval(2.0)
	
	# Stage 2: Hacker modifies file
	animation_tween.tween_callback(func():
		status_label.text = "2️⃣ Hacker secretly modifies the file!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		file_doc.modulate = Color(1.5, 0.6, 0.3)  # Orange - being modified!
		if hacker.get_child_count() > 0:
			hacker.get_child(0).modulate = Color(1.5, 0.6, 0.3)  # Orange - attacking!
		if file_doc.get_child_count() > 0 and file_doc.get_child(0) is Label:
			file_doc.get_child(0).text = "📄 Modified!\nDocument.pdf"
	)
	animation_tween.tween_interval(2.0)
	
	# Stage 3: Hash changes!
	animation_tween.tween_callback(func():
		status_label.text = "3️⃣ Hash CHANGES because file was modified! ⚠️"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		file_doc.modulate = Color(1.5, 0.6, 0.3)  # Stay orange - still modified
		hash_value.text = "x9z7k5m2"
		hash_value.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var hash_style_changed = StyleBoxFlat.new()
		hash_style_changed.bg_color = Color(0.08, 0.1, 0.14)
		hash_style_changed.border_color = Color(1.0, 0.3, 0.3)  # Red border!
		hash_style_changed.border_width_left = 2
		hash_style_changed.border_width_right = 2
		hash_style_changed.border_width_top = 2
		hash_style_changed.border_width_bottom = 2
		hash_style_changed.corner_radius_top_left = 6
		hash_style_changed.corner_radius_top_right = 6
		hash_style_changed.corner_radius_bottom_left = 6
		hash_style_changed.corner_radius_bottom_right = 6
		hash_panel.add_theme_stylebox_override("panel", hash_style_changed)
		if hacker.get_child_count() > 0:
			hacker.get_child(0).modulate = Color(1.5, 0.6, 0.3)  # Stay orange
		var hash_style_red = StyleBoxFlat.new()
		hash_style_red.bg_color = Color(0.08, 0.1, 0.14)
		hash_style_red.border_color = Color(1.0, 0.3, 0.3)
		hash_style_red.border_width_left = 2
		hash_style_red.border_width_right = 2
		hash_style_red.border_width_top = 2
		hash_style_red.border_width_bottom = 2
		hash_style_red.corner_radius_top_left = 6
		hash_style_red.corner_radius_top_right = 6
		hash_style_red.corner_radius_bottom_left = 6
		hash_style_red.corner_radius_bottom_right = 6
		hash_panel.add_theme_stylebox_override("panel", hash_style_red)
	)
	animation_tween.tween_interval(2.0)
	
	# Stage 4: Detection and protection!
	animation_tween.tween_callback(func():
		status_label.text = "4️⃣ Attack detected! File restored from backup. System PROTECTED! ✅"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		file_doc.modulate = Color(0.5, 1.3, 0.5)  # Green - protected!
		if file_doc.get_child_count() > 0 and file_doc.get_child(0) is Label:
			file_doc.get_child(0).text = "💾 Backup\nRestored!"
		hash_value.text = "a3f9b2c1"  # Hash restored to original
		hash_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		var hash_style_secure = StyleBoxFlat.new()
		hash_style_secure.bg_color = Color(0.08, 0.1, 0.14)
		hash_style_secure.border_color = Color(0.3, 1.0, 0.4)  # Green border - secure!
		hash_style_secure.border_width_left = 2
		hash_style_secure.border_width_right = 2
		hash_style_secure.border_width_top = 2
		hash_style_secure.border_width_bottom = 2
		hash_style_secure.corner_radius_top_left = 6
		hash_style_secure.corner_radius_top_right = 6
		hash_style_secure.corner_radius_bottom_left = 6
		hash_style_secure.corner_radius_bottom_right = 6
		hash_panel.add_theme_stylebox_override("panel", hash_style_secure)
		if hacker.get_child_count() > 0:
			hacker.get_child(0).modulate = Color(1.5, 0.2, 0.2)  # Bright red - caught!
	)
	animation_tween.tween_interval(2.5)
	
	# Reset
	animation_tween.tween_callback(func():
		status_label.text = "♻️ Restarting demonstration..."
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		file_doc.modulate = Color(1.0, 1.0, 1.0)
		if hacker.get_child_count() > 0:
			hacker.get_child(0).modulate = Color(0.5, 0.5, 0.5)
		if file_doc.get_child_count() > 0 and file_doc.get_child(0) is Label:
			file_doc.get_child(0).text = "📄 Important\nDocument.pdf"
	)
	animation_tween.tween_interval(1.5)

func _create_availability_diagram() -> void:
	_clear_diagram()
	
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18)
	bg.custom_minimum_size = Vector2(680, 470)
	bg.z_index = -1
	diagram_panel.add_child(bg)
	
	diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(680, 470)
	diagram_panel.add_child(diagram_container)
	
	# Title panel
	var title_panel = PanelContainer.new()
	title_panel.position = Vector2(125, 10)
	title_panel.custom_minimum_size = Vector2(430, 50)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.1, 0.14)
	title_style.border_color = Color(0.3, 0.6, 0.9)
	title_style.border_width_left = 2
	title_style.border_width_right = 2
	title_style.border_width_top = 2
	title_style.border_width_bottom = 2
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 8
	title_style.corner_radius_bottom_right = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	var title_label = Label.new()
	title_label.text = "AVAILABILITY = SERVICE STAYS ONLINE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
	title_panel.add_child(title_label)
	diagram_container.add_child(title_panel)
	
	# User icon at top (shows service is accessible)
	var user_icon = Control.new()
	user_icon.custom_minimum_size = Vector2(50, 50)
	user_icon.position = Vector2(315, 80)
	var user_texture = TextureRect.new()
	user_texture.texture = load("res://asset/icons/boy.png")
	user_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	user_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	user_texture.custom_minimum_size = Vector2(40, 40)
	user_icon.add_child(user_texture)
	diagram_container.add_child(user_icon)
	
	# Service label
	var service_label = Label.new()
	service_label.text = "🌐 Website Service"
	service_label.position = Vector2(270, 140)
	service_label.add_theme_font_size_override("font_size", 16)
	service_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	diagram_container.add_child(service_label)
	
	# Three servers with icons
	var server1 = Control.new()
	server1.custom_minimum_size = Vector2(150, 100)
	server1.position = Vector2(90, 200)
	var server1_panel = PanelContainer.new()
	server1_panel.custom_minimum_size = Vector2(150, 100)
	var server1_style = StyleBoxFlat.new()
	server1_style.bg_color = Color(0.15, 0.4, 0.15)
	server1_style.corner_radius_top_left = 8
	server1_style.corner_radius_top_right = 8
	server1_style.corner_radius_bottom_left = 8
	server1_style.corner_radius_bottom_right = 8
	server1_panel.add_theme_stylebox_override("panel", server1_style)
	var server1_vbox = VBoxContainer.new()
	server1_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var server1_icon = TextureRect.new()
	server1_icon.texture = load("res://asset/icons/server.png")
	server1_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	server1_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	server1_icon.custom_minimum_size = Vector2(40, 40)
	server1_vbox.add_child(server1_icon)
	var server1_label = Label.new()
	server1_label.text = "Server 1\n✅ Online"
	server1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	server1_label.add_theme_font_size_override("font_size", 14)
	server1_vbox.add_child(server1_label)
	server1_panel.add_child(server1_vbox)
	server1.add_child(server1_panel)
	diagram_container.add_child(server1)
	
	var server2 = Control.new()
	server2.custom_minimum_size = Vector2(150, 100)
	server2.position = Vector2(265, 200)
	var server2_panel = PanelContainer.new()
	server2_panel.custom_minimum_size = Vector2(150, 100)
	var server2_style = StyleBoxFlat.new()
	server2_style.bg_color = Color(0.15, 0.4, 0.15)
	server2_style.corner_radius_top_left = 8
	server2_style.corner_radius_top_right = 8
	server2_style.corner_radius_bottom_left = 8
	server2_style.corner_radius_bottom_right = 8
	server2_panel.add_theme_stylebox_override("panel", server2_style)
	var server2_vbox = VBoxContainer.new()
	server2_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var server2_icon = TextureRect.new()
	server2_icon.texture = load("res://asset/icons/server.png")
	server2_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	server2_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	server2_icon.custom_minimum_size = Vector2(40, 40)
	server2_vbox.add_child(server2_icon)
	var server2_label = Label.new()
	server2_label.text = "Server 2\n✅ Online"
	server2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	server2_label.add_theme_font_size_override("font_size", 14)
	server2_vbox.add_child(server2_label)
	server2_panel.add_child(server2_vbox)
	server2.add_child(server2_panel)
	diagram_container.add_child(server2)
	
	var server3 = Control.new()
	server3.custom_minimum_size = Vector2(150, 100)
	server3.position = Vector2(440, 200)
	var server3_panel = PanelContainer.new()
	server3_panel.custom_minimum_size = Vector2(150, 100)
	var server3_style = StyleBoxFlat.new()
	server3_style.bg_color = Color(0.15, 0.4, 0.15)
	server3_style.corner_radius_top_left = 8
	server3_style.corner_radius_top_right = 8
	server3_style.corner_radius_bottom_left = 8
	server3_style.corner_radius_bottom_right = 8
	server3_panel.add_theme_stylebox_override("panel", server3_style)
	var server3_vbox = VBoxContainer.new()
	server3_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var server3_icon = TextureRect.new()
	server3_icon.texture = load("res://asset/icons/server.png")
	server3_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	server3_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	server3_icon.custom_minimum_size = Vector2(40, 40)
	server3_vbox.add_child(server3_icon)
	var server3_label = Label.new()
	server3_label.text = "Server 3\n✅ Online"
	server3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	server3_label.add_theme_font_size_override("font_size", 14)
	server3_vbox.add_child(server3_label)
	server3_panel.add_child(server3_vbox)
	server3.add_child(server3_panel)
	diagram_container.add_child(server3)
	
	# CMD-style status panel
	var status_panel = PanelContainer.new()
	status_panel.position = Vector2(10, 360)
	status_panel.custom_minimum_size = Vector2(660, 100)
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.08, 0.1, 0.14)
	status_style.border_color = Color(0.2, 0.8, 0.3)
	status_style.border_width_left = 2
	status_style.border_width_right = 2
	status_style.border_width_top = 2
	status_style.border_width_bottom = 2
	status_style.corner_radius_top_left = 6
	status_style.corner_radius_top_right = 6
	status_style.corner_radius_bottom_left = 6
	status_style.corner_radius_bottom_right = 6
	status_style.content_margin_left = 15
	status_style.content_margin_right = 15
	status_style.content_margin_top = 15
	status_style.content_margin_bottom = 15
	status_panel.add_theme_stylebox_override("panel", status_style)
	var status_label = Label.new()
	status_label.text = "1️⃣ All servers online. Service accessible! ✅"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	var status_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if status_font:
		status_label.add_theme_font_override("font", status_font)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(630, 0)
	status_panel.add_child(status_label)
	diagram_container.add_child(status_panel)
	
	# Warning icon (initially hidden)
	var warning_icon = Control.new()
	warning_icon.custom_minimum_size = Vector2(60, 60)
	warning_icon.position = Vector2(310, 240)
	var warning_texture = TextureRect.new()
	warning_texture.texture = load("res://asset/icons/redwarning.png")
	warning_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	warning_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	warning_texture.custom_minimum_size = Vector2(60, 60)
	warning_icon.add_child(warning_texture)
	warning_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)  # Hidden initially
	diagram_container.add_child(warning_icon)
	
	# 4-stage animation showing server failure and redundancy
	animation_tween = create_tween()
	animation_tween.set_loops()
	
	# Stage 1: All servers online (2s)
	animation_tween.tween_interval(2.0)
	
	# Stage 2: Server 2 fails!
	animation_tween.tween_callback(func():
		status_label.text = "2️⃣ Server 2 CRASHED! ⚠️ But service still works..."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		server2.modulate = Color(1.5, 0.3, 0.3)  # Red - failed!
		if server2.get_child_count() > 0 and server2.get_child(0).get_child_count() > 0:
			var vbox = server2.get_child(0).get_child(0)
			if vbox.get_child_count() > 1:
				vbox.get_child(1).text = "Server 2\n❌ CRASHED"
		warning_icon.modulate = Color(1.0, 0.6, 0.2, 1.0)  # Show warning
	)
	animation_tween.tween_interval(2.5)
	
	# Stage 3: Other servers handle the load
	animation_tween.tween_callback(func():
		status_label.text = "3️⃣ Servers 1 & 3 handle traffic. Users don't notice! 🎯"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		server1.modulate = Color(0.7, 1.3, 0.7)  # Brighter - working harder!
		server3.modulate = Color(0.7, 1.3, 0.7)
		warning_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)  # Hide warning
	)
	animation_tween.tween_interval(2.5)
	
	# Stage 4: Server 2 recovers
	animation_tween.tween_callback(func():
		status_label.text = "4️⃣ Server 2 restored! All back to normal. AVAILABILITY! ✅"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		server1.modulate = Color(1.0, 1.0, 1.0)  # Back to normal brightness
		server2.modulate = Color(0.5, 1.3, 0.5)  # Green - recovered!
		server3.modulate = Color(1.0, 1.0, 1.0)
		if server2.get_child_count() > 0 and server2.get_child(0).get_child_count() > 0:
			var vbox = server2.get_child(0).get_child(0)
			if vbox.get_child_count() > 1:
				vbox.get_child(1).text = "Server 2\n✅ Online"
	)
	animation_tween.tween_interval(2.5)
	
	# Reset to stage 1
	animation_tween.tween_callback(func():
		status_label.text = "♻️ Restarting demonstration..."
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		server1.modulate = Color(1.0, 1.0, 1.0)
		server2.modulate = Color(1.0, 1.0, 1.0)
		server3.modulate = Color(1.0, 1.0, 1.0)
		if server2.get_child_count() > 0 and server2.get_child(0).get_child_count() > 0:
			var vbox = server2.get_child(0).get_child(0)
			if vbox.get_child_count() > 1:
				vbox.get_child(1).text = "Server 2\n✅ Online"
	)
	animation_tween.tween_interval(1.5)

func _create_threat_model_diagram() -> void:
	_clear_diagram()
	
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18)
	bg.custom_minimum_size = Vector2(680, 470)
	bg.z_index = -1
	diagram_panel.add_child(bg)
	
	diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(680, 470)
	diagram_panel.add_child(diagram_container)
	
	# Title panel
	var title_panel = PanelContainer.new()
	title_panel.position = Vector2(125, 10)
	title_panel.custom_minimum_size = Vector2(430, 50)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.1, 0.14)
	title_style.border_color = Color(0.3, 0.6, 0.9)
	title_style.border_width_left = 2
	title_style.border_width_right = 2
	title_style.border_width_top = 2
	title_style.border_width_bottom = 2
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 8
	title_style.corner_radius_bottom_right = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	var title_label = Label.new()
	title_label.text = "THREAT MODEL = HOW RISKS HAPPEN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
	title_panel.add_child(title_label)
	diagram_container.add_child(title_panel)
	
	# Threat box (Hacker)
	var threat = _create_device_node("⚠️ Threat\n(Hacker)", Color(0.5, 0.3, 0.15), Vector2(70, 120))
	diagram_container.add_child(threat)
	
	# Plus sign
	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.position = Vector2(240, 145)
	plus_label.add_theme_font_size_override("font_size", 40)
	plus_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	diagram_container.add_child(plus_label)
	
	# Vulnerability box (Weak Password)
	var vulnerability = _create_device_node("🔓 Vulnerability\n(Weak Password)", Color(0.5, 0.15, 0.15), Vector2(290, 120))
	diagram_container.add_child(vulnerability)
	
	# Equals sign
	var equals_label = Label.new()
	equals_label.text = "="
	equals_label.position = Vector2(460, 145)
	equals_label.add_theme_font_size_override("font_size", 40)
	equals_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	diagram_container.add_child(equals_label)
	
	# Risk box (HIGH RISK)
	var risk = _create_device_node("☠️ HIGH RISK\n(Data Breach)", Color(0.6, 0.1, 0.1), Vector2(510, 120))
	diagram_container.add_child(risk)
	
	# Password input label
	var input_label = Label.new()
	input_label.text = "Type a strong password to fix vulnerability:"
	input_label.position = Vector2(120, 240)
	input_label.add_theme_font_size_override("font_size", 16)
	input_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	diagram_container.add_child(input_label)
	
	# Password input field
	var password_input = LineEdit.new()
	password_input.placeholder_text = "Enter strong password..."
	password_input.position = Vector2(120, 270)
	password_input.custom_minimum_size = Vector2(300, 40)
	password_input.add_theme_font_size_override("font_size", 14)
	diagram_container.add_child(password_input)
	
	# Apply button
	var fix_button = Button.new()
	fix_button.text = "🛡️ Apply Password"
	fix_button.position = Vector2(440, 270)
	fix_button.custom_minimum_size = Vector2(150, 40)
	fix_button.add_theme_font_size_override("font_size", 14)
	diagram_container.add_child(fix_button)
	
	# CMD-style status panel
	var status_panel = PanelContainer.new()
	status_panel.position = Vector2(10, 360)
	status_panel.custom_minimum_size = Vector2(660, 100)
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.08, 0.1, 0.14)
	status_style.border_color = Color(0.2, 0.8, 0.3)
	status_style.border_width_left = 2
	status_style.border_width_right = 2
	status_style.border_width_top = 2
	status_style.border_width_bottom = 2
	status_style.corner_radius_top_left = 6
	status_style.corner_radius_top_right = 6
	status_style.corner_radius_bottom_left = 6
	status_style.corner_radius_bottom_right = 6
	status_style.content_margin_left = 15
	status_style.content_margin_right = 15
	status_style.content_margin_top = 15
	status_style.content_margin_bottom = 15
	status_panel.add_theme_stylebox_override("panel", status_style)
	var status_label = Label.new()
	status_label.text = "⚠️ VULNERABLE: Hacker + Weak Password = HIGH RISK!\nType a strong password to fix the vulnerability..."
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	var status_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if status_font:
		status_label.add_theme_font_override("font", status_font)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(630, 0)
	status_panel.add_child(status_label)
	diagram_container.add_child(status_panel)
	
	# Button interaction - YOU type the password!
	fix_button.set_meta("is_fixed", false)
	fix_button.pressed.connect(func():
		var is_fixed = fix_button.get_meta("is_fixed")
		if not is_fixed:
			var password = password_input.text
			
			# Check if password is strong enough (at least 8 chars, has uppercase, lowercase, number)
			var is_strong = password.length() >= 8
			var has_upper = false
			var has_lower = false
			var has_number = false
			
			for c in password:
				if c.to_upper() == c and c.to_lower() != c:
					has_upper = true
				elif c.to_lower() == c and c.to_upper() != c:
					has_lower = true
				elif c.is_valid_int():
					has_number = true
			
			is_strong = is_strong and has_upper and has_lower and has_number
			
			if password.is_empty():
				status_label.text = "❌ ERROR: Please type a password first!"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			elif not is_strong:
				status_label.text = "⚠️ WEAK PASSWORD! Need: 8+ chars, uppercase, lowercase, number\nTry again with a stronger password..."
				status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
				vulnerability.modulate = Color(1.5, 0.3, 0.3)  # Flash red
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(vulnerability):
					vulnerability.modulate = Color(1.0, 1.0, 1.0)
			else:
				# Password is STRONG! Fix applied!
				fix_button.set_meta("is_fixed", true)
				
				# Vulnerability becomes FIXED (green)
				vulnerability.modulate = Color(0.5, 1.3, 0.5)
				if vulnerability.get_child_count() > 0 and vulnerability.get_child(0) is Label:
					vulnerability.get_child(0).text = "🔒 FIXED!\n(Strong Password)"
				
				# Risk becomes LOW (green)
				risk.modulate = Color(0.5, 1.3, 0.5)
				if risk.get_child_count() > 0 and risk.get_child(0) is Label:
					risk.get_child(0).text = "✅ LOW RISK\n(Protected!)"
				
				# Update status
				status_label.text = "✅ PROTECTED: Strong password '" + password + "' applied!\nRisk reduced to LOW! Hacker blocked! 🎉"
				status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
				
				fix_button.text = "🎉 Security Improved!"
				fix_button.disabled = true
				password_input.editable = false
				
				# Reset after 4 seconds
				await get_tree().create_timer(4.0).timeout
				if is_instance_valid(fix_button) and is_instance_valid(vulnerability) and is_instance_valid(risk):
					fix_button.set_meta("is_fixed", false)
					vulnerability.modulate = Color(1.0, 1.0, 1.0)
					if vulnerability.get_child_count() > 0 and vulnerability.get_child(0) is Label:
						vulnerability.get_child(0).text = "🔓 Vulnerability\n(Weak Password)"
					
					risk.modulate = Color(1.0, 1.0, 1.0)
					if risk.get_child_count() > 0 and risk.get_child(0) is Label:
						risk.get_child(0).text = "☠️ HIGH RISK\n(Data Breach)"
					
					status_label.text = "⚠️ VULNERABLE: Hacker + Weak Password = HIGH RISK!\nType a strong password to fix the vulnerability..."
					status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
					
					password_input.text = ""
					password_input.editable = true
					fix_button.text = "🛡️ Apply Password"
					fix_button.disabled = false
	)
	
	# Animate pulsing effect on high risk elements
	animation_tween = create_tween()
	animation_tween.set_loops()
	animation_tween.tween_property(threat, "modulate", Color(1.2, 0.7, 0.4), 0.5)
	animation_tween.set_parallel(true)
	animation_tween.tween_property(vulnerability, "modulate", Color(1.2, 0.5, 0.5), 0.5)
	animation_tween.tween_property(risk, "modulate", Color(1.1, 0.3, 0.3), 0.5)
	animation_tween.set_parallel(false)
	animation_tween.tween_property(threat, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	animation_tween.set_parallel(true)
	animation_tween.tween_property(vulnerability, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	animation_tween.tween_property(risk, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	animation_tween.set_parallel(false)

func _create_device_node(label_text: String, color: Color, pos: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(150, 80)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	
	return panel

func _on_close_button_pressed() -> void:
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
	# User confirmed - go back to mode selection
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _on_confirm_no_pressed() -> void:
	# User cancelled - hide popup with animation
	var tween := create_tween()
	tween.tween_property(confirm_popup, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	confirm_overlay.visible = false
