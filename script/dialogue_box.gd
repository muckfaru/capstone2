extends Control

signal dialogue_finished
signal dialogue_advanced

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

func _ready():
	visible = false
	blink_timer.timeout.connect(_on_blink_timer_timeout)

func _input(event):
	if not visible:
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
	name_label.text = character_name
	name_label.visible = character_name != ""
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
	visible = false
	dialogue_finished.emit()

func _on_blink_timer_timeout():
	if indicator.visible and not is_typing:
		indicator.modulate.a = 0.3 if indicator.modulate.a > 0.5 else 1.0