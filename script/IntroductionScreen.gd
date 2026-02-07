extends Node2D

var current_page = 0
var total_pages = 4

@onready var page_title = $CanvasLayer/ContentPanel/MarginContainer/VBox/PageContainer/PageTitle
@onready var page_content = $CanvasLayer/ContentPanel/MarginContainer/VBox/PageContainer/PageContent
@onready var prev_button = $CanvasLayer/ContentPanel/MarginContainer/VBox/ButtonContainer/PrevButton
@onready var next_button = $CanvasLayer/ContentPanel/MarginContainer/VBox/ButtonContainer/NextButton
@onready var page_indicator = $CanvasLayer/ContentPanel/MarginContainer/VBox/ButtonContainer/PageIndicator
@onready var start_button = $CanvasLayer/ContentPanel/MarginContainer/VBox/StartButton

var pages = []

func _ready():
	setup_pages()
	show_page(0)

func setup_pages():
	pages = [
		# Page 0: Introduction
		{
			"title": "What is Cybersecurity?",
			"content": """[center]Cybersecurity protects computers, networks, and data from digital attacks.

In this game, you'll learn about [color=#00ff66]TWO main types of security[/color]:[/center]

[color=#5599ff]📁 DATA SECURITY[/color] - Protects information and files
[color=#ff5544]🌐 NETWORK SECURITY[/color] - Protects connections and traffic

[center]Let's learn about each one![/center]"""
		},
		
		# Page 1: DATA Security
		{
			"title": "📁 DATA SECURITY",
			"content": """[center][color=#5599ff]DATA Security protects INFORMATION stored on computers.[/color][/center]

[b]What is DATA?[/b]
• Files, documents, and databases
• Passwords and login credentials
• Photos, videos, and personal information
• Customer records and financial data

[b]Common DATA attacks:[/b]
[color=#ff4444]🔒 Ransomware[/color] - Locks your files and demands payment
[color=#ff4444]🦠 Viruses[/color] - Infect and steal data from your computer
[color=#ff4444]🔑 Password Theft[/color] - Steals login credentials
[color=#ff4444]💉 SQL Injection[/color] - Tricks databases to reveal information

[center][b]Remember: If it attacks FILES or INFORMATION, it's DATA security![/b][/center]"""
		},
		
		# Page 2: NETWORK Security
		{
			"title": "🌐 NETWORK SECURITY",
			"content": """[center][color=#ff5544]NETWORK Security protects CONNECTIONS between computers.[/color][/center]

[b]What is a NETWORK?[/b]
• Internet connections and WiFi
• Communication between devices
• Email and messaging traffic
• Website access and downloads

[b]Common NETWORK attacks:[/b]
[color=#ff4444]💥 DDoS[/color] - Floods servers with fake traffic
[color=#ff4444]📡 WiFi Jamming[/color] - Blocks wireless signals
[color=#ff4444]👤 Man-in-the-Middle[/color] - Eavesdrops on connections
[color=#ff4444]🎭 DNS Spoofing[/color] - Redirects you to fake websites

[center][b]Remember: If it attacks CONNECTIONS or TRAFFIC, it's NETWORK security![/b][/center]"""
		},
		
		# Page 3: How to Play
		{
			"title": "🎮 How to Play",
			"content": """[center][b][color=#ffff44]Your Mission: Sort Cyber Attacks![/color][/b][/center]

[b]1. Attack Cards Will Appear[/b]
   Each card shows a different cyber attack with a countdown timer.

[b]2. Drag Cards to the Correct Zone[/b]
   [color=#5599ff]📁 DATA Zone[/color] - For attacks targeting files and information
   [color=#ff5544]🌐 NETWORK Zone[/color] - For attacks targeting connections

[b]3. Watch the CIA Triad[/b]
   Wrong answers damage your system health:
   • [color=#5599ff]C[/color]onfidentiality - Information secrecy
   • [color=#ffaa44]I[/color]ntegrity - Data accuracy
   • [color=#44ff44]A[/color]vailability - System uptime

[b]4. Complete All Waves[/b]
   Survive increasingly difficult waves of attacks!

[center][color=#00ff66]Think carefully! Speed and accuracy both matter![/color][/center]"""
		}
	]

func show_page(page_index: int):
	current_page = page_index
	
	var page_data = pages[page_index]
	page_title.text = page_data.title
	page_content.text = page_data.content
	
	# Update page indicator
	page_indicator.text = "Page %d of %d" % [current_page + 1, total_pages]
	
	# Update button states
	prev_button.disabled = (current_page == 0)
	
	if current_page < total_pages - 1:
		next_button.visible = true
		start_button.visible = false
	else:
		next_button.visible = false
		start_button.visible = true

func _on_prev_button_pressed():
	if current_page > 0:
		show_page(current_page - 1)

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		show_page(current_page + 1)

func _on_start_button_pressed():
	# Transition to the main game
	get_tree().change_scene_to_file("res://scene/DataVsNetwork.tscn")

func _input(event):
	# Allow skipping with ESC key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")