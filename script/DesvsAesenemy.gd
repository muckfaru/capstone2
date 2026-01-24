extends Node2D

var enemy_name = "Attacker"
var speed = 1.0
var base_speed = 50.0
var target_x = 300  # Attack position
var is_active = true

@onready var sprite = $Sprite
@onready var label = $Label
@onready var progress_bar = $ProgressBar

func setup(name: String, spd: float, color: Color):
	enemy_name = name
	speed = spd
	if sprite:
		sprite.modulate = color
	if label:
		label.text = name
	if progress_bar:
		progress_bar.modulate = color

func _ready():
	if progress_bar:
		progress_bar.value = 0

func _process(delta):
	if not is_active:
		return
	
	# Move towards target
	if position.x > target_x:
		position.x -= base_speed * speed * delta
	
	# Update progress bar (attack progress)
	if progress_bar:
		var distance = position.x - target_x
		var max_distance = 1000 - target_x
		progress_bar.value = (1.0 - (distance / max_distance)) * 100

func is_attacking() -> bool:
	return position.x <= target_x + 50

func push_back(amount: float):
	position.x += amount
	position.x = min(position.x, 1000)  # Don't push beyond spawn

func _draw():
	# Draw enemy as a rectangle
	draw_rect(Rect2(-25, -25, 50, 50), sprite.modulate)
	draw_rect(Rect2(-25, -25, 50, 50), Color.WHITE, false, 2)