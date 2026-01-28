extends Control

# ============================================
# NETWORK DEFENSE SIMULATOR
# Gamified network security training
# ============================================

enum GamePhase {
	INTRO,
	IP_DEFENSE,
	PORT_SCANNER,
	PROTOCOL_GUARDIAN,
	FINAL_BOSS,
	VICTORY
}

enum ConnectionType {
	SAFE,
	THREAT
}

@onready var point_lights = [
	$TextureRect/PointLight2D,
	$TextureRect/PointLight2D2,
	$TextureRect/PointLight2D3,
	$TextureRect/PointLight2D4
]
var current_phase = GamePhase.INTRO
var score := 0
var combo := 0
var multiplier := 1.0
var shields := 5
var max_shields := 5
var xp_earned := 0
var wave_number := 1
var connections_handled := 0
var time = 0.0
var base_energy = 1.0
var flicker_speed = 5.0
var flicker_amount = 0.2
# Power-ups
var hint_tokens := 3
var time_freeze_available := true
var auto_filter_charges := 2

# Timers
var phase_timer := 0.0
var spawn_timer := 0.0
var spawn_interval := 2.0  # Seconds between spawns
var is_paused := false
var is_frozen := false
var freeze_duration := 0.0
var is_game_over := false

# Active connections on screen
var active_connections := []

@onready var quit_btn: Button = $TextureRect/Quit

# Challenge data
var ip_challenges := [
	{"text": "192.168.1.100", "type": ConnectionType.SAFE, "category": "private", "hint": "192.168 = Home network"},
	{"text": "10.0.0.50", "type": ConnectionType.SAFE, "category": "private", "hint": "10.x = Company network"},
	{"text": "45.33.32.156:4444", "type": ConnectionType.THREAT, "category": "backdoor", "hint": "Port 4444 = BACKDOOR!"},
	{"text": "172.16.5.20", "type": ConnectionType.SAFE, "category": "private", "hint": "172.16-31 = Private"},
	{"text": "8.8.8.8:53", "type": ConnectionType.SAFE, "category": "dns", "hint": "Google DNS"},
	{"text": "203.45.67.89:31337", "type": ConnectionType.THREAT, "category": "hacker", "hint": "31337 = Elite hacker port"},
]

var port_challenges := [
	{"text": "192.168.1.100:80", "type": ConnectionType.SAFE, "hint": "Port 80 = HTTP"},
	{"text": "45.33.32.156:443", "type": ConnectionType.SAFE, "hint": "Port 443 = HTTPS"},
	{"text": "203.45.12.34:4444", "type": ConnectionType.THREAT, "hint": "4444 = TROJAN"},
	{"text": "8.8.8.8:22", "type": ConnectionType.SAFE, "hint": "Port 22 = SSH"},
	{"text": "45.67.89.12:1337", "type": ConnectionType.THREAT, "hint": "1337 = Malware"},
]

var protocol_challenges := [
	{"text": "HTTPS", "type": ConnectionType.SAFE, "hint": "Encrypted web"},
	{"text": "HTTP", "type": ConnectionType.THREAT, "hint": "No encryption!"},
	{"text": "SSH", "type": ConnectionType.SAFE, "hint": "Secure shell"},
	{"text": "FTP", "type": ConnectionType.THREAT, "hint": "Plain text transfer"},
	{"text": "Telnet", "type": ConnectionType.THREAT, "hint": "Sends passwords plain!"},
]

# Node references
@onready var phase_label: Label = $UI/TopBar/PhaseLabel
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var combo_label: Label = $UI/TopBar/ComboLabel
@onready var shield_container: HBoxContainer = $UI/TopBar/ShieldContainer
@onready var timer_label: Label = $UI/TopBar/TimerLabel

@onready var connection_spawn: Node2D = $GameArea/ConnectionSpawn
@onready var allow_zone: Area2D = $GameArea/AllowZone
@onready var block_zone: Area2D = $GameArea/BlockZone

@onready var hint_button: Button = $UI/PowerUps/HintButton
@onready var freeze_button: Button = $UI/PowerUps/FreezeButton
@onready var auto_button: Button = $UI/PowerUps/AutoButton

@onready var intro_panel: Panel = $UI/IntroPanel
@onready var victory_panel: Panel = $UI/VictoryPanel

# Preload connection scene
const CONNECTION_SCENE = preload("res://scene/network_connection.tscn")

# Debug
var debug_mode := true

