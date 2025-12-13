extends Control

# ============================================
# NETWORK BASICS TUTORIAL
# IP addresses, ports, protocols
# Foundation for understanding advanced scenarios
# ============================================

enum Section {
	INTRO,
	IP_ADDRESSES,
	NAT_EXPLAINED,      # NEW: Added NAT section
	SUBNET_MASKS,       # NEW: Added Subnet Masks section
	PORTS,
	PROTOCOLS,
	QUIZ,
	COMPLETE
}

var current_section = Section.INTRO
var score := 0
var current_quiz_index := 0

# Node references
# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/SectionLabel
@onready var content_scroll: ScrollContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var diagram_panel: PanelContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel
@onready var diagram_text: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/DiagramPanel/DiagramText
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup
# Interactive diagram components
var diagram_container: Control = null
var packet_sprite: Control = null  # Can be TextureRect or ColorRect
var packet_label: Label = null  # NEW: Shows IP:Port on packet during animation
var animation_tween: Tween = null
var typing_speed := 0.015  # Seconds per character
var current_text := ""
var target_text := ""
var typing_tween: Tween = null
var cursor_blink_tween: Tween = null
var cursor_label: Label = null
var cmd_prefix_label: Label = null

# Quiz data
var quiz_questions := [
	{
		"question": "Your device is 192.168.1.50. Malware connects to 45.33.32.156:4444. Where is the attacker?",
		"options": [
			"On my local network",
			"On the internet (external)",
			"In my router"
		],
		"correct": 1,
		"explanation": "45.x.x.x is a PUBLIC IP! If it was 192.168.1.x, the attacker would be on YOUR network (worse!)."
	},
	{
		"question": "What does NAT (Network Address Translation) do?",
		"options": [
			"Encrypts your traffic",
			"Translates private IPs to public IP",
			"Blocks all malware"
		],
		"correct": 1,
		"explanation": "NAT lets multiple devices share ONE public IP by translating private IPs at the router!"
	},
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
		"question": "Which IP range is private (local network only)?",
		"options": [
			"192.168.0.0 to 192.168.255.255",
			"45.0.0.0 to 45.255.255.255",
			"8.8.8.8"
		],
		"correct": 0,
		"explanation": "192.168.x.x is a private range! 45.x.x.x and 8.8.8.8 are PUBLIC IPs visible to the internet."
	},
	{
		"question": "Which protocol is secure (encrypted)?",
		"options": ["HTTP", "HTTPS", "FTP"],
		"correct": 1,
		"explanation": "HTTPS uses encryption (the 'S' = Secure). HTTP sends data in plaintext - anyone can read it!"
	}
]
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
	
	# Set text alignment and CMD styling
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1))
	content_label.add_theme_font_size_override("font_size", 17)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.custom_minimum_size = Vector2(690, 0)
	
	var mono_font = load("res://asset/fonts/CONSOLA.TTF")
	if not mono_font:
		mono_font = load("res://asset/fonts/ABeeZee-Regular.ttf")
	if mono_font:
		content_label.add_theme_font_override("font", mono_font)
	
	# Create VBox for CMD interface
	var scroll_content = scroll_container.get_child(0)
	if scroll_content and scroll_content != content_label:
		# VBox already exists
		pass
	else:
		# Create new VBox and reorganize
		var content_vbox = VBoxContainer.new()
		content_vbox.add_theme_constant_override("separation", 5)
		
		# Add CMD prefix label
		cmd_prefix_label = Label.new()
		cmd_prefix_label.text = "C:\\NETWORK\\TUTORIAL>"
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
		cmd_input.visible = false  # Start hidden
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
	
	var cmd_input = find_child("CommandInput", true, false)
	if cmd_input:
		cmd_input.visible = visible

func _start_cursor_blink() -> void:
	if not cursor_label:
		return
		
	if cursor_blink_tween:
		cursor_blink_tween.kill()
	
	cursor_blink_tween = create_tween()
	cursor_blink_tween.set_loops()
	cursor_blink_tween.tween_property(cursor_label, "modulate:a", 0.0, 0.5)
	cursor_blink_tween.tween_property(cursor_label, "modulate:a", 1.0, 0.5)

func _on_command_entered(command: String) -> void:
	var cmd = command.strip_edges().to_lower()
	var cmd_input = find_child("CommandInput", true, false)
	
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
		var help_text = "\n> Available commands: next, back, help"
		content_label.text += help_text
	else:
		var error_text = "\n> Unknown command: '" + command + "'. Type 'help' for available commands."
		content_label.text += error_text

