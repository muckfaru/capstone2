extends Control

@onready var beginner_btn: Button = $CanvasLayer/ButtonContainer/BeginnerButton
@onready var intermediate_btn: Button = $CanvasLayer/ButtonContainer/IntermediateButton
@onready var advanced_btn: Button = $CanvasLayer/ButtonContainer/AdvancedButton
@onready var xp_label: Label = $CanvasLayer/XPLabel
@onready var rank_icon: TextureRect = $CanvasLayer/RankIcon
@onready var rank_label: Label = $CanvasLayer/RankLabel
@onready var profile_btn: Button = $CanvasLayer/ProfileButton
@onready var back_btn: Button = $CanvasLayer/BackButton

# Dynamically created nodes (set in _setup_ui_elements)
var xp_progress_bar: ProgressBar = null
var unlock_panel: Panel = null
var beginner_desc: Label = null
var intermediate_desc: Label = null
var advanced_desc: Label = null
var fade_overlay: ColorRect = null  # ADD THIS LINE

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

# Tutorial metadata with time estimates and XP ranges
const TUTORIAL_METADATA := {
	"beginner_fundamentals": {"time": "10-15 min", "xp_range": "100-200 XP", "difficulty": 2},
	"beginner_network": {"time": "12-18 min", "xp_range": "100-200 XP", "difficulty": 3},
	"beginner_password": {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3},
	"beginner_malware": {"time": "10-15 min", "xp_range": "100-200 XP", "difficulty": 2},
	"intermediate_phishing": {"time": "20-25 min", "xp_range": "100-200 XP", "difficulty": 4},
	"intermediate_trojan": {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3},
	"intermediate_defense": {"time": "18-25 min", "xp_range": "100-200 XP", "difficulty": 4},
	"intermediate_lab": {"time": "20-30 min", "xp_range": "100-200 XP", "difficulty": 4},
	"advanced_scenarios": {"time": "25-35 min", "xp_range": "100-200 XP", "difficulty": 5},
	"advanced_encryption": {"time": "20-25 min", "xp_range": "100-200 XP", "difficulty": 4},
	"advanced_lab": {"time": "25-40 min", "xp_range": "100-200 XP", "difficulty": 5}
}

func _ready() -> void:
	# Verify auth state
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ No auth state! Redirecting to login...")
		get_tree().change_scene_to_file("res://scene/login.tscn")
		return
	
	print("✅ Mode Selection Ready | UID:", Auth.current_local_id)
	
	# Setup UI elements first
	_setup_ui_elements()
	_setup_smooth_video_loop()
	
	# Connect to data_loaded signal BEFORE loading data
	if not TutorialManager.data_loaded.is_connected(_update_xp_display):
		TutorialManager.data_loaded.connect(_update_xp_display)
	
	# Load TutorialManager data if not already loaded
	if not TutorialManager.data_has_loaded:
		print("[ModeSelection] TutorialManager data not loaded yet, loading now...")
		TutorialManager.load_user_data()
	else:
		print("[ModeSelection] TutorialManager already has data (XP: %d)" % TutorialManager.total_xp)
		# Update display immediately since data is already loaded
		call_deferred("_update_xp_display")
	
	# Connect profile button
	if profile_btn:
		profile_btn.pressed.connect(_on_profile_pressed)
	
	# Connect back button
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	
	# Animate entrance
	_animate_entrance()
	
	# Animate entrance
	_animate_entrance()

	var bgm = $BackgroundMusic
	if bgm:
		bgm.volume_db = -80  # Start silent
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -10, 2.0)

func _fade_out_music_and_transition(scene_path: String) -> void:
	var bgm = $BackgroundMusic
	if bgm:
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -80, 0.5)
		await tween.finished
	
	get_tree().change_scene_to_file(scene_path)

func _setup_smooth_video_loop() -> void:
	var video_player = $VideoStreamPlayer
	
	# Create fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.modulate.a = 0
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)
	move_child(fade_overlay, get_child_count() - 2)  # Just above video
	
	# Disable built-in loop, handle manually
	video_player.loop = false
	video_player.finished.connect(_on_video_finished)

