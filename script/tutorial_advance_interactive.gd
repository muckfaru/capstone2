extends Control

# ============================================
# HANDS-ON MALWARE REMOVAL LAB
# Interactive Cybersecurity Tutorial
# ============================================

enum Phase {
	DOWNLOAD,
	INFECTION,
	DETECTION,
	CONTAINMENT,
	ERADICATION,
	COMPLETE
}

var current_phase: Phase = Phase.DOWNLOAD
var commands_used: int = 0
var start_time: float = 0.0
var score: int = 1000
var hint_timer: float = 0.0
var show_hint_delay: float = 15.0  # Show hint after 15 seconds

# Malware simulation state
var malware_processes := ["malware.exe", "svchost32.exe", "updater.exe"]
var malware_registry_key := "WindowsUpdate"
var c2_server := "45.33.32.156"
var malware_active := false

# Node references
@onready var phase_label: Label = $CanvasLayer/Header/PhaseLabel
@onready var desktop: Panel = $CanvasLayer/Desktop
@onready var email_window: Panel = $CanvasLayer/Desktop/EmailWindow
@onready var infection_alert: Panel = $CanvasLayer/Desktop/InfectionAlert
@onready var cmd_terminal: Panel = $CanvasLayer/CMDTerminal
@onready var output_text: Label = $CanvasLayer/CMDTerminal/OutputScroll/OutputText
@onready var command_input: LineEdit = $CanvasLayer/CMDTerminal/InputContainer/CommandInput
@onready var hint_label: Label = $CanvasLayer/HintLabel
@onready var debrief_screen: Panel = $CanvasLayer/DebriefScreen
@onready var score_label: Label = $CanvasLayer/DebriefScreen/DebriefContent/Score
@onready var summary_label: Label = $CanvasLayer/DebriefScreen/DebriefContent/Summary

# Command validation
var valid_commands := {
	"tasklist": "detection",
	"netstat": "detection",
	"netstat -ano": "detection",
	"dir %appdata%": "detection",
	"taskkill /f /im malware.exe": "containment",
	"taskkill /f /im svchost32.exe": "containment",
	"taskkill /f /im updater.exe": "containment",
	"netsh advfirewall firewall add rule name=\"blockmfw\" dir=out remoteip=45.33.32.156 action=block": "containment",
	"reg delete \"hkcu\\software\\microsoft\\windows\\currentversion\\run\" /v \"windowsupdate\" /f": "eradication",
	"del /f /q \"%appdata%\\malware.exe\"": "eradication",
	"del /f /q \"%appdata%\\svchost32.exe\"": "eradication",
	"schtasks /delete /tn \"systemupdate\" /f": "eradication"
}

var phase_requirements := {
	"detection": ["tasklist", "netstat"],
	"containment": ["taskkill"],
	"eradication": ["reg delete", "del"]
}

var completed_tasks := {
	"detected_processes": false,
	"detected_network": false,
	"killed_processes": false,
	"blocked_c2": false,
	"removed_registry": false,
	"deleted_files": false
}


func _ready() -> void:
	print("🦠 Interactive Malware Lab Ready")
	_start_phase(Phase.DOWNLOAD)


func _process(delta: float) -> void:
	if malware_active and start_time > 0:
		hint_timer += delta
		if hint_timer >= show_hint_delay and !hint_label.visible:
			_show_hint()


# ============================================
# PHASE MANAGEMENT
# ============================================
func _start_phase(phase: Phase) -> void:
	current_phase = phase
	match phase:
		Phase.DOWNLOAD:
			phase_label.text = "Phase 1: Social Engineering"
			email_window.visible = true
			infection_alert.visible = false
			cmd_terminal.visible = false
		
		Phase.INFECTION:
			phase_label.text = "Phase 2: Infection!"
			email_window.visible = false
			infection_alert.visible = true
			await get_tree().create_timer(3.0).timeout
			_start_phase(Phase.DETECTION)
		
		Phase.DETECTION:
			phase_label.text = "Phase 3: Detection"
			desktop.visible = false
			cmd_terminal.visible = true
			command_input.grab_focus()
			malware_active = true
			start_time = Time.get_ticks_msec() / 1000.0
			hint_timer = 0.0
			_add_output("\n🚨 MALWARE DETECTED! Analyze the system.\n")
		
		Phase.CONTAINMENT:
			phase_label.text = "Phase 4: Containment"
			hint_timer = 0.0
			hint_label.visible = false
			_add_output("\n✅ Threat detected! Now STOP the malware.\n")
		
		Phase.ERADICATION:
			phase_label.text = "Phase 5: Eradication"
			hint_timer = 0.0
			hint_label.visible = false
			_add_output("\n✅ Malware contained! Now REMOVE all traces.\n")
		
		Phase.COMPLETE:
			_show_debrief()


