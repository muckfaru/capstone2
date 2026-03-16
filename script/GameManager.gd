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

# GameMode multiplayer
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# ✅ Wave completion tracking
var threats_spawned_this_wave = 0
var threats_defeated_this_wave = 0

# ✅ Custom cursor
var custom_cursor_texture: Texture2D

# ✅ AUDIO SYSTEM - 100% BACKEND, NO TSCN NODES NEEDED
var audio_players = {}
var bgm_player: AudioStreamPlayer = null  # ✅ Background music player

var sfx_files = {
	"threat_hit": "gunshot.mp3",           # When defense hits threat
	"threat_kill": "threat_kill.mp3",     # When threat is eliminated
	"threat_miss": "threat_miss.mp3",          # When threat reaches asset
	"defense_select": "threat_miss.mp3",    # When selecting defense tool
	"wave_start": "wave_start.mp3",          # Wave beginning
	"wave_complete": "wave_complete.mp3", # Wave cleared
	"asset_damage": "shield_lost.mp3",   # Asset takes damage
	"game_over": "game_over.mp3",        # Mission failed
	"victory": "victoryA.mp3"             # Mission complete
}

# ✅ Background music file
var bgm_file = "commandobg.mp3"  # Change this to your preferred BGM file

# Asset health tracking with numeric display
var assets_health = {
	"employee_pc": 5,
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

# ✅ Enhanced wave configurations with progressive difficulty
var wave_configs = {
	1: {
		"name": "Wave 1",
		"threats": ["phishing", "malware", "brute_force", "ddos", "sql_injection", "ransomware"],
		"count": 8,
		"delay": 5.0,
		"threat_speed": 60.0,
		"threat_health": 1
	},
	2: {
		"name": "Wave 2",
		"threats": ["phishing", "brute_force", "malware", "ddos"],
		"count": 8,
		"delay": 3.5,
		"threat_speed": 100.0,
		"threat_health": 1
	},
	3: {
		"name": "Wave 3",
		"threats": ["phishing", "ddos", "sql_injection", "malware", "brute_force"],
		"count": 12,
		"delay": 3.0,
		"threat_speed": 120.0,
		"threat_health": 2
	},
	4: {
		"name": "Wave 4",
		"threats": ["ransomware", "zero_day", "sql_injection", "ddos", "phishing", "malware"],
		"count": 15,
		"delay": 2.5,
		"threat_speed": 140.0,
		"threat_health": 2
	},
	5: {
		"name": "Wave 5",
		"threats": ["ransomware", "zero_day", "insider_threat", "sql_injection", "ddos", "brute_force", "phishing"],
		"count": 20,
		"delay": 2.0,
		"threat_speed": 160.0,
		"threat_health": 3
	}
}

# Node references
@onready var threat_spawner = $ThreatSpawner
@onready var ui_layer = $UILayer
@onready var timer_label = $UILayer/GameUI/TopBar/TimeLabel
@onready var score_label = $UILayer/GameUI/TopBar/ScoreLabel
@onready var wave_label = $UILayer/GameUI/TopBar/WaveLabel if has_node("UILayer/GameUI/TopBar/WaveLabel") else null
@onready var feedback_popup = $UILayer/FeedbackPopup
@onready var game_over_panel = $UILayer/GameOverPanel
@onready var start_panel = $UILayer/StartPanel
@onready var instruction_panel = $UILayer/InstructionPanel

# ✅ PowerUp System
const PowerUpScene = preload("res://scene/PowerUp.tscn")
var powerup_timer: Timer

func _ready():
	randomize()
	
	# ✅ Load audio system (no testing on startup)
	_load_audio_files()
	await get_tree().create_timer(0.1).timeout  # Brief wait for audio system
	
	setup_game()
	show_start_screen()
	
	load_custom_cursor()
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# ✅ GameMode detection
	if get_tree().has_meta("gamemode_room_code"):
		_is_gamemode = true
		_gamemode_room_code = get_tree().get_meta("gamemode_room_code")
		_gamemode_lobby_url = get_tree().get_meta("gamemode_lobby_url")
		_gamemode_start_time_ms = get_tree().get_meta("gamemode_start_time_ms")
		print("[Asset vs Threats] 🎮 GameMode detected — room: %s" % _gamemode_room_code)
		# Hide quit button in GameMode
		if quit_btn:
			quit_btn.visible = false
	
	print("\n=== 🛡️ DEFENSE MATRIX ===")
	for threat in defense_matrix.keys():
		print("  ", threat, " → ", defense_matrix[threat])
	print("=========================\n")

	if is_in_group("game_manager"):
		print("✅ GameManager is in 'game_manager' group")
	else:
		print("❌ ERROR: GameManager NOT in group!")
		add_to_group("game_manager")

# ✅ ENHANCED AUDIO LOADING SYSTEM - NO AUTO-TESTING
func _load_audio_files() -> void:
	print("\n" + "=".repeat(60))
	print("🔊 AUDIO SYSTEM INITIALIZATION")
	print("=".repeat(60))
	
	var sfx_path = "res://asset/minigamessoundsfx/"
	
	# Step 1: Check AudioServer settings
	print("\n🔧 STEP 1: AudioServer Check")
	var master_idx = AudioServer.get_bus_index("Master")
	print("Master bus index: ", master_idx)
	print("Master bus volume: ", AudioServer.get_bus_volume_db(master_idx), " dB")
	print("Master bus muted: ", AudioServer.is_bus_mute(master_idx))
	
	if AudioServer.is_bus_mute(master_idx):
		print("⚠️ WARNING: Master bus is MUTED! Unmuting...")
		AudioServer.set_bus_mute(master_idx, false)
	
	# ✅ FIX: Set Master volume to 0 dB if it's too quiet
	var current_volume = AudioServer.get_bus_volume_db(master_idx)
	if current_volume < -20.0:
		print("⚠️ WARNING: Master bus volume too low (", current_volume, " dB)")
		print("🔧 Setting Master bus to 0 dB (full volume)...")
		AudioServer.set_bus_volume_db(master_idx, 0.0)
		print("✅ Master bus volume now: ", AudioServer.get_bus_volume_db(master_idx), " dB")
	
	# Step 2: Load SFX files
	print("\n🎵 STEP 2: Loading SFX Files")
	var loaded_count = 0
	var failed_count = 0
	
	for sfx_name in sfx_files.keys():
		var file_name = sfx_files[sfx_name]
		var full_path = sfx_path + file_name
		
		# Create AudioStreamPlayer
		var player = AudioStreamPlayer.new()
		player.name = "SFX_" + sfx_name
		player.bus = "Master"
		add_child(player)
		
		# Check if file exists
		if ResourceLoader.exists(full_path):
			var stream = load(full_path)
			if stream:
				player.stream = stream
				audio_players[sfx_name] = player
				loaded_count += 1
				print("  ✅ ", sfx_name, " → ", file_name)
			else:
				audio_players[sfx_name] = null
				failed_count += 1
				print("  ❌ Failed to load: ", file_name)
		else:
			audio_players[sfx_name] = null
			failed_count += 1
			print("  ❌ Not found: ", file_name)
	
	# Step 3: Load Background Music
	print("\n🎵 STEP 3: Loading Background Music")
	var bgm_path = sfx_path + bgm_file
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGM_Player"
	bgm_player.bus = "Master"
	bgm_player.volume_db = -20.0  # ✅ Quieter BGM for better gameplay focus
	add_child(bgm_player)
	
	if ResourceLoader.exists(bgm_path):
		var bgm_stream = load(bgm_path)
		if bgm_stream:
			bgm_player.stream = bgm_stream
			print("  ✅ BGM loaded: ", bgm_file)
			
			# ✅ Connect to finished signal for smooth looping
			bgm_player.connect("finished", _on_bgm_finished)
		else:
			print("  ❌ Failed to load BGM stream")
	else:
		print("  ❌ BGM file not found: ", bgm_path)
	
	# Step 4: Summary
	print("\n" + "=".repeat(60))
	print("📊 AUDIO SUMMARY")
	print("=".repeat(60))
	print("SFX loaded: ", loaded_count, "/", sfx_files.size())
	print("BGM loaded: ", "Yes" if bgm_player.stream else "No")
	print("=".repeat(60) + "\n")

# ✅ BACKGROUND MUSIC CONTROLS
func start_bgm():
	"""Start playing background music with fade-in"""
	if bgm_player and bgm_player.stream and not bgm_player.playing:
		print("🎵 Starting background music...")
		bgm_player.volume_db = -80.0  # Start silent
		bgm_player.play()
		
		# Fade in over 2 seconds to -18dB (quieter)
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -18.0, 2.0)

