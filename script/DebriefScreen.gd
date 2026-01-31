extends Control

signal continue_pressed
signal replay_pressed

@onready var title_label = $Panel/VBox/Title
@onready var stats_label = $Panel/VBox/Stats
@onready var lessons_text = $Panel/VBox/LessonsScroll/Lessons
@onready var final_score_label = $Panel/VBox/FinalScore
@onready var grade_label = $Panel/VBox/Grade
@onready var continue_button = $Panel/VBox/Buttons/ContinueButton
@onready var replay_button = $Panel/VBox/Buttons/ReplayButton

func show_debrief(total_scenarios: int, correct_decisions: int, attacks_blocked: int, 
				  total_attacks: int, false_denials: int, final_trust: int, final_xp: int):
	visible = true
	
	# Calculate stats (FIX: Use proper float division)
	var accuracy: float = 0.0
	if total_scenarios > 0:
		accuracy = (float(correct_decisions) / float(total_scenarios)) * 100.0
	
	var attack_block_rate: float = 0.0
	if total_attacks > 0:
		attack_block_rate = (float(attacks_blocked) / float(total_attacks)) * 100.0
	
	# Stats summary
	stats_label.text = """[center]Requests Processed: %d
Correct Decisions: %d (%d%%)
Attacks Blocked: %d/%d (%d%%)
False Denials: %d[/center]""" % [
		total_scenarios,
		correct_decisions,
		int(accuracy),
		attacks_blocked,
		total_attacks,
		int(attack_block_rate),
		false_denials
	]
	
	# Lessons learned
	var lessons = _generate_lessons(correct_decisions, total_scenarios, attacks_blocked, total_attacks, false_denials)
	lessons_text.text = lessons
	
	# Final score
	final_score_label.text = "Final Score: %d/100 | XP Earned: %d" % [final_trust, final_xp]
	
	# Grade
	var grade = _calculate_grade(final_trust)
	grade_label.text = grade
	
	match grade[0]:
		"A":
			grade_label.modulate = Color.GREEN
		"B":
			grade_label.modulate = Color.CYAN
		"C":
			grade_label.modulate = Color.YELLOW
		"F":
			grade_label.modulate = Color.RED

func _calculate_grade(trust: int) -> String:
	if trust >= 90:
		return "A - SECURITY CHAMPION"
	elif trust >= 75:
		return "B - COMPETENT ANALYST"
	elif trust >= 60:
		return "C - NEEDS IMPROVEMENT"
	else:
		return "F - REMEDIAL TRAINING REQUIRED"

func _generate_lessons(correct: int, total: int, blocked: int, attacks: int, false_denials: int) -> String:
	var lessons = "[b]KEY LESSONS:[/b]\n\n"
	
	# FIX: Use proper float division
	var accuracy: float = 0.0
	if total > 0:
		accuracy = (float(correct) / float(total)) * 100.0
	
	if accuracy >= 80:
		lessons += "✓ [color=green]Excellent decision-making skills demonstrated[/color]\n"
	else:
		lessons += "✗ [color=red]Need to improve threat assessment accuracy[/color]\n"
	
	if blocked == attacks and attacks > 0:
		lessons += "✓ [color=green]Perfect attack detection - blocked all threats![/color]\n"
	elif blocked < attacks:
		var missed = attacks - blocked
		lessons += "✗ [color=red]Missed " + str(missed) + " attack(s) - review MFA and context flags[/color]\n"
	
	if false_denials == 0:
		lessons += "✓ [color=green]Zero false denials - great balance of security and usability[/color]\n"
	else:
		lessons += "⚠ [color=yellow]" + str(false_denials) + " false denial(s) - ensure legitimate users can work[/color]\n"
	
	lessons += "\n[b]REMEMBER:[/b]\n"
	lessons += "• Authentication = WHO (identity verification)\n"
	lessons += "• Authorization = WHAT (access permissions)\n"
	lessons += "• MFA prevents 99% of credential attacks\n"
	lessons += "• Context matters: location, time, behavior\n"
	lessons += "• Least privilege minimizes breach impact\n"
	
	return lessons

func _on_continue_button_pressed():
	emit_signal("continue_pressed")

func _on_replay_button_pressed():
	emit_signal("replay_pressed")