extends Panel

signal confirmed

@onready var label = $MarginContainer/VBoxContainer/Label
@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)

func _input(event):
	if visible and event.is_action_pressed("ui_accept"):
		_on_continue_pressed()

func _on_continue_pressed():
	hide()
	confirmed.emit()