extends Control

# Game state variables
var current_stage = 0
var score = 0
var attempts = 0
var processes = []
var malicious_files = []
var registry_keys = []
var game_state = "menu"  # menu, tutorial, challenge, complete
var command_history = []
var tutorial_mode = true
var tutorial_step = 0
var current_tutorial_steps = []
var tutorial_completed = false

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
@onready var tutorial_progress = $TutorialPanel/VBoxContainer/ProgressLabel
@onready var next_step_button = $TutorialPanel/VBoxContainer/NextStepButton
@onready var auto_fill_button = $TutorialPanel/VBoxContainer/AutoFillButton
@onready var mode_label = $VBoxContainer/HeaderPanel/HBoxContainer/ModeLabel

# Mode selection menu
@onready var mode_selection_panel = $ModeSelectionPanel
@onready var tutorial_mode_button = $ModeSelectionPanel/VBoxContainer/TutorialModeButton
@onready var challenge_mode_button = $ModeSelectionPanel/VBoxContainer/ChallengeModeButton

# Tutorial step definitions for each stage
var tutorial_steps_data = {
	0: [  # Stage 1: tasklist
		{
			"title": "Welcome to Incident Response Training!",
			"text": """🎓 WELCOME TO THE CMD INCIDENT RESPONSE SIMULATOR!

You are a cybersecurity analyst who just received an URGENT alert:
⚠️ Suspicious network activity detected
⚠️ Possible malware infection
⚠️ Data exfiltration in progress

Your mission is to investigate and neutralize the threat using Windows command-line tools.

This tutorial will guide you through EVERY STEP of the incident response process.

Click 'Next Step' to begin your training!""",
			"action": "none"
		},
		{
			"title": "Understanding the Threat",
			"text": """📋 CURRENT SITUATION:

Our monitoring systems detected:
• Multiple outbound connections to suspicious IP: 45.142.212.61
• Unusual process behavior
• Potential data theft in progress

🎯 FIRST STEP: PROCESS DISCOVERY

Before we can stop the threat, we need to see what's running on the system.

The 'tasklist' command shows all active processes:
• Process names (program executables)
• Process IDs (PID) - unique numbers for each process
• Memory usage
• Session information

Click 'Next Step' to learn the exact command.""",
			"action": "none"
		},
		{
			"title": "Running Your First Command",
			"text": """⌨️ TYPE THIS COMMAND:

tasklist

This command will display all running processes on the system.

📝 WHAT TO LOOK FOR:
Look for processes with suspicious names. Malware often disguises itself as legitimate Windows processes but with small differences:
• svchost32.exe ❌ (FAKE - has a number)
• svchost.exe ✅ (REAL - no number)

💡 TIP: You can click 'Auto-Fill Command' to automatically fill in the correct command, or type it yourself for practice!

When ready, click the ⚡ EXECUTE button or press Enter to run the command.""",
			"action": "command",
			"command": "tasklist"
		}
	],
	1: [  # Stage 2: tasklist /v
		{
			"title": "Great! Process Found",
			"text": """✅ EXCELLENT WORK!

You successfully listed all running processes and identified a suspicious one:
🔴 svchost32.exe (PID: 4832)

This process name is VERY suspicious because:
• Real Windows process is 'svchost.exe' (no number)
• The '32' suffix is a common malware trick
• It's using unusually high memory (12,844 K)

🎯 NEXT STEP: GET MORE DETAILS

We need verbose (detailed) information about all processes to understand what svchost32.exe is doing.

Click 'Next Step' to continue...""",
			"action": "none"
		},
		{
			"title": "Using Command Flags",
			"text": """📚 LEARNING: COMMAND FLAGS

Most Windows commands accept 'flags' or 'switches' that modify their behavior.
Flags start with a forward slash (/)

For tasklist:
• /v = verbose (detailed information)
• /svc = show services
• /fo = format output

⌨️ TYPE THIS COMMAND:

tasklist /v

The /v flag will show:
• Window titles
• User accounts running each process
• CPU time
• Detailed status

This helps identify malware that's hiding or running with suspicious privileges.

Click 'Auto-Fill Command' or type it yourself, then click EXECUTE.""",
			"action": "command",
			"command": "tasklist /v"
		}
	],
	2: [  # Stage 3: wmic process
		{
			"title": "Confirming the Threat",
			"text": """🔍 ANALYSIS COMPLETE!

The verbose output confirmed our suspicions:
• Process: svchost32.exe
• PID: 4832
• User: SYSTEM (has high privileges!)
• Making network connections to suspicious IP

⚠️ CRITICAL FINDING:
This malware is actively communicating with a Command & Control (C2) server at 45.142.212.61:443

🎯 NEXT STEP: LOCATE THE MALWARE FILE

Before we terminate the process, we need to find WHERE the malware executable file is stored on disk.

Click 'Next Step' to learn how...""",
			"action": "none"
		},
		{
			"title": "Using WMIC to Query Processes",
			"text": """📚 ADVANCED TOOL: WMIC

WMIC (Windows Management Instrumentation Command) is a powerful tool for querying system information.

⌨️ TYPE THIS COMMAND:

wmic process where ProcessId=4832 get ExecutablePath

COMMAND BREAKDOWN:
• wmic process = Query process information
• where ProcessId=4832 = Filter by our suspicious PID
• get ExecutablePath = Show the file location

🎯 WHY THIS MATTERS:
Legitimate Windows processes run from:
✅ C:\\Windows\\System32\\
✅ C:\\Program Files\\

Malware often hides in:
❌ C:\\Windows\\Temp\\
❌ C:\\Users\\...\\AppData\\
❌ Random temporary folders

Let's find out where svchost32.exe is hiding!

Type the command or use Auto-Fill, then EXECUTE.""",
			"action": "command",
			"command": "wmic process where ProcessId=4832 get ExecutablePath"
		}
	],
	3: [  # Stage 4: taskkill
		{
			"title": "Malware Location Confirmed!",
			"text": """🚨 MALWARE DETECTED:

ExecutablePath: C:\\Windows\\Temp\\svchost32.exe

This CONFIRMS it's malware because:
❌ Real svchost.exe is in C:\\Windows\\System32\\
❌ The Temp folder is a common malware hiding spot
❌ Legitimate system processes NEVER run from Temp

🎯 CONTAINMENT PHASE

Now we need to STOP the malware immediately before it:
• Steals more data
• Spreads to other systems
• Downloads additional malware
• Damages files

Click 'Next Step' to learn how to terminate malicious processes...""",
			"action": "none"
		},
		{
			"title": "Terminating Malicious Processes",
			"text": """⚡ CONTAINMENT: KILL THE PROCESS

The 'taskkill' command terminates (stops) running processes.

⌨️ TYPE THIS COMMAND:

taskkill /im svchost32.exe /f

COMMAND BREAKDOWN:
• taskkill = Terminate process command
• /im svchost32.exe = Identify by image name (process name)
• /f = FORCE termination (don't ask for confirmation)

⚠️ THE /f FLAG IS CRITICAL:
• Normal termination might fail with malware
• Malware often resists being stopped
• /f overrides any resistance

ALTERNATIVE SYNTAX:
You could also use: taskkill /pid 4832 /f
(Terminates by Process ID instead of name)

🎯 IMMEDIATE ACTION REQUIRED:
Every second counts! The malware is actively stealing data.

Type the command or use Auto-Fill, then EXECUTE NOW!""",
			"action": "command",
			"command": "taskkill /im svchost32.exe /f"
		}
	],
	4: [  # Stage 5: del
		{
			"title": "Process Terminated Successfully!",
			"text": """✅ CONTAINMENT SUCCESSFUL!

The malicious process has been stopped:
• Process svchost32.exe (PID 4832) terminated
• Network connections to C2 server severed
• Data exfiltration halted

🎯 ERADICATION PHASE

But we're NOT done yet! The malware file still exists on disk.

If we reboot or the malware has auto-restart mechanisms, it could:
• Start running again
• Re-establish C2 connections
• Continue its malicious activity

We need to DELETE the malware file permanently.

Click 'Next Step' to continue...""",
			"action": "none"
		},
		{
			"title": "Deleting Malicious Files",
			"text": """🗑️ FILE DELETION

The 'del' command removes files from the file system.

⌨️ TYPE THIS COMMAND:

del C:\\Windows\\Temp\\svchost32.exe

COMMAND BREAKDOWN:
• del = Delete file command
• C:\\Windows\\Temp\\svchost32.exe = Full path to malware

⚠️ IMPORTANT NOTES:
• Always use the FULL PATH when deleting critical files
• Double-check you're deleting the RIGHT file
• Deleting wrong system files can break Windows!

ADVANCED OPTIONS:
• /f = Force delete read-only files
• /q = Quiet (no confirmation prompt)

🔬 IN REAL INCIDENTS:
Before deleting, you should:
1. Create a copy for forensic analysis
2. Calculate file hash (MD5/SHA256)
3. Submit to VirusTotal
4. Document everything
5. THEN delete

For this training, we'll proceed directly to deletion.

Type the command or use Auto-Fill, then EXECUTE.""",
			"action": "command",
			"command": "del C:\\Windows\\Temp\\svchost32.exe"
		}
	],
	5: [  # Stage 6: reg delete
		{
			"title": "Malware File Deleted!",
			"text": """✅ FILE REMOVED!

The malware executable has been deleted from disk:
• File: C:\\Windows\\Temp\\svchost32.exe
• Status: Permanently removed
• Hash: d41d8cd98f00b204e9800998ecf8427e
• Identified as: Emotet banking trojan variant

🎯 PERSISTENCE REMOVAL PHASE

There's one more critical step!

Sophisticated malware creates PERSISTENCE MECHANISMS to survive reboots.

Common persistence methods:
• Registry Run keys (auto-start programs)
• Scheduled tasks
• Services
• Startup folder shortcuts

Our investigation revealed this malware created a registry entry.

Click 'Next Step' to learn how to remove it...""",
			"action": "none"
		},
		{
			"title": "Understanding Registry Persistence",
			"text": """📚 WINDOWS REGISTRY PERSISTENCE

The Windows Registry contains settings that control what programs run automatically.

COMMON PERSISTENCE LOCATIONS:
HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run
HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run

HKCU = Current User (affects one user)
HKLM = Local Machine (affects all users)

⚠️ MALWARE FOUND IN REGISTRY:
Key: HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run
Value: SecurityUpdate
Data: C:\\Windows\\Temp\\svchost32.exe

This means the malware would restart every time the user logs in!

Click 'Next Step' to learn the deletion command...""",
			"action": "none"
		},
		{
			"title": "Removing Registry Persistence",
			"text": """🔧 REGISTRY DELETION

The 'reg delete' command removes registry keys and values.

⌨️ TYPE THIS COMMAND:

reg delete HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v SecurityUpdate /f

COMMAND BREAKDOWN:
• reg delete = Registry deletion command
• HKCU\\...\\Run = Path to the Run key
• /v SecurityUpdate = Value name to delete
• /f = Force (no confirmation prompt)

⚠️ BE EXTREMELY CAREFUL:
• Wrong registry edits can break Windows
• Always verify the path before deleting
• The /f flag skips confirmation - use wisely

OTHER USEFUL REGISTRY COMMANDS:
• reg query [path] = View registry values
• reg add [path] /v [name] /d [data] = Add value
• reg export [path] [file] = Backup registry

🎯 FINAL PERSISTENCE REMOVAL:
This command will prevent the malware from auto-starting on reboot.

Type the command or use Auto-Fill, then EXECUTE.""",
			"action": "command",
			"command": "reg delete HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v SecurityUpdate /f"
		}
	],
	6: [  # Stage 7: verification
		{
			"title": "Persistence Removed!",
			"text": """✅ REGISTRY CLEANED!

The malware's persistence mechanism has been removed:
• Registry key deleted successfully
• Malware will NOT restart on reboot
• System startup is now clean

🎯 VERIFICATION & VALIDATION PHASE

This is the MOST IMPORTANT step that many responders forget!

You must VERIFY that:
✓ No malicious processes are running
✓ No malicious files remain
✓ No persistence mechanisms are active
✓ System is truly clean

"Trust, but verify" is the golden rule of incident response.

Click 'Next Step' to perform final verification...""",
			"action": "none"
		},
		{
			"title": "Final System Verification",
			"text": """🔍 COMPREHENSIVE SYSTEM CHECK

Let's verify the system is completely clean.

⌨️ TYPE THIS COMMAND:

tasklist

Yes, we're running tasklist again! This time we're checking:
• The malicious svchost32.exe is GONE
• Only legitimate processes remain
• No new suspicious processes appeared

COMPLETE VERIFICATION CHECKLIST:
✓ Process check (tasklist)
✓ File system check (dir C:\\Windows\\Temp)
✓ Registry check (reg query ...\\Run)
✓ Network check (netstat -ano)
✓ Scheduled tasks (schtasks /query)

📊 POST-INCIDENT ACTIONS:
After verification, you should:
1. Document everything (timeline, IoCs)
2. Update antivirus definitions
3. Run full system scan
4. Monitor for 24-48 hours
5. Review security logs
6. Patch vulnerabilities
7. Create incident report

For this training, we'll just verify processes.

Type the command or use Auto-Fill, then EXECUTE.""",
			"action": "command",
			"command": "tasklist"
		}
	]
}

