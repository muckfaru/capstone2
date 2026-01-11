extends Node2D
class_name DefuseTrojanEnemy

# Enemy properties
var word: String = ""
var speed: float = 80.0
var enemy_type: String = "virus"
var is_targeted: bool = false

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var word_label: Label = $WordLabel
@onready var typed_label: Label = $TypedLabel

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
	# Load texture for enemy type FIRST (before other setup)
	_load_enemy_texture()
	
	# Apply enemy type config
	if ENEMY_CONFIGS.has(enemy_type):
		var config = ENEMY_CONFIGS[enemy_type]
		speed *= config.speed_mult
		if word_label:
			word_label.add_theme_color_override("font_color", config.color)
	
	if word_label:
		word_label.text = word
	if typed_label:
		typed_label.text = ""
		typed_label.visible = false

func _load_enemy_texture() -> void:
	"""Load the appropriate texture for the enemy type"""
	var texture_path = "res://asset/defuse_trojan/enemy_%s.png" % enemy_type
	var texture = load(texture_path)
	if texture and sprite:
		sprite.texture = texture
		print("[Enemy] ✅ Loaded texture: %s" % texture_path)
	else:
		push_warning("[Enemy] ⚠️ Failed to load texture: %s | sprite: %s" % [texture_path, sprite])

func _process(delta: float) -> void:
	# Move downward
	position.y += speed * delta
	
	# Check if reached bottom of screen
	if position.y > get_viewport_rect().size.y + 50:
		reached_bottom.emit(self)

func set_word(new_word: String) -> void:
	word = new_word.to_upper()
	if word_label:
		word_label.text = word

func set_enemy_type(type: String) -> void:
	enemy_type = type
	# Texture is loaded in _ready() after node references are available


func set_targeted(targeted: bool) -> void:
	is_targeted = targeted
	if is_targeted:
		# Highlight effect
		modulate = Color(1.2, 1.2, 1.2)
		typed_label.visible = true
		# Scale up slightly
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	else:
		modulate = Color(1.0, 1.0, 1.0)
		typed_label.visible = false
		typed_label.text = ""
		scale = Vector2(1.0, 1.0)

func update_typed_progress(typed: String) -> void:
	if typed_label:
		typed_label.text = typed
		# Show matched characters in green
		var remaining = word.substr(typed.length())
		word_label.text = "[color=#00ff00]%s[/color]%s" % [typed, remaining]

func get_points() -> int:
	if ENEMY_CONFIGS.has(enemy_type):
		return ENEMY_CONFIGS[enemy_type].points
	return 100

func destroy() -> void:
	# Play destruction animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "rotation", rotation + PI * 0.5, 0.15)
	await tween.finished
	
	destroyed.emit(self, get_points())
	queue_free()
