extends Control

# ============================================
# MALWARE INCIDENT RESPONSE SIMULATION
# Educational Advanced Tutorial
# ============================================

# Phase system
enum Phase {
	DETECTION,
	INVESTIGATION,
	CONTAINMENT,
	ERADICATION,
	RECOVERY
}

var current_phase: Phase = Phase.DETECTION
var phase_index: int = 0

# Scenario data
var scenarios := []
var current_scenario_index: int = 0

# Scoring
var score: int = 1000
var mistakes: int = 0
var start_time: float = 0.0
var elapsed_time: float = 0.0

# Node references
@onready var phase_label: Label = $CanvasLayer/Header/PhaseLabel
@onready var timer_label: Label = $CanvasLayer/Header/TimerLabel
@onready var alert_panel: Panel = $CanvasLayer/AlertPanel
@onready var alert_text: Label = $CanvasLayer/AlertPanel/AlertText
@onready var system_monitor: Panel = $CanvasLayer/SystemMonitor
@onready var action_buttons: HBoxContainer = $CanvasLayer/ActionButtons
@onready var feedback_panel: Panel = $CanvasLayer/FeedbackPanel
@onready var feedback_icon: Label = $CanvasLayer/FeedbackPanel/FeedbackIcon
@onready var feedback_text: Label = $CanvasLayer/FeedbackPanel/FeedbackText
@onready var debrief_screen: Panel = $CanvasLayer/DebriefScreen
@onready var score_label: Label = $CanvasLayer/DebriefScreen/DebriefContent/ScoreLabel
@onready var time_label: Label = $CanvasLayer/DebriefScreen/DebriefContent/TimeLabel

# Action button references
@onready var action1_btn: Button = $CanvasLayer/ActionButtons/Action1
@onready var action2_btn: Button = $CanvasLayer/ActionButtons/Action2
@onready var action3_btn: Button = $CanvasLayer/ActionButtons/Action3

# Process/Network/Registry labels
@onready var process_list: VBoxContainer = $CanvasLayer/SystemMonitor/ProcessList


func _ready() -> void:
	print("🦠 Advanced Tutorial (Malware Simulation) Ready")
	print("📊 Node references check:")
	print("  - Phase label:", phase_label != null)
	print("  - Action buttons:", action1_btn != null, action2_btn != null, action3_btn != null)
	print("  - System monitor:", system_monitor != null)
	_initialize_scenarios()
	_start_scenario()


func _process(_delta: float) -> void:
	if start_time > 0 and debrief_screen.visible == false:
		elapsed_time = Time.get_ticks_msec() / 1000.0 - start_time
		@warning_ignore("integer_division")
		var minutes: int = int(elapsed_time) / 60
		var seconds: int = int(elapsed_time) % 60
		timer_label.text = "⏱ %02d:%02d" % [minutes, seconds]


