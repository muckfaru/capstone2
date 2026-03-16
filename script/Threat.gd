extends Area2D

signal threat_blocked(threat_type, defense_used)
signal threat_succeeded(threat_type, target_asset)

@export var threat_type = "phishing"
@export var target_asset = "employee_pc"
@export var speed = 100.0
@export var max_health = 1

var target_position = Vector2.ZERO
var is_moving = false
var is_blocked = false
var click_count = 0
var current_health = 1

# ✅ TARGET DISPLAY SIZE — adjust this single value to resize all threats
const THREAT_DISPLAY_SIZE = 100.0

# ✅ Map threat types to their .tres animation files (same pattern as SOC game)
var threat_sprite_frames = {
	"phishing":       "res://asset/animations/threats/phishing.tres",
	"brute_force":    "res://asset/animations/threats/brute_force.tres",
	"malware":        "res://asset/animations/threats/malware.tres",
	"ddos":           "res://asset/animations/threats/ddos.tres",
	"sql_injection":  "res://asset/animations/threats/sql_injection.tres",
	"ransomware":     "res://asset/animations/threats/ransomware.tres",
	"zero_day":       "res://asset/animations/threats/zero_day.tres",
	"insider_threat": "res://asset/animations/threats/insider_threat.tres"
}

# ✅ Fallback PNG paths if no .tres exists
var threat_textures = {
	"phishing":       "res://asset/threats/phishing.png",
	"brute_force":    "res://asset/threats/brute_force.png",
	"malware":        "res://asset/threats/malware.png",
	"ddos":           "res://asset/threats/ddos.png",
	"sql_injection":  "res://asset/threats/sql_injection.png",
	"ransomware":     "res://asset/threats/ransomware.png",
	"zero_day":       "res://asset/threats/zero_day.png",
	"insider_threat": "res://asset/threats/insider_threat.png"
}

var threat_names = {
	"phishing":       "Phishing",
	"brute_force":    "Brute Force",
	"malware":        "Malware",
	"ddos":           "DDoS",
	"sql_injection":  "SQL Injection",
	"ransomware":     "Ransomware",
	"zero_day":       "Zero Day",
	"insider_threat": "Insider Threat"
}

var threat_icons = {
	"phishing":       "🎣",
	"brute_force":    "🔨",
	"malware":        "🦠",
	"ddos":           "💥",
	"sql_injection":  "💉",
	"ransomware":     "🔒",
	"zero_day":       "⚡",
	"insider_threat": "🕵️"
}

# ✅ Get nodes the same safe way the SOC game does
var animated_sprite: AnimatedSprite2D
var icon_label: Label
var name_label: Label
var health_bar: ColorRect
var health_label: Label

func _ready():
	current_health = max_health
	add_to_group("threats")
	connect("input_event", _on_input_event)
	set_process_input(true)
	collision_layer = 1
	collision_mask = 0
	input_pickable = true

	# ✅ Use get_node_or_null — exactly like SOC game — safe and no crash
	animated_sprite = get_node_or_null("SpriteAnim")
	icon_label       = get_node_or_null("Label")
	name_label       = get_node_or_null("NameLabel")
	health_bar       = get_node_or_null("HealthBar")
	health_label     = get_node_or_null("HealthLabel")

	# ✅ Reset the .tscn hardcoded scale before we set our own
	if animated_sprite:
		animated_sprite.scale = Vector2(1.0, 1.0)
		animated_sprite.flip_h = false

	print("🦠 Threat._ready() | type:%s target:%s hp:%d" % [threat_type, target_asset, max_health])

	# ✅ Load animations using the same pattern as SOC's load_threat_animations()
	load_threat_animations(threat_type)

	if name_label:
		name_label.text = threat_names.get(threat_type, threat_type)

	update_health_display()


