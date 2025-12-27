extends CharacterBody3D

const SPEED = 5.0
const MOUSE_SENSITIVITY = 0.003
const INTERACTION_DISTANCE = 5.0

@onready var camera = $Camera3D
@onready var interaction_label = $Control/Label

var can_interact = false
var e_key_was_pressed = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interaction_label.visible = false
	print("Player ready! Use WASD to move, Mouse to look, ESC to free mouse")

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Check for E key press
		if event.keycode == KEY_E and event.pressed and not e_key_was_pressed:
			e_key_was_pressed = true
			if can_interact:
				use_computer()
			else:
				print("Can't interact - not looking at computer")
		elif event.keycode == KEY_E and not event.pressed:
			e_key_was_pressed = false

func _physics_process(delta):
	# Movement
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
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	move_and_slide()
	
	# Check if looking at computer every frame
	check_computer_interaction()

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
			interaction_label.text = "Press E to use Computer"
		else:
			can_interact = false
			interaction_label.visible = false
	else:
		can_interact = false
		interaction_label.visible = false

func use_computer():
	print("Using computer! Switching scene...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scene/computer_desktop.tscn")
