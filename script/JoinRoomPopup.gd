extends Control

signal join_requested(room_code: String)
signal popup_closed

@onready var code_input: LineEdit = $PopupPanel/VBox/CodeInput
@onready var join_btn: Button     = $PopupPanel/VBox/JoinButton
@onready var back_btn: Button     = $PopupPanel/TopBar/BackButton
@onready var title_label: Label   = $PopupPanel/TopBar/TitleLabel
@onready var error_label: Label   = $PopupPanel/VBox/ErrorLabel

# Student number restriction (dynamically shown)
var _student_num_label: Label = null
var _student_num_input: LineEdit = null
var _student_num_visible: bool = false

func _ready() -> void:
	visible = false
	error_label.visible = false
	_build_student_number_field()

func _build_student_number_field() -> void:
	var vbox = $PopupPanel/VBox
	if not vbox:
		return

	# Find CodeInput index to insert after it
	var insert_idx := 0
	for i in vbox.get_child_count():
		if vbox.get_child(i) == code_input:
			insert_idx = i + 1
			break

	# Label
	_student_num_label = Label.new()
	_student_num_label.text = "Student Number"
	_student_num_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0, 0.8))
	_student_num_label.add_theme_font_size_override("font_size", 13)
	_student_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_student_num_label.visible = false
	vbox.add_child(_student_num_label)
	vbox.move_child(_student_num_label, insert_idx)

	# Input
	_student_num_input = LineEdit.new()
	_student_num_input.custom_minimum_size = Vector2(0, 52)
	_student_num_input.placeholder_text = "e.g. 21-2169"
	_student_num_input.max_length = 30
	_student_num_input.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
	_student_num_input.add_theme_color_override("caret_color", Color(0.145, 0.878, 0.992, 1.0))
	_student_num_input.add_theme_font_size_override("font_size", 22)
	# Copy the same style as CodeInput
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.02, 0.05, 0.14, 1.0)
	input_style.border_color = Color(0.145, 0.878, 0.992, 0.5)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(8)
	input_style.content_margin_left = 16.0
	input_style.content_margin_top = 8.0
	input_style.content_margin_right = 16.0
	input_style.content_margin_bottom = 8.0
	_student_num_input.add_theme_stylebox_override("normal", input_style)
	_student_num_input.add_theme_stylebox_override("focus", input_style)
	_student_num_input.visible = false
	vbox.add_child(_student_num_input)
	vbox.move_child(_student_num_input, insert_idx + 1)

func show_student_number_field(visible_flag: bool) -> void:
	_student_num_visible = visible_flag
	if _student_num_label:
		_student_num_label.visible = visible_flag
	if _student_num_input:
		_student_num_input.visible = visible_flag
		if not visible_flag:
			_student_num_input.text = ""
	# Resize popup to fit
	var panel = $PopupPanel
	if panel:
		if visible_flag:
			panel.offset_top = -250.0
			panel.offset_bottom = 250.0
		else:
			panel.offset_top = -180.0
			panel.offset_bottom = 180.0

func get_student_number() -> String:
	if _student_num_input and _student_num_visible:
		return _student_num_input.text.strip_edges().to_upper()
	return ""

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