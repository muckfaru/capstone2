extends PanelContainer

signal card_expired(card)

var attack_data: Dictionary = {}
var alert_number: int = 1
var time_limit: float = 4.0
var time_remaining: float = 0.0
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

@onready var alert_label = $VBox/Header/AlertLabel
@onready var timer_bar = $VBox/Header/TimerBar
@onready var icon = $VBox/Icon
@onready var description = $VBox/Description

func _ready():
	original_position = position
	time_remaining = time_limit
	
	alert_label.text = "⚠️ ALERT #%d" % alert_number
	description.text = attack_data.get("description", "Unknown attack")
	
	if attack_data.has("icon"):
		var label = Label.new()
		label.text = attack_data.icon
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 40)
		icon.add_child(label)
	
	timer_bar.value = 1.0

func _process(delta):
	if not is_dragging:
		time_remaining -= delta
		timer_bar.value = time_remaining / time_limit
		
		if time_remaining < time_limit * 0.3:
			timer_bar.modulate = Color(1, 0.3, 0.3)
		elif time_remaining < time_limit * 0.6:
			timer_bar.modulate = Color(1, 1, 0.3)
		
		if time_remaining <= 0:
			card_expired.emit(self)
	
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = get_local_mouse_position()
				z_index = 100
			else:
				is_dragging = false
				z_index = 0
				check_drop_zones()

func check_drop_zones():
	# Get the center point of the card
	var card_center = global_position + size / 2
	
	print("Card dropped - center point: %s" % card_center)
	
	# Get the game manager to access drop zones
	var game_manager = get_tree().root.get_node("Main")
	if not game_manager:
		print("  - ERROR: Could not find game manager!")
		return_to_original()
		return
	
	var data_zone = game_manager.get_node_or_null("CanvasLayer/DropZones/DataZone")
	var network_zone = game_manager.get_node_or_null("CanvasLayer/DropZones/NetworkZone")
	
	# Check data zone first
	if data_zone and data_zone.has_method("is_point_inside"):
		if data_zone.is_point_inside(card_center):
			print("  - Dropped on DATA zone!")
			data_zone.handle_drop(self)
			return
	
	# Check network zone
	if network_zone and network_zone.has_method("is_point_inside"):
		if network_zone.is_point_inside(card_center):
			print("  - Dropped on NETWORK zone!")
			network_zone.handle_drop(self)
			return
	
	print("  - No valid drop zone found")
	return_to_original()

func return_to_original():
	var tween = create_tween()
	tween.tween_property(self, "position", original_position, 0.3).set_ease(Tween.EASE_OUT)