# Stage definitions
var stages = [
	{
		"title": "Stage 1: Detection - Process Discovery",
		"objective": "List all running processes to identify suspicious activity",
		"command": "tasklist",
		"hint": "Use 'tasklist' to view all running processes"
	},
	{
		"title": "Stage 2: Detailed Analysis",
		"objective": "Get verbose information about processes",
		"command": "tasklist /v",
		"hint": "Add the /v flag for verbose output"
	},
	{
		"title": "Stage 3: Path Investigation",
		"objective": "Locate the executable path of suspicious process (PID: 4832)",
		"command": "wmic process where ProcessId=4832 get ExecutablePath",
		"hint": "Use WMIC to query process 4832's location"
	},
	{
		"title": "Stage 4: Containment",
		"objective": "Terminate the malicious process",
		"command": "taskkill /im svchost32.exe /f",
		"hint": "Use taskkill with /f to force terminate"
	},
	{
		"title": "Stage 5: Eradication",
		"objective": "Delete the malicious executable",
		"command": "del C:\\Windows\\Temp\\svchost32.exe",
		"hint": "Use 'del' to remove the malware file"
	},
	{
		"title": "Stage 6: Persistence Removal",
		"objective": "Remove malware from registry startup",
		"command": "reg delete HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v SecurityUpdate /f",
		"hint": "Use 'reg delete' to remove the registry entry"
	},
	{
		"title": "Stage 7: Verification",
		"objective": "Confirm the system is clean",
		"command": "tasklist",
		"hint": "Re-run tasklist to verify"
	}
]

