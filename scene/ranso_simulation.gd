# Save this as: ranso_simulation.gd
extends Node2D

var documents_window = null
var image_viewer_window = null
var ransomware_window = null
var files_encrypted = false  # Track if files are encrypted
var calculator_window = null
var computer_icon = null
var taskmanager_icon = null
var documents_icon = null
var calculator_icon = null
var legitgame_icon = null
# Add these with your other variables at the top
var dragging_window = null
var drag_offset = Vector2.ZERO
var mrmeow_icon = null
var hint_button = null  # ADD THIS LINE
var documents_opened = false  # ADD THIS LINE

# Sample file data
var documents_files = [
	{"name": "Mr Meow.jpg", "type": "image", "icon": "📷"},
	{"name": "lol.jpg", "type": "image", "icon": "📷"},
	{"name": "funny.jpg", "type": "image", "icon": "📷"},
	{"name": "list.txt", "type": "text", "icon": "📄"}
]

# Countdown timers
var payment_time = 259257  # 2 days, 23 hours, 59 minutes, 57 seconds
var deletion_time = 604737  # 6 days, 23 hours, 59 minutes, 57 seconds

func _ready():
	# Load icon textures
	computer_icon = load("res://asset/icons/computericon.png")
	taskmanager_icon = load("res://asset/icons/taskmanagericon-1.png")
	documents_icon = load("res://asset/icons/filesicon.png")
	calculator_icon = load("res://asset/icons/calculatoricon-4.png")
	legitgame_icon = load("res://asset/icons/Flying Windows-1.png")
	mrmeow_icon = load("res://asset/icons/mrmeowjpgicon.jpg")

	create_hint_button()
	setup_icon_interactions()
	show_introduction()

func _process(delta):
	# Update countdown timers if ransomware is active
	if ransomware_window != null:
		payment_time -= delta
		deletion_time -= delta
		update_countdown_timers()

func make_window_draggable(window: Panel, title_bar: Panel):
	title_bar.gui_input.connect(_on_titlebar_input.bind(window))
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_titlebar_input(event: InputEvent, window: Panel):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				dragging_window = window
				drag_offset = event.position
			else:
				# Stop dragging
				dragging_window = null
	
	elif event is InputEventMouseMotion:
		if dragging_window == window:
			# Update window position
			window.position += event.relative

func _input(event: InputEvent):
	if event is InputEventMouseMotion and dragging_window != null:
		dragging_window.position += event.relative

func create_hint_button():
	hint_button = Button.new()
	hint_button.text = "? Hint"
	hint_button.position = Vector2(1050, 10)  # TOP-RIGHT CORNER (changed from 10, 10)
	hint_button.size = Vector2(80, 35)
	hint_button.z_index = 100  # Always on top
	
	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.5, 0.8, 0.9)  # Blue background
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	hint_button.add_theme_stylebox_override("normal", btn_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0, 0.6, 1, 1)  # Lighter blue on hover
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hint_button.add_theme_stylebox_override("hover", hover_style)
	
	hint_button.add_theme_color_override("font_color", Color.WHITE)
	hint_button.add_theme_font_size_override("font_size", 14)
	
	# Connect to show introduction when clicked
	hint_button.pressed.connect(show_introduction)
	
	add_child(hint_button)



func show_introduction():
	
	show_info_screen("Introduction", 
		"C:\\> RANSOMWARE SIMULATION\n==============================\n\n>> INTRODUCTION\n\nThis demonstration will guide you through a simulated ransomware attack.\n\nBefore activating the malware, take a look through the documents and programs on this simulated desktop environment.\n\nFirst, double click on the documents folder and look through some of the text and image files.\n\n[color=#ffff00]>> REMEMBER: This is only a simulation for educational purposes.[/color]",
		"Next",
		func(): show_info_screen("WannaCry",
			"C:\\> WANNACRY\n==============================\n\n[color=#ff0000]>> WARNING <<[/color]\n\nThe WannaCry virus, like a lot of malware, is disguised as a legitimate program in order to trick users into executing it.\n\nIn this case, a program on the desktop appears to be a game, but in fact a copy of the virus.\n\n[color=#ffff00]Run it now to see the effect of executing malware on this simulated system.[/color]",
			"Next",
			func(): show_info_screen("Files are now encrypted",
				"C:\\> FILES ENCRYPTED\n==============================\n\n[color=#ff0000]>> YOUR FILES ARE NOW ENCRYPTED <<[/color]\n\nThe user is presented with a message clearly warning them that their files are now inaccessible, including a worrying countdown timer.\n\nThey are then invited to pay the perpetrators through cryptocurrency in order to decrypt these files. This is known as ransomware.\n\n[color=#ffff00]Try to open one of the files in the documents folder now to see the effect.[/color]",
				"OK",
				func(): pass
			)
		)
	)

