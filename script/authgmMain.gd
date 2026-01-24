extends Control

# Preload the ScenarioDatabase script
const ScenarioDatabaseScript = preload("res://script/ScenarioDatabase.gd")

# Game state
enum GameState { INTRO, PLAYING, FEEDBACK, DEBRIEF }
var current_state = GameState.INTRO

# Scenario management
var scenario_database
var all_scenarios: Array = []
var current_scenario_index: int = 0
var current_wave: int = 1
var max_waves: int = 10

# Score tracking
var trust_score: int = 100
var xp: int = 0
var total_scenarios: int = 0
var correct_decisions: int = 0
var attacks_blocked: int = 0
var total_attacks: int = 0
var false_denials: int = 0

# UI References
@onready var hud = $HUD
@onready var trust_bar = $HUD/MetricsPanel/VBox/TrustBar
@onready var trust_label = $HUD/MetricsPanel/VBox/TrustLabel
@onready var threats_label = $HUD/MetricsPanel/VBox/ThreatsLabel
@onready var xp_label = $HUD/MetricsPanel/VBox/XPLabel
@onready var wave_label = $HUD/MetricsPanel/VBox/WaveLabel
@onready var request_card = $RequestCard
@onready var feedback_popup = $FeedbackPopup
@onready var debrief_screen = $DebriefScreen
@onready var intro_panel = $IntroPanel
@onready var start_button = $IntroPanel/VBox/StartButton

func _ready():
	# Initialize database using the preloaded script
	scenario_database = ScenarioDatabaseScript.new()
	add_child(scenario_database)
	
	# Load all scenarios
	all_scenarios = scenario_database.get_all_scenarios()
	
	# Count total attacks
	for scenario in all_scenarios:
		if scenario.is_attacker:
			total_attacks += 1
	
	# Connect signals
	request_card.decision_made.connect(_on_decision_made)
	feedback_popup.feedback_complete.connect(_on_feedback_complete)
	debrief_screen.continue_pressed.connect(_on_continue_pressed)
	debrief_screen.replay_pressed.connect(_on_replay_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	# Start with intro
	_show_intro()

func _show_intro():
	current_state = GameState.INTRO
	intro_panel.visible = true
	request_card.visible = false
	feedback_popup.visible = false
	debrief_screen.visible = false
	hud.visible = false

func _on_start_pressed():
	intro_panel.visible = false
	hud.visible = true
	_start_game()

func _start_game():
	current_state = GameState.PLAYING
	current_scenario_index = 0
	current_wave = 1
	trust_score = 100
	xp = 0
	total_scenarios = 0
	correct_decisions = 0
	attacks_blocked = 0
	false_denials = 0
	
	_update_hud()
	_show_next_scenario()

func _show_next_scenario():
	if current_scenario_index >= all_scenarios.size():
		_show_debrief()
		return
	
	current_state = GameState.PLAYING
	
	var scenario = all_scenarios[current_scenario_index]
	current_wave = scenario.wave
	
	request_card.visible = true
	request_card.setup(scenario)
	
	_update_hud()

func _on_decision_made(action: String, scenario: Scenario):
	current_state = GameState.FEEDBACK
	total_scenarios += 1
	
	var is_correct = false
	var score_change = 0
	var feedback_message = ""
	
	# Handle timeout
	if action == "timeout":
		is_correct = false
		trust_score -= 15
		feedback_message = "Time expired! Auto-denied for safety. Be faster in real incidents."
	else:
		# Check if decision was correct
		is_correct = (action == scenario.correct_action)
		
		if is_correct:
			correct_decisions += 1
			score_change = 15
			trust_score += score_change
			xp += 10
			feedback_message = scenario.feedback_correct
			
			# Track blocked attacks
			if scenario.is_attacker:
				attacks_blocked += 1
		else:
			trust_score -= scenario.threat_consequence
			feedback_message = scenario.feedback_incorrect
			
			# Track false denials
			if not scenario.is_attacker and action == "deny":
				false_denials += 1
	
	# Clamp trust score
	trust_score = clampi(trust_score, 0, 100)
	
	# Show feedback
	request_card.visible = false
	feedback_popup.show_feedback(is_correct, feedback_message, score_change, scenario)
	
	_update_hud()

func _on_feedback_complete():
	# Check for game over
	if trust_score < 20:
		_show_game_over()
		return
	
	# Move to next scenario
	current_scenario_index += 1
	_show_next_scenario()

func _show_game_over():
	debrief_screen.visible = true
	debrief_screen.show_debrief(
		total_scenarios,
		correct_decisions,
		attacks_blocked,
		total_attacks,
		false_denials,
		trust_score,
		xp
	)

func _show_debrief():
	current_state = GameState.DEBRIEF
	request_card.visible = false
	feedback_popup.visible = false
	debrief_screen.visible = true
	
	debrief_screen.show_debrief(
		total_scenarios,
		correct_decisions,
		attacks_blocked,
		total_attacks,
		false_denials,
		trust_score,
		xp
	)

func _on_continue_pressed():
	# Could load next level or return to menu
	get_tree().quit()

func _on_replay_pressed():
	debrief_screen.visible = false
	_start_game()

func _update_hud():
	trust_bar.value = trust_score
	trust_label.text = "Trust Score: %d%%" % trust_score
	
	# Color code trust bar
	if trust_score >= 80:
		trust_bar.modulate = Color.GREEN
	elif trust_score >= 50:
		trust_bar.modulate = Color.YELLOW
	else:
		trust_bar.modulate = Color.RED
	
	var active_threats = total_attacks - attacks_blocked
	threats_label.text = "Active Threats: %d 🔴" % active_threats
	
	xp_label.text = "XP: %d" % xp
	wave_label.text = "Wave: %d/%d" % [current_wave, max_waves]
