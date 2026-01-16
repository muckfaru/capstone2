extends Node2D

# Game state
var score = 0
var threats_blocked = 0
var threats_missed = 0
var game_time = 90.0
var is_game_active = false
var current_level = 1

# Asset health tracking
var assets_health = {
	"employee_pc": 3,
	"database": 3,
	"router": 3,
	"email_server": 3,
	"backup": 3,
	"ceo_laptop": 3
}

# Defense effectiveness matrix - THIS IS THE KEY!
var defense_matrix = {
	"phishing": ["email_filter"],
	"brute_force": ["firewall", "strong_password"],
	"malware": ["antivirus"],
	"ddos": ["firewall"],
	"sql_injection": ["security_patch"],
	"ransomware": ["antivirus", "backup_system"],
	"zero_day": ["security_patch"],
	"insider_threat": ["access_control"]
}

# Threat definitions
var threat_definitions = {
	"phishing": {"targets": ["employee_pc", "ceo_laptop"], "damage": "Steals passwords"},
	"brute_force": {"targets": ["database"], "damage": "Cracks passwords"},
	"malware": {"targets": ["employee_pc"], "damage": "Encrypts files"},
	"ddos": {"targets": ["router"], "damage": "Floods network"},
	"sql_injection": {"targets": ["database"], "damage": "Steals data"},
	"ransomware": {"targets": ["backup", "database"], "damage": "Encrypts files"}
}

# Wave configurations
var wave_configs = {
	1: {"threats": ["phishing", "brute_force", "malware"], "count": 3, "delay": 4.0},
	2: {"threats": ["phishing", "ddos", "sql_injection", "malware"], "count": 6, "delay": 3.0},
	3: {"threats": ["phishing", "ddos", "sql_injection", "ransomware", "brute_force"], "count": 9, "delay": 2.0}
}

# Node references
@onready var threat_spawner = $ThreatSpawner
@onready var ui_layer = $UILayer
@onready var timer_label = $UILayer/GameUI/TopBar/TimeLabel
@onready var score_label = $UILayer/GameUI/TopBar/ScoreLabel
@onready var feedback_popup = $UILayer/FeedbackPopup
@onready var game_over_panel = $UILayer/GameOverPanel
@onready var start_panel = $UILayer/StartPanel

# Cheat sheet
var cheat_sheet: Panel = null

# Audio (will work if you add AudioStreamPlayer nodes)
@onready var success_sound = $SuccessSound if has_node("SuccessSound") else null
@onready var fail_sound = $FailSound if has_node("FailSound") else null
@onready var alarm_sound = $AlarmSound if has_node("AlarmSound") else null

func _ready():
	randomize()
	setup_game()
	show_start_screen()
	create_cheat_sheet()
	
	# Debug: Print defense matrix
	print("\n=== 🛡️ DEFENSE MATRIX ===")
	for threat in defense_matrix.keys():
		print("  ", threat, " → ", defense_matrix[threat])
	print("=========================\n")

	if is_in_group("game_manager"):
		print("✅ GameManager is in 'game_manager' group")
	else:
		print("❌ ERROR: GameManager NOT in group!")
		add_to_group("game_manager")  # Add it automatically
		
func create_cheat_sheet():
	cheat_sheet = Panel.new()
	cheat_sheet.position = Vector2(10, 70)
	cheat_sheet.size = Vector2(250, 400)
	cheat_sheet.z_index = 50
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(230, 380)
	
	var title = Label.new()
	title.text = "🔍 DEFENSE GUIDE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Add each threat and its defenses
	for threat in defense_matrix.keys():
		var threat_label = Label.new()
		var defenses = defense_matrix[threat]
		var defense_str = ""
		for d in defenses:
			defense_str += d.replace("_", " ").capitalize() + ", "
		defense_str = defense_str.substr(0, defense_str.length() - 2) # Remove last comma
		
		threat_label.text = threat.capitalize() + ":\n  → " + defense_str
		threat_label.add_theme_font_size_override("font_size", 11)
		threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		threat_label.custom_minimum_size = Vector2(220, 0)
		vbox.add_child(threat_label)
		
		var spacer = HSeparator.new()
		spacer.modulate = Color(0.3, 0.3, 0.3)
		vbox.add_child(spacer)
	
	cheat_sheet.add_child(vbox)
	ui_layer.add_child(cheat_sheet)

func setup_game():
	# Reset game state
	score = 0
	threats_blocked = 0
	threats_missed = 0
	game_time = 90.0
	is_game_active = false
	
	# Reset asset health
	for asset in assets_health.keys():
		assets_health[asset] = 3
	
	# Update UI
	update_ui()

func show_start_screen():
	if start_panel:
		start_panel.visible = true
	if game_over_panel:
		game_over_panel.visible = false

func start_game():
	if start_panel:
		start_panel.visible = false
	is_game_active = true
	start_threat_waves()

func _process(delta):
	if is_game_active:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			end_game()

func update_ui():
	if timer_label:
		timer_label.text = "Time: " + str(int(game_time)) + "s"
	if score_label:
		score_label.text = "Score: " + str(score)

func start_threat_waves():
	var config = wave_configs[current_level]
	for i in range(config.count):
		await get_tree().create_timer(config.delay).timeout
		if is_game_active:
			spawn_threat(config.threats)

