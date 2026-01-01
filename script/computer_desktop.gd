extends Control

var game_state = "desktop"
var chat_shown = false
var popups = []
var active_tweens = []
var search_tutorial_shown = false
var download_started = false

# Built-in dialogue system variables
var dialogue_active = false
var dialogue_lines = []
var current_dialogue_index = 0
var typing_active = false
var current_char_index = 0
var typing_speed = 0.03
var dialogue_box_ui = null
var dialogue_text_label = null
var dialogue_continue_indicator = null
var dialogue_name_label = null
var popup_sfx_player: AudioStreamPlayer
var popup_sound: AudioStream = preload("res://asset/audio/sfx/popup_warning.mp3")



var button_sfx_player: AudioStreamPlayer
var typing_sfx_player: AudioStreamPlayer
var error_sfx_player: AudioStreamPlayer
var download_sfx_player: AudioStreamPlayer


@export var button_click_sound: AudioStream
@export var typing_sound: AudioStream
@export var error_sound: AudioStream
@export var download_complete_sound: AudioStream

func _ready():

	popup_sfx_player = AudioStreamPlayer.new()
	popup_sfx_player.name = "PopupSFXPlayer"
	popup_sfx_player.volume_db = -10.0  # Adjust volume as needed
	add_child(popup_sfx_player)

	button_sfx_player = AudioStreamPlayer.new()
	button_sfx_player.name = "ButtonSFXPlayer"
	button_sfx_player.volume_db = -8.0
	add_child(button_sfx_player)
	
	typing_sfx_player = AudioStreamPlayer.new()
	typing_sfx_player.name = "TypingSFXPlayer"
	typing_sfx_player.volume_db = -10.0
	add_child(typing_sfx_player)
	
	error_sfx_player = AudioStreamPlayer.new()
	error_sfx_player.name = "ErrorSFXPlayer"
	error_sfx_player.volume_db = -3.0
	add_child(error_sfx_player)
	
	download_sfx_player = AudioStreamPlayer.new()
	download_sfx_player.name = "DownloadSFXPlayer"
	download_sfx_player.volume_db = -5.0
	add_child(download_sfx_player)

	# Set this control to fill the entire screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Connect button signals
	$Desktop/IconBrowser.pressed.connect(_on_browser_clicked)
	$Desktop/IconMessages.pressed.connect(_on_messages_clicked)
	$Desktop/IconFiles.pressed.connect(_on_files_clicked)
	$Taskbar/ExitButton.pressed.connect(_on_exit_clicked)
	
	# Browser window controls
	if has_node("WindowBrowser"):
		$WindowBrowser/TitleBar/CloseBtn.pressed.connect(_on_browser_close)
		$WindowBrowser/SearchButton.pressed.connect(_on_search_clicked)
		$WindowBrowser/AddressBar.text_submitted.connect(_on_search_submitted)
	
	# Messages window controls
	if has_node("WindowMessages"):
		$WindowMessages/TitleBar/CloseBtn.pressed.connect(_on_messages_close)
	
	update_time()
	
	# Create dialogue UI FIRST
	create_dialogue_ui()
	
	# Wait for everything to be ready
	await get_tree().process_frame
	
	print("Computer Desktop Ready!")
	
	# Start dialogue sequence after a delay
	await get_tree().create_timer(1.5).timeout
	
	# Check game state and show appropriate dialogue
	if GlobalState.joined_ca_organization and not GlobalState.ca_training_completed:
		# Player joined CA - show training mission
		start_ca_training_sequence()
	elif not GlobalState.has_opened_computer_before:
		# First time opening computer - original tutorial
		print("First time opening computer")
		GlobalState.has_opened_computer_before = true
		start_dialogue([
			"Alright, I'm on my computer now.",
			"Let me see if I can find that game somewhere...",
			"First, let me check if anyone sent me a link."
		])
		await dialogue_finished()
		await get_tree().create_timer(0.5).timeout
		start_tutorial()
	else:
		# Returning to computer after infection (if not joined CA yet)
		start_tutorial()

