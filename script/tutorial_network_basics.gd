extends Control

# ============================================
# NETWORK BASICS TUTORIAL
# IP addresses, ports, protocols
# Foundation for understanding advanced scenarios
# ============================================

enum Section {
	INTRO,
	IP_LESSON,
	IP_CHALLENGE,
	PORT_LESSON,
	PORT_CHALLENGE,
	PROTOCOL_LESSON,
	PROTOCOL_CHALLENGE,
	COMPLETE
}

var current_section = Section.INTRO
var score := 0
var xp_earned := 150
var challenge_items := []
var current_challenge_index := 0
var reference_visible := true

# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/SectionLabel
@onready var content_scroll: ScrollContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll
@onready var content_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var quiz_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel
@onready var quiz_question: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/QuestionLabel
@onready var option_container: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/QuizPanel/OptionsContainer
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup

# Typing animation
var typing_speed := 0.015
var current_text := ""
var target_text := ""
var typing_tween: Tween = null
var cursor_blink_tween: Tween = null
var cursor_label: Label = null
var cmd_prefix_label: Label = null

# Challenge data
var ip_challenges := [
	{"ip": "192.168.1.100", "type": "private", "hint": "Starts with 192.168 = Your home network!"},
	{"ip": "10.0.0.50", "type": "private", "hint": "Starts with 10 = Company network"},
	{"ip": "45.33.32.156", "type": "public", "hint": "Not 192.168 or 10 = Internet!"},
	{"ip": "172.16.5.20", "type": "private", "hint": "172.16-31 = Private range"},
	{"ip": "8.8.8.8", "type": "public", "hint": "Google DNS = Public internet IP"},
	{"ip": "192.168.0.1", "type": "private", "hint": "192.168 again = Your router!"},
	{"ip": "203.45.67.89", "type": "public", "hint": "Unknown number = Public IP"}
]

var port_challenges := [
	{"connection": "192.168.1.100:80", "action": "allow", "hint": "Port 80 = Normal websites (HTTP)"},
	{"connection": "45.33.32.156:443", "action": "allow", "hint": "Port 443 = Secure websites (HTTPS)"},
	{"connection": "203.45.12.34:4444", "action": "block", "hint": "Port 4444 = BACKDOOR TROJAN!"},
	{"connection": "192.168.1.50:22", "action": "allow", "hint": "Port 22 = SSH remote login (safe)"},
	{"connection": "45.67.89.12:31337", "action": "block", "hint": "Port 31337 = Hacker port (elite)"},
	{"connection": "8.8.8.8:53", "action": "allow", "hint": "Port 53 = DNS lookups (normal)"},
	{"connection": "203.12.45.67:1337", "action": "block", "hint": "Port 1337 = Suspicious malware port"}
]

