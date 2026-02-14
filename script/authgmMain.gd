extends Control

# Preload the ScenarioDatabase script
const ScenarioDatabaseScript = preload("res://script/ScenarioDatabase.gd")

# ============================================================================
# AUDIO PLAYERS - Dynamically created
# ============================================================================
var audio_panel_select: AudioStreamPlayer
var audio_panel_hover: AudioStreamPlayer
var audio_panel_drop: AudioStreamPlayer
var audio_confirm_click: AudioStreamPlayer
var audio_decision_correct: AudioStreamPlayer
var audio_decision_wrong: AudioStreamPlayer
var audio_decision_timeout: AudioStreamPlayer
var audio_trust_gain: AudioStreamPlayer
var audio_trust_loss: AudioStreamPlayer
var audio_trust_critical: AudioStreamPlayer
var audio_breach_detected: AudioStreamPlayer
var audio_timer_warning: AudioStreamPlayer
var audio_timer_tick: AudioStreamPlayer
var audio_wave_complete: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_victory: AudioStreamPlayer
var audio_ui_click: AudioStreamPlayer
var audio_start_game: AudioStreamPlayer

# Background music
var audio_bgm_intro: AudioStreamPlayer
var audio_bgm_gameplay: AudioStreamPlayer
var audio_bgm_tense: AudioStreamPlayer
var current_bgm: AudioStreamPlayer
var bgm_fade_tween: Tween

# Audio control
var audio_initialized = false
var enable_audio_test = false
var timer_warning_played = false

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
@onready var metrics_panel = $HUD/MetricsPanel
@onready var trust_bar = $HUD/MetricsPanel/VBox/TrustBar
@onready var trust_label = $HUD/MetricsPanel/VBox/TrustLabel
@onready var threats_label = $HUD/MetricsPanel/VBox/ThreatsLabel
@onready var xp_label = $HUD/MetricsPanel/VBox/XPLabel
@onready var wave_label = $HUD/MetricsPanel/VBox/WaveLabel
@onready var request_card = $RequestCard
@onready var feedback_popup = $FeedbackPopup
@onready var debrief_screen = $DebriefScreen
@onready var intro_panel = $IntroPanel
@onready var start_button = $IntroPanel/MarginContainer/VBox/StartButton
@onready var decision_bar = $DecisionBar
@onready var exit_button = $ExitButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 Gatekeeper Protocol - Loading Audio System...")
	
	_check_audio_bus_setup()
	_load_audio_files()
	
	audio_initialized = true
	
	if enable_audio_test:
		call_deferred("_test_audio_playback")
	
	# Seed random number generator
	randomize()
	
	# Initialize database
	scenario_database = ScenarioDatabaseScript.new()
	add_child(scenario_database)
	
	# Load scenarios
	all_scenarios = scenario_database.get_randomized_scenarios_by_wave()
	
	# Count attacks
	for scenario in all_scenarios:
		if scenario.is_attacker:
			total_attacks += 1
	
	# Connect signals
	request_card.decision_made.connect(_on_decision_made)
	feedback_popup.feedback_complete.connect(_on_feedback_complete)
	debrief_screen.continue_pressed.connect(_on_continue_pressed)
	debrief_screen.replay_pressed.connect(_on_replay_pressed)
	
	# Connect button sounds
	connect_button_sounds(start_button)
	connect_button_sounds(exit_button)
	
	# Make sure exit button is always on top
	if exit_button:
		exit_button.z_index = 1000
		exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Start with intro
	_show_intro()
	
	print("Game initialized with ", all_scenarios.size(), " randomized scenarios")
	print("Total attacks in game: ", total_attacks)

# ============================================================================
# AUDIO SYSTEM
# ============================================================================