# ============================================
# USER INTERACTIONS
# ============================================
func _on_download_pressed() -> void:
	print("💀 User clicked malicious download!")
	_start_phase(Phase.INFECTION)


func _on_command_submitted(command: String) -> void:
	var cmd := command.strip_edges().to_lower()
	_add_output("C:\\Users\\Player> " + command + "\n")
	
	commands_used += 1
	hint_timer = 0.0  # Reset hint timer
	hint_label.visible = false
	
	# Process command
	_execute_command(cmd)
	
	command_input.clear()
	command_input.grab_focus()


func _execute_command(cmd: String) -> void:
	# Check if valid command
	var command_found := false
	
	for valid_cmd in valid_commands.keys():
		if cmd == valid_cmd or cmd.begins_with(valid_cmd):
			command_found = true
			_handle_valid_command(cmd, valid_cmd)
			break
	
	if !command_found:
		if cmd == "help":
			_show_help()
		elif cmd == "cls" or cmd == "clear":
			output_text.text = "C:\\Users\\Player> "
		else:
			_add_output("❌ Command not recognized. Type 'help' for guidance.\n\n")
			score -= 10


func _handle_valid_command(_cmd: String, valid_cmd: String) -> void:
	var cmd_type: String = valid_commands[valid_cmd]
	
	match cmd_type:
		"detection":
			_handle_detection_command(valid_cmd)
		"containment":
			_handle_containment_command(valid_cmd)
		"eradication":
			_handle_eradication_command(valid_cmd)


func _handle_detection_command(cmd: String) -> void:
	if current_phase != Phase.DETECTION and current_phase != Phase.CONTAINMENT:
		_add_output("✅ Already completed detection phase.\n\n")
		return
	
	match cmd:
		"tasklist":
			completed_tasks["detected_processes"] = true
			_add_output("""
✅ RUNNING PROCESSES:
explorer.exe          PID: 1234    Normal
svchost.exe          PID: 5678    Normal
malware.exe          PID: 9012    ⚠️ SUSPICIOUS
svchost32.exe        PID: 3456    ⚠️ SUSPICIOUS (Fake svchost)
updater.exe          PID: 7890    ⚠️ SUSPICIOUS

""")
		
		"netstat", "netstat -ano":
			completed_tasks["detected_network"] = true
			_add_output("""
✅ NETWORK CONNECTIONS:
192.168.1.100 → 8.8.8.8:443           [HTTPS - Normal]
192.168.1.100 → 45.33.32.156:443      ⚠️ [C2 SERVER - MALWARE]

""")
		
		"dir %appdata%":
			_add_output("""
✅ APPDATA FOLDER:
malware.exe            120 KB   ⚠️ MALICIOUS
svchost32.exe           95 KB   ⚠️ MALICIOUS

""")
	
	_check_phase_completion()


func _handle_containment_command(cmd: String) -> void:
	if current_phase != Phase.CONTAINMENT and current_phase != Phase.ERADICATION:
		_add_output("⚠️ Need to detect threats first!\n\n")
		return
	
	if cmd.begins_with("taskkill"):
		if "malware.exe" in cmd or "svchost32.exe" in cmd or "updater.exe" in cmd:
			completed_tasks["killed_processes"] = true
			_add_output("✅ Process terminated successfully.\n\n")
		else:
			_add_output("❌ Specify malicious process name.\n\n")
	
	elif "firewall" in cmd:
		completed_tasks["blocked_c2"] = true
		_add_output("✅ Firewall rule added - C2 server blocked!\n\n")
	
	_check_phase_completion()


