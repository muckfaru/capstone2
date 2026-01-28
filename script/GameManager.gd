extends Node2D

# Game state
var score = 0
var threats_blocked = 0
var threats_missed = 0
var game_time = 180.0  # Extended time for 5 waves
var is_game_active = false
var current_wave = 1
var max_waves = 5
var wave_in_progress = false
@onready var quit_btn: Button = $Background/Quit
# ✅ NEW: Wave completion tracking
var threats_spawned_this_wave = 0
var threats_defeated_this_wave = 0

# ✅ Custom cursor
var custom_cursor_texture: Texture2D

# Asset health tracking with numeric display
var assets_health = {
	"employee_pc": 5,    # Increased health for longer gameplay
	"database": 5,
	"router": 5,
	"email_server": 5,
	"backup": 5,
	"ceo_laptop": 5
}

var assets_max_health = {
	"employee_pc": 5,
	"database": 5,
	"router": 5,
	"email_server": 5,
	"backup": 5,
	"ceo_laptop": 5
}

# Defense effectiveness matrix
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
	"ransomware": {"targets": ["backup", "database"], "damage": "Encrypts files"},
	"zero_day": {"targets": ["employee_pc", "database", "router"], "damage": "Exploits vulnerability"},
	"insider_threat": {"targets": ["database", "ceo_laptop"], "damage": "Data breach"}
}

# ✅ NEW: Enhanced wave configurations with progressive difficulty
var wave_configs = {
	1: {
		"name": "Wave 1",
		"threats": ["phishing", "malware", "brute_force", "ddos", "sql_injection", "ransomware"],  # ✅ ALL THREATS for tutorial
		"count": 8,  # More threats to show all types
		"delay": 5.0,  # Slower for learning
		"threat_speed": 60.0,  # Slower speed for learning
		"threat_health": 1  # 1 tap to kill
	},
	2: {
		"name": "Wave 2",
		"threats": ["phishing", "brute_force", "malware", "ddos"],
		"count": 8,
		"delay": 3.5,
		"threat_speed": 100.0,
		"threat_health": 1  # Still 1 tap
	},
	3: {
		"name": "Wave 3",
		"threats": ["phishing", "ddos", "sql_injection", "malware", "brute_force"],
		"count": 12,
		"delay": 3.0,
		"threat_speed": 120.0,
		"threat_health": 2  # 2 taps required!
	},
	4: {
		"name": "Wave 4",
		"threats": ["ransomware", "zero_day", "sql_injection", "ddos", "phishing", "malware"],
		"count": 15,
		"delay": 2.5,
		"threat_speed": 140.0,
		"threat_health": 2  # 2 taps
	},
	5: {
		"name": "Wave 5",
		"threats": ["ransomware", "zero_day", "insider_threat", "sql_injection", "ddos", "brute_force", "phishing"],
		"count": 20,
		"delay": 2.0,
		"threat_speed": 160.0,
		"threat_health": 3  # FINAL WAVE: 3 taps required!
	}
}

# Node references
@onready var threat_spawner = $ThreatSpawner
@onready var ui_layer = $UILayer
@onready var timer_label = $UILayer/GameUI/TopBar/TimeLabel
@onready var score_label = $UILayer/GameUI/TopBar/ScoreLabel
@onready var wave_label = $UILayer/GameUI/TopBar/WaveLabel  # ✅ NEW
@onready var feedback_popup = $UILayer/FeedbackPopup
@onready var game_over_panel = $UILayer/GameOverPanel
@onready var start_panel = $UILayer/StartPanel
@onready var instruction_panel = $UILayer/InstructionPanel

# Audio
@onready var success_sound = $SuccessSound if has_node("SuccessSound") else null
@onready var fail_sound = $FailSound if has_node("FailSound") else null
@onready var alarm_sound = $AlarmSound if has_node("AlarmSound") else null

