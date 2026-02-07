class_name ScoreManager
extends RefCounted

var score: int = 0
var max_score: int = 100
var feedback_text: String = ""

var attack_score: int = 0
var entry_score: int = 0
var response_score: int = 0
var evidence_score: int = 0

func evaluate_answers(attack_type: String, entry_method: String, response_action: String, 
					  scenario: ScenarioManager, evidence: EvidenceManager):
	score = 0
	attack_score = 0
	entry_score = 0
	response_score = 0
	evidence_score = 0
	
	# Evaluate attack type (35 points)
	if attack_type == scenario.get_correct_attack_type():
		attack_score = 35
		score += 35
	
	# Evaluate entry method (30 points)
	if entry_method == scenario.get_correct_entry_method():
		entry_score = 30
		score += 30
	
	# Evaluate response action (25 points)
	if response_action == scenario.get_correct_response():
		response_score = 25
		score += 25
	elif "All of the Above" in scenario.get_correct_response() and response_action != "Select Response Action":
		# Partial credit if they chose one correct action
		response_score = 10
		score += 10
	
	# Evidence collection bonus (10 points)
	var evidence_count = evidence.get_evidence_count()
	if evidence_count >= 5:
		evidence_score = 10
		score += 10
	elif evidence_count >= 3:
		evidence_score = 7
		score += 7
	elif evidence_count >= 1:
		evidence_score = 4
		score += 4
	
	_generate_feedback(attack_type, entry_method, response_action, scenario, evidence)

func _generate_feedback(attack_type: String, entry_method: String, response_action: String,
						scenario: ScenarioManager, evidence: EvidenceManager):
	feedback_text = "[center][color=yellow]INVESTIGATION COMPLETE[/color][/center]\n\n"
	feedback_text += "======================================================================\n\n"
	var grade = _get_grade(score)
	var grade_color = _get_grade_color(grade)
	
	feedback_text += "[center][color=" + grade_color + "]FINAL SCORE: " + str(score) + "/" + str(max_score) + " (" + grade + ")[/color][/center]\n\n"
	feedback_text += "======================================================================\n\n"
	
	# Attack Type Analysis
	feedback_text += "[color=cyan]ATTACK TYPE IDENTIFICATION:[/color] "
	if attack_score > 0:
		feedback_text += "[color=lime]CORRECT ✓[/color] (+" + str(attack_score) + " points)\n"
	else:
		feedback_text += "[color=red]INCORRECT ✗[/color] (+0 points)\n"
	
	feedback_text += "Your answer: " + attack_type + "\n"
	feedback_text += "Correct answer: " + scenario.get_correct_attack_type() + "\n\n"
	
	if attack_score == 0:
		feedback_text += _get_attack_type_explanation(scenario) + "\n\n"
	
	# Entry Method Analysis
	feedback_text += "[color=cyan]ENTRY METHOD IDENTIFICATION:[/color] "
	if entry_score > 0:
		feedback_text += "[color=lime]CORRECT ✓[/color] (+" + str(entry_score) + " points)\n"
	else:
		feedback_text += "[color=red]INCORRECT ✗[/color] (+0 points)\n"
	
	feedback_text += "Your answer: " + entry_method + "\n"
	feedback_text += "Correct answer: " + scenario.get_correct_entry_method() + "\n\n"
	
	if entry_score == 0:
		feedback_text += _get_entry_method_explanation(scenario) + "\n\n"
	
	# Response Action Analysis
	feedback_text += "[color=cyan]INCIDENT RESPONSE ACTION:[/color] "
	if response_score == 25:
		feedback_text += "[color=lime]CORRECT ✓[/color] (+" + str(response_score) + " points)\n"
	elif response_score > 0:
		feedback_text += "[color=yellow]PARTIAL CREDIT[/color] (+" + str(response_score) + " points)\n"
	else:
		feedback_text += "[color=red]INCORRECT ✗[/color] (+0 points)\n"
	
	feedback_text += "Your answer: " + response_action + "\n"
	feedback_text += "Correct answer: " + scenario.get_correct_response() + "\n\n"
	
	if response_score < 25:
		feedback_text += _get_response_explanation(scenario) + "\n\n"
	
	# Evidence Collection
	feedback_text += "[color=cyan]EVIDENCE COLLECTION:[/color] +" + str(evidence_score) + " points\n"
	feedback_text += "Evidence collected: " + str(evidence.get_evidence_count()) + " items\n\n"
	
	var evidences = evidence.get_all_evidence()
	if evidences.size() > 0:
		feedback_text += "[color=yellow]Collected Evidence:[/color]\n"
		for ev in evidences:
			feedback_text += "  • " + ev.name + "\n"
		feedback_text += "\n"
	
	# Final analysis
	feedback_text += "======================================================================\n\n"
	feedback_text += _get_final_analysis(score) + "\n"

