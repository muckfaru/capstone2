class_name Tutorialmanagerforensic
extends RefCounted

# ═══════════════════════════════════════════════════════════════
# FULL GAME TUTORIAL - Complete Walkthrough
# Player completes ONE ENTIRE investigation from start to finish
# with step-by-step guidance. After completion, tutorial never
# plays again (unless manually restarted).
# ═══════════════════════════════════════════════════════════════

var steps: Array = [
	{
		"title": "Welcome to Digital Forensics",
		"body": "[b]You are a Digital Forensics Analyst.[/b]\n\nYou have been assigned to investigate a security breach.\n\n[u]This tutorial will guide you through:[/u]\n• Running investigation commands\n• Collecting evidence\n• Analyzing findings\n• Making the correct conclusion\n• Submitting your report\n\n[color=yellow]This is a FULL game walkthrough. Pay attention — after this tutorial, you'll investigate on your own![/color]",
		"command": "",
		"phase": "start"
	},
	{
		"title": "Step 1: Identify Current User",
		"body": "Every investigation starts with understanding your system context.\n\n[b]Task:[/b] Find out which user account you are logged in as.\n\nClick the green command below to execute it.",
		"command": "whoami",
		"phase": "investigation"
	},
	{
		"title": "Step 2: List All User Accounts",
		"body": "Attackers often create unauthorized accounts for persistence.\n\n[b]Task:[/b] List all user accounts on this workstation.\n\n[color=yellow]Look for account names that seem suspicious or out of place.[/color]",
		"command": "net user",
		"phase": "investigation"
	},
	{
		"title": "Step 3: Check Running Processes",
		"body": "Malware disguises itself as legitimate system processes.\n\n[b]Task:[/b] Display all currently running processes.\n\n[color=yellow]Compare process names against what you'd expect on a normal Windows system.[/color]",
		"command": "tasklist",
		"phase": "investigation"
	},
	{
		"title": "Step 4: Inspect Network Connections",
		"body": "Malware communicates with Command & Control servers.\n\n[b]Task:[/b] Show all active network connections.\n\n[color=yellow]Look for connections to external IPs that aren't local (192.168.x.x or 127.0.0.1).[/color]",
		"command": "netstat -ano",
		"phase": "investigation"
	},
	{
		"title": "Step 5: Read Security Log",
		"body": "System logs record everything that happens on the machine.\n\n[b]Task:[/b] Read the security.log file.\n\n[color=yellow]Look for executed programs, especially .exe files from unusual locations.[/color]",
		"command": "type security.log",
		"phase": "investigation"
	},
	{
		"title": "Step 6: Read Authentication Log",
		"body": "Authentication logs show all login attempts.\n\n[b]Task:[/b] Read the auth.log file.\n\n[color=yellow]Look for patterns like multiple failed attempts followed by success.[/color]",
		"command": "type auth.log",
		"phase": "investigation"
	},
	{
		"title": "Evidence Review",
		"body": "[b]Excellent work, Analyst![/b]\n\nYou've collected evidence from this investigation.\n\n[u]Check the Evidence Panel on the right →[/u]\nClick on each evidence item to read its description.\n\n[color=lime]Evidence collected:[/color]\n• You should now have 2-3 pieces of evidence\n• Each piece reveals clues about the attack\n\n[color=yellow]Once you've reviewed the evidence, click Next to analyze your findings.[/color]",
		"command": "",
		"phase": "review"
	},
	{
		"title": "Analysis: Attack Type",
		"body": "[b]Now let's analyze what happened.[/b]\n\nBased on the evidence you collected:\n\n[color=cyan]Security.log shows:[/color]\n• Invoice_Q4.exe was executed (email attachment)\n• This created winlogon32.exe (fake system process)\n• Windows Defender was disabled\n\n[color=cyan]Network connections show:[/color]\n• Outbound connection to 185.220.101.47 (C2 server)\n\n[color=lime]Conclusion:[/color] This is a [b]Phishing → Trojan Malware[/b] attack.\n\nThe user opened a malicious email attachment that installed a trojan.",
		"command": "",
		"phase": "analysis"
	},
	{
		"title": "Analysis: Entry Method",
		"body": "[b]How did the attacker get in?[/b]\n\nLooking at security.log again:\n• Invoice_Q4.exe came from Downloads folder\n• User executed it manually\n• This is typical of email phishing\n\n[color=lime]Entry Method:[/color] [b]Malicious Email Attachment[/b]\n\nThe attacker sent a fake invoice via email. The user downloaded and ran it.",
		"command": "",
		"phase": "analysis"
	},
	{
		"title": "Analysis: Incident Response",
		"body": "[b]What should you do?[/b]\n\nIn a real incident, you must take multiple actions:\n\n• [color=red]Isolate[/color] the infected system from the network\n• [color=red]Kill[/color] the malicious process (winlogon32.exe)\n• [color=red]Remove[/color] the malware files\n• [color=red]Reset[/color] potentially compromised credentials\n• [color=red]Patch[/color] any vulnerabilities\n• [color=red]Report[/color] to the security team\n\n[color=lime]Correct Answer:[/color] [b]All of the Above[/b]\n\nIncident response requires comprehensive action.",
		"command": "",
		"phase": "analysis"
	},
	{
		"title": "Make Your Decision",
		"body": "[b]The Decision Panel is now unlocked (bottom of screen).[/b]\n\n[u]Your task:[/u]\nSelect the correct answers:\n\n1. [color=cyan]Attack Type:[/color] Phishing → Trojan Malware\n2. [color=cyan]Entry Method:[/color] Malicious Email Attachment  \n3. [color=cyan]Response Action:[/color] All of the Above\n\n[color=yellow]Scroll down to the Decision Panel, make your selections, then click SUBMIT.[/color]\n\n[color=lime]This tutorial will continue after you submit...[/color]",
		"command": "",
		"phase": "decision"
	},
	{
		"title": "Tutorial Complete!",
		"body": "[b][color=lime]Congratulations! You've completed your first investigation![/color][/b]\n\nYou just:\n✓ Ran forensic commands\n✓ Collected evidence  \n✓ Analyzed the attack\n✓ Made the correct conclusion\n\n[u]What happens next?[/u]\n\nYou'll see your score and feedback. After reviewing it, you can choose:\n\n• [b]Practice Mode[/b] - Hints and command suggestions available\n• [b]Solo Mode[/b] - No hints, pure challenge\n\n[color=yellow]Click 'Finish Tutorial' to see your results![/color]",
		"command": "",
		"phase": "complete"
	}
]

