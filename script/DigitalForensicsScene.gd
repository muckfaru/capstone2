extends Control

# Node references
@onready var briefing_panel = $BriefingPanel
@onready var briefing_text = $BriefingPanel/BriefingText
@onready var start_button = $BriefingPanel/StartButton

@onready var terminal_panel = $TerminalPanel
@onready var terminal_output = $TerminalPanel/TerminalOutput
@onready var terminal_input = $TerminalPanel/TerminalInput
@onready var cursor_animation = $TerminalPanel/CursorAnimation

@onready var evidence_panel = $EvidencePanel
@onready var evidence_list = $EvidencePanel/EvidenceList
@onready var evidence_description = $EvidencePanel/EvidenceDescription

@onready var objective_panel = $ObjectivePanel
@onready var objective_text = $ObjectivePanel/ObjectiveText

@onready var decision_panel = $DecisionPanel
@onready var attack_type_dropdown = $DecisionPanel/AttackTypeDropdown
@onready var entry_method_dropdown = $DecisionPanel/EntryMethodDropdown
@onready var response_dropdown = $DecisionPanel/ResponseDropdown
@onready var submit_button = $DecisionPanel/SubmitButton

@onready var feedback_panel = $FeedbackPanel
@onready var result_text = $FeedbackPanel/ResultText
@onready var continue_button = $FeedbackPanel/ContinueButton

# Tutorial panel
@onready var tutorial_panel = $TutorialPanel
@onready var tutorial_title = $TutorialPanel/TutorialHeader/TutorialTitle
@onready var tutorial_body = $TutorialPanel/TutorialBody
@onready var tutorial_cmd_box = $TutorialPanel/CommandBox
@onready var tutorial_hide_btn = $TutorialPanel/HideButton

# Mode selection panel
@onready var mode_panel = $ModeSelectionPanel
@onready var practice_mode_btn = $ModeSelectionPanel/PracticeModeButton
@onready var solo_mode_btn = $ModeSelectionPanel/SoloModeButton

# Game managers
var command_parser: CommandParser
var scenario_manager: ScenarioManager
var evidence_manager: EvidenceManager
var score_manager: ScoreManager
var tutorial_manager: Tutorialmanagerforensic

var current_phase: String = "briefing"
var tutorial_mode: bool = true  # locks terminal until tutorial complete
var tutorial_ever_completed: bool = false  # tracks if tutorial was completed at least once
var practice_mode: bool = false  # hints available when true
var game_mode_selected: bool = false  # tracks if player chose practice/solo after tutorial

