# create_room_popup.gd
extends Window

signal confirmed(room_name: String, anonymous: bool)
signal canceled

@onready var _room_name_edit: LineEdit = $BackgroundPanel/VBox/RoomNameContainer/RoomNameEdit
@onready var _anonymous_check: CheckBox = $BackgroundPanel/VBox/AnonymousContainer/AnonymousCheckInsideRoom
@onready var _create_btn: Button = $BackgroundPanel/VBox/Buttons/CreateButton
@onready var _cancel_btn: Button = $BackgroundPanel/VBox/Buttons/CancelButton
@onready var _background_panel: Panel = $BackgroundPanel
@onready var _header_label: Label = $BackgroundPanel/VBox/HeaderLabel
@onready var _close_btn: Button = $BackgroundPanel/CloseButton

var _default_name: String = ""
var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	# Make window borderless and transparent
	borderless = true
	transient = true
	transparent = true
	transparent_bg = true
	
	# Connect buttons
	_create_btn.pressed.connect(_on_create_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_close_btn.pressed.connect(_on_cancel_pressed)
	_anonymous_check.toggled.connect(func(_pressed: bool):
		_apply_name()
	)
	
	# Setup dragging on header
	_header_label.gui_input.connect(_on_header_input)
	
	# Apply initial name
	_apply_name()
	
	# Setup hover effects
	_setup_hover_effects()
	
	# Play entrance animation
	_play_entrance_animation()

func init_with_username(username: String) -> void:
	_default_name = username
	_apply_name()

func _apply_name() -> void:
	var effective := "Anonymous" if _anonymous_check.button_pressed else (_default_name if _default_name != "" else _room_name_edit.text)
	_room_name_edit.text = effective

func _on_header_input(event: InputEvent) -> void:
	"""Handle dragging when clicking on header"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_mouse_position()
			else:
				_dragging = false
	
	elif event is InputEventMouseMotion and _dragging:
		position += Vector2i(event.relative)

func _setup_hover_effects() -> void:
	"""Add smooth hover animations to buttons"""
	# CREATE ROOM button hover
	_create_btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(_create_btn, "scale", Vector2(1.05, 1.05), 0.3)
	)
	_create_btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_create_btn, "scale", Vector2(1.0, 1.0), 0.2)
	)
	
	# CANCEL button hover
	_cancel_btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(_cancel_btn, "scale", Vector2(1.05, 1.05), 0.3)
	)
	_cancel_btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_cancel_btn, "scale", Vector2(1.0, 1.0), 0.2)
	)
	
	# Close button hover
	_close_btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_close_btn, "modulate", Color(1, 0.3, 0.3, 1), 0.2)
	)
	_close_btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_close_btn, "modulate", Color(1, 1, 1, 0.8), 0.2)
	)

func _play_entrance_animation() -> void:
	"""Smooth fade-in and scale animation when popup opens"""
	if not _background_panel:
		return
	
	# Start with transparent and smaller
	_background_panel.modulate.a = 0.0
	_background_panel.scale = Vector2(0.8, 0.8)
	
	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(_background_panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(_background_panel, "scale", Vector2(1.0, 1.0), 0.4)

func _play_exit_animation() -> void:
	"""Smooth fade-out animation when closing"""
	if not _background_panel:
		hide()
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(_background_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(_background_panel, "scale", Vector2(0.9, 0.9), 0.2)
	
	await tween.finished
	hide()

func _on_create_pressed() -> void:
	emit_signal("confirmed", _room_name_edit.text, _anonymous_check.button_pressed)
	_play_exit_animation()

func _on_cancel_pressed() -> void:
	emit_signal("canceled")
	_play_exit_animation()