extends Control
# Drag area for CIA Triad incident card

var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - get_parent().global_position
				get_parent().z_index = 100
			else:
				_dragging = false
				get_parent().z_index = 0
				get_owner()._on_card_dropped(get_global_mouse_position())
	
	elif event is InputEventMouseMotion and _dragging:
		get_parent().global_position = get_global_mouse_position() - _drag_offset