func _handle_eradication_command(cmd: String) -> void:
	if current_phase != Phase.ERADICATION and current_phase != Phase.COMPLETE:
		_add_output("⚠️ Contain the threat first!\n\n")
		return
	
	if cmd.begins_with("reg delete"):
		completed_tasks["removed_registry"] = true
		_add_output("✅ Registry key deleted - Persistence removed!\n\n")
	
	elif cmd.begins_with("del") and "appdata" in cmd:
		completed_tasks["deleted_files"] = true
		_add_output("✅ Malicious file deleted!\n\n")
	
	elif cmd.begins_with("schtasks"):
		_add_output("✅ Scheduled task removed!\n\n")
	
	_check_phase_completion()


func _check_phase_completion() -> void:
	match current_phase:
		Phase.DETECTION:
			if completed_tasks["detected_processes"] and completed_tasks["detected_network"]:
				score += 100
				await get_tree().create_timer(1.0).timeout
				_start_phase(Phase.CONTAINMENT)
		
		Phase.CONTAINMENT:
			if completed_tasks["killed_processes"]:
				score += 100
				await get_tree().create_timer(1.0).timeout
				_start_phase(Phase.ERADICATION)
		
		Phase.ERADICATION:
			if completed_tasks["removed_registry"] and completed_tasks["deleted_files"]:
				score += 150
				await get_tree().create_timer(1.0).timeout
				_start_phase(Phase.COMPLETE)
				
func _on_header_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _show_help() -> void:
	var help_text := """
📚 AVAILABLE COMMANDS:

DETECTION:
  tasklist               - List running processes
  netstat -ano           - Show network connections
  dir %appdata%          - Check AppData folder

CONTAINMENT:
  taskkill /F /IM [process.exe]  - Kill process
  netsh advfirewall...   - Block IP with firewall

ERADICATION:
  reg delete...          - Remove registry keys
  del /F /Q [file path]  - Delete malicious files
  schtasks /delete...    - Remove scheduled tasks

"""
	_add_output(help_text)


func _show_hint() -> void:
	hint_label.visible = true
	match current_phase:
		Phase.DETECTION:
			if !completed_tasks["detected_processes"]:
				hint_label.text = "💡 Hint: Type 'tasklist' to see running processes"
			elif !completed_tasks["detected_network"]:
				hint_label.text = "💡 Hint: Type 'netstat -ano' to check network connections"
		
		Phase.CONTAINMENT:
			if !completed_tasks["killed_processes"]:
				hint_label.text = "💡 Hint: Use 'taskkill /F /IM malware.exe' to stop the process"
		
		Phase.ERADICATION:
			if !completed_tasks["removed_registry"]:
				hint_label.text = "💡 Hint: Use 'reg delete' to remove persistence keys"
			elif !completed_tasks["deleted_files"]:
				hint_label.text = "💡 Hint: Use 'del /F /Q' to delete malicious files"


func _add_output(text: String) -> void:
	output_text.text += text
	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll := cmd_terminal.get_node("OutputScroll") as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# ============================================
# DEBRIEF
# ============================================
func _show_debrief() -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - start_time
	@warning_ignore("integer_division")
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	
	var time_bonus: int = max(0, 180 - int(elapsed))  # Bonus for completing under 3 min
	var final_score: int = score + time_bonus
	
	score_label.text = "SCORE: %d/1000" % final_score
	summary_label.text = """Commands used: %d
Time taken: %d:%02d
Malware removed successfully!

🏅 Grade: %s""" % [commands_used, minutes, seconds, _get_grade(final_score)]
	
	# Save tutorial result to TutorialManager
	var tutorial_id: String = get_tree().get_meta("tutorial_id", "intermediate_defense")
	var tutorial_mgr = get_node("/root/TutorialManager")
	tutorial_mgr.save_tutorial_result(tutorial_id, final_score, 1000)
	await tutorial_mgr.save_completed
	
	cmd_terminal.visible = false
	debrief_screen.visible = true


func _get_grade(final_score: int) -> String:
	if final_score >= 900:
		return "S-RANK: Cyber Expert! 🏆"
	elif final_score >= 750:
		return "A-RANK: Security Pro! 🥇"
	elif final_score >= 600:
		return "B-RANK: Good Work! 🥈"
	else:
		return "C-RANK: Keep Learning! 🥉"


# ============================================
# NAVIGATION
# ============================================
func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")
