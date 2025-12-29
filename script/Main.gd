extends Node3D

@onready var player = $Player
@onready var story_manager = $StoryManager

func _ready():
	# IMPORTANT: Hide dialogue box immediately when scene loads
	if DialogueManager.dialogue_box and DialogueManager.dialogue_box.visible:
		DialogueManager.dialogue_box.visible = false
	
	# Check if returning from computer
	if GlobalState.returning_from_computer:
		# Position player at computer desk
		player.global_position = Vector3(-3, 6.31636, -2.05119)
		player.rotation.y = 0
		
		# Disable story manager dialogues when returning
		if story_manager:
			story_manager.has_shown_exploration_tip = true
			story_manager.has_shown_intro_dialogue = true
		
		# Reset flag
		GlobalState.returning_from_computer = false
		
		# Start panic sequence
		await add_fade_in()
		await get_tree().create_timer(0.5).timeout
		start_panic_sequence()

func add_fade_in():
	# Create black overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 100
	add_child(fade_overlay)
	
	# Fade from black
	await get_tree().create_timer(0.3).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 1.0)
	await fade_tween.finished
	fade_overlay.queue_free()

func start_panic_sequence():
	# Start camera shake
	start_camera_shake(3.0)  # Shake for 3 seconds
	
	# Show panic dialogue
	var panic_lines = [
		"Oh no! What did I just do?!",
		"My computer just shut down!",
		"Did I just download a virus?!",
		"This can't be happening...",
		"I shouldn't have clicked on that sketchy site!"
	]
	
	DialogueManager.show_dialogue(panic_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Stop shake after dialogue
	stop_camera_shake()
	
	# After panic, show what to do next
	await get_tree().create_timer(1.0).timeout
	
	if GlobalState.computer_infected:
		var next_lines = [
			"I need to check if my computer still works...",
			"Maybe I should try turning it on again?"
		]
		DialogueManager.show_dialogue(next_lines, "You")

func start_camera_shake(duration: float):
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		var original_position = camera.position
		
		# Create shake effect
		var shake_timer = 0.0
		var shake_intensity = 0.15
		
		while shake_timer < duration:
			var offset_x = randf_range(-shake_intensity, shake_intensity)
			var offset_y = randf_range(-shake_intensity, shake_intensity)
			var offset_z = randf_range(-shake_intensity, shake_intensity)
			
			camera.position = original_position + Vector3(offset_x, offset_y, offset_z)
			
			await get_tree().create_timer(0.05).timeout
			shake_timer += 0.05
		
		# Reset camera position
		camera.position = original_position

func stop_camera_shake():
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		# Reset to default position
		camera.position = Vector3(0.674639, 0.195653, -0.305826)