func stop_bgm():
	"""Stop background music with fade-out"""
	if bgm_player and bgm_player.playing:
		print("🎵 Stopping background music...")
		
		# Fade out over 1.5 seconds
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, 1.5)
		tween.tween_callback(bgm_player.stop)

func _on_bgm_finished():
	"""Called when BGM finishes - seamless loop with crossfade"""
	if is_game_active and bgm_player and bgm_player.stream:
		print("🔄 Looping background music...")
		
		# Crossfade: fade out current, restart, fade in
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -25.0, 0.5)  # Quick fade out
		tween.tween_callback(func():
			bgm_player.play()  # Restart
		)
		tween.tween_property(bgm_player, "volume_db", -18.0, 0.5)  # Fade back in to -18dB

# ✅ PLAY SOUND FUNCTION (cleaner, no debug spam)
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if not sfx_name in audio_players:
		return
	
	var player = audio_players[sfx_name]
	
	if player == null or player.stream == null:
		return
	
	# Set volume and play
	player.volume_db = volume_db
	player.play()

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
	
	setup_powerup_timer()
	
	update_ui()
	update_all_health_bars()

func setup_powerup_timer():
	if powerup_timer == null:
		powerup_timer = Timer.new()
		powerup_timer.name = "PowerUpTimer"
		powerup_timer.timeout.connect(_on_powerup_timer_timeout)
		add_child(powerup_timer)
		