func _ready() -> void:
	print("🎮 Network Defense Simulator Ready")
	
	if debug_mode:
		print("DEBUG MODE: Press SPACE to manually spawn a connection")
	
	# Connect signals
	allow_zone.area_entered.connect(_on_allow_zone_entered)
	block_zone.area_entered.connect(_on_block_zone_entered)
	quit_btn.pressed.connect(_on_quit_pressed)
	hint_button.pressed.connect(_use_hint)
	freeze_button.pressed.connect(_use_time_freeze)
	auto_button.pressed.connect(_use_auto_filter)
	
	_update_ui()
	_start_phase(GamePhase.INTRO)


func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if debug_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("DEBUG: Manually spawning connection")
			_spawn_connection()

func _process(delta: float) -> void:
	# Flicker effect for PointLight2D
	time += delta * flicker_speed
	var noise = sin(time) * cos(time * 1.3) * sin(time * 1.7)
	
	# Apply flicker to all lights
	for light in point_lights:
		if light:  # Safety check
			light.energy = base_energy + (noise * flicker_amount)
	
	if is_paused or is_game_over:
		return
	# Handle time freeze
	if is_frozen:
		freeze_duration -= delta
		if freeze_duration <= 0:
			is_frozen = false
			_resume_connections()
		return
	
	# Update phase timer
	phase_timer += delta
	_update_timer_display()
	
	# Spawn connections based on phase
	if current_phase in [GamePhase.IP_DEFENSE, GamePhase.PORT_SCANNER, GamePhase.PROTOCOL_GUARDIAN, GamePhase.FINAL_BOSS]:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_spawn_connection()

func _start_phase(phase: GamePhase) -> void:
	current_phase = phase
	phase_timer = 0.0
	spawn_timer = 0.0
	
	# Clear existing connections
	for conn in active_connections:
		if is_instance_valid(conn):
			conn.queue_free()
	active_connections.clear()
	
	match phase:
		GamePhase.INTRO:
			_show_intro()
		GamePhase.IP_DEFENSE:
			phase_label.text = "PHASE 1: IP Defense"
			spawn_interval = 2.5
			intro_panel.hide()
		GamePhase.PORT_SCANNER:
			phase_label.text = "PHASE 2: Port Scanner"
			spawn_interval = 2.0
			wave_number = 2
		GamePhase.PROTOCOL_GUARDIAN:
			phase_label.text = "PHASE 3: Protocol Guardian"
			spawn_interval = 1.8
			wave_number = 3
		GamePhase.FINAL_BOSS:
			phase_label.text = "FINAL PHASE: APT Attack!"
			spawn_interval = 1.2
			wave_number = 4
		GamePhase.VICTORY:
			_show_victory()

func _show_intro() -> void:
	intro_panel.show()
	var intro_text = intro_panel.get_node("VBox/IntroText")
	intro_text.text = """
Your company's network is under attack!
The security team is offline.

YOU are the last line of defense.

🎯 MISSION:
• ALLOW safe connections (drag to green zone)
• BLOCK threats (drag to red zone)
• Protect your shields
• Build combos for bonus points

Press START to defend the network!"""

func _show_victory() -> void:
	victory_panel.show()
	var victory_text = victory_panel.get_node("VBox/VictoryText")
	var title_label = victory_panel.get_node("VBox/TitleLabel")
	var retry_button = victory_panel.get_node("VBox/ButtonContainer/RetryButton")
	var finish_button = victory_panel.get_node("VBox/ButtonContainer/FinishButton")
	
	# Show both buttons for victory
	retry_button.visible = true
	finish_button.visible = true
	
	# Reset title color for victory
	title_label.text = "MISSION COMPLETE"
	title_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	
	# Calculate XP based on performance
	xp_earned = score + (combo * 10)
	if shields == max_shields:
		xp_earned += 100  # Perfect run bonus
	
	var star_rating = _calculate_stars()
	var stars = "⭐".repeat(star_rating)
	
	victory_text.text = """🎉 NETWORK SECURED! 🎉

%s

Final Score: %d
Max Combo: %d
Shields Remaining: %d/%d

XP Earned: +%d XP

You've mastered network defense!""" % [stars, score, combo, shields, max_shields, xp_earned]

func _show_game_over() -> void:
	victory_panel.show()
	var victory_text = victory_panel.get_node("VBox/VictoryText")
	var title_label = victory_panel.get_node("VBox/TitleLabel")
	var retry_button = victory_panel.get_node("VBox/ButtonContainer/RetryButton")
	var finish_button = victory_panel.get_node("VBox/ButtonContainer/FinishButton")
	
	# Show only retry button for game over
	retry_button.visible = true
	finish_button.visible = false
	
	# Change title to show failure
	title_label.text = "NETWORK BREACHED!"
	title_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	
	var star_rating = _calculate_stars()
	var stars = "⭐".repeat(star_rating) if star_rating > 0 else "💔"
	
	victory_text.text = """🚨 SHIELDS DEPLETED 🚨

%s

Final Score: %d
Max Combo: %d
Connections Handled: %d

The network has been compromised.
Try again to improve your defense!""" % [stars, score, combo, connections_handled]

