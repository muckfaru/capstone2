extends Node2D

# Projectile properties
var target: Node2D = null
var speed: float = 1200.0
var damage_effect: bool = true

@onready var sprite: Polygon2D = $Sprite
@onready var trail: Line2D = $Trail

signal hit_target(target: Node2D)

func _ready() -> void:
	# Start moving towards target
	if target and is_instance_valid(target):
		look_at(target.global_position)
	
	# Trail effect setup
	trail.clear_points()
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0, 15))

func _process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		# Target destroyed, just fade out
		_fade_and_destroy()
		return
	
	# Move towards target
	var direction = (target.global_position - global_position).normalized()
	var distance = global_position.distance_to(target.global_position)
	
	# Rotate to face target
	look_at(target.global_position)
	
	# Move
	var move_distance = speed * delta
	if move_distance >= distance:
		# Hit target
		global_position = target.global_position
		hit_target.emit(target)
		_create_impact_effect()
		queue_free()
	else:
		global_position += direction * move_distance
		
	# Update trail
	_update_trail()

func _update_trail() -> void:
	# Simple trail effect
	trail.clear_points()
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0, 20))

func _fade_and_destroy() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()

func _create_impact_effect() -> void:
	# Create small burst particles at impact
	var parent = get_parent()
	if not parent:
		return
	
	for i in range(4):
		var particle = Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		particle.color = Color(0, 1, 0.8, 1)
		particle.global_position = global_position
		parent.add_child(particle)
		
		# Random direction
		var angle = randf() * TAU
		var direction = Vector2(cos(angle), sin(angle)) * 50.0
		
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", particle.global_position + direction, 0.2)
		tween.tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free).set_delay(0.2)
