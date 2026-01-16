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

func spawn_threat(threat_type, target_asset):
	print("📦 Spawning threat: ", threat_type, " targeting ", target_asset)
	
	var threat = ThreatScene.instantiate()
	
	# Set threat properties BEFORE adding to tree
	threat.threat_type = threat_type
	threat.target_asset = target_asset
	threat.target_position = asset_positions[target_asset]
	
	# Random spawn position
	var spawn_pos = spawn_positions[randi() % spawn_positions.size()]
	threat.global_position = spawn_pos
	
	# Add to scene tree
	add_child(threat)
	
	# NOW initialize visuals (after threat_type is set)
	threat.initialize_visuals()
	
	print("   Spawned at: ", threat.global_position)
	print("   Target: ", threat.target_position)
	print("   Threat type set to: ", threat.threat_type)
	
	# Connect signals to game manager - PASS THE THREAT OBJECT
	var game_manager = get_tree().get_nodes_in_group("game_manager")
	if game_manager.size() > 0:
		# Lambda adds threat as first parameter
		threat.threat_blocked.connect(func(ttype, defense): 
			game_manager[0].on_threat_blocked(threat, ttype, defense))
		threat.threat_succeeded.connect(game_manager[0].on_threat_succeeded)
		print("   ✅ Signals connected to game manager")
	else:
		print("   ❌ ERROR: No game manager found!")
	
	# Start moving
	threat.start_moving()