func _on_powerup_timer_timeout():
	if is_game_active and wave_in_progress:
		spawn_powerup()
		# Randomize next drop interval between 10 to 25 seconds
		powerup_timer.start(randf_range(10.0, 25.0))

func spawn_powerup():
	var powerup = PowerUpScene.instantiate()
	# Randomize the type before adding to scene
	powerup.powerup_type = randi() % 3
	# Spawn at a random X position near the top of the screen
	var random_x = randf_range(100.0, 1000.0)
	powerup.position = Vector2(random_x, -50.0)
	add_child(powerup)

# ✅ POWER UP ACTIVATIONS
func activate_freeze():
	print("❄️ FREEZE ACTIVATED! Stopping all threats...")
	show_feedback("❄️ FREEZE!", Color(0.5, 0.8, 1.0), "Threats stopped for 4s")
	
	var all_threats = get_tree().get_nodes_in_group("threats")
	for t in all_threats:
		if t and "speed" in t and t.speed > 0:
			var old_speed = t.speed
			t.speed = 0
			
			# Visual feedback
			t.modulate = Color(0.5, 0.8, 1.0)
			
			# Restore speed after 4 seconds
			var timer = get_tree().create_timer(4.0)
			timer.timeout.connect(func():
				if is_instance_valid(t):
					t.speed = old_speed
					t.modulate = Color(1.0, 1.0, 1.0)
			)

func activate_kill_all():
	print("⚡ KILL ALL ACTIVATED! Wiping board...")
	show_feedback("⚡ PURGE!", Color(1.0, 0.9, 0.2), "All active threats destroyed!")
	play_sfx("threat_kill", -2.0)
	
	var all_threats = get_tree().get_nodes_in_group("threats")
	for t in all_threats:
		if is_instance_valid(t) and not t.is_blocked:
			# Auto-kill them and grab the points
			score += 15
			threats_blocked += 1
			threats_defeated_this_wave += 1
			t.block_threat("kill_all_powerup")
			
	check_wave_completion()
	update_ui()

func activate_health_boost():
	print("✚ HEAL ACTIVATED! Restoring 1 asset...")
	
	var damaged_assets = []
	for asset_name in assets_health.keys():
		if assets_health[asset_name] > 0 and assets_health[asset_name] < assets_max_health[asset_name]:
			damaged_assets.append(asset_name)
			
	if damaged_assets.size() > 0:
		var target = damaged_assets[randi() % damaged_assets.size()]
		assets_health[target] += 1
		show_feedback("✚ REPAIR!", Color(0.2, 1.0, 0.2), target.replace("_", " ").capitalize() + " Healed!")
		
		# Update UI representation
		var asset_node = get_node_or_null("NetworkDiagram/" + target)
		if asset_node and asset_node.has_method("set_health"):
			asset_node.set_health(assets_health[target])
		update_asset_health_display(asset_node, target)
	else:
		# If everyone is full health, give bonus points instead
		score += 50
		show_feedback("✚ POWER BOOST!", Color(0.2, 1.0, 0.2), "+50 Bonus XP")
		update_ui()

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
	
	# ✅ Start background music when game starts
	start_bgm()
	
	# Start the powerup timer
	if powerup_timer:
		powerup_timer.start(randf_range(10.0, 20.0))
	
	start_wave(current_wave)