func _check_audio_bus_setup():
	print("\n=== AUDIO BUS CHECK ===")
	
	for i in range(AudioServer.bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		
		if bus_name == "Master":
			if AudioServer.is_bus_mute(i):
				AudioServer.set_bus_mute(i, false)
				print("✓ Unmuted Master bus")
			
			var bus_volume = AudioServer.get_bus_volume_db(i)
			if bus_volume < -20:
				AudioServer.set_bus_volume_db(i, 0.0)
				print("✓ Reset Master bus volume")
	
	print("=== AUDIO BUS READY ===\n")

func _load_audio_files() -> void:
	print("=== LOADING AUDIO FILES ===")
	
	var sfx_path = "res://asset/minigamessoundsfx/"
	
	# PANEL INTERACTION SOUNDS
	audio_panel_select = _create_audio_player([
		sfx_path + "panel_hover.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -10.0)
	
	audio_panel_hover = _create_audio_player([
		sfx_path + "panel_select.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -16.0)
	
	audio_panel_drop = _create_audio_player([
		sfx_path + "panel_drop.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -8.0)
	
	# DECISION SOUNDS
	audio_confirm_click = _create_audio_player([
		sfx_path + "confirm_click.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -6.0)
	
	audio_decision_correct = _create_audio_player([
		sfx_path + "decision_correct.mp3",
		sfx_path + "tama.mp3",
		sfx_path + "chrisiex1-correct-156911.mp3",
	], "Master", -5.0)
	
	audio_decision_wrong = _create_audio_player([
		sfx_path + "decision_wrong.mp3",
		sfx_path + "error_buzz.wav",
		sfx_path + "wrong.mp3",
	], "Master", -4.0)
	
	audio_decision_timeout = _create_audio_player([
		sfx_path + "timeout.mp3",
		sfx_path + "alarm_danger.wav",
	], "Master", -3.0)
	
	# TRUST SCORE SOUNDS
	audio_trust_gain = _create_audio_player([
		sfx_path + "trust_gain.mp3",
		sfx_path + "tama.mp3",
	], "Master", -8.0)
	
	audio_trust_loss = _create_audio_player([
		sfx_path + "trust_loss.mp3",
		sfx_path + "heart_break.wav",
	], "Master", -6.0)
	
	audio_trust_critical = _create_audio_player([
		sfx_path + "trust_critical.mp3",
		sfx_path + "alarm_danger.wav",
	], "Master", -4.0)
	
	audio_breach_detected = _create_audio_player([
		sfx_path + "breach.mp3",
		sfx_path + "police_alert.mp3",
		sfx_path + "alarm_danger.wav",
	], "Master", -3.0)
	
	# TIMER SOUNDS
	audio_timer_warning = _create_audio_player([
		sfx_path + "timer_warning.mp3",
		sfx_path + "notification_warning.wav",
	], "Master", -8.0)
	
	audio_timer_tick = _create_audio_player([
		sfx_path + "timer_tick.mp3",
		sfx_path + "scanner_beep.wav",
	], "Master", -12.0)
	
	# GAME STATE SOUNDS
	audio_wave_complete = _create_audio_player([
		sfx_path + "wave_complete.mp3",
		sfx_path + "mission_complete.wav",
	], "Master", -5.0)
	
	audio_game_over = _create_audio_player([
		sfx_path + "sgame_over.mp3",
	], "Master", 0.0)
	
	audio_victory = _create_audio_player([
		sfx_path + "victory_fanfares.mp3",
		sfx_path + "combo_low.mp3",
	], "Master", -2.0)
	
	audio_ui_click = _create_audio_player([
		sfx_path + "panel_select.mp3",
	], "Master", -12.0)
	
	audio_start_game = _create_audio_player([
		sfx_path + "panel_select.mp3",
		sfx_path + "ui_clicksa.mp3",
	], "Master", -8.0)
	
	# BACKGROUND MUSIC
	audio_bgm_intro = _create_music_player([
		sfx_path + "auth_gameplay.mp3",
		sfx_path + "tutorial_calm.ogg",
	], "Master", -20.0)
	
	audio_bgm_gameplay = _create_music_player([
		sfx_path + "auth_gameplay.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
	], "Master", -18.0)
	
	audio_bgm_tense = _create_music_player([
		sfx_path + "auth_gameplay.mp3",
		sfx_path + "dtvsntbgsfx.mp3",
	], "Master", -16.0)
	
	print("=== AUDIO LOADING COMPLETE ===\n")

func _create_audio_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	player.autoplay = false
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("✅ " + file_path.get_file() + " (" + str(volume_db) + " dB)")
				return player
	
	print("⚠️  " + file_paths[0].get_file() + " not found")
	return player

func _create_music_player(file_paths: Array, bus: String, volume_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = -80.0
	player.autoplay = false
	add_child(player)
	
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			var audio_stream = load(file_path)
			if audio_stream:
				player.stream = audio_stream
				print("🎵 " + file_path.get_file() + " (" + str(volume_db) + " dB target)")
				
				if audio_stream is AudioStreamMP3:
					audio_stream.loop = true
				elif audio_stream is AudioStreamOggVorbis:
					audio_stream.loop = true
				elif audio_stream is AudioStreamWAV:
					audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				
				player.set_meta("target_volume", volume_db)
				return player
	
	print("⚠️  BGM not found")
	return player

func _test_audio_playback():
	print("\n=== TESTING AUDIO ===")
	await get_tree().create_timer(1.0).timeout
	
	if audio_ui_click and audio_ui_click.stream:
		print("🔊 Playing test click...")
		_play_sfx(audio_ui_click, 0, 1.0)
	
	print("=== TEST COMPLETE ===\n")

func _play_sfx(sfx_player: AudioStreamPlayer, pitch_variation: float = 0.0, base_pitch: float = 1.0) -> void:
	if not audio_initialized or not sfx_player or not sfx_player.stream:
		return
	
	if sfx_player.playing:
		sfx_player.stop()
	
	if pitch_variation > 0:
		sfx_player.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	else:
		sfx_player.pitch_scale = base_pitch
	
	sfx_player.play()

func _play_bgm(bgm_player: AudioStreamPlayer, fade_in_duration: float = 2.0):
	if not audio_initialized or not bgm_player or not bgm_player.stream:
		return
	
	if current_bgm and current_bgm.playing and current_bgm != bgm_player:
		await _fade_out_bgm(1.0)
	
	current_bgm = bgm_player
	var target_volume = bgm_player.get_meta("target_volume", -18.0)
	
	bgm_player.volume_db = -80.0
	bgm_player.play()
	
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(bgm_player, "volume_db", target_volume, fade_in_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func _fade_out_bgm(duration: float = 1.5):
	if not current_bgm or not current_bgm.playing:
		return
	
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(current_bgm, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await bgm_fade_tween.finished
	current_bgm.stop()

func connect_button_sounds(button: Button):
	if not button:
		return
	
	if button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.disconnect(_on_button_hover)
	if button.pressed.is_connected(_on_button_press):
		button.pressed.disconnect(_on_button_press)
	
	button.mouse_entered.connect(_on_button_hover)
	button.pressed.connect(_on_button_press)

func _on_button_hover():
	_play_sfx(audio_ui_click, 0.1, 0.7)

func _on_button_press():
	_play_sfx(audio_ui_click, 0.05, 1.0)

# ============================================================================
# PUBLIC METHODS FOR OTHER SCRIPTS TO CALL
# ============================================================================

func play_panel_select_sound():
	_play_sfx(audio_panel_select, 0.05, 1.0)

func play_panel_hover_sound():
	_play_sfx(audio_panel_hover, 0.1, 1.0)

func play_panel_drop_sound():
	_play_sfx(audio_panel_drop, 0, 1.0)

func play_confirm_click_sound():
	_play_sfx(audio_confirm_click, 0, 1.0)

# ============================================================================
# GAME LOGIC
# ============================================================================

func _show_intro():
	current_state = GameState.INTRO
	intro_panel.visible = true
	request_card.visible = false
	feedback_popup.visible = false
	debrief_screen.visible = false
	hud.visible = false
	decision_bar.visible = false
	metrics_panel.visible = false
	
	# Play intro BGM
	_play_bgm(audio_bgm_intro, 2.0)

func _on_start_pressed():
	_play_sfx(audio_start_game, 0, 1.0)
	
	intro_panel.visible = false
	hud.visible = true
	decision_bar.visible = true
	metrics_panel.visible = true
	
	# Fade to gameplay music
	await _fade_out_bgm(1.0)
	await get_tree().create_timer(0.5).timeout
	_play_bgm(audio_bgm_gameplay, 2.0)
	
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
	
	# Re-randomize scenarios on each new game
	all_scenarios = scenario_database.get_randomized_scenarios_by_wave()
	
	# Recount attacks
	total_attacks = 0
	for scenario in all_scenarios:
		if scenario.is_attacker:
			total_attacks += 1
	
	print("\n=== NEW GAME STARTED ===")
	print("Scenarios shuffled: ", all_scenarios.size())
	print("Total attacks: ", total_attacks)
	print("========================\n")
	
	_update_hud()
	_show_next_scenario()

func _show_next_scenario():
	if current_scenario_index >= all_scenarios.size():
		_show_debrief()
		return
	
	current_state = GameState.PLAYING
	timer_warning_played = false
	
	var scenario = all_scenarios[current_scenario_index]
	current_wave = scenario.wave
	
	# Switch to tense music on higher waves
	if current_wave >= 5 and current_bgm != audio_bgm_tense:
		await _fade_out_bgm(1.0)
		_play_bgm(audio_bgm_tense, 2.0)
	
	request_card.visible = true
	request_card.setup(scenario)
	
	_update_hud()

func _process(_delta):
	# Play timer warning sound at 5 seconds
	if current_state == GameState.PLAYING and not timer_warning_played:
		if request_card and request_card.time_remaining <= 5.0 and request_card.time_remaining > 4.9:
			_play_sfx(audio_timer_warning, 0, 1.0)
			timer_warning_played = true
	
	# Play tick sound at 3 seconds and below
	if current_state == GameState.PLAYING:
		if request_card and request_card.time_remaining <= 3.0:
			var time_int = int(request_card.time_remaining)
			if time_int != int(request_card.time_remaining + _delta):
				_play_sfx(audio_timer_tick, 0.1, 1.0)

func _on_decision_made(action: String, scenario: Scenario):
	current_state = GameState.FEEDBACK
	total_scenarios += 1
	
	var is_correct = false
	var score_change = 0
	var feedback_message = ""
	
	# Handle timeout
	if action == "timeout":
		_play_sfx(audio_decision_timeout, 0, 1.0)
		is_correct = false
		trust_score -= 15
		feedback_message = "Time expired! Auto-denied for safety. Be faster in real incidents."
		_play_sfx(audio_trust_loss, 0, 1.0)
	else:
		# Check if decision was correct
		is_correct = (action == scenario.correct_action)
		
		if is_correct:
			# CORRECT DECISION
			_play_sfx(audio_decision_correct, 0.1, 1.0)
			
			correct_decisions += 1
			score_change = 15
			trust_score += score_change
			xp += 10
			feedback_message = scenario.feedback_correct
			
			_play_sfx(audio_trust_gain, 0, 1.0)
			
			if scenario.is_attacker:
				attacks_blocked += 1
		else:
			# WRONG DECISION
			_play_sfx(audio_decision_wrong, 0, 1.0)
			
			trust_score -= scenario.threat_consequence
			feedback_message = scenario.feedback_incorrect
			
			_play_sfx(audio_trust_loss, 0, 1.0)
			
			# Breach detected sound
			if scenario.is_attacker:
				_play_sfx(audio_breach_detected, 0, 1.0)
			
			# False denial tracking
			if not scenario.is_attacker and action == "deny":
				false_denials += 1
	
	# Clamp trust score
	trust_score = clampi(trust_score, 0, 100)
	
	# Critical trust warning
	if trust_score < 30:
		_play_sfx(audio_trust_critical, 0, 1.0)
	
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
	_play_sfx(audio_game_over, 0, 1.0)
	await _fade_out_bgm(2.0)
	
	# ✅ AWARD PARTIAL XP ON LOSS (Based on performance)
	var accuracy = (float(correct_decisions) / float(total_scenarios)) * 100.0 if total_scenarios > 0 else 0.0
	
	var wave_xp = current_wave * 5  # 5 XP per wave reached (vs 6 on win)
	var accuracy_xp = int((accuracy / 100.0) * 25)  # Up to 25 XP from accuracy (vs 40 on win)
	var trust_xp = int((trust_score / 100.0) * 15)  # Up to 15 XP from trust (vs 30 on win)
	var attack_xp = int((float(attacks_blocked) / float(total_attacks)) * 10) if total_attacks > 0 else 0  # Up to 10 XP (vs 20 on win)
	var partial_xp = wave_xp + accuracy_xp + trust_xp + attack_xp
	
	print("[Security Guardian] 💀 Game Over - Awarding partial XP:")
	print("  Wave XP: %d (wave %d)" % [wave_xp, current_wave])
	print("  Accuracy XP: %d (%.1f%% accuracy)" % [accuracy_xp, accuracy])
	print("  Trust XP: %d (trust %d)" % [trust_xp, trust_score])
	print("  Attack XP: %d (%d/%d blocked)" % [attack_xp, attacks_blocked, total_attacks])
	print("  Total Partial XP: %d" % partial_xp)
	
	# Award XP but DON'T mark as completed
	TutorialManager.add_xp(partial_xp, "Security Guardian (Attempt)")
	
	debrief_screen.visible = true
	metrics_panel.visible = false
	debrief_screen.show_debrief(
		total_scenarios,
		correct_decisions,
		attacks_blocked,
		total_attacks,
		false_denials,
		trust_score,
		partial_xp  # Show partial XP instead of 0
	)

func _show_debrief():
	current_state = GameState.DEBRIEF
	request_card.visible = false
	feedback_popup.visible = false
	decision_bar.visible = false
	metrics_panel.visible = false
	debrief_screen.visible = true
	
	# ✅ AWARD XP BASED ON PERFORMANCE (First-time only)
	var accuracy = 0.0
	if total_scenarios > 0:
		accuracy = (float(correct_decisions) / float(total_scenarios)) * 100.0
	var base_xp = 70  # Base XP for completing the game
	var wave_xp = current_wave * 6  # 6 XP per wave completed
	var accuracy_xp = int((accuracy / 100.0) * 40)  # Up to 40 XP from accuracy
	var trust_xp = int((trust_score / 100.0) * 30)  # Up to 30 XP from trust score
	var attack_xp = int((float(attacks_blocked) / float(total_attacks)) * 20) if total_attacks > 0 else 0  # Up to 20 XP
	var total_xp_earned = base_xp + wave_xp + accuracy_xp + trust_xp + attack_xp
	
	print("[Security Guardian] 🎯 Victory! Awarding XP:")
	print("  Base XP: %d" % base_xp)
	print("  Wave XP: %d (waves %d)" % [wave_xp, current_wave])
	print("  Accuracy XP: %d (accuracy %.1f%%)" % [accuracy_xp, accuracy])
	print("  Trust XP: %d (trust %d)" % [trust_xp, trust_score])
	print("  Attack XP: %d (%d/%d blocked)" % [attack_xp, attacks_blocked, total_attacks])
	print("  Total XP: %d" % total_xp_earned)
	
	var final_score = total_scenarios  # Use scenarios completed as score
	var xp_awarded = TutorialManager.award_minigame_xp("security_guardian", total_xp_earned, final_score)
	if xp_awarded == 0:
		print("  ⚠️ Replay - No XP awarded (game still playable!)")
	
	# Victory sound
	_play_sfx(audio_victory, 0, 1.0)
	await _fade_out_bgm(2.0)
	
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
	_play_sfx(audio_ui_click, 0, 1.0)
	await _fade_out_bgm(0.5)
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _on_replay_pressed():
	_play_sfx(audio_ui_click, 0, 1.0)
	debrief_screen.visible = false
	metrics_panel.visible = true
	
	# Restart with intro music
	_play_bgm(audio_bgm_intro, 2.0)
	
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

# ============================================================================
# EXIT FUNCTIONALITY
# ============================================================================

func _input(event):
	# Press ESC to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_exit_pressed()

func _on_exit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[Gatekeeper Protocol] Exit button pressed, returning to mode selection...")
	
	# Play exit sound
	_play_sfx(audio_ui_click, 0, 1.0)
	
	# Fade out music
	await _fade_out_bgm(0.5)
	
	print("[DEBUG] About to change scene...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	print("[DEBUG] Scene change called")