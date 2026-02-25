extends Control

signal join_requested(room_code: String)
signal popup_closed

@onready var code_input: LineEdit = $PopupPanel/VBox/CodeInput
@onready var join_btn: Button     = $PopupPanel/VBox/JoinButton
@onready var back_btn: Button     = $PopupPanel/TopBar/BackButton
@onready var title_label: Label   = $PopupPanel/TopBar/TitleLabel
@onready var error_label: Label   = $PopupPanel/VBox/ErrorLabel

func _ready() -> void:
	visible = false
	error_label.visible = false

func show_popup() -> void:
	code_input.text = ""
	error_label.visible = false
	visible = true
	_animate_in()
	code_input.grab_focus()

func _on_join_pressed() -> void:
	var code := code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_show_error("Please enter a room code.")
		return
	if code.length() < 6:
		_show_error("Invalid room code.")
		return
	emit_signal("join_requested", code)

func _on_back_pressed() -> void:
	emit_signal("popup_closed")
	_animate_out()

func _on_code_input_changed(new_text: String) -> void:
	# Force uppercase
	var upper := new_text.to_upper()
	if upper != new_text:
		code_input.text = upper
		code_input.caret_column = upper.length()
	error_label.visible = false

func show_error(msg: String) -> void:
	_show_error(msg)

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true
	# Shake animation
	var original_pos := code_input.position
	var tw := create_tween()
	tw.tween_property(code_input, "position:x", original_pos.x - 8, 0.05)
	tw.tween_property(code_input, "position:x", original_pos.x + 8, 0.05)
	tw.tween_property(code_input, "position:x", original_pos.x - 4, 0.05)
	tw.tween_property(code_input, "position:x", original_pos.x, 0.05)

func _animate_in() -> void:
	modulate.a = 0.0
	scale      = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(0.95, 0.95), 0.18)
	tw.tween_callback(_on_animate_out_done)

func _on_animate_out_done() -> void:
	visible = false