# ✅ Directly copied pattern from SOC game's load_threat_animations()
func load_threat_animations(type: String):
	if not animated_sprite:
		push_error("❌ SpriteAnim node not found on Threat!")
		return

	# Step 1: Try the .tres SpriteFrames file
	if threat_sprite_frames.has(type):
		var frames_path: String = threat_sprite_frames[type]
		if ResourceLoader.exists(frames_path):
			var frames: SpriteFrames = load(frames_path)
			if frames:
				animated_sprite.sprite_frames = frames
				# Stop whatever the .tres was last playing in the editor
				animated_sprite.stop()

				print("✅ Loaded .tres: %s" % frames_path)
				print("   Animations found: %s" % str(frames.get_animation_names()))

				# Find walk animation and force it to play
				var walk_name: String = find_walk_animation(frames)
				if walk_name != "":
					# Force correct FPS and loop on all animations
					frames.set_animation_loop(walk_name, true)
					frames.set_animation_speed(walk_name, 10.0)
					if frames.has_animation("attack"):
						frames.set_animation_loop("attack", false)
						frames.set_animation_speed("attack", 12.0)
					if frames.has_animation("destroy"):
						frames.set_animation_loop("destroy", false)
						frames.set_animation_speed("destroy", 12.0)
					set_sprite_scale(frames, walk_name)
					# Explicitly set animation name then play
					animated_sprite.animation = walk_name
					animated_sprite.frame = 0
					animated_sprite.play(walk_name)
					print("   Playing walk: '%s' at 10fps" % walk_name)
				else:
					print("   No walk found — using first animation")
					var all_anims: Array = frames.get_animation_names()
					if all_anims.size() > 0:
						var first: String = all_anims[0]
						frames.set_animation_loop(first, true)
						frames.set_animation_speed(first, 10.0)
						set_sprite_scale(frames, first)
						animated_sprite.animation = first
						animated_sprite.frame = 0
						animated_sprite.play(first)
				return

	# Step 2: Fallback to single PNG (same as SOC's create_fallback_sprite_frames)
	print("⚠️ No .tres found for '%s' — using PNG fallback" % type)
	create_fallback_sprite_frames(type)


func find_walk_animation(frames: SpriteFrames) -> String:
	# Check common walk animation names
	for candidate in ["walk", "Walk", "WALK", "run", "Run", "idle", "Idle", "move", "default"]:
		if frames.has_animation(candidate):
			return candidate
	return ""


func set_sprite_scale(frames: SpriteFrames, anim_name: String):
	if frames.get_frame_count(anim_name) == 0:
		animated_sprite.scale = Vector2(0.5, 0.5)
		return

	var frame_tex: Texture2D = frames.get_frame_texture(anim_name, 0)
	if frame_tex == null:
		animated_sprite.scale = Vector2(0.5, 0.5)
		return

	# KEY FIX: AtlasTexture (spritesheet regions) returns region size = one frame
	# Regular Texture2D returns full image size
	var frame_size: Vector2 = Vector2.ZERO

	if frame_tex is AtlasTexture:
		var region: Rect2 = frame_tex.region
		frame_size = region.size
		print("   AtlasTexture region: " + str(frame_size))
	else:
		frame_size = frame_tex.get_size()
		print("   Regular texture size: " + str(frame_size))

	var max_dim: float = max(frame_size.x, frame_size.y)
	print("   max_dim: " + str(max_dim))

	if max_dim > 0.0:
		var s: float = THREAT_DISPLAY_SIZE / max_dim
		animated_sprite.scale = Vector2(s, s)
		print("   Scale set to: " + str(s))
	else:
		animated_sprite.scale = Vector2(0.5, 0.5)
		print("   Fallback scale 0.5")


# ✅ Same pattern as SOC's create_fallback_sprite_frames()
func create_fallback_sprite_frames(type: String):
	if not animated_sprite:
		return

	# Try PNG first
	var png_path: String = threat_textures.get(type, "")
	if png_path != "" and ResourceLoader.exists(png_path):
		var tex: Texture2D = load(png_path)
		var frames: SpriteFrames = SpriteFrames.new()

		frames.add_animation("walk")
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 5.0)
		frames.add_frame("walk", tex)

		frames.add_animation("destroy")
		frames.set_animation_loop("destroy", false)
		frames.set_animation_speed("destroy", 8.0)

		frames.add_animation("attack")
		frames.set_animation_loop("attack", false)
		frames.set_animation_speed("attack", 8.0)

		animated_sprite.sprite_frames = frames
		set_sprite_scale(frames, "walk")
		animated_sprite.play("walk")
		print("✅ PNG fallback loaded: %s" % png_path)
		return

	# Last resort: emoji label
	print("❌ No PNG found for '%s' — using emoji" % type)
	if icon_label:
		icon_label.text = threat_icons.get(type, "❓")
		icon_label.visible = true
	if animated_sprite:
		animated_sprite.visible = false