func create_dialogue_ui():
	print("Creating dialogue UI...")
	
	# Create dialogue box UI
	dialogue_box_ui = Panel.new()
	dialogue_box_ui.name = "DialogueBox"
	dialogue_box_ui.z_index = 1000
	
	# Position at bottom of screen
	dialogue_box_ui.anchor_left = 0.0
	dialogue_box_ui.anchor_top = 1.0
	dialogue_box_ui.anchor_right = 1.0
	dialogue_box_ui.anchor_bottom = 1.0
	dialogue_box_ui.offset_left = 50
	dialogue_box_ui.offset_top = -180
	dialogue_box_ui.offset_right = -50
	dialogue_box_ui.offset_bottom = -20
	dialogue_box_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue_box_ui.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	dialogue_box_ui.visible = false
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 1, 1, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialogue_box_ui.add_theme_stylebox_override("panel", style)
	
	# Create text container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_box_ui.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Character name label
	dialogue_name_label = Label.new()
	dialogue_name_label.name = "NameLabel"
	dialogue_name_label.text = "You"
	dialogue_name_label.add_theme_font_size_override("font_size", 20)
	dialogue_name_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	vbox.add_child(dialogue_name_label)
	
	# Dialogue text
	dialogue_text_label = Label.new()
	dialogue_text_label.name = "DialogueText"
	dialogue_text_label.add_theme_font_size_override("font_size", 18)
	dialogue_text_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(dialogue_text_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Continue indicator
	dialogue_continue_indicator = Label.new()
	dialogue_continue_indicator.name = "ContinueIndicator"
	dialogue_continue_indicator.text = "▼ PRESS SPACE"
	dialogue_continue_indicator.add_theme_font_size_override("font_size", 14)
	dialogue_continue_indicator.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	dialogue_continue_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_continue_indicator.visible = false
	vbox.add_child(dialogue_continue_indicator)
	
	add_child(dialogue_box_ui)
	
	print("Dialogue UI created successfully!")

# ============================================
# CA TRAINING SEQUENCE
# ============================================

func start_ca_training_sequence():
	print("Starting CA training sequence...")
	
	# Agent Reeves gives training instructions
	start_dialogue_with_name([
		"Welcome back, recruit.",
		"Your computer has been fully restored and secured.",
		"Now it's time for your first mission.",
		"I've registered you for CyberArena - our training platform.",
		"You need to create your operative username and complete the tutorial."
	], "Anonymouse")
	await dialogue_finished()
	
	await get_tree().create_timer(0.5).timeout
	
	start_dialogue_with_name([
		"I'm redirecting you to the registration portal now.",
		"Create your operative username carefully - this will be your identity.",
		"I'll see you on the other side, recruit. Good luck."
	], "Anonymouse")
	await dialogue_finished()
	
	# Mark training as complete and transition to username creation
	GlobalState.ca_training_completed = true
	
	await get_tree().create_timer(1.5).timeout
	print("✅ CA Training complete! Transitioning to username creation...")
	get_tree().change_scene_to_file("res://scene/intro_scene.tscn")

func start_dialogue_with_name(lines: Array, character_name: String):
	dialogue_lines = lines
	current_dialogue_index = 0
	dialogue_active = true
	
	if dialogue_box_ui:
		dialogue_box_ui.visible = true
		dialogue_box_ui.z_index = 1000
		
		# Set character name and color
		if dialogue_name_label:
			dialogue_name_label.text = character_name
			dialogue_name_label.visible = true
			
			# Color code based on character
			if character_name == "Anonymouse":
				dialogue_name_label.add_theme_color_override("font_color", Color(1, 0.5, 0))  # Orange
			elif character_name == "You":
				dialogue_name_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))  # Green
			else:
				dialogue_name_label.add_theme_color_override("font_color", Color(0, 1, 1))  # Cyan
		
		print("Dialogue box is now visible")
	else:
		print("ERROR: dialogue_box_ui is null!")
		return
	
	show_current_line()

func start_dialogue(lines: Array):
	start_dialogue_with_name(lines, "You")

func show_current_line():
	if current_dialogue_index >= dialogue_lines.size():
		end_dialogue()
		return
	
	print("Showing line ", current_dialogue_index, ": ", dialogue_lines[current_dialogue_index])
	
	dialogue_continue_indicator.visible = false
	typing_active = true
	current_char_index = 0
	dialogue_text_label.text = ""
	type_next_character()

