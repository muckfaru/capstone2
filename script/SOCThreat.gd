extends Node2D

signal reached_target(threat)

var threat_type := ""
var threat_data := {}
var tutorial_mode := false

var speed := 30.0
var base_speed := 30.0
var target_position := Vector2(280, 0)
var time_alive := 0.0
var max_time := 15.0

var is_neutralized := false

# Texture paths mapping - UPDATE THESE TO MATCH YOUR ACTUAL PNG FILENAMES
var threat_textures := {
	"port_scanner": "res://asset/alien/port_scanner.png",
	"brute_force": "res://asset/alien/brute_force.png",
	"sql_injection": "res://asset/alien/sql_injection.png",
	"ddos_flood": "res://asset/alien/ddos_flood.png",
	"malware_beacon": "res://asset/alien/malware_beacon.png",
	"credential_stuffing": "res://asset/alien/credential_stuffing.png",
	"data_exfiltration": "res://asset/alien/data_exfiltration.png",
	"lateral_movement": "res://asset/alien/lateral_movement.png"
}

# Target size for all icons (in pixels)
const ICON_SIZE := 180.0  # Adjust this to make icons bigger/smaller

# Store the original scale for pulse animation
var original_scale := Vector2.ONE

func setup(type: String, data: Dictionary, is_tutorial: bool):
	threat_type = type
	threat_data = data
	tutorial_mode = is_tutorial
	
	# Load and set the PNG texture
	load_threat_texture(type)
	
	# Set text properties
	$VisualContainer/InfoPanel/ThreatName.text = data.name
	$VisualContainer/InfoPanel/Description.text = data.description
	
	# Tutorial mode shows hints
	if tutorial_mode:
		$VisualContainer/InfoPanel/TutorialHint.visible = true
		$VisualContainer/InfoPanel/TutorialHint.text = "[color=cyan]Command: " + data.correct_command + "[/color]"
		max_time = 20.0  # More time in tutorial
	
	# Set speed
	base_speed = data.speed
	speed = base_speed
	
	# Adjust target position based on screen position
	target_position.y = position.y

func load_threat_texture(type: String):
	var icon_node = $VisualContainer/ThreatIcon
	
	# Check if the icon node is actually a Sprite2D
	if not icon_node is Sprite2D:
		push_error("ThreatIcon must be a Sprite2D node! Current type: " + icon_node.get_class())
		return
	
	# Check if we have a texture path for this threat type
	if threat_textures.has(type):
		var texture_path = threat_textures[type]
		
		# Try to load the texture
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			icon_node.texture = texture
			
			# Scale the texture to our target size
			if texture:
				var texture_size = texture.get_size()
				var scale_factor = ICON_SIZE / max(texture_size.x, texture_size.y)
				# FLIP HORIZONTALLY: Use negative X scale to flip the sprite left
				icon_node.scale = Vector2(-scale_factor, scale_factor)
				original_scale = icon_node.scale
			else:
				push_warning("Failed to load texture: " + texture_path)
				create_fallback_texture(icon_node, type)
		else:
			# Fallback: use a colored square if texture not found
			push_warning("Texture not found: " + texture_path)
			create_fallback_texture(icon_node, type)
	else:
		# No texture mapping for this threat type
		push_warning("No texture mapping for threat type: " + type)
		create_fallback_texture(icon_node, type)

func create_fallback_texture(icon_node: Node, type: String):
	# Only proceed if it's a Sprite2D
	if not icon_node is Sprite2D:
		return
	
	# Create a simple colored square as fallback
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# Use the color from threat_data if available, otherwise use a default color
	var fill_color = threat_data.get("color", Color.WHITE)
	img.fill(fill_color)
	
	# Add a border to make it more visible
	for x in range(64):
		for y in range(64):
			if x < 4 or x >= 60 or y < 4 or y >= 60:
				img.set_pixel(x, y, Color.BLACK)
	
	var texture = ImageTexture.create_from_image(img)
	icon_node.texture = texture
	# FLIP HORIZONTALLY: Use negative X scale
	icon_node.scale = Vector2(-1, 1)
	original_scale = icon_node.scale

func _on_animation_timer_timeout():
	if is_neutralized:
		return
	
	# Move toward target
	position.x -= speed * 0.05
	time_alive += 0.05
	
	# Update progress bar
	var progress = 1.0 - (time_alive / max_time)
	$VisualContainer/ProgressBar.value = progress
	
	# Calculate time remaining and update label
	var time_remaining = max_time - time_alive
	$VisualContainer/ProgressBar/TimeLabel.text = str(int(ceil(time_remaining))) + "s"
	
	# Get the fill StyleBox and change its color based on urgency
	var fill_style = $VisualContainer/ProgressBar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if progress < 0.3:
			fill_style.bg_color = Color.RED
		elif progress < 0.6:
			fill_style.bg_color = Color.YELLOW
		else:
			fill_style.bg_color = Color.GREEN
	
	# Pulse animation - use the original scale as base
	var pulse = 1.0 + sin(time_alive * 5.0) * 0.1
	$VisualContainer/ThreatIcon.scale = original_scale * pulse
	
	# Check if reached target
	if position.x <= target_position.x or time_alive >= max_time:
		reached_target.emit(self)
		queue_free()

func speed_up():
	# Wrong command makes threat move faster
	speed *= 1.3
	$VisualContainer/InfoPanel.modulate = Color(1.0, 0.5, 0.5)  # Flash red

func neutralize():
	is_neutralized = true
	
	# Success animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($VisualContainer, "modulate", Color(0, 1, 0, 0), 0.5)
	tween.tween_property($VisualContainer, "scale", Vector2(2, 2), 0.5)
	
	await tween.finished
	queue_free()
