extends Node
class_name CardCosmetics

static func apply_card_background(card_node: Node, texture_path: String) -> void:
	if card_node == null:
		return

	# Empty path means keep the default UI background.
	var path := texture_path.strip_edges()
	if path == "":
		_clear_background(card_node)
		return

	if not ResourceLoader.exists(path):
		push_warning("[CardCosmetics] Texture not found: %s" % path)
		_clear_background(card_node)
		return

	var tex := load(path)
	if tex == null:
		push_warning("[CardCosmetics] Failed to load texture: %s" % path)
		_clear_background(card_node)
		return

	var bg := _ensure_background_node(card_node)
	bg.texture = tex

static func _ensure_background_node(card_node: Node) -> TextureRect:
	var existing := card_node.get_node_or_null("CardBackground")
	if existing and existing is TextureRect:
		return existing as TextureRect

	var bg := TextureRect.new()
	bg.name = "CardBackground"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_as_relative = true
	bg.z_index = 0

	# Put it first so it renders behind other children.
	card_node.add_child(bg)
	card_node.move_child(bg, 0)
	return bg

static func _clear_background(card_node: Node) -> void:
	var existing := card_node.get_node_or_null("CardBackground")
	if existing and existing is TextureRect:
		(existing as TextureRect).texture = null