# ============================================
# SCENARIO INITIALIZATION
# ============================================
func _initialize_scenarios() -> void:
	scenarios = [
		# PHASE 1: DETECTION (Identify the threat)
		{
			"phase": Phase.DETECTION,
			"phase_name": "DETECTION",
			"alert": "SECURITY ALERT: Employee John Doe clicked 'invoice.pdf.exe'\nEndpoint Detection: Suspicious process spawned on PC-ACCOUNTING-07",
			"actions": [
				"Delete the file immediately",
				"Isolate machine from network",
				"Restart the computer"
			],
			"correct_action": 1,
			"feedback_correct": "✅ CORRECT! Network isolation is the first critical step.\n\nWhy? Prevents lateral movement to other systems and stops C2 communication.",
			"feedback_wrong": "❌ WRONG! Deleting/restarting triggers fail-safe mechanisms.\n\nThe malware may spread to network shares or encrypt files immediately.",
			"score_penalty": 200
		},
		
		# PHASE 2: INVESTIGATION (Analyze the threat)
		{
			"phase": Phase.INVESTIGATION,
			"phase_name": "INVESTIGATION",
			"alert": "Machine isolated. Analyzing system state...\nWhat should you investigate FIRST to understand the attack?",
			"actions": [
				"Check browser history",
				"Analyze network connections & processes",
				"Scan with antivirus"
			],
			"correct_action": 1,
			"feedback_correct": "✅ CORRECT! Network connections reveal C2 servers.\n\nYou found: 45.33.32.156:443 (Command & Control server)\nProcess 'invoice.exe' spawned hidden PowerShell scripts.",
			"feedback_wrong": "❌ WRONG! Browser history and AV scans are too slow.\n\nActive C2 communication is the priority - it shows what the attacker is doing RIGHT NOW.",
			"score_penalty": 150
		},
		
		# PHASE 3: CONTAINMENT (Stop the threat)
		{
			"phase": Phase.CONTAINMENT,
			"phase_name": "CONTAINMENT",
			"alert": "Threat identified: Trojan with C2 connection to 45.33.32.156\nWhat is your NEXT containment action?",
			"actions": [
				"Unplug the network cable only",
				"Kill processes + Block C2 IP at firewall",
				"Shutdown the computer"
			],
			"correct_action": 1,
			"feedback_correct": "✅ CORRECT! Multi-layer containment is best.\n\nKilling processes stops the malware execution.\nFirewall block prevents reconnection attempts.",
			"feedback_wrong": "❌ WRONG! Partial containment leaves gaps.\n\nUnplugging alone: Malware persists, reconnects after reboot.\nShutdown: Loses volatile memory evidence (RAM artifacts).",
			"score_penalty": 150
		},
		
		# PHASE 4: ERADICATION (Remove the threat)
		{
			"phase": Phase.ERADICATION,
			"phase_name": "ERADICATION",
			"alert": "Processes killed, C2 blocked. Now removing persistence mechanisms...\nWhere does this Trojan typically hide?",
			"actions": [
				"Only in Downloads folder",
				"Registry Run keys + Scheduled Tasks + AppData",
				"Desktop shortcuts"
			],
			"correct_action": 1,
			"feedback_correct": "✅ CORRECT! Trojans use multiple persistence methods.\n\nFound and removed:\n• HKCU\\...\\Run\\WindowsUpdate\n• Scheduled Task: 'SystemUpdate'\n• C:\\Users\\JohnDoe\\AppData\\Roaming\\svchost32.exe",
			"feedback_wrong": "❌ WRONG! Trojans use sophisticated persistence.\n\nIf you miss registry keys or scheduled tasks, the malware auto-restarts on boot.",
			"score_penalty": 150
		},
		
		# PHASE 5: RECOVERY (Restore and prevent)
		{
			"phase": Phase.RECOVERY,
			"phase_name": "RECOVERY",
			"alert": "Malware removed successfully. Final recovery step?\nHow do you ensure system integrity?",
			"actions": [
				"Just restart and continue working",
				"Restore from clean backup + Patch vulnerability + Train user",
				"Reinstall OS (nuclear option)"
			],
			"correct_action": 1,
			"feedback_correct": "✅ PERFECT! Defense-in-depth recovery strategy.\n\n1. Clean backup ensures no remnants\n2. Patch closes attack vector (e.g., CVE-2024-XXXX)\n3. User training prevents re-infection\n\n🎯 INCIDENT RESOLVED!",
			"feedback_wrong": "❌ WRONG! Incomplete recovery risks reinfection.\n\nRestarting alone: Malware may have rootkit components.\nFull reinstall: Overkill for most cases, causes downtime.",
			"score_penalty": 150
		}
	]


# ============================================
# SCENARIO FLOW
# ============================================
func _start_scenario() -> void:
	start_time = Time.get_ticks_msec() / 1000.0
	current_scenario_index = 0
	_load_scenario(current_scenario_index)


func _load_scenario(index: int) -> void:
	if index >= scenarios.size():
		_show_debrief()
		return
	
	var scenario = scenarios[index]
	current_phase = scenario.phase
	
	# Update UI
	phase_label.text = "PHASE: " + scenario.phase_name
	alert_text.text = scenario.alert
	
	# Update action buttons
	action1_btn.text = scenario.actions[0]
	action2_btn.text = scenario.actions[1]
	action3_btn.text = scenario.actions[2]
	
	# Show alert panel with animation
	_animate_alert_panel()
	
	# Enable buttons
	_set_buttons_enabled(true)
	
	# Update system monitor based on phase
	_update_system_monitor(current_phase)


