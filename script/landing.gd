extends Control

@onready var logout_button: Button = $LogoutButton

func _ready() -> void:
	logout_button.pressed.connect(_on_logout_pressed)


func _on_logout_pressed() -> void:
	# i-clear ang session/token
	Global.current_id_token = ""  # kung naka-store ka ng token sa Global singleton
	# balik login scene
	get_tree().change_scene_to_file("res://scene/login.tscn")
