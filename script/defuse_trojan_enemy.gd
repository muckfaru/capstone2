extends Node2D
class_name DefuseTrojanEnemy

# Enemy properties
var word: String = ""
var speed: float = 80.0
var enemy_type: String = "virus"
var is_targeted: bool = false

# Node References
@onready var sprite: Sprite2D = $Sprite2D
@onready var word_label: Label = $WordLabel
@onready var typed_progress: RichTextLabel = $TypedProgress
@onready var target_indicator: Polygon2D = $TargetIndicator
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

signal reached_bottom(enemy: DefuseTrojanEnemy)
signal destroyed(enemy: DefuseTrojanEnemy, points: int)

# Enemy type configurations
const ENEMY_CONFIGS = {
	"trojan": {"speed_mult": 0.8, "points": 150, "color": Color(0.8, 0.2, 0.4)},
	"worm": {"speed_mult": 1.2, "points": 100, "color": Color(0.2, 1.0, 0.4)},
	"virus": {"speed_mult": 1.0, "points": 120, "color": Color(1.0, 0.4, 0.2)},
	"ransomware": {"speed_mult": 0.6, "points": 200, "color": Color(1.0, 0.85, 0.0)}
}

func _ready() -> void:
	# Load texture for enemy type
	_load_enemy_texture()
	
	# Apply enemy type config
	if ENEMY_CONFIGS.has(enemy_type):
		var config = ENEMY_CONFIGS[enemy_type]
		speed *= config.speed_mult
		if word_label:
			word_label.add_theme_color_override("font_color", config.color)
	
	if word_label:
		word_label.text = word
	if typed_progress:
		typed_progress.visible = false
	if target_indicator:
		target_indicator.visible = false
	
	# Start idle animation
	if animation_player:
		animation_player.play("idle")
	
	# Connect Area2D signals for collision detection
	if area_2d:
		area_2d.area_entered.connect(_on_area_entered)

func _load_enemy_texture() -> void:
	"""Load the appropriate texture for the enemy type"""
	var texture_path_png = "res://asset/defuse_trojan/enemy_%s.png" % enemy_type
	var texture_path_jpg = "res://asset/defuse_trojan/enemy_%s.jpg" % enemy_type
	
	var texture = load(texture_path_png)
	if not texture:
		texture = load(texture_path_jpg)
	
	if texture and sprite:
		sprite.texture = texture

func _process(delta: float) -> void:
	# Move downward
	position.y += speed * delta
	
	# Check if reached bottom of screen
	if position.y > get_viewport_rect().size.y + 50:
		reached_bottom.emit(self)
	
	# Pulsing effect when targeted
	if is_targeted and target_indicator:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) / 2.0
		target_indicator.color = Color(0, 1, 0.8, 0.2 + pulse * 0.3)

func _on_area_entered(other_area: Area2D) -> void:
	"""Called when this enemy enters another Area2D (e.g., player defense zone)"""
	if other_area.is_in_group("player_defense"):
		# Emit signal that enemy reached player
		reached_bottom.emit(self)

func set_word(new_word: String) -> void:
	word = new_word.to_upper()
	if word_label:
		word_label.text = word

func set_enemy_type(type: String) -> void:
	enemy_type = type

func set_targeted(targeted: bool) -> void:
	is_targeted = targeted
	if is_targeted:
		# Show target indicator
		if target_indicator:
			target_indicator.visible = true
		if typed_progress:
			typed_progress.visible = true
		# Play targeted animation
		if animation_player:
			animation_player.play("targeted")
		# Tween scale up
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	else:
		if target_indicator:
			target_indicator.visible = false
		if typed_progress:
			typed_progress.visible = false
		# Return to idle animation
		if animation_player:
			animation_player.play("idle")
		scale = Vector2(1.0, 1.0)

func update_typed_progress(typed: String) -> void:
	if not typed_progress:
		return
	
	# Show colored progress using RichTextLabel BBCode
	var typed_part = typed
	var remaining_part = word.substr(typed.length())
	
	typed_progress.text = "[center][color=#00ff88]%s[/color][color=#ff6644]%s[/color][/center]" % [typed_part, remaining_part]
	typed_progress.visible = true
	
	# Hide the regular word label when showing progress
	if word_label:
		word_label.visible = false

func get_points() -> int:
	if ENEMY_CONFIGS.has(enemy_type):
		return ENEMY_CONFIGS[enemy_type].points
	return 100

func destroy() -> void:
	# Disable collision during destruction
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Play destroy animation using AnimationPlayer
	if animation_player:
		animation_player.play("destroy")
		await animation_player.animation_finished
	else:
		# Fallback to Tween if no AnimationPlayer
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(self, "modulate:a", 0.0, 0.15)
		tween.tween_property(self, "rotation", rotation + PI * 0.5, 0.15)
		await tween.finished
	
	# Spawn explosion particles
	_spawn_explosion_particles()
	
	destroyed.emit(self, get_points())
	queue_free()

func _spawn_explosion_particles() -> void:
	"""Create particle effect on destruction"""
	var effects_layer = get_tree().current_scene.get_node_or_null("EffectsLayer")
	if not effects_layer:
		return
	
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = ENEMY_CONFIGS.get(enemy_type, {"color": Color.WHITE}).color
		particle.position = global_position
		
		effects_layer.add_child(particle)
		
		# Random direction
		var angle = randf() * TAU
		var speed_p = randf_range(100, 200)
		var direction = Vector2(cos(angle), sin(angle)) * speed_p
		
		# Animate particle with Tween
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + direction * 0.5, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "size", Vector2(1, 1), 0.4)
		tween.tween_callback(particle.queue_free).set_delay(0.4)
