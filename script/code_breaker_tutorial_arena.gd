# CodeBreakerTutorialArena.gd
# Tutorial version of Code Breaker arena - same assets, AI bot opponent
extends Control

# Tutorial state
var tutorial_guide: CanvasLayer = null
var tutorial_completed := false
var match_started := false
var in_tutorial_phase := true

# AI Bot Timer
var ai_type_timer: Timer = null
var ai_current_char_index := 0
var ai_typing_active := false

# ===== SAME UI REFERENCES AS REAL ARENA =====
@onready var _host_name_label: Label = $HeaderPanel/HostNameLabel
@onready var _timer_label: Label = $HeaderPanel/TimerLabel
@onready var _client_name_label: Label = $HeaderPanel/ClientNameLabel
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _p1_score: Label = $VBox/ScorePanel/ScoreP1
@onready var _p2_score: Label = $VBox/ScorePanel/ScoreP2
@onready var _p1_health: ProgressBar = $VBox/ScorePanel/P1HealthBar
@onready var _p2_health: ProgressBar = $VBox/ScorePanel/P2HealthBar
@onready var _p1_title: Label = $VBox/ScorePanel/Player1Title
@onready var _p2_title: Label = $VBox/ScorePanel/Player2Title
@onready var _code_display: RichTextLabel = $VBox/CodeDisplayPanel/CodeDisplay
@onready var _input_field: LineEdit = $VBox/InputField
@onready var _code_panel: Panel = $VBox/CodeDisplayPanel
@onready var _snippet_timer_label: Label = $VBox/CodeDisplayPanel/SnippetTimer
@onready var _countdown_label: Label = $CountdownLabel
@onready var _battle_music: AudioStreamPlayer = $BattleMusic
@onready var _pop_sound: AudioStreamPlayer = $PopSound
@onready var _menu_btn: Button = $MenuButton

# Power-up Panels
@onready var _default_panel: Sprite2D = $VBox/CodeDisplayPanel/DefaultPanel
@onready var _heal_panel: Sprite2D = $"VBox/CodeDisplayPanel/HealPanel()"
@onready var _freeze_panel: Sprite2D = $"VBox/CodeDisplayPanel/FreezTime(iceBlue)Panel"
@onready var _extend_panel: Sprite2D = $"VBox/CodeDisplayPanel/ExtendTime(yellow)Panel"
@onready var _defensive_panel: Sprite2D = $"VBox/CodeDisplayPanel/DefensivePanel(grey)"

# ===== SAME CONSTANTS AS REAL ARENA =====
const STARTING_HEALTH := 100
const SCORE_CORRECT := 100
const DAMAGE_TO_ENEMY := 10
const SELF_DAMAGE_PENALTY := 8
const SNIPPET_TIME_LIMIT := 15.0
const GAME_DURATION := 180.0 # 3 minutes

# AI Bot settings (slower than real players)
const AI_MIN_CHAR_DELAY := 0.15
const AI_MAX_CHAR_DELAY := 0.35
const AI_TYPO_CHANCE := 0.08 # 8% chance to make a typo

# Game state
var player_health := STARTING_HEALTH
var player_score := 0
var ai_health := STARTING_HEALTH
var ai_score := 0
var _game_active := false
var _match_start_time := 0.0

# Snippet data
var _snippet_list: Array[String] = []
var _current_snippet_index := 0
var _code_snippet := ""
var _snippet_time_remaining := SNIPPET_TIME_LIMIT
var _snippet_timer_active := false

# Timers
var _game_timer: Timer = null
var _snippet_timer: Timer = null

signal match_completed(player_won: bool)