func type_next_character():
	if current_char_index < dialogue_lines[current_dialogue_index].length():
		play_typing_sound()
		dialogue_text_label.text += dialogue_lines[current_dialogue_index][current_char_index]
		current_char_index += 1
		await get_tree().create_timer(typing_speed).timeout
		if typing_active:
			type_next_character()
	else:
		finish_typing()

func finish_typing():
	typing_active = false
	dialogue_text_label.text = dialogue_lines[current_dialogue_index]
	dialogue_continue_indicator.visible = true
	print("Line finished typing")

func advance_dialogue():
	if typing_active:
		print("Skipping typing animation")
		typing_active = false
		finish_typing()
	else:
		print("Advancing to next line")
		current_dialogue_index += 1
		show_current_line()

func end_dialogue():
	print("Dialogue ended")
	dialogue_active = false
	if dialogue_box_ui:
		dialogue_box_ui.visible = false
	dialogue_lines.clear()

func dialogue_finished():
	while dialogue_active:
		await get_tree().create_timer(0.1).timeout

func _input(event):
	if dialogue_active:
		if event is InputEventKey:
			if (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and event.pressed:
				print("Space/Enter pressed during dialogue")
				advance_dialogue()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				print("Mouse clicked during dialogue")
				advance_dialogue()

# ============================================
# ORIGINAL TUTORIAL (First time on computer)
# ============================================

func start_tutorial():
	print("Starting tutorial")
	start_dialogue([
		"Alright, let me check my messages first.",
		"Maybe someone shared a link to the game..."
	])
	await dialogue_finished()
	print("Tutorial dialogue finished, highlighting messages")
	highlight_icon($Desktop/IconMessages)

func highlight_icon(icon_button):
	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(icon_button, "modulate:a", 0.5, 0.5)
	tween.tween_property(icon_button, "modulate:a", 1.0, 0.5)
	active_tweens.append(tween)

func stop_all_highlights():
	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()
	
	if has_node("Desktop/IconBrowser"):
		$Desktop/IconBrowser.modulate.a = 1.0
	if has_node("Desktop/IconMessages"):
		$Desktop/IconMessages.modulate.a = 1.0
	if has_node("Desktop/IconFiles"):
		$Desktop/IconFiles.modulate.a = 1.0

func update_time():
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var am_pm = "AM"
	if hour >= 12:
		am_pm = "PM"
		if hour > 12:
			hour -= 12
	if hour == 0:
		hour = 12
	$Taskbar/TimeLabel.text = "%d:%02d %s" % [hour, time.minute, am_pm]

# ============================================
# ICON CLICK HANDLERS
# ============================================

func _on_browser_clicked():
	play_button_sound()
	stop_all_highlights()
	
	if has_node("WindowBrowser"):
		$WindowBrowser.visible = true
		$WindowBrowser/AddressBar.text = ""
		clear_search_results()
		
		# Check if CA training mission
		if GlobalState.joined_ca_organization and not GlobalState.ca_training_completed:
			# Show hint for cyberarena.com
			await get_tree().create_timer(0.5).timeout
			start_dialogue_with_name([
				"Remember: Go to cyberarena.com to start your training."
			], "Anonymouse")
		elif not search_tutorial_shown:
			search_tutorial_shown = true
			await get_tree().create_timer(0.5).timeout
			start_dialogue([
				"Try searching for 'free games' or 'cyberrun free download'."
			])

func _on_messages_clicked():
	play_button_sound()
	stop_all_highlights()
	
	# Don't allow messages during CA training
	if GlobalState.joined_ca_organization and not GlobalState.ca_training_completed:
		start_dialogue_with_name([
			"Focus on your mission, recruit.",
			"Check your messages later."
		], "Anonymouse")
		return
	
	if has_node("WindowMessages"):
		$WindowMessages.visible = true
		if not chat_shown:
			chat_shown = true
			load_chat_messages()
			
			await get_tree().create_timer(3.0).timeout
			show_after_messages_dialogue()

func _on_files_clicked():
	stop_all_highlights()
	show_message("Just some school files and photos...")

func show_after_messages_dialogue():
	stop_all_highlights()
	
	start_dialogue([
		"Man, they're all having so much fun...",
		"I need to find a way to get this game.",
		"Let me search online for a free download."
	])
	await dialogue_finished()
	
	$WindowMessages.visible = false
	highlight_icon($Desktop/IconBrowser)

func _on_browser_close():
	if has_node("WindowBrowser"):
		$WindowBrowser.visible = false

func _on_messages_close():
	if has_node("WindowMessages"):
		$WindowMessages.visible = false

func _on_exit_clicked():
	stop_all_highlights()
	
	# If CA training is complete and no username yet, go to intro scene
	if GlobalState.ca_training_completed and (Auth.current_username == "" or Auth.current_username == null):
		print("✅ Training done, going to username creation...")
		get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
	else:
		# Otherwise go back to main room
		get_tree().change_scene_to_file("res://scene/Main.tscn")

# ============================================
# SEARCH FUNCTIONALITY
# ============================================

func _on_search_clicked():
	play_button_sound()
	if has_node("WindowBrowser"):
		perform_search($WindowBrowser/AddressBar.text)

func _on_search_submitted(text):
	perform_search(text)

func perform_search(query: String):
	clear_search_results()
	
	if has_node("WindowBrowser/ContentArea/SearchResults"):
		$WindowBrowser/ContentArea/SearchResults.add_theme_constant_override("separation", 15)
	
	# Check if searching for CyberArena (CA training mission)
	if GlobalState.joined_ca_organization and not GlobalState.ca_training_completed:
		if query.to_lower().contains("cyberarena") or query.to_lower() == "cyberarena.com":
			# Found the correct site!
			add_ca_training_result()
			return
		else:
			add_search_result("No results found", "", "Try searching for 'cyberarena.com'", false)
			return
	
	# Original search logic (for free game download)
	if query.to_lower().contains("free") and (query.to_lower().contains("game") or query.to_lower().contains("cyberrun")):
		add_search_result("CyberRun 2024 - Official Store", "https://officialgamestore.com", "₱1,000 - Official download with updates and support", false)
		add_search_result("⚠️ FREE GAMES DOWNLOAD - CyberRun 2024", "http://freegamesdownload123.xyz", "Download CyberRun 2024 FREE! No payment needed! CLICK HERE!", true)
		add_search_result("GameShare Forum - CyberRun Discussion", "https://gameshare.com/cyberrun", "Users discussing the game. Mixed reviews on third-party sites.", false)
	else:
		add_search_result("No results found", "", "Try searching for 'free game download' or 'cyberrun free'", false)

func add_ca_training_result():
	if not has_node("WindowBrowser/ContentArea/SearchResults"):
		return
	
	var result_panel = Panel.new()
	result_panel.custom_minimum_size = Vector2(0, 200)
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	result_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "🛡️ CyberArena - Official CA Training Platform"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0, 1, 0))  # Green - safe
	vbox.add_child(title_label)
	
	var url_label = Label.new()
	url_label.text = "https://cyberarena.com"
	url_label.add_theme_color_override("font_color", Color.DARK_GREEN)
	url_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(url_label)
	
	var desc_label = Label.new()
	desc_label.text = "Official Cyber Anomaly Organization training platform. Create your operative profile and begin your cybersecurity training."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)
	
	var enter_btn = Button.new()
	enter_btn.text = "✓ ENTER CYBERARENA"
	enter_btn.custom_minimum_size = Vector2(200, 40)
	enter_btn.pressed.connect(_on_cyberarena_clicked)
	vbox.add_child(enter_btn)
	
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(bottom_spacer)
	
	$WindowBrowser/ContentArea/SearchResults.add_child(result_panel)

