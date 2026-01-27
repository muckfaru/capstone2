extends Control

# Instruction page data
var instruction_pages = []
var current_page = 0

# Custom font
var content_font: Font

# Node references
@onready var title_label = $VBox/TitleLabel
@onready var content_container = $VBox/ContentScroll/ContentVBox
@onready var prev_button = $VBox/ButtonBox/PrevButton
@onready var next_button = $VBox/ButtonBox/NextButton
@onready var start_button = $VBox/ButtonBox/StartButton

# Threat icons (matching Threat.gd)
var threat_textures = {
	"phishing": "res://asset/threats/phishing.png",
	"brute_force": "res://asset/threats/brute_force.png",
	"malware": "res://asset/threats/malware.png",
	"ddos": "res://asset/threats/ddos.png",
	"sql_injection": "res://asset/threats/sql_injection.png",
	"ransomware": "res://asset/threats/ransomware.png",
	"zero_day": "res://asset/threats/zero_day.png",
	"insider_threat": "res://asset/threats/insider_threat.png"
}

# Defense tool icons
var defense_textures = {
	"firewall": "res://asset/Firewallshield.png",
	"antivirus": "res://asset/minigamesicon/antiv.png",
	"email_filter": "res://asset/minigamesicon/emailfiltering.png",
	"strong_password": "res://asset/minigamesicon/password.png",
	"backup_system": "res://asset/minigamesicon/backup.png",
	"security_patch": "res://asset/minigamesicon/patch.png",
	"access_control": "res://asset/minigamesicon/authee.png"
}

func _ready():
	# Load custom font
	var font_path = "res://asset/fonts/ChakraPetch-SemiBold.ttf"  # Change to your actual font file
	if ResourceLoader.exists(font_path):
		content_font = load(font_path)
	
	setup_instruction_pages()
	update_page_display()
	
	# Connect button signals
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	start_button.pressed.connect(_on_start_pressed)

func setup_instruction_pages():
	"""Define all instruction pages with threat info and defense recommendations"""
	
	# Page 1: Welcome
	instruction_pages.append({
		"title": "CYBER DEFENSE COMMAND",
		"type": "welcome",
		"content": "Welcome, Commander!\n\nShadow Byte hackers are attacking CyberCorp's network!\n\nYour mission: Use defense tools to block incoming cyber threats and protect critical assets.\n\nLet's learn about the threats you'll face..."
	})
	
	# Page 2: Phishing & Email Filter
	instruction_pages.append({
		"title": "THREAT: Phishing",
		"type": "threat_defense",
		"threat": "phishing",
		"threat_name": "Phishing Attack",
		"description": "Fake emails trick users into revealing passwords and sensitive information. Targets employee computers and CEO laptop.",
		"defenses": ["email_filter"],
		"defense_names": ["Email Filter"]
	})
	
	# Page 3: Brute Force & Defenses
	instruction_pages.append({
		"title": "THREAT: Brute Force",
		"type": "threat_defense",
		"threat": "brute_force",
		"threat_name": "Brute Force Attack",
		"description": "Automated password guessing attempts to crack weak passwords. Targets databases.",
		"defenses": ["firewall", "strong_password"],
		"defense_names": ["Firewall", "Strong Password"]
	})
	
	# Page 4: Malware & Antivirus
	instruction_pages.append({
		"title": "THREAT: Malware",
		"type": "threat_defense",
		"threat": "malware",
		"threat_name": "Malware Infection",
		"description": "Malicious software that damages or steals data. Can spread through employee computers.",
		"defenses": ["antivirus"],
		"defense_names": ["Antivirus"]
	})
	
	# Page 5: DDoS & Firewall
	instruction_pages.append({
		"title": "THREAT: DDoS",
		"type": "threat_defense",
		"threat": "ddos",
		"threat_name": "DDoS Attack",
		"description": "Distributed Denial of Service floods network with fake traffic, overwhelming routers.",
		"defenses": ["firewall"],
		"defense_names": ["Firewall"]
	})
	
	# Page 6: SQL Injection & Patch
	instruction_pages.append({
		"title": "THREAT: SQL Injection",
		"type": "threat_defense",
		"threat": "sql_injection",
		"threat_name": "SQL Injection",
		"description": "Code injection exploits unpatched database vulnerabilities to steal data.",
		"defenses": ["security_patch"],
		"defense_names": ["Security Patch"]
	})
	
	# Page 7: Ransomware & Defenses
	instruction_pages.append({
		"title": "THREAT: Ransomware",
		"type": "threat_defense",
		"threat": "ransomware",
		"threat_name": "Ransomware",
		"description": "Encrypts files and demands payment. Targets backups and databases.",
		"defenses": ["antivirus", "backup_system"],
		"defense_names": ["Antivirus", "Backup System"]
	})
	
	# Page 8: How to Play
	instruction_pages.append({
		"title": "HOW TO PLAY",
		"type": "gameplay",
		"content": "1. Click a defense tool from the toolbar at the bottom\n\n2. Click on an incoming threat to apply the defense\n\n3. Use the CORRECT defense for each threat type!\n\n4. Wrong defenses won't stop the threat and cost points\n\n5. Protect assets - if 3 assets reach 0 health, game over!\n\n6. Block threats quickly to earn points"
	})
	
	# Page 9: Ready to Play
	instruction_pages.append({
		"title": "READY FOR BATTLE?",
		"type": "final",
		"content": "Remember:\n\n✅ Match the RIGHT defense to each threat\n✅ Work quickly - threats are fast!\n✅ Protect your assets\n✅ Wrong defenses = penalty\n\nGood luck, Commander!\n\nClick START MISSION when ready!"
	})

