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

func _ready():
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
	
	print("Starting dialogue...")
	
	if not GlobalState.has_opened_computer_before:
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
		print("Returning to computer")
		start_tutorial()

func create_dialogue_ui():
	print("Creating dialogue UI...")
	
	# Create dialogue box UI
	dialogue_box_ui = Panel.new()
	dialogue_box_ui.name = "DialogueBox"
	dialogue_box_ui.z_index = 1000  # Make sure it's on top
	
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
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "You"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	vbox.add_child(name_label)
	
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

func start_dialogue(lines: Array):
	print("Starting dialogue with ", lines.size(), " lines")
	dialogue_lines = lines
	current_dialogue_index = 0
	dialogue_active = true
	
	if dialogue_box_ui:
		dialogue_box_ui.visible = true
		dialogue_box_ui.z_index = 1000  # Ensure it's on top
		print("Dialogue box is now visible")
	else:
		print("ERROR: dialogue_box_ui is null!")
		return
	
	show_current_line()

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
		dialogue_text_label.text += dialogue_lines[current_dialogue_index][current_char_index]
		current_char_index += 1
		await get_tree().create_timer(typing_speed).timeout
		if typing_active:  # Check if not skipped
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
		# Skip typing animation
		print("Skipping typing animation")
		typing_active = false
		finish_typing()
	else:
		# Move to next line
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
	# Wait until dialogue is done
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

func _on_browser_clicked():
	stop_all_highlights()
	
	if has_node("WindowBrowser"):
		$WindowBrowser.visible = true
		$WindowBrowser/AddressBar.text = ""
		clear_search_results()
		
		if not search_tutorial_shown:
			search_tutorial_shown = true
			await get_tree().create_timer(0.5).timeout
			start_dialogue([
				"Try searching for 'free games' or 'cyberrun free download'."
			])

func _on_messages_clicked():
	stop_all_highlights()
	
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
	get_tree().change_scene_to_file("res://scene/Main.tscn")

func _on_search_clicked():
	if has_node("WindowBrowser"):
		perform_search($WindowBrowser/AddressBar.text)

func _on_search_submitted(text):
	perform_search(text)

func perform_search(query: String):
	clear_search_results()
	
	if has_node("WindowBrowser/ContentArea/SearchResults"):
		$WindowBrowser/ContentArea/SearchResults.add_theme_constant_override("separation", 15)
	
	if query.to_lower().contains("free") and (query.to_lower().contains("game") or query.to_lower().contains("cyberrun")):
		add_search_result("CyberRun 2024 - Official Store", "https://officialgamestore.com", "₱1,000 - Official download with updates and support", false)
		add_search_result("⚠️ FREE GAMES DOWNLOAD - CyberRun 2024", "http://freegamesdownload123.xyz", "Download CyberRun 2024 FREE! No payment needed! CLICK HERE!", true)
		add_search_result("GameShare Forum - CyberRun Discussion", "https://gameshare.com/cyberrun", "Users discussing the game. Mixed reviews on third-party sites.", false)
	else:
		add_search_result("No results found", "", "Try searching for 'free game download' or 'cyberrun free'", false)

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
		"Hmm, this site looks a bit sketchy...",
		"But it's free! What could go wrong?",
		"Let me just download it real quick..."
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
	loading_label.text = "Downloading CyberRun2024_Free.exe..."
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
	add_message("Mark", "Bro have you played CyberRun 2024 yet?!", "2:30 PM")
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