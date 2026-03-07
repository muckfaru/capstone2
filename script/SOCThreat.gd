# ✅ FIXED: Speed-up capped at 50% increase (was unlimited)

extends CharacterBody2D

signal reached_target(threat)

var threat_type := ""
var threat_data := {}
var tutorial_mode := false
var game_manager  # Reference to main game for audio

var speed := 30.0
var base_speed := 30.0
var target_position := Vector2(280, 0)
var time_alive := 0.0
var max_time := 15.0

var is_neutralized := false

# Animation control
var current_animation := "idle"

# Sprite sheet mappings (using alien sprites)
var threat_sprite_frames := {
	"weak_key": "res://asset/alien/brute_force_frames.tres",
	"ecb_pattern": "res://asset/alien/sql_injection_frames.tres",
	"des_legacy": "res://asset/alien/port_scanner_frames.tres",
	"no_authentication": "res://asset/alien/credential_stuffing_frames.tres",
	"iv_reuse": "res://asset/alien/ddos_flood_frames.tres",
	"key_reuse": "res://asset/alien/malware_beacon_frames.tres",
	"padding_oracle": "res://asset/alien/data_exfiltration_frames.tres",
	"plaintext_keys": "res://asset/alien/lateral_movement_frames.tres",
	"plaintext_transit": "res://asset/alien/port_scanner_frames.tres"
}

const COLLISION_SIZE := Vector2(80, 80)

# Node references
var animated_sprite: AnimatedSprite2D
var collision_shape: CollisionShape2D
var info_panel: Panel
var threat_name_label: Label
var description_label: Label
var tutorial_hint: RichTextLabel
var progress_bar: ProgressBar
var time_label: Label

func _ready():
	# Get node references safely
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")
	info_panel = get_node_or_null("VisualContainer/InfoPanel")
	threat_name_label = get_node_or_null("VisualContainer/InfoPanel/ThreatName")
	description_label = get_node_or_null("VisualContainer/InfoPanel/Description")
	tutorial_hint = get_node_or_null("VisualContainer/InfoPanel/TutorialHint")
	progress_bar = get_node_or_null("VisualContainer/ProgressBar")
	time_label = get_node_or_null("VisualContainer/ProgressBar/TimeLabel")
	
	if not animated_sprite:
		push_error("❌ AnimatedSprite2D not found!")
		return
	
	if not collision_shape:
		push_error("❌ CollisionShape2D not found!")
		return
	
	# FLIP THE SPRITE TO FACE LEFT
	animated_sprite.flip_h = true
	
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	set_physics_process(false)

func setup(type: String, data: Dictionary, is_tutorial: bool):
	threat_type = type
	threat_data = data
	tutorial_mode = is_tutorial
	
	load_threat_animations(type)
	setup_collision()
	
	if threat_name_label:
		threat_name_label.text = data.name
	if description_label:
		description_label.text = data.description
	
	if tutorial_hint:
		if tutorial_mode:
			tutorial_hint.visible = true
			tutorial_hint.text = "[color=cyan]" + data.correct_command + "[/color]"
			max_time = 20.0
		else:
			tutorial_hint.visible = false
	
	base_speed = data.speed
	speed = base_speed
	
	target_position.y = position.y
	
	play_animation("idle")

func load_threat_animations(type: String):
	if not animated_sprite:
		push_error("❌ Cannot load animations - AnimatedSprite2D is null!")
		return
	
	# Try to load pre-configured SpriteFrames
	if threat_sprite_frames.has(type):
		var frames_path = threat_sprite_frames[type]
		if ResourceLoader.exists(frames_path):
			animated_sprite.sprite_frames = load(frames_path)
			print("✅ Loaded sprite frames: " + frames_path)
			return
	
	# Fallback to colored squares
	print("⚠️  Creating fallback sprite frames for: " + type)
	create_fallback_sprite_frames(type)

