extends TextureRect

## Lightweight draggable card control for Akashic TCG.
## Expects `card_data` to contain at least: {"card_id": String, "hand_index": int}

signal drag_started(card_data: Dictionary)
signal drag_ended(card_data: Dictionary)

signal card_clicked(card_data: Dictionary)

var card_data: Dictionary = {}
var drag_enabled: bool = true
var click_enabled: bool = true

# Optional hover SFX (used for player's hand cards).
const _SFX_HOVER: AudioStream = preload("res://asset/audio/akashic sfx/flipcard-91468.mp3")
const _SFX_HOVER_VOLUME_DB := -10.0
var hover_sfx_enabled: bool = false
var _hover_sfx_player: AudioStreamPlayer = null

var _pre_drag_modulate: Color = Color(1, 1, 1, 1)
var _pre_hover_modulate: Color = Color(1, 1, 1, 1)
var _is_dragging: bool = false
var _drag_started_this_press: bool = false

var _press_pos: Vector2 = Vector2.ZERO
var _press_time_msec: int = 0
var _pressed: bool = false

const CLICK_MAX_DIST_PX := 10.0
const CLICK_MAX_TIME_MSEC := 300

var _is_hovered: bool = false
var _hover_overlay: TextureRect = null
var _hover_tween: Tween = null
var _hover_layer: CanvasLayer = null

const HOVER_ELEVATE_Y := -78.0
const HOVER_SCALE := 1.06
const HOVER_TWEEN_SEC := 0.10

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	# Better looking scale animations.
	var base_size := custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	if base_size != Vector2.ZERO:
		pivot_offset = base_size * 0.5

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	gui_input.connect(_on_gui_input)
	# If this card node gets freed/rebuilt during state re-render while hovered,
	# ensure any top-level hover overlay is removed (it lives in a shared CanvasLayer).
	tree_exiting.connect(func():
		_cleanup_hover_overlay(true)
	)

	# Note: We avoid animating Control.position while inside Containers.
	# Hover uses an overlay preview instead.
	
	if hover_sfx_enabled:
		_ensure_hover_sfx_player()


func _ensure_hover_sfx_player() -> void:
	if _hover_sfx_player != null and is_instance_valid(_hover_sfx_player):
		return
	_hover_sfx_player = AudioStreamPlayer.new()
	_hover_sfx_player.stream = _SFX_HOVER
	_hover_sfx_player.volume_db = _SFX_HOVER_VOLUME_DB
	add_child(_hover_sfx_player)


func _play_hover_sfx() -> void:
	if not hover_sfx_enabled:
		return
	_ensure_hover_sfx_player()
	if _hover_sfx_player == null or not is_instance_valid(_hover_sfx_player):
		return
	_hover_sfx_player.play()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressed = true
			_drag_started_this_press = false
			_press_pos = mb.position
			_press_time_msec = Time.get_ticks_msec()
			return
		# release
		if not _pressed:
			return
		_pressed = false
		if _drag_started_this_press or _is_dragging:
			return
		if not click_enabled or not drag_enabled:
			return
		if card_data.is_empty():
			return
		var dt := Time.get_ticks_msec() - _press_time_msec
		if dt > CLICK_MAX_TIME_MSEC:
			return
		if mb.position.distance_to(_press_pos) > CLICK_MAX_DIST_PX:
			return
		_cleanup_hover_overlay(true)
		card_clicked.emit(card_data)


func _kill_hover_tween() -> void:
	if _hover_tween and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = null


func _cleanup_hover_overlay(immediate: bool) -> void:
	_kill_hover_tween()
	if _hover_overlay != null and is_instance_valid(_hover_overlay):
		if immediate:
			_hover_overlay.queue_free()
		else:
			_hover_overlay.queue_free()
	_hover_overlay = null
	_is_hovered = false
	# Restore original appearance.
	modulate = _pre_hover_modulate
	if _hover_layer != null and is_instance_valid(_hover_layer):
		# Keep the layer for reuse.
		pass


func _ensure_hover_overlay() -> void:
	if _hover_overlay != null and is_instance_valid(_hover_overlay):
		return
	_pre_hover_modulate = modulate
	# Hide the original to prevent "duplicate" look.
	modulate = Color(modulate.r, modulate.g, modulate.b, 0.0)

	# Put hover overlays in a dedicated top canvas layer so they render above
	# stacked cards/containers regardless of tree order.
	if _hover_layer == null or not is_instance_valid(_hover_layer):
		var scene := get_tree().current_scene
		if scene != null:
			var existing := scene.get_node_or_null("HoverOverlayLayer")
			if existing != null and existing is CanvasLayer:
				_hover_layer = existing as CanvasLayer
			else:
				_hover_layer = CanvasLayer.new()
				_hover_layer.name = "HoverOverlayLayer"
				_hover_layer.layer = 100
				scene.add_child(_hover_layer)

	_hover_overlay = TextureRect.new()
	_hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_overlay.texture = texture
	_hover_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hover_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_hover_overlay.custom_minimum_size = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	_hover_overlay.pivot_offset = _hover_overlay.custom_minimum_size * 0.5
	_hover_overlay.top_level = true
	_hover_overlay.z_as_relative = false
	_hover_overlay.z_index = 10000
	if _hover_layer != null and is_instance_valid(_hover_layer):
		_hover_layer.add_child(_hover_overlay)
	else:
		# Fallback: keep behavior as before.
		add_child(_hover_overlay)
	# Place overlay on top of the original card location.
	var r := get_global_rect()
	_hover_overlay.global_position = r.position
	_hover_overlay.size = r.size


func _on_mouse_entered() -> void:
	if _is_dragging:
		return
	_play_hover_sfx()
	_is_hovered = true
	_ensure_hover_overlay()
	_kill_hover_tween()
	# Re-sync overlay base position in case layout shifted.
	var base_pos := get_global_rect().position
	_hover_overlay.global_position = base_pos
	_hover_overlay.scale = Vector2.ONE
	_hover_overlay.modulate = Color(1, 1, 1, 1)

	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_hover_overlay, "global_position", base_pos + Vector2(0, HOVER_ELEVATE_Y), HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(_hover_overlay, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), HOVER_TWEEN_SEC)


func _on_mouse_exited() -> void:
	if _is_dragging:
		return
	if _hover_overlay == null or not is_instance_valid(_hover_overlay):
		_is_hovered = false
		return
	_is_hovered = false
	_kill_hover_tween()
	var base_pos := get_global_rect().position
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_hover_overlay, "global_position", base_pos, HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(_hover_overlay, "scale", Vector2.ONE, HOVER_TWEEN_SEC)
	_hover_tween.finished.connect(func():
		_cleanup_hover_overlay(true)
	)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled:
		return null
	if card_data.is_empty():
		return null

	drag_started.emit(card_data)
	_is_dragging = true
	_drag_started_this_press = true
	# Cancel any hover overlay while dragging.
	_cleanup_hover_overlay(true)
	_pre_drag_modulate = modulate
	# Fade the original while dragging so it doesn't look like a duplicate.
	modulate = Color(modulate.r, modulate.g, modulate.b, 0.2)

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
		if _is_dragging:
			_is_dragging = false
			modulate = _pre_drag_modulate
			# Restore hover visuals if the mouse is still over the card.
			if get_rect().has_point(get_local_mouse_position()):
				_on_mouse_entered()
		if not card_data.is_empty():
			drag_ended.emit(card_data)
	elif what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		_cleanup_hover_overlay(true)
