extends CharacterBody3D

const SPEED = 5.0
const RUN_SPEED = 8.0
const MOUSE_SENSITIVITY = 0.003
const INTERACTION_DISTANCE = 5.0
const WALK_FOOTSTEP_INTERVAL = 0.45
const RUN_FOOTSTEP_INTERVAL = 0.3

@onready var camera = $Camera3D
@onready var interaction_label = $Control/Label
@onready var footstep_player = $FootstepPlayer

var can_interact = false
var e_key_was_pressed = false
var footstep_timer = 0.0
var is_moving = false
var current_speed = SPEED

var footstep_sounds = [
	preload("res://asset/audio/sfx/footstep1.mp3"),
]

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interaction_label.visible = false
	
	if footstep_player:
		footstep_player.stream = footstep_sounds[0]
	
	print("Player ready! Use WASD to move, SHIFT to run, Mouse to look, ESC to free mouse")

func _input(event):
	# Don't process input during dialogue
	if DialogueManager.is_active():
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		if event.keycode == KEY_E and event.pressed and not e_key_was_pressed:
			e_key_was_pressed = true
			if can_interact:
				use_computer()
			else:
				print("Can't interact - not looking at computer")
		elif event.keycode == KEY_E and not event.pressed:
			e_key_was_pressed = false

func _physics_process(delta):
	# Don't move during dialogue
	if DialogueManager.is_active():
		velocity = Vector3.ZERO
		return
	
	current_speed = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
	
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	is_moving = direction.length() > 0
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	handle_footsteps(delta)
	check_computer_interaction()

func handle_footsteps(delta):
	if is_moving and is_on_floor():
		var interval = RUN_FOOTSTEP_INTERVAL if current_speed > SPEED else WALK_FOOTSTEP_INTERVAL
		footstep_timer += delta
		
		if footstep_timer >= interval:
			play_footstep()
			footstep_timer = 0.0
	else:
		footstep_timer = 0.0

func play_footstep():
	if footstep_player and not footstep_player.playing:
		footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()

func check_computer_interaction():
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * INTERACTION_DISTANCE
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		var collider_name = collider.name
		var is_computer = false
		
		# Check if it's the computer
		if collider.is_in_group("computer"):
			is_computer = true
			print("Hit computer directly: ", collider_name)
		elif collider.get_parent() and collider.get_parent().is_in_group("computer"):
			is_computer = true
			print("Hit computer parent: ", collider_name)
		
		if is_computer:
			can_interact = true
			interaction_label.visible = true
			
			# Change text based on computer status
			if GlobalState.computer_infected:
				interaction_label.text = "Press E to check Computer"
			else:
				interaction_label.text = "Press E to use Computer"
		else:
			can_interact = false
			interaction_label.visible = false
	else:
		can_interact = false
		interaction_label.visible = false

func use_computer():
	# Check if computer is infected
	if GlobalState.computer_infected:
		print("Computer is infected! Showing error message...")
		show_computer_broken_dialogue()
		return
	
	print("Using computer! Switching scene...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scene/computer_desktop.tscn")

func show_computer_broken_dialogue():
	var error_lines = [
		"The computer won't turn on...",
		"The screen is just black.",
		"I think I really messed it up with that download.",
		"Maybe I should try again later..."
	]
	
	DialogueManager.show_dialogue(error_lines, "You")