func _on_cyberarena_clicked():
	print("Loading CyberArena registration...")
	
	# Store tree reference
	var tree = get_tree()
	if not tree:
		return
	
	# Show message WITHOUT dialogue system (instant)
	if dialogue_box_ui:
		dialogue_box_ui.visible = true
		dialogue_name_label.text = "Anonymouse"
		dialogue_name_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
		dialogue_text_label.text = "Perfect. Loading CyberArena...\nCreate your username carefully. This will be your operative ID."
		dialogue_continue_indicator.visible = false
	
	# Wait and transition
	await tree.create_timer(2.0).timeout
	
	if dialogue_box_ui:
		dialogue_box_ui.visible = false
	
	if not is_inside_tree():
		return
	
	print("Changing to intro_scene.tscn...")
	tree.change_scene_to_file("res://scene/intro_scene.tscn")

func clear_search_results():
	if has_node("WindowBrowser/ContentArea/SearchResults"):
		for child in $WindowBrowser/ContentArea/SearchResults.get_children():
			child.queue_free()

func add_search_result(title: String, url: String, description: String, is_suspicious: bool):
	if not has_node("WindowBrowser/ContentArea/SearchResults"):
		return
	
	var result_panel = Panel.new()
	result_panel.custom_minimum_size = Vector2(0, 200)
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	result_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	if is_suspicious:
		title_label.add_theme_color_override("font_color", Color.RED)
	else:
		title_label.add_theme_color_override("font_color", Color.DODGER_BLUE)
	vbox.add_child(title_label)
	
	var url_label = Label.new()
	url_label.text = url
	url_label.add_theme_color_override("font_color", Color.DARK_GREEN)
	url_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(url_label)
	
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)
	
	var download_btn = Button.new()
	download_btn.text = "Visit Site" if not is_suspicious else "⚠️ DOWNLOAD FREE"
	download_btn.custom_minimum_size = Vector2(200, 40)
	download_btn.pressed.connect(func():
		if not download_started:
			download_btn.disabled = true
			_on_download_clicked(is_suspicious)
	)
	vbox.add_child(download_btn)
	
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(bottom_spacer)
	
	$WindowBrowser/ContentArea/SearchResults.add_child(result_panel)

