extends Control

# ============================================
# NETWORK BASICS TUTORIAL
# IP addresses, ports, protocols
# Foundation for understanding advanced scenarios
# ============================================

enum Section {
	INTRO,
	IP_ADDRESSES,
	PORTS,
	PROTOCOLS,
	QUIZ,
	COMPLETE
}

var current_section = Section.INTRO
var score := 0
var current_quiz_index := 0

# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/SectionLabel
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var diagram_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel
@onready var diagram_text: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel/DiagramText
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton

# Quiz data
var quiz_questions := [
	{
		"question": "You see traffic to 45.33.32.156:4444. What does port 4444 indicate?",
		"options": [
			"Normal web browsing",
			"Suspicious backdoor port",
			"Email connection"
		],
		"correct": 1,
		"explanation": "Port 4444 is commonly used by backdoor trojans! Port 80/443 = web, Port 4444 = suspicious!"
	},
	{
		"question": "What's the difference between public and private IP addresses?",
		"options": [
			"Public = internet, Private = local network only",
			"They are the same",
			"Private = faster, Public = slower"
		],
		"correct": 0,
		"explanation": "Private IPs (192.168.x.x) work only on local network. Public IPs are visible to the entire internet!"
	},
	{
		"question": "Which protocol is secure (encrypted)?",
		"options": ["HTTP", "HTTPS", "FTP"],
		"correct": 1,
		"explanation": "HTTPS uses encryption (the 'S' = Secure). HTTP sends data in plaintext - anyone can read it!"
	}
]


func _ready() -> void:
	print("🌐 Network Basics Tutorial Ready")
	
	quiz_panel.visible = false
	diagram_panel.visible = false
	
	_start_section(Section.INTRO)


