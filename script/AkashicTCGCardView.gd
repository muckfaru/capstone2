extends TextureRect

## Lightweight draggable card control for Akashic TCG.
## Expects `card_data` to contain at least: {"card_id": String, "hand_index": int}

signal drag_started(card_data: Dictionary)
signal drag_ended(card_data: Dictionary)

var card_data: Dictionary = {}
var drag_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled:
		return null
	if card_data.is_empty():
		return null

	drag_started.emit(card_data)

	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.modulate = Color(1, 1, 1, 0.95)
	set_drag_preview(preview)

	return card_data

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not card_data.is_empty():
			drag_ended.emit(card_data)