func _ready():
	randomize()
	setup_game()
	show_start_screen()
	
	load_custom_cursor()
	quit_btn.pressed.connect(_on_quit_pressed)
	print("\n=== 🛡️ DEFENSE MATRIX ===")
	for threat in defense_matrix.keys():
		print("  ", threat, " → ", defense_matrix[threat])
	print("=========================\n")

	if is_in_group("game_manager"):
		print("✅ GameManager is in 'game_manager' group")
	else:
		print("❌ ERROR: GameManager NOT in group!")
		add_to_group("game_manager")

func load_custom_cursor():
	var cursor_path = "res://asset/threats/crosshair.png"
	
	if ResourceLoader.exists(cursor_path):
		var original_texture = load(cursor_path)
		var desired_size = Vector2(80, 80)
		var image = original_texture.get_image()
		image.resize(desired_size.x, desired_size.y, Image.INTERPOLATE_LANCZOS)
		custom_cursor_texture = ImageTexture.create_from_image(image)
		print("✅ Custom cursor loaded and resized!")
	else:
		print("⚠️ Custom cursor not found at: ", cursor_path)

func set_cursor_for_gameplay():
	if custom_cursor_texture:
		var cursor_size = custom_cursor_texture.get_size()
		var hotspot = cursor_size / 2
		Input.set_custom_mouse_cursor(custom_cursor_texture, Input.CURSOR_ARROW, hotspot)

func reset_cursor():
	Input.set_custom_mouse_cursor(null)

func setup_game():
	score = 0
	threats_blocked = 0
	threats_missed = 0
	game_time = 180.0
	is_game_active = false
	current_wave = 1
	wave_in_progress = false
	threats_spawned_this_wave = 0
	threats_defeated_this_wave = 0
	
	# Reset asset health
	for asset in assets_health.keys():
		assets_health[asset] = assets_max_health[asset]
	
	update_ui()
	update_all_health_bars()

func show_start_screen():
	if instruction_panel:
		instruction_panel.visible = true
	if start_panel:
		start_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false
	
	set_cursor_for_gameplay()

func start_game():
	if start_panel:
		start_panel.visible = false
	if instruction_panel:
		instruction_panel.visible = false
	is_game_active = true
	
	set_cursor_for_gameplay()
	
	start_wave(current_wave)

func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _process(delta):
	if is_game_active:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			end_game()

func update_ui():
	if timer_label:
		var minutes = int(game_time) / 60
		var seconds = int(game_time) % 60
		timer_label.text = "Time: %d:%02d" % [minutes, seconds]
	
	if score_label:
		score_label.text = "Score: " + str(score)
	
	# ✅ NEW: Wave indicator
	if wave_label:
		if wave_in_progress:
			wave_label.text = "Wave %d/%d - %d/%d" % [current_wave, max_waves, threats_defeated_this_wave, threats_spawned_this_wave]
		else:
			wave_label.text = "Wave %d/%d - Ready!" % [current_wave, max_waves]

# ✅ NEW: Wave management system
func start_wave(wave_num):
	if wave_num > max_waves:
		win_game()
		return
	
	current_wave = wave_num
	wave_in_progress = true
	threats_spawned_this_wave = 0
	threats_defeated_this_wave = 0
	
	var config = wave_configs[current_wave]
	
	show_feedback("" + config.name, Color(0.3, 0.7, 1), "Get Ready!")
	
	print("\nStarting Wave ", current_wave)
	print("   Threat count: ", config.count)
	print("   Threat health: ", config.threat_health)
	print("   Speed: ", config.threat_speed)
	
	await get_tree().create_timer(2.0).timeout
	
	spawn_wave_threats(config)

func spawn_wave_threats(config):
	threats_spawned_this_wave = config.count
	
	for i in range(config.count):
		if not is_game_active:
			break
		
		await get_tree().create_timer(config.delay).timeout
		
		if is_game_active:
			spawn_threat_with_config(config)

func spawn_threat_with_config(config):
	var threat_type = config.threats[randi() % config.threats.size()]
	var targets = threat_definitions[threat_type].targets
	var target = targets[randi() % targets.size()]
	
	# ✅ Pass wave configuration to spawner
	threat_spawner.spawn_threat_advanced(
		threat_type,
		target,
		config.threat_speed,
		config.threat_health
	)

