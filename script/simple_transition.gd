extends CanvasLayer

@export_file("*.tscn") var next_scene_path: String = "res://scene/Main.tscn"
@export var display_duration: float = 3.0
@export var fade_in_duration: float = 0.5
@export var fade_out_duration: float = 1.0

@onready var text_label = $Control/CenterText
@onready var fade_overlay = $Control/FadeOverlay
@onready var animated_sprite = $Control/AnimatedSprite2D

func _ready() -> void:
	# Set layer to be on top
	layer = 100
	
	# Preload next scene in background
	if not next_scene_path.is_empty():
		ResourceLoader.load_threaded_request(next_scene_path)
	
	# Start with everything visible EXCEPT the fade overlay
	fade_overlay.modulate.a = 0.0
	fade_overlay.visible = true
	text_label.modulate.a = 0.0
	animated_sprite.modulate.a = 1.0
	
	# Play the animation
	animated_sprite.play()
	
	# Fade in the text
	var fade_in = create_tween()
	fade_in.tween_property(text_label, "modulate:a", 1.0, fade_in_duration)
	await fade_in.finished
	
	# Wait for display duration
	await get_tree().create_timer(display_duration).timeout
	
	# Fade out everything to black
	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(text_label, "modulate:a", 0.0, fade_out_duration)
	fade_out.tween_property(animated_sprite, "modulate:a", 0.0, fade_out_duration)
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, fade_out_duration)
	await fade_out.finished
	
	# Ensure black screen stays
	fade_overlay.modulate.a = 1.0
	fade_overlay.visible = true
	
	if next_scene_path.is_empty():
		print("Warning: No next scene path set!")
		return
	
	# Wait for scene to finish loading
	while ResourceLoader.load_threaded_get_status(next_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().process_frame
	
	# Small delay to ensure black screen is visible
	await get_tree().create_timer(0.1).timeout
	
	# Load and change scene smoothly
	var new_scene: PackedScene = ResourceLoader.load_threaded_get(next_scene_path)
	if new_scene:
		var new_node = new_scene.instantiate()
		
		# Add the new scene
		get_tree().get_root().add_child(new_node)
		get_tree().current_scene = new_node
		
		# Wait one frame for scene to initialize
		await get_tree().process_frame
		
		# Now fade out the black overlay to reveal the new scene
		var reveal_tween = create_tween()
		reveal_tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
		await reveal_tween.finished
		
		# Clean up
		queue_free()
