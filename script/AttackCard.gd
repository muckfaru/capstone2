extends PanelContainer

signal card_expired(card)

var attack_data: Dictionary = {}
var alert_number: int = 1
var time_limit: float = 4.0
var time_remaining: float = 0.0
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var game_manager = null  # Reference to main game manager for sounds
var _has_expired: bool = false  # Guard: emit card_expired only once

@onready var timer_bar = $VBox/Header/TimerBar
@onready var icon = $VBox/Icon
@onready var description = $VBox/Description

func _ready():
	original_position = position
	time_remaining = time_limit
	
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
		var progress = time_remaining / time_limit
		timer_bar.value = progress
		
		# Update the fill color based on remaining time
		update_timer_color(progress)
		
		if time_remaining <= 0 and not _has_expired:
			_has_expired = true
			set_process(false)
			card_expired.emit(self)
			return
	
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func update_timer_color(progress: float):
	var fill_style = timer_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if progress < 0.3:
			fill_style.bg_color = Color(1, 0.3, 0.3, 0.73)  # Red
		elif progress < 0.6:
			fill_style.bg_color = Color(1, 0.8, 0.3, 0.73)  # Yellow/Orange
		else:
			fill_style.bg_color = Color(0, 0.728, 0.412, 0.73)  # Green

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = get_local_mouse_position()
				z_index = 100
				# Play pickup sound
				if game_manager:
					game_manager.play_card_pickup_sound()
			else:
				is_dragging = false
				z_index = 0
				check_drop_zones()

func check_drop_zones():
	var card_center = global_position + size / 2
	
	print("Card dropped - center point: %s" % card_center)
	
	if not game_manager:
		game_manager = get_tree().root.get_node("Main")
	
	if not game_manager:
		print("  - ERROR: Could not find game manager!")
		return_to_original()
		return
	
	var data_zone = game_manager.get_node_or_null("CanvasLayer/DropZones/DataZone")
	var network_zone = game_manager.get_node_or_null("CanvasLayer/DropZones/NetworkZone")
	
	if data_zone and data_zone.has_method("is_point_inside"):
		if data_zone.is_point_inside(card_center):
			print("  - Dropped on DATA zone!")
			data_zone.handle_drop(self)
			return
	
	if network_zone and network_zone.has_method("is_point_inside"):
		if network_zone.is_point_inside(card_center):
			print("  - Dropped on NETWORK zone!")
			network_zone.handle_drop(self)
			return
	
	print("  - No valid drop zone found")
	return_to_original()

func return_to_original():
	# Play return sound
	if game_manager:
		game_manager.play_card_return_sound()
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_position, 0.3).set_ease(Tween.EASE_OUT)