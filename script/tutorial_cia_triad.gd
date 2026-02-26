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
@onready var quit_btn: Button = $CanvasLayer/TopPanel/Button

# CIA Zone tooltips
@onready var c_tooltip: Label = $CanvasLayer/CIAZones/ConfidentialityZone/TooltipLabel
@onready var i_tooltip: Label = $CanvasLayer/CIAZones/IntegrityZone/TooltipLabel
@onready var a_tooltip: Label = $CanvasLayer/CIAZones/AvailabilityZone/TooltipLabel

# Audio - Created dynamically in code
var sfx_correct: AudioStreamPlayer
var sfx_wrong: AudioStreamPlayer
var bgm_player: AudioStreamPlayer

# Background music settings
const BGM_NORMAL_VOLUME := -10.0  # Normal background music volume in dB
const BGM_FADE_VOLUME := -25.0    # Faded (quiet) volume in dB
const BGM_FADE_DURATION := 2.0    # How long the fade takes in seconds
const BGM_FADE_BEFORE_LOOP := 3.0 # Start fading X seconds before loop ends

# ALL AVAILABLE SCENARIOS (will be shuffled each game)
const ALL_SCENARIOS = [
	# CONFIDENTIALITY scenarios
	{
		"text": "Someone broke into the hospital's computer system using a weak password. Now personal medical records of 10,000 patients can be seen by anyone on the internet.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nConfidentiality means keeping sensitive data PRIVATE. Patient records were exposed to unauthorized people—this breaks confidentiality."
	},
	{
		"text": "A laptop was stolen from a coffee shop. Inside the laptop were company financial reports and customer credit card information that weren't password-protected.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nThe sensitive financial data can now be SEEN by unauthorized people (the thief). Confidentiality breach!"
	},
	{
		"text": "An employee found a USB flash drive in the parking lot labeled 'Employee Salaries 2025' and plugged it into their work computer. A hidden virus copied company files and sent them to criminals on the internet.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nThe virus STOLE and SENT files to attackers. Private data was exposed to unauthorized parties."
	},
	{
		"text": "A hacker intercepted unencrypted emails containing social security numbers and bank account details of 500 customers.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nSensitive customer data was EXPOSED to unauthorized parties through interception."
	},
	{
		"text": "An employee accidentally sent an email with the entire customer database to a wrong recipient outside the company.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nConfidential customer information was DISCLOSED to unauthorized external parties."
	},
	{
		"text": "Security cameras caught someone taking photos of confidential documents displayed on unattended computer screens in the office.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nConfidential information was ACCESSED and potentially copied by unauthorized individuals."
	},
	{
		"text": "A company's internal chat logs discussing unreleased product designs were leaked to a competitor through a former employee.",
		"correct": "C",
		"explanation": "✅ Correct! This is a [color=cyan]CONFIDENTIALITY[/color] breach.\n\nProprietary information was DISCLOSED to competitors, violating confidentiality."
	},
	
	# INTEGRITY scenarios
	{
		"text": "Someone hacked the school's computer and changed 20 students' report card grades from C to A without permission.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nIntegrity means keeping data ACCURATE and UNCHANGED. The grades were modified incorrectly—this breaks integrity."
	},
	{
		"text": "Attackers broke into the company website and replaced the homepage with spray paint-style graffiti and posted fake news about the CEO.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nIntegrity means data stays CORRECT and TRUSTWORTHY. The website content was tampered with—breaking integrity."
	},
	{
		"text": "A malicious insider modified the prices in the online store database, changing $1,000 items to $1 before making purchases.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nThe product pricing data was ALTERED without authorization, compromising data integrity."
	},
	{
		"text": "Hackers modified bank account balances in the system, transferring money to fake accounts they created.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nFinancial records were TAMPERED with, making the data inaccurate and untrustworthy."
	},
	{
		"text": "An attacker altered the timestamp logs in the security system to hide evidence of when they broke into the building.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nAudit logs were MODIFIED to conceal unauthorized activity, destroying data integrity."
	},
	{
		"text": "Someone intercepted a payment transaction and changed the recipient's bank account number to redirect the funds.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nTransaction data was ALTERED during transmission, compromising its accuracy."
	},
	{
		"text": "A disgruntled employee modified customer shipping addresses in the database, causing orders to be sent to wrong locations.",
		"correct": "I",
		"explanation": "✅ Correct! This is an [color=yellow]INTEGRITY[/color] breach.\n\nCustomer data was CORRUPTED through unauthorized modifications."
	},
	
	# AVAILABILITY scenarios
	{
		"text": "A virus locked all the company's files and demands payment to unlock them. Workers can't open emails, check payroll, or access any documents. Everything has been blocked for 2 days.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nAvailability means keeping systems ACCESSIBLE when needed. The virus didn't steal or change data—it blocked access to it."
	},
	{
		"text": "Attackers flooded the online shopping website with millions of fake visitors at once. Real customers can't load the website or buy anything because it's too overloaded.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe website is BLOCKED from legitimate users. The data wasn't stolen or changed—just made inaccessible."
	},
	{
		"text": "The company's backup storage system broke during a building fire. When they tried to recover their data afterwards, they realized nothing was saved for the past 6 months—all that work is now gone forever.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe data couldn't be ACCESSED when needed. Even though the original data wasn't stolen or changed, it became unavailable due to lack of proper backups."
	},
	{
		"text": "A power outage caused the hospital's patient monitoring systems to go offline for 3 hours, preventing doctors from accessing vital patient information.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nCritical systems were UNAVAILABLE when needed, even though data wasn't stolen or modified."
	},
	{
		"text": "Hackers crashed the airline's booking system during peak holiday season, preventing customers from purchasing tickets for 48 hours.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe service was DISRUPTED and inaccessible to legitimate users."
	},
	{
		"text": "A construction crew accidentally cut the fiber optic cable, causing the company's internet and cloud services to be down for an entire day.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nNetwork services became UNAVAILABLE, preventing access to business systems."
	},
	{
		"text": "A misconfigured update caused the email server to crash. Employees couldn't send or receive emails for the entire morning shift.",
		"correct": "A",
		"explanation": "✅ Correct! This is an [color=green]AVAILABILITY[/color] breach.\n\nThe email service was INACCESSIBLE due to system failure."
	}
]