func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	if _is_gamemode:
		return  # Block quitting in GameMode
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	
	# ✅ Stop BGM when quitting
	stop_bgm()
	
	# ✅ Reset cursor to default
	reset_cursor()
	
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
	
	# Wave indicator
	if wave_label:
		if wave_in_progress:
			wave_label.text = "Wave %d/%d - %d/%d" % [current_wave, max_waves, threats_defeated_this_wave, threats_spawned_this_wave]
		else:
			wave_label.text = "Wave %d/%d - Ready!" % [current_wave, max_waves]

# ✅ Wave management system
func start_wave(wave_num):
	if wave_num > max_waves:
		win_game()
		return
	
	current_wave = wave_num
	wave_in_progress = true
	threats_spawned_this_wave = 0
	threats_defeated_this_wave = 0
	
	var config = wave_configs[current_wave]
	
	play_sfx("wave_start", -5.0)  # ✅ Wave start sound
	show_feedback("🎖️ " + config.name, Color(0.3, 0.7, 1), "Get Ready!")
	
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
	
	# Pass wave configuration to spawner
	threat_spawner.spawn_threat_advanced(
		threat_type,
		target,
		config.threat_speed,
		config.threat_health
	)

func on_threat_blocked(threat, threat_type, defense_used):
	if not threat_type in defense_matrix:
		show_feedback("❌ Unknown Threat!", Color(1, 0, 0), "System error")
		if threat and "click_count" in threat:
			threat.click_count = 0
		return
	
	var valid_defenses = defense_matrix[threat_type]
	
	if defense_used in valid_defenses:
		# Check if threat is destroyed
		if threat and threat.has_method("take_damage"):
			var destroyed = threat.take_damage()
			
			if destroyed:
				# Threat fully destroyed
				score += 15
				threats_blocked += 1
				threats_defeated_this_wave += 1
				
				# ✅ +5 second time bonus for each kill!
				game_time += 5.0
				
				play_sfx("threat_kill", -2.0)  # ✅ Killing blow
				show_feedback("💥 ELIMINATED! +5s ⏱️", Color(0, 1, 0), "+15 XP")
				
				check_wave_completion()
			else:
				# Threat damaged but not destroyed
				score += 5
				play_sfx("threat_hit", -2.0)  # ✅ Hit but not killed
				show_feedback("🎯 HIT!", Color(0.5, 1, 0.5), "+5 XP")
		
		update_ui()
	else:
		var needed_str = ""
		for d in valid_defenses:
			needed_str += d.replace("_", " ").capitalize() + " or "
		needed_str = needed_str.substr(0, needed_str.length() - 4)
		
		play_sfx("defense_select", -8.0)  # ✅ Wrong defense sound
		show_feedback("❌ Wrong Defense!", Color(1, 0.5, 0), "Need: " + needed_str)
		
		if threat and "click_count" in threat:
			threat.click_count = 0
		
		score = max(0, score - 3)
		update_ui()

func check_wave_completion():
	if threats_defeated_this_wave >= threats_spawned_this_wave:
		complete_wave()

func complete_wave():
	wave_in_progress = false
	
	# Wave completion bonus
	var wave_bonus = current_wave * 50
	score += wave_bonus
	
	play_sfx("wave_complete", -3.0)  # ✅ Wave complete sound
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
	threats_defeated_this_wave += 1
	
	play_sfx("threat_miss", 0.0)  # ✅ Threat reached asset
	damage_asset(target_asset, threat_type)
	
	check_wave_completion()

func damage_asset(asset_name, threat_type):
	if asset_name in assets_health:
		assets_health[asset_name] -= 1
		
		play_sfx("asset_damage", -3.0)  # ✅ Asset damage sound
		
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
	if powerup_timer:
		powerup_timer.stop()
	
	# ✅ Stop BGM on game over
	stop_bgm()
	
	play_sfx("game_over", -8.0)  # ✅ Quieter game over sound
	show_game_over()