func _style_cmd_buttons() -> void:
	# Style NEXT button - softer green
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
	
	# Style BACK button - softer red
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
	content_label.text = ""
	
	# Show cursor while typing
	if cursor_label:
		cursor_label.visible = true
	
	typing_tween = create_tween()
	
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			if i < target_text.length():
				current_text += target_text[i]
				content_label.text = current_text + "█"  # Cursor follows text
		)
		var delay = typing_speed
		if i < text.length() and text[i] == '\n':
			delay = 0.1
		typing_tween.tween_interval(delay)
	
	# Hide cursor after typing completes
	typing_tween.tween_callback(func():
		content_label.text = current_text  # Remove cursor
		if cursor_label:
			cursor_label.visible = false
	)
func _ready() -> void:
	print("🌐 Network Basics Tutorial Ready")
	
	quiz_panel.visible = false
	diagram_panel.visible = false
	
	# Setup CMD-style interface
	_setup_cmd_interface()
	
	_start_section(Section.INTRO)


func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
	diagram_panel.visible = false
	content_scroll.visible = true
	content_label.visible = true
	
	# Toggle CMD interface (only show in INTRO)
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
	
	var section_text := ""

	match section:
		Section.INTRO:
			section_label.text = "Network Basics for Cybersecurity"
			section_text = """UNDERSTANDING COMPUTER NETWORKS

Before analyzing malware and attacks, you need to understand how computers communicate:

 Topics we'll cover:
   • IP Addresses 
   • Ports 
   • Protocols

Why this matters:
• Malware connects to Command & Control (C2) servers
• Firewalls block suspicious ports
• You'll see these in logs: "Connection to 45.33.32.156:4444"

Let's learn what those numbers mean!

Type 'next' to learn about IP addresses →"""
		
		Section.IP_ADDRESSES:
			section_label.text = "IP Addresses - Computer Street Addresses"
			section_text = """WHAT IS AN IP ADDRESS?
			
IP Address = Unique identifier for computers on a network
Think of it like a street address for your computer!

FORMAT: Four numbers (0-255) separated by dots
Example: 192.168.1.100 = 192 | 168 | 1 | 100
Why 0-255? Each section = 8 bits = 2⁸ = 256 possible values

TWO TYPES:

1️⃣ PRIVATE IP (Local Network Only)
   • 10.0.0.0 to 10.255.255.255 (Class A - large networks)
   • 172.16.0.0 to 172.31.255.255 (Class B - medium networks)
   • 192.168.0.0 to 192.168.255.255 (Class C - home networks)
   • Only visible on your home/office network
   • Router assigns these
   • Example: Your laptop = 192.168.1.100

2️⃣ PUBLIC IP (Internet-Facing)
   • Visible to entire internet
   • ISP assigns one per router
   • Example: Your home router = 45.67.89.123
   • All devices in your home share this PUBLIC IP

SPECIAL IPs:
   • 127.0.0.1 = Localhost (your own computer)
   • 0.0.0.0 = Any address (server configs)

MALWARE EXAMPLE:
"Connection to 45.33.32.156" means malware is talking to an internet server (likely attacker's Command & Control server!)


MALWARE EXAMPLE:
"Connection to 45.33.32.156" means malware is talking to an internet server (likely attacker's Command & Control server!)

Click on the interactive diagram below to see packet flow! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_network_diagram()
		
		Section.PORTS:
			section_label.text = "Ports - Doors for Different Services"
			section_text = """WHAT ARE PORTS?

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

When you see "Connection to 45.33.32.156:4444" → RED FLAG!