func start_moving():
	is_moving = true

	# Flip sprite to face toward its target based on spawn side
	# Spawned from RIGHT (x > 600) = face LEFT = flip_h true
	# Spawned from LEFT  (x < 600) = face RIGHT = flip_h false
	if animated_sprite:
		animated_sprite.flip_h = global_position.x > 600

	print("🏃 %s moving | hp:%d/%d | facing:%s" % [threat_type, current_health, max_health, "left" if global_position.x > 600 else "right"])


func _process(delta):
	if is_moving and not is_blocked:
		var dir: Vector2 = (target_position - global_position).normalized()
		global_position += dir * speed * delta
		if global_position.distance_to(target_position) < 20:
			reach_target()


func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if global_position.distance_to(get_global_mouse_position()) < 70:
			handle_click()
			get_viewport().set_input_as_handled()


func handle_click():
	print("🎯 CLICK | %s | hp:%d | blocked:%s" % [threat_type, current_health, str(is_blocked)])
	if is_blocked:
		return

	click_count += 1
	var defense_tool = get_tree().get_first_node_in_group("defense_tools")
	if defense_tool:
		var defense: String = defense_tool.get_class_selected_defense_type()
		if defense != "":
			emit_signal("threat_blocked", threat_type, defense)
		else:
			print("   ❌ No defense selected")
			click_count = 0
	else:
		print("   ❌ No defense_tools group!")
		click_count = 0


func take_damage() -> bool:
	current_health -= 1
	click_count = 0
	print("💥 %s damaged | hp:%d/%d" % [threat_type, current_health, max_health])
	update_health_display()

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.08)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.08)

	if current_health <= 0:
		block_threat("destroyed")
		return true
	return false


func update_health_display():
	if health_bar:
		var pct: float = float(current_health) / float(max_health)
		health_bar.size = Vector2(60.0 * pct, 8)
		health_bar.position = Vector2(-30, -75)
		if pct > 0.66:
			health_bar.color = Color(0, 1, 0)
		elif pct > 0.33:
			health_bar.color = Color(1, 1, 0)
		else:
			health_bar.color = Color(1, 0, 0)
		health_bar.visible = max_health > 1

	if health_label:
		if max_health > 1:
			health_label.text = "%d/%d" % [current_health, max_health]
			health_label.visible = true
		else:
			health_label.visible = false


func block_threat(defense_name: String):
	print("🛡️ block_threat | %s | %s" % [threat_type, defense_name])
	if is_blocked:
		return

	is_blocked = true
	is_moving = false
	input_pickable = false

	if health_bar: health_bar.visible = false
	if health_label: health_label.visible = false
	if name_label: name_label.visible = false

	# ✅ Play destroy animation — same pattern as SOC's neutralize()
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("destroy"):
			animated_sprite.sprite_frames.set_animation_loop("destroy", false)
			animated_sprite.play("destroy")
			await animated_sprite.animation_finished
		else:
			# Fallback tween if no destroy animation
			var saved_scale: Vector2 = animated_sprite.scale
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(self, "modulate", Color(0.2, 1.0, 0.2, 0.0), 0.4)
			tween.tween_property(animated_sprite, "scale", saved_scale * 1.8, 0.4)
			await tween.finished
	else:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished

	queue_free()


func reach_target():
	if is_blocked:
		return
	print("💥 %s reached %s" % [threat_type, target_asset])
	is_moving = false

	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("attack"):
			animated_sprite.sprite_frames.set_animation_loop("attack", false)
			animated_sprite.play("attack")
			await get_tree().create_timer(0.4).timeout

	emit_signal("threat_succeeded", threat_type, target_asset)
	queue_free()