func win_game():
	is_game_active = false
	if powerup_timer:
		powerup_timer.stop()
	
	# ✅ Stop BGM on victory
	stop_bgm()
	
	play_sfx("victory", -6.0)  # ✅ Quieter victory sound
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var protected_count = 0
	for health in assets_health.values():
		if health > 0:
			protected_count += 1
	var protection_rate = float(protected_count) / float(assets_health.size())
	
	var base_xp = 50  # Base XP for winning
	var wave_xp = current_wave * 8  # 8 XP per wave completed
	var score_xp = int((score / 1000.0) * 30)  # Up to 30 XP from score
	var protection_xp = int(protection_rate * 30)  # Up to 30 XP for protecting assets
	var total_xp_earned = base_xp + wave_xp + score_xp + protection_xp
	
	print("[Asset vs Threats] 🏆 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Wave XP: %d (waves %d)" % [wave_xp, current_wave])
	print("  Score XP: %d (score %d)" % [score_xp, score])
	print("  Protection XP: %d (%d/%d assets)" % [protection_xp, protected_count, assets_health.size()])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("asset_vs_threats", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	elif xp_awarded > 0:
		MinigameRewards.try_grant_rewards("asset_vs_threats", score, xp_awarded, self)
	
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	
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
	# Calculate stats first (needed for both GameMode and normal)
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
	
	# ✅ AWARD PARTIAL XP ON LOSS (Based on performance)
	var wave_xp = current_wave * 5  # 5 XP per wave reached (vs 8 XP on win)
	var score_xp = int((float(score) / 1000.0) * 15)  # Up to 15 XP from score (vs 30 on win)
	var protection_xp = int((protection_rate / 100.0) * 15)  # Up to 15 XP from protection (vs 30 on win)
	var partial_xp = wave_xp + score_xp + protection_xp
	
	print("[Asset vs Threats] 💀 Game Over - Awarding partial XP:")
	print("  Wave XP: %d (wave %d)" % [wave_xp, current_wave])
	print("  Score XP: %d (score %d)" % [score_xp, score])
	print("  Protection XP: %d (%.1f%% protected)" % [protection_xp, protection_rate])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Award XP but DON'T mark as completed
	TutorialManager.add_xp(partial_xp, "Asset vs Threats (Attempt)")
	TutorialManager.mark_minigame_attempted("asset_vs_threats", partial_xp)
	TutorialManager.mark_minigame_attempted("intermediate_assetandthreat", partial_xp)
	
	# ✅ GameMode: skip game over panel, go straight to leaderboard
	if _is_gamemode:
		_submit_gamemode_score(score, 500)
		return
	
	if game_over_panel:
		game_over_panel.visible = true
		
		var result_label = game_over_panel.get_node_or_null("VBox/ResultLabel")
		var stats_label = game_over_panel.get_node_or_null("VBox/StatsLabel")
		
		if result_label:
			if protection_rate >= 50:
				result_label.text = "MISSION FAILED\nWave " + str(current_wave) + " Reached\nRating: " + rating + "\n+" + str(partial_xp) + " XP"
			else:
				result_label.text = "NETWORK COMPROMISED\nWave " + str(current_wave) + "\nRating: Failed\n+" + str(partial_xp) + " XP"
		
		if stats_label:
			stats_label.text = "Score: " + str(score) + "\n"
			stats_label.text += "Threats Blocked: " + str(threats_blocked) + "\n"
			stats_label.text += "Threats Missed: " + str(threats_missed) + "\n"
			stats_label.text += "Wave Reached: " + str(current_wave) + "/" + str(max_waves) + "\n"
			stats_label.text += "Assets Protected: " + str(protected_count) + "/6"

func show_feedback(title, color, message):
	if feedback_popup:
		feedback_popup.show_message(title, color, message)

func restart_game():
	print("\n🔄 RESTARTING GAME...")
	
	# ✅ Stop any playing BGM
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
	
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
	await get_tree().process_frame
	update_all_health_bars()
	
	print("   ✅ Game state reset")
	
	# Start the game (this will also start BGM)
	start_game()

func _on_StartButton_pressed():
	start_game()

func _on_RestartButton_pressed():
	restart_game()

func _input(event):
		# Handle ESC key to quit/return to mode selection
		if event.is_action_pressed("ui_cancel"):  # ESC key
			if _is_gamemode:
				return  # Block ESC in GameMode
			print("[Network Defense] ESC key pressed")
			_on_quit_pressed()


# ============================================
# GAMEMODE MULTIPLAYER
# ============================================

func _submit_gamemode_score(final_score: int, max_score: int) -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": final_score,
		"max_score": max_score,
		"time_taken_ms": time_taken_ms
	})

	print("[GameMode] Submitting score: %d/%d (time: %dms)" % [final_score, max_score, time_taken_ms])

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Score submitted → status %d" % code)
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	reset_cursor()
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")
