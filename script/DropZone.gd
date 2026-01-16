extends PanelContainer

signal zone_dropped(card, zone_type)

@export var zone_type = "data"  # "data" or "network"
@export var zone_color = Color(0.2, 0.5, 0.8)

@onready var icon_label = $VBox/Icon
@onready var title_label = $VBox/Title
@onready var subtitle_label = $VBox/Subtitle
@onready var panel = $Panel
@onready var area_2d = $Area2D

var original_style: StyleBox

func _ready():
	setup_zone()
	# Collision shape is now set up in the scene file
	original_style = panel.get_theme_stylebox("panel").duplicate()

func setup_zone():
	if zone_type == "data":
		icon_label.text = "📁"
		title_label.text = "DATA SECURITY"
		subtitle_label.text = "Files, Databases, Credentials"
	else:
		icon_label.text = "🌐"
		title_label.text = "NETWORK SECURITY"
		subtitle_label.text = "Connections, Traffic, Infrastructure"
	
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = zone_color

func handle_drop(card):
	zone_dropped.emit(card, zone_type)

func show_success_effect():
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var tween = create_tween()
		tween.tween_property(style, "border_color", Color(0.2, 1, 0.2), 0.1)
		tween.tween_property(style, "bg_color", Color(0.2, 0.8, 0.2, 0.3), 0.1)
		tween.tween_property(style, "border_color", zone_color, 0.3)
		tween.tween_property(style, "bg_color", Color(0.2, 0.2, 0.25, 0.5), 0.3)
	
	# Shield effect
	var shield = Label.new()
	shield.text = "🛡️"
	shield.add_theme_font_size_override("font_size", 72)
	shield.position = size / 2 - Vector2(36, 36)
	shield.modulate = Color(1, 1, 1, 0)
	add_child(shield)
	
	var tween2 = create_tween()
	tween2.tween_property(shield, "modulate:a", 1.0, 0.2)
	tween2.tween_property(shield, "scale", Vector2(1.3, 1.3), 0.3)
	tween2.tween_property(shield, "modulate:a", 0.0, 0.3)
	await tween2.finished
	shield.queue_free()

func show_fail_effect():
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var tween = create_tween()
		tween.tween_property(style, "border_color", Color(1, 0.2, 0.2), 0.1)
		tween.tween_property(style, "bg_color", Color(1, 0.2, 0.2, 0.3), 0.1)
		tween.tween_property(style, "border_color", zone_color, 0.3)
		tween.tween_property(style, "bg_color", Color(0.2, 0.2, 0.25, 0.5), 0.3)
	
	# Shake effect
	var original_pos = position
	var tween2 = create_tween()
	for i in range(4):
		tween2.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
		tween2.tween_property(self, "position", original_pos + Vector2(-10, 0), 0.05)
	tween2.tween_property(self, "position", original_pos, 0.05)