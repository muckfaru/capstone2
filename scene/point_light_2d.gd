extends PointLight2D

@export var flicker_speed: float = 5.0
@export var min_energy: float = 0.7
@export var max_energy: float = 1.3
@export var use_noise: bool = true

var noise = FastNoiseLite.new()
var time: float = 0.0

func _ready() -> void:
	if use_noise:
		noise.seed = randi()
		noise.frequency = 2.0

func _process(delta: float) -> void:
	time += delta * flicker_speed
	
	if use_noise:
		# Smooth, organic flicker using noise
		var flicker = noise.get_noise_1d(time)
		energy = remap(flicker, -1.0, 1.0, min_energy, max_energy)
	else:
		# Random jittery flicker
		energy = randf_range(min_energy, max_energy)