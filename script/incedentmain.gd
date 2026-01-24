extends Control

# Game state variables
var current_stage = 0
var score = 0
var attempts = 0
var processes = []
var malicious_files = []
var registry_keys = []
var game_state = "tutorial"
var command_history = []

# UI references
@onready var terminal_output = $VBoxContainer/TerminalPanel/ScrollContainer/TerminalOutput
@onready var command_input = $VBoxContainer/CommandPanel/HBoxContainer/CommandInput
@onready var execute_button = $VBoxContainer/CommandPanel/HBoxContainer/ExecuteButton
@onready var stage_label = $VBoxContainer/HeaderPanel/HBoxContainer/StageLabel
@onready var score_label = $VBoxContainer/HeaderPanel/HBoxContainer/ScoreLabel
@onready var objective_label = $VBoxContainer/ObjectivePanel/ObjectiveLabel
@onready var tutorial_panel = $TutorialPanel
@onready var tutorial_text = $TutorialPanel/VBoxContainer/ScrollContainer/TutorialText
@onready var hint_button = $VBoxContainer/CommandPanel/HBoxContainer/HintButton
@onready var process_list = $VBoxContainer/SystemStatus/ProcessPanel/ProcessList
@onready var file_list = $VBoxContainer/SystemStatus/FilePanel/FileList
@onready var registry_list = $VBoxContainer/SystemStatus/RegistryPanel/RegistryList

