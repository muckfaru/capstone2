class_name CommandParser
extends RefCounted

var command_history: Array = []

# --- string-padding helpers (GDScript has no built-in pad) ---
func _pad_right(s: String, width: int) -> String:
	if s.length() >= width:
		return s
	return s + " ".repeat(width - s.length())

func _pad_left(s: String, width: int) -> String:
	if s.length() >= width:
		return s
	return " ".repeat(width - s.length()) + s
# -------------------------------------------------------------

func parse_command(command: String, scenario: ScenarioManager) -> Dictionary:
	var cmd = command.strip_edges().to_lower()
	command_history.append(cmd)
	
	# Help command
	if cmd == "help":
		return _cmd_help()
	
	# System information commands
	elif cmd == "whoami":
		return _cmd_whoami(scenario)
	elif cmd == "systeminfo":
		return _cmd_systeminfo(scenario)
	
	# User management
	elif cmd == "net user" or cmd.begins_with("net user"):
		return _cmd_net_user(scenario)
	
	# Process investigation
	elif cmd == "tasklist":
		return _cmd_tasklist(scenario)
	elif cmd == "tasklist /svc":
		return _cmd_tasklist_svc(scenario)
	
	# Network investigation
	elif cmd == "netstat -ano":
		return _cmd_netstat(scenario)
	elif cmd == "ipconfig":
		return _cmd_ipconfig(scenario)
	
	# File system
	elif cmd == "dir" or cmd.begins_with("dir "):
		return _cmd_dir(scenario)
	
	# Log analysis
	elif cmd.begins_with("type "):
		return _cmd_type(cmd, scenario)
	elif cmd.begins_with("find "):
		return _cmd_find(cmd, scenario)
	
	else:
		return {
			"output": "[color=red]'" + command + "' is not recognized as a valid command.[/color]\n[color=yellow]Type 'help' for available commands.[/color]"
		}

func _cmd_help() -> Dictionary:
	var help_text = """[color=lime]AVAILABLE COMMANDS:[/color]

[color=cyan]SYSTEM INFORMATION:[/color]
  whoami          - Display current user
  systeminfo      - Display system information
  
[color=cyan]USER MANAGEMENT:[/color]
  net user        - List all user accounts
  
[color=cyan]PROCESS INVESTIGATION:[/color]
  tasklist        - List running processes
  tasklist /svc   - List processes with services
  
[color=cyan]NETWORK INVESTIGATION:[/color]
  netstat -ano    - Display network connections
  ipconfig        - Display network configuration
  
[color=cyan]FILE SYSTEM:[/color]
  dir             - List directory contents
  
[color=cyan]LOG ANALYSIS:[/color]
  type [file]     - Display file contents
                    (e.g., type security.log)
  find "text" [file] - Search for text in file
                    (e.g., find "failed" auth.log)

[color=yellow]Available log files: security.log, auth.log, system.log[/color]
"""
	return {"output": help_text}

func _cmd_whoami(scenario: ScenarioManager) -> Dictionary:
	return {
		"output": scenario.get_current_user()
	}

func _cmd_systeminfo(scenario: ScenarioManager) -> Dictionary:
	var info = scenario.get_system_info()
	return {"output": info}

func _cmd_net_user(scenario: ScenarioManager) -> Dictionary:
	var users = scenario.get_user_accounts()
	var output = "User accounts for \\\\WORKSTATION\n" + "------------------------------------------------------------" + "\n"
	
	for user in users:
		output += user + "\n"
	
	# Check for suspicious users
	var suspicious = scenario.get_suspicious_user()
	if suspicious in users:
		return {
			"output": output,
			"evidence": {
				"name": "Suspicious User Account: " + suspicious,
				"description": "Unauthorized user account detected in system. This account was not created by IT and may be used by the attacker."
			}
		}
	
	return {"output": output}

func _cmd_tasklist(scenario: ScenarioManager) -> Dictionary:
	var processes = scenario.get_processes()
	var output = "[color=lime]Image Name                     PID Session Name     Mem Usage[/color]\n"
	output += "============================================================\n"
	
	for process in processes:
		output += _pad_right(str(process.name), 30) + _pad_left(str(process.pid), 5) + " " + _pad_right(str(process.session), 16) + _pad_left(str(process.memory), 8) + "\n"
	
	# Check for malicious process
	var malicious = scenario.get_malicious_process()
	if malicious != "":
		for process in processes:
			if process.name == malicious:
				return {
					"output": output,
					"evidence": {
						"name": "Malicious Process: " + malicious,
						"description": "Suspicious process detected. PID: " + str(process.pid) + ". This process is not part of normal system operations and may be malware."
					}
				}
	
	return {"output": output}

func _cmd_tasklist_svc(scenario: ScenarioManager) -> Dictionary:
	var processes = scenario.get_processes_with_services()
	var output = "[color=lime]Image Name                     PID Services[/color]\n"
	output += "============================================================\n"
	
	for process in processes:
		output += _pad_right(str(process.name), 30) + _pad_left(str(process.pid), 5) + " " + str(process.service) + "\n"
	
	return {"output": output}

