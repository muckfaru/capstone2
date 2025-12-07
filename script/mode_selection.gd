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
				{"name": "🐴 Trojan Horse Analysis", "scene": "res://scene/malware_trojan_tutorial.tscn", "id": "intermediate_trojan"},
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
	
	# Create selection dialog
	var dialog := ConfirmationDialog.new()
	dialog.title = "Choose Tutorial - Level %d Assessment" % level_int
	dialog.dialog_text = ""  # Clear default text to avoid overlap
	dialog.get_ok_button().visible = false
	dialog.get_cancel_button().text = "Back"
	dialog.min_size = Vector2(600, 500)  # Set minimum dialog size
	
	# Create main container with proper margins
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	
	# Create vertical container for all content
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	
	# Add header label
	var header_label := Label.new()
	header_label.text = "Complete tutorials to earn XP and unlock games!\nPassing score: 70% or higher"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(header_label)
	
	# Add separator
	var separator := HSeparator.new()
	main_vbox.add_child(separator)
	
	# Create vertical list of tutorial cards
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	for tutorial in tutorials:
		var tutorial_id: String = tutorial["id"]
		var is_completed: bool = TutorialManager.completed_tutorials.has(tutorial_id)
		var metadata = TUTORIAL_METADATA.get(tutorial_id, {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3})
		
		# Create card container
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.05, 0.1, 0.8) if not is_completed else Color(0.1, 0.2, 0.1, 0.8)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0, 1, 1, 0.6) if not is_completed else Color(0, 1, 0.5, 0.8)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", card_style)
		
		# Card content
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 5)
		
		# Title row
		var title_label = Label.new()
		title_label.text = tutorial["name"]
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.add_theme_color_override("font_color", Color.WHITE)
		card_vbox.add_child(title_label)
		
		# Info row (time + XP)
		var info_hbox = HBoxContainer.new()
		info_hbox.add_theme_constant_override("separation", 20)
		
		var time_label = Label.new()
		time_label.text = "⏱️ " + metadata["time"]
		time_label.add_theme_font_size_override("font_size", 12)
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1))
		info_hbox.add_child(time_label)
		
		var xp_info_label = Label.new()
		xp_info_label.text = "💎 " + metadata["xp_range"]
		xp_info_label.add_theme_font_size_override("font_size", 12)
		xp_info_label.add_theme_color_override("font_color", Color(1, 0.843, 0))
		info_hbox.add_child(xp_info_label)
		
		var difficulty_label = Label.new()
		var stars = ""
		for i in metadata["difficulty"]:
			stars += "★"
		for i in (5 - metadata["difficulty"]):
			stars += "☆"
		difficulty_label.text = "📊 " + stars
		difficulty_label.add_theme_font_size_override("font_size", 12)
		difficulty_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		info_hbox.add_child(difficulty_label)
		
		card_vbox.add_child(info_hbox)
		
		# Status row
		var btn := Button.new()
		if is_completed:
			var result = TutorialManager.completed_tutorials[tutorial_id]
			var percentage: float = result.get("percentage", 0.0)
			btn.text = "✅ COMPLETED - %.0f%%" % percentage
			btn.disabled = true
			
			var status_label = Label.new()
			status_label.text = "🏆 XP earned: %d" % result.get("xp_earned", 0)
			status_label.add_theme_font_size_override("font_size", 11)
			status_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
			card_vbox.add_child(status_label)
		else:
			btn.text = "START TUTORIAL →"
			btn.add_theme_color_override("font_color", Color(0, 1, 1))
		
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(func():
			dialog.queue_free()
			# Store tutorial metadata for result tracking
			get_tree().set_meta("tutorial_id", tutorial_id)
			get_tree().set_meta("tutorial_level", level_int)
			_save_level_and_navigate(level_int, tutorial["scene"])
		)
		card_vbox.add_child(btn)
		
		card.add_child(card_vbox)
		vbox.add_child(card)
	
	main_vbox.add_child(vbox)
	margin_container.add_child(main_vbox)
	dialog.add_child(margin_container)
	add_child(dialog)
	dialog.popup_centered()


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
