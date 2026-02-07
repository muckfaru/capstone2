extends PanelContainer

signal zone_dropped(card, zone_type)

@export var zone_type = "network"
@export var zone_color = Color(0.8, 0.3, 0.2)

@onready var icon_label = $VBox/Icon
@onready var title_label = $VBox/Title
@onready var subtitle_label = $VBox/Subtitle
@onready var panel = $Panel

var original_style: StyleBox

func _ready():
	setup_zone()
	original_style = panel.get_theme_stylebox("panel").duplicate()
	print("NetworkZone ready: global_pos=%s, size=%s" % [global_position, size])

func setup_zone():
	icon_label.text = "🌐"
	title_label.text = "NETWORK SECURITY"
	subtitle_label.text = "Connections, Traffic, Infrastructure"
	
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = zone_color

func is_point_inside(point: Vector2) -> bool:
	var rect = Rect2(global_position, size)
	var inside = rect.has_point(point)
	if inside:
		print("NetworkZone: Point %s IS inside rect %s" % [point, rect])
	return inside

func handle_drop(card):
	print("NetworkZone received card drop!")
	zone_dropped.emit(card, zone_type)

func show_success_effect():
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var tween = create_tween()
		# Flash bright green with higher opacity
		tween.tween_property(style, "border_color", Color(0.2, 1, 0.2), 0.15)
		tween.tween_property(style, "bg_color", Color(0.2, 1, 0.2, 0.7), 0.15)
		# Hold the green for a moment
		tween.tween_property(style, "border_color", Color(0.2, 1, 0.2), 0.2)
		tween.tween_property(style, "bg_color", Color(0.2, 1, 0.2, 0.7), 0.2)
		# Return to original
		tween.tween_property(style, "border_color", zone_color, 0.3)
		tween.tween_property(style, "bg_color", Color(0.2, 0.2, 0.25, 0.5), 0.3)

func show_fail_effect():
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var tween = create_tween()
		# Flash bright red with higher opacity
		tween.tween_property(style, "border_color", Color(1, 0.2, 0.2), 0.15)
		tween.tween_property(style, "bg_color", Color(1, 0.2, 0.2, 0.7), 0.15)
		# Hold the red for a moment
		tween.tween_property(style, "border_color", Color(1, 0.2, 0.2), 0.2)
		tween.tween_property(style, "bg_color", Color(1, 0.2, 0.2, 0.7), 0.2)
		# Return to original
		tween.tween_property(style, "border_color", zone_color, 0.3)
		tween.tween_property(style, "bg_color", Color(0.2, 0.2, 0.25, 0.5), 0.3)
	
	# Shake effect
	var original_pos = position
	var tween2 = create_tween()
	for i in range(4):
		tween2.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
		tween2.tween_property(self, "position", original_pos + Vector2(-10, 0), 0.05)
	tween2.tween_property(self, "position", original_pos, 0.05)