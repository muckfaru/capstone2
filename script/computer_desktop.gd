extends Control

var game_state = "desktop"  # desktop, searching, downloading, infected
var chat_shown = false

func _ready():
    # Connect button signals
    $Desktop/IconBrowser/IconButton.pressed.connect(_on_browser_clicked)
    $Desktop/IconMessages/IconButton.pressed.connect(_on_messages_clicked)
    $Taskbar/ExitButton.pressed.connect(_on_exit_clicked)
    
    # Browser window controls
    $WindowBrowser/TitleBar/CloseBtn.pressed.connect(_on_browser_close)
    $WindowBrowser/SearchButton.pressed.connect(_on_search_clicked)
    $WindowBrowser/AddressBar.text_submitted.connect(_on_search_submitted)
    
    # Messages window controls
    $WindowMessages/TitleBar/CloseBtn.pressed.connect(_on_messages_close)
    
    # Update time
    update_time()
    
    # Load initial chat messages
    load_chat_messages()

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
    $WindowBrowser.visible = true
    $WindowBrowser/AddressBar.text = ""
    clear_search_results()

func _on_messages_clicked():
    $WindowMessages.visible = true
    if not chat_shown:
        chat_shown = true
        # Show educational hint after reading messages
        await get_tree().create_timer(2.0).timeout
        add_message("System", "Remember: Always download games from official sources!", "System")

func _on_browser_close():
    $WindowBrowser.visible = false

func _on_messages_close():
    $WindowMessages.visible = false

func _on_exit_clicked():
    # Return to room scene
    get_tree().change_scene_to_file("res://scene/Main.tscn")

func _on_search_clicked():
    perform_search($WindowBrowser/AddressBar.text)

func _on_search_submitted(text):
    perform_search(text)

func perform_search(query: String):
    clear_search_results()
    
    if query.to_lower().contains("free") and (query.to_lower().contains("game") or query.to_lower().contains("cyberrun")):
        # Show suspicious websites
        add_search_result("CyberRun 2024 - Official Store", "https://officialgamestore.com", "₱1,000 - Official download with updates and support", false)
        add_search_result("⚠️ FREE GAMES DOWNLOAD - CyberRun 2024", "http://freegamesdownload123.xyz", "Download CyberRun 2024 FREE! No payment needed! CLICK HERE!", true)
        add_search_result("GameShare Forum - CyberRun Discussion", "https://gameshare.com/cyberrun", "Users discussing the game. Mixed reviews on third-party sites.", false)
    else:
        add_search_result("No results found", "", "Try searching for 'free game download'", false)

func clear_search_results():
    for child in $WindowBrowser/ContentArea/SearchResults.get_children():
        child.queue_free()

func add_search_result(title: String, url: String, description: String, is_suspicious: bool):
    var result_panel = Panel.new()
    result_panel.custom_minimum_size = Vector2(0, 100)
    
    var vbox = VBoxContainer.new()
    result_panel.add_child(vbox)
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 5)
    
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
    vbox.add_child(url_label)
    
    var desc_label = Label.new()
    desc_label.text = description
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    vbox.add_child(desc_label)
    
    var download_btn = Button.new()
    download_btn.text = "Visit Site" if not is_suspicious else "⚠️ DOWNLOAD FREE"
    download_btn.pressed.connect(_on_download_clicked.bind(is_suspicious))
    vbox.add_child(download_btn)
    
    $WindowBrowser/ContentArea/SearchResults.add_child(result_panel)

func _on_download_clicked(is_suspicious: bool):
    if is_suspicious:
        # Show warning or directly infect
        show_download_warning()
    else:
        # Safe download
        show_message("This would take you to the official store.\n(Outside the scope of this demo)")

func show_download_warning():
    # Create warning dialog
    var dialog = AcceptDialog.new()
    dialog.dialog_text = "⚠️ WARNING!\n\nThis website looks suspicious:\n• Strange URL (xyz domain)\n• Offers paid game for free\n• No HTTPS security\n\nDo you want to continue?"
    dialog.title = "Security Warning"
    
    # Add custom buttons
    dialog.add_cancel_button("Go Back (Safe)")
    dialog.confirmed.connect(_on_dangerous_download_confirmed)
    
    add_child(dialog)
    dialog.popup_centered()

func _on_dangerous_download_confirmed():
    # Player chose to download the virus
    start_infection_sequence()

func start_infection_sequence():
    game_state = "infected"
    
    # Create infection overlay
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.7)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    
    var warning_label = Label.new()
    warning_label.text = "DOWNLOADING..."
    warning_label.add_theme_font_size_override("font_size", 48)
    warning_label.add_theme_color_override("font_color", Color.RED)
    warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    warning_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(warning_label)
    
    # Simulate infection
    await get_tree().create_timer(2.0).timeout
    warning_label.text = "SYSTEM COMPROMISED!"
    
    await get_tree().create_timer(2.0).timeout
    warning_label.text = "ACCOUNTS STOLEN!\nFILES ENCRYPTED!\nDATA BREACHED!"
    
    await get_tree().create_timer(3.0).timeout
    
    # Go to consequence/learning scene
    get_tree().change_scene_to_file("res://scenes/consequence_scene.tscn")

func load_chat_messages():
    add_message("Mark", "Bro have you played CyberRun 2024 yet?!", "2:30 PM")
    add_message("Sarah", "It's so good! Already level 15!", "2:31 PM")
    add_message("Mark", "Costs 1000 pesos though 😅", "2:32 PM")
    add_message("You", "I really want to play but don't have the money...", "2:33 PM")

func add_message(sender: String, text: String, time: String):
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