func spawn_threat(threat_types):
	var threat_type = threat_types[randi() % threat_types.size()]
	var targets = threat_definitions[threat_type].targets
	var target = targets[randi() % targets.size()]
	
	threat_spawner.spawn_threat(threat_type, target)

func on_threat_blocked(threat, threat_type, defense_used):
	print("\n=== 🎯 ON_THREAT_BLOCKED CALLED ===")
	print("Threat object: ", threat)
	print("Threat type: ", threat_type)
	print("Defense used: ", defense_used)
	print("Valid defenses: ", defense_matrix.get(threat_type, []))
	
	# Check if this threat type exists in the defense matrix
	if not threat_type in defense_matrix:
		print("❌ ERROR: Threat type '", threat_type, "' not found in defense matrix!")
		show_feedback("❌ Unknown Threat!", Color(1, 0, 0), "System error")
		return
	
	# Get valid defenses for this threat
	var valid_defenses = defense_matrix[threat_type]
	
	# Check if the defense used is valid
	if defense_used in valid_defenses:
		print("✅✅✅ CORRECT DEFENSE! ✅✅✅")
		score += 10
		threats_blocked += 1
		print("New score: ", score)
		print("Threats blocked: ", threats_blocked)
		
		show_feedback("✅ BLOCKED!", Color(0, 1, 0), "+10 XP")
		play_sound(success_sound)
		update_ui()
		
		# Tell the threat to block itself
		print("Calling threat.block_threat(", defense_used, ")")
		threat.block_threat(defense_used)
	else:
		print("❌ WRONG DEFENSE!")
		print("You used: ", defense_used)
		print("Needed: ", valid_defenses)
		show_feedback("❌ Wrong Defense!", Color(1, 0.5, 0), "Need: " + str(valid_defenses))
		play_sound(fail_sound)
	
	print("=== END ON_THREAT_BLOCKED ===\n")

func on_threat_succeeded(threat_type, target_asset):
	print("💥 Threat succeeded: ", threat_type, " hit ", target_asset)
	threats_missed += 1
	damage_asset(target_asset, threat_type)
	play_sound(alarm_sound)

func damage_asset(asset_name, threat_type):
	if asset_name in assets_health:
		assets_health[asset_name] -= 1
		
		var damage_msg = threat_definitions[threat_type].damage if threat_type in threat_definitions else "System compromised"
		show_feedback("💥 " + asset_name.replace("_", " ").capitalize() + " Hit!", Color(1, 0, 0), damage_msg)
		
		# Update asset visual
		var asset_node = get_node_or_null("NetworkDiagram/" + asset_name)
		if asset_node:
			asset_node.take_damage()
		
		if assets_health[asset_name] <= 0:
			show_feedback("🚨 CRITICAL!", Color(0.8, 0, 0), asset_name.replace("_", " ").capitalize() + " compromised!")
			check_lose_condition()

func check_lose_condition():
	var compromised_count = 0
	
	for asset in assets_health.keys():
		if assets_health[asset] <= 0:
			compromised_count += 1
	
	if compromised_count >= 3:
		end_game()

func end_game():
	is_game_active = false
	show_game_over()

func show_game_over():
	if game_over_panel:
		game_over_panel.visible = true
		
		var result_label = game_over_panel.get_node_or_null("VBox/ResultLabel")
		var stats_label = game_over_panel.get_node_or_null("VBox/StatsLabel")
		
		var protected_count = 0
		for health in assets_health.values():
			if health > 0:
				protected_count += 1
		
		var protection_rate = float(protected_count) / float(assets_health.size()) * 100
		var rating = "Bronze ⭐"
		
		if protection_rate >= 100:
			rating = "Gold ⭐⭐⭐"
		elif protection_rate >= 75:
			rating = "Silver ⭐⭐"
		
		if result_label:
			if protection_rate >= 50:
				result_label.text = "MISSION SUCCESS!\nRating: " + rating
			else:
				result_label.text = "NETWORK COMPROMISED\nRating: Failed"
		
		if stats_label:
			stats_label.text = "Score: " + str(score) + "\n"
			stats_label.text += "Threats Blocked: " + str(threats_blocked) + "\n"
			stats_label.text += "Threats Missed: " + str(threats_missed) + "\n"
			stats_label.text += "Assets Protected: " + str(protected_count) + "/6"

func show_feedback(title, color, message):
	print("\n📢 SHOW_FEEDBACK CALLED:")
	print("   Title: ", title)
	print("   Color: ", color)
	print("   Message: ", message)
	print("   Feedback popup exists: ", feedback_popup != null)
	
	if feedback_popup:
		print("   Calling feedback_popup.show_message()")
		feedback_popup.show_message(title, color, message)
		print("   Feedback popup visible: ", feedback_popup.visible)
	else:
		print("   ❌ ERROR: feedback_popup is null!")

func play_sound(sound_player):
	if sound_player and sound_player.stream:
		sound_player.play()

func restart_game():
	setup_game()
	if game_over_panel:
		game_over_panel.visible = false
	start_game()

func _on_StartButton_pressed():
	start_game()

func _on_RestartButton_pressed():
	restart_game()
