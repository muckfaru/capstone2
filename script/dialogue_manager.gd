extends Node

var dialogue_box_scene = preload("res://ui/dialogue_box.tscn")
var dialogue_box = null
var is_dialogue_active = false

# Choice system
var choice_container: VBoxContainer = null
var selected_choice: int = -1
var is_waiting_for_choice: bool = false

signal dialogue_finished
signal choice_made(choice_index: int)

func _ready():
	# Create dialogue box and add to scene tree
	dialogue_box = dialogue_box_scene.instantiate()
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	
	# Create choice container
	create_choice_system()

func create_choice_system():
	# Choice container - positioned on RIGHT SIDE, middle-right area
	choice_container = VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	
	# Position on the RIGHT side, vertically centered
	choice_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	choice_container.anchor_left = 1.0
	choice_container.anchor_right = 1.0
	choice_container.anchor_top = 0.5
	choice_container.anchor_bottom = 0.5
	choice_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	choice_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Right side positioning - wider buttons, middle of screen
	choice_container.offset_left = -420  # 420px from right edge (wider to fit more text)
	choice_container.offset_right = -20   # 20px margin from edge
	choice_container.offset_top = -150    # Centered vertically
	choice_container.offset_bottom = 120  # Centered vertically
	
	choice_container.add_theme_constant_override("separation", 15)
	choice_container.visible = false
	choice_container.z_index = 150
	choice_container.mouse_filter = Control.MOUSE_FILTER_STOP

func show_dialogue(lines: Array, character_name: String = "You"):
	if not dialogue_box.is_inside_tree():
		get_tree().root.add_child(dialogue_box)
	
	is_dialogue_active = true
	dialogue_box.start_dialogue(lines, character_name)
func show_choices(question: String, choices: Array) -> int:
	# IMPORTANT: Keep dialogue box visible and prevent it from hiding
	if dialogue_box:
		# Stop the dialogue box from hiding itself
		dialogue_box.visible = true
		dialogue_box.keep_visible_for_choices()
		
		# Disconnect the finished signal temporarily to prevent auto-hiding
		if dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			dialogue_box.dialogue_finished.disconnect(_on_dialogue_finished)
	
	# Make sure mouse is visible for clicking
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show choices on RIGHT SIDE
	if not choice_container.is_inside_tree():
		get_tree().root.add_child(choice_container)
	
	# Clear previous choices
	for child in choice_container.get_children():
		child.queue_free()
	
	# Create choice buttons with ACTUAL choice text
	for i in range(choices.size()):
		var button = Button.new()
		# Show the actual choice text with number
		button.text = str(i + 1) + ". " + choices[i]
		button.custom_minimum_size = Vector2(380, 60)  # Wider and taller buttons
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Wrap long text
		
		# Style - compact cyan bordered buttons
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
		normal_style.border_color = Color(0, 0.9, 1, 0.85)
		normal_style.border_width_left = 3
		normal_style.border_width_right = 3
		normal_style.border_width_top = 3
		normal_style.border_width_bottom = 3
		normal_style.corner_radius_top_left = 10
		normal_style.corner_radius_top_right = 10
		normal_style.corner_radius_bottom_left = 10
		normal_style.corner_radius_bottom_right = 10
		normal_style.content_margin_left = 20
		normal_style.content_margin_right = 20
		normal_style.content_margin_top = 15
		normal_style.content_margin_bottom = 15
		
		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.1, 0.15, 0.22, 1)
		hover_style.border_color = Color(0, 1, 1, 1)
		hover_style.border_width_left = 4
		hover_style.border_width_right = 4
		hover_style.border_width_top = 4
		hover_style.border_width_bottom = 4
		
		var pressed_style = hover_style.duplicate()
		pressed_style.bg_color = Color(0, 0.7, 0.9, 0.4)
		
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.add_theme_stylebox_override("focus", hover_style)
		button.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		button.add_theme_color_override("font_pressed_color", Color(0, 1, 1))
		button.add_theme_font_size_override("font_size", 16)  # Slightly larger font
		
		# Connect button press
		button.pressed.connect(_on_choice_selected.bind(i))
		
		choice_container.add_child(button)
		
		# Make sure button is ready
		await get_tree().process_frame
	
	choice_container.visible = true
	is_waiting_for_choice = true
	is_dialogue_active = true
	selected_choice = -1
	
	print("Waiting for player to choose...")
	
	# Wait for choice to be made
	while selected_choice == -1:
		await get_tree().process_frame
	
	print("Choice made: ", selected_choice)
	
	# Hide choices
	choice_container.visible = false
	is_waiting_for_choice = false
	
	# Reconnect the signal
	if dialogue_box and not dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	
	# Re-enable dialogue box input
	if dialogue_box:
		dialogue_box.restore_after_choices()
	
	# Brief pause before returning choice
	await get_tree().create_timer(0.2).timeout
	
	return selected_choice
	
func _on_choice_selected(choice_index: int):
	print("Button clicked: ", choice_index)
	selected_choice = choice_index
	emit_signal("choice_made", choice_index)

func hide_dialogue():
	"""Force hide the dialogue box"""
	if dialogue_box and dialogue_box.visible:
		dialogue_box.visible = false
	
	# Also hide choices if visible
	if choice_container and choice_container.visible:
		choice_container.visible = false
		is_waiting_for_choice = false
	
	is_dialogue_active = false

func _on_dialogue_finished():
	# Don't set inactive if we're waiting for a choice
	if not is_waiting_for_choice:
		is_dialogue_active = false

func is_active() -> bool:
	return is_dialogue_active or is_waiting_for_choice