# ============================================
# INFECTION SEQUENCE (Original game flow)
# ============================================

func _on_download_clicked(is_suspicious: bool):
	if download_started:
		return
		
	if is_suspicious:
		download_started = true
		show_download_warning()
	else:
		show_message("This would take you to the official store.\n(Outside the scope of this demo)")

func show_download_warning():
	start_dialogue([
		"Found it I hope it's safe to download...",
		"I always get free games from this site, I think it's fine.",
		"Let me just download it real quick...",
		
	])
	await dialogue_finished()
	start_infection_sequence()

func start_infection_sequence():
	stop_all_highlights()
	game_state = "infected"
	
	if has_node("WindowBrowser"):
		$WindowBrowser.visible = false
	
	show_fake_loading()
	await get_tree().create_timer(4.0).timeout
	spawn_malware_popups()

func show_fake_loading():
	var loading_overlay = ColorRect.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.color = Color(0, 0, 0, 0.8)
	loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay.z_index = 500
	add_child(loading_overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-200, -50)
	vbox.size = Vector2(400, 100)
	vbox.add_theme_constant_override("separation", 20)
	loading_overlay.add_child(vbox)
	
	var loading_label = Label.new()
	loading_label.text = "Downloading CyberRun2026_Free.exe..."
	loading_label.add_theme_font_size_override("font_size", 24)
	loading_label.add_theme_color_override("font_color", Color.WHITE)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(loading_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(400, 30)
	progress_bar.value = 0
	vbox.add_child(progress_bar)
	
	var percent_label = Label.new()
	percent_label.text = "0%"
	percent_label.add_theme_font_size_override("font_size", 18)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(percent_label)
	
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100, 3.5)
	
	for i in range(101):
		await get_tree().create_timer(0.035).timeout
		percent_label.text = str(i) + "%"
		if i == 100:
			play_download_complete()

func spawn_malware_popups():
	var popup_messages = [
		"⚠️ VIRUS DETECTED!\nClick here to remove!",
		"🎉 CONGRATULATIONS!\nYou've won $1000!",
		"⚠️ YOUR COMPUTER IS AT RISK!\nInstall AntiVirus NOW!",
		"💰 EARN MONEY FAST!\nClick here to learn how!",
		"🔒 YOUR FILES ARE ENCRYPTED!\nPay ransom to unlock!",
		"⚠️ SYSTEM ERROR!\nYour data is being stolen!",
		"🚨 MALWARE ALERT!\nImmediate action required!"
	]
	
	for i in range(7):
		await get_tree().create_timer(0.3).timeout
		create_popup_window(popup_messages[i], i)
	
	await get_tree().create_timer(3.0).timeout
	show_infection_result()

