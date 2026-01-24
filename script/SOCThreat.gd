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

func setup(type: String, data: Dictionary, is_tutorial: bool):
	threat_type = type
	threat_data = data
	tutorial_mode = is_tutorial
	
	# Set visual properties
	$VisualContainer/ThreatIcon.text = data.visual
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

func _on_animation_timer_timeout():
	if is_neutralized:
		return
	
	# Move toward target
	position.x -= speed * 0.05
	time_alive += 0.05
	
	# Update progress bar
	var progress = 1.0 - (time_alive / max_time)
	$VisualContainer/ProgressBar.value = progress
	
	# Change color based on urgency
	if progress < 0.3:
		$VisualContainer/ProgressBar.modulate = Color.RED
	elif progress < 0.6:
		$VisualContainer/ProgressBar.modulate = Color.YELLOW
	else:
		$VisualContainer/ProgressBar.modulate = Color.GREEN
	
	# Pulse animation
	var pulse = 1.0 + sin(time_alive * 5.0) * 0.1
	$VisualContainer/ThreatIcon.scale = Vector2.ONE * pulse
	
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