# Stage definitions with detailed tutorials
var stages = [
	{
		"title": "Stage 1: Detection - Process Discovery",
		"objective": "List all running processes to identify suspicious activity",
		"command": "tasklist",
		"hint": "Use 'tasklist' to view all running processes",
		"auto_fill": true,
		"tutorial": """DETECTION PHASE - Understanding Process Enumeration

The 'tasklist' command is your first line of defense. It displays:
- Process names (executable files)
- Process IDs (PID) - unique identifiers
- Memory usage - how much RAM each process uses
- Session information

WHY THIS MATTERS:
Malware often disguises itself as legitimate processes but with slight variations.
Look for:
• Misspelled system processes (svchost32.exe vs svchost.exe)
• Unusual memory usage patterns
• Processes running from unexpected locations

REAL-WORLD TIP:
Legitimate svchost.exe runs from C:\\Windows\\System32, not from Temp folders!""",
		"challenge": "Identify which process looks suspicious based on its name"
	},
	{
		"title": "Stage 2: Detailed Analysis",
		"objective": "Get verbose information about processes including window titles",
		"command": "tasklist /v",
		"hint": "Add the /v flag for verbose output with more details",
		"auto_fill": true,
		"tutorial": """ANALYSIS PHASE - Verbose Process Information

The /v (verbose) flag provides critical additional information:
- Window titles (what the process is displaying)
- User accounts (who owns the process)
- CPU time (how long it's been running)
- Status information

COMMAND FLAGS EXPLAINED:
/v = verbose (detailed output)
/svc = shows services for each process
/fo = format output (TABLE, LIST, CSV)

INVESTIGATION TECHNIQUE:
Malware often runs with no window title or suspicious user accounts.
System processes typically run under SYSTEM or LOCAL SERVICE.""",
		"challenge": "Note the PID of any process that seems abnormal"
	},
	{
		"title": "Stage 3: Path Investigation",
		"objective": "Locate the executable path of suspicious process (PID: 4832)",
		"command": "wmic process where ProcessId=4832 get ExecutablePath",
		"hint": "Use WMIC to query process 4832's executable location",
		"auto_fill": false,
		"tutorial": """INVESTIGATION PHASE - WMIC Process Querying

WMIC (Windows Management Instrumentation Command) is powerful for:
- Querying system information
- Remote system management
- Detailed process analysis

COMMAND BREAKDOWN:
wmic process           → Target process objects
where ProcessId=4832   → Filter by specific PID
get ExecutablePath     → Retrieve the file location

OTHER USEFUL WMIC QUERIES:
• wmic process get Name,ProcessId,ParentProcessId
• wmic process where Name='malware.exe' get CommandLine
• wmic startup list full (check startup programs)

RED FLAGS:
Legitimate Windows processes run from System32 or Program Files.
Malware often hides in:
- C:\\Windows\\Temp
- C:\\Users\\[user]\\AppData
- Random folders with system-sounding names""",
		"challenge": "Determine if the process location is legitimate or malicious"
	},
	{
		"title": "Stage 4: Containment",
		"objective": "Terminate the malicious process before it spreads",
		"command": "taskkill /im svchost32.exe /f",
		"hint": "Use taskkill with /f to force terminate the process",
		"auto_fill": false,
		"tutorial": """CONTAINMENT PHASE - Process Termination

TASKKILL is critical for stopping malicious processes:

SYNTAX OPTIONS:
taskkill /im [imagename]   → Kill by process name
taskkill /pid [number]     → Kill by Process ID
taskkill /f                → Force termination
taskkill /t                → Terminate child processes too

WHEN TO USE /F (FORCE):
- Process doesn't respond to normal termination
- Malware is actively defending itself
- Critical incident response situations

WARNING:
Killing system processes can crash Windows!
Always verify the process is malicious before using /f.

ADVANCED TECHNIQUE:
Use /t flag to kill parent AND all child processes:
taskkill /im malware.exe /f /t

INCIDENT RESPONSE BEST PRACTICE:
1. Document the PID and process name
2. Capture memory dump if possible (procdump)
3. Terminate the process
4. Monitor for re-spawning""",
		"challenge": "Stop the malware before it exfiltrates more data"
	},
	{
		"title": "Stage 5: Eradication",
		"objective": "Delete the malicious executable from the file system",
		"command": "del C:\\Windows\\Temp\\svchost32.exe",
		"hint": "Use 'del' command to remove the malware file",
		"auto_fill": false,
		"tutorial": """ERADICATION PHASE - File Removal

The DEL command removes files from the system:

BASIC SYNTAX:
del [filename]         → Delete file
del /f [filename]      → Force delete read-only files
del /q [filename]      → Quiet mode (no confirmation)

FULL PATH REQUIRED:
Always specify complete path for critical deletions:
del C:\\Windows\\Temp\\malware.exe

ADVANCED DELETION:
For stubborn malware:
1. Take ownership: takeown /f file.exe
2. Grant permissions: icacls file.exe /grant administrators:F
3. Delete: del /f /q file.exe

FORENSICS NOTE:
In real incidents, DON'T delete immediately!
1. Create forensic copy (hash the file)
2. Submit to VirusTotal or sandbox
3. Document IoCs (Indicators of Compromise)
4. Then safely remove

ALTERNATIVE TOOLS:
• SDelete (secure deletion, overwrites data)
• PowerShell Remove-Item with -Force
• Autoruns (find and disable persistence)""",
		"challenge": "Remove the malware without damaging system files"
	},
	{
		"title": "Stage 6: Persistence Removal",
		"objective": "Remove malware from Windows startup registry",
		"command": "reg delete HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v SecurityUpdate /f",
		"hint": "Use 'reg delete' to remove the malicious registry entry",
		"auto_fill": false,
		"tutorial": """PERSISTENCE REMOVAL - Registry Cleanup

Malware achieves persistence through registry keys that auto-start programs.

REGISTRY COMMAND BASICS:
reg query [keypath]              → View registry values
reg add [keypath] /v [name]      → Add new value
reg delete [keypath] /v [name]   → Delete specific value
/f flag                          → Force without confirmation

COMMON PERSISTENCE LOCATIONS:
HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run
HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run
HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce
HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce

HKCU vs HKLM:
HKCU (Current User) → Affects only current user
HKLM (Local Machine) → Affects all users (requires admin)

COMMAND BREAKDOWN:
reg delete                                          → Delete command
HKCU\\Software\\...\\Run                           → Registry path
/v SecurityUpdate                                   → Value name to delete
/f                                                  → Force (no prompt)

OTHER PERSISTENCE MECHANISMS:
• Scheduled Tasks (schtasks /query)
• Services (sc query)
• WMI Event Subscriptions
• Startup Folder (shell:startup)

REAL-WORLD EXAMPLE:
Emotet malware creates Run keys like:
HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\[random]

BEST PRACTICE:
Always check BOTH HKCU and HKLM locations!""",
		"challenge": "Prevent malware from restarting on system reboot"
	},
	{
		"title": "Stage 7: Verification & Validation",
		"objective": "Confirm the system is clean and no traces remain",
		"command": "tasklist",
		"hint": "Re-run tasklist to verify malicious process is gone",
		"auto_fill": false,
		"tutorial": """VERIFICATION PHASE - Final System Check

The final and crucial step: VERIFY YOUR WORK!

VERIFICATION CHECKLIST:
✓ No malicious processes running (tasklist)
✓ Malicious files deleted (dir C:\\Windows\\Temp)
✓ Registry cleaned (reg query ...\\Run)
✓ No unexpected network connections (netstat -ano)
✓ No scheduled tasks (schtasks /query)

ADDITIONAL VERIFICATION COMMANDS:
netstat -ano              → Check active connections
schtasks /query /fo LIST  → List all scheduled tasks
sc query                  → Check services
wmic startup get caption,command  → Startup items

POST-INCIDENT ACTIONS:
1. Document everything (timeline, commands, findings)
2. Update antivirus definitions
3. Run full system scan
4. Monitor for re-infection (24-48 hours)
5. Review logs (Event Viewer)
6. Patch vulnerabilities

INCIDENT REPORT SHOULD INCLUDE:
• Initial indicators of compromise
• Malware name/family
• Persistence mechanisms used
• Files and registry keys affected
• Remediation steps taken
• Recommendations to prevent recurrence

FINAL CHECK:
If system is clean, you've successfully completed incident response!
If anything seems off, investigate further - malware often has multiple components.""",
		"challenge": "Ensure complete eradication with no remaining threats"
	}
]