func create_fallback_sprite_frames(type: String):
	if not animated_sprite:
		return
	
	var sprite_frames = SpriteFrames.new()
	
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 5.0)
	sprite_frames.set_animation_loop("idle", true)
	
	sprite_frames.add_animation("attack")
	sprite_frames.set_animation_speed("attack", 8.0)
	sprite_frames.set_animation_loop("attack", true)
	
	sprite_frames.add_animation("death")
	sprite_frames.set_animation_speed("death", 10.0)
	sprite_frames.set_animation_loop("death", false)
	
	var color = threat_data.get("color", Color.WHITE)
	
	for i in range(4):
		var texture = create_colored_texture(color, 64, 64, i)
		sprite_frames.add_frame("idle", texture)
	
	for i in range(6):
		var texture = create_colored_texture(color, 64, 64, i)
		sprite_frames.add_frame("attack", texture)
	
	for i in range(8):
		var fade_alpha = 1.0 - (float(i) / 8.0)
		var fade_color = Color(color.r, color.g, color.b, fade_alpha)
		var texture = create_colored_texture(fade_color, 64, 64, i)
		sprite_frames.add_frame("death", texture)
	
	animated_sprite.sprite_frames = sprite_frames

func create_colored_texture(color: Color, width: int, height: int, frame: int) -> ImageTexture:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var pulse = 1.0 + sin(frame * 0.5) * 0.2
	var adjusted_color = Color(
		color.r * pulse,
		color.g * pulse,
		color.b * pulse,
		color.a
	)
	
	img.fill(adjusted_color)
	
	# Add border
	for x in range(width):
		for y in range(height):
			if x < 3 or x >= width - 3 or y < 3 or y >= height - 3:
				img.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(img)

func setup_collision():
	if not collision_shape:
		return
	
	if collision_shape.shape == null:
		collision_shape.shape = RectangleShape2D.new()
	
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = COLLISION_SIZE

func play_animation(anim_name: String):
	if not animated_sprite or animated_sprite.sprite_frames == null:
		return
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		current_animation = anim_name
		animated_sprite.play(anim_name)

func _process(delta):
	if is_neutralized:
		return
	
	position.x -= speed * delta
	time_alive += delta
	
	if progress_bar:
		var progress = 1.0 - (time_alive / max_time)
		progress_bar.value = progress
		
		var fill_style = progress_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			if progress < 0.3:
				fill_style.bg_color = Color.RED
				if current_animation != "attack":
					play_animation("attack")
			elif progress < 0.6:
				fill_style.bg_color = Color.YELLOW
			else:
				fill_style.bg_color = Color.GREEN
	
	if time_label:
		var time_remaining = max_time - time_alive
		time_label.text = str(int(ceil(time_remaining))) + "s"
	
	if position.x <= target_position.x or time_alive >= max_time:
		reached_target.emit(self)
		queue_free()

# ✅ FIXED: Speed-up capped at 50% maximum increase
func speed_up():
	"""Wrong command makes threat move faster - capped at 50% increase"""
	
	# Only increase speed if below 150% of base speed
	if speed < base_speed * 1.5:
		speed *= 1.2  # ✅ FIXED: 20% increase (down from 30%)
		
		# Cap at 150% max
		if speed > base_speed * 1.5:
			speed = base_speed * 1.5
		
		print("⚡ Threat sped up: " + str(speed) + " (max: " + str(base_speed * 1.5) + ")")
	else:
		print("⚡ Threat already at max speed")
	
	if info_panel:
		info_panel.modulate = Color(1.0, 0.5, 0.5)
	
	play_animation("attack")
	
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(info_panel):
		info_panel.modulate = Color.WHITE

func neutralize():
	is_neutralized = true
	
	play_animation("death")
	
	if game_manager and game_manager.has_method("play_threat_neutralized_sound"):
		game_manager.play_threat_neutralized_sound()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0, 1, 0, 0), 0.8)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.8)
	
	await tween.finished
	queue_free()