Click on ports below to see what happens! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_ports_diagram()
		
		Section.PROTOCOLS:
			section_label.text = "Protocols - Languages Computers Speak"
			section_text = """WHAT ARE PROTOCOLS?

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
You'll see: "TCP connection to 45.33.32.156:4444" in firewall logs!

Click to see protocol layers in action! →"""
			diagram_panel.visible = true
			diagram_text.visible = false
			_create_protocol_stack_diagram()
		
		Section.QUIZ:
			section_label.text = "Network Knowledge Check"
			
			# Stop typing and hide content
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
			
			content_scroll.visible = false
			content_label.visible = false
			diagram_panel.visible = false
			quiz_panel.visible = false
			
			# Hide CMD interface during quiz
			_toggle_cmd_interface(false)
			
			# Show buttons
			next_button.visible = true
			back_button.visible = true
			
			_show_quiz_question()
			return  # Skip typing
		
		Section.COMPLETE:
			section_label.text = "Network Basics Mastered!"
			section_text = """🎉 CONGRATULATIONS!

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
	
	# Clear and reset quiz question text (not append)
	quiz_question.text = "Q%d: %s" % [current_quiz_index + 1, q["question"]]
	quiz_question.add_theme_color_override("font_color", Color.WHITE)
	
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
			print("[TUTORIAL] FINISH button pressed!")
			print("[TUTORIAL] Quiz Score: %d/%d" % [score, quiz_questions.size()])
			print("[TUTORIAL] Calculated Score: %d / Max: %d" % [score * 50, quiz_questions.size() * 50])
			
			# Save tutorial result
			var tutorial_mgr = get_node("/root/TutorialManager")
			if tutorial_mgr:
				print("[TUTORIAL] TutorialManager found, saving result...")
				tutorial_mgr.save_tutorial_result("beginner_network", score * 50, quiz_questions.size() * 50)
				
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
		Section.IP_ADDRESSES:
			_start_section(Section.INTRO)
		Section.PORTS:
			_start_section(Section.IP_ADDRESSES)
		Section.PROTOCOLS:
			_start_section(Section.PORTS)
		Section.QUIZ:
			_start_section(Section.PROTOCOLS)
		Section.COMPLETE:
			# From complete screen, go back to quiz start
			current_quiz_index = 0
			score = 0
			_start_section(Section.QUIZ)


# ============================================
# INTERACTIVE DIAGRAM FUNCTIONS
# ============================================

func _clear_diagram() -> void:
	# Stop any running animations
	if animation_tween and animation_tween.is_running():
		animation_tween.kill()
	
	# Clear existing diagram content
	if diagram_container:
		diagram_container.queue_free()
		diagram_container = null
	
	# Create fresh container
	diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(0, 300)
	diagram_panel.add_child(diagram_container)


func _create_network_diagram() -> void:
	_clear_diagram()
	
	# Center-aligned network nodes (diagram width ~500px)
	var laptop = _create_device_node("💻 Laptop\n192.168.1.100", Vector2(50, 30), Color(0.3, 0.7, 1.0))
	var phone = _create_device_node("📱 Phone\n192.168.1.101", Vector2(310, 30), Color(0.3, 0.7, 1.0))
	var router = _create_device_node("🌐 Router\n45.67.89.123", Vector2(180, 100), Color(0.2, 0.8, 0.5))
	var internet = _create_device_node("☁️ Internet", Vector2(180, 165), Color(0.5, 0.5, 0.5))
	var attacker = _create_device_node("⚠️ Attacker\n45.33.32.156", Vector2(180, 230), Color(1.0, 0.3, 0.3))
	
	diagram_container.add_child(laptop)
	diagram_container.add_child(phone)
	diagram_container.add_child(router)
	diagram_container.add_child(internet)
	diagram_container.add_child(attacker)
	
	# Create animated user icon (use boy.png if available, fallback to colored circle)
	var user_icon_path = "res://asset/icons/boy.png"  # User icon representing YOU
	if ResourceLoader.exists(user_icon_path):
		# Use custom user image
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(user_icon_path)
		texture_rect.custom_minimum_size = Vector2(32, 32)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.position = laptop.position + Vector2(55, 10)
		packet_sprite = texture_rect
	else:
		# Fallback: Create circular sprite
		packet_sprite = ColorRect.new()
		packet_sprite.custom_minimum_size = Vector2(24, 24)
		packet_sprite.color = Color(1.0, 0.8, 0.0)
		packet_sprite.position = laptop.position + Vector2(60, 15)
	
	diagram_container.add_child(packet_sprite)
	
	# Add instruction label
	var instruction = Label.new()
	instruction.text = "▶️ Watch how YOUR data travels and gets tracked by the attacker!"
	instruction.position = Vector2(10, 10)
	instruction.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
	instruction.add_theme_font_size_override("font_size", 12)
	diagram_container.add_child(instruction)
	
	# Start animation
	_animate_packet_flow([laptop, router, internet, attacker])


func _create_ports_diagram() -> void:
	_clear_diagram()
	
	# Computer box
	var computer_box = PanelContainer.new()
	computer_box.custom_minimum_size = Vector2(400, 200)
	computer_box.position = Vector2(50, 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.8, 0.9, 1.0)
	computer_box.add_theme_stylebox_override("panel", style)
	diagram_container.add_child(computer_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	computer_box.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Computer: 192.168.1.100"
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	# Create clickable port buttons
	var port_80 = _create_port_button("Port 80: Web (HTTP)", Color(0.2, 0.8, 0.3), false)
	var port_443 = _create_port_button("Port 443: HTTPS (Secure)", Color(0.2, 0.8, 0.3), false)
	var port_4444 = _create_port_button("Port 4444: BACKDOOR", Color(0.9, 0.2, 0.2), true)
	
	vbox.add_child(port_80)
	vbox.add_child(port_443)
	vbox.add_child(port_4444)
	
	# Status label
	var status = Label.new()
	status.name = "StatusLabel"
	status.text = "Click on a port to see what happens!"
	status.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 1.0))
	status.add_theme_font_size_override("font_size", 14)
	status.position = Vector2(50, 270)
	diagram_container.add_child(status)


func _create_protocol_stack_diagram() -> void:
	_clear_diagram()
	
	var layers = [
		{"name": "Application", "examples": "HTTP, FTP, SSH", "color": Color(0.8, 0.3, 0.3)},
		{"name": "Transport", "examples": "TCP, UDP", "color": Color(0.3, 0.8, 0.3)},
		{"name": "Internet", "examples": "IP (routing)", "color": Color(0.3, 0.3, 0.8)},
		{"name": "Physical", "examples": "WiFi, Ethernet", "color": Color(0.7, 0.7, 0.3)}
	]
	
	var y_pos = 20
	for i in range(layers.size()):
		var layer = layers[i]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(400, 60)
		panel.position = Vector2(50, y_pos)
		
		var style = StyleBoxFlat.new()
		style.bg_color = layer.color
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.0, 0.0, 0.0, 1.0)
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		
		var title = Label.new()
		title.text = layer.name
		title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		title.add_theme_font_size_override("font_size", 16)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)
		
		var examples = Label.new()
		examples.text = layer.examples
		examples.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		examples.add_theme_font_size_override("font_size", 12)
		examples.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(examples)
		
		diagram_container.add_child(panel)
		y_pos += 70


func _create_device_node(label_text: String, pos: Vector2, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 50)
	panel.position = pos
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)
	
	return panel


func _create_port_button(text: String, color: Color, is_malware: bool) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	button.add_theme_stylebox_override("normal", style)
	
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	if is_malware:
		button.pressed.connect(func(): _on_malware_port_clicked())
	else:
		button.pressed.connect(func(): _on_safe_port_clicked(text))
	
	return button


func _animate_packet_flow(nodes: Array) -> void:
	if animation_tween:
		animation_tween.kill()
	
	animation_tween = create_tween().set_loops()
	
	# Color changes as user data travels (blue → yellow → red = tracked!)
	var colors = [
		Color(0.3, 0.7, 1.0),   # Blue at laptop (safe)
		Color(0.8, 0.8, 0.2),   # Yellow at router (transmitting)
		Color(0.7, 0.7, 0.7),   # Gray at internet (public)
		Color(1.0, 0.2, 0.2)    # Red at attacker (TRACKED!)
	]
	
	for i in range(nodes.size()):
		# Center user icon on each node
		var target_pos = nodes[i].position + Vector2(55, 10)
		animation_tween.tween_property(packet_sprite, "position", target_pos, 0.8)
		
		# Change color to show danger level (only works for ColorRect fallback)
		if packet_sprite is ColorRect:
			animation_tween.tween_property(packet_sprite, "color", colors[i], 0.3)
		
		animation_tween.tween_interval(0.3)
	
	# Return to start
	animation_tween.tween_property(packet_sprite, "position", nodes[0].position + Vector2(55, 10), 0.5)
	if packet_sprite is ColorRect:
		animation_tween.tween_property(packet_sprite, "color", colors[0], 0.3)
	animation_tween.tween_interval(1.0)


func _on_safe_port_clicked(port_name: String) -> void:
	var status = diagram_container.get_node("StatusLabel")
	if status:
		status.text = "✅ " + port_name + " - Normal traffic allowed!"
		status.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0, 1.0))


func _on_malware_port_clicked() -> void:
	var status = diagram_container.get_node("StatusLabel")
	if status:
		status.text = "🚨 BLOCKED BY FIREWALL! Malware can't connect!"
		status.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))

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