func _ready():
	# Initialize managers
	command_parser = CommandParser.new()
	scenario_manager = ScenarioManager.new()
	evidence_manager = EvidenceManager.new()
	score_manager = ScoreManager.new()
	tutorial_manager = Tutorialmanagerforensic.new()
	
	# Connect signals
	start_button.pressed.connect(_on_start_button_pressed)
	terminal_input.text_submitted.connect(_on_terminal_input_submitted)
	submit_button.pressed.connect(_on_submit_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	evidence_list.item_selected.connect(_on_evidence_selected)
	tutorial_cmd_box.pressed.connect(_on_tutorial_cmd_pressed)
	tutorial_hide_btn.pressed.connect(_on_tutorial_hide_pressed)
	practice_mode_btn.pressed.connect(_on_practice_mode_selected)
	solo_mode_btn.pressed.connect(_on_solo_mode_selected)
	
	# Setup initial state
	_setup_initial_state()
	_load_scenario()

func _setup_initial_state():
	terminal_panel.hide()
	evidence_panel.hide()
	objective_panel.hide()
	decision_panel.hide()
	feedback_panel.hide()
	mode_panel.hide()
	briefing_panel.show()
	
	# Setup dropdowns
	_setup_dropdowns()

func _setup_dropdowns():
	# Attack types
	attack_type_dropdown.clear()
	attack_type_dropdown.add_item("Select Attack Type", 0)
	attack_type_dropdown.add_item("Phishing → Trojan Malware", 1)
	attack_type_dropdown.add_item("RDP Brute-Force Attack", 2)
	attack_type_dropdown.add_item("Credential Reuse", 3)
	attack_type_dropdown.add_item("Backdoor Malware", 4)
	attack_type_dropdown.add_item("Ransomware Infection", 5)
	attack_type_dropdown.add_item("Malicious Scheduled Task", 6)
	
	# Entry methods
	entry_method_dropdown.clear()
	entry_method_dropdown.add_item("Select Entry Method", 0)
	entry_method_dropdown.add_item("Malicious Email Attachment", 1)
	entry_method_dropdown.add_item("Brute-Force Login", 2)
	entry_method_dropdown.add_item("Stolen Credentials", 3)
	entry_method_dropdown.add_item("Software Vulnerability", 4)
	entry_method_dropdown.add_item("USB Device", 5)
	entry_method_dropdown.add_item("Weak Password", 6)
	
	# Response actions
	response_dropdown.clear()
	response_dropdown.add_item("Select Response Action", 0)
	response_dropdown.add_item("Isolate System from Network", 1)
	response_dropdown.add_item("Kill Malicious Process", 2)
	response_dropdown.add_item("Reset User Credentials", 3)
	response_dropdown.add_item("Patch System Vulnerability", 4)
	response_dropdown.add_item("Remove Malware Files", 5)
	response_dropdown.add_item("All of the Above", 6)

func _load_scenario():
	scenario_manager.load_random_scenario()
	briefing_text.text = scenario_manager.get_briefing()
	objective_text.text = scenario_manager.get_objective()

func _on_start_button_pressed():
	current_phase = "investigation"
	briefing_panel.hide()
	terminal_panel.show()
	evidence_panel.show()
	objective_panel.show()
	
	# Lock terminal input during tutorial
	terminal_input.editable = false
	terminal_input.placeholder_text = "Tutorial in progress..."
	
	_append_terminal_output("[color=lime]DIGITAL FORENSICS INVESTIGATION TERMINAL[/color]")
	_append_terminal_output("[color=yellow]Type 'help' for available commands[/color]")
	_append_terminal_output("============================================================")
	_append_terminal_output("")
	
	# Launch mandatory tutorial immediately
	_show_tutorial_step()

func _on_terminal_input_submitted(command_text: String):
	if command_text.strip_edges().is_empty():
		return
	
	# TUTORIAL MODE: only accept the required command
	if tutorial_mode and tutorial_manager.is_active():
		if not tutorial_manager.is_correct_command(command_text):
			_append_terminal_output("[color=red]>>> Tutorial Mode: Please execute the highlighted command above.[/color]")
			_append_terminal_output("")
			terminal_input.text = ""
			return
	
	# Echo command
	_append_terminal_output("[color=cyan]C:\\> " + command_text + "[/color]")
	
	# Parse and execute command
	var result = command_parser.parse_command(command_text, scenario_manager)
	
	if result.has("output"):
		_append_terminal_output(result.output)
	
	# Collect evidence (even during tutorial - this is part of learning!)
	if result.has("evidence"):
		evidence_manager.add_evidence(result.evidence)
		_update_evidence_list()
		_append_terminal_output("[color=yellow]>>> Evidence collected![/color]")
	
	# Always check whether we now have enough evidence
	_unlock_decision_phase()
	
	# TUTORIAL: mark step complete and show Next button
	if tutorial_mode and tutorial_manager.is_active():
		tutorial_manager.mark_step_complete()
		_show_tutorial_step()  # refresh to show Next button
	
	# Clear input
	terminal_input.text = ""
	_append_terminal_output("")

func _append_terminal_output(text: String):
	terminal_output.append_text(text + "\n")

func _update_evidence_list():
	evidence_list.clear()
	var evidences = evidence_manager.get_all_evidence()
	for ev in evidences:
		evidence_list.add_item(ev.name)

func _on_evidence_selected(index: int):
	var evidences = evidence_manager.get_all_evidence()
	if index < evidences.size():
		evidence_description.text = evidences[index].description

func _unlock_decision_phase():
	if evidence_manager.has_minimum_evidence() and not decision_panel.visible:
		decision_panel.show()
		_append_terminal_output("[color=lime]>>> You have collected sufficient evidence![/color]")
		_append_terminal_output("[color=lime]>>> Decision panel unlocked. Make your conclusion.[/color]")

func _on_submit_button_pressed():
	var attack_idx = attack_type_dropdown.selected
	var entry_idx = entry_method_dropdown.selected
	var response_idx = response_dropdown.selected
	
	if attack_idx == 0 or entry_idx == 0 or response_idx == 0:
		_append_terminal_output("[color=red]Please select all options before submitting.[/color]")
		return
	
	# Evaluate answers
	var attack_type = attack_type_dropdown.get_item_text(attack_idx)
	var entry_method = entry_method_dropdown.get_item_text(entry_idx)
	var response_action = response_dropdown.get_item_text(response_idx)
	
	score_manager.evaluate_answers(
		attack_type,
		entry_method,
		response_action,
		scenario_manager,
		evidence_manager
	)
	
	# If in tutorial, notify manager that decision was submitted
	if tutorial_mode and tutorial_manager.is_active():
		tutorial_manager.on_decision_submitted()
	
	_show_feedback()

func _show_feedback():
	current_phase = "feedback"
	terminal_panel.hide()
	evidence_panel.hide()
	objective_panel.hide()
	decision_panel.hide()
	feedback_panel.show()
	
	result_text.text = score_manager.get_feedback()
	
	# If tutorial just completed for first time, prepare mode selection
	if tutorial_mode and not tutorial_ever_completed:
		tutorial_ever_completed = true
		# Continue button will show mode selection instead of restarting
		continue_button.text = "CHOOSE GAME MODE"
		
		# Also show the final tutorial step (completion message)
		_show_tutorial_step()
	else:
		continue_button.text = "NEW INVESTIGATION"

func _on_continue_button_pressed():
	# If tutorial just finished, show mode selection screen
	if tutorial_ever_completed and not game_mode_selected:
		feedback_panel.hide()
		mode_panel.show()
		return
	
	# Otherwise, start new investigation
	evidence_manager.clear_evidence()
	score_manager.reset()
	command_parser.reset()
	terminal_output.clear()
	
	# Only replay tutorial if player explicitly wants it
	# (for now, tutorial never replays - they chose a mode)
	tutorial_mode = false
	
	_setup_initial_state()
	_load_scenario()

# ══════════════════════════════════════════════════════════════
# TUTORIAL SYSTEM – Full Game Walkthrough
# ══════════════════════════════════════════════════════════════

func _show_tutorial_step():
	"""Populate and display the current tutorial step."""
	if not tutorial_manager.is_active():
		tutorial_panel.hide()
		return
	
	var step = tutorial_manager.get_current_step()
	if step.is_empty():
		tutorial_panel.hide()
		return
	
	# Populate UI
	tutorial_title.text = step.title
	tutorial_body.text = step.body
	
	# Show or hide the clickable command box
	if step.command != "":
		tutorial_cmd_box.text = "  ▶  " + step.command
		tutorial_cmd_box.show()
	else:
		tutorial_cmd_box.hide()
	
	# Handle special phase: decision step forces decision panel to unlock
	if step.phase == "decision":
		# Override normal evidence requirement - show decision panel for tutorial
		if not decision_panel.visible:
			decision_panel.show()
			_append_terminal_output("[color=lime]>>> Decision Panel unlocked for tutorial![/color]")
			_append_terminal_output("[color=yellow]>>> Scroll down to make your selections.[/color]")
	
	# Show or hide Next button
	if tutorial_manager.can_proceed_to_next():
		if step.phase == "complete":
			tutorial_hide_btn.text = "Finish Tutorial ▶"
		else:
			tutorial_hide_btn.text = "Next ▶"
		tutorial_hide_btn.show()
	else:
		tutorial_hide_btn.hide()
	
	tutorial_panel.show()

func _on_tutorial_cmd_pressed():
	"""Auto-type the required command into terminal but don't execute — player must press Enter."""
	var step = tutorial_manager.get_current_step()
	if step.is_empty() or step.command == "":
		return
	
	# Put command in terminal input box
	terminal_input.text = step.command
	
	# Enable terminal and focus it so player can press Enter
	terminal_input.editable = true
	terminal_input.placeholder_text = "Press Enter to execute..."
	terminal_input.grab_focus()

func _on_tutorial_hide_pressed():
	"""Advance to next tutorial step or finish tutorial."""
	if not tutorial_manager.can_proceed_to_next():
		return
	
	var step = tutorial_manager.get_current_step()
	
	# If this is the completion step, finish tutorial
	if step.phase == "complete":
		_finish_tutorial()
		return
	
	tutorial_manager.advance_step()
	
	# Check if that was the last step
	if tutorial_manager.is_complete():
		_finish_tutorial()
	else:
		_show_tutorial_step()

func _finish_tutorial():
	"""Tutorial complete — but don't unlock terminal yet. Wait for decision submission and feedback."""
	tutorial_mode = false
	tutorial_manager.finish_tutorial()
	tutorial_panel.hide()
	
	# Terminal stays unlocked (was unlocked during investigation phase)
	# Player will now see their score and then choose a game mode

# ══════════════════════════════════════════════════════════════
# MODE SELECTION – Practice vs Solo
# ══════════════════════════════════════════════════════════════

func _on_practice_mode_selected():
	"""Player chose Practice Mode - hints and autofill available."""
	practice_mode = true
	game_mode_selected = true
	mode_panel.hide()
	
	# Start first real investigation
	evidence_manager.clear_evidence()
	score_manager.reset()
	command_parser.reset()
	terminal_output.clear()
	
	_setup_initial_state()
	_load_scenario()
	
	# When investigation starts, show a practice mode hint
	current_phase = "investigation"
	briefing_panel.hide()
	terminal_panel.show()
	evidence_panel.show()
	objective_panel.show()
	
	terminal_input.editable = true
	terminal_input.grab_focus()
	_append_terminal_output("[color=lime]DIGITAL FORENSICS INVESTIGATION TERMINAL[/color]")
	_append_terminal_output("[color=yellow]PRACTICE MODE ACTIVE - Type 'help' for commands[/color]")
	_append_terminal_output("============================================================")
	_append_terminal_output("")
	_append_terminal_output("[color=cyan]HINT: Start with 'whoami' then 'net user' to check accounts.[/color]")
	_append_terminal_output("")

func _on_solo_mode_selected():
	"""Player chose Solo Mode - no hints, pure challenge."""
	practice_mode = false
	game_mode_selected = true
	mode_panel.hide()
	
	# Start first real investigation
	evidence_manager.clear_evidence()
	score_manager.reset()
	command_parser.reset()
	terminal_output.clear()
	
	_setup_initial_state()
	_load_scenario()
	
	# When investigation starts, show no hints
	current_phase = "investigation"
	briefing_panel.hide()
	terminal_panel.show()
	evidence_panel.show()
	objective_panel.show()
	
	terminal_input.editable = true
	terminal_input.grab_focus()
	_append_terminal_output("[color=lime]DIGITAL FORENSICS INVESTIGATION TERMINAL[/color]")
	_append_terminal_output("[color=red]SOLO MODE - No hints. Good luck, Analyst.[/color]")
	_append_terminal_output("============================================================")
	_append_terminal_output("")

func _input(event):
	# Press ESC to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_exit_pressed()

func _on_exit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[Digital Forensics] Exit pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")