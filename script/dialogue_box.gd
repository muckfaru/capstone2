extends Control

signal dialogue_finished
signal dialogue_advanced

@onready var dialogue_panel = $DialoguePanel
@onready var margin_container = $DialoguePanel/MarginContainer
@onready var name_label = $DialoguePanel/MarginContainer/VBoxContainer/NameLabel
@onready var text_label = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel
@onready var indicator = $DialoguePanel/MarginContainer/VBoxContainer/HBoxContainer/IndicatorPanel
@onready var blink_timer = $BlinkTimer

var dialogue_lines = []
var current_line = 0
var is_typing = false
var current_text = ""
var char_index = 0
var typing_speed = 0.03
var can_advance = true  # Control whether player can advance

func _ready():
	visible = false
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	
	# Set up dialogue box sizing and positioning
	setup_dialogue_box()

func setup_dialogue_box():
	# Make dialogue box wider and better positioned
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	anchor_left = 0.0
	anchor_right = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Position and size - centered at bottom with margins
	offset_top = -180  # Height from bottom
	offset_bottom = -20  # Margin from bottom edge
	offset_left = 150  # Margin from left
	offset_right = -150  # Margin from right
	
	# Set minimum size for dialogue panel
	if dialogue_panel:
		dialogue_panel.custom_minimum_size = Vector2(900, 140)
	
	# Increase margins for better text spacing
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 40)
		margin_container.add_theme_constant_override("margin_right", 40)
		margin_container.add_theme_constant_override("margin_top", 30)
		margin_container.add_theme_constant_override("margin_bottom", 30)
	
	# Set up text label properties
	if text_label:
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.add_theme_font_size_override("font_size", 18)  # Larger, more readable text
		text_label.add_theme_constant_override("line_spacing", 6)  # Space between lines
	
	# Set up name label
	if name_label:
		name_label.add_theme_font_size_override("font_size", 20)  # Slightly larger name
		name_label.add_theme_constant_override("outline_size", 8)  # Add outline for readability

func _input(event):
	if not visible or not can_advance:
		return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed):
		if is_typing:
			# Skip typing animation
			finish_typing()
		else:
			# Move to next line
			next_line()

func start_dialogue(lines: Array, character_name: String = ""):
	dialogue_lines = lines
	current_line = 0
	visible = true
	can_advance = true
	
	# Set character name and color
	name_label.text = character_name
	name_label.visible = character_name != ""
	
	# Color code based on character
	if character_name == "Anonymouse":
		name_label.add_theme_color_override("font_color", Color(1, 0.5, 0))  # Orange
	elif character_name == "You":
		name_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))  # Green
	elif character_name == "???":
		name_label.add_theme_color_override("font_color", Color(1, 0, 0.5))  # Pink/Red
	else:
		name_label.add_theme_color_override("font_color", Color(0, 1, 1))  # Cyan
	
	show_line(0)

func show_line(index: int):
	if index >= dialogue_lines.size():
		end_dialogue()
		return
	
	current_line = index
	current_text = dialogue_lines[index]
	char_index = 0
	is_typing = true
	text_label.text = ""
	indicator.visible = false
	
	_type_character()

func _type_character():
	if char_index < current_text.length():
		text_label.text += current_text[char_index]
		char_index += 1
		
		# Play typing sound effect here if you have one
		# $TypingSound.play()
		
		await get_tree().create_timer(typing_speed).timeout
		_type_character()
	else:
		finish_typing()

func finish_typing():
	is_typing = false
	text_label.text = current_text
	char_index = current_text.length()
	indicator.visible = true

func next_line():
	dialogue_advanced.emit()
	show_line(current_line + 1)

func end_dialogue():
	# Only hide if we're not waiting for choices
	if not get_parent().get("is_waiting_for_choice"):
		visible = false
	dialogue_finished.emit()

func _on_blink_timer_timeout():
	if indicator.visible and not is_typing:
		indicator.modulate.a = 0.3 if indicator.modulate.a > 0.5 else 1.0

# Helper functions for external control
func pause_input():
	"""Prevent player from advancing dialogue"""
	can_advance = false

func resume_input():
	"""Allow player to advance dialogue again"""
	can_advance = true

func keep_visible_for_choices():
	"""Keep dialogue visible but disable input - used when showing choices"""
	can_advance = false
	if indicator:
		indicator.visible = false

func restore_after_choices():
	"""Restore dialogue box to normal state after choices"""
	can_advance = true
	if indicator and not is_typing:
		indicator.visible = true