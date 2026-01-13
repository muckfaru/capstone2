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

# Node References - will be found dynamically
var animated_sprite: AnimatedSprite2D
var word_label: Label
var typed_progress: RichTextLabel
var target_indicator: Polygon2D

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
	# Wait one frame to ensure set_enemy_type and set_word have been called
	await get_tree().process_frame
	_initialize()

func _initialize() -> void:
	if is_initialized:
		return
	is_initialized = true
	
	# Find AnimatedSprite2D in children
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
	# Create UI elements dynamically
	_create_ui_elements()
	
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

func _create_ui_elements() -> void:
	# Create word label
	word_label = Label.new()
	word_label.name = "WordLabel"
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.position = Vector2(-100, 45)
	word_label.size = Vector2(200, 30)
	word_label.add_theme_font_size_override("font_size", 18)
	word_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	word_label.add_theme_constant_override("outline_size", 4)
	add_child(word_label)
	
	# Create typed progress
	typed_progress = RichTextLabel.new()
	typed_progress.name = "TypedProgress"
	typed_progress.bbcode_enabled = true
	typed_progress.fit_content = true
	typed_progress.scroll_active = false
	typed_progress.position = Vector2(-100, 65)
	typed_progress.size = Vector2(200, 30)
	typed_progress.add_theme_font_size_override("normal_font_size", 16)
	typed_progress.visible = false
	add_child(typed_progress)
	
	# Create target indicator
	target_indicator = Polygon2D.new()
	target_indicator.name = "TargetIndicator"
	target_indicator.polygon = PackedVector2Array([Vector2(-8, -60), Vector2(8, -60), Vector2(0, -45)])
	target_indicator.color = Color(0, 1, 0.8, 0.3)
	target_indicator.visible = false
	add_child(target_indicator)

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
		if animated_sprite:
			animated_sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		if target_indicator:
			target_indicator.visible = false
		if typed_progress:
			typed_progress.visible = false
		if animated_sprite:
			animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
		var dir = Vector2(cos(angle), sin(angle)) * speed_p
		
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + dir * 0.5, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "size", Vector2(1, 1), 0.4)
		tween.tween_callback(particle.queue_free).set_delay(0.4)