func _ready():
	# Connect mode selection buttons
	tutorial_mode_button.pressed.connect(_on_tutorial_mode_selected)
	challenge_mode_button.pressed.connect(_on_challenge_mode_selected)
	
	execute_button.pressed.connect(_on_execute_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	next_step_button.pressed.connect(_on_next_step_pressed)
	auto_fill_button.pressed.connect(_on_auto_fill_pressed)
	command_input.text_submitted.connect(_on_command_submitted)
	
	# Show mode selection
	show_mode_selection()

func show_mode_selection():
	mode_selection_panel.visible = true
	$VBoxContainer.visible = false

func _on_tutorial_mode_selected():
	tutorial_mode = true
	game_state = "tutorial"
	mode_selection_panel.visible = false
	$VBoxContainer.visible = true
	
	initialize_system()
	update_ui()
	command_input.grab_focus()
	
	# Show hint button in tutorial mode
	hint_button.visible = true
	mode_label.text = "MODE: Tutorial"
	mode_label.modulate = Color.YELLOW
	
	# Start tutorial
	start_tutorial()

func _on_challenge_mode_selected():
	tutorial_mode = false
	game_state = "challenge"
	mode_selection_panel.visible = false
	$VBoxContainer.visible = true
	
	initialize_system()
	update_ui()
	command_input.grab_focus()
	
	# Hide hint button in challenge mode
	hint_button.visible = false
	mode_label.text = "MODE: Challenge"
	mode_label.modulate = Color.RED
	
	add_terminal_line("🎯 CHALLENGE MODE - No hints available!", Color.RED)
	add_terminal_line("Use your knowledge to complete the incident response!\n", Color.YELLOW)

func start_tutorial():
	tutorial_step = 0
	current_tutorial_steps = tutorial_steps_data[current_stage]
	show_current_tutorial_step()

func show_current_tutorial_step():
	if !tutorial_mode:
		return
		
	if tutorial_step >= current_tutorial_steps.size():
		tutorial_panel.visible = false
		return
	
	var step = current_tutorial_steps[tutorial_step]
	tutorial_text.text = "[b][color=cyan]" + step["title"] + "[/color][/b]\n\n" + step["text"]
	tutorial_progress.text = "Tutorial Step %d/%d" % [tutorial_step + 1, current_tutorial_steps.size()]
	
	# Show/hide buttons based on step type
	if step["action"] == "command":
		next_step_button.text = "I understand, let me try the command →"
		auto_fill_button.visible = true
	else:
		next_step_button.text = "Next Step →"
		auto_fill_button.visible = false
	
	tutorial_panel.visible = true
	tutorial_text.scroll_to_line(0)

func _on_next_step_pressed():
	var step = current_tutorial_steps[tutorial_step]
	
	if step["action"] == "command":
		# Close tutorial and let player execute command
		tutorial_panel.visible = false
		command_input.grab_focus()
	else:
		# Move to next tutorial step
		tutorial_step += 1
		show_current_tutorial_step()

func _on_auto_fill_pressed():
	var step = current_tutorial_steps[tutorial_step]
	if step["action"] == "command":
		command_input.text = step["command"]
		tutorial_panel.visible = false
		command_input.grab_focus()

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
			if tutorial_mode:
				add_terminal_line("📋 NOTICE: Process 'svchost32.exe' looks suspicious!", Color.YELLOW)
		
		1:  # tasklist /v
			add_terminal_line("Image Name           PID  Status      User Name     Window Title", Color.GRAY)
			add_terminal_line("svchost32.exe       4832  Running     SYSTEM        N/A", Color.RED)
			add_terminal_line("explorer.exe        1456  Running     User          Program Manager", Color.WHITE)
			add_terminal_line("...", Color.GRAY)
			add_terminal_line("\n✓ Detailed information retrieved!", Color.GREEN)
			if tutorial_mode:
				add_terminal_line("⚠️ PID 4832 making connections to 45.142.212.61:443", Color.RED)
		
		2:  # wmic query
			add_terminal_line("ExecutablePath", Color.GRAY)
			add_terminal_line("C:\\Windows\\Temp\\svchost32.exe", Color.RED)
			add_terminal_line("\n✓ Malware location identified!", Color.GREEN)
			if tutorial_mode:
				add_terminal_line("⚠️ This is NOT a legitimate directory!", Color.RED)
		
		3:  # taskkill
			processes = processes.filter(func(p): return !p["malware"])
			add_terminal_line("SUCCESS: Process terminated.", Color.WHITE)
			add_terminal_line("\n✓ Malicious process STOPPED!", Color.GREEN)
		
		4:  # del
			malicious_files.clear()
			add_terminal_line("✓ File deleted successfully!", Color.GREEN)
		
		5:  # reg delete
			registry_keys.clear()
			add_terminal_line("The operation completed successfully.", Color.WHITE)
			add_terminal_line("\n✓ Registry persistence REMOVED!", Color.GREEN)
		
		6:  # verification
			var clean_procs = processes.filter(func(p): return !p["malware"]).slice(0, 5)
			for p in clean_procs:
				add_terminal_line("%s %s" % [pad_string(p["name"], 25), 
											  pad_string(str(p["pid"]), 8, true)], Color.WHITE)
			add_terminal_line("\n✓ System verification COMPLETE!", Color.GREEN)
			add_terminal_line("🎉 INCIDENT RESOLVED!", Color.CYAN)
			game_state = "complete"
	
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
		
		# Only show tutorial in tutorial mode
		if tutorial_mode:
			tutorial_step = 0
			current_tutorial_steps = tutorial_steps_data[current_stage]
			show_current_tutorial_step()
	else:
		show_completion_screen()

func handle_incorrect_command(cmd: String):
	add_terminal_line("'%s' is not the expected command." % cmd, Color.RED)
	
	# Only show hints in tutorial mode
	if tutorial_mode:
		add_terminal_line("💡 HINT: %s" % stages[current_stage]["hint"], Color.CYAN)
		add_terminal_line("   Press F1 to see the full tutorial again\n", Color.GRAY)
	else:
		add_terminal_line("⚠️ Incorrect command. Think carefully about what's needed.\n", Color.YELLOW)

func _on_hint_pressed():
	if tutorial_mode:
		show_current_tutorial_step()

func show_completion_screen():
	add_terminal_line("\n" + "=".repeat(50), Color.CYAN)
	
	var accuracy = get_accuracy()
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var base_xp = 80  # Base XP for completing all stages
	var stage_xp = (current_stage + 1) * 10  # 10 XP per stage completed
	var accuracy_xp = int((accuracy / 100.0) * 50)  # Up to 50 XP from accuracy
	var score_xp = int((score / 1000.0) * 20)  # Up to 20 XP from score
	var total_xp_earned = base_xp + stage_xp + accuracy_xp + score_xp
	
	print("[CMD Defender] 🏆 Completion! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Stage XP: %d (stages %d)" % [stage_xp, current_stage + 1])
	print("  Accuracy XP: %d (accuracy %d%%)" % [accuracy_xp, accuracy])
	print("  Score XP: %d (score %d)" % [score_xp, score])
	print("  Total XP: %d" % total_xp_earned)
	
	var xp_awarded = TutorialManager.award_minigame_xp("cmd_defender", total_xp_earned, score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	
	if tutorial_mode:
		add_terminal_line("TUTORIAL COMPLETE!", Color.GREEN)
		add_terminal_line("=".repeat(50), Color.CYAN)
		add_terminal_line("\n✅ Congratulations! You've completed the tutorial!", Color.GREEN)
		add_terminal_line("\nFINAL SCORE: %d points" % score, Color.YELLOW)
		add_terminal_line("ACCURACY: %d%%" % get_accuracy(), Color.YELLOW)
		add_terminal_line("\n🎓 You've learned all 7 stages of incident response!", Color.CYAN)
		add_terminal_line("\n💡 NEXT STEP: Try Challenge Mode!", Color.MAGENTA)
		add_terminal_line("   Press F5 to restart and select Challenge Mode", Color.WHITE)
		add_terminal_line("   (No tutorials, no auto-fill, no hints!)\n", Color.GRAY)
		tutorial_completed = true
	else:
		add_terminal_line("CHALLENGE COMPLETE!", Color.GREEN)
		add_terminal_line("=".repeat(50), Color.CYAN)
		add_terminal_line("\n🏆 EXCELLENT WORK!", Color.GREEN)
		add_terminal_line("\nFINAL SCORE: %d points" % score, Color.YELLOW)
		add_terminal_line("ACCURACY: %d%%" % get_accuracy(), Color.YELLOW)
		add_terminal_line("\n✓ You've mastered incident response!", Color.CYAN)
		add_terminal_line("  Press F5 to play again\n", Color.WHITE)

func add_terminal_line(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	terminal_output.add_child(label)
	
	await get_tree().process_frame
	var scroll = $VBoxContainer/TerminalPanel/ScrollContainer
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func get_accuracy() -> int:
	if attempts == 0:
		return 100
	return int((float(current_stage + 1) / float(attempts)) * 100)

func _input(event):
	# Press ESC to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_exit_pressed()
	
	# Keep existing F1 and F5 functionality
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and tutorial_mode:
			show_current_tutorial_step()
		elif event.keycode == KEY_F5 and game_state == "complete":
			get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[CMD Incident Response] Exit pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")