var current_index: int = 0
var step_completed: bool = false
var tutorial_finished: bool = false
var waiting_for_decision_submit: bool = false  # special flag for decision step

# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

func is_active() -> bool:
	return not tutorial_finished

func is_complete() -> bool:
	return current_index >= steps.size()

func get_current_step() -> Dictionary:
	if current_index < steps.size():
		return steps[current_index]
	return {}

func get_step_progress() -> String:
	if tutorial_finished:
		return ""
	return "Tutorial Step " + str(current_index + 1) + " / " + str(steps.size())

func mark_step_complete():
	step_completed = true

func advance_step():
	current_index += 1
	step_completed = false
	waiting_for_decision_submit = false

func finish_tutorial():
	tutorial_finished = true

func is_correct_command(command: String) -> bool:
	if current_index >= steps.size():
		return false
	var required = steps[current_index].command.strip_edges().to_lower()
	if required == "":
		return false  # This step has no command
	return command.strip_edges().to_lower() == required

func can_proceed_to_next() -> bool:
	if current_index >= steps.size():
		return false
	var step = steps[current_index]
	
	# Steps with no command can proceed immediately
	if step.command == "":
		return true
	
	# Steps with commands must be completed first
	return step_completed

func get_current_phase() -> String:
	if current_index < steps.size():
		return steps[current_index].phase
	return ""

# Called when player submits their decision answers
func on_decision_submitted():
	waiting_for_decision_submit = false
	step_completed = true