func create_popup_window(message: String, index: int):
	play_popup_sound()
	var popup = Panel.new()
	popup.custom_minimum_size = Vector2(300, 150)
	popup.z_index = 600 + index
	
	var rand_x = randf_range(100, get_viewport_rect().size.x - 400)
	var rand_y = randf_range(100, get_viewport_rect().size.y - 250)
	popup.position = Vector2(rand_x, rand_y)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.RED
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	vbox.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	margin.add_child(inner_vbox)
	
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner_vbox.add_child(msg_label)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(popup.queue_free)
	popup.add_child(close_btn)
	close_btn.position = Vector2(popup.custom_minimum_size.x - 35, 5)
	
	add_child(popup)
	popups.append(popup)
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(popup, "position:x", popup.position.x + 5, 0.1)
	tween.tween_property(popup, "position:x", popup.position.x - 5, 0.1)

func show_infection_result():
	stop_all_highlights()
	
	for popup in popups:
		if is_instance_valid(popup):
			popup.queue_free()
	
	if has_node("LoadingOverlay"):
		$LoadingOverlay.queue_free()
	
	show_shutdown_animation()

func show_shutdown_animation():
	var shutdown_overlay = ColorRect.new()
	shutdown_overlay.name = "ShutdownOverlay"
	shutdown_overlay.color = Color(0.067, 0.318, 0.612, 1)
	shutdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shutdown_overlay.z_index = 2000
	add_child(shutdown_overlay)
	
	var loading_circle = TextureRect.new()
	loading_circle.name = "LoadingCircle"
	loading_circle.texture = preload("res://asset/icons/loading.png")
	loading_circle.custom_minimum_size = Vector2(128, 128)
	loading_circle.set_anchors_preset(Control.PRESET_CENTER)
	loading_circle.position = Vector2(-64, -120)
	loading_circle.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	loading_circle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shutdown_overlay.add_child(loading_circle)
	
	var message_label = Label.new()
	message_label.text = "Shutting down..."
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position = Vector2(-150, 50)
	message_label.size = Vector2(300, 40)
	shutdown_overlay.add_child(message_label)
	
	await get_tree().create_timer(2.0).timeout
	
	var fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 3000
	add_child(fade_overlay)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 1.0)
	
	await fade_tween.finished
	await get_tree().create_timer(0.5).timeout
	
	GlobalState.returning_from_computer = true
	GlobalState.computer_infected = true
	
	get_tree().change_scene_to_file("res://scene/Main.tscn")

func load_chat_messages():
	add_message("Mark", "Bro have you played CyberRun 2026 yet?!", "2:30 PM")
	add_message("Sarah", "It's so good! Already level 15!", "2:31 PM")
	add_message("Mark", "Costs 1000 pesos though 😅", "2:32 PM")
	add_message("Sarah", "Worth every peso IMO", "2:33 PM")
	add_message("You", "I really want to play but don't have the money...", "2:34 PM")
	add_message("Mark", "Maybe wait for a sale? 🤔", "2:35 PM")

func add_message(sender: String, text: String, time: String):
	if not has_node("WindowMessages/ChatArea/ChatMessages"):
		return
	
	var msg_container = HBoxContainer.new()
	msg_container.custom_minimum_size = Vector2(0, 60)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sender_label = Label.new()
	sender_label.text = sender + " - " + time
	sender_label.add_theme_font_size_override("font_size", 12)
	sender_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(sender_label)
	
	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text_label)
	
	msg_container.add_child(vbox)
	$WindowMessages/ChatArea/ChatMessages.add_child(msg_container)

func show_message(text: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()


func play_popup_sound():
	if popup_sound and popup_sfx_player:
		# Stop current sound to allow rapid-fire popups
		if popup_sfx_player.playing:
			popup_sfx_player.stop()
		
		popup_sfx_player.stream = popup_sound
		popup_sfx_player.pitch_scale = randf_range(0.95, 1.05)  # Slight variation
		popup_sfx_player.play()

func play_button_sound():
	if button_click_sound and button_sfx_player:
		button_sfx_player.stream = button_click_sound
		button_sfx_player.pitch_scale = randf_range(0.98, 1.02)
		button_sfx_player.play()

func play_typing_sound():
	if typing_sound and typing_sfx_player:
		if not typing_sfx_player.playing:
			typing_sfx_player.stream = typing_sound
			typing_sfx_player.play()

func play_error_sound():
	if error_sound and error_sfx_player:
		error_sfx_player.stream = error_sound
		error_sfx_player.play()

func play_download_complete():
	if download_complete_sound and download_sfx_player:
		download_sfx_player.stream = download_complete_sound
		download_sfx_player.play()