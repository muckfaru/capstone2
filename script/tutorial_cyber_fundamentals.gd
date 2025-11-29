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
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/SectionLabel
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var diagram_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel
@onready var diagram_text: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel/DiagramLabel
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton

# Quiz data
var quiz_questions := [
	{
		"question": "A hacker steals your password database. Which part of CIA Triad is violated?",
		"options": ["Confidentiality", "Integrity", "Availability"],
		"correct": 0,
		"explanation": "Confidentiality means keeping data SECRET. Stolen passwords = confidentiality breach!"
	},
	{
		"question": "An attacker modifies your website to show fake information. Which is violated?",
		"options": ["Confidentiality", "Integrity", "Availability"],
		"correct": 1,
		"explanation": "Integrity means data is ACCURATE and unmodified. Changed website = integrity breach!"
	},
	{
		"question": "A DDoS attack makes your website unreachable. Which is violated?",
		"options": ["Confidentiality", "Integrity", "Availability"],
		"correct": 2,
		"explanation": "Availability means services are ACCESSIBLE. Website down = availability breach!"
	},
	{
		"question": "What is the difference between Threat and Vulnerability?",
		"options": [
			"Threat = potential danger, Vulnerability = weakness",
			"They are the same thing",
			"Vulnerability = attacker, Threat = defense"
		],
		"correct": 0,
		"explanation": "Threat = what CAN happen (hacker attack). Vulnerability = weakness that makes it possible (outdated software)."
	}
]

var current_quiz_index := 0


func _ready() -> void:
	print("🛡️ Cybersecurity Fundamentals Ready")
	
	quiz_panel.visible = false
	diagram_panel.visible = false
	
	_start_section(Section.INTRO)


func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
	diagram_panel.visible = false
	
	match section:
		Section.INTRO:
			section_label.text = "What is Cybersecurity?"
			content_label.text = """WELCOME TO CYBERSECURITY FUNDAMENTALS

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

Click NEXT to learn the CIA Triad →"""
		
		Section.CIA_CONFIDENTIALITY:
			section_label.text = "CIA Triad - Part 1: Confidentiality"
			content_label.text = """CONFIDENTIALITY = KEEPING SECRETS

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
❌ Someone reads your private messages"""
			diagram_panel.visible = true
			diagram_text.text = """
🔐 CONFIDENTIALITY

YOU ←→ [ENCRYPTED DATA] ←→ SERVER
		Only you can decrypt!

Attacker tries to steal → BLOCKED by encryption
"""
		
		Section.CIA_INTEGRITY:
			section_label.text = "CIA Triad - Part 2: Integrity"
			content_label.text = """INTEGRITY = PREVENTING TAMPERING

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
❌ Attacker modifies website to spread misinformation"""
			diagram_panel.visible = true
			diagram_text.text = """
✅ INTEGRITY

ORIGINAL FILE → [Hash: ABC123]
Modified file → [Hash: XYZ789]  ← Mismatch detected!

Hash changes = File was tampered with!
"""
		
		Section.CIA_AVAILABILITY:
			section_label.text = "CIA Triad - Part 3: Availability"
			content_label.text = """AVAILABILITY = KEEPING SERVICES RUNNING

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
❌ Server outage (hardware failure, power loss)"""
			diagram_panel.visible = true
			diagram_text.text = """
⚡ AVAILABILITY

Users → Load Balancer → [Server 1] ✓
					  → [Server 2] ✓
					  → [Server 3] ✓

If one server fails, others keep running!
"""
		
		Section.THREAT_MODEL:
			section_label.text = "Understanding Threats, Vulnerabilities, and Risks"
			content_label.text = """THREAT MODEL - THE SECURITY FRAMEWORK

🎯 THREAT = Potential danger or attacker
   Examples: Hackers, malware, insider threats, natural disasters
   Think: "WHAT could attack us?"

🕳️ VULNERABILITY = Weakness that can be exploited
   Examples: Outdated software, weak passwords, misconfiguration
   Think: "WHERE are we weak?"

⚠️ RISK = Likelihood + Impact of a threat exploiting a vulnerability
   Formula: Risk = Threat × Vulnerability × Impact
   Think: "HOW bad could it be?"

REAL-WORLD EXAMPLE:
• Threat: Ransomware hackers
• Vulnerability: No backups, outdated Windows
• Risk: HIGH (if attacked, lose all files)

MITIGATION:
• Remove vulnerability: Update Windows, create backups
• Result: Risk = LOW (even if attacked, restore from backup)"""
			diagram_panel.visible = true
			diagram_text.text = """
THREAT MODEL DIAGRAM:

[THREAT]        [VULNERABILITY]      [RISK]
Hacker    +    Weak Password    =   HIGH RISK
					 ↓
			  FIX: Strong password
					 ↓
Hacker    +    Strong Password  =   LOW RISK
"""
		
		Section.QUIZ:
			section_label.text = "Knowledge Check - CIA Triad Quiz"
			quiz_panel.visible = false
			_show_quiz_question()
		
		Section.COMPLETE:
			section_label.text = "Fundamentals Mastered!"
			content_label.text = """🎉 CONGRATULATIONS!

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


func _show_quiz_question() -> void:
	if current_quiz_index >= quiz_questions.size():
		_start_section(Section.COMPLETE)
		return
	
	quiz_panel.visible = true
	var q = quiz_questions[current_quiz_index]
	quiz_question.text = "Q%d: %s" % [current_quiz_index + 1, q["question"]]
	
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
	
	next_button.disabled = true


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
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			tutorial_mgr.save_tutorial_result("beginner_fundamentals", score * 50, quiz_questions.size() * 50)
			
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
