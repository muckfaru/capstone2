extends OmniLight3D

@export var blink_speed: float = 2.0
@export var min_energy: float = 1.0
@export var max_energy: float = 3.0
@export var random_offset: bool = true

var time: float = 0.0
var offset: float = 0.0

func _ready():
    if random_offset:
        offset = randf() * PI * 2

func _process(delta):
    time += delta * blink_speed
    
    # Sine wave for smooth pulsing
    var pulse = sin(time + offset)
    light_energy = min_energy + (pulse + 1.0) / 2.0 * (max_energy - min_energy)
    
    # Optional: Random flicker
    if randf() < 0.01:  # 1% chance per frame
        light_energy *= 0.3  # Brief dim