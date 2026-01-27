extends Area2D

signal threat_blocked(threat_type, defense_used)
signal threat_succeeded(threat_type, target_asset)

@export var threat_type = "phishing"
@export var target_asset = "employee_pc"
@export var speed = 100.0
@export var max_health = 1

var target_position = Vector2.ZERO
var is_moving = false
var is_blocked = false
var click_count = 0
var current_health = 1

# Threat display names
var threat_names = {
	"phishing": "Phishing",
	"brute_force": "Brute Force",
	"malware": "Malware",
	"ddos": "DDoS",
	"sql_injection": "SQL Injection",
	"ransomware": "Ransomware",
	"zero_day": "Zero Day",
	"insider_threat": "Insider Threat"
}

# Threat PNG texture paths
var threat_textures = {
	"phishing": "res://asset/threats/phishing.png",
	"brute_force": "res://asset/threats/brute_force.png",
	"malware": "res://asset/threats/malware.png",
	"ddos": "res://asset/threats/ddos.png",
	"sql_injection": "res://asset/threats/sql_injection.png",
	"ransomware": "res://asset/threats/ransomware.png",
	"zero_day": "res://asset/threats/zero_day.png",
	"insider_threat": "res://asset/threats/insider_threat.png"
}

# Emoji fallback
var threat_icons = {
	"phishing": "🎣",
	"brute_force": "🔨",
	"malware": "🦠",
	"ddos": "💥",
	"sql_injection": "💉",
	"ransomware": "🔒",
	"zero_day": "⚡",
	"insider_threat": "🕵️"
}

@onready var icon_texture = $IconTexture
@onready var icon_label = $Label
@onready var name_label = $NameLabel
@onready var health_bar = $HealthBar
@onready var health_label = $HealthLabel

func _ready():
	print("\n🦠 Threat._ready() called")
	print("   Threat type: ", threat_type)
	print("   Target asset: ", target_asset)
	print("   Max health: ", max_health)
	
	current_health = max_health
	
	add_to_group("threats")
	
	# Connect input event
	connect("input_event", _on_input_event)
	set_process_input(true)
	
	collision_layer = 1
	collision_mask = 0
	input_pickable = true
	
	update_health_display()

func initialize_visuals():
	print("🎨 initialize_visuals() called for: ", threat_type)
	
	# Set name label
	if name_label and threat_type in threat_names:
		name_label.text = threat_names[threat_type]
	
	# Load PNG texture
	if icon_texture and threat_type in threat_textures:
		var texture_path = threat_textures[threat_type]
		
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			icon_texture.texture = texture
			icon_texture.visible = true
			if icon_label:
				icon_label.visible = false
			print("   ✅ PNG texture loaded successfully!")
		else:
			print("   ⚠️ Texture file not found: ", texture_path)
			use_emoji_fallback()
	else:
		use_emoji_fallback()
	
	update_health_display()

func use_emoji_fallback():
	if icon_label and threat_type in threat_icons:
		icon_label.text = threat_icons[threat_type]
		icon_label.visible = true
		if icon_texture:
			icon_texture.visible = false

func start_moving():
	is_moving = true
	print("🏃 Threat started moving - Health: ", current_health, "/", max_health)

func _process(delta):
	if is_moving and not is_blocked:
		var direction = (target_position - global_position).normalized()
		global_position += direction * speed * delta
		
		if global_position.distance_to(target_position) < 20:
			reach_target()

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		if distance < 70:
			handle_click()
			get_viewport().set_input_as_handled()

func handle_click():
	print("\n=== 🎯 HANDLE_CLICK CALLED ===")
	print("   Threat type: ", threat_type)
	print("   Current health: ", current_health, "/", max_health)
	print("   Is blocked: ", is_blocked)
	print("   Click count: ", click_count)
	
	if is_blocked:
		print("   ⚠️ Threat already blocked")
		return
	
	# ✅ FIX: Allow rapid clicks without blocking
	# Removed the click_count check that was preventing rapid clicks
	
	click_count += 1
	
	var defense_tool = get_tree().get_first_node_in_group("defense_tools")
	
	if defense_tool:
		var defense = defense_tool.get_class_selected_defense_type()
		
		if defense != "":
			print("   📤 Emitting threat_blocked signal")
			emit_signal("threat_blocked", threat_type, defense)
			# Don't clear selection anymore - keep it for rapid clicking
		else:
			print("   ❌ No defense selected")
			click_count = 0
	else:
		print("   ❌ No defense tool found!")
		click_count = 0
	
	print("=== END HANDLE_CLICK ===\n")

func take_damage() -> bool:
	"""Returns true if threat is destroyed, false if still alive"""
	current_health -= 1
	click_count = 0  # Reset for next click
	
	print("💥 Threat took damage! Health: ", current_health, "/", max_health)
	
	update_health_display()
	
	# Visual damage feedback
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	
	if current_health <= 0:
		block_threat("destroyed")
		return true
	else:
		return false

func update_health_display():
	if health_bar:
		var health_percent = float(current_health) / float(max_health)
		
		# Update health bar width
		var bar_width = 60.0 * health_percent
		health_bar.size = Vector2(bar_width, 8)
		health_bar.position = Vector2(-30, -75)
		
		# Color based on health
		if health_percent > 0.66:
			health_bar.color = Color(0, 1, 0)  # Green
		elif health_percent > 0.33:
			health_bar.color = Color(1, 1, 0)  # Yellow
		else:
			health_bar.color = Color(1, 0, 0)  # Red
		
		health_bar.visible = max_health > 1
	
	if health_label:
		if max_health > 1:
			health_label.text = str(current_health) + "/" + str(max_health)
			health_label.visible = true
		else:
			health_label.visible = false

func block_threat(defense_name):
	print("\n🛡️ block_threat() called")
	
	if is_blocked:
		return
	
	is_blocked = true
	is_moving = false
	
	# Death animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0, 1, 0, 0.5), 0.3)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	queue_free()

func reach_target():
	if is_blocked:
		return
	
	print("\n💥 THREAT REACHED TARGET!")
	print("   Threat type: ", threat_type)
	print("   Target asset: ", target_asset)
	
	emit_signal("threat_succeeded", threat_type, target_asset)
	queue_free()