extends Control

# Save as: res://scene/phishing_intro.gd (Encryption Audit Lab intro)

@onready var start_button: Button = $ScrollContainer/MainContainer/VBox/ButtonContainer/StartButton
@onready var back_button: Button = $ScrollContainer/MainContainer/VBox/ButtonContainer/BackButton

# GameMode multiplayer
var _is_gamemode: bool = false

func _ready() -> void:
	print("📚 Encryption Audit Introduction Scene Loaded")
	
	# GameMode detection
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		print("[GameMode] Encryption Audit Intro running in game mode")
	
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		start_button.mouse_entered.connect(_on_start_button_hover)
		start_button.mouse_exited.connect(_on_start_button_unhover)
	else:
		push_error("Start button not found!")
	
	if back_button:
		if _is_gamemode:
			back_button.visible = false  # Hide back button in GameMode
		else:
			back_button.pressed.connect(_on_back_button_pressed)
	else:
		push_error("Back button not found!")

func _on_start_button_pressed() -> void:
	print("Starting Encryption Audit Lab...")
	get_tree().change_scene_to_file("res://scene/tutorial_phishing_lab.tscn")

func _on_back_button_pressed() -> void:
	if _is_gamemode:
		return  # Block quitting in GameMode
	print("Returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _on_start_button_hover() -> void:
	if start_button:
		var tween = create_tween()
		tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.2)

func _on_start_button_unhover() -> void:
	if start_button:
		var tween = create_tween()
		tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.2)