func update_page_display():
	"""Update UI to show current instruction page"""
	var page_data = instruction_pages[current_page]
	
	# Update title
	title_label.text = page_data.title
	
	# Clear previous content
	for child in content_container.get_children():
		child.queue_free()
	
	# Display content based on page type
	match page_data.type:
		"welcome", "gameplay", "final":
			display_text_page(page_data)
		"threat_defense":
			display_threat_defense_page(page_data)
	
	# Update button visibility
	prev_button.visible = current_page > 0
	next_button.visible = current_page < instruction_pages.size() - 1
	start_button.visible = current_page == instruction_pages.size() - 1

func display_text_page(page_data):
	"""Display a simple text page"""
	var label = Label.new()
	label.text = page_data.content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Styling
	if content_font:
		label.add_theme_font_override("font", content_font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	content_container.add_child(label)

func display_threat_defense_page(page_data):
	"""Display threat icon with defense recommendations"""
	
	# Add some spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	content_container.add_child(spacer1)
	
	# Threat Icon
	var threat_texture_rect = TextureRect.new()
	threat_texture_rect.custom_minimum_size = Vector2(128, 128)
	threat_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	threat_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load threat texture
	if page_data.threat in threat_textures:
		var texture_path = threat_textures[page_data.threat]
		if ResourceLoader.exists(texture_path):
			threat_texture_rect.texture = load(texture_path)
	
	var threat_container = CenterContainer.new()
	threat_container.add_child(threat_texture_rect)
	content_container.add_child(threat_container)
	
	# Threat Name
	var threat_name_label = Label.new()
	threat_name_label.text = page_data.threat_name
	threat_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if content_font:
		threat_name_label.add_theme_font_override("font", content_font)
	threat_name_label.add_theme_font_size_override("font_size", 28)
	threat_name_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	content_container.add_child(threat_name_label)
	
	# Spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	content_container.add_child(spacer2)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = page_data.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(600, 0)
	if content_font:
		desc_label.add_theme_font_override("font", content_font)
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	content_container.add_child(desc_label)
	
	# Spacing
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 25)
	content_container.add_child(spacer3)
	
	# Defense Recommendation Header
	var defense_header = Label.new()
	defense_header.text = "USE THESE DEFENSES:"
	defense_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if content_font:
		defense_header.add_theme_font_override("font", content_font)
	defense_header.add_theme_font_size_override("font_size", 24)
	defense_header.add_theme_color_override("font_color", Color.LIME_GREEN)
	content_container.add_child(defense_header)
	
	# Spacing
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 15)
	content_container.add_child(spacer4)
	
	# Defense Tools (horizontal layout)
	var defense_hbox = HBoxContainer.new()
	defense_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	defense_hbox.add_theme_constant_override("separation", 30)
	
	for i in range(page_data.defenses.size()):
		var defense_key = page_data.defenses[i]
		var defense_name = page_data.defense_names[i]
		
		# Defense container (vertical: icon + name)
		var defense_vbox = VBoxContainer.new()
		defense_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Defense Icon
		var defense_texture_rect = TextureRect.new()
		defense_texture_rect.custom_minimum_size = Vector2(80, 80)
		defense_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		defense_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if defense_key in defense_textures:
			var texture_path = defense_textures[defense_key]
			if ResourceLoader.exists(texture_path):
				defense_texture_rect.texture = load(texture_path)
		
		defense_vbox.add_child(defense_texture_rect)
		
		# Defense Name
		var defense_label = Label.new()
		defense_label.text = defense_name
		defense_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if content_font:
			defense_label.add_theme_font_override("font", content_font)
		defense_label.add_theme_font_size_override("font_size", 18)
		defense_label.add_theme_color_override("font_color", Color.CYAN)
		defense_vbox.add_child(defense_label)
		
		defense_hbox.add_child(defense_vbox)
	
	content_container.add_child(defense_hbox)

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_page_display()

func _on_next_pressed():
	if current_page < instruction_pages.size() - 1:
		current_page += 1
		update_page_display()

func _on_start_pressed():
	# Hide instruction panel and start game
	visible = false
	
	# Get GameManager and start game
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.start_game()