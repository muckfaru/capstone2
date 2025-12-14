# PokemonStyleWelcomeUI.gd
# Attach this to the PokemonStyleWelcomeUI CanvasLayer in landing.tscn
extends CanvasLayer

# UI References
@onready var dialogue_box: Panel = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/MarginContainer/DialogueText
@onready var continue_indicator: Label = $DialogueBox/ContinueIndicator
@onready var portrait: TextureRect = $DialogueBox/Portrait/TextureRect
@onready var overlay: ColorRect = $Overlay

# Store original styles
var original_dialogue_style: StyleBoxFlat
var original_indicator_text := "▼ Tap the screen"
var original_indicator_color := Color(1, 1, 0, 1)  # Yellow
var original_portrait_texture: Texture2D  # ✅ Store original portrait image

# Tutorial data
var tutorial_steps := [
	{
		"text": "Welcome to Cyber Arena, trainer! I'm your guide to this digital world.",
		"highlight": null,
		"action": null
	},
	{
		"text": "This is your HOME screen. Here you can see the latest news and updates!",
		"highlight": "HomeNavigate",
		"action": "show_home"
	},
	{
		"text": "Ready to battle? Click GAME to see all available games you can play!",
		"highlight": "GameNavigate",
		"action": "show_games"
	},
	{
		"text": "Check the RANKING to see how you stack up against other players!",
		"highlight": "RankingNavigate",
		"action": null
	},
	{
		"text": "Your PROFILE shows your stats, XP, and rank. Keep playing to level up!",
		"highlight": "ProfileNavigate",
		"action": "show_profile"
	},
	{
		"text": "Visit MODULE anytime to complete tutorials and earn XP to unlock new games!",
		"highlight": "ModuleNavigate",
		"action": null
	},
	{
		"text": "New alert! Our systems has under attack! User data is at risk! the virus is spreading fast!",
		"highlight": null,
		"action": "alert_red_and_change_image"
	},
	{
		"text": "This is your first mission,  can you handle it?",
		"highlight": null,
		"action": "mission_prompt"
	},
	{
		"text": "I send the file immediately. review it, execute the required tasks, and ensure the mission is completed. I await the data.",
		"highlight": null,
		"action": "reset_colors_and_restore_image"
	},
	{
		"text": "That's all for now! Good luck on your journey, trainer!",
		"highlight": null,
		"action": "complete"
	}
]

var current_step := 0
var is_typing := false
var char_index := 0
var typing_speed := 0.03
var current_text := ""

# Highlight nodes
var highlighted_node: Control = null
var highlight_rect: ReferenceRect = null

# ✅ Track active tweens to prevent memory leaks
var active_tweens: Array[Tween] = []

signal tutorial_completed

func _ready() -> void:
	print("[PokemonWelcomeUI] _ready() called")
	
	# Initially hide everything
	visible = false
	
	# Store original dialogue box style
	if dialogue_box and dialogue_box.get_theme_stylebox("panel"):
		original_dialogue_style = dialogue_box.get_theme_stylebox("panel").duplicate()
	
	# ✅ Store original portrait texture
	if portrait and portrait.texture:
		original_portrait_texture = portrait.texture
		print("[PokemonWelcomeUI] Original portrait saved")
	
	# Setup overlay
	if overlay:
		overlay.color = Color(0, 0, 0, 0.7)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.gui_input.connect(_on_overlay_input)
		print("[PokemonWelcomeUI] Overlay configured")
	else:
		push_error("[PokemonWelcomeUI] Overlay not found!")
	
	# Setup dialogue box
	if dialogue_box:
		dialogue_box.mouse_filter = Control.MOUSE_FILTER_STOP
		print("[PokemonWelcomeUI] DialogueBox configured")
	else:
		push_error("[PokemonWelcomeUI] DialogueBox not found!")
	
	# Setup continue indicator animation
	if continue_indicator:
		_animate_continue_indicator()
		print("[PokemonWelcomeUI] ContinueIndicator configured")
	else:
		push_error("[PokemonWelcomeUI] ContinueIndicator not found!")
	
	print("[PokemonWelcomeUI] Ready complete - waiting for start_tutorial() call")

func start_tutorial() -> void:
	"""Call this to start the tutorial"""
	print("[PokemonWelcomeUI] ========== START TUTORIAL CALLED ==========")
	print("[PokemonWelcomeUI] Overlay exists: ", overlay != null)
	print("[PokemonWelcomeUI] DialogueBox exists: ", dialogue_box != null)
	print("[PokemonWelcomeUI] DialogueText exists: ", dialogue_text != null)
	
	visible = true
	
	if overlay:
		overlay.visible = true
		print("[PokemonWelcomeUI] Overlay made visible")
	
	if dialogue_box:
		dialogue_box.visible = true
		print("[PokemonWelcomeUI] DialogueBox made visible")
	
	current_step = 0
	_show_step(current_step)
	print("[PokemonWelcomeUI] Tutorial started successfully!")

