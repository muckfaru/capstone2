extends Control

# ============================================
# CYBERSECURITY FUNDAMENTALS - TEXT-BASED
# Interactive scenarios instead of diagrams
# ============================================

enum Section {
	INTRO,
	CIA_TRIAD,
	THREAT_MODEL,
	COMPLETE
}

var current_section = Section.INTRO
var xp_earned := 100
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# Node references
@onready var section_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/SectionLabel
@onready var content_label: RichTextLabel = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ContentScroll/ContentLabel
@onready var interaction_panel: VBoxContainer = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/InteractionPanel

@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/NextButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_popup: PanelContainer = $ConfirmOverlay/ConfirmPopup

# CMD typing animation variables
var typing_speed := 0.02
var current_text := ""
var target_text := ""
var typing_tween: Tween = null




func _ready() -> void:
	print("🛡️ Cybersecurity Fundamentals Ready")
	
	# Detect multiplayer game mode
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[GameMode] Running in multiplayer game mode (room: %s)" % _gamemode_room_code)
	
	interaction_panel.visible = false
	
	_setup_cmd_interface()
	_start_section(Section.INTRO)
	
	# Hide close/back button in multiplayer mode
	if _is_gamemode:
		var close_btn = get_node_or_null("WindowDialog/VBox/TitleBar/MarginContainer/HBox/CloseButton")
		if close_btn:
			close_btn.visible = false


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
		
		Section.CIA_TRIAD:
			section_label.text = "The CIA Triad"
			section_text = """[color=#5fd35f]C:\\SECURITY\\CIA>[/color] [color=#ffff99]learn_cia_triad.exe[/color]

[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]
[b]THE CIA TRIAD - 3 CORE SECURITY PRINCIPLES[/b]
[b][color=#5fd35f]═══════════════════════════════════════════[/color][/b]

[color=#55ff55]🔒 CONFIDENTIALITY[/color]
[color=#ffffff]Keeping data SECRET from unauthorized people.[/color]

Examples:
   • Passwords (only you should know them)
   • Medical records (private information)
   • Credit card numbers (financial data)


[color=#5fd35f]──────────────────────────────────────────[/color]

[color=#55ff55]✅ INTEGRITY[/color]
[color=#ffffff]Keeping data ACCURATE and preventing tampering.[/color]

Examples:
   • Bank account balances (must be exact)
   • Software downloads (no malware injected)
   • Medical prescriptions (correct dosage)


[color=#5fd35f]──────────────────────────────────────────[/color]

[color=#55ff55]🌐 AVAILABILITY[/color]
[color=#ffffff]Keeping systems ACCESSIBLE and running when needed.[/color]

Examples:
   • Websites online 24/7
   • Email servers responding quickly
   • Hospital systems during emergencies


[color=#ffff99]Press NEXT to learn about Threat Modeling →[/color]"""
		
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
		
		Section.COMPLETE:
			content_label.visible = true
			section_label.text = "Fundamentals Complete!"
			section_text = """[color=#5fd35f]C:\\CYBERSECURITY>[/color] [color=#ffff99]fundamentals_complete.exe[/color]

[b][color=#55ff55]═══════════════════════════════════════════[/color][/b]
[b]🎉 FUNDAMENTALS COMPLETE![/b]
[b][color=#55ff55]═══════════════════════════════════════════[/color][/b]

[center][color=#ffff00]╔══════════════════════════╗[/color]
[color=#ffff00]║[/color]  [color=#55ff55]⭐ XP EARNED: +%d XP[/color]  [color=#ffff00]║[/color]
[color=#ffff00]╚══════════════════════════╝[/color][/center]

You now understand cybersecurity fundamentals:

[color=#55ff55]✓ CIA Triad:[/color]
   • [b]Confidentiality[/b] (keeping secrets)
   • [b]Integrity[/b] (preventing tampering)
   • [b]Availability[/b] (keeping services running)

[color=#55ff55]✓ Threat Modeling:[/color]
   • [b]Threats[/b] (potential dangers)
   • [b]Vulnerabilities[/b] (weaknesses)
   • [b]Risks[/b] (likelihood × impact)

[color=#5fd35f]──────────────────────────────────────────[/color]

[b]Next up: Practice applying the CIA Triad![/b]

[color=#55ff55]Press NEXT to continue to interactive CIA training →[/color]""" % xp_earned
			next_button.text = "CONTINUE"
			next_button.disabled = false
	
	if not section_text.is_empty():
		_type_text(section_text)



func _on_next_pressed() -> void:
	match current_section:
		Section.INTRO:
			_start_section(Section.CIA_TRIAD)
		Section.CIA_TRIAD:
			_start_section(Section.THREAT_MODEL)
		Section.THREAT_MODEL:
			_start_section(Section.COMPLETE)
		Section.COMPLETE:
			# Check first-time before saving (save marks it complete)
			var _first_clear: bool = MinigameRewards.is_first_completion("beginner_fundamentals")
			# Save progress with XP
			var tutorial_mgr = get_node_or_null("/root/TutorialManager")
			if tutorial_mgr:
				tutorial_mgr.save_tutorial_result("beginner_fundamentals", xp_earned, xp_earned)
				if tutorial_mgr.has_signal("save_completed"):
					await tutorial_mgr.save_completed
				await get_tree().process_frame
			# Show reward popup on first completion
			if _first_clear and not _is_gamemode:
				MinigameRewards.try_grant_rewards("beginner_fundamentals", xp_earned, xp_earned, self)
			# Always transition to CIA Triad interactive game
			# (tutorial_cia_triad.gd has its own GameMode support and will
			#  handle score submission after the player completes the game)
			get_tree().change_scene_to_file("res://scene/tutorial_cia_triad.tscn")


func _on_back_pressed() -> void:
	match current_section:
		Section.INTRO:
			if _is_gamemode:
				return  # Cannot quit during multiplayer game
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Section.CIA_TRIAD:
			_start_section(Section.INTRO)
		Section.THREAT_MODEL:
			_start_section(Section.CIA_TRIAD)
		Section.COMPLETE:
			_start_section(Section.THREAT_MODEL)


func _on_close_button_pressed() -> void:
	if _is_gamemode:
		return  # Cannot quit during multiplayer game
	confirm_overlay.visible = true
	confirm_popup.scale = Vector2.ZERO
	confirm_popup.pivot_offset = confirm_popup.size / 2
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(confirm_popup, "scale", Vector2.ONE, 0.3)


func _on_confirm_yes_pressed() -> void:
	if _is_gamemode:
		return
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _on_confirm_no_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(confirm_popup, "scale", Vector2.ZERO, 0.2)
	await tween.finished
	confirm_overlay.visible = false


func _submit_gamemode_score() -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": xp_earned,
		"max_score": xp_earned,
		"time_taken_ms": time_taken_ms
	})
	
	next_button.disabled = true
	next_button.text = "Submitting..."
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Score submitted: %d (time: %dms) → status %d" % [xp_earned, time_taken_ms, code])
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")