func _on_video_finished() -> void:
	var video_player = $VideoStreamPlayer
	var tween = create_tween()
	
	# Fade out
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	await tween.finished
	
	# Restart
	video_player.play()
	await get_tree().create_timer(0.1).timeout
	
	# Fade in
	var tween2 = create_tween()
	tween2.tween_property(fade_overlay, "modulate:a", 0.0, 0.6)
# -------------------------
# UI SETUP
# -------------------------
func _setup_ui_elements() -> void:
	"""Setup progress bars, unlock panels, and level descriptions"""
	# Create XP Progress Bar if not in scene
	if not xp_progress_bar:
		xp_progress_bar = ProgressBar.new()
		xp_progress_bar.name = "XPProgressBar"
		xp_progress_bar.anchors_preset = Control.PRESET_TOP_WIDE
		xp_progress_bar.offset_left = 20
		xp_progress_bar.offset_top = 20
		xp_progress_bar.offset_right = -20
		xp_progress_bar.offset_bottom = 50
		xp_progress_bar.show_percentage = false
		$CanvasLayer.add_child(xp_progress_bar)
	
	# Create Unlock Progress Panel
	if not unlock_panel:
		unlock_panel = Panel.new()
		unlock_panel.name = "UnlockProgressPanel"
		unlock_panel.custom_minimum_size = Vector2(400, 200)
		unlock_panel.anchors_preset = Control.PRESET_TOP_RIGHT
		unlock_panel.offset_left = -420
		unlock_panel.offset_top = 80
		unlock_panel.offset_right = -20
		unlock_panel.offset_bottom = 280
		unlock_panel.visible = false  # Hide by default until populated
		
		# Add stylebox for glassmorphism effect
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0, 1, 1, 0.5)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		unlock_panel.add_theme_stylebox_override("panel", style)
		
		$CanvasLayer.add_child(unlock_panel)
		_populate_unlock_panel()
		unlock_panel.visible = true  # Show after population
	
	# Add level descriptions and icons if buttons exist
	if beginner_btn and not beginner_desc:
		# Add icon to beginner button
		var icon_texture = load("res://asset/icons/Beginner Icon.png")
		if icon_texture and not beginner_btn.has_node("IconRect"):
			var icon_rect = TextureRect.new()
			icon_rect.name = "IconRect"
			icon_rect.texture = icon_texture
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.position = Vector2(20, 16)  # Left side, vertically centered
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			beginner_btn.add_child(icon_rect)
		
		var desc = Label.new()
		desc.name = "Description"
		desc.text = "Cybersecurity Fundamentals - Start here if new!"
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.9, 0.9))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.position = Vector2(0, 50)
		desc.size = Vector2(500, 25)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beginner_btn.add_child(desc)
	
	if intermediate_btn and not intermediate_desc:
		# Add intermediate icon
		var icon_texture = load("res://asset/icons/intermediate.png")
		if icon_texture and not intermediate_btn.has_node("IconRect"):
			var icon_rect = TextureRect.new()
			icon_rect.name = "IconRect"
			icon_rect.texture = icon_texture
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.position = Vector2(20, 16)  # Left side, vertically centered
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			intermediate_btn.add_child(icon_rect)
		
		var desc = Label.new()
		desc.name = "Description"
		desc.text = "Real-world Threats & Defense"
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.9, 0.9))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.position = Vector2(0, 50)
		desc.size = Vector2(500, 25)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intermediate_btn.add_child(desc)
	
	if advanced_btn and not advanced_desc:
		# Add advanced icon
		var icon_texture = load("res://asset/icons/Advance.png")
		if icon_texture and not advanced_btn.has_node("IconRect"):
			var icon_rect = TextureRect.new()
			icon_rect.name = "IconRect"
			icon_rect.texture = icon_texture
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.position = Vector2(20, 16)  # Left side, vertically centered
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			advanced_btn.add_child(icon_rect)
		
		var desc = Label.new()
		desc.name = "Description"
		desc.text = "Red Team Tactics & Forensics"
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.9, 0.9))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.position = Vector2(0, 50)
		desc.size = Vector2(500, 25)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		advanced_btn.add_child(desc)