func _show_step(step: int) -> void:
	if step >= tutorial_steps.size():
		_complete_tutorial()
		return
	
	var step_data = tutorial_steps[step]
	
	# Clear previous highlight
	_clear_highlight()
	
	# Execute action if any
	if step_data.has("action") and step_data["action"] != null:
		_execute_action(step_data["action"])
	
	# Show new text
	current_text = step_data["text"]
	_start_typing()
	
	# Highlight UI element if specified
	if step_data.has("highlight") and step_data["highlight"] != null:
		_highlight_element(step_data["highlight"])

func _start_typing() -> void:
	is_typing = true
	char_index = 0
	dialogue_text.text = ""
	continue_indicator.visible = false
	_type_next_char()

func _type_next_char() -> void:
	if char_index < current_text.length():
		dialogue_text.text += current_text[char_index]
		char_index += 1
		await get_tree().create_timer(typing_speed).timeout
		_type_next_char()
	else:
		is_typing = false
		continue_indicator.visible = true

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()

func _advance_dialogue() -> void:
	if is_typing:
		# Skip typing animation
		dialogue_text.text = current_text
		is_typing = false
		char_index = current_text.length()
		continue_indicator.visible = true
	else:
		# Move to next step
		current_step += 1
		_show_step(current_step)

func _highlight_element(element_name: String) -> void:
	# Get the navigation panel from Landing scene
	var landing = get_parent()
	if not landing:
		push_error("[PokemonWelcomeUI] Cannot find Landing parent")
		return
	
	var nav_panel = landing.get_node_or_null("NavigationPanel/HBoxContainer")
	if not nav_panel:
		push_error("[PokemonWelcomeUI] Cannot find NavigationPanel")
		return
	
	var target_node = nav_panel.get_node_or_null(element_name)
	if not target_node:
		push_error("[PokemonWelcomeUI] Cannot find element: %s" % element_name)
		return
	
	highlighted_node = target_node
	
	# Create highlight rectangle
	highlight_rect = ReferenceRect.new()
	highlight_rect.border_color = Color(0.0, 0.8, 1.0)  # Cyan
	highlight_rect.border_width = 3.0
	highlight_rect.editor_only = false
	
	# Position highlight around the button
	var global_pos = target_node.global_position
	var size = target_node.size
	
	highlight_rect.position = global_pos - Vector2(5, 5)
	highlight_rect.size = size + Vector2(10, 10)
	
	add_child(highlight_rect)
	
	# Animate highlight
	_animate_highlight()

func _clear_highlight() -> void:
	# ✅ Kill any active tweens before clearing highlight
	_kill_all_tweens()
	
	if highlight_rect:
		highlight_rect.queue_free()
		highlight_rect = null
	highlighted_node = null

# ✅ FIX: Use finite loops instead of infinite loops
func _animate_highlight() -> void:
	if not highlight_rect:
		return
	
	var tween = create_tween()
	tween.set_loops(100)  # ✅ FIXED: Use finite loops (100 loops = ~100 seconds)
	tween.tween_property(highlight_rect, "modulate:a", 0.3, 0.5)
	tween.tween_property(highlight_rect, "modulate:a", 1.0, 0.5)
	
	# Track tween for cleanup
	active_tweens.append(tween)
	tween.finished.connect(func(): active_tweens.erase(tween))

# ✅ FIX: Use finite loops instead of infinite loops
func _animate_continue_indicator() -> void:
	if not continue_indicator:
		return
	
	var tween = create_tween()
	tween.set_loops(100)  # ✅ FIXED: Use finite loops
	tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)
	
	# Track tween for cleanup
	active_tweens.append(tween)
	tween.finished.connect(func(): active_tweens.erase(tween))

# ✅ NEW: Kill all active tweens
func _kill_all_tweens() -> void:
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()

func _execute_action(action: String) -> void:
	var landing = get_parent()
	if not landing:
		return
	
	var panel_paths := {
		"home": "HomePanel",
		"game": "GameSelectPanel",
		"ranking": "RankingPanel",
		"profile": "ProfilePanel"
	}
	
	match action:
		"show_home":
			landing._show_panel(panel_paths, "home")
		"show_games":
			landing._show_panel(panel_paths, "game")
		"show_profile":
			landing._show_panel(panel_paths, "profile")
		"alert_red_and_change_image":
			_trigger_alert_effect()
			_change_portrait_to_mission_file()
		"mission_prompt":
			_change_indicator_to_confused()
		"reset_colors_and_restore_image":
			_reset_to_normal_colors()
			_restore_original_portrait()
		"complete":
			_complete_tutorial()