# Game state
var current_scenario_index := 0
var score := 0
var streak := 0
var shuffled_scenarios := []  # Will hold randomized scenarios for this game
const SCENARIOS_PER_GAME := 10  # How many scenarios to show per game
const POINTS_PER_CORRECT := 30  # Changed from 100 to 30

# Drag state
var dragging := false
var drag_offset := Vector2.ZERO
var card_original_position := Vector2.ZERO

# Tutorial ID for TutorialManager
const TUTORIAL_ID := "cia_triad_basics"

# Multiplayer game mode state
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0


func _ready() -> void:
	print("[CIA Triad] Tutorial scene ready!")
	
	# Detect multiplayer game mode
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code"))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", Time.get_ticks_msec()))
		print("[GameMode] Running in multiplayer mode — room: %s" % _gamemode_room_code)
	
	# FIX MASTER BUS VOLUME FIRST!
	_fix_audio_bus()
	
	# CREATE AUDIO PLAYERS DYNAMICALLY IN CODE
	_setup_audio()
	
	# START BACKGROUND MUSIC
	_start_background_music()
	
	# SHUFFLE SCENARIOS FOR THIS GAME SESSION
	_shuffle_scenarios()
	
	# Hide popups initially
	feedback_popup.hide()
	results_screen.hide()
	
	# Store original card position
	card_original_position = incident_card.position
	
	# Connect signals
	try_again_btn.pressed.connect(_on_try_again_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# In multiplayer mode: hide quit button, start time is tracked
	if _is_gamemode:
		quit_btn.visible = false

	# Setup tooltips
	_setup_tooltips()
	
	# Setup keyboard shortcuts
	set_process_input(true)
	
	# Load first scenario
	_load_scenario()
	
	# Update display
	_update_ui()


func _process(delta: float) -> void:
	"""Monitor background music for smooth looping with fade"""
	if bgm_player and bgm_player.playing:
		var stream_length = bgm_player.stream.get_length()
		var current_position = bgm_player.get_playback_position()
		var time_remaining = stream_length - current_position
		
		# Start fade out before loop ends
		if time_remaining <= BGM_FADE_BEFORE_LOOP and time_remaining > BGM_FADE_BEFORE_LOOP - 0.1:
			_fade_bgm_for_loop()


func _shuffle_scenarios() -> void:
	"""Shuffle scenarios and select a random subset for this game"""
	print("[DEBUG] Shuffling scenarios...")
	
	# Create a copy of all scenarios
	var all_scenarios_copy = ALL_SCENARIOS.duplicate()
	
	# Shuffle the array using Fisher-Yates algorithm
	randomize()  # Seed random number generator
	for i in range(all_scenarios_copy.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = all_scenarios_copy[i]
		all_scenarios_copy[i] = all_scenarios_copy[j]
		all_scenarios_copy[j] = temp
	
	# Take first SCENARIOS_PER_GAME scenarios
	shuffled_scenarios = all_scenarios_copy.slice(0, SCENARIOS_PER_GAME)
	
	print("[DEBUG] Selected %d random scenarios from %d total scenarios" % [shuffled_scenarios.size(), ALL_SCENARIOS.size()])


func _fix_audio_bus() -> void:
	"""Fix the Master audio bus volume if it's too low"""
	var master_bus_index = AudioServer.get_bus_index("Master")
	var current_volume = AudioServer.get_bus_volume_db(master_bus_index)
	
	print("[DEBUG] Current Master bus volume: ", current_volume, " dB")
	
	# If volume is below -20 dB, it's probably muted/too quiet
	if current_volume < -20.0:
		print("[WARNING] Master bus volume is TOO LOW (", current_volume, " dB)")
		print("[FIX] Setting Master bus to 0 dB (normal volume)")
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)
		print("[DEBUG] New Master bus volume: ", AudioServer.get_bus_volume_db(master_bus_index), " dB")
	else:
		print("[DEBUG] Master bus volume is fine")


func _setup_audio() -> void:
	"""Create and configure audio players dynamically in code"""
	print("[DEBUG] Setting up audio players in code...")
	
	# Create CORRECT sound effect player
	sfx_correct = AudioStreamPlayer.new()
	sfx_correct.name = "SFX_Correct_Dynamic"
	
	# Load the audio stream
	var correct_stream = load("res://asset/minigamessoundsfx/corrects.mp3")
	if correct_stream:
		sfx_correct.stream = correct_stream
		sfx_correct.volume_db = -9.397
		sfx_correct.bus = "Master"
		add_child(sfx_correct)
		print("[DEBUG] ✓ Correct SFX loaded")
	else:
		print("[ERROR] ✗ Failed to load correct SFX")
	
	# Create WRONG sound effect player
	sfx_wrong = AudioStreamPlayer.new()
	sfx_wrong.name = "SFX_Wrong_Dynamic"
	
	# Load the audio stream
	var wrong_stream = load("res://asset/minigamessoundsfx/wrong.mp3")
	if wrong_stream:
		sfx_wrong.stream = wrong_stream
		sfx_wrong.volume_db = -9.397
		sfx_wrong.bus = "Master"
		add_child(sfx_wrong)
		print("[DEBUG] ✓ Wrong SFX loaded")
	else:
		print("[ERROR] ✗ Failed to load wrong SFX")
	
	# Create BACKGROUND MUSIC player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGM_Player_Dynamic"
	
	# Try to load background music (replace with your music file path)
	var bgm_stream = load("res://asset/minigamessoundsfx/ciabg.mp3")  # CHANGE THIS PATH
	if bgm_stream:
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = BGM_NORMAL_VOLUME
		bgm_player.bus = "Master"
		add_child(bgm_player)
		print("[DEBUG] ✓ Background music loaded")
	else:
		print("[WARNING] Background music not found at res://asset/minigamessoundsfx/ciabg.mp3")
		print("[INFO] Looking for alternative music files...")
		
		# Try alternative paths
		var alternative_paths = [
			"res://asset/minigamessoundsfx/bgm.mp3",
			"res://asset/minigamessoundsfx/background.mp3",
			"res://asset/minigamessoundsfx/music.mp3",
			"res://asset/minigamessoundsfx/game_music.ogg",
		]
		
		for path in alternative_paths:
			bgm_stream = load(path)
			if bgm_stream:
				bgm_player.stream = bgm_stream
				bgm_player.volume_db = BGM_NORMAL_VOLUME
				bgm_player.bus = "Master"
				add_child(bgm_player)
				print("[DEBUG] ✓ Background music loaded from: ", path)
				break
		
		if not bgm_player.stream:
			print("[WARNING] No background music found - game will run without BGM")


func _start_background_music() -> void:
	"""Start playing background music with fade-in"""
	if bgm_player and bgm_player.stream:
		print("[DEBUG] Starting background music with fade-in...")
		
		# Start at very low volume
		bgm_player.volume_db = -80.0
		bgm_player.play()
		
		# Fade in to normal volume
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", BGM_NORMAL_VOLUME, BGM_FADE_DURATION)
		
		print("[DEBUG] Background music started")
	else:
		print("[INFO] No background music to play")


func _fade_bgm_for_loop() -> void:
	"""Fade BGM out and back in for smooth looping"""
	if not bgm_player or not bgm_player.playing:
		return
	
	print("[DEBUG] Fading BGM for smooth loop...")
	
	# Create fade out tween
	var fade_out = create_tween()
	fade_out.tween_property(bgm_player, "volume_db", BGM_FADE_VOLUME, BGM_FADE_DURATION / 2)
	
	# Wait for fade out to complete, then fade back in
	await fade_out.finished
	
	# Create fade in tween
	var fade_in = create_tween()
	fade_in.tween_property(bgm_player, "volume_db", BGM_NORMAL_VOLUME, BGM_FADE_DURATION / 2)


func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the tutorial"""
	if _is_gamemode:
		return  # Cannot quit during multiplayer game
	print("[CIA Triad] Quit button pressed, returning to mode selection...")
	
	# Fade out music before leaving
	if bgm_player and bgm_player.playing:
		var fade_out = create_tween()
		fade_out.tween_property(bgm_player, "volume_db", -80.0, 0.5)
		await fade_out.finished
		bgm_player.stop()
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


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
		if _is_gamemode:
			return  # Cannot quit during multiplayer game
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
	if current_scenario_index >= shuffled_scenarios.size():
		_show_results()
		return
	
	var scenario = shuffled_scenarios[current_scenario_index]
	incident_text.text = "[center]🚨 [b]INCIDENT ALERT #%d[/b] 🚨[/center]\n\n%s" % [current_scenario_index + 1, scenario["text"]]
	
	# Reset card position and appearance
	incident_card.position = card_original_position
	incident_card.modulate = Color.WHITE
	incident_card.show()
	
	print("[CIA Triad] Loaded scenario %d/%d" % [current_scenario_index + 1, shuffled_scenarios.size()])


func _update_ui() -> void:
	"""Update score and streak display"""
	var max_score = shuffled_scenarios.size() * POINTS_PER_CORRECT
	score_label.text = "Score: %d/%d" % [score, max_score]
	
	if streak > 0:
		streak_label.text = "Streak: %d 🔥" % streak
	else:
		streak_label.text = "Streak: 0"


func _check_answer(zone_type: String) -> void:
	"""Check if the selected zone is correct"""
	var scenario = shuffled_scenarios[current_scenario_index]
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
	if sfx_correct and sfx_correct.stream:
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
	if sfx_wrong and sfx_wrong.stream:
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
	var scenario = shuffled_scenarios[current_scenario_index]
	
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
	var max_score = shuffled_scenarios.size() * POINTS_PER_CORRECT
	print("[CIA Triad] Tutorial complete! Score: %d/%d" % [score, max_score])
	
	# Hide game UI
	incident_card.hide()
	
	# Calculate percentage
	var percentage = (float(score) / float(max_score)) * 100.0
	
	# Determine grade and XP (always award some XP for effort)
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
		xp_earned = max(int(percentage * 0.5), 10)  # At least 10 XP for trying, scales with performance
	
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
	TutorialManager.save_tutorial_result(TUTORIAL_ID, score, max_score)
	
	# Show results screen
	results_screen.show()
	
	# In multiplayer game mode: change button text and auto-submit score
	if _is_gamemode:
		back_btn.text = "View Leaderboard"
		_submit_gamemode_score()


func _on_back_pressed() -> void:
	"""Return to mode selection"""
	if _is_gamemode:
		# In game mode, back from results goes to leaderboard
		_submit_gamemode_score()
		return
	print("[CIA Triad] Returning to mode selection...")
	
	# Fade out music before leaving
	if bgm_player and bgm_player.playing:
		var fade_out = create_tween()
		fade_out.tween_property(bgm_player, "volume_db", -80.0, 0.5)
		await fade_out.finished
		bgm_player.stop()
	
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


func _on_button_pressed() -> void:
	pass # Replace with function body.

# ===================================================
# MULTIPLAYER GAME MODE
# ===================================================
var _gamemode_submitted: bool = false

func _submit_gamemode_score() -> void:
	"""Submit score and time to server for multiplayer game mode"""
	if not _is_gamemode or _gamemode_room_code.is_empty():
		return
	if _gamemode_submitted:
		# Already submitted — go to leaderboard scene
		_go_to_gamemode_leaderboard()
		return
	_gamemode_submitted = true

	var max_score_val = shuffled_scenarios.size() * POINTS_PER_CORRECT
	var time_taken_ms: int = Time.get_ticks_msec() - _gamemode_start_time_ms

	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := {
		"player_id": Auth.current_local_id,
		"score": score,
		"max_score": max_score_val,
		"time_taken_ms": time_taken_ms,
	}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[GameMode] ✅ Score submitted: %d/%d in %dms" % [score, max_score_val, time_taken_ms])
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_error("[GameMode] ❌ Failed to submit score: %d %s" % [code, err_text])
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("[GameMode] ❌ HTTP request failed: %d" % err)
		http.queue_free()

func _go_to_gamemode_leaderboard() -> void:
	"""Navigate to the game mode leaderboard scene"""
	# Pass info via tree meta
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)

	# Fade out music
	if bgm_player and bgm_player.playing:
		var fade_out = create_tween()
		fade_out.tween_property(bgm_player, "volume_db", -80.0, 0.5)
		await fade_out.finished
		bgm_player.stop()

	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")

func _get_lobby_url_gm() -> String:
	if has_node("/root/MultiplayerConfig"):
		return get_node("/root/MultiplayerConfig").get_lobby_url()
	var cfg_script = load("res://script/MultiplayerConfig.gd")
	if cfg_script:
		var cfg = cfg_script.new()
		return cfg.get_lobby_url()
	return "https://codebreaker-lobby.onrender.com"