func _populate_unlock_panel() -> void:
	"""Populate unlock panel with game unlock progress"""
	if not unlock_panel:
		return
	
	# Clear existing children
	for child in unlock_panel.get_children():
		child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(380, 180)
	
	# Title
	var title = Label.new()
	title.text = "🎮 UNLOCKABLE GAMES"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Akashic TCG (always unlocked)
	var akashic_label = Label.new()
	akashic_label.text = "✅ Akashic TCG (Always Available)"
	akashic_label.add_theme_font_size_override("font_size", 14)
	akashic_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	vbox.add_child(akashic_label)
	
	# Code Breaker progress
	var code_breaker_vbox = VBoxContainer.new()
	code_breaker_vbox.add_theme_constant_override("separation", 5)
	
	var cb_label = Label.new()
	var current_xp = TutorialManager.total_xp
	var required_xp = TutorialManager.XP_THRESHOLDS["code_breaker"]
	var is_unlocked = TutorialManager.is_game_unlocked("code_breaker")
	
	if is_unlocked:
		cb_label.text = "✅ Code Breaker (Unlocked!)"
		cb_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	else:
		cb_label.text = "🔒 Code Breaker (Unlock at 500 XP)"
		cb_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	cb_label.add_theme_font_size_override("font_size", 14)
	code_breaker_vbox.add_child(cb_label)
	
	if not is_unlocked:
		var cb_progress = ProgressBar.new()
		cb_progress.max_value = required_xp
		cb_progress.value = current_xp
		cb_progress.custom_minimum_size = Vector2(360, 20)
		cb_progress.show_percentage = false
		code_breaker_vbox.add_child(cb_progress)
		
		var cb_progress_label = Label.new()
		cb_progress_label.text = "Progress: %d/%d XP (%.0f%%)" % [current_xp, required_xp, (float(current_xp) / required_xp) * 100.0]
		cb_progress_label.add_theme_font_size_override("font_size", 12)
		cb_progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		code_breaker_vbox.add_child(cb_progress_label)
	
	vbox.add_child(code_breaker_vbox)
	
	# Game 3 placeholder
	var game3_label = Label.new()
	var game3_unlocked = TutorialManager.is_game_unlocked("game_3")
	if game3_unlocked:
		game3_label.text = "✅ Mystery Game (Unlocked!)"
		game3_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	else:
		game3_label.text = "🔒 Mystery Game (Unlock at 1500 XP)"
		game3_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	game3_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(game3_label)
	
	unlock_panel.add_child(vbox)