func _calculate_stars() -> int:
	if shields >= 5 and combo >= 10:
		return 3
	elif shields >= 3 and combo >= 5:
		return 2
	else:
		return 1

func _spawn_connection() -> void:
	# Determine which challenge pool to use
	var challenge_data
	match current_phase:
		GamePhase.IP_DEFENSE:
			challenge_data = ip_challenges[randi() % ip_challenges.size()]
		GamePhase.PORT_SCANNER:
			challenge_data = port_challenges[randi() % port_challenges.size()]
		GamePhase.PROTOCOL_GUARDIAN:
			challenge_data = protocol_challenges[randi() % protocol_challenges.size()]
		GamePhase.FINAL_BOSS:
			# Mix all challenges
			var all_challenges = ip_challenges + port_challenges + protocol_challenges
			challenge_data = all_challenges[randi() % all_challenges.size()]
		_:
			if debug_mode:
				# In debug mode, spawn even in intro
				challenge_data = ip_challenges[0]
			else:
				return
	
	if debug_mode:
		print("Spawning connection: ", challenge_data)
	
	# Create connection node
	var connection = CONNECTION_SCENE.instantiate()
	connection_spawn.add_child(connection)
	
	# Set spawn position - centered with tighter range
	# Screen is 1280x720, connection is 200px wide
	# ConnectionSpawn is at x=576, so we offset from there
	# Center spawn area: -200 to 200 (400px range centered)
	var spawn_x = randf_range(-200, 200)
	connection.position = Vector2(spawn_x, -50)
	
	if debug_mode:
		print("Connection spawned at: ", connection.global_position)
	
	# Configure connection
	connection.set_data(challenge_data)
	connection.destroyed.connect(_on_connection_destroyed)
	
	active_connections.append(connection)
	
	# Check phase completion (e.g., after 10 connections)
	if current_phase != GamePhase.INTRO:
		connections_handled += 1
		if connections_handled >= 10:
			connections_handled = 0
			_advance_phase()

func _advance_phase() -> void:
	match current_phase:
		GamePhase.IP_DEFENSE:
			_start_phase(GamePhase.PORT_SCANNER)
		GamePhase.PORT_SCANNER:
			_start_phase(GamePhase.PROTOCOL_GUARDIAN)
		GamePhase.PROTOCOL_GUARDIAN:
			_start_phase(GamePhase.FINAL_BOSS)
		GamePhase.FINAL_BOSS:
			_start_phase(GamePhase.VICTORY)

func _on_allow_zone_entered(area: Area2D) -> void:
	if debug_mode:
		print("Area entered ALLOW zone: ", area)
	
	var connection = area
	if connection and connection.has_method("is_dragging"):
		if debug_mode:
			print("Connection is dragging: ", connection.is_dragging())
		if not connection.is_dragging():
			return
		_process_decision(connection, "allow")

func _on_block_zone_entered(area: Area2D) -> void:
	if debug_mode:
		print("Area entered BLOCK zone: ", area)
	
	var connection = area
	if connection and connection.has_method("is_dragging"):
		if debug_mode:
			print("Connection is dragging: ", connection.is_dragging())
		if not connection.is_dragging():
			return
		_process_decision(connection, "block")

func _process_decision(connection, decision: String) -> void:
	var is_correct = false
	
	if decision == "allow" and connection.connection_type == ConnectionType.SAFE:
		is_correct = true
	elif decision == "block" and connection.connection_type == ConnectionType.THREAT:
		is_correct = true
	
	if is_correct:
		_handle_correct(connection)
	else:
		_handle_wrong(connection)
	
	# Remove connection using call_deferred to avoid physics callback error
	active_connections.erase(connection)
	connection.call_deferred("queue_free")

func _handle_correct(connection) -> void:
	combo += 1
	
	# Update multiplier based on combo
	if combo >= 10:
		multiplier = 3.0
	elif combo >= 5:
		multiplier = 2.0
	elif combo >= 3:
		multiplier = 1.5
	else:
		multiplier = 1.0
	
	var points = int(10 * multiplier)
	score += points
	
	# Visual feedback
	_show_floating_text(connection.global_position, "+%d" % points, Color.GREEN)
	_play_success_effect(connection.global_position)
	
	_update_ui()

