extends Area2D

signal collected(powerup)

var powerup_type := "health"
var powerup_data := {}

var fall_speed := 80.0
var rotation_speed := 2.0
var bob_amplitude := 5.0
var bob_speed := 3.0

var time_alive := 0.0
var despawn_time := 12.0
var start_y := 0.0

# ✅ FIX: Collection trigger position
const COLLECTION_Y := 500.0  # Auto-collect when reaching terminal area

# References to nodes
var icon_sprite: Sprite2D  # Custom PNG icon
var glow_sprite: Sprite2D  # Background glow effect
var label: Label
var particles: CPUParticles2D

var collected_already := false  # Prevent double collection

func _ready():
	# Get node references safely
	icon_sprite = get_node_or_null("IconSprite")
	glow_sprite = get_node_or_null("GlowSprite")
	label = get_node_or_null("Label")
	particles = get_node_or_null("CPUParticles2D")
	
	# ✅ REMOVED: area_entered - not needed since we check position
	# Power-ups auto-collect when they reach the terminal area
	
	input_pickable = false
	
	start_y = position.y

func setup(type: String, data: Dictionary):
	powerup_type = type
	powerup_data = data
	
	# Try to load custom texture
	var texture_path = data.get("texture_path", "")
	if texture_path != "" and FileAccess.file_exists(texture_path):
		# Load the custom PNG texture
		var custom_texture = load(texture_path)
		if custom_texture and icon_sprite:
			icon_sprite.texture = custom_texture
			icon_sprite.visible = true
			
			# ✅ FIX TEXTURE SCALING: Scale down the texture to fit properly
			var target_size = 60.0  # Target display size in pixels
			if custom_texture.get_width() > 0:
				var scale_factor = target_size / custom_texture.get_width()
				icon_sprite.scale = Vector2(scale_factor, scale_factor)
			else:
				# Fallback if texture size unknown
				icon_sprite.scale = Vector2(0.25, 0.25)
			
			# Tint the icon with the power-up color
			icon_sprite.modulate = data.get("color", Color.WHITE)
			
			# Hide the emoji label since we have a texture
			if label:
				label.visible = false
			
			print("✅ Loaded custom texture: " + texture_path + " (scaled to " + str(icon_sprite.scale) + ")")
	else:
		# Fallback to emoji if texture not found
		if label:
			label.text = data.get("label", "❤️")
			label.visible = true
			
			# Make label bigger for better visibility
			if label.has_theme_font_size_override("font_size"):
				label.add_theme_font_size_override("font_size", 40)
		
		# Hide icon sprite if using emoji
		if icon_sprite:
			icon_sprite.visible = false
		
		print("⚠️ Texture not found, using emoji fallback: " + texture_path)
	
	# Update glow sprite color
	if glow_sprite:
		glow_sprite.modulate = data.get("color", Color.GREEN)
	
	# Update particle color
	if particles:
		particles.color = data.get("color", Color.GREEN)
	
	# Adjust fall speed based on rarity
	match type:
		"destroy_all":
			fall_speed = 60.0  # Falls slower (rarer, more valuable)
			rotation_speed = 3.0  # Spins faster
		"time_stop":
			fall_speed = 70.0
			rotation_speed = 2.5
		"health":
			fall_speed = 80.0  # Falls fastest (most common)
			rotation_speed = 2.0

func _process(delta):
	# Safety check - don't process if being deleted
	if not is_inside_tree():
		return
	
	time_alive += delta
	
	# Fall down slowly
	position.y += fall_speed * delta
	
	# ✅ FIX: AUTO-COLLECT when reaching terminal area
	if not collected_already and position.y >= COLLECTION_Y:
		collect()
		return
	
	# Gentle bobbing motion
	var bob_offset = sin(time_alive * bob_speed) * bob_amplitude
	if label:
		label.position.y = -30 + bob_offset
	
	# Rotate icon sprite (with proper scaling preserved)
	if icon_sprite and icon_sprite.visible:
		icon_sprite.rotation += rotation_speed * delta
		
		# Special effect for destroy_all - intense pulsing
		if powerup_type == "destroy_all":
			var intense_pulse = 1.0 + sin(time_alive * 8.0) * 0.3
			icon_sprite.modulate = Color(intense_pulse, 0.2, 0.2)
	
	# Rotate glow sprite (opposite direction for cool effect)
	if glow_sprite:
		glow_sprite.rotation -= rotation_speed * 0.5 * delta
		
		# Special effect for destroy_all - intense pulsing
		if powerup_type == "destroy_all":
			var intense_pulse = 1.0 + sin(time_alive * 8.0) * 0.3
			glow_sprite.modulate = Color(intense_pulse, 0.2, 0.2)
	
	# Pulse scale effect (only affects the whole power-up, not individual sprites)
	var pulse = 1.0 + sin(time_alive * 4.0) * 0.15
	
	# Destroy all has bigger pulse
	if powerup_type == "destroy_all":
		pulse = 1.1 + sin(time_alive * 5.0) * 0.25
	
	scale = Vector2(pulse, pulse)
	
	# Flash warning before despawning
	if time_alive > despawn_time - 2.0:
		var alpha = 0.4 + abs(sin(time_alive * 8.0)) * 0.6
		modulate.a = alpha
	
	# Despawn if too old or off screen
	if time_alive >= despawn_time or position.y > 750:
		if is_inside_tree():
			print("💊 Power-up despawned: " + powerup_type)
			queue_free()

func collect():
	"""Called when collected"""
	# Prevent double collection
	if collected_already or not is_inside_tree():
		return
	
	collected_already = true
	
	print("✅ Power-up collected: " + powerup_type)
	
	# Emit signal
	collected.emit(self)
	
	# Disconnect signals to prevent further interaction
	set_process(false)
	input_pickable = false
	
	# Start particle effect
	if particles and is_instance_valid(particles):
		particles.emitting = true
		
		# Safely reparent particles if possible
		var parent = get_parent()
		if parent and is_instance_valid(parent):
			particles.reparent(parent)
			
			# Delete particles after they finish
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(particles):
					particles.queue_free()
			)
	
	# Visual collection effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	
	await tween.finished
	
	# Safe cleanup
	if is_inside_tree():
		queue_free()