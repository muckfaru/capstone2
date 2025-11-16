extends CanvasLayer

@export var timeout_seconds: float = 10.0  # Network timeout duration
@export var delay_before_login: float = 3.0  # Delay before going to login

var _elapsed_time: float = 0.0
var _is_loading: bool = true
var _connection_failed: bool = false

func _ready() -> void:
	# Animated sprite is already playing, just wait for timeout
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
	
	# Stop the animation
	var sprite = get_node_or_null("Control/AnimatedSprite2D")
	if sprite:
		sprite.stop()
	
	# Show error (optional: add a label or change color)
	var texture_rect = get_node_or_null("Control/TextureRect")
	if texture_rect:
		texture_rect.self_modulate = Color.RED
	
	# Wait before going to login
	await get_tree().create_timer(delay_before_login).timeout
	_go_to_login()

func _go_to_login() -> void:
	"""Transition to login scene"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	var control = get_node("Control")
	tween.tween_property(control, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	
	get_tree().change_scene_to_file("res://scene/login.tscn")