func _handle_wrong(connection) -> void:
	combo = 0
	multiplier = 1.0
	shields -= 1
	
	# Visual feedback
	_show_floating_text(connection.global_position, "BREACH!", Color.RED)
	_play_error_effect(connection.global_position)
	_screen_shake()
	
	_update_ui()
	
	# Game over check
	if shields <= 0:
		_game_over()

func _game_over() -> void:
	print("Game Over - No shields remaining")
	is_game_over = true
	
	# Stop all connections from moving
	for conn in active_connections:
		if is_instance_valid(conn):
			conn.freeze()
	
	_show_game_over()

func _show_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.global_position = pos
	add_child(label)
	
	# Animate
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", pos.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _play_success_effect(pos: Vector2) -> void:
	# Green particle burst
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.color = Color.GREEN
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _play_error_effect(pos: Vector2) -> void:
	# Red explosion
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.color = Color.RED
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.initial_velocity_min = 150
	particles.initial_velocity_max = 250
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _screen_shake() -> void:
	var original_pos = position
	var tween = create_tween()
	for i in range(4):
		tween.tween_property(self, "position", original_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

func _use_hint() -> void:
	if hint_tokens <= 0 or is_game_over:
		return
	
	hint_tokens -= 1
	# Show hint for next connection
	if active_connections.size() > 0:
		var conn = active_connections[0]
		conn.show_hint()
	_update_ui()

func _use_time_freeze() -> void:
	if not time_freeze_available or is_game_over:
		return
	
	time_freeze_available = false
	is_frozen = true
	freeze_duration = 5.0
	
	# Pause all connections
	for conn in active_connections:
		conn.freeze()
	
	_update_ui()

func _resume_connections() -> void:
	for conn in active_connections:
		conn.unfreeze()

func _use_auto_filter() -> void:
	if auto_filter_charges <= 0 or is_game_over:
		return
	
	auto_filter_charges -= 1
	
	# Auto-handle next 3 safe connections
	var handled = 0
	for conn in active_connections:
		if conn.connection_type == ConnectionType.SAFE and handled < 3:
			_handle_correct(conn)
			conn.call_deferred("queue_free")
			active_connections.erase(conn)
			handled += 1
	
	_update_ui()

func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	combo_label.text = "Combo: x%d (%.1fx)" % [combo, multiplier]
	
	# Update shields
	for i in range(shield_container.get_child_count()):
		shield_container.get_child(i).queue_free()
	
	for i in range(max_shields):
		var shield_icon = Label.new()
		shield_icon.text = "🛡️" if i < shields else "💔"
		shield_icon.add_theme_font_size_override("font_size", 20)
		shield_container.add_child(shield_icon)
	
	# Update power-up buttons - disable all if game over
	hint_button.text = "" % hint_tokens
	hint_button.disabled = hint_tokens <= 0 or is_game_over
	
	freeze_button.text = "" if time_freeze_available else "Used"
	freeze_button.disabled = not time_freeze_available or is_game_over
	
	auto_button.text = "" % auto_filter_charges
	auto_button.disabled = auto_filter_charges <= 0 or is_game_over

func _update_timer_display() -> void:
	var minutes = int(phase_timer) / 60
	var seconds = int(phase_timer) % 60
	timer_label.text = "%02d:%02d" % [int(minutes), int(seconds)]

func _on_connection_destroyed(connection) -> void:
	# Connection timed out (fell off screen)
	if connection.connection_type == ConnectionType.THREAT:
		# Threat escaped = lose shield
		shields -= 1
		combo = 0
		_update_ui()
	
	active_connections.erase(connection)

func _on_start_button_pressed() -> void:
	_start_phase(GamePhase.IP_DEFENSE)

func _on_retry_button_pressed() -> void:
	# Hide victory panel
	victory_panel.hide()
	
	# Reset game over state
	is_game_over = false
	
	# Reset stats
	score = 0
	combo = 0
	multiplier = 1.0
	shields = max_shields
	hint_tokens = 3
	time_freeze_available = true
	auto_filter_charges = 2
	connections_handled = 0
	wave_number = 1
	xp_earned = 0
	
	# Clear any remaining connections
	for conn in active_connections:
		if is_instance_valid(conn):
			conn.queue_free()
	active_connections.clear()
	
	# Update UI
	_update_ui()
	
	# Start from beginning
	_start_phase(GamePhase.IP_DEFENSE)

func _on_finish_button_pressed() -> void:
	# Save results
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.save_tutorial_result("network_defense", xp_earned, xp_earned)
		if tutorial_mgr.has_signal("save_completed"):
			await tutorial_mgr.save_completed
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