func _animate_entrance() -> void:
	"""Animate UI elements on entrance"""
	# Fade in and slide buttons
	for btn in [beginner_btn, intermediate_btn, advanced_btn]:
		if btn:
			btn.modulate.a = 0
			btn.position.x -= 50
	
	if beginner_btn:
		var tween = create_tween()
		tween.tween_property(beginner_btn, "modulate:a", 1.0, 0.5).set_delay(0.1)
		tween.parallel().tween_property(beginner_btn, "position:x", beginner_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if intermediate_btn:
		var tween = create_tween()
		tween.tween_property(intermediate_btn, "modulate:a", 1.0, 0.5).set_delay(0.2)
		tween.parallel().tween_property(intermediate_btn, "position:x", intermediate_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if advanced_btn:
		var tween = create_tween()
		tween.tween_property(advanced_btn, "modulate:a", 1.0, 0.5).set_delay(0.3)
		tween.parallel().tween_property(advanced_btn, "position:x", advanced_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------
# BUTTON HOVER EFFECT (Scale animation)
# -------------------------
func _on_button_hover(level: String) -> void:
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return
		
	var hover_sfx = $HoverSound
	if hover_sfx and not hover_sfx.playing:
		hover_sfx.play()
	# Bounce scale animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.3)


# -------------------------
# LEVEL SELECTION (Main logic)
# -------------------------
func _on_level_selected(level: String) -> void:
	print("🎯 Level selected:", level)
	
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return
	
	# Click animation (press down → bounce back)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	
	await tween.finished
	
	# Show tutorial selection menu for this level
	_show_tutorial_menu(level)


# -------------------------
# SHOW TUTORIAL MENU (Selection Dialog)
# -------------------------
func _show_tutorial_menu(level: String) -> void:
	var tutorials: Array = []
	var level_int: int = 1
	
	match level:
		"beginner":
			level_int = 1
			tutorials = [
				{"name": "🎓 Cybersecurity Fundamentals (Start Here!)", "scene": "res://scene/tutorial_cyber_fundamentals.tscn", "id": "beginner_fundamentals"},
				{"name": "🌐 Network Basics", "scene": "res://scene/tutorial_network_basics.tscn", "id": "beginner_network"},
				{"name": "🔐 Password Fortress Defender", "scene": "res://scene/tutorial_password_basics.tscn", "id": "beginner_password"},
				{"name": "🦠 Malware Types Overview", "scene": "res://scene/tutorial_malware_types.tscn", "id": "beginner_malware"}
			]
		"intermediate":
			level_int = 2
			tutorials = [
				{"name": "🎣 Phishing Detection Lab", "scene": "res://scene/tutorial_phishing_lab.tscn", "id": "intermediate_phishing"},
				{"name": "🛡️ Interactive Defense Training", "scene": "res://scene/tutorial_advance_interactive.tscn", "id": "intermediate_defense"},
				{"name": "🔬 Advanced Malware Lab", "scene": "res://scene/malware_tutorial_menu.tscn", "id": "intermediate_lab"}
			]
		"advanced":
			level_int = 3
			tutorials = [
				{"name": "⚔️ Advanced Threat Scenarios", "scene": "res://scene/tutorial_advance.tscn", "id": "advanced_scenarios"},
				{"name": "🔐 Encryption", "scene": "res://scene/tutorial_encryption_basics.tscn", "id": "advanced_encryption"},
				{"name": "💀 Malware Research Lab", "scene": "res://scene/malware_tutorial_menu.tscn", "id": "advanced_lab"}
			]
	
	# Update Auth level
	Auth.current_level = level_int
	
	# Wait for TutorialManager data if not loaded
	if not TutorialManager.data_has_loaded:
		print("[Dialog] Waiting for TutorialManager data...")
		await TutorialManager.data_loaded
		print("[Dialog] TutorialManager data loaded, showing dialog...")
	
	# Create a custom Control instead of ConfirmationDialog for full styling control
	var overlay = Control.new()
	overlay.name = "TutorialMenuOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 99
	
	# Semi-transparent black background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	
	# Main dialog panel
	var dialog_panel = Panel.new()
	dialog_panel.custom_minimum_size = Vector2(680, 580)
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_top = 0.5
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_bottom = 0.5
	dialog_panel.offset_left = -340
	dialog_panel.offset_top = -290
	dialog_panel.offset_right = 340
	dialog_panel.offset_bottom = 290
	dialog_panel.z_index = 100
	
	# Custom StyleBox for the main panel (dark with cyan border)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.1, 0.15, 0.95)  # Dark blue-ish background
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0, 0.9, 1, 0.8)  # Cyan border
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0, 1, 1, 0.3)
	panel_style.shadow_size = 15
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	
	overlay.add_child(dialog_panel)
	
	# Add cyberpunk corner decorations
	_add_corner_decorations(dialog_panel)
	
	# Close button (X)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(630, 8)
	close_btn.size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0, 0))
	close_btn.z_index = 200
	
	# Create custom style for button
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.2, 0, 0, 0.3)
	close_style.border_width_left = 1
	close_style.border_width_top = 1
	close_style.border_width_right = 1
	close_style.border_width_bottom = 1
	close_style.border_color = Color(1, 0, 0, 0.5)
	close_style.corner_radius_top_left = 5
	close_style.corner_radius_top_right = 5
	close_style.corner_radius_bottom_left = 5
	close_style.corner_radius_bottom_right = 5
	close_btn.add_theme_stylebox_override("normal", close_style)
	
	var close_hover = close_style.duplicate()
	close_hover.bg_color = Color(0.4, 0, 0, 0.6)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	
	close_btn.pressed.connect(func(): 
		print("🔴 Close button pressed!")
		overlay.queue_free()
	)
	dialog_panel.add_child(close_btn)
	
	# Content container
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_top", 55)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(margin_container)
	
	# Main VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_child(main_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Choose Tutorial - Level %d Assessment" % level_int
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0, 1, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(title_label)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Complete tutorials to earn XP and unlock games!\nPassing score: 70% or higher"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.9, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(subtitle)
	
	# Separator line
	var separator = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0, 1, 1, 0.3)
	separator.add_theme_stylebox_override("separator", sep_style)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(separator)
	
	# Scrollable container for tutorials
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var tutorials_vbox = VBoxContainer.new()
	tutorials_vbox.add_theme_constant_override("separation", 12)
	tutorials_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tutorials_vbox)
	
	# Add tutorial cards
	for tutorial in tutorials:
		var card = _create_tutorial_card(tutorial, level_int, overlay)
		tutorials_vbox.add_child(card)
	
	# Add overlay to CanvasLayer to ensure it appears on top
	$CanvasLayer.add_child(overlay)
	
	# Animate entrance
	dialog_panel.modulate.a = 0
	dialog_panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(dialog_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_corner_decorations(panel: Panel) -> void:
	"""Add cyberpunk corner decorations to the panel"""
	var corner_size = 40
	var corner_thickness = 3
	var corner_color = Color(0, 1, 1, 1)  # Cyan
	var corner_length = 50
	
	# Function to create a corner decoration
	var create_corner = func(pos: Vector2, h_flip: bool, v_flip: bool):
		var corner = Control.new()
		corner.custom_minimum_size = Vector2(corner_length, corner_length)
		corner.position = pos
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Horizontal line
		var h_line = ColorRect.new()
		h_line.color = corner_color
		h_line.size = Vector2(corner_length, corner_thickness)
		h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if v_flip:
			h_line.position.y = corner_length - corner_thickness
		corner.add_child(h_line)
		
		# Vertical line
		var v_line = ColorRect.new()
		v_line.color = corner_color
		v_line.size = Vector2(corner_thickness, corner_length)
		v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if h_flip:
			v_line.position.x = corner_length - corner_thickness
		corner.add_child(v_line)
		
		# Add glow effect with additional lines
		var glow_color = Color(0, 1, 1, 0.3)
		
		var h_glow = ColorRect.new()
		h_glow.color = glow_color
		h_glow.size = Vector2(corner_length, corner_thickness + 4)
		h_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if v_flip:
			h_glow.position.y = corner_length - corner_thickness - 2
		else:
			h_glow.position.y = -2
		h_glow.z_index = -1
		corner.add_child(h_glow)
		
		var v_glow = ColorRect.new()
		v_glow.color = glow_color
		v_glow.size = Vector2(corner_thickness + 4, corner_length)
		v_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if h_flip:
			v_glow.position.x = corner_length - corner_thickness - 2
		else:
			v_glow.position.x = -2
		v_glow.z_index = -1
		corner.add_child(v_glow)
		
		return corner
	
	# Top-left corner
	panel.add_child(create_corner.call(Vector2(5, 5), false, false))
	
	# Top-right corner
	panel.add_child(create_corner.call(Vector2(panel.custom_minimum_size.x - corner_length - 5, 5), true, false))
	
	# Bottom-left corner
	panel.add_child(create_corner.call(Vector2(5, panel.custom_minimum_size.y - corner_length - 5), false, true))
	
	# Bottom-right corner
	panel.add_child(create_corner.call(Vector2(panel.custom_minimum_size.x - corner_length - 5, panel.custom_minimum_size.y - corner_length - 5), true, true))


func _create_tutorial_card(tutorial: Dictionary, level_int: int, overlay: Control) -> PanelContainer:
	"""Create a styled tutorial card"""
	var tutorial_id: String = tutorial["id"]
	var is_completed: bool = TutorialManager.completed_tutorials.has(tutorial_id)
	var metadata = TUTORIAL_METADATA.get(tutorial_id, {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3})
	
	# Card container
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(580, 95)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var card_style = StyleBoxFlat.new()
	if is_completed:
		card_style.bg_color = Color(0.05, 0.2, 0.1, 0.9)  # Darker green background
		card_style.border_color = Color(0, 1, 0.5, 1.0)  # Bright green border
		card_style.shadow_color = Color(0, 1, 0.5, 0.4)  # Green glow
		card_style.shadow_size = 8
	else:
		card_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
		card_style.border_color = Color(0, 1, 1, 0.6)
	
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	
	# Card content with margin
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 15)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_right", 15)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = tutorial["name"]
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(title_label)
	
	# Info row
	var info_hbox = HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 25)
	
	var time_label = Label.new()
	time_label.text = "⏱️ " + metadata["time"]
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	info_hbox.add_child(time_label)
	
	var xp_label = Label.new()
	xp_label.text = "💎 " + metadata["xp_range"]
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.add_theme_color_override("font_color", Color(1, 0.843, 0))
	info_hbox.add_child(xp_label)
	
	var difficulty_label = Label.new()
	var stars = ""
	for i in metadata["difficulty"]:
		stars += "★"
	for i in (5 - metadata["difficulty"]):
		stars += "☆"
	difficulty_label.text = "📊 " + stars
	difficulty_label.add_theme_font_size_override("font_size", 13)
	difficulty_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	info_hbox.add_child(difficulty_label)
	
	card_vbox.add_child(info_hbox)
	
	# Button or status
	if is_completed:
		var result = TutorialManager.completed_tutorials[tutorial_id]
		var percentage: float = result.get("percentage", 0.0)
		
		var status_label = Label.new()
		status_label.text = "✅ COMPLETED - %.0f%% | 🏆 XP earned: %d" % [percentage, result.get("xp_earned", 0)]
		status_label.add_theme_font_size_override("font_size", 14)
		status_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		card_vbox.add_child(status_label)
	else:
		var btn = Button.new()
		btn.text = "START TUTORIAL →"
		btn.custom_minimum_size = Vector2(200, 35)
		btn.add_theme_color_override("font_color", Color(0, 1, 1))
		btn.add_theme_font_size_override("font_size", 14)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0, 0.3, 0.4, 0.5)
		btn_style.border_width_left = 2
		btn_style.border_width_top = 2
		btn_style.border_width_right = 2
		btn_style.border_width_bottom = 2
		btn_style.border_color = Color(0, 1, 1, 0.8)
		btn_style.corner_radius_top_left = 5
		btn_style.corner_radius_top_right = 5
		btn_style.corner_radius_bottom_left = 5
		btn_style.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0, 0.5, 0.6, 0.7)
		btn.add_theme_stylebox_override("hover", btn_hover)
		
		btn.pressed.connect(func():
			overlay.queue_free()
			get_tree().set_meta("tutorial_id", tutorial_id)
			get_tree().set_meta("tutorial_level", level_int)
			_save_level_and_navigate(level_int, tutorial["scene"])
		)
		
		card_vbox.add_child(btn)
	
	return card


