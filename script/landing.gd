extends Control

@onready var logout_button: Button = $LogoutButton

func _ready() -> void:
	logout_button.pressed.connect(_on_logout_pressed)


func _on_logout_pressed() -> void:
	pass
