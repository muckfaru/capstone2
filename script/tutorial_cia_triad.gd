extends Control

# ===================================================
# CIA TRIAD DEFENDER - Interactive Mini-Game
# ===================================================
# Learning Objective: Teach Confidentiality, Integrity, 
# and Availability through scenario-based sorting
# ===================================================

# Node references
@onready var score_label: Label = $CanvasLayer/TopPanel/ScoreLabel
@onready var streak_label: Label = $CanvasLayer/TopPanel/StreakLabel
@onready var incident_card: Panel = $CanvasLayer/IncidentCard
@onready var incident_text: RichTextLabel = $CanvasLayer/IncidentCard/MarginContainer/IncidentText
@onready var confidentiality_zone: Panel = $CanvasLayer/CIAZones/ConfidentialityZone
@onready var integrity_zone: Panel = $CanvasLayer/CIAZones/IntegrityZone
@onready var availability_zone: Panel = $CanvasLayer/CIAZones/AvailabilityZone
@onready var feedback_popup: Panel = $CanvasLayer/FeedbackPopup
@onready var feedback_text: RichTextLabel = $CanvasLayer/FeedbackPopup/MarginContainer/VBoxContainer/FeedbackText
@onready var try_again_btn: Button = $CanvasLayer/FeedbackPopup/MarginContainer/VBoxContainer/TryAgainButton
@onready var results_screen: Panel = $CanvasLayer/ResultsScreen
@onready var results_text: RichTextLabel = $CanvasLayer/ResultsScreen/MarginContainer/VBoxContainer/ResultsText
@onready var back_btn: Button = $CanvasLayer/ResultsScreen/MarginContainer/VBoxContainer/BackButton
@onready var sfx_correct: AudioStreamPlayer = $SFX_Correct
@onready var sfx_wrong: AudioStreamPlayer = $SFX_Wrong

# CIA Zone tooltips
@onready var c_tooltip: Label = $CanvasLayer/CIAZones/ConfidentialityZone/TooltipLabel
@onready var i_tooltip: Label = $CanvasLayer/CIAZones/IntegrityZone/TooltipLabel
@onready var a_tooltip: Label = $CanvasLayer/CIAZones/AvailabilityZone/TooltipLabel

# Scenario data
# Scenario data
const SCENARIOS = [
	{
		"text": "Someone broke into the hospital's computer system using a weak password. Now personal medical records of 10,000 patients can be seen by anyone on the internet.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nConfidentiality means keeping sensitive data PRIVATE. Patient records were exposed to unauthorized people—this breaks confidentiality."
	},
	{
		"text": "A virus locked all the company's files and demands payment to unlock them. Workers can't open emails, check payroll, or access any documents. Everything has been blocked for 2 days.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nAvailability means keeping systems ACCESSIBLE when needed. The virus didn't steal or change data—it blocked access to it."
	},
	{
		"text": "Someone hacked the school's computer and changed 20 students' report card grades from C to A without permission.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nIntegrity means keeping data ACCURATE and UNCHANGED. The grades were modified incorrectly—this breaks integrity."
	},
	{
		"text": "A laptop was stolen from a coffee shop. Inside the laptop were company financial reports and customer credit card information that weren't password-protected.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nThe sensitive financial data can now be SEEN by unauthorized people (the thief). Confidentiality breach!"
	},
	{
		"text": "Attackers broke into the company website and replaced the homepage with spray paint-style graffiti and posted fake news about the CEO.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nIntegrity means data stays CORRECT and TRUSTWORTHY. The website content was tampered with—breaking integrity."
	},
	{
		"text": "Attackers flooded the online shopping website with millions of fake visitors at once. Real customers can't load the website or buy anything because it's too overloaded.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe website is BLOCKED from legitimate users. The data wasn't stolen or changed—just made inaccessible."
	},
	{
		"text": "An employee found a USB flash drive in the parking lot labeled 'Employee Salaries 2025' and plugged it into their work computer. A hidden virus copied company files and sent them to criminals on the internet.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nThe virus STOLE and SENT files to attackers. Private data was exposed to unauthorized parties."
	},
	{
		"text": "The company's backup storage system broke during a building fire. When they tried to recover their data afterwards, they realized nothing was saved for the past 6 months—all that work is now gone forever.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe data couldn't be ACCESSED when needed. Even though the original data wasn't stolen or changed, it became unavailable due to lack of proper backups."
	}
]

# Game state
var current_scenario_index := 0
var score := 0
var streak := 0
const TOTAL_SCENARIOS := 8
const POINTS_PER_CORRECT := 100

# Drag state
var dragging := false
var drag_offset := Vector2.ZERO
var card_original_position := Vector2.ZERO

