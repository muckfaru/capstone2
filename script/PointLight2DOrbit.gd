extends PointLight2D

# Blinking animation parameters
@export var min_energy: float = 0.2      # Minimum brightness
@export var max_energy: float = 0.8      # Maximum brightness
@export var blink_speed: float = 3.0     # Speed of blinking (cycles per second)
@export var pulse_mode: bool = true      # Smooth pulse vs hard blink
@export var random_offset: bool = false  # Random start time for variation

var time_passed: float = 0.0
var initial_energy: float = 0.42

func _ready():
	initial_energy = energy
	if random_offset:
		time_passed = randf() * TAU  # Random start between 0 and 2π

func _process(delta):
	time_passed += delta * blink_speed
	
	if pulse_mode:
		# Smooth pulsing using sine wave
		var pulse = (sin(time_passed) + 1.0) / 3.0  # Normalize to 0-1
		energy = lerp(min_energy, max_energy, pulse)
	else:
		# Hard blinking (on/off)
		var blink = int(time_passed) % 2
		energy = max_energy if blink == 0 else min_energy
