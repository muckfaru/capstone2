extends Area2D

@export var asset_name = ""
@export var asset_icon = ""
@export var max_health = 5

var current_health = max_health

# ✅ TARGET DISPLAY SIZE — adjust this single value to resize all assets
const ASSET_DISPLAY_SIZE = 120.0

# ✅ Map asset node names to their .tres animation files
var asset_sprite_frames = {
	"employee_pc":  "res://asset/animations/assets/employee_pc.tres",
	"database":     "res://asset/animations/assets/database.tres",
	"router":       "res://asset/animations/assets/router.tres",
	"email_server": "res://asset/animations/assets/email_server.tres",
	"backup":       "res://asset/animations/assets/backup.tres",
	"ceo_laptop":   "res://asset/animations/assets/ceo_laptop.tres"
}

var animated_sprite: AnimatedSprite2D
var icon_label
var name_label: Label
var health_bar: ColorRect
var health_label

# Track if hit animation is currently playing to avoid interrupting it
var is_playing_hit: bool = false


func _ready():
	current_health = max_health

	animated_sprite = get_node_or_null("SpriteAnim")
	icon_label       = get_node_or_null("IconLabel")
	name_label       = get_node_or_null("NameLabel")
	health_bar       = get_node_or_null("HealthBar")
	health_label     = get_node_or_null("HealthLabel")

	if animated_sprite:
		animated_sprite.scale = Vector2(1.0, 1.0)

	if name_label:
		name_label.text = asset_name.replace("_", " ").capitalize()

	load_asset_animations(name)
	sync_with_game_manager()
	update_health_bar()


func load_asset_animations(node_name: String):
	if not animated_sprite:
		push_error("❌ SpriteAnim not found on Asset: %s" % node_name)
		return

	if asset_sprite_frames.has(node_name):
		var frames_path: String = asset_sprite_frames[node_name]
		if ResourceLoader.exists(frames_path):
			var frames: SpriteFrames = load(frames_path)
			if frames:
				animated_sprite.sprite_frames = frames
				animated_sprite.stop()

				print("✅ Asset '%s' loaded: %s" % [node_name, frames_path])
				print("   Animations: %s" % str(frames.get_animation_names()))

				# ✅ Set correct loop/fps for all three animations
				if frames.has_animation("idle"):
					frames.set_animation_loop("idle", true)
					frames.set_animation_speed("idle", 8.0)
				if frames.has_animation("hit"):
					frames.set_animation_loop("hit", false)
					frames.set_animation_speed("hit", 12.0)
				if frames.has_animation("destroy"):
					frames.set_animation_loop("destroy", false)
					frames.set_animation_speed("destroy", 12.0)

				# Start on idle
				var idle_name: String = find_idle_animation(frames)
				if idle_name != "":
					set_sprite_scale(frames, idle_name)
					animated_sprite.animation = idle_name
					animated_sprite.frame = 0
					animated_sprite.play(idle_name)
					print("   ▶ Playing idle: '%s'" % idle_name)
					if icon_label:
						icon_label.visible = false
				else:
					print("   ⚠️ No idle found — playing first available")
					var all_anims: Array = frames.get_animation_names()
					if all_anims.size() > 0:
						var first: String = all_anims[0]
						frames.set_animation_loop(first, true)
						set_sprite_scale(frames, first)
						animated_sprite.animation = first
						animated_sprite.frame = 0
						animated_sprite.play(first)
				return

	# No .tres — use icon label fallback
	print("⚠️ No .tres found for '%s' — using icon label" % node_name)
	if animated_sprite:
		animated_sprite.visible = false
	if icon_label and asset_icon != "":
		icon_label.visible = true
		icon_label.text = asset_icon


func find_idle_animation(frames: SpriteFrames) -> String:
	for candidate in ["idle", "Idle", "IDLE", "default", "Default"]:
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

	var frame_size: Vector2 = Vector2.ZERO
	if frame_tex is AtlasTexture:
		frame_size = frame_tex.region.size
		print("   AtlasTexture region: " + str(frame_size))
	else:
		frame_size = frame_tex.get_size()
		print("   Regular texture size: " + str(frame_size))

	var max_dim: float = max(frame_size.x, frame_size.y)
	if max_dim > 0.0:
		var s: float = ASSET_DISPLAY_SIZE / max_dim
		animated_sprite.scale = Vector2(s, s)
		print("   Scale set to: " + str(s))
	else:
		animated_sprite.scale = Vector2(0.5, 0.5)