func _ready() -> void:
	print("[CBTutorialArena] Tutorial Arena ready")
	
	# Hide menu button for tutorial
	if _menu_btn:
		_menu_btn.visible = false
	
	# Set names
	if _host_name_label:
		var username = Auth.current_username if Auth and Auth.current_username != "" else "AGENT"
		_host_name_label.text = username.to_upper()
	if _client_name_label:
		_client_name_label.text = "CYBER BOT"
	
	# Setup input
	if _input_field:
		_input_field.text_submitted.connect(_on_input_submitted)
		_input_field.editable = false # Disabled until match starts
	
	# Initialize health bars
	if _p1_health:
		_p1_health.min_value = 0
		_p1_health.max_value = STARTING_HEALTH
		_p1_health.value = STARTING_HEALTH
	if _p2_health:
		_p2_health.min_value = 0
		_p2_health.max_value = STARTING_HEALTH
		_p2_health.value = STARTING_HEALTH
	
	# Setup timers
	_setup_timers()
	
	# Generate snippets
	_generate_snippet_list()
	
	# Initialize power-up panels
	_reset_powerup_panels()
	
	# Update UI
	_update_ui()
	
	# Start tutorial guide
	_load_tutorial_guide()

func _setup_timers() -> void:
	# Game timer (updates display every 100ms)
	_game_timer = Timer.new()
	_game_timer.wait_time = 0.1
	_game_timer.timeout.connect(_on_game_timer_tick)
	add_child(_game_timer)
	
	# Snippet timer
	_snippet_timer = Timer.new()
	_snippet_timer.wait_time = 0.1
	_snippet_timer.timeout.connect(_on_snippet_timer_tick)
	add_child(_snippet_timer)
	
	# AI typing timer
	ai_type_timer = Timer.new()
	ai_type_timer.one_shot = true
	ai_type_timer.timeout.connect(_on_ai_type_char)
	add_child(ai_type_timer)

func _reset_powerup_panels() -> void:
	if _default_panel:
		_default_panel.visible = true
	if _heal_panel:
		_heal_panel.visible = false
	if _freeze_panel:
		_freeze_panel.visible = false
	if _extend_panel:
		_extend_panel.visible = false
	if _defensive_panel:
		_defensive_panel.visible = false

func _load_tutorial_guide() -> void:
	print("[CBTutorialArena] Loading tutorial guide...")
	var guide_scene = load("res://scene/code_breaker_tutorial_guide.tscn")
	if guide_scene:
		tutorial_guide = guide_scene.instantiate()
		add_child(tutorial_guide)
		
		# Connect signals
		tutorial_guide.start_practice_match.connect(_on_start_practice_match)
		tutorial_guide.tutorial_skipped.connect(_on_tutorial_skipped)
		
		# Start tutorial
		var username = Auth.current_username if Auth and Auth.current_username != "" else "Agent"
		tutorial_guide.start_tutorial(self, username)
	else:
		push_warning("[CBTutorialArena] Could not load tutorial guide")
		_start_match()

func _on_start_practice_match() -> void:
	print("[CBTutorialArena] Starting practice match after tutorial...")
	in_tutorial_phase = false
	_start_match()

func _on_tutorial_skipped() -> void:
	print("[CBTutorialArena] Tutorial skipped, starting match...")
	in_tutorial_phase = false
	_start_match()

func _start_match() -> void:
	if match_started:
		return
	
	match_started = true
	
	# Show countdown
	await _show_countdown()
	
	# Start game
	_game_active = true
	_match_start_time = Time.get_ticks_msec() / 1000.0
	
	# Enable input
	if _input_field:
		_input_field.editable = true
		_input_field.grab_focus()
	
	# Show first snippet
	_show_current_snippet()
	
	# Start timers
	_game_timer.start()
	_snippet_timer.start()
	_snippet_timer_active = true
	
	# Start AI typing
	_start_ai_typing()
	
	# Start battle music
	if _battle_music:
		_battle_music.volume_db = -10
		_battle_music.play()
	
	print("[CBTutorialArena] Match started!")

func _show_countdown() -> void:
	if _countdown_label:
		_countdown_label.visible = true
		
		for i in range(3, 0, -1):
			_countdown_label.text = str(i)
			_animate_countdown_number()
			await get_tree().create_timer(1.0).timeout
		
		_countdown_label.text = "TYPE!"
		_animate_countdown_number()
		await get_tree().create_timer(0.5).timeout
		
		_countdown_label.visible = false

func _animate_countdown_number() -> void:
	if not _countdown_label:
		return
	
	_countdown_label.scale = Vector2(0.5, 0.5)
	_countdown_label.modulate.a = 0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_countdown_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_countdown_label, "modulate:a", 1.0, 0.2)
	tween.chain().tween_property(_countdown_label, "scale", Vector2(1.0, 1.0), 0.1)