var protocol_challenges := [
	{"protocol": "HTTPS", "type": "secure", "hint": "HTTPS = The 'S' means SECURE!"},
	{"protocol": "HTTP", "type": "unsafe", "hint": "HTTP = NO encryption, anyone can read it"},
	{"protocol": "SSH", "type": "secure", "hint": "SSH = Encrypted remote login"},
	{"protocol": "FTP", "type": "unsafe", "hint": "FTP = Old file transfer, no encryption"},
	{"protocol": "TLS", "type": "secure", "hint": "TLS = Encryption layer (used in HTTPS)"},
	{"protocol": "Telnet", "type": "unsafe", "hint": "Telnet = Sends passwords in plain text!"}
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

func _toggle_cmd_interface(show_cmd: bool) -> void:
	if cmd_prefix_label:
		cmd_prefix_label.visible = show_cmd
	if cursor_label:
		cursor_label.visible = show_cmd
	
	var cmd_input = find_child("CommandInput", true, false)
	if cmd_input:
		cmd_input.visible = show_cmd

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
	
	# Setup CMD-style interface
	_setup_cmd_interface()
	
	_start_section(Section.INTRO)


func _start_section(section: Section) -> void:
	current_section = section
	quiz_panel.visible = false
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
			section_label.text = "Network Basics for Beginners"
			section_text = """WELCOME TO NETWORK BASICS!

Don't worry if you've never learned about networks before.
We'll teach you step by step!

Think of the internet like a postal system:
 • Your computer has an ADDRESS (IP address)
 • Services use different DOORS (ports)
 • Messages follow RULES (protocols)

You'll learn:
 1. IP Addresses - Computer addresses
 2. Ports - Different services
 3. Protocols - Communication rules

Each lesson has:
 ✓ Simple explanation
 ✓ Interactive practice
 ✓ Hints to help you

Ready to become a network expert?
Type 'next' to start learning! →"""
		
		Section.IP_LESSON:
			section_label.text = "Lesson 1: IP Addresses"
			section_text = """WHAT IS AN IP ADDRESS?

Every computer on a network needs an address, just like houses on a street!

IP Address = 4 numbers separated by dots
Example: 192.168.1.100

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TWO TYPES YOU NEED TO KNOW:

🟢 PRIVATE IP (Safe - Your Local Network)
   • 192.168.x.x  ← Most home networks
   • 10.x.x.x     ← Big company networks
   • 172.16-31.x.x ← Medium networks
   
   Think: Your HOME address
   Only visible inside your house/office
   Example: Your laptop = 192.168.1.100

🔴 PUBLIC IP (Internet - Visible to Everyone)
   • Everything else!
   • Examples: 45.33.32.156, 8.8.8.8
   
   Think: Your STREET address
   Everyone on the internet can see it
   Example: Google = 8.8.8.8

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WHY THIS MATTERS:

When you see: \"Connection to 45.33.32.156\"
   → That's a PUBLIC IP on the INTERNET!
   → Could be a hacker's server!

When you see: \"Connection to 192.168.1.50\"
   → That's a PRIVATE IP on YOUR network
   → Just your phone or laptop

Ready to practice? →"""
		
		Section.IP_CHALLENGE:
			section_label.text = "Practice: Identify IP Addresses"
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
			content_scroll.visible = false
			content_label.visible = false
			quiz_panel.visible = true
			challenge_items = ip_challenges
			current_challenge_index = 0
			_show_challenge("IP")
			return
		
		Section.PORT_LESSON:
			section_label.text = "Lesson 2: Ports"
			section_text = """WHAT ARE PORTS?

If IP Address = House Address, then Port = Room Number!

One computer can run MANY services at once:
 • Web server uses Port 80
 • Secure website uses Port 443
 • Email uses Port 25

═══════════════════════════════════════════

HOW TO READ IT:

Format: IP:Port
Example: 192.168.1.100:80
         └──IP Address─┘ └Port┘

Means: \\\"Computer 192.168.1.100, on port 80\\\"

═══════════════════════════════════════════

COMMON PORTS (You'll See These Often):

✅ SAFE PORTS:
   • Port 80   = HTTP (regular websites)
   • Port 443  = HTTPS (secure websites with lock 🔒)
   • Port 22   = SSH (remote login to servers)
   • Port 25   = SMTP (sending email)
   • Port 53   = DNS (looking up website names)

⚠️ DANGEROUS PORTS (Used by Hackers):
   • Port 4444   = Backdoor trojans
   • Port 31337  = \\\"Elite\\\" hacker port
   • Port 1337   = Another hacker favorite
   • Port 12345  = NetBus trojan

═══════════════════════════════════════════

REAL EXAMPLE:

When you visit www.google.com:
   Your computer → 172.217.14.206:443
                   └─Google's IP─┘ └HTTPS┘

When malware calls home:
   Your computer → 45.33.32.156:4444
                   └─Hacker's IP┘ └Backdoor!┘

═══════════════════════════════════════════

YOUR JOB:
As a security defender, you BLOCK dangerous ports
and ALLOW safe ports!

Ready to be a firewall defender? →"""
		
		Section.PORT_CHALLENGE:
			section_label.text = "Practice: Block or Allow Connections"
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
			content_scroll.visible = false
			content_label.visible = false
			quiz_panel.visible = true
			challenge_items = port_challenges
			current_challenge_index = 0
			_show_challenge("PORT")
			return
		
		Section.PROTOCOL_LESSON:
			section_label.text = "Lesson 3: Protocols"
			section_text = """WHAT ARE PROTOCOLS?

Protocol = Language computers use to talk

Just like humans speak English, Spanish, or French,
computers use HTTP, HTTPS, SSH, etc.

═══════════════════════════════════════════

TWO TYPES YOU NEED TO KNOW:

🔒 SECURE PROTOCOLS (Encrypted - Can't Read)
   • HTTPS  = Websites with lock 🔒
   • SSH    = Secure remote login
   • TLS    = Encryption layer
   • SFTP   = Secure file transfer
   
   Think: Talking in SECRET CODE
   Even if someone listens, they hear gibberish!

🔓 UNSAFE PROTOCOLS (Plain Text - Anyone Can Read)
   • HTTP   = Regular websites (NO lock)
   • FTP    = File transfer (no encryption)
   • Telnet = Old remote login
   • SMTP   = Email (can be intercepted)
   
   Think: Shouting in PUBLIC
   Anyone listening can hear everything!

═══════════════════════════════════════════

REAL-WORLD EXAMPLE:

Sending your password:

HTTP (Unsafe):
   Password: \\\"MySecret123\\\"  ← Anyone can read!
   
HTTPS (Secure):
   Password: \\\"X9$mK2@pL4nR\\\"  ← Encrypted gibberish!

═══════════════════════════════════════════

WHY THIS MATTERS:

✅ Shopping online? Make sure it's HTTPS!
✅ Logging into accounts? Check for the lock 🔒
❌ Sending passwords over HTTP? DANGER!

═══════════════════════════════════════════

QUICK TIP:
Look for the LOCK icon in your browser:
   🔒 https://bank.com  ← SAFE
   ⚠️ http://bank.com   ← DANGER!

Ready to identify secure protocols? →"""
		
		Section.PROTOCOL_CHALLENGE:
			section_label.text = "Practice: Secure or Unsafe?"
			if typing_tween:
				typing_tween.kill()
				typing_tween = null
			content_scroll.visible = false
			content_label.visible = false
			quiz_panel.visible = true
			challenge_items = protocol_challenges
			current_challenge_index = 0
			_show_challenge("PROTOCOL")
			return
		
		Section.COMPLETE:
			section_label.text = "Network Basics Mastered!"
			section_text = """🎉 CONGRATULATIONS!

You've learned the fundamentals of computer networks!

[center]╔══════════════════════════╗
║  ⭐ XP EARNED: +%d XP  ║
╚══════════════════════════╝[/center]

═══════════════════════════════════════════

✅ WHAT YOU LEARNED:

🌐 IP ADDRESSES:
   • 192.168.x.x, 10.x.x.x = PRIVATE (safe, local)
   • Everything else = PUBLIC (internet)
   
🔌 PORTS:
   • Port 80, 443, 22 = SAFE (normal services)
   • Port 4444, 31337 = DANGER (malware!)
   
🔒 PROTOCOLS:
   • HTTPS, SSH, TLS = SECURE (encrypted)
   • HTTP, FTP, Telnet = UNSAFE (plain text)

═══════════════════════════════════════════

YOUR NEW SUPERPOWER:

When you see this in a firewall log:
   "Connection to 45.33.32.156:4444"

You NOW know:
   ✓ 45.33.32.156 = PUBLIC IP (internet, not your network)
   ✓ Port 4444 = BACKDOOR (malware trying to phone home!)
   ✓ Action needed: BLOCK IT!

═══════════════════════════════════════════

Score: %d/18 correct

You're ready for advanced security tutorials!""" % [xp_earned, score]
			next_button.text = "FINISH"
			next_button.disabled = false
	
	# Start typing animation
	if not section_text.is_empty():
		_type_text(section_text)


func _show_challenge(challenge_type: String) -> void:
	if current_challenge_index >= challenge_items.size():
		# All challenges complete - move to next section
		match challenge_type:
			"IP":
				_start_section(Section.PORT_LESSON)
			"PORT":
				_start_section(Section.PROTOCOL_LESSON)
			"PROTOCOL":
				_start_section(Section.COMPLETE)
		return
	
	quiz_panel.visible = true
	var item = challenge_items[current_challenge_index]
	
	# Build challenge text with hint
	var challenge_text = ""
	var hint_text = ""
	
	match challenge_type:
		"IP":
			challenge_text = "🌐 IP Address: %s" % item["ip"]
			hint_text = "💡 Hint: %s" % item["hint"]
		"PORT":
			challenge_text = "🔌 Connection: %s" % item["connection"]
			hint_text = "💡 Hint: %s" % item["hint"]
		"PROTOCOL":
			challenge_text = "📡 Protocol: %s" % item["protocol"]
			hint_text = "💡 Hint: %s" % item["hint"]
	
	# Show challenge with progress
	quiz_question.text = "[center]Challenge %d/%d\n\n%s\n\n%s[/center]" % [
		current_challenge_index + 1,
		challenge_items.size(),
		challenge_text,
		hint_text if reference_visible else ""
	]
	quiz_question.add_theme_color_override("font_color", Color.WHITE)
	
	# Clear previous buttons
	for child in option_container.get_children():
		child.queue_free()
	
	# Create answer buttons based on challenge type
	match challenge_type:
		"IP":
			_create_answer_button("🟢 PRIVATE", "private", item)
			_create_answer_button("🔴 PUBLIC", "public", item)
		"PORT":
			_create_answer_button("✅ ALLOW", "allow", item)
			_create_answer_button("🛑 BLOCK", "block", item)
		"PROTOCOL":
			_create_answer_button("🔒 SECURE", "secure", item)
			_create_answer_button("⚠️ UNSAFE", "unsafe", item)
	
	# Disable next/back during challenge
	next_button.disabled = true
	back_button.disabled = true


func _create_answer_button(text: String, answer: String, item: Dictionary) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 50)
	button.add_theme_font_size_override("font_size", 18)
	
	# Get the correct answer key based on challenge type
	var correct_answer = ""
	if item.has("type"):
		correct_answer = item["type"]
	elif item.has("action"):
		correct_answer = item["action"]
	
	button.pressed.connect(func(): _on_challenge_answer(answer, correct_answer))
	option_container.add_child(button)


