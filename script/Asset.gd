extends Area2D

@export var asset_name = ""
@export var asset_icon = ""  # Leave empty to use scene's IconLabel
@export var max_health = 3

var current_health = max_health

@onready var icon_label = $IconLabel
@onready var name_label = $NameLabel
@onready var health_bar = $HealthBar

func _ready():
	current_health = max_health
	
	# Only set icon if asset_icon is not empty (allows scene to define icon)
	if icon_label and asset_icon != "":
		icon_label.text = asset_icon
	
	if name_label:
		name_label.text = asset_name.replace("_", " ").capitalize()
	
	update_health_bar()

func take_damage():
	current_health -= 1
	update_health_bar()
	
	# Visual feedback
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		on_compromised()

func update_health_bar():
	if health_bar:
		# Update health bar visual
		health_bar.size.x = 60 * (float(current_health) / float(max_health))
		
		if current_health <= 1:
			health_bar.color = Color(1, 0, 0)
		elif current_health <= 2:
			health_bar.color = Color(1, 0.5, 0)
		else:
			health_bar.color = Color(0, 1, 0)

func on_compromised():
	modulate = Color(0.3, 0.3, 0.3)
	if name_label:
		name_label.text = "COMPROMISED"
		name_label.modulate = Color(1, 0, 0)