extends Panel

## Drop target for Akashic TCG cards.

signal card_dropped(card_data: Dictionary)

var drop_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep the drop target itself invisible, but do NOT hide its children
	# (we render dropped cards inside this panel).
	self_modulate = Color(1, 1, 1, 0)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drop_enabled:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return StringName("card_id") in data

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	card_dropped.emit(data)
