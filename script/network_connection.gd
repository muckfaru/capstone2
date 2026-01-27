extends Area2D

# ============================================
# NETWORK CONNECTION PACKET
# Draggable connection that player must sort
# ============================================

signal destroyed(connection)

var connection_data: Dictionary
var connection_type: int  # ConnectionType.SAFE or ConnectionType.THREAT
var dragging := false
var drag_offset := Vector2.ZERO
var original_position := Vector2.ZERO
var fall_speed := 50.0
var is_frozen_state := false
var hint_visible := false

# Debug
var debug_mode := true

@onready var panel: Panel = $Panel  # CHANGED from PanelContainer to Panel
@onready var connection_label: Label = $Panel/VBox/ConnectionLabel
@onready var category_label: Label = $Panel/VBox/CategoryLabel
@onready var hint_label: Label = $Panel/VBox/HintLabel
@onready var glow_rect: ColorRect = $GlowRect
@onready var timer_bar: ProgressBar = $Panel/VBox/TimerBar

var lifetime := 8.0  # Seconds before timeout
var elapsed_time := 0.0

func _ready() -> void:
	input_pickable = true
	monitoring = true
	monitorable = true
	
	# Setup visual styling
	_setup_appearance()
	
	# Hide hint initially
	hint_label.visible = false
	
	# Start moving down
	original_position = position
	
	# Make sure child controls don't block mouse
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not is_instance_valid(self):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var rect = Rect2(global_position - Vector2(100, 50), Vector2(200, 100))
		
		if debug_mode:
			print("Mouse at: ", mouse_pos, " | Connection at: ", global_position, " | In rect: ", rect.has_point(mouse_pos))
		
		if rect.has_point(mouse_pos):
			if event.pressed:
				dragging = true
				drag_offset = mouse_pos - global_position
				z_index = 100
				_show_drag_feedback()
				if debug_mode:
					print("Started dragging: ", connection_label.text)
				get_viewport().set_input_as_handled()
			else:
				if dragging:
					dragging = false
					z_index = 0
					_hide_drag_feedback()
					if debug_mode:
						print("Stopped dragging: ", connection_label.text)
					get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_frozen_state:
		return
	
	if not dragging:
		# Fall down slowly
		position.y += fall_speed * delta
		
		# Update lifetime
		elapsed_time += delta
		timer_bar.value = (elapsed_time / lifetime) * 100.0
		
		# Check if timed out (fell off screen)
		if position.y > 700 or elapsed_time >= lifetime:
			destroyed.emit(self)
			queue_free()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# Keeping this for compatibility but main logic is in _input()
	pass

func _physics_process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() - drag_offset

func set_data(data: Dictionary) -> void:
	connection_data = data
	connection_type = data.get("type", 0)
	
	# Update labels
	connection_label.text = data.get("text", "Unknown")
	
	var category = data.get("category", "")
	if category:
		category_label.text = "Category: %s" % category
		category_label.visible = true
	else:
		category_label.visible = false
	
	hint_label.text = "💡 %s" % data.get("hint", "")
	
	# Style based on type
	_update_style_for_type()

func _setup_appearance() -> void:
	# Note: Panel already has StyleBoxTexture from scene file
	# Only override if you need to change it dynamically
	# Otherwise, the texture from the scene will be used
	
	# Timer bar styling
	timer_bar.show_percentage = false
	timer_bar.value = 0

func _update_style_for_type() -> void:
	# Subtle color hint based on type (not too obvious)
	if connection_type == 0:  # SAFE
		glow_rect.color = Color(0.2, 0.8, 0.2, 0.15)
	else:  # THREAT
		glow_rect.color = Color(0.8, 0.2, 0.2, 0.15)

func _show_drag_feedback() -> void:
	# Scale up slightly
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Brighter glow
	glow_rect.modulate.a = 0.4

func _hide_drag_feedback() -> void:
	# Scale back
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	
	# Normal glow
	glow_rect.modulate.a = 0.2

func show_hint() -> void:
	hint_visible = true
	hint_label.visible = true
	
	# Flash the hint
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(hint_label, "modulate:a", 0.3, 0.3)
	tween.tween_property(hint_label, "modulate:a", 1.0, 0.3)

func freeze() -> void:
	is_frozen_state = true
	# Visual feedback: blue tint
	modulate = Color(0.7, 0.7, 1.0, 1.0)

func unfreeze() -> void:
	is_frozen_state = false
	modulate = Color.WHITE

func is_dragging() -> bool:
	return dragging
