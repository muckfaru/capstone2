extends Node2D

# Game state
var score := 0
var current_wave := 1
var systems_health := 3
var threats_neutralized := 0
var threats_missed := 0
var missed_threats_data := []

# Tutorial state
var tutorial_phase := 0
var tutorial_active := true

# Threat management
var active_threats := []
var threat_scene := preload("res://scene/SOCThreat.tscn")

# Spawn position settings - ADJUST THESE TO FIT YOUR GAME
const SPAWN_X := 1200  # How far right threats spawn (off-screen)
const SPAWN_Y_MIN := 120  # Minimum Y position (below the top UI)
const SPAWN_Y_MAX := 380  # Maximum Y position (above the command terminal)
# Note: Your game area appears to be ~650px tall
# Top UI is ~120px, Command Terminal starts at ~520px
# So safe spawn zone is roughly 120-480

# Command database
var command_database := {
	"block-source": {
		"category": "PERIMETER",
		"effective_against": ["port_scanner"],
		"description": "Block attacking IP at firewall"
	},
	"activate-scrubbing": {
		"category": "PERIMETER",
		"effective_against": ["ddos_flood"],
		"description": "Enable DDoS mitigation service"
	},
	"rate-limit": {
		"category": "ACCESS",
		"effective_against": ["brute_force"],
		"description": "Slow down authentication attempts"
	},
	"enforce-mfa": {
		"category": "ACCESS",
		"effective_against": ["credential_stuffing"],
		"description": "Require multi-factor authentication"
	},
	"isolate-host": {
		"category": "HOST",
		"effective_against": ["malware_beacon", "lateral_movement"],
		"description": "Quarantine infected machine"
	},
	"sanitize-input": {
		"category": "HOST",
		"effective_against": ["sql_injection"],
		"description": "Filter out injection attempts"
	},
	"block-egress": {
		"category": "DATA",
		"effective_against": ["data_exfiltration"],
		"description": "Stop outbound data transfer"
	},
	"restore-backup": {
		"category": "DATA",
		"effective_against": ["ransomware"],
		"description": "Recover from ransomware attack"
	},
	"segment-network": {
		"category": "NETWORK",
		"effective_against": ["lateral_movement"],
		"description": "Create security boundaries"
	}
}

# Threat types with their properties
var threat_types := {
	"port_scanner": {
		"name": "Port Scanner",
		"visual": "🔍",
		"color": Color(0.8, 0.8, 0.2),
		"description": "Probing multiple ports",
		"speed": 30.0,
		"impact": "System blueprint stolen",
		"tutorial_hint": "This attacker is scanning for open ports.\nBlock their IP address to stop reconnaissance.",
		"correct_command": "block-source"
	},
	"brute_force": {
		"name": "Brute Force Login",
		"visual": "🔓",
		"color": Color(1.0, 0.5, 0.0),
		"description": "Repeated auth attempts",
		"speed": 35.0,
		"impact": "Account compromised",
		"tutorial_hint": "Thousands of login attempts per second.\nSlow down authentication to stop the attack.",
		"correct_command": "rate-limit"
	},
	"sql_injection": {
		"name": "SQL Injection",
		"visual": "💉",
		"color": Color(1.0, 0.2, 0.2),
		"description": "Malformed database queries",
		"speed": 40.0,
		"impact": "Database dumped",
		"tutorial_hint": "Malicious SQL code in user input.\nValidate and clean inputs before database queries.",
		"correct_command": "sanitize-input"
	},
	"ddos_flood": {
		"name": "DDoS Flood",
		"visual": "🌊",
		"color": Color(0.3, 0.5, 1.0),
		"description": "High volume traffic",
		"speed": 25.0,
		"impact": "Service overwhelmed",
		"tutorial_hint": "Massive traffic flood overwhelming servers.\nActivate cloud-based traffic filtering.",
		"correct_command": "activate-scrubbing"
	},
	"malware_beacon": {
		"name": "Malware Beacon",
		"visual": "📡",
		"color": Color(0.8, 0.2, 0.8),
		"description": "Outbound suspicious connections",
		"speed": 32.0,
		"impact": "Command & control established",
		"tutorial_hint": "Infected host calling home to attacker.\nIsolate the compromised machine from network.",
		"correct_command": "isolate-host"
	},
	"credential_stuffing": {
		"name": "Credential Stuffing",
		"visual": "🌍",
		"color": Color(0.9, 0.6, 0.2),
		"description": "Valid logins from wrong locations",
		"speed": 38.0,
		"impact": "Multiple accounts breached",
		"tutorial_hint": "Stolen credentials from other breaches.\nRequire additional authentication factors.",
		"correct_command": "enforce-mfa"
	},
	"data_exfiltration": {
		"name": "Data Exfiltration",
		"visual": "📤",
		"color": Color(1.0, 0.3, 0.3),
		"description": "Large outbound transfers",
		"speed": 45.0,
		"impact": "Customer data leaked",
		"tutorial_hint": "Sensitive data being transferred out.\nBlock outbound connections immediately.",
		"correct_command": "block-egress"
	},
	"lateral_movement": {
		"name": "Lateral Movement",
		"visual": "↔️",
		"color": Color(0.7, 0.3, 0.9),
		"description": "Internal scanning after breach",
		"speed": 42.0,
		"impact": "Multiple systems infected",
		"tutorial_hint": "Attacker moving between internal systems.\nCreate network boundaries to contain spread.",
		"correct_command": "segment-network"
	}
}