func _get_attack_type_explanation(scenario: ScenarioManager) -> String:
	var correct = scenario.get_correct_attack_type()
	
	match correct:
		"Phishing → Trojan Malware":
			return "The security logs show Invoice_Q4.exe was executed from an email attachment, which then created winlogon32.exe (a fake system process). This is classic phishing leading to trojan deployment."
		
		"RDP Brute-Force Attack":
			return "The auth.log shows multiple failed RDP login attempts followed by a successful login from an unusual IP. This pattern indicates a brute-force attack."
		
		"Credential Reuse":
			return "The legitimate user's credentials were used from an unusual location, and a suspicious account was created. The credentials were likely stolen from a data breach."
		
		"Backdoor Malware":
			return "The svchosts.exe process (note the 's' at the end) maintains persistent connections to a C2 server and was installed via a scheduled task for persistence."
		
		"Ransomware Infection":
			return "The encrypt.exe process performed mass file modifications, deleted shadow copies, and left a ransom note. These are clear indicators of ransomware."
		
		"Malicious Scheduled Task":
			return "A scheduled task was created to run PowerShell scripts with SYSTEM privileges at regular intervals, establishing persistence for the attacker."
		
		_:
			return "Review the evidence carefully to identify the attack pattern."

func _get_entry_method_explanation(scenario: ScenarioManager) -> String:
	var correct = scenario.get_correct_entry_method()
	
	match correct:
		"Malicious Email Attachment":
			return "The security logs show a suspicious executable (Invoice_Q4.exe or document_final.exe) was executed, likely from an email attachment."
		
		"Weak Password":
			return "The brute-force attack succeeded because the password was weak enough to be guessed within a short time period."
		
		"Stolen Credentials":
			return "Valid credentials were used from an unusual location, suggesting they were compromised in a previous breach."
		
		"Software Vulnerability":
			return "The attacker exploited a vulnerability to install malware or create persistence mechanisms without user interaction."
		
		_:
			return "Analyze the logs to determine how the attacker gained initial access."

func _get_response_explanation(scenario: ScenarioManager) -> String:
	return "In most security incidents, a comprehensive response is required: isolate the system to prevent spread, kill malicious processes, remove malware, reset compromised credentials, patch vulnerabilities, and report the incident to the security team."

func _get_grade(points: int) -> String:
	if points >= 90:
		return "A - Excellent"
	elif points >= 80:
		return "B - Good"
	elif points >= 70:
		return "C - Satisfactory"
	elif points >= 60:
		return "D - Needs Improvement"
	else:
		return "F - Poor"

func _get_grade_color(grade: String) -> String:
	if grade.begins_with("A"):
		return "lime"
	elif grade.begins_with("B"):
		return "green"
	elif grade.begins_with("C"):
		return "yellow"
	elif grade.begins_with("D"):
		return "orange"
	else:
		return "red"

func _get_final_analysis(points: int) -> String:
	if points >= 90:
		return "[color=lime]Outstanding work! You demonstrated strong digital forensics skills and correctly identified all key elements of the attack. You're ready for advanced incident response scenarios.[/color]"
	elif points >= 80:
		return "[color=green]Good investigation! You identified most key elements correctly. Review the areas where you lost points to improve your forensic analysis skills.[/color]"
	elif points >= 70:
		return "[color=yellow]Satisfactory effort. You found the main evidence but missed some important details. Practice analyzing logs more carefully and correlating evidence across multiple sources.[/color]"
	elif points >= 60:
		return "[color=orange]Your investigation needs improvement. Focus on systematically checking all available commands and correlating evidence from multiple sources before drawing conclusions.[/color]"
	else:
		return "[color=red]This investigation was insufficient. Review the correct answers and try again. Remember: collect evidence methodically, analyze logs carefully, and base conclusions on facts, not assumptions.[/color]"

func get_feedback() -> String:
	return feedback_text

func reset():
	score = 0
	attack_score = 0
	entry_score = 0
	response_score = 0
	evidence_score = 0
	feedback_text = ""