extends Node2D

var encryption_type = "DES"
var key_size = 56
var shield_color = Color.BLUE

@onready var shield_sprite = $Shield
@onready var key_label = $KeyLabel
@onready var type_label = $TypeLabel

func _ready():
	set_encryption_type("DES", 56)

func set_encryption_type(type: String, key: int):
	encryption_type = type
	key_size = key
	
	if type_label:
		type_label.text = type
	if key_label:
		key_label.text = str(key) + "-bit Key"
	
	if type == "DES":
		shield_color = Color(1.0, 0.5, 0.0)  # Orange - weak
		if type_label:
			type_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		shield_color = Color(0.0, 0.8, 1.0)  # Cyan - strong
		if type_label:
			type_label.add_theme_color_override("font_color", Color.CYAN)
	
	queue_redraw()

func pulse():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _draw():
	# Draw encryption shield
	var radius = 80
	var segments = 32
	
	# Shield glow
	draw_circle(Vector2.ZERO, radius + 10, Color(shield_color, 0.3))
	
	# Main shield
	for i in range(segments):
		var angle1 = (PI * 2 / segments) * i
		var angle2 = (PI * 2 / segments) * (i + 1)
		
		var p1 = Vector2(cos(angle1), sin(angle1)) * radius
		var p2 = Vector2(cos(angle2), sin(angle2)) * radius
		
		draw_line(p1, p2, shield_color, 3.0)
	
	# Center indicator
	draw_circle(Vector2.ZERO, 20, shield_color)
	draw_circle(Vector2.ZERO, 20, Color.WHITE, false, 2)