# Tutorial ID for TutorialManager
const TUTORIAL_ID := "cia_triad_basics"


func _ready() -> void:
	print("[CIA Triad] Tutorial scene ready!")
	
	# Hide popups initially
	feedback_popup.hide()
	results_screen.hide()
	
	# Store original card position
	card_original_position = incident_card.position
	
	# Connect signals
	try_again_btn.pressed.connect(_on_try_again_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	# Setup tooltips
	_setup_tooltips()
	
	# Setup keyboard shortcuts
	set_process_input(true)
	
	# Load first scenario
	_load_scenario()
	
	# Update display
	_update_ui()


func _setup_tooltips() -> void:
	"""Setup hover tooltips for CIA zones"""
	if c_tooltip:
		c_tooltip.text = "Keeping data SECRET\nfrom unauthorized people"
		c_tooltip.hide()
	
	if i_tooltip:
		i_tooltip.text = "Keeping data ACCURATE\nand UNCHANGED"
		i_tooltip.hide()
	
	if a_tooltip:
		a_tooltip.text = "Keeping systems RUNNING\nand ACCESSIBLE"
		a_tooltip.hide()


func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts"""
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		return
	
	# Only allow shortcuts when card is visible
	if not incident_card.visible or feedback_popup.visible:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C:
				_check_answer("C")
			KEY_I:
				_check_answer("I")
			KEY_A:
				_check_answer("A")


func _gui_input(event: InputEvent) -> void:
	"""Handle drag and drop on incident card"""
	pass  # Handled by child panel


func _load_scenario() -> void:
	"""Load current scenario into the incident card"""
	if current_scenario_index >= TOTAL_SCENARIOS:
		_show_results()
		return
	
	var scenario = SCENARIOS[current_scenario_index]
	incident_text.text = "[center]🚨 [b]INCIDENT ALERT #%d[/b] 🚨[/center]\n\n%s" % [current_scenario_index + 1, scenario["text"]]
	
	# Reset card position and appearance
	incident_card.position = card_original_position
	incident_card.modulate = Color.WHITE
	incident_card.show()
	
	print("[CIA Triad] Loaded scenario %d/%d" % [current_scenario_index + 1, TOTAL_SCENARIOS])


func _update_ui() -> void:
	"""Update score and streak display"""
	score_label.text = "Score: %d/%d" % [score, TOTAL_SCENARIOS * POINTS_PER_CORRECT]
	
	if streak > 0:
		streak_label.text = "Streak: %d 🔥" % streak
	else:
		streak_label.text = "Streak: 0"


func _check_answer(zone_type: String) -> void:
	"""Check if the selected zone is correct"""
	var scenario = SCENARIOS[current_scenario_index]
	var correct_answer = scenario["correct"]
	
	if zone_type == correct_answer:
		_handle_correct_answer(zone_type)
	else:
		_handle_wrong_answer(zone_type, correct_answer)


func _handle_correct_answer(zone_type: String) -> void:
	"""Handle correct answer feedback"""
	score += POINTS_PER_CORRECT
	streak += 1
	
	# Play success sound
	if sfx_correct:
		sfx_correct.play()
	
	# Visual feedback
	_play_success_animation(zone_type)
	
	# Update UI
	_update_ui()
	
	# Wait and load next scenario
	await get_tree().create_timer(1.5).timeout
	current_scenario_index += 1
	_load_scenario()


func _handle_wrong_answer(chosen: String, correct: String) -> void:
	"""Handle wrong answer feedback"""
	streak = 0
	
	# Play wrong sound
	if sfx_wrong:
		sfx_wrong.play()
	
	# Visual feedback
	_play_wrong_animation()
	
	# Show educational feedback popup
	_show_feedback(correct)
	
	# Update UI
	_update_ui()


func _play_success_animation(zone_type: String) -> void:
	"""Play success animation on correct zone"""
	var zone: Panel = null
	match zone_type:
		"C":
			zone = confidentiality_zone
		"I":
			zone = integrity_zone
		"A":
			zone = availability_zone
	
	if not zone:
		return
	
	# Green flash animation
	var original_modulate = zone.modulate
	zone.modulate = Color.GREEN_YELLOW
	
	var tween = create_tween()
	tween.tween_property(zone, "modulate", original_modulate, 0.5)
	
	# Card slides into zone
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(incident_card, "position", zone.position + Vector2(20, 20), 0.3)
	tween2.tween_property(incident_card, "modulate:a", 0.0, 0.3)


func _play_wrong_animation() -> void:
	"""Play wrong answer animation"""
	# Red flash on card
	incident_card.modulate = Color.ORANGE_RED
	
	# Shake animation
	var original_pos = incident_card.position
	var tween = create_tween()
	tween.tween_property(incident_card, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(incident_card, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(incident_card, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(incident_card, "position", original_pos, 0.05)
	
	await tween.finished
	
	# Reset color
	incident_card.modulate = Color.WHITE


func _show_feedback(correct_answer: String) -> void:
	"""Show educational feedback popup"""
	var scenario = SCENARIOS[current_scenario_index]
	
	var principle_name := ""
	var principle_color := ""
	match correct_answer:
		"C":
			principle_name = "CONFIDENTIALITY"
			principle_color = "cyan"
		"I":
			principle_name = "INTEGRITY"
			principle_color = "yellow"
		"A":
			principle_name = "AVAILABILITY"
			principle_color = "green"
	
	feedback_text.text = "[center]⚠️ [b]Not Quite![/b] ⚠️[/center]\n\nThis was a [color=%s][b]%s[/b][/color] breach.\n\n[color=%s]Remember:[/color] %s\n\n%s" % [
		principle_color, 
		principle_name,
		principle_color,
		_get_principle_reminder(correct_answer),
		scenario["explanation"].split("✅ Correct! ")[1] if "✅ Correct! " in scenario["explanation"] else scenario["explanation"]
	]
	
	feedback_popup.show()


func _get_principle_reminder(principle: String) -> String:
	"""Get reminder text for each principle"""
	match principle:
		"C":
			return "Confidentiality = Keeping data SECRET from unauthorized eyes."
		"I":
			return "Integrity = Keeping data ACCURATE and UNCHANGED."
		"A":
			return "Availability = Keeping systems RUNNING and ACCESSIBLE."
	return ""


func _on_try_again_pressed() -> void:
	"""Close feedback popup and allow retry"""
	feedback_popup.hide()
	# Reset card for retry
	incident_card.position = card_original_position
	incident_card.modulate = Color.WHITE


func _show_results() -> void:
	"""Show final results screen"""
	print("[CIA Triad] Tutorial complete! Score: %d/%d" % [score, TOTAL_SCENARIOS * POINTS_PER_CORRECT])
	
	# Hide game UI
	incident_card.hide()
	
	# Calculate percentage
	var max_score = TOTAL_SCENARIOS * POINTS_PER_CORRECT
	var percentage = (float(score) / float(max_score)) * 100.0
	
	# Determine grade
	var grade := ""
	var xp_earned := 0
	if percentage >= 90:
		grade = "A"
		xp_earned = 200
	elif percentage >= 80:
		grade = "B"
		xp_earned = 150
	elif percentage >= 70:
		grade = "C"
		xp_earned = 100
	elif percentage >= 50:
		grade = "D"
		xp_earned = 50
	else:
		grade = "F"
		xp_earned = 0
	
	# Display results
	results_text.text = """[center][b]🎓 CIA TRIAD TRAINING COMPLETE 🎓[/b][/center]

[center]━━━━━━━━━━━━━━━━━━━━━━━━━━━[/center]

[center][b]Final Score:[/b] %d / %d[/center]
[center][b]Accuracy:[/b] %.1f%%[/center]
[center][b]Grade:[/b] [color=cyan]%s[/color][/center]
[center][b]XP Earned:[/b] [color=yellow]+%d XP[/color][/center]

[center]━━━━━━━━━━━━━━━━━━━━━━━━━━━[/center]

[center]You've mastered the CIA Triad basics![/center]
[center]Remember: [color=cyan]Confidentiality[/color], [color=yellow]Integrity[/color],[/center]
[center]and [color=green]Availability[/color] work together![/center]
""" % [score, max_score, percentage, grade, xp_earned]
	
	# Complete tutorial via TutorialManager
	TutorialManager.complete_tutorial(TUTORIAL_ID, score, max_score)
	
	# Show results screen
	results_screen.show()


func _on_back_pressed() -> void:
	"""Return to mode selection"""
	print("[CIA Triad] Returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# ===================================================
# DRAG AND DROP SYSTEM
# ===================================================
func _on_card_dropped(global_pos: Vector2) -> void:
	"""Check which zone the card was dropped on"""
	# Check each zone
	var zones = [
		{"node": confidentiality_zone, "type": "C"},
		{"node": integrity_zone, "type": "I"},
		{"node": availability_zone, "type": "A"}
	]
	
	for zone in zones:
		var rect = zone["node"].get_global_rect()
		if rect.has_point(global_pos):
			_check_answer(zone["type"])
			return
	
	# Dropped outside zones - snap back
	var tween = create_tween()
	tween.tween_property(incident_card, "position", card_original_position, 0.2)