func _ready():
	randomize()
	update_ui()
	show_tutorial()
	$UI/CommandTerminal/CommandInput.grab_focus()

func _process(_delta):
	# Keep input focused
	if not $UI/CommandTerminal/CommandInput.has_focus() and not tutorial_active:
		$UI/CommandTerminal/CommandInput.grab_focus()

func show_tutorial():
	tutorial_active = true
	var tutorial_texts := [
		"[b]Welcome to Incident Command: Active Defense Protocol[/b]\n\nYou are a Security Operations Center (SOC) analyst. Cyber threats will attack your systems from the right side of the screen.\n\nYour job: Type the correct defensive command to neutralize each threat.",
		"[b]How Threats Work[/b]\n\nEach threat has:\n• A visual indicator (emoji)\n• A description of its behavior\n• A specific defensive command that works against it\n\nWrong commands won't work - you need to match the defense to the attack type.",
		"[b]Your First Threat[/b]\n\nA [color=yellow]Port Scanner[/color] will appear soon.\nIt's probing your systems for open ports.\n\nThe correct command is: [color=cyan]block-source[/color]\n\nType it in the terminal at the bottom when the threat appears."
	]
	
	$UI/TutorialPanel.visible = true
	$UI/TutorialPanel/TutorialText.text = tutorial_texts[tutorial_phase]

func _on_tutorial_continue():
	tutorial_phase += 1
	
	if tutorial_phase >= 3:
		$UI/TutorialPanel.visible = false
		tutorial_active = false
		start_wave()
	else:
		show_tutorial()

func start_wave():
	$Timers/WaveTimer.start()

func _on_wave_timer_timeout():
	spawn_threat()
	
	# Schedule next threat
	var next_spawn_time := 0.0
	if current_wave <= 2:
		next_spawn_time = 5.0  # Tutorial: one at a time
	elif current_wave <= 5:
		next_spawn_time = 4.0  # Medium difficulty
	else:
		next_spawn_time = 3.0  # Higher difficulty
	
	$Timers/WaveTimer.start(next_spawn_time)

func spawn_threat():
	# Determine which threats are available this wave
	var available_threats := []
	
	if current_wave <= 3:
		# Tutorial waves: basic threats
		available_threats = ["port_scanner", "brute_force", "sql_injection"]
	elif current_wave <= 6:
		# Medium waves: add more threats
		available_threats = ["port_scanner", "brute_force", "sql_injection", "ddos_flood", "malware_beacon"]
	else:
		# Advanced waves: all threats
		available_threats = threat_types.keys()
	
	var threat_type = available_threats[randi() % available_threats.size()]
	var threat = threat_scene.instantiate()
	
	threat.setup(threat_type, threat_types[threat_type], current_wave <= 3)
	
	# FIXED SPAWN POSITION - Now uses constants defined at the top
	threat.position = Vector2(SPAWN_X, randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX))
	
	threat.reached_target.connect(_on_threat_reached_target)
	
	$ThreatContainer.add_child(threat)
	active_threats.append(threat)
	
	# Update command reference visibility
	if current_wave > 3:
		$UI/CommandReference/ReferenceList.modulate.a = 0.5  # Fade hints
	if current_wave > 6:
		$UI/CommandReference.visible = false  # Remove hints

func _on_command_submitted(command_text: String):
	var command = command_text.strip_edges().to_lower()
	$UI/CommandTerminal/CommandInput.clear()
	
	if active_threats.is_empty():
		show_feedback("✗ NO ACTIVE THREATS", Color.GRAY)
		return
	
	# Find the oldest threat (first in line)
	var target_threat = active_threats[0]
	
	# Check if command exists
	if not command_database.has(command):
		show_feedback("✗ UNKNOWN COMMAND - Check reference panel", Color.RED)
		return
	
	# Check if command is effective against this threat
	var threat_data = threat_types[target_threat.threat_type]
	var cmd_data = command_database[command]
	
	if target_threat.threat_type in cmd_data.effective_against:
		# CORRECT COMMAND
		handle_success(target_threat, command, cmd_data)
	else:
		# WRONG COMMAND
		handle_wrong_command(target_threat, command, cmd_data, threat_data)