func _generate_snippet_list() -> void:
	var cmd_snippets = [
		"scan /system /deep",
		"check-integrity --files",
		"firewall enable /all",
		"netstat -a -n",
		"tasklist /malware",
		"killvirus /id:0231",
		"clean temp /force",
		"quarantine threat_virus.exe",
		"update-defender /latest",
		"restore system --safe",
	]
	
	var terminal_snippets = [
		"sudo chkrootkit",
		"sudo rkhunter --check",
		"sudo ufw enable",
		"sudo systemctl stop trojan.service",
		"sudo rm -rf /tmp/malware",
		"sudo apt update && sudo apt upgrade",
		"sudo find / -name \"virus*\"",
		"sudo chmod -x /usr/bin/fakephish",
		"sudo iptables -L",
		"sudo reboot --safe-mode",
	]
	
	var all_snippets = cmd_snippets + terminal_snippets
	all_snippets.shuffle()
	
	_snippet_list.clear()
	for snippet in all_snippets:
		_snippet_list.append(str(snippet))
	
	_current_snippet_index = 0
	_code_snippet = _snippet_list[0]
	
	print("[CBTutorialArena] Generated %d snippets" % _snippet_list.size())

func _show_current_snippet() -> void:
	if _current_snippet_index >= _snippet_list.size():
		_generate_snippet_list()
		_current_snippet_index = 0
	
	_code_snippet = _snippet_list[_current_snippet_index]
	_snippet_time_remaining = SNIPPET_TIME_LIMIT
	
	if _code_display:
		_code_display.text = _code_snippet
	
	_update_snippet_timer_display()
	
	# Reset AI typing for new snippet
	ai_current_char_index = 0
	
	# Play pop sound
	if _pop_sound:
		_pop_sound.play()

func _on_input_submitted(text: String) -> void:
	if not _game_active:
		return
	
	if _input_field:
		_input_field.text = ""
	
	if text == _code_snippet:
		# Correct!
		player_score += SCORE_CORRECT
		ai_health = maxi(0, ai_health - DAMAGE_TO_ENEMY)
		
		print("[CBTutorialArena] ✅ Correct! Score: %d, AI HP: %d" % [player_score, ai_health])
		
		# Play success sound
		if _pop_sound:
			_pop_sound.pitch_scale = 1.5
			_pop_sound.play()
		
		# Check win condition
		if ai_health <= 0:
			_end_game_victory()
			return
		
		# Next snippet
		_current_snippet_index += 1
		_show_current_snippet()
		_start_ai_typing()
	else:
		# Wrong!
		player_health = maxi(0, player_health - SELF_DAMAGE_PENALTY)
		
		print("[CBTutorialArena] ❌ Wrong! HP: %d" % player_health)
		
		# Play error sound
		if _pop_sound:
			_pop_sound.pitch_scale = 0.7
			_pop_sound.play()
		
		# Check lose condition
		if player_health <= 0:
			_end_game_defeat()
			return
	
	_update_ui()

func _start_ai_typing() -> void:
	ai_current_char_index = 0
	ai_typing_active = true
	_schedule_next_ai_char()

func _schedule_next_ai_char() -> void:
	if not ai_typing_active or not _game_active:
		return
	
	var delay = randf_range(AI_MIN_CHAR_DELAY, AI_MAX_CHAR_DELAY)
	ai_type_timer.wait_time = delay
	ai_type_timer.start()

func _on_ai_type_char() -> void:
	if not ai_typing_active or not _game_active:
		return
	
	# Check if AI finished current snippet
	if ai_current_char_index >= _code_snippet.length():
		# AI completed the snippet!
		_on_ai_completed_snippet()
		return
	
	# Simulate typing (occasionally make typos)
	if randf() < AI_TYPO_CHANCE:
		# AI made a typo - takes extra time to "correct"
		ai_type_timer.wait_time = 0.5
		ai_type_timer.start()
		return
	
	ai_current_char_index += 1
	_schedule_next_ai_char()