func _cmd_netstat(scenario: ScenarioManager) -> Dictionary:
	var connections = scenario.get_network_connections()
	var output = "[color=lime]Active Connections[/color]\n\n"
	output += "  Proto  Local Address          Foreign Address        State       PID\n"
	
	for conn in connections:
		output += "  " + _pad_right(str(conn.proto), 6) + " " + _pad_right(str(conn.local), 22) + " " + _pad_right(str(conn.foreign), 22) + " " + _pad_right(str(conn.state), 11) + " " + str(conn.pid) + "\n"
	
	# Check for suspicious IP
	var suspicious_ip = scenario.get_suspicious_ip()
	if suspicious_ip != "":
		for conn in connections:
			if suspicious_ip in conn.foreign:
				return {
					"output": output,
					"evidence": {
						"name": "Suspicious IP Connection: " + suspicious_ip,
						"description": "Outbound connection to unknown external IP detected. This IP is not associated with any known legitimate service and may be a command & control server."
					}
				}
	
	return {"output": output}

func _cmd_ipconfig(scenario: ScenarioManager) -> Dictionary:
	return {
		"output": scenario.get_ip_config()
	}

func _cmd_dir(scenario: ScenarioManager) -> Dictionary:
	var files = scenario.get_directory_listing()
	var output = " Directory of C:\\Users\\" + scenario.get_current_user() + "\n\n"
	
	for file in files:
		output += _pad_right(str(file.date), 20) + " " + str(file.name) + "\n"
	
	return {"output": output}

func _cmd_type(cmd: String, scenario: ScenarioManager) -> Dictionary:
	var parts = cmd.split(" ", false)
	if parts.size() < 2:
		return {"output": "[color=red]Usage: type [filename][/color]"}
	
	var filename = parts[1]
	
	if filename == "security.log":
		return _analyze_security_log(scenario)
	elif filename == "auth.log":
		return _analyze_auth_log(scenario)
	elif filename == "system.log":
		return _analyze_system_log(scenario)
	else:
		return {"output": "[color=red]File not found: " + filename + "[/color]"}

func _analyze_security_log(scenario: ScenarioManager) -> Dictionary:
	var log = scenario.get_security_log()
	return {"output": log}

func _analyze_auth_log(scenario: ScenarioManager) -> Dictionary:
	var log = scenario.get_auth_log()
	var result = {"output": log}
	
	# Check for brute force evidence
	if scenario.has_brute_force_attempts():
		result.evidence = {
			"name": "Brute Force Attack Detected",
			"description": "Multiple failed authentication attempts detected in auth.log, followed by successful login. Pattern indicates password guessing attack."
		}
	
	return result

func _analyze_system_log(scenario: ScenarioManager) -> Dictionary:
	var log = scenario.get_system_log()
	return {"output": log}

func _cmd_find(cmd: String, scenario: ScenarioManager) -> Dictionary:
	# Parse: find "search_term" filename
	var regex = RegEx.new()
	regex.compile("find\\s+\"([^\"]+)\"\\s+([\\w\\.]+)")
	var result_match = regex.search(cmd)
	
	if result_match == null:
		return {"output": "[color=red]Usage: find \"search_term\" filename[/color]"}
	
	var search_term = result_match.get_string(1)
	var filename = result_match.get_string(2)
	
	var log_content = ""
	if filename == "security.log":
		log_content = scenario.get_security_log()
	elif filename == "auth.log":
		log_content = scenario.get_auth_log()
	elif filename == "system.log":
		log_content = scenario.get_system_log()
	else:
		return {"output": "[color=red]File not found: " + filename + "[/color]"}
	
	# Search for term
	var lines = log_content.split("\n")
	var matches = []
	
	for line in lines:
		if search_term.to_lower() in line.to_lower():
			matches.append(line)
	
	if matches.is_empty():
		return {"output": "[color=yellow]No matches found for \"" + search_term + "\" in " + filename + "[/color]"}
	
	var output = "[color=lime]Found " + str(matches.size()) + " matches in " + filename + ":[/color]\n\n"
	for match in matches:
		output += match + "\n"
	
	# Check for specific evidence triggers
	var evidence = _check_find_evidence(search_term, filename, matches, scenario)
	if evidence != null:
		return {
			"output": output,
			"evidence": evidence,
			"unlock_decision": matches.size() >= 3
		}
	
	return {"output": output}

func _check_find_evidence(search_term: String, filename: String, matches: Array, scenario: ScenarioManager):
	if filename == "auth.log" and search_term.to_lower() == "failed":
		if matches.size() > 5:
			return {
				"name": "Authentication Failures",
				"description": "Excessive failed login attempts detected. " + str(matches.size()) + " failures logged, indicating possible brute-force attack."
			}
	
	if filename == "security.log" and search_term.to_lower() == "rdp":
		if matches.size() > 0:
			return {
				"name": "RDP Access Log",
				"description": "Remote Desktop Protocol connections detected in security log. May indicate remote access attempt."
			}
	
	if filename == "system.log" and search_term.to_lower() == "error":
		if matches.size() > 3:
			return {
				"name": "System Errors",
				"description": "Multiple system errors detected, possibly caused by malware interference with system services."
			}
	
	return null

func reset():
	command_history.clear()