func _on_challenge_answer(selected: String, correct: String) -> void:
	var is_correct = (selected == correct)
	
	# Disable all buttons
	for button in option_container.get_children():
		button.disabled = true
	
	# Show feedback
	if is_correct:
		score += 1
		quiz_question.text += "\n\n✅ CORRECT!"
		quiz_question.add_theme_color_override("font_color", Color(0, 0.8, 0))
	else:
		quiz_question.text += "\n\n❌ WRONG! The answer was: %s" % correct.to_upper()
		quiz_question.add_theme_color_override("font_color", Color(0.8, 0, 0))
	
	await get_tree().create_timer(2.0).timeout
	quiz_question.add_theme_color_override("font_color", Color.WHITE)
	
	# Move to next challenge
	current_challenge_index += 1
	
	# Determine challenge type from current section
	var challenge_type = ""
	match current_section:
		Section.IP_CHALLENGE:
			challenge_type = "IP"
		Section.PORT_CHALLENGE:
			challenge_type = "PORT"
		Section.PROTOCOL_CHALLENGE:
			challenge_type = "PROTOCOL"
	
	_show_challenge(challenge_type)


func _on_next_pressed() -> void:
	match current_section:
		Section.INTRO:
			_start_section(Section.IP_LESSON)
		Section.IP_LESSON:
			_start_section(Section.IP_CHALLENGE)
		Section.PORT_LESSON:
			_start_section(Section.PORT_CHALLENGE)
		Section.PROTOCOL_LESSON:
			_start_section(Section.PROTOCOL_CHALLENGE)
		Section.COMPLETE:
			print("[TUTORIAL] FINISH button pressed!")
			print("[TUTORIAL] Score: %d/18" % score)
			print("[TUTORIAL] XP Earned: %d" % xp_earned)
			
			# Save tutorial result with XP
			var tutorial_mgr = get_node_or_null("/root/TutorialManager")
			if tutorial_mgr:
				print("[TUTORIAL] TutorialManager found, saving result...")
				tutorial_mgr.save_tutorial_result("beginner_network", xp_earned, xp_earned)
				
				if tutorial_mgr.has_signal("save_completed"):
					print("[TUTORIAL] Waiting for Firestore save...")
					await tutorial_mgr.save_completed
					print("[TUTORIAL] Save confirmed!")
			else:
				push_error("[TUTORIAL] TutorialManager not found!")
			
			# Return to mode selection
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_back_pressed() -> void:
	match current_section:
		Section.INTRO:
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Section.IP_LESSON:
			_start_section(Section.INTRO)
		Section.IP_CHALLENGE:
			_start_section(Section.IP_LESSON)
		Section.PORT_LESSON:
			_start_section(Section.IP_CHALLENGE)
		Section.PORT_CHALLENGE:
			_start_section(Section.PORT_LESSON)
		Section.PROTOCOL_LESSON:
			_start_section(Section.PORT_CHALLENGE)
		Section.PROTOCOL_CHALLENGE:
			_start_section(Section.PROTOCOL_LESSON)
		Section.COMPLETE:
			_start_section(Section.PROTOCOL_CHALLENGE)


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