func show_info_screen(title: String, content_text: String, button_text: String, on_button_click: Callable):
	var info_window = Panel.new()
	info_window.position = Vector2(550, 100) 
	info_window.size = Vector2(600, 400)
	info_window.z_index = 50
	add_child(info_window)
	
	# CMD-style black background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_border_width_all(2)
	style.border_color = Color(0, 0.5, 0, 1)
	info_window.add_theme_stylebox_override("panel", style)
	
	# Title bar
	var title_bar = Panel.new()
	title_bar.size = Vector2(600, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.1, 0.1, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	info_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "C:\\WINDOWS\\system32\\cmd.exe - " + title
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	title_label.add_theme_font_size_override("font_size", 12)
	title_bar.add_child(title_label)
	
	# ADD CLOSE BUTTON HERE
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(565, 5)
	close_btn.size = Vector2(25, 25)
	close_btn.add_theme_font_size_override("font_size", 18)
	
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.9, 0.3, 0.3, 1)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_stylebox_override("pressed", close_style)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	
	close_btn.pressed.connect(func(): info_window.queue_free())
	title_bar.add_child(close_btn)
	
	# Add this line after creating title_bar
	make_window_draggable(info_window, title_bar)
	
	# Content area
	var content = RichTextLabel.new()
	content.position = Vector2(20, 50)
	content.size = Vector2(560, 290)
	content.bbcode_enabled = true
	content.add_theme_color_override("default_color", Color(0, 1, 0, 1))
	content.add_theme_font_size_override("normal_font_size", 14)
	content.text = "[color=#00ff00]" + content_text + "[/color]"
	info_window.add_child(content)
	
	# Button
	var btn = Button.new()
	btn.text = button_text
	btn.position = Vector2(470, 350)
	btn.size = Vector2(110, 35)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.5, 0, 1)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	btn.pressed.connect(func(): 
		info_window.queue_free()
		on_button_click.call()
	)
	info_window.add_child(btn)



func setup_icon_interactions():
	var desktop_icons = {
		"Computer": computer_icon,
		"TotallyLegitGame": legitgame_icon,
		"TaskManager": taskmanager_icon,
		"Documents": documents_icon,
		"Calculator": calculator_icon,
		"Credits": null  # Keep this as is or add a credits icon
	}
	
	for icon_name in desktop_icons.keys():
		var icon = get_node_or_null(icon_name)
		if icon:
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			icon.gui_input.connect(_on_icon_input.bind(icon_name))
			icon.mouse_entered.connect(_on_icon_hover.bind(icon, true))
			icon.mouse_exited.connect(_on_icon_hover.bind(icon, false))
			
			# Find the IconLabel (emoji label) to replace
			var icon_label = icon.get_node_or_null("IconLabel")
			if icon_label and desktop_icons[icon_name] != null:
				# Get the position and size of the original label
				var original_pos = icon_label.position
				var original_size = icon_label.size
				
				# Hide the emoji label
				icon_label.visible = false
				
				# Create new TextureRect with same positioning
				var tex_rect = TextureRect.new()
				tex_rect.texture = desktop_icons[icon_name]
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.position = original_pos
				tex_rect.size = original_size
				
				icon.add_child(tex_rect)
				icon.move_child(tex_rect, 0)  # Move to front

func _on_icon_input(event: InputEvent, icon_name: String):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			handle_icon_double_click(icon_name)

func _on_icon_hover(icon: Control, is_hovering: bool):
	if is_hovering:
		icon.modulate = Color(1.2, 1.2, 1.2)
	else:
		icon.modulate = Color(1, 1, 1)

func handle_icon_double_click(icon_name: String):
	match icon_name:
		"Computer":
			print("Computer opened!")
		"TotallyLegitGame":
			if documents_opened:
				show_ransomware_attack()
			else:
				show_blocked_message()  # ADD THIS ELSE BLOCK
		"TaskManager":
			print("Task Manager opened!")
		"Documents":
			open_documents_window()
		"Calculator":
			open_calculator()
		"Credits":
			print("Credits opened!")
			
func show_blocked_message():
	var blocked_dialog = Panel.new()
	blocked_dialog.position = Vector2(300, 200)
	blocked_dialog.size = Vector2(400, 150)
	blocked_dialog.z_index = 30
	add_child(blocked_dialog)
	
	# Background
	var bg = ColorRect.new()
	bg.size = blocked_dialog.size
	bg.color = Color(0.75, 0.75, 0.75, 1)
	blocked_dialog.add_child(bg)
	
	# Title bar
	var title_bar = ColorRect.new()
	title_bar.size = Vector2(400, 30)
	title_bar.color = Color(0.3, 0.3, 0.3, 1)
	blocked_dialog.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Reminder"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bar.add_child(title_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(360, 2)
	close_btn.size = Vector2(30, 26)
	close_btn.pressed.connect(func(): blocked_dialog.queue_free())
	title_bar.add_child(close_btn)
	
	# Message text
	var message = Label.new()
	message.text = "Please check the Documents folder first