func on_threat_blocked(threat, threat_type, defense_used):
	print("\n=== 🎯 ON_THREAT_BLOCKED CALLED ===")
	print("Threat type: ", threat_type)
	print("Defense used: ", defense_used)
	
	if not threat_type in defense_matrix:
		show_feedback("❌ Unknown Threat!", Color(1, 0, 0), "System error")
		if threat and "click_count" in threat:
			threat.click_count = 0
		return
	
	var valid_defenses = defense_matrix[threat_type]
	
	if defense_used in valid_defenses:
		print("✅ CORRECT DEFENSE! ✅")
		
		# ✅ Check if threat is destroyed
		if threat and threat.has_method("take_damage"):
			var destroyed = threat.take_damage()
			
			if destroyed:
				# Threat fully destroyed
				score += 15  # Bonus for complete elimination
				threats_blocked += 1
				threats_defeated_this_wave += 1
				
				show_feedback("💥 ELIMINATED!", Color(0, 1, 0), "+15 XP")
				play_sound(success_sound)
				
				check_wave_completion()
			else:
				# Threat damaged but not destroyed
				score += 5
				show_feedback("🎯 HIT!", Color(0.5, 1, 0.5), "+5 XP")
				play_sound(success_sound)
		
		update_ui()
	else:
		print("❌ WRONG DEFENSE! ❌")
		
		var needed_str = ""
		for d in valid_defenses:
			needed_str += d.replace("_", " ").capitalize() + " or "
		needed_str = needed_str.substr(0, needed_str.length() - 4)
		
		show_feedback("❌ Wrong Defense!", Color(1, 0.5, 0), "Need: " + needed_str)
		play_sound(fail_sound)
		
		if threat and "click_count" in threat:
			threat.click_count = 0
		
		score = max(0, score - 3)
		update_ui()
	
	print("=== END ON_THREAT_BLOCKED ===\n")

# ✅ NEW: Check if wave is completed
func check_wave_completion():
	print("📊 Wave Progress: ", threats_defeated_this_wave, "/", threats_spawned_this_wave)
	
	if threats_defeated_this_wave >= threats_spawned_this_wave:
		complete_wave()

func complete_wave():
	wave_in_progress = false
	
	# Wave completion bonus
	var wave_bonus = current_wave * 50
	score += wave_bonus
	
	show_feedback("🎉 WAVE COMPLETE!", Color(0, 1, 0.5), "+" + str(wave_bonus) + " Bonus XP")
	
	print("✅ Wave ", current_wave, " completed!")
	
	await get_tree().create_timer(3.0).timeout
	
	if current_wave < max_waves:
		current_wave += 1
		start_wave(current_wave)
	else:
		win_game()

func on_threat_succeeded(threat_type, target_asset):
	print("💥 Threat succeeded: ", threat_type, " hit ", target_asset)
	threats_missed += 1
	threats_defeated_this_wave += 1  # Count as "dealt with" even if it hit
	damage_asset(target_asset, threat_type)
	play_sound(alarm_sound)
	
	check_wave_completion()

func damage_asset(asset_name, threat_type):
	if asset_name in assets_health:
		assets_health[asset_name] -= 1
		
		var damage_msg = threat_definitions[threat_type].damage if threat_type in threat_definitions else "System compromised"
		show_feedback("💥 " + asset_name.replace("_", " ").capitalize() + " Hit!", Color(1, 0, 0), damage_msg)
		
		# Update asset visual
		var asset_node = get_node_or_null("NetworkDiagram/" + asset_name)
		if asset_node:
			asset_node.take_damage()
			update_asset_health_display(asset_node, asset_name)
		
		if assets_health[asset_name] <= 0:
			show_feedback("🚨 CRITICAL!", Color(0.8, 0, 0), asset_name.replace("_", " ").capitalize() + " compromised!")
			check_lose_condition()