func _update_system_monitor(phase: Phase) -> void:
	# Show different system states based on phase
	match phase:
		Phase.DETECTION:
			# Initial infection detected
			pass  # Default state already shows suspicious processes
		
		Phase.INVESTIGATION:
			# Show more details
			var network2: Label = process_list.get_node("Network2")
			network2.text = "❌ 192.168.1.100 → 45.33.32.156:443     [C2 SERVER - ACTIVE BEACONING]"
		
		Phase.CONTAINMENT:
			# Show processes being killed
			var process3: Label = process_list.get_node("Process3")
			process3.text = "⏹️ invoice.exe           PID: 9012    [TERMINATED]"
		
		Phase.ERADICATION:
			# Show cleanup progress
			var process4: Label = process_list.get_node("Process4")
			process4.modulate = Color(0.5, 0.5, 0.5, 0.7)
			process4.text = "⏹️ powershell.exe        PID: 3456    [TERMINATED]"
		
		Phase.RECOVERY:
			# Show clean state
			var registry1: Label = process_list.get_node("Registry1")
			registry1.text = "✅ Registry keys cleaned - No persistence detected"
			registry1.modulate = Color(0, 1, 0, 1)


# ============================================
# USER INTERACTION
# ============================================
func _on_action_selected(action_index: int) -> void:
	print("🎯 Action selected: ", action_index)
	_set_buttons_enabled(false)
	
	var scenario: Dictionary = scenarios[current_scenario_index]
	var is_correct: bool = (action_index == scenario.correct_action)
	
	if is_correct:
		score += 50  # Bonus for correct answer
		_show_feedback(true, scenario.feedback_correct)
	else:
		score -= scenario.score_penalty
		mistakes += 1
		_show_feedback(false, scenario.feedback_wrong)
	
	# Wait for feedback, then proceed
	await get_tree().create_timer(4.0).timeout
	feedback_panel.visible = false
	
	current_scenario_index += 1
	_load_scenario(current_scenario_index)


func _show_feedback(is_correct: bool, message: String) -> void:
	feedback_panel.visible = true
	feedback_icon.text = "✅" if is_correct else "❌"
	feedback_text.text = message
	
	# Color based on correctness
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0.3, 0, 0.95) if is_correct else Color(0.3, 0, 0, 0.95)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0, 1, 0, 1) if is_correct else Color(1, 0, 0, 1)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.corner_radius_bottom_left = 15
	feedback_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Bounce animation
	feedback_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback_panel, "scale", Vector2(1.0, 1.0), 0.5)


func _set_buttons_enabled(enabled: bool) -> void:
	action1_btn.disabled = !enabled
	action2_btn.disabled = !enabled
	action3_btn.disabled = !enabled


# ============================================
# DEBRIEF (End screen)
# ============================================
func _show_debrief() -> void:
	debrief_screen.visible = true
	
	# Calculate final score
	var time_bonus: int = max(0, 300 - int(elapsed_time))  # Bonus for speed (under 5 min)
	var final_score: int = max(0, score + time_bonus)
	
	score_label.text = "SCORE: %d/1000" % final_score
	
	@warning_ignore("integer_division")
	var minutes: int = int(elapsed_time) / 60
	var seconds: int = int(elapsed_time) % 60
	time_label.text = "⏱ Time: %d:%02d  |  Mistakes: %d" % [minutes, seconds, mistakes]
	
	# Grade
	var grade := ""
	if final_score >= 900:
		grade = "S-RANK: Security Expert! 🏆"
	elif final_score >= 750:
		grade = "A-RANK: Incident Response Pro! 🥇"
	elif final_score >= 600:
		grade = "B-RANK: Good Security Awareness 🥈"
	elif final_score >= 400:
		grade = "C-RANK: Needs More Training 🥉"
	else:
		grade = "D-RANK: Review the Basics 📚"
	
	var summary: Label = $CanvasLayer/DebriefScreen/DebriefContent/Summary
	summary.text = "📊 INCIDENT SUMMARY:\n• Trojan detected and isolated\n• C2 communication blocked\n• Persistence mechanisms removed\n• System restored successfully\n\n🏅 " + grade
	
	# Save tutorial result to TutorialManager
	var tutorial_id: String = get_tree().get_meta("tutorial_id", "advance_scenarios")
	var tutorial_mgr = get_node("/root/TutorialManager")
	tutorial_mgr.save_tutorial_result(tutorial_id, final_score, 1000)
	await tutorial_mgr.save_completed
	
	# Animate debrief
	debrief_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(debrief_screen, "modulate:a", 1.0, 0.5)


# ============================================
# NAVIGATION BUTTONS
# ============================================
func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	# TODO: Load next advanced scenario (e.g., Ransomware, APT)
	print("🎯 Next scenario not yet implemented")
	_on_back_pressed()


func _on_back_pressed() -> void:
	# Return to landing
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# ============================================
# ANIMATIONS
# ============================================
func _animate_alert_panel() -> void:
	alert_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(alert_panel, "scale", Vector2(1.0, 1.0), 0.6)
	
	# No pulse animation - static warning icon


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
