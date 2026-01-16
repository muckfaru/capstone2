extends Area2D

signal threat_blocked(threat_type, defense_used)
signal threat_succeeded(threat_type, target_asset)

var threat_type = "phishing"
var target_asset = "employee_pc"
var target_position = Vector2.ZERO
var speed = 80.0
var is_moving = false
var is_blocked = false
var visuals_created = false

# Threat icons/colors
var threat_colors = {
	"phishing": Color(1, 0.5, 0),
	"brute_force": Color(0.8, 0, 0),
	"malware": Color(0.6, 0, 0.8),
	"ddos": Color(0, 0.5, 1),
	"sql_injection": Color(1, 0, 0.5),
	"ransomware": Color(0.5, 0, 0),
	"zero_day": Color(0.2, 0.2, 0.2),
	"insider_threat": Color(0.8, 0.8, 0)
}

var threat_symbols = {
	"phishing": "🎣",
	"brute_force": "🔨",
	"malware": "🦠",
	"ddos": "🌊",
	"sql_injection": "💉",
	"ransomware": "🔒",
	"zero_day": "💀",
	"insider_threat": "👤"
}

# Visual components
var icon_rect: ColorRect
var emoji_label: Label
var type_label: Label
var collision_shape: CollisionShape2D

func _ready():
	print("\n=== THREAT READY ===")
	print("Threat type: ", threat_type)
	
	# Enable input
	input_pickable = true
	set_process_input(true)
	z_index = 10
	
	add_to_group("threats")
	
	print("===================\n")

func initialize_visuals():
	if visuals_created:
		return
		
	visuals_created = true
	create_visuals()
	print("✅ Visuals created for ", threat_type)

func create_visuals():
	# Background
	icon_rect = ColorRect.new()
	icon_rect.size = Vector2(60, 60)
	icon_rect.position = Vector2(-30, -30)
	icon_rect.color = threat_colors.get(threat_type, Color.RED)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)
	
	# Emoji
	emoji_label = Label.new()
	emoji_label.position = Vector2(-30, -30)
	emoji_label.size = Vector2(60, 60)
	emoji_label.add_theme_font_size_override("font_size", 40)
	emoji_label.text = threat_symbols.get(threat_type, "⚠️")
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emoji_label)
	
	# Type label
	type_label = Label.new()
	type_label.position = Vector2(-50, 35)
	type_label.size = Vector2(100, 20)
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.text = threat_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", Color(1, 1, 0))
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(type_label)
	
	# Collision shape
	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 35.0
	collision_shape.shape = circle
	add_child(collision_shape)

func start_moving():
	is_moving = true
	print("🏃 Threat ", threat_type, " moving to ", target_asset)

func _process(delta):
	if is_moving and not is_blocked:
		var direction = (target_position - position).normalized()
		position += direction * speed * delta
		
		if position.distance_to(target_position) < 20:
			threat_hit_asset()

func threat_hit_asset():
	if is_blocked:
		return
		
	is_moving = false
	print("💥 Threat ", threat_type, " hit ", target_asset)
	emit_signal("threat_succeeded", threat_type, target_asset)
	queue_free()

func block_threat(defense_type):
	if is_blocked:
		return
	
	is_blocked = true
	is_moving = false
	
	print("✅ BLOCKED: ", threat_type, " with ", defense_type)
	
	if type_label:
		type_label.text = "BLOCKED!"
		type_label.add_theme_color_override("font_color", Color(0, 1, 0))
	
	if icon_rect:
		var tween = create_tween()
		tween.tween_property(icon_rect, "modulate:a", 0, 0.3)
	
	if emoji_label:
		var tween2 = create_tween()
		tween2.tween_property(emoji_label, "modulate:a", 0, 0.3)
	
	await get_tree().create_timer(0.3).timeout
	queue_free()

# NEW: This catches ALL mouse button presses
func _input(event):
	if is_blocked:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is on this threat
			var local_pos = to_local(event.position)
			if local_pos.length() < 35:  # Within collision radius
				print("\n🎯 CLICKED THREAT: ", threat_type)
				handle_click()
				get_viewport().set_input_as_handled()  # Consume the event

func handle_click():
	# Get selected defense from DefenseTool
	var defense_tools = get_tree().get_nodes_in_group("defense_tools")
	
	if defense_tools.is_empty():
		print("❌ No defense tools found!")
		return
	
	var selected_defense = defense_tools[0].get_class_selected_defense_type()
	print("   Selected defense: '", selected_defense, "'")
	
	if selected_defense == "":
		print("   ⚠️ NO DEFENSE SELECTED!")
		show_error_message("SELECT A TOOL FIRST!")
		return
	
	print("   📡 Emitting threat_blocked signal")
	emit_signal("threat_blocked", threat_type, selected_defense)
	
	# Clear selection
	defense_tools[0].clear_class_selection()

func show_error_message(msg: String):
	if type_label:
		var original_text = type_label.text
		type_label.text = msg
		type_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
		await get_tree().create_timer(1.0).timeout
		
		if is_instance_valid(type_label):
			type_label.text = original_text
			type_label.add_theme_color_override("font_color", Color(1, 1, 0))