func sync_with_game_manager():
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and name in gm.assets_health:
		current_health = gm.assets_health[name]
		max_health = gm.assets_max_health[name]
		print("📊 %s synced: %d/%d" % [name, current_health, max_health])


func take_damage():
	current_health -= 1
	update_health_bar()

	# ✅ Play hit → then return to idle (or stay on destroy if dead)
	if current_health > 0:
		play_hit_animation()
	else:
		play_destroy_animation()

	shake_asset()


func play_hit_animation():
	if not animated_sprite or not animated_sprite.sprite_frames:
		# No sprite — just flash red
		_flash_red()
		return

	if animated_sprite.sprite_frames.has_animation("hit"):
		is_playing_hit = true

		# Flash red tint while playing hit
		animated_sprite.modulate = Color(1, 0.3, 0.3)

		animated_sprite.animation = "hit"
		animated_sprite.frame = 0
		animated_sprite.play("hit")
		print("💥 %s playing 'hit' animation" % name)

		# Wait for hit animation to finish then return to idle
		await animated_sprite.animation_finished

		# Only return to idle if still alive and not compromised
		if current_health > 0 and is_instance_valid(self):
			animated_sprite.modulate = Color.WHITE
			if animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.animation = "idle"
				animated_sprite.frame = 0
				animated_sprite.play("idle")
				print("   ↩ Returned to 'idle'")

		is_playing_hit = false
	else:
		# No hit animation — flash red as fallback
		print("⚠️ No 'hit' animation on %s — using flash fallback" % name)
		_flash_red()


func play_destroy_animation():
	if not animated_sprite or not animated_sprite.sprite_frames:
		_grey_out()
		return

	if animated_sprite.sprite_frames.has_animation("destroy"):
		# Stop any current animation first
		animated_sprite.stop()
		animated_sprite.modulate = Color.WHITE

		animated_sprite.animation = "destroy"
		animated_sprite.frame = 0
		animated_sprite.play("destroy")
		print("💀 %s playing 'destroy' animation" % name)

		await animated_sprite.animation_finished

		# Grey out after destroy finishes
		if is_instance_valid(self):
			_grey_out()
	else:
		# No destroy animation — just grey out
		print("⚠️ No 'destroy' animation on %s — greying out" % name)
		_grey_out()

	_show_compromised_label()


func _flash_red():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)


func _grey_out():
	modulate = Color(0.3, 0.3, 0.3)


func _show_compromised_label():
	if name_label:
		name_label.text = "COMPROMISED"
		name_label.modulate = Color(1, 0, 0)
	if health_label:
		health_label.text = "0/%d" % max_health
		health_label.add_theme_color_override("font_color", Color(1, 0, 0))


func shake_asset():
	var orig: Vector2 = position
	var tween = create_tween()
	tween.tween_property(self, "position", orig + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", orig + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", orig + Vector2(0, 5), 0.05)
	tween.tween_property(self, "position", orig + Vector2(0, -5), 0.05)
	tween.tween_property(self, "position", orig, 0.05)


func update_health_bar():
	if health_bar:
		var pct: float = float(current_health) / float(max_health)
		health_bar.size.x = 60.0 * pct
		if pct <= 0.2:
			health_bar.color = Color(1, 0, 0)
		elif pct <= 0.4:
			health_bar.color = Color(1, 0.5, 0)
		else:
			health_bar.color = Color(0, 1, 0)

	if health_label:
		var pct: float = float(current_health) / float(max_health)
		health_label.text = "%d/%d" % [current_health, max_health]
		if current_health <= 0:
			health_label.add_theme_color_override("font_color", Color(1, 0, 0))
			health_label.text = "0/%d" % max_health
		elif pct <= 0.33:
			health_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
		else:
			health_label.add_theme_color_override("font_color", Color(1, 1, 1))


func on_compromised():
	# Called by GameManager — triggers destroy animation
	play_destroy_animation()


func set_health(new_health: int):
	var was_dead = (current_health <= 0)
	current_health = new_health
	update_health_bar()
	
	if current_health > 0:
		# ✅ Revive visually!
		modulate = Color.WHITE
		if name_label:
			name_label.text = asset_name.replace("_", " ").capitalize()
			name_label.modulate = Color.WHITE
			
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE
			if (was_dead or animated_sprite.animation == "destroy") and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.animation = "idle"
				animated_sprite.frame = 0
				animated_sprite.play("idle")


func get_health() -> int:
	return current_health