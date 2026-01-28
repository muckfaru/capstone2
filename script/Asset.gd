extends Area2D

@export var asset_name = ""
@export var asset_icon = ""  # Leave empty to use scene's IconLabel
@export var max_health = 5  # ✅ UPDATED: Increased from 3 to 5 for longer gameplay

var current_health = max_health

@onready var icon_label = $IconLabel
@onready var name_label = $NameLabel
@onready var health_bar = $HealthBar
@onready var health_label = $HealthLabel if has_node("HealthLabel") else null  # ✅ NEW

func _ready():
	current_health = max_health
	
	# Only set icon if asset_icon is not empty (allows scene to define icon)
	if icon_label and asset_icon != "":
		icon_label.text = asset_icon
	
	if name_label:
		name_label.text = asset_name.replace("_", " ").capitalize()
	
	# ✅ NEW: Sync with GameManager if available
	sync_with_game_manager()
	
	update_health_bar()

# ✅ NEW: Sync health with GameManager on ready
func sync_with_game_manager():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		# Use the node's name to get health from GameManager
		var node_name = name
		if node_name in game_manager.assets_health:
			current_health = game_manager.assets_health[node_name]
			max_health = game_manager.assets_max_health[node_name]
			print("📊 ", node_name, " synced with GameManager: ", current_health, "/", max_health)

func take_damage():
	current_health -= 1
	update_health_bar()
	
	# Visual feedback - your original shake effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# ✅ NEW: Additional shake for more impact
	shake_asset()
	
	if current_health <= 0:
		on_compromised()

# ✅ NEW: Shake effect for damage feedback
func shake_asset():
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(0, 5), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(0, -5), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

func update_health_bar():
	if health_bar:
		# Update health bar visual (your original code)
		health_bar.size.x = 60 * (float(current_health) / float(max_health))
		
		# Color coding (your original thresholds, adjusted for max_health=5)
		var health_percent = float(current_health) / float(max_health)
		
		if health_percent <= 0.2:  # 20% or less (1/5 HP)
			health_bar.color = Color(1, 0, 0)  # Red
		elif health_percent <= 0.4:  # 40% or less (2/5 HP)
			health_bar.color = Color(1, 0.5, 0)  # Orange
		else:  # Above 40%
			health_bar.color = Color(0, 1, 0)  # Green
	
	# ✅ NEW: Update numeric health label
	update_health_label()

# ✅ NEW: Update numeric health display
func update_health_label():
	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)
		
		# Color based on health percentage
		var health_percent = float(current_health) / float(max_health)
		
		if current_health <= 0:
			health_label.add_theme_color_override("font_color", Color(1, 0, 0))  # Red
			health_label.text = "0/" + str(max_health)
		elif health_percent <= 0.33:
			health_label.add_theme_color_override("font_color", Color(1, 0.5, 0))  # Orange
		else:
			health_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White

func on_compromised():
	modulate = Color(0.3, 0.3, 0.3)  # Your original gray out
	if name_label:
		name_label.text = "COMPROMISED"
		name_label.modulate = Color(1, 0, 0)
	
	# ✅ NEW: Update health label to show 0
	if health_label:
		health_label.text = "0/" + str(max_health)
		health_label.add_theme_color_override("font_color", Color(1, 0, 0))

# ✅ NEW: Manual health update (called by GameManager when needed)
func set_health(new_health: int):
	current_health = new_health
	update_health_bar()

# ✅ NEW: Get current health (for GameManager to query)
func get_health() -> int:
	return current_health