func _on_ai_completed_snippet() -> void:
	if not _game_active:
		return
	
	# AI correctly submitted
	ai_score += SCORE_CORRECT
	player_health = maxi(0, player_health - DAMAGE_TO_ENEMY)
	
	print("[CBTutorialArena] 🤖 AI completed snippet! Score: %d, Player HP: %d" % [ai_score, player_health])
	
	_update_ui()
	
	# Check lose condition
	if player_health <= 0:
		_end_game_defeat()
		return
	
	# AI moves to next snippet (but player stays on current)
	# Start AI typing again
	ai_current_char_index = 0
	_schedule_next_ai_char()

func _on_game_timer_tick() -> void:
	if not _game_active:
		return
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _match_start_time
	var remaining = GAME_DURATION - elapsed
	
	if remaining <= 0:
		_end_game_time_up()
		return
	
	# Update timer display
	var mins = int(remaining) / 60
	var secs = int(remaining) % 60
	if _timer_label:
		_timer_label.text = "%02d:%02d" % [mins, secs]

func _on_snippet_timer_tick() -> void:
	if not _snippet_timer_active or not _game_active:
		return
	
	_snippet_time_remaining -= 0.1
	_update_snippet_timer_display()
	
	if _snippet_time_remaining <= 0:
		# Time up on this snippet - player takes damage
		player_health = maxi(0, player_health - SELF_DAMAGE_PENALTY)
		print("[CBTutorialArena] ⏰ Time up! Player HP: %d" % player_health)
		
		_update_ui()
		
		if player_health <= 0:
			_end_game_defeat()
			return
		
		# Move to next snippet
		_current_snippet_index += 1
		_show_current_snippet()
		_start_ai_typing()

func _update_snippet_timer_display() -> void:
	if _snippet_timer_label:
		_snippet_timer_label.text = "%.1fs" % maxf(0, _snippet_time_remaining)
		
		# Color based on time
		if _snippet_time_remaining < 5:
			_snippet_timer_label.add_theme_color_override("font_color", Color.RED)
		elif _snippet_time_remaining < 10:
			_snippet_timer_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			_snippet_timer_label.add_theme_color_override("font_color", Color.WHITE)

func _update_ui() -> void:
	if _p1_health:
		_p1_health.value = player_health
	if _p2_health:
		_p2_health.value = ai_health
	if _p1_score:
		_p1_score.text = "SCORE: %d" % player_score
	if _p2_score:
		_p2_score.text = "%d :SCORE" % ai_score

func _end_game_victory() -> void:
	print("[CBTutorialArena] 🎉 VICTORY!")
	_game_active = false
	ai_typing_active = false
	_game_timer.stop()
	_snippet_timer.stop()
	
	if _countdown_label:
		_countdown_label.text = "🏆 YOU WIN!"
		_countdown_label.visible = true
	
	_mark_tutorial_complete()
	
	await get_tree().create_timer(3.0).timeout
	_return_to_landing()

func _end_game_defeat() -> void:
	print("[CBTutorialArena] 💀 DEFEAT!")
	_game_active = false
	ai_typing_active = false
	_game_timer.stop()
	_snippet_timer.stop()
	
	if _countdown_label:
		_countdown_label.text = "💀 GAME OVER"
		_countdown_label.visible = true
	
	_mark_tutorial_complete()
	
	await get_tree().create_timer(3.0).timeout
	_return_to_landing()

func _end_game_time_up() -> void:
	print("[CBTutorialArena] ⏰ TIME UP!")
	_game_active = false
	ai_typing_active = false
	_game_timer.stop()
	_snippet_timer.stop()
	
	var result = "YOU WIN!" if player_health > ai_health else "GAME OVER"
	if _countdown_label:
		_countdown_label.text = "⏰ %s" % result
		_countdown_label.visible = true
	
	_mark_tutorial_complete()
	
	await get_tree().create_timer(3.0).timeout
	_return_to_landing()

func _mark_tutorial_complete() -> void:
	print("[CBTutorialArena] Saving tutorial completion to Firestore...")
	
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=code_breaker_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"code_breaker_tutorial_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[CBTutorialArena] ✅ Tutorial completion saved!")
		else:
			push_warning("[CBTutorialArena] Failed to save tutorial completion")
	)
	
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _return_to_landing() -> void:
	print("[CBTutorialArena] Returning to landing...")
	get_tree().change_scene_to_file("res://scene/landing.tscn")
