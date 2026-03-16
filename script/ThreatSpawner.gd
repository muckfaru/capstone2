extends Node2D

# Preload threat scene
const ThreatScene = preload("res://scene/Threat.tscn")

# Spawn positions (off-screen, adjusted for NetworkDiagram offset of Y+80)
var spawn_positions = [
	Vector2(-100, 70),    # Left side, top
	Vector2(-100, 220),   # Left side, middle
	Vector2(-100, 370),   # Left side, bottom
	Vector2(1180, 70),    # Right side, top
	Vector2(1180, 220),   # Right side, middle
	Vector2(1180, 370)    # Right side, bottom
]

# Asset positions (targets on network diagram, adjusted for NetworkDiagram Y offset)
var asset_positions = {
	"employee_pc": Vector2(200, 230),
	"database": Vector2(540, 230),
	"router": Vector2(880, 230),
	"email_server": Vector2(200, 480),
	"backup": Vector2(540, 480),
	"ceo_laptop": Vector2(880, 480)
}

# Legacy spawn function (backwards compatible)
func spawn_threat(threat_type, target_asset):
	spawn_threat_advanced(threat_type, target_asset, 100.0, 1)

# Advanced spawn function with wave configuration
func spawn_threat_advanced(threat_type: String, target_asset: String, threat_speed: float, threat_health: int):
	print("📦 Spawning threat: ", threat_type, " targeting ", target_asset)
	print("   Speed: ", threat_speed, " | Health: ", threat_health)

	var threat = ThreatScene.instantiate()

	# ✅ Set ALL properties BEFORE adding to scene tree
	# This way _ready() runs with the correct values already set
	threat.threat_type = threat_type
	threat.target_asset = target_asset
	threat.target_position = asset_positions[target_asset]
	threat.speed = threat_speed
	threat.max_health = threat_health
	threat.current_health = threat_health

	# Random spawn position
	var spawn_pos = spawn_positions[randi() % spawn_positions.size()]
	threat.global_position = spawn_pos

	# ✅ add_child triggers _ready() which calls load_threat_animations() automatically
	# Do NOT call initialize_visuals() — it no longer exists
	add_child(threat)

	print("   Spawned at: ", threat.global_position)
	print("   Target: ", threat.target_position)
	print("   Threat type: ", threat.threat_type)

	# Connect signals to game manager
	var game_manager = get_tree().get_nodes_in_group("game_manager")
	if game_manager.size() > 0:
		threat.threat_blocked.connect(func(ttype, defense):
			game_manager[0].on_threat_blocked(threat, ttype, defense))
		threat.threat_succeeded.connect(game_manager[0].on_threat_succeeded)
		print("   ✅ Signals connected to game manager")
	else:
		print("   ❌ ERROR: No game manager found!")

	# Start moving
	threat.start_moving()
	print("   🚀 Threat spawned and moving!")
