extends Control

# Simple draggable menu: full-screen overlay blocks input; drag the header of the window; close with X.

@onready var window_panel: Panel = $Window
@onready var header_panel: Panel = $Window/Panel
@onready var close_button: Button = $Window/Panel/CloseMenuButton
@onready var overlay: ColorRect = $Overlay
@onready var menu_logout_button: Button = $Window/Body/LogoutButton

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.focus_mode = Control.FOCUS_NONE
	if header_panel and not header_panel.gui_input.is_connected(_on_header_gui_input):
		header_panel.gui_input.connect(_on_header_gui_input)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if menu_logout_button and not menu_logout_button.pressed.is_connected(_on_menu_logout_pressed):
		menu_logout_button.pressed.connect(_on_menu_logout_pressed)


func _on_close_pressed() -> void:
	visible = false


func _on_menu_logout_pressed() -> void:
	# Mirror navigation logout behavior
	Auth.set_user_offline()
	get_tree().change_scene_to_file("res://scene/login.tscn")


func _on_header_gui_input(event: InputEvent) -> void:
	# Start/stop dragging when interacting with the header bar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - window_panel.global_position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		window_panel.global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_viewport()
		accept_event()


func _clamp_to_viewport() -> void:
	# Keep the menu within the viewport bounds
	var vp_rect := get_viewport().get_visible_rect()
	var pos := window_panel.global_position
	var sz := window_panel.size
	pos.x = clamp(pos.x, 0.0, max(0.0, vp_rect.size.x - sz.x))
	pos.y = clamp(pos.y, 0.0, max(0.0, vp_rect.size.y - sz.y))
	window_panel.global_position = pos
