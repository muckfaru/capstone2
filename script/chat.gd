extends Panel

var _dragging := false
var _drag_offset := Vector2.ZERO
var _handle: Control

func _ready() -> void:
	# Allow free positioning independent of parent layout
	top_level = true

	# Use child 'Panel' as handle if exists; else drag from this node
	if has_node("Panel"):
		_handle = $Panel
	if _handle:
		_handle.gui_input.connect(_on_gui_input)
		_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		gui_input.connect(_on_gui_input)
		mouse_default_cursor_shape = Control.CURSOR_MOVE

func _process(_delta: float) -> void:
	if not _dragging:
		return

	var target := get_global_mouse_position() - _drag_offset
	var vp := get_viewport_rect()
	var max_pos := vp.size - size
	target.x = clamp(target.x, 0.0, max_pos.x)
	target.y = clamp(target.y, 0.0, max_pos.y)
	global_position = target

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position - global_position
			accept_event()
		else:
			_dragging = false
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	# Stop dragging if mouse released outside the handle
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