# ✅ NEW: Update health bar with numeric display
func update_asset_health_display(asset_node, asset_name):
	var health_label = asset_node.get_node_or_null("HealthLabel")
	if health_label:
		var current_health = assets_health[asset_name]
		var max_health = assets_max_health[asset_name]
		health_label.text = str(current_health) + "/" + str(max_health)

func update_all_health_bars():
	print("\n🏥 Updating all health bars...")
	for asset_name in assets_health.keys():
		var asset_node = get_node_or_null("NetworkDiagram/" + asset_name)
		if asset_node and asset_node.has_method("set_health"):
			asset_node.set_health(assets_health[asset_name])
			# Reset visual state
			asset_node.modulate = Color.WHITE
			var name_label = asset_node.get_node_or_null("NameLabel")
			if name_label:
				name_label.text = asset_name.replace("_", " ").capitalize()
				name_label.modulate = Color.WHITE
			print("   ✅ ", asset_name, " updated to ", assets_health[asset_name], "/", assets_max_health[asset_name])
		else:
			print("   ⚠️ Asset node not found: ", asset_name)

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

func win_game():
	is_game_active = false
	show_victory()

func show_victory():
	if game_over_panel:
		game_over_panel.visible = true
		
		var result_label = game_over_panel.get_node_or_null("VBox/ResultLabel")
		var stats_label = game_over_panel.get_node_or_null("VBox/StatsLabel")
		
		if result_label:
			result_label.text = "🎉 MISSION SUCCESS! 🎉\nAll Waves Defended!\nRating: LEGEND ⭐⭐⭐"
			result_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		
		if stats_label:
			var time_remaining = int(game_time)
			var time_bonus = time_remaining * 10
			score += time_bonus
			
			stats_label.text = "Final Score: " + str(score) + "\n"
			stats_label.text += "Threats Blocked: " + str(threats_blocked) + "\n"
			stats_label.text += "Threats Missed: " + str(threats_missed) + "\n"
			stats_label.text += "Time Bonus: +" + str(time_bonus) + "\n"
			stats_label.text += "\n🏆 PERFECT DEFENSE! 🏆"

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
				result_label.text = "MISSION FAILED\nWave " + str(current_wave) + " Reached\nRating: " + rating
			else:
				result_label.text = "NETWORK COMPROMISED\nWave " + str(current_wave) + "\nRating: Failed"
		
		if stats_label:
			stats_label.text = "Score: " + str(score) + "\n"
			stats_label.text += "Threats Blocked: " + str(threats_blocked) + "\n"
			stats_label.text += "Threats Missed: " + str(threats_missed) + "\n"
			stats_label.text += "Wave Reached: " + str(current_wave) + "/" + str(max_waves) + "\n"
			stats_label.text += "Assets Protected: " + str(protected_count) + "/6"

func show_feedback(title, color, message):
	if feedback_popup:
		feedback_popup.show_message(title, color, message)

func play_sound(sound_player):
	if sound_player and sound_player.stream:
		sound_player.play()

func restart_game():
	print("\n🔄 RESTARTING GAME...")
	
	# Clear any existing threats
	for threat in get_tree().get_nodes_in_group("threats"):
		threat.queue_free()
	
	# Clear defense tool selection
	var defense_tools = get_tree().get_nodes_in_group("defense_tools")
	if defense_tools.size() > 0:
		var first_tool = defense_tools[0]
		if first_tool.has_method("clear_class_selection"):
			first_tool.clear_class_selection()
			print("   ✅ Defense selection cleared")
	
	# Reset game state
	setup_game()
	
	# Hide game over panel
	if game_over_panel:
		game_over_panel.visible = false
	
	# Force update all asset health displays
	await get_tree().process_frame  # Wait one frame for scene to update
	update_all_health_bars()
	
	print("   ✅ Game state reset")
	print("   Score: ", score)
	print("   Time: ", game_time)
	print("   Wave: ", current_wave)
	
	# Start the game
	start_game()

func _on_StartButton_pressed():
	start_game()

func _on_RestartButton_pressed():
	restart_game()
