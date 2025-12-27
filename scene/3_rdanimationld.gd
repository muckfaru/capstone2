extends CanvasLayer

@export var timeout_seconds: float = 10.0
@export var delay_before_login: float = 3.0
@export var transition_color: Color = Color.RED

var _elapsed_time: float = 0.0
var _is_loading: bool = true
var _connection_failed: bool = false

func _ready() -> void:
	# Create a ColorRect for transition
	var color_rect = ColorRect.new()
	color_rect.name = "TransitionRect"
	color_rect.color = transition_color
	color_rect.modulate.a = 0.0  # Start invisible
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_node("Control").add_child(color_rect)
	
	await get_tree().create_timer(timeout_seconds).timeout
	if _is_loading:
		_on_connection_timeout()

func _process(delta: float) -> void:
	if _is_loading:
		_elapsed_time += delta

func _on_connection_timeout() -> void:
	"""Handle connection timeout"""
	_is_loading = false
	_connection_failed = true
	
	var sprite = get_node_or_null("Control/AnimatedSprite2D")
	if sprite:
		sprite.stop()
	
	var texture_rect = get_node_or_null("Control/TextureRect")
	if texture_rect:
		texture_rect.self_modulate = Color.RED
	
	await get_tree().create_timer(delay_before_login).timeout
	_go_to_login()

func _go_to_login() -> void:
	"""Transition to login scene with red fade"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	
	# Fade in the red overlay
	var transition_rect = get_node_or_null("Control/TransitionRect")
	if transition_rect:
		tween.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
	
	await tween.finished
	
	get_tree().change_scene_to_file("res://scene/login.tscn")