func _ready():
	initialize_system()
	update_ui()
	command_input.grab_focus()
	execute_button.pressed.connect(_on_execute_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	$TutorialPanel/VBoxContainer/CloseButton.pressed.connect(_on_tutorial_close)
	command_input.text_submitted.connect(_on_command_submitted)
	
	# Show initial tutorial
	show_tutorial()

# Helper function to pad strings (replacement for pad_align)
func pad_string(text: String, length: int, align_right: bool = false) -> String:
	var current_length = text.length()
	if current_length >= length:
		return text
	
	var padding = " ".repeat(length - current_length)
	if align_right:
		return padding + text
	else:
		return text + padding

func initialize_system():
	processes = [
		{"name": "System", "pid": 4, "memory": "8 K", "status": "Running", "malware": false},
		{"name": "csrss.exe", "pid": 456, "memory": "3,892 K", "status": "Running", "malware": false},
		{"name": "winlogon.exe", "pid": 512, "memory": "2,144 K", "status": "Running", "malware": false},
		{"name": "services.exe", "pid": 624, "memory": "4,256 K", "status": "Running", "malware": false},
		{"name": "lsass.exe", "pid": 636, "memory": "3,128 K", "status": "Running", "malware": false},
		{"name": "svchost.exe", "pid": 892, "memory": "5,432 K", "status": "Running", "malware": false},
		{"name": "svchost32.exe", "pid": 4832, "memory": "12,844 K", "status": "Running", "malware": true},
		{"name": "explorer.exe", "pid": 1456, "memory": "45,232 K", "status": "Running", "malware": false},
		{"name": "chrome.exe", "pid": 2348, "memory": "98,432 K", "status": "Running", "malware": false},
	]
	
	malicious_files = ["C:\\Windows\\Temp\\svchost32.exe"]
	registry_keys = ["HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\SecurityUpdate"]
	
	add_terminal_line("=== INCIDENT RESPONSE TERMINAL ===", Color.CYAN)
	add_terminal_line("⚠️ ALERT: Suspicious network activity detected!", Color.YELLOW)
	add_terminal_line("⚠️ Multiple outbound connections to IP: 45.142.212.61", Color.YELLOW)
	add_terminal_line("⚠️ Data exfiltration in progress - IMMEDIATE ACTION REQUIRED", Color.RED)
	add_terminal_line("Your mission: Investigate and neutralize the threat\n", Color.WHITE)

func update_ui():
	stage_label.text = "Stage %d/%d: %s" % [current_stage + 1, stages.size(), stages[current_stage]["title"]]
	score_label.text = "Score: %d | Accuracy: %d%%" % [score, get_accuracy()]
	objective_label.text = "OBJECTIVE: " + stages[current_stage]["objective"]
	
	if stages[current_stage]["auto_fill"]:
		command_input.text = stages[current_stage]["command"]
		command_input.editable = true
	else:
		command_input.text = ""
		command_input.editable = true
	
	# Update system status
	update_system_status()

func update_system_status():
	process_list.text = "Processes: %d" % processes.size()
	if processes.any(func(p): return p["malware"]):
		process_list.text += " ⚠️ THREAT"
		process_list.modulate = Color.RED
	else:
		process_list.modulate = Color.GREEN
	
	file_list.text = "Malicious Files: %d" % malicious_files.size()
	file_list.modulate = Color.RED if malicious_files.size() > 0 else Color.GREEN
	
	registry_list.text = "Bad Registry: %d" % registry_keys.size()
	registry_list.modulate = Color.RED if registry_keys.size() > 0 else Color.GREEN

func _on_execute_pressed():
	execute_command(command_input.text)

func _on_command_submitted(text):
	execute_command(text)

func execute_command(cmd: String):
	if cmd.strip_edges() == "":
		return
	
	attempts += 1
	var trimmed = cmd.strip_edges().to_lower()
	var expected = stages[current_stage]["command"].to_lower()
	
	add_terminal_line("C:\\> " + cmd, Color.WHITE)
	
	if trimmed == expected or is_valid_variant(trimmed, expected):
		handle_correct_command(cmd)
	else:
		handle_incorrect_command(cmd)
	
	command_input.text = ""
	command_history.append(cmd)

func is_valid_variant(input: String, expected: String) -> bool:
	match current_stage:
		2:  # WMIC query
			return "wmic" in input and "4832" in input and "executablepath" in input
		3:  # Taskkill
			return "taskkill" in input and "svchost32" in input and "/f" in input
		4:  # Delete file
			return "del" in input and "svchost32.exe" in input
		5:  # Registry delete
			return "reg delete" in input and "run" in input and "/f" in input
	return false

func handle_correct_command(cmd: String):
	var stage_data = stages[current_stage]
	
	match current_stage:
		0:  # tasklist
			add_terminal_line("Image Name                     PID Session Name     Mem Usage", Color.GRAY)
			add_terminal_line("========================= ======== ================ ============", Color.GRAY)
			for p in processes:
				var line = "%s %s Console %s" % [pad_string(p["name"], 25), 
												  pad_string(str(p["pid"]), 8, true),
												  pad_string(p["memory"], 12, true)]
				var color = Color.RED if p["malware"] else Color.WHITE
				add_terminal_line(line, color)
			add_terminal_line("\n✓ Process list retrieved successfully!", Color.GREEN)
			add_terminal_line("📋 NOTICE: Process 'svchost32.exe' looks suspicious!", Color.YELLOW)
			add_terminal_line("   Real svchost.exe has no number. This is likely malware.\n", Color.YELLOW)
		
		1:  # tasklist /v
			add_terminal_line("Image Name           PID  Status      User Name     Window Title", Color.GRAY)
			add_terminal_line("svchost32.exe       4832  Running     SYSTEM        N/A", Color.RED)
			add_terminal_line("explorer.exe        1456  Running     User          Program Manager", Color.WHITE)
			add_terminal_line("...", Color.GRAY)
			add_terminal_line("\n✓ Detailed process information retrieved!", Color.GREEN)
			add_terminal_line("⚠️ CRITICAL: PID 4832 making connections to 45.142.212.61:443", Color.RED)
			add_terminal_line("   Location: Unknown - requires investigation\n", Color.YELLOW)
		
		2:  # wmic query
			add_terminal_line("ExecutablePath", Color.GRAY)
			add_terminal_line("C:\\Windows\\Temp\\svchost32.exe", Color.RED)
			add_terminal_line("\n✓ Malware location identified!", Color.GREEN)
			add_terminal_line("⚠️ CONFIRMED MALWARE: This is NOT a legitimate Windows directory!", Color.RED)
			add_terminal_line("   Real svchost.exe is always in C:\\Windows\\System32\\", Color.YELLOW)
			add_terminal_line("   This is a TROJAN attempting to appear legitimate!\n", Color.RED)
		
		3:  # taskkill
			processes = processes.filter(func(p): return !p["malware"])
			add_terminal_line("SUCCESS: The process 'svchost32.exe' with PID 4832 has been terminated.", Color.WHITE)
			add_terminal_line("\n✓ Malicious process TERMINATED!", Color.GREEN)
			add_terminal_line("⚡ Quick containment prevented further data theft", Color.GREEN)
			add_terminal_line("   Network connections to C2 server severed\n", Color.CYAN)
		
		4:  # del
			malicious_files.clear()
			add_terminal_line("✓ File deleted successfully!", Color.GREEN)
			add_terminal_line("   C:\\Windows\\Temp\\svchost32.exe has been removed from disk", Color.WHITE)
			add_terminal_line("   MD5: d41d8cd98f00b204e9800998ecf8427e", Color.GRAY)
			add_terminal_line("   File was a variant of Emotet banking trojan\n", Color.YELLOW)
		
		5:  # reg delete
			registry_keys.clear()
			add_terminal_line("The operation completed successfully.", Color.WHITE)
			add_terminal_line("\n✓ Registry persistence REMOVED!", Color.GREEN)
			add_terminal_line("🔒 Malware will NOT restart on system boot", Color.GREEN)
			add_terminal_line("   Deleted: HKCU\\...\\Run\\SecurityUpdate\n", Color.CYAN)
		
		6:  # verification
			var clean_procs = processes.filter(func(p): return !p["malware"]).slice(0, 5)
			for p in clean_procs:
				add_terminal_line("%s %s" % [pad_string(p["name"], 25), 
											  pad_string(str(p["pid"]), 8, true)], Color.WHITE)
			add_terminal_line("\n✓ System verification COMPLETE!", Color.GREEN)
			add_terminal_line("🎯 No malicious processes detected", Color.GREEN)
			add_terminal_line("🎯 No malicious files found", Color.GREEN)
			add_terminal_line("🎯 No persistence mechanisms active", Color.GREEN)
			add_terminal_line("\n🎉 INCIDENT RESOLVED - System is CLEAN!", Color.CYAN)
			add_terminal_line("🏆 Incident Response completed successfully!\n", Color.YELLOW)
			game_state = "complete"
	
	# Award points
	var points = max(100 - (attempts - current_stage - 1) * 20, 50)
	score += points
	add_terminal_line("+ %d points earned!\n" % points, Color.YELLOW)
	
	update_system_status()
	
	if current_stage < stages.size() - 1:
		await get_tree().create_timer(2.0).timeout
		current_stage += 1
		add_terminal_line("=== %s ===" % stages[current_stage]["title"], Color.MAGENTA)
		add_terminal_line("OBJECTIVE: %s\n" % stages[current_stage]["objective"], Color.CYAN)
		update_ui()
		show_tutorial()
	else:
		show_completion_screen()

func handle_incorrect_command(cmd: String):
	add_terminal_line("'%s' is not recognized as an internal or external command." % cmd, Color.RED)
	add_terminal_line("operable program or batch file.\n", Color.RED)
	add_terminal_line("💡 HINT: %s" % stages[current_stage]["hint"], Color.CYAN)
	add_terminal_line("   Try typing the exact command syntax\n", Color.GRAY)

func show_tutorial():
	var tutorial_content = stages[current_stage]["tutorial"]
	# Format the text for better display
	tutorial_text.text = tutorial_content
	tutorial_text.scroll_to_line(0)  # Scroll to top
	tutorial_panel.visible = true

func _on_tutorial_close():
	tutorial_panel.visible = false
	command_input.grab_focus()

func _on_hint_pressed():
	show_tutorial()

func show_completion_screen():
	add_terminal_line("\n" + "=".repeat(50), Color.CYAN)
	add_terminal_line("INCIDENT RESPONSE MISSION COMPLETE", Color.GREEN)
	add_terminal_line("=".repeat(50), Color.CYAN)
	add_terminal_line("\nFINAL SCORE: %d points" % score, Color.YELLOW)
	add_terminal_line("ACCURACY: %d%%" % get_accuracy(), Color.YELLOW)
	add_terminal_line("ATTEMPTS: %d" % attempts, Color.WHITE)
	add_terminal_line("\n📊 THREAT ANALYSIS REPORT:", Color.CYAN)
	add_terminal_line("   Threat Type: Emotet Banking Trojan", Color.WHITE)
	add_terminal_line("   Severity: CRITICAL", Color.RED)
	add_terminal_line("   Vector: Phishing email attachment", Color.WHITE)
	add_terminal_line("   Actions Taken: Process killed, file removed, persistence deleted", Color.GREEN)
	add_terminal_line("\n✓ You've successfully completed incident response training!", Color.GREEN)
	add_terminal_line("  You're now ready for real-world cybersecurity operations.\n", Color.CYAN)

func add_terminal_line(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	terminal_output.add_child(label)
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll = $VBoxContainer/TerminalPanel/ScrollContainer
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func get_accuracy() -> int:
	if attempts == 0:
		return 100
	return int((float(current_stage + 1) / float(attempts)) * 100)

func _input(event):
	if event is InputEventKey and event.pressed:
		# F1 - Show help/tutorial
		if event.keycode == KEY_F1:
			show_tutorial()
		# F5 - Restart game when complete
		elif event.keycode == KEY_F5 and game_state == "complete":
			get_tree().reload_current_scene()
		# ESC - Close tutorial
		elif event.keycode == KEY_ESCAPE and tutorial_panel.visible:
			tutorial_panel.visible = false