func handle_success(threat, command: String, cmd_data: Dictionary):
	score += 100
	threats_neutralized += 1
	
	# Remove threat
	active_threats.erase(threat)
	threat.neutralize()
	
	var feedback = "[color=lime]✓ THREAT NEUTRALIZED[/color]\n"
	feedback += cmd_data.description
	show_feedback(feedback, Color.GREEN)
	
	update_ui()
	
	# Wave progression
	if threats_neutralized % 5 == 0:
		advance_wave()

func handle_wrong_command(threat, command: String, cmd_data: Dictionary, threat_data: Dictionary):
	var feedback = "[color=red]✗ INEFFECTIVE[/color]\n"
	
	# Contextual explanations
	if cmd_data.category == "PERIMETER" and threat.threat_type in ["sql_injection", "lateral_movement"]:
		feedback += "Can't block - this threat bypasses perimeter defenses. Try a different approach."
	elif cmd_data.category == "HOST" and threat.threat_type in ["ddos_flood"]:
		feedback += "Host defenses won't stop network floods. Use perimeter controls."
	else:
		feedback += "Wrong defense type. [color=yellow]" + threat_data.name + "[/color] needs: [color=cyan]" + threat_data.correct_command + "[/color]"
	
	show_feedback(feedback, Color.ORANGE)
	
	# Threat advances faster on wrong command
	threat.speed_up()

func _on_threat_reached_target(threat):
	# Threat reached a system
	active_threats.erase(threat)
	systems_health -= 1
	threats_missed += 1
	
	# Store data for debrief
	var threat_data = threat_types[threat.threat_type]
	missed_threats_data.append({
		"name": threat_data.name,
		"impact": threat_data.impact,
		"correct_command": threat_data.correct_command
	})
	
	# Show impact
	var feedback = "[color=red]⚠ BREACH DETECTED[/color]\n"
	feedback += threat_data.impact
	show_feedback(feedback, Color.RED)
	
	# Update system status
	update_system_status()
	
	if systems_health <= 0:
		game_over()
	else:
		update_ui()

func update_system_status():
	var systems = [
		$UI/ProtectedSystems/WebServer/Status,
		$UI/ProtectedSystems/Database/Status,
		$UI/ProtectedSystems/UserEndpoints/Status
	]
	
	var compromised_count = 3 - systems_health
	for i in range(compromised_count):
		if i < systems.size():
			systems[i].text = "COMPROMISED"
			systems[i].add_theme_color_override("font_color", Color.RED)

func advance_wave():
	current_wave += 1
	show_feedback("[color=cyan]▶ WAVE " + str(current_wave) + " INCOMING[/color]", Color.CYAN)
	update_ui()

func show_feedback(text: String, color: Color):
	$UI/CommandTerminal/FeedbackLabel.text = text
	$UI/CommandTerminal/FeedbackLabel.add_theme_color_override("default_color", color)
	
	# Auto-clear after 4 seconds
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid($UI/CommandTerminal/FeedbackLabel):
		$UI/CommandTerminal/FeedbackLabel.text = ""

func update_ui():
	$UI/TopBar/ScoreLabel.text = "Score: " + str(score)
	$UI/TopBar/WaveLabel.text = "Wave: " + str(current_wave)
	
	# Update health bar VALUE (this controls the fill)
	$UI/TopBar/HealthBar.value = systems_health
	
	# Get the fill StyleBox and change its color based on health
	var fill_style = $UI/TopBar/HealthBar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		# Color coding based on health
		if systems_health == 3:
			fill_style.bg_color = Color(0.0235294, 0.529412, 0.0941176, 0.772549)  # Green
		elif systems_health == 2:
			fill_style.bg_color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow
		else:
			fill_style.bg_color = Color(1.0, 0.0, 0.0, 0.8)  # Red

func game_over():
	$Timers/WaveTimer.stop()
	
	# Clear all threats
	for threat in active_threats:
		threat.queue_free()
	active_threats.clear()
	
	# Show debrief
	var debrief = "[b]SECURITY OPERATIONS FAILED[/b]\n\n"
	debrief += "Threats Neutralized: [color=lime]" + str(threats_neutralized) + "[/color]\n"
	debrief += "Threats Missed: [color=red]" + str(threats_missed) + "[/color]\n"
	debrief += "Final Score: " + str(score) + "\n\n"
	
	if missed_threats_data.size() > 0:
		debrief += "[color=yellow]MISSED THREATS:[/color]\n\n"
		for i in range(min(3, missed_threats_data.size())):
			var threat = missed_threats_data[i]
			debrief += "[color=red]• " + threat.name + "[/color]\n"
			debrief += "  Impact: " + threat.impact + "\n"
			debrief += "  Correct command: [color=cyan]" + threat.correct_command + "[/color]\n\n"
	
	$UI/DebriefPanel/DebriefText.text = debrief
	$UI/DebriefPanel.visible = true

func _on_restart_game():
	get_tree().reload_current_scene()