before running any programs."
	message.position = Vector2(50, 60)
	message.size = Vector2(300, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 14)
	blocked_dialog.add_child(message)
	
	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.position = Vector2(150, 105)
	ok_btn.size = Vector2(100, 30)
	ok_btn.pressed.connect(func(): blocked_dialog.queue_free())
	blocked_dialog.add_child(ok_btn)
func show_ransomware_attack():
	# Encrypt all files
	encrypt_files()
	
	# Show ransomware window
	open_ransomware_window()

func encrypt_files():
	# Change all file extensions to .cry
	files_encrypted = true
	for file in documents_files:
		if file.name.ends_with(".jpg"):
			file.name = file.name.replace(".jpg", ".cry")
		elif file.name.ends_with(".txt"):
			file.name = file.name.replace(".txt", ".cry")
		file.type = "encrypted"

func show_wannacry_panel():
	pass  # Removed - no longer needed

func open_ransomware_window():
	if ransomware_window != null:
		return
	
	ransomware_window = Panel.new()
	ransomware_window.position = Vector2(80, 10)
	ransomware_window.size = Vector2(700, 600)
	ransomware_window.z_index = 20
	add_child(ransomware_window)
	
	# CMD-style black background with rounded corners
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3, 1)
	ransomware_window.add_theme_stylebox_override("panel", style)
	
	# Title bar - CMD style
	var title_bar = Panel.new()
	title_bar.size = Vector2(700, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.1, 0.1, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	ransomware_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "C:\\WINDOWS\\system32\\cmd.exe - Wana Decryptor 2.0"
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	title_label.add_theme_font_size_override("font_size", 12)
	title_bar.add_child(title_label)
	
	# Window controls - CMD style
	var close_btn = create_window_button("×", Vector2(660, 5), Color(0.9, 0.3, 0.3, 1))
	close_btn.pressed.connect(func(): ransomware_window.queue_free())
	title_bar.add_child(close_btn)
	
	var maximize_btn = create_window_button("□", Vector2(625, 5), Color(0.3, 0.3, 0.3, 1))
	title_bar.add_child(maximize_btn)
	
	var minimize_btn = create_window_button("─", Vector2(590, 5), Color(0.3, 0.3, 0.3, 1))
	title_bar.add_child(minimize_btn)
	make_window_draggable(ransomware_window, title_bar)
	# Red warning banner with CMD-style text
	var warning_banner = ColorRect.new()
	warning_banner.position = Vector2(0, 35)
	warning_banner.size = Vector2(700, 60)
	warning_banner.color = Color(0.6, 0.1, 0.1, 1)
	ransomware_window.add_child(warning_banner)
	
	var warning_text = Label.new()
	warning_text.text = ">> OOPS, YOUR FILES HAVE BEEN ENCRYPTED!"
	warning_text.position = Vector2(20, 15)
	warning_text.add_theme_font_size_override("font_size", 18)
	warning_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	warning_banner.add_child(warning_text)
	
	# Left panel - Lock icon and countdown (CMD terminal style)
	create_left_panel_cmd()
	
	# Right panel - Instructions (CMD terminal style)
	create_right_panel_cmd()
	
	# Bottom buttons
	create_bottom_buttons()

func create_left_panel_cmd():
	var left_panel = ColorRect.new()
	left_panel.position = Vector2(10, 105)  # Position after warning banner
	left_panel.size = Vector2(290, 440)  # Adjusted size
	left_panel.color = Color(0.05, 0.05, 0.05, 1)
	ransomware_window.add_child(left_panel)
	
	# Rest of the function remains the same...
	
	# Payment countdown
	var payment_label = Label.new()
	payment_label.text = ">> Payment doubled in:"
	payment_label.position = Vector2(30, 180)  # Changed from 200
	payment_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	payment_label.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(payment_label)
	
	var payment_timer = Label.new()
	payment_timer.name = "PaymentTimer"
	payment_timer.text = "   2:23:59:57"
	payment_timer.position = Vector2(40, 210)  # Changed from 230
	payment_timer.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	payment_timer.add_theme_font_size_override("font_size", 24)
	left_panel.add_child(payment_timer)
	
	# Deletion countdown
	var deletion_label = Label.new()
	deletion_label.text = ">> Files deleted in:"
	deletion_label.position = Vector2(30, 280)  # Changed from 310
	deletion_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	deletion_label.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(deletion_label)
	
	var deletion_timer = Label.new()
	deletion_timer.name = "DeletionTimer"
	deletion_timer.text = "   6:23:59:57"
	deletion_timer.position = Vector2(40, 310)  # Changed from 340
	deletion_timer.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	deletion_timer.add_theme_font_size_override("font_size", 24)
	left_panel.add_child(deletion_timer)

func create_right_panel_cmd():
	var right_panel = ColorRect.new()
	right_panel.position = Vector2(300, 100)
	right_panel.size = Vector2(390, 450)
	right_panel.color = Color(0.05, 0.05, 0.05, 1)
	ransomware_window.add_child(right_panel)
	
	# CMD-style instructions with green text
	var instructions = RichTextLabel.new()
	instructions.position = Vector2(15, 15)
	instructions.size = Vector2(360, 420)
	instructions.bbcode_enabled = true
	instructions.add_theme_font_size_override("normal_font_size", 13)
	instructions.add_theme_color_override("default_color", Color(0, 1, 0, 1))
	instructions.text = "[color=#00ff00]C:\\> SYSTEM COMPROMISED
------------------------------

[color=#ffff00]>> YOUR FILES ARE ENCRYPTED <<[/color]

Your documents, photos, videos
and other files are now
encrypted and no longer
accessible.

Don't bother trying to fix
this. Only our decryption
service can help.

[color=#ff0000]>> PAYMENT REQUIRED <<[/color]

Send $300 worth of bitcoin to
recover your files. You have 3
days to make payment, after
which the price will double.

Pay within 7 days or files
will be lost forever!

Type 'HELP' for assistance
Type 'PAY' to make payment
[/color]"
	right_panel.add_child(instructions)

func create_bottom_buttons():
	# Make Payment button
	var payment_btn = Button.new()
	payment_btn.text = "Make Payment"
	payment_btn.position = Vector2(310, 555)  # Adjusted Y from 560
	payment_btn.size = Vector2(180, 35)
	payment_btn.pressed.connect(_on_make_payment_clicked)
	ransomware_window.add_child(payment_btn)
	
	# Decrypt button
	var decrypt_btn = Button.new()
	decrypt_btn.text = "Decrypt"
	decrypt_btn.position = Vector2(500, 555)  # Adjusted Y from 560
	decrypt_btn.size = Vector2(180, 35)
	decrypt_btn.pressed.connect(_on_decrypt_clicked)
	ransomware_window.add_child(decrypt_btn)

func update_countdown_timers():
	if ransomware_window == null:
		return
	
	# Find and update payment timer
	var left_panel = ransomware_window.get_children()
	for child in left_panel:
		if child is ColorRect and child.position == Vector2(10, 100):
			for timer_child in child.get_children():
				if timer_child.name == "PaymentTimer":
					timer_child.text = format_time(payment_time)
				elif timer_child.name == "DeletionTimer":
					timer_child.text = format_time(deletion_time)

func format_time(seconds: float) -> String:
	var days = int(seconds / 86400)
	var hours = int((seconds - days * 86400) / 3600)
	var mins = int((seconds - days * 86400 - hours * 3600) / 60)
	var secs = int(seconds - days * 86400 - hours * 3600 - mins * 60)
	return "%d:%02d:%02d:%02d" % [days, hours, mins, secs]

func open_documents_window():
	documents_opened = true
	if documents_window != null:
		documents_window.queue_free()
	
	documents_window = Panel.new()
	documents_window.position = Vector2(180, 170)
	documents_window.size = Vector2(600, 340)
	documents_window.z_index = 10
	add_child(documents_window)
	
	# Add rounded corners using StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	documents_window.add_theme_stylebox_override("panel", style)
	
	# Title bar with rounded top
	var title_bar = Panel.new()
	title_bar.size = Vector2(600, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.2, 0.4, 0.8, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	documents_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Documents"
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title_label)
	
	# Window control buttons
	var close_btn = create_window_button("×", Vector2(560, 5), Color(0.9, 0.3, 0.3, 1))
	close_btn.pressed.connect(_on_close_documents)
	title_bar.add_child(close_btn)
	
	var maximize_btn = create_window_button("□", Vector2(525, 5), Color(0.3, 0.7, 0.3, 1))
	title_bar.add_child(maximize_btn)
	
	var minimize_btn = create_window_button("─", Vector2(490, 5), Color(0.9, 0.8, 0.3, 1))
	title_bar.add_child(minimize_btn)
	make_window_draggable(documents_window, title_bar)
	# Menu bar
	var menu_bar = ColorRect.new()
	menu_bar.position = Vector2(0, 35)
	menu_bar.size = Vector2(600, 30)
	menu_bar.color = Color(0.85, 0.85, 0.85, 1)
	documents_window.add_child(menu_bar)
	
	# Styled button
	var all_files_btn = Button.new()
	all_files_btn.text = "All Files"
	all_files_btn.position = Vector2(10, 3)
	all_files_btn.size = Vector2(120, 24)
	
	# Button styling
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.7, 0.7, 0.7, 1)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	all_files_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover_style = StyleBoxFlat.new()
	btn_hover_style.bg_color = Color(0.6, 0.6, 0.6, 1)
	btn_hover_style.corner_radius_top_left = 4
	btn_hover_style.corner_radius_top_right = 4
	btn_hover_style.corner_radius_bottom_left = 4
	btn_hover_style.corner_radius_bottom_right = 4
	all_files_btn.add_theme_stylebox_override("hover", btn_hover_style)
	
	all_files_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	menu_bar.add_child(all_files_btn)
	
	# Content area - lighter gray for better contrast
	var content_bg = ColorRect.new()
	content_bg.position = Vector2(0, 65)
	content_bg.size = Vector2(600, 275)
	content_bg.color = Color(0, 0, 0, 1)  # Slightly darker than before
	documents_window.add_child(content_bg)
	
	var start_x = 40
	var start_y = 80
	var spacing_x = 120
	
	for i in range(documents_files.size()):
		var file = documents_files[i]
		var file_control = create_file_icon(file, i)
		file_control.position = Vector2(start_x + (i * spacing_x), start_y)
		documents_window.add_child(file_control)

func create_window_button(text: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(25, 25)
	btn.add_theme_font_size_override("font_size", 16)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	return btn

func create_file_icon(file_data: Dictionary, index: int) -> Control:
	var file_control = Control.new()
	file_control.custom_minimum_size = Vector2(100, 120)
	file_control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var icon_label = Label.new()
	icon_label.text = file_data.icon
	icon_label.position = Vector2(30, 0)
	icon_label.add_theme_font_size_override("font_size", 48)
	file_control.add_child(icon_label)
	
	var name_label = Label.new()
	name_label.text = file_data.name
	name_label.position = Vector2(0, 60)
	name_label.size = Vector2(100, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	file_control.add_child(name_label)
	
	file_control.gui_input.connect(_on_file_clicked.bind(file_data))
	file_control.mouse_entered.connect(_on_file_hover.bind(file_control, true))
	file_control.mouse_exited.connect(_on_file_hover.bind(file_control, false))
	
	return file_control

func _on_file_hover(file_control: Control, is_hovering: bool):
	if is_hovering:
		file_control.modulate = Color(1.2, 1.2, 1.2)
	else:
		file_control.modulate = Color(1, 1, 1)

func _on_file_clicked(event: InputEvent, file_data: Dictionary):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			if files_encrypted:
				# Show "Cannot open file" dialog
				show_encrypted_file_dialog()
			else:
				# Open files normally
				if file_data.type == "image":
					open_image_viewer(file_data.name)
				elif file_data.type == "text":
					open_text_viewer(file_data.name)

func open_image_viewer(filename: String):
	if image_viewer_window != null:
		image_viewer_window.queue_free()
	
	image_viewer_window = Panel.new()
	image_viewer_window.position = Vector2(120, 40)
	image_viewer_window.size = Vector2(450, 310)
	image_viewer_window.z_index = 15
	add_child(image_viewer_window)
	
	# Rounded panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	image_viewer_window.add_theme_stylebox_override("panel", style)
	
	# Title bar
	var title_bar = Panel.new()
	title_bar.size = Vector2(450, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.2, 0.4, 0.8, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	image_viewer_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Image Viewer - " + filename
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title_label)
	
	# Window controls
	var close_btn = create_window_button("×", Vector2(410, 5), Color(0.9, 0.3, 0.3, 1))
	close_btn.pressed.connect(_on_close_image_viewer)
	title_bar.add_child(close_btn)
	
	var maximize_btn = create_window_button("□", Vector2(375, 5), Color(0.3, 0.7, 0.3, 1))
	title_bar.add_child(maximize_btn)
	
	var minimize_btn = create_window_button("─", Vector2(340, 5), Color(0.9, 0.8, 0.3, 1))
	title_bar.add_child(minimize_btn)
	make_window_draggable(image_viewer_window, title_bar)

	# Image display area
	
	
	var image_bg = ColorRect.new()
	image_bg.position = Vector2(0, 35)
	image_bg.size = Vector2(450, 275)
	image_bg.color = Color(0.95, 0.95, 0.95, 1)
	image_viewer_window.add_child(image_bg)

# Centered image display - NO WHITE PLACEHOLDER
	var img_display = TextureRect.new()
	img_display.texture = mrmeow_icon
	img_display.position = Vector2(0, 35)  # Fill entire viewing area
	img_display.size = Vector2(450, 275)   # Fill entire viewing area
	img_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_viewer_window.add_child(img_display)

func open_text_viewer(filename: String):
	var text_window = Panel.new()
	text_window.position = Vector2(250, 150)
	text_window.size = Vector2(500, 400)
	text_window.z_index = 15
	add_child(text_window)
	
	# Rounded panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	text_window.add_theme_stylebox_override("panel", style)
	
	# Title bar
	var title_bar = Panel.new()
	title_bar.size = Vector2(500, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.2, 0.4, 0.8, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	text_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Text Viewer - " + filename
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title_label)
	
	# Window controls
	var close_btn = create_window_button("×", Vector2(460, 5), Color(0.9, 0.3, 0.3, 1))
	close_btn.pressed.connect(func(): text_window.queue_free())
	title_bar.add_child(close_btn)
	
	var maximize_btn = create_window_button("□", Vector2(425, 5), Color(0.3, 0.7, 0.3, 1))
	title_bar.add_child(maximize_btn)
	
	var minimize_btn = create_window_button("─", Vector2(390, 5), Color(0.9, 0.8, 0.3, 1))
	title_bar.add_child(minimize_btn)
	make_window_draggable(text_window, title_bar)
	# Text content area
	var content_bg = ColorRect.new()
	content_bg.position = Vector2(0, 35)
	content_bg.size = Vector2(500, 365)
	content_bg.color = Color(1, 1, 1, 1)
	text_window.add_child(content_bg)
	
	var text_content = RichTextLabel.new()
	text_content.position = Vector2(10, 45)
	text_content.size = Vector2(480, 345)
	text_content.bbcode_enabled = true
	text_content.text = "This is a sample text file content.\n\nYou can add your text here."
	text_window.add_child(text_content)

func _on_close_documents():
	if documents_window != null:
		documents_window.queue_free()
		documents_window = null

func _on_close_image_viewer():
	if image_viewer_window != null:
		image_viewer_window.queue_free()
		image_viewer_window = null

func _on_decrypt_clicked():
	# Open decrypt window
	var decrypt_window = Panel.new()
	decrypt_window.position = Vector2(200, 150)
	decrypt_window.size = Vector2(570, 490)
	decrypt_window.z_index = 25
	add_child(decrypt_window)
	
	# Background
	var bg = ColorRect.new()
	bg.size = decrypt_window.size
	bg.color = Color(0.5, 0.1, 0.1, 1)
	decrypt_window.add_child(bg)
	
	# Title bar
	var title_bar = ColorRect.new()
	title_bar.size = Vector2(570, 30)
	title_bar.color = Color(0.3, 0.3, 0.3, 1)
	decrypt_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Decrypt"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bar.add_child(title_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(530, 2)
	close_btn.size = Vector2(30, 26)
	close_btn.pressed.connect(func(): decrypt_window.queue_free())
	title_bar.add_child(close_btn)
	make_window_draggable(decrypt_window, title_bar)
	# Instruction text
	var instruction = Label.new()
	instruction.text = "Select a host to decrypt and click \"Start\"."
	instruction.position = Vector2(20, 45)
	instruction.size = Vector2(530, 25)
	instruction.add_theme_color_override("font_color", Color.WHITE)
	instruction.add_theme_font_size_override("font_size", 14)
	decrypt_window.add_child(instruction)
	
	# Path label
	var path_label = Label.new()
	path_label.text = "Path"
	path_label.position = Vector2(60, 85)
	path_label.add_theme_font_size_override("font_size", 12)
	decrypt_window.add_child(path_label)
	
	# Large text area (list box simulation)
	var text_area = ColorRect.new()
	text_area.position = Vector2(55, 110)
	text_area.size = Vector2(465, 280)
	text_area.color = Color(0.75, 0.75, 0.75, 1)
	decrypt_window.add_child(text_area)
	
	# Start button
	var start_btn = Button.new()
	start_btn.text = "Start"
	start_btn.position = Vector2(55, 410)
	start_btn.size = Vector2(150, 40)
	start_btn.pressed.connect(func(): 
		decrypt_window.queue_free()
		show_payment_dialog()
	)
	decrypt_window.add_child(start_btn)
	
	# Close button (bottom)
	var close_bottom_btn = Button.new()
	close_bottom_btn.text = "Close"
	close_bottom_btn.position = Vector2(370, 410)
	close_bottom_btn.size = Vector2(150, 40)
	close_bottom_btn.pressed.connect(func(): decrypt_window.queue_free())
	decrypt_window.add_child(close_bottom_btn)

func _on_make_payment_clicked():
	show_payment_not_advised_dialog()

func show_payment_not_advised_dialog():
	# Payment Not Advised dialog
	var not_advised_dialog = Panel.new()
	not_advised_dialog.position = Vector2(190, 160)
	not_advised_dialog.size = Vector2(480, 200)
	not_advised_dialog.z_index = 30
	add_child(not_advised_dialog)
	
	# Background
	var bg = ColorRect.new()
	bg.size = not_advised_dialog.size
	bg.color = Color(0.75, 0.75, 0.75, 1)
	not_advised_dialog.add_child(bg)
	
	# Title bar
	var title_bar = ColorRect.new()
	title_bar.size = Vector2(480, 30)
	title_bar.color = Color(0.3, 0.3, 0.3, 1)
	not_advised_dialog.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Payment Not Advised"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bar.add_child(title_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(440, 2)
	close_btn.size = Vector2(30, 26)
	close_btn.pressed.connect(func(): not_advised_dialog.queue_free())
	title_bar.add_child(close_btn)
	
	# Message text
	var message = Label.new()
	message.text = "The real Ransomware would take you to a
BitCoin payment page. It's strongly
recommended never to pay a ransom."
	message.position = Vector2(40, 60)
	message.size = Vector2(400, 80)
	message.add_theme_font_size_override("font_size", 14)
	not_advised_dialog.add_child(message)
	
	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.position = Vector2(190, 150)
	ok_btn.size = Vector2(100, 35)
	ok_btn.pressed.connect(func(): not_advised_dialog.queue_free())
	not_advised_dialog.add_child(ok_btn)

func show_encrypted_file_dialog():
	# "Cannot open file" dialog
	var encrypted_dialog = Panel.new()
	encrypted_dialog.position = Vector2(225, 110)
	encrypted_dialog.size = Vector2(300, 140)
	encrypted_dialog.z_index = 30
	add_child(encrypted_dialog)
	
	# Background
	var bg = ColorRect.new()
	bg.size = encrypted_dialog.size
	bg.color = Color(0.75, 0.75, 0.75, 1)
	encrypted_dialog.add_child(bg)
	
	# Title bar
	var title_bar = ColorRect.new()
	title_bar.size = Vector2(300, 30)
	title_bar.color = Color(0.3, 0.3, 0.3, 1)
	encrypted_dialog.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Cannot open file"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bar.add_child(title_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(260, 2)
	close_btn.size = Vector2(30, 26)
	close_btn.pressed.connect(func(): encrypted_dialog.queue_free())
	title_bar.add_child(close_btn)
	
	# Message text
	var message = Label.new()
	message.text = "File contents encrypted"
	message.position = Vector2(50, 60)
	message.size = Vector2(200, 25)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 14)
	encrypted_dialog.add_child(message)
	
	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.position = Vector2(100, 95)
	ok_btn.size = Vector2(100, 30)
	ok_btn.pressed.connect(func(): encrypted_dialog.queue_free())
	encrypted_dialog.add_child(ok_btn)

func open_calculator():
	if calculator_window != null:
		calculator_window.queue_free()
	
	calculator_window = Panel.new()
	calculator_window.position = Vector2(280, 60)
	calculator_window.size = Vector2(320, 410)
	calculator_window.z_index = 10
	add_child(calculator_window)
	
	# Rounded panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	calculator_window.add_theme_stylebox_override("panel", style)
	
	# Title bar
	var title_bar = Panel.new()
	title_bar.size = Vector2(320, 35)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.2, 0.4, 0.8, 1)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_bar.add_theme_stylebox_override("panel", title_style)
	calculator_window.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Calculator"
	title_label.position = Vector2(10, 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title_label)
	
	# Window controls
	var close_btn = create_window_button("×", Vector2(280, 5), Color(0.9, 0.3, 0.3, 1))
	close_btn.pressed.connect(func(): calculator_window.queue_free())
	title_bar.add_child(close_btn)
	
	var maximize_btn = create_window_button("□", Vector2(245, 5), Color(0.3, 0.7, 0.3, 1))
	title_bar.add_child(maximize_btn)
	
	var minimize_btn = create_window_button("─", Vector2(210, 5), Color(0.9, 0.8, 0.3, 1))
	title_bar.add_child(minimize_btn)
	make_window_draggable(calculator_window, title_bar)
	# Display
	var display = ColorRect.new()
	display.position = Vector2(10, 50)
	display.size = Vector2(210, 50)
	display.color = Color(0.3, 0.3, 0.3, 1)
	calculator_window.add_child(display)
	
	var display_label = Label.new()
	display_label.name = "Display"
	display_label.text = "0"
	display_label.position = Vector2(10, 15)
	display_label.size = Vector2(190, 25)
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	display_label.add_theme_color_override("font_color", Color.WHITE)
	display_label.add_theme_font_size_override("font_size", 20)
	display.add_child(display_label)
	
	# Clear button (C)
	var clear_btn = create_calc_button("C", Vector2(230, 50), Vector2(80, 50))
	clear_btn.pressed.connect(func(): calc_clear())
	calculator_window.add_child(clear_btn)
	
	# Number buttons
	var buttons = [
		["7", Vector2(10, 110)], ["8", Vector2(90, 110)], ["9", Vector2(170, 110)],
		["4", Vector2(10, 170)], ["5", Vector2(90, 170)], ["6", Vector2(170, 170)],
		["1", Vector2(10, 230)], ["2", Vector2(90, 230)], ["3", Vector2(170, 230)],
		["0", Vector2(10, 290)], [".", Vector2(170, 290)]
	]
	
	for btn_data in buttons:
		var btn = create_calc_button(btn_data[0], btn_data[1], Vector2(70, 50))
		btn.pressed.connect(calc_number_pressed.bind(btn_data[0]))
		calculator_window.add_child(btn)
	
	# Operation buttons
	var operations = [
		["÷", Vector2(250, 110)], ["×", Vector2(250, 170)],
		["-", Vector2(250, 230)], ["+", Vector2(250, 290)]
	]
	
	for op_data in operations:
		var op_btn = create_calc_button(op_data[0], op_data[1], Vector2(60, 50))
		op_btn.pressed.connect(calc_operation_pressed.bind(op_data[0]))
		calculator_window.add_child(op_btn)
	
	# Equals button
	var equals_btn = create_calc_button("=", Vector2(10, 350), Vector2(300, 50))
	equals_btn.pressed.connect(func(): calc_equals())
	calculator_window.add_child(equals_btn)

# Calculator variables
var calc_current_value = "0"
var calc_operation = ""
var calc_previous_value = 0.0
var calc_new_number = true

func create_calc_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func calc_number_pressed(number: String):
	var display = calculator_window.find_child("Display", true, false)
	if display:
		if calc_new_number:
			calc_current_value = number
			calc_new_number = false
		else:
			if calc_current_value == "0":
				calc_current_value = number
			else:
				calc_current_value += number
		display.text = calc_current_value

func calc_operation_pressed(op: String):
	calc_previous_value = float(calc_current_value)
	calc_operation = op
	calc_new_number = true

func calc_equals():
	var result = 0.0
	var current = float(calc_current_value)
	
	match calc_operation:
		"+":
			result = calc_previous_value + current
		"-":
			result = calc_previous_value - current
		"×":
			result = calc_previous_value * current
		"÷":
			if current != 0:
				result = calc_previous_value / current
			else:
				result = 0
		_:
			result = current
	
	var display = calculator_window.find_child("Display", true, false)
	if display:
		calc_current_value = str(result)
		display.text = calc_current_value
	
	calc_new_number = true
	calc_operation = ""

func calc_clear():
	calc_current_value = "0"
	calc_previous_value = 0.0
	calc_operation = ""
	calc_new_number = true
	
	var display = calculator_window.find_child("Display", true, false)
	if display:
		display.text = "0"

func show_payment_dialog():
	# Payment popup dialog
	var payment_dialog = Panel.new()
	payment_dialog.position = Vector2(290, 190)
	payment_dialog.size = Vector2(480, 180)
	payment_dialog.z_index = 30
	add_child(payment_dialog)
	
	# Background
	var bg = ColorRect.new()
	bg.size = payment_dialog.size
	bg.color = Color(0.75, 0.75, 0.75, 1)
	payment_dialog.add_child(bg)
	
	# Title bar
	var title_bar = ColorRect.new()
	title_bar.size = Vector2(480, 30)
	title_bar.color = Color(0.3, 0.3, 0.3, 1)
	payment_dialog.add_child(title_bar)
	
	var title_label = Label.new()
	title_label.text = "Wana Decryptor"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_bar.add_child(title_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(440, 2)
	close_btn.size = Vector2(30, 26)
	close_btn.pressed.connect(func(): payment_dialog.queue_free())
	title_bar.add_child(close_btn)
	
	# Message text
	var message = Label.new()
	message.text = "Pay now, if you want to decrypt
ALL
your files"
	message.position = Vector2(100, 60)
	message.size = Vector2(280, 80)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 16)
	payment_dialog.add_child(message)
	
	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.position = Vector2(190, 130)
	ok_btn.size = Vector2(100, 35)
	ok_btn.pressed.connect(func(): payment_dialog.queue_free())
	payment_dialog.add_child(ok_btn)



func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