func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
	diagram_panel.visible = false
	
	match section:
		Section.INTRO:
			section_label.text = "Network Basics for Cybersecurity"
			content_label.text = """UNDERSTANDING COMPUTER NETWORKS

Before analyzing malware and attacks, you need to understand how computers communicate:

🌐 Topics we'll cover:
   • IP Addresses (computer addresses on networks)
   • Ports (doors for different services)
   • Protocols (languages computers speak)

Why this matters:
• Malware connects to Command & Control (C2) servers
• Firewalls block suspicious ports
• You'll see these in logs: "Connection to 45.33.32.156:4444"

Let's learn what those numbers mean!

Click NEXT to learn about IP addresses →"""
		
		Section.IP_ADDRESSES:
			section_label.text = "IP Addresses - Computer Street Addresses"
			content_label.text = """WHAT IS AN IP ADDRESS?

IP Address = Unique identifier for computers on a network
Think of it like a street address for your computer!

TWO TYPES:

1️⃣ PRIVATE IP (Local Network Only)
   • 192.168.x.x, 10.x.x.x, 172.16-31.x.x
   • Only visible on your home/office network
   • Router assigns these
   • Example: Your laptop = 192.168.1.100

2️⃣ PUBLIC IP (Internet-Facing)
   • Visible to entire internet
   • ISP assigns one per router
   • Example: Your home router = 45.67.89.123
   • All devices in your home share this PUBLIC IP

MALWARE EXAMPLE:
"Connection to 45.33.32.156" means malware is talking to an internet server (likely attacker's Command & Control server!)"""
			diagram_panel.visible = true
			diagram_text.text = """
NETWORK DIAGRAM:

[Your Laptop]          [Your Phone]
192.168.1.100          192.168.1.101
	   ↓                     ↓
	[Home Router] ← Public IP: 45.67.89.123
		   ↓
	  [Internet]
		   ↓
  [Attacker Server] ← Public IP: 45.33.32.156
"""
		
		Section.PORTS:
			section_label.text = "Ports - Doors for Different Services"
			content_label.text = """WHAT ARE PORTS?

If IP Address = Street Address, then Port = Apartment Number!

One computer (IP) can run many services (ports):
• Web server on port 80
• Email server on port 25
• Game server on port 7777

PORT FORMAT: IP:Port
Example: 192.168.1.100:80 means "computer 192.168.1.100, port 80"

COMMON PORTS:
✓ Port 80  = HTTP (websites)
✓ Port 443 = HTTPS (secure websites)
✓ Port 22  = SSH (remote login)
✓ Port 25  = SMTP (email)
✓ Port 3389 = RDP (Windows Remote Desktop)

⚠️ SUSPICIOUS PORTS (used by malware):
❌ Port 4444 = Common backdoor
❌ Port 31337 = "Elite" hacker port
❌ Port 1337  = Another hacker favorite

When you see "Connection to 45.33.32.156:4444" → RED FLAG!"""
			diagram_panel.visible = true
			diagram_text.text = """
PORTS DIAGRAM:

Computer: 192.168.1.100
┌─────────────────────┐
│ Port 80:  Web       │ ← Browser connects here
│ Port 443: HTTPS     │ ← Secure web
│ Port 4444: BACKDOOR │ ← MALWARE! 🚨
└─────────────────────┘

Firewall blocks port 4444 = Malware can't connect!
"""
		
		Section.PROTOCOLS:
			section_label.text = "Protocols - Languages Computers Speak"
			content_label.text = """WHAT ARE PROTOCOLS?

Protocol = Set of rules for how computers communicate
Think: English, Spanish, French for humans = HTTP, FTP, TCP for computers

COMMON PROTOCOLS:

🌐 WEB PROTOCOLS:
• HTTP = HyperText Transfer Protocol (websites)
  └─ NOT encrypted - anyone can read your data!
• HTTPS = HTTP Secure (encrypted websites)
  └─ Encrypted - safe for passwords/credit cards

📧 EMAIL PROTOCOLS:
• SMTP = Send email (port 25)
• POP3/IMAP = Receive email (ports 110/143)

🔗 NETWORK PROTOCOLS:
• TCP = Reliable delivery (confirm every packet)
• UDP = Fast but unreliable (streaming, gaming)

🔒 SECURITY PROTOCOLS:
• SSH = Secure remote login (port 22)
• TLS/SSL = Encryption layer (used in HTTPS)

MALWARE EXAMPLE:
Trojan opens TCP connection on port 4444 to attacker's server.
You'll see: "TCP connection to 45.33.32.156:4444" in firewall logs!"""
			diagram_panel.visible = true
			diagram_text.text = """
PROTOCOL STACK:

Application:  HTTP, FTP, SSH
	 ↓
Transport:    TCP, UDP
	 ↓
Internet:     IP (routing)
	 ↓
Physical:     WiFi, Ethernet

Example: Browsing website
HTTP → TCP → IP → WiFi → Internet!
"""
		
		Section.QUIZ:
			section_label.text = "Network Knowledge Check"
			quiz_panel.visible = false
			_show_quiz_question()
		
		Section.COMPLETE:
			section_label.text = "Network Basics Mastered!"
			content_label.text = """🎉 CONGRATULATIONS!

You now understand network fundamentals:

✓ IP Addresses:
  • Private (192.168.x.x) = local only
  • Public (visible to internet)

✓ Ports:
  • Port 80/443 = Web (normal)
  • Port 4444 = Backdoor (suspicious!)

✓ Protocols:
  • HTTP = Not encrypted
  • HTTPS = Encrypted (secure)
  • TCP/UDP = Transport methods

Quiz Score: %d/%d correct

NOW WHEN YOU SEE:
"Connection to 45.33.32.156:4444"

YOU KNOW:
• 45.33.32.156 = Attacker's public IP
• Port 4444 = Backdoor trojan
• Should be BLOCKED by firewall!

Ready for advanced security tutorials!""" % [score, quiz_questions.size()]
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
			_start_section(Section.IP_ADDRESSES)
		Section.IP_ADDRESSES:
			_start_section(Section.PORTS)
		Section.PORTS:
			_start_section(Section.PROTOCOLS)
		Section.PROTOCOLS:
			_start_section(Section.QUIZ)
		Section.COMPLETE:
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			tutorial_mgr.save_tutorial_result("intermediate_network", score * 50, quiz_questions.size() * 50)
			
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
