extends Area2D

# 0 = Freeze, 1 = Kill All, 2 = Health
enum Type { FREEZE, KILL_ALL, HEALTH }
var powerup_type: Type

var fall_speed: float = 80.0
var sway_speed: float = 2.0
var sway_amount: float = 30.0
var base_x: float = 0.0
var time_alive: float = 0.0

# ✅ TARGET DISPLAY SIZE for powerup sprites
const POWERUP_DISPLAY_SIZE = 80.0

# ✅ Map powerup types to their .tres files
var powerup_sprite_frames = {
	Type.FREEZE:   "res://asset/animations/powerups/freeze.tres",
	Type.KILL_ALL: "res://asset/animations/powerups/kill_all.tres",
	Type.HEALTH:   "res://asset/animations/powerups/health.tres"
}

# ✅ Emoji fallback labels per type
var powerup_labels = {
	Type.FREEZE:   "❄️",
	Type.KILL_ALL: "⚡",
	Type.HEALTH:   "✚"
}

# ✅ Tint colors per type for glow effect
var powerup_colors = {
	Type.FREEZE:   Color(0.5, 0.8, 1.0),
	Type.KILL_ALL: Color(1.0, 0.9, 0.2),
	Type.HEALTH:   Color(0.2, 1.0, 0.2)
}

var animated_sprite: AnimatedSprite2D
var type_label: Label
var background: Panel


func _ready():
	base_x = position.x

	# Safe node fetching
	animated_sprite = get_node_or_null("SpriteAnim")
	type_label       = get_node_or_null("TypeLabel")
	background       = get_node_or_null("Background")

	# Assign random type if not set by spawner
	if powerup_type == null:
		powerup_type = randi() % 3 as Type

	# ✅ Reset tscn scale before we set our own
	if animated_sprite:
		animated_sprite.scale = Vector2(1.0, 1.0)

	# ✅ Try to load animation first, fall back to emoji
	var loaded = load_powerup_animation(powerup_type)

	if not loaded:
		# Show emoji fallback
		if type_label:
			type_label.visible = true
			type_label.text = powerup_labels.get(powerup_type, "?")
			type_label.modulate = powerup_colors.get(powerup_type, Color.WHITE)

	# ✅ Apply color tint to background panel to match type
	if background:
		var tint: Color = powerup_colors.get(powerup_type, Color.WHITE)
		tint.a = 0.4
		var style = background.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.border_color = powerup_colors.get(powerup_type, Color.WHITE)

	# Connect click
	connect("input_event", _on_input_event)

	# ✅ Start floating glow pulse animation
	_start_pulse_animation()

	print("🎁 PowerUp Spawned: ", powerup_type)


func load_powerup_animation(ptype: Type) -> bool:
	if not animated_sprite:
		return false

	if not powerup_sprite_frames.has(ptype):
		return false

	var frames_path: String = powerup_sprite_frames[ptype]
	if not ResourceLoader.exists(frames_path):
		print("⚠️ PowerUp .tres not found: %s" % frames_path)
		return false

	var frames: SpriteFrames = load(frames_path)
	if frames == null:
		return false

	animated_sprite.sprite_frames = frames
	animated_sprite.stop()

	print("✅ PowerUp loaded: %s" % frames_path)
	print("   Animations: %s" % str(frames.get_animation_names()))

	# Set correct loop/fps for each animation
	if frames.has_animation("idle"):
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 8.0)
	if frames.has_animation("collect"):
		frames.set_animation_loop("collect", false)
		frames.set_animation_speed("collect", 12.0)

	# Start on idle
	if not frames.has_animation("idle"):
		print("   ❌ No idle animation in .tres")
		return false

	_set_sprite_scale(frames, "idle")
	animated_sprite.animation = "idle"
	animated_sprite.frame = 0
	animated_sprite.play("idle")
	animated_sprite.visible = true

	if type_label:
		type_label.visible = false

	print("   ▶ Playing idle, collect ready")
	return true


func _set_sprite_scale(frames: SpriteFrames, anim_name: String):
	if frames.get_frame_count(anim_name) == 0:
		animated_sprite.scale = Vector2(0.5, 0.5)
		return

	var frame_tex: Texture2D = frames.get_frame_texture(anim_name, 0)
	if frame_tex == null:
		animated_sprite.scale = Vector2(0.5, 0.5)
		return

	var frame_size: Vector2 = Vector2.ZERO
	if frame_tex is AtlasTexture:
		frame_size = frame_tex.region.size
	else:
		frame_size = frame_tex.get_size()

	var max_dim: float = max(frame_size.x, frame_size.y)
	if max_dim > 0.0:
		var s: float = POWERUP_DISPLAY_SIZE / max_dim
		animated_sprite.scale = Vector2(s, s)
		print("   PowerUp scale: %.4f" % s)
	else:
		animated_sprite.scale = Vector2(0.5, 0.5)


func _start_pulse_animation():
	# ✅ Gentle floating pulse — works even without sprite animations
	var tween = create_tween()
	tween.set_loops()  # Loop forever
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)


func _process(delta):
	time_alive += delta

	# Fall down
	var new_y = position.y + (fall_speed * delta)

	# Gentle sway
	var new_x = base_x + sin(time_alive * sway_speed) * sway_amount

	position = Vector2(new_x, new_y)

	# Remove if off screen
	if position.y > 800:
		queue_free()


func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activate_powerup()


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if global_position.distance_to(get_global_mouse_position()) < 60:
			activate_powerup()
			get_viewport().set_input_as_handled()


func activate_powerup():
	var game_managers = get_tree().get_nodes_in_group("game_manager")
	if game_managers.size() > 0:
		var gm = game_managers[0]
		match powerup_type:
			Type.FREEZE:
				if gm.has_method("activate_freeze"): gm.activate_freeze()
			Type.KILL_ALL:
				if gm.has_method("activate_kill_all"): gm.activate_kill_all()
			Type.HEALTH:
				if gm.has_method("activate_health_boost"): gm.activate_health_boost()

	# ✅ Play collect animation if available, then disappear
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("collect"):
		# Stop pulse tween so it does not fight the collect animation
		animated_sprite.sprite_frames.set_animation_loop("collect", false)
		animated_sprite.animation = "collect"
		animated_sprite.frame = 0
		animated_sprite.play("collect")
		print("   ▶ Playing collect animation")

		# Wait for collect animation to finish
		await animated_sprite.animation_finished

		# Fade out after collect finishes
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(self, "modulate:a", 0.0, 0.15)
		await tween.finished
	else:
		# No collect animation — just scale up and fade out
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.2)
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		await tween.finished

	queue_free()