func _trigger_alert_effect() -> void:
	"""Make dialogue box red and shake screen"""
	print("[PokemonWelcomeUI] 🚨 ALERT TRIGGERED!")
	
	# Change dialogue box to red
	if dialogue_box:
		var red_style = original_dialogue_style.duplicate() if original_dialogue_style else StyleBoxFlat.new()
		red_style.border_color = Color(1, 0, 0, 1)  # Red border
		red_style.bg_color = Color(0.2, 0.05, 0.05, 0.95)  # Dark red background
		dialogue_box.add_theme_stylebox_override("panel", red_style)
	
	# Screen shake effect
	_shake_screen(0.8, 10.0)

func _shake_screen(duration: float, intensity: float) -> void:
	"""Shake the dialogue box"""
	if not dialogue_box:
		return
	
	var original_position = dialogue_box.position
	var shake_timer = 0.0
	var shake_interval = 0.05
	
	while shake_timer < duration:
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		dialogue_box.position = original_position + shake_offset
		await get_tree().create_timer(shake_interval).timeout
		shake_timer += shake_interval
	
	# Reset to original position
	dialogue_box.position = original_position

func _change_portrait_to_mission_file() -> void:
	"""Change the portrait to show mission file icon"""
	print("[PokemonWelcomeUI] 📁 Changing portrait to mission file")
	
	if not portrait:
		push_error("[PokemonWelcomeUI] Portrait not found!")
		return
	
	# Load mission file image - CHANGE THIS PATH TO YOUR MISSION FILE IMAGE
	var mission_texture = load("res://asset/icons/mission_file.png")  # ← Change this!
	
	if mission_texture:
		portrait.texture = mission_texture
		print("[PokemonWelcomeUI] ✅ Portrait changed to mission file")
	else:
		push_warning("[PokemonWelcomeUI] ⚠️ Mission file image not found at path")

func _restore_original_portrait() -> void:
	"""Restore the original portrait image"""
	print("[PokemonWelcomeUI] 🔄 Restoring original portrait")
	
	if not portrait:
		push_error("[PokemonWelcomeUI] Portrait not found!")
		return
	
	if original_portrait_texture:
		portrait.texture = original_portrait_texture
		print("[PokemonWelcomeUI] ✅ Original portrait restored")
	else:
		push_warning("[PokemonWelcomeUI] ⚠️ No original portrait texture saved!")

func _change_indicator_to_confused() -> void:
	"""Change continue indicator to red confused text"""
	print("[PokemonWelcomeUI] 😰 Mission prompt - player confused!")
	
	if continue_indicator:
		continue_indicator.text = "I dont know what to do"
		continue_indicator.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # Red

func _reset_to_normal_colors() -> void:
	"""Reset dialogue box and indicator to normal blue/yellow"""
	print("[PokemonWelcomeUI] ✅ Resetting to normal colors")
	
	# Reset dialogue box to original blue style
	if dialogue_box and original_dialogue_style:
		dialogue_box.add_theme_stylebox_override("panel", original_dialogue_style)
	
	# Reset continue indicator
	if continue_indicator:
		continue_indicator.text = original_indicator_text
		continue_indicator.add_theme_color_override("font_color", original_indicator_color)

func _complete_tutorial() -> void:
	print("[PokemonWelcomeUI] ========== COMPLETING TUTORIAL ==========")
	
	# ✅ Kill all tweens before completing
	_kill_all_tweens()
	_clear_highlight()
	
	# Show completion message
	dialogue_text.text = "Tutorial Complete! You're ready to explore Cyber Arena!"
	continue_indicator.visible = false
	
	# Save tutorial completion to Firestore
	_mark_tutorial_complete()
	
	# Hide after a delay
	await get_tree().create_timer(2.0).timeout
	
	# ✅ Kill any remaining tweens one more time
	_kill_all_tweens()
	
	hide()
	
	print("[PokemonWelcomeUI] 🎉 Emitting tutorial_completed signal")
	tutorial_completed.emit()
	print("[PokemonWelcomeUI] ✅ Tutorial completed!")

func _mark_tutorial_complete() -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[PokemonWelcomeUI] Cannot save - user not logged in")
		return
	
	var firestore_url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=welcome_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"welcome_tutorial_completed": { "booleanValue": true }
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[PokemonWelcomeUI] ✅ Tutorial completion saved to Firestore")
		else:
			push_error("[PokemonWelcomeUI] ❌ Failed to save tutorial completion")
	)
	
	var err = http.request(firestore_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("[PokemonWelcomeUI] HTTP request failed: %s" % err)
		http.queue_free()

# ✅ Cleanup on exit
func _exit_tree() -> void:
	_kill_all_tweens()
	print("[PokemonWelcomeUI] Cleaned up all tweens on exit")
