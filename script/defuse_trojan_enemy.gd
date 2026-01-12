extends Node2D
class_name DefuseTrojanEnemy

# Enemy properties
var word: String = ""
var speed: float = 80.0
var enemy_type: String = "virus"
var is_targeted: bool = false
var is_initialized: bool = false

# Animation
var idle_tween: Tween

# Node References
@onready var sprite: Sprite2D = $Sprite2D
@onready var word_label: Label = $WordLabel
@onready var typed_progress: RichTextLabel = $TypedProgress
@onready var target_indicator: Polygon2D = $TargetIndicator
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

signal reached_bottom(enemy: DefuseTrojanEnemy)
signal destroyed(enemy: DefuseTrojanEnemy, points: int)

# Enemy type configurations with textures
const ENEMY_CONFIGS = {
	"trojan": {"speed_mult": 0.8, "points": 150, "color": Color(0.8, 0.2, 0.4), "texture": "trojan_1"},
	"worm": {"speed_mult": 1.2, "points": 100, "color": Color(0.2, 1.0, 0.4), "texture": "worm_1"},
	"virus": {"speed_mult": 1.0, "points": 120, "color": Color(1.0, 0.4, 0.2), "texture": "virus_1"},
	"ransomware": {"speed_mult": 0.6, "points": 200, "color": Color(1.0, 0.85, 0.0), "texture": "ransomware_1"}
}

func _ready() -> void:
	# Wait one frame to ensure set_enemy_type and set_word have been called
	await get_tree().process_frame
	_initialize()

func _initialize() -> void:
	if is_initialized:
		return
	is_initialized = true
	
	# Load texture for this enemy type
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
	
	# Start smooth idle animation
	_start_idle_animation()
	
	# Connect Area2D signals
	if area_2d:
		area_2d.area_entered.connect(_on_area_entered)

func _load_enemy_texture() -> void:
	"""Load the texture for this enemy type"""
	if not sprite:
		return
	
	var texture_name = "virus_1"
	if ENEMY_CONFIGS.has(enemy_type):
		texture_name = ENEMY_CONFIGS[enemy_type].texture
	
	var texture_path = "res://asset/defuse_trojan/frames/%s.jpg" % texture_name
	var texture = load(texture_path)
	if texture:
		sprite.texture = texture

func _start_idle_animation() -> void:
	"""Start smooth floating/pulsing idle animation using Tween"""
	if idle_tween:
		idle_tween.kill()
	
	# Scale pulse (breathing effect)
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "scale", Vector2(1.05, 0.95), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.chain().tween_property(self, "scale", Vector2(0.95, 1.05), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Slight rotation wobble
	var rot_tween = create_tween()
	rot_tween.set_loops()
	rot_tween.tween_property(self, "rotation", 0.05, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	rot_tween.chain().tween_property(self, "rotation", -0.05, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	rot_tween.chain().tween_property(self, "rotation", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if not is_initialized:
		return
	
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
	if other_area.is_in_group("player_defense"):
		reached_bottom.emit(self)

func set_word(new_word: String) -> void:
	word = new_word.to_upper()
	if word_label and is_initialized:
		word_label.text = word

func set_enemy_type(type: String) -> void:
	enemy_type = type

func set_targeted(targeted: bool) -> void:
	is_targeted = targeted
	if is_targeted:
		if target_indicator:
			target_indicator.visible = true
		if typed_progress:
			typed_progress.visible = true
		if sprite:
			sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		if target_indicator:
			target_indicator.visible = false
		if typed_progress:
			typed_progress.visible = false
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func update_typed_progress(typed: String) -> void:
	if not typed_progress:
		return
	
	var typed_part = typed
	var remaining_part = word.substr(typed.length())
	
	typed_progress.text = "[center][color=#00ff88]%s[/color][color=#ff6644]%s[/color][/center]" % [typed_part, remaining_part]
	typed_progress.visible = true
	
	if word_label:
		word_label.visible = false

func get_points() -> int:
	if ENEMY_CONFIGS.has(enemy_type):
		return ENEMY_CONFIGS[enemy_type].points
	return 100

func destroy() -> void:
	# Stop idle animations
	if idle_tween:
		idle_tween.kill()
	
	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Destruction animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "rotation", rotation + PI * 0.5, 0.2)
	await tween.finished
	
	_spawn_explosion_particles()
	
	destroyed.emit(self, get_points())
	queue_free()

func _spawn_explosion_particles() -> void:
	var effects_layer = get_tree().current_scene.get_node_or_null("EffectsLayer")
	if not effects_layer:
		return
	
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = ENEMY_CONFIGS.get(enemy_type, {"color": Color.WHITE}).color
		particle.position = global_position
		
		effects_layer.add_child(particle)
		
		var angle = randf() * TAU
		var speed_p = randf_range(100, 200)
		var direction = Vector2(cos(angle), sin(angle)) * speed_p
		
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + direction * 0.5, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "size", Vector2(1, 1), 0.4)
		tween.tween_callback(particle.queue_free).set_delay(0.4)