# -------------------------
# SAVE LEVEL TO FIRESTORE + NAVIGATE TO TUTORIAL
# -------------------------
func _save_level_and_navigate(level_int: int, tutorial_scene: String) -> void:
	print("💾 Saving level to Firestore...")
	
	# Build Firestore PATCH request (only update 'level' field)
	var url: String = "%s/users/%s?updateMask.fieldPaths=level" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	var body := {
		"fields": {
			"level": {"integerValue": level_int}
		}
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		var text: String = body_response.get_string_from_utf8()
		
		if code == 200:
			print("✅ Level saved successfully:", level_int)
		else:
			push_error("❌ Failed to save level (%s): %s" % [code, text])
		
		# Navigate to tutorial scene (even if save fails)
		_transition_to_tutorial(tutorial_scene)
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()
		_transition_to_tutorial(tutorial_scene)


# -------------------------
# TRANSITION TO TUTORIAL (Zoom + Fade animation)
# -------------------------
func _transition_to_tutorial(scene_path: String) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	
	# Zoom in + fade out
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	var bgm = $BackgroundMusic
	if bgm:
		tween.tween_property(bgm, "volume_db", -80, 0.3)
	await tween.finished
	
	# Navigate to tutorial scene
	get_tree().change_scene_to_file(scene_path)


# -------------------------
# MENU BUTTON (Placeholder)
# -------------------------
# -------------------------
# MENU BUTTON (Opens Settings)
# -------------------------
func _on_menu_pressed() -> void:
	print("🍔 Menu button pressed - Opening settings...")
	
	# Load the settings panel scene
	var settings_scene = load("res://scene/SettingsPanel.tscn")
	if not settings_scene:
		push_error("❌ Failed to load settings_panel.tscn")
		return
	
	var settings_panel = settings_scene.instantiate()
	
	# Set the background music as the target for volume control
	var bgm = $BackgroundMusic
	if bgm and settings_panel.has_method("set_target_music"):
		settings_panel.set_target_music(bgm)
	
	# Add settings panel to the scene
	$CanvasLayer.add_child(settings_panel)
	
	# Center the settings panel on screen
	# Center the settings panel on screen
	if settings_panel.has_node("Window"):
		var window = settings_panel.get_node("Window")
		var viewport_size = get_viewport_rect().size
		window.position = (viewport_size - window.size) / 2

# -------------------------
# XP AND RANK DISPLAY
# -------------------------
func _update_xp_display() -> void:
	print("[ModeSelection] ========== UPDATING XP DISPLAY ==========")
	print("[ModeSelection] TutorialManager.total_xp: %d" % TutorialManager.total_xp)
	print("[ModeSelection] TutorialManager.data_has_loaded: %s" % TutorialManager.data_has_loaded)
	
	var rank: Dictionary = TutorialManager.get_rank()
	var current_xp = TutorialManager.total_xp
	
	if xp_label:
		xp_label.text = ": %d" % current_xp
		xp_label.add_theme_color_override("font_color", Color(0.984, 0.992, 0.910, 1))  # #fbfde8
		print("[ModeSelection] ✅ XP Label updated to: %s" % xp_label.text)
	else:
		print("[ModeSelection] ⚠️ xp_label not found!")
	
	if rank_icon:
		var icon_texture = load(rank["icon"])
		if icon_texture:
			rank_icon.texture = icon_texture
			print("[ModeSelection] ✅ Rank Icon loaded: %s" % rank["icon"])
		else:
			print("[ModeSelection] ⚠️ Failed to load rank icon: %s" % rank["icon"])
	else:
		print("[ModeSelection] ⚠️ rank_icon not found!")
	
	if rank_label:
		rank_label.text = rank["name"]
		rank_label.add_theme_color_override("font_color", rank["color"])
		rank_label.tooltip_text = "Progress: %.0f%% | XP to next rank: %d" % [rank["progress"], rank["xp_to_next"]]
		print("[ModeSelection] ✅ Rank Label updated to: %s" % rank_label.text)
	else:
		print("[ModeSelection] ⚠️ rank_label not found!")
	
	# Update XP Progress Bar
	if xp_progress_bar:
		var next_rank_xp = rank["max_xp"] if rank["max_xp"] != 999999 else rank["min_xp"] + 1000
		xp_progress_bar.max_value = next_rank_xp
		xp_progress_bar.value = current_xp
		
		# Animate progress bar fill
		var tween = create_tween()
		tween.tween_property(xp_progress_bar, "value", current_xp, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Update unlock panel
	_populate_unlock_panel()


# -------------------------
# PROFILE BUTTON
# -------------------------
func _on_profile_pressed() -> void:
	print("👤 Opening profile...")
	_fade_out_music_and_transition("res://scene/landing.tscn")


# -------------------------
# BACK BUTTON
# -------------------------
func _on_back_pressed() -> void:
		_fade_out_music_and_transition("res://scene/landing.tscn")
