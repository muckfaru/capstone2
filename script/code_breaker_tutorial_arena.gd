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
const SNIPPET_TIME_LIMIT := 60.0 # ⚠️ TUTORIAL: Extended from 15s to 60s!
const GAME_DURATION := 180.0 # 3 minutes

# ===== POWER-UP SYSTEM (BUFFED FOR TUTORIAL) =====
enum PowerUpType {NORMAL, HEAL, FREEZE_TIME, EXTEND_TIME, SHIELD}
const HEAL_BONUS := 20 # ⚠️ TUTORIAL: +20 HP (doubled from 10)
const HEAL_CHANCE := 0.30 # 30% chance for heal power-up
const FREEZE_CHANCE := 0.10 # 10% chance for freeze time power-up
const FREEZE_DURATION := 30.0 # ⚠️ TUTORIAL: 30 seconds (doubled from 15)
const EXTEND_CHANCE := 0.25 # 25% chance for extend time power-up
const EXTEND_SNIPPET_TIME := 30.0 # ⚠️ TUTORIAL: +30 seconds (doubled from 15)
const EXTEND_MAIN_TIME := 16.0 # ⚠️ TUTORIAL: +16 seconds (doubled from 8)
const EXTEND_BUFF_DURATION := 40.0 # ⚠️ TUTORIAL: 40 seconds (doubled from 20)
const SHIELD_CHANCE := 0.10 # 10% chance for defensive shield power-up
const SHIELD_DURATION := 30.0 # ⚠️ TUTORIAL: 30 seconds (doubled from 15)

# Power-up state
var _current_powerup: PowerUpType = PowerUpType.NORMAL
var _time_frozen: bool = false
var _freeze_time_remaining: float = 0.0
var _extend_time_active: bool = false
var _extend_time_remaining: float = 0.0
var _shield_active: bool = false
var _shield_time_remaining: float = 0.0
var _powerups_used: int = 0

# AI Bot settings - NERFED SO PLAYER ALWAYS WINS!
const AI_MIN_CHAR_DELAY := 5.0 # ⚠️ TUTORIAL: 5 seconds per character (super slow!)
const AI_MAX_CHAR_DELAY := 10.0 # ⚠️ TUTORIAL: Up to 10 seconds per character
const AI_TYPO_CHANCE := 0.50 # ⚠️ TUTORIAL: 50% typo chance (AI is bad at typing)

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
	# Ensure we use the latest Code Breaker BGM even if the scene resource is cached.
	if _battle_music and ResourceLoader.exists("res://asset/background/code breaker new bgm.mp3"):
		_battle_music.stream = load("res://asset/background/code breaker new bgm.mp3")
		print("[CBTutorialArena] 🎵 Using BGM: res://asset/background/code breaker new bgm.mp3")
	
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
	
	# Add extend time bonus if active
	if _extend_time_active:
		_snippet_time_remaining += EXTEND_SNIPPET_TIME
		print("[CBTutorialArena] 🟡 Extend bonus! +%.0fs to snippet" % EXTEND_SNIPPET_TIME)
	
	if _code_display:
		_code_display.text = _code_snippet
	
	# ===== POWER-UP RANDOM SELECTION =====
	var rand_value = randf()
	if rand_value < SHIELD_CHANCE:
		_current_powerup = PowerUpType.SHIELD
		_set_powerup_panel("shield")
		print("[CBTutorialArena] 🛡️ SHIELD POWER-UP!")
	elif rand_value < (SHIELD_CHANCE + FREEZE_CHANCE):
		_current_powerup = PowerUpType.FREEZE_TIME
		_set_powerup_panel("freeze")
		print("[CBTutorialArena] 🧊 FREEZE TIME POWER-UP!")
	elif rand_value < (SHIELD_CHANCE + FREEZE_CHANCE + EXTEND_CHANCE):
		_current_powerup = PowerUpType.EXTEND_TIME
		_set_powerup_panel("extend")
		print("[CBTutorialArena] 🟡 EXTEND TIME POWER-UP!")
	elif rand_value < (SHIELD_CHANCE + FREEZE_CHANCE + EXTEND_CHANCE + HEAL_CHANCE):
		_current_powerup = PowerUpType.HEAL
		_set_powerup_panel("heal")
		print("[CBTutorialArena] 💚 HEAL POWER-UP!")
	else:
		_current_powerup = PowerUpType.NORMAL
		_set_powerup_panel("normal")
	
	_update_snippet_timer_display()
	
	# Reset AI typing for new snippet
	ai_current_char_index = 0
	
	# Play pop sound
	if _pop_sound:
		_pop_sound.play()

func _set_powerup_panel(powerup_type: String) -> void:
	# Hide all panels first
	if _default_panel:
		_default_panel.visible = (powerup_type == "normal")
	if _heal_panel:
		_heal_panel.visible = (powerup_type == "heal")
	if _freeze_panel:
		_freeze_panel.visible = (powerup_type == "freeze")
	if _extend_panel:
		_extend_panel.visible = (powerup_type == "extend")
	if _defensive_panel:
		_defensive_panel.visible = (powerup_type == "shield")

func _on_input_submitted(text: String) -> void:
	if not _game_active:
		return
	
	if _input_field:
		_input_field.text = ""
	
	if text == _code_snippet:
		# Correct!
		player_score += SCORE_CORRECT
		ai_health = maxi(0, ai_health - DAMAGE_TO_ENEMY)
		
		# ===== APPLY POWER-UP EFFECTS =====
		var bonus_text := ""
		match _current_powerup:
			PowerUpType.HEAL:
				player_health = mini(STARTING_HEALTH, player_health + HEAL_BONUS)
				bonus_text = " | 💚 +%d HP HEAL!" % HEAL_BONUS
				_powerups_used += 1
				print("[CBTutorialArena] 💚 HEAL BONUS! +%d HP" % HEAL_BONUS)
			PowerUpType.FREEZE_TIME:
				_time_frozen = true
				_freeze_time_remaining = FREEZE_DURATION
				bonus_text = " | 🧊 TIME FROZEN %.0fs!" % FREEZE_DURATION
				_powerups_used += 1
				print("[CBTutorialArena] 🧊 FREEZE TIME ACTIVATED!")
			PowerUpType.EXTEND_TIME:
				_extend_time_active = true
				_extend_time_remaining = EXTEND_BUFF_DURATION
				_snippet_time_remaining += EXTEND_SNIPPET_TIME
				_match_start_time += EXTEND_MAIN_TIME # Extra time
				bonus_text = " | 🟡 TIME BUFF %.0fs!" % EXTEND_BUFF_DURATION
				_powerups_used += 1
				print("[CBTutorialArena] 🟡 EXTEND TIME BUFF ACTIVATED!")
			PowerUpType.SHIELD:
				_shield_active = true
				_shield_time_remaining = SHIELD_DURATION
				bonus_text = " | 🛡️ SHIELD %.0fs!" % SHIELD_DURATION
				_powerups_used += 1
				print("[CBTutorialArena] 🛡️ DEFENSIVE SHIELD ACTIVATED!")
			_:
				pass
		
		print("[CBTutorialArena] ✅ Correct! Score: %d, AI HP: %d%s" % [player_score, ai_health, bonus_text])
		
		# PARTICLE EFFECT: Success sparkles!
		if _code_display:
			var particle_pos = _code_display.global_position + _code_display.size / 2
			_spawn_success_particles(particle_pos)
		
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
		var damage_taken := SELF_DAMAGE_PENALTY
		
		# 🛡️ SHIELD: Block damage if active!
		if _shield_active:
			damage_taken = 0
			print("[CBTutorialArena] 🛡️ SHIELD BLOCKED %d damage!" % SELF_DAMAGE_PENALTY)
		else:
			player_health = maxi(0, player_health - damage_taken)
			print("[CBTutorialArena] ❌ Wrong! HP: %d" % player_health)
			
			# SHAKE EFFECT: Health bar shake on damage
			if _p1_health:
				_shake_node(_p1_health, 8.0, 0.25)
				var is_critical = player_health < 30
				var particle_pos = _p1_health.global_position + _p1_health.size / 2
				_spawn_damage_explosion(particle_pos, is_critical)
			
			# SCREEN SHAKE on critical damage
			if player_health < 30 and player_health > 0:
				_shake_screen(12.0, 0.35)
		
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
	
	# ===== POWER-UP BUFF COUNTDOWN =====
	# Freeze time countdown
	if _time_frozen:
		_freeze_time_remaining -= 0.1
		if _freeze_time_remaining <= 0:
			_time_frozen = false
			print("[CBTutorialArena] 🧊 Freeze time ended!")
		else:
			# Don't count down snippet timer while frozen!
			_update_snippet_timer_display()
			return
	
	# Extend time buff countdown
	if _extend_time_active:
		_extend_time_remaining -= 0.1
		if _extend_time_remaining <= 0:
			_extend_time_active = false
			print("[CBTutorialArena] 🟡 Extend time buff ended!")
	
	# Shield countdown
	if _shield_active:
		_shield_time_remaining -= 0.1
		if _shield_time_remaining <= 0:
			_shield_active = false
			print("[CBTutorialArena] 🛡️ Shield expired!")
	
	# Normal snippet timer countdown
	_snippet_time_remaining -= 0.1
	_update_snippet_timer_display()
	
	if _snippet_time_remaining <= 0:
		# Time up on this snippet - player takes damage (unless shielded)
		if not _shield_active:
			player_health = maxi(0, player_health - SELF_DAMAGE_PENALTY)
			print("[CBTutorialArena] ⏰ Time up! Player HP: %d" % player_health)
		else:
			print("[CBTutorialArena] ⏰ Time up but 🛡️ SHIELD blocked damage!")
		
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
	
	_mark_tutorial_complete()
	
	# Show post-game results panel
	await _show_postgame_results(true)
	
	# Set meta flag for landing to show rewards
	get_tree().set_meta("show_code_breaker_reward", true)
	_return_to_landing()

func _end_game_defeat() -> void:
	print("[CBTutorialArena] 💀 DEFEAT!")
	_game_active = false
	ai_typing_active = false
	_game_timer.stop()
	_snippet_timer.stop()
	
	_mark_tutorial_complete()
	
	# Show post-game results panel
	await _show_postgame_results(false)
	
	# Set meta flag for landing to show rewards
	get_tree().set_meta("show_code_breaker_reward", true)
	_return_to_landing()

func _end_game_time_up() -> void:
	print("[CBTutorialArena] ⏰ TIME UP!")
	_game_active = false
	ai_typing_active = false
	_game_timer.stop()
	_snippet_timer.stop()
	
	var player_won = player_health > ai_health
	
	_mark_tutorial_complete()
	
	# Show post-game results panel
	await _show_postgame_results(player_won)
	
	# Set meta flag for landing to show rewards
	get_tree().set_meta("show_code_breaker_reward", true)
	_return_to_landing()

func _show_postgame_results(player_won: bool) -> void:
	"""Show post-game results panel with detailed stats"""
	print("[CBTutorialArena] Showing post-game results...")
	
	# Create overlay
	var overlay = ColorRect.new()
	overlay.name = "PostgameOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)
	
	# Create results panel
	var panel = Panel.new()
	panel.name = "PostgamePanel"
	panel.custom_minimum_size = Vector2(400, 350)
	panel.z_index = 51
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -175
	panel.offset_bottom = 175
	
	# Style panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.08, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0, 1, 1, 0.9) if player_won else Color(1, 0.3, 0.3, 0.9)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.shadow_color = panel_style.border_color
	panel_style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	# Result title
	var title = Label.new()
	title.text = "🏆 VICTORY!" if player_won else "💀 DEFEAT"
	title.position = Vector2(0, 20)
	title.size = Vector2(500, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.84, 0, 1) if player_won else Color(1, 0.3, 0.3, 1))
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Tutorial Complete!"
	subtitle.position = Vector2(0, 70)
	subtitle.size = Vector2(500, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	subtitle.add_theme_font_size_override("font_size", 18)
	panel.add_child(subtitle)
	
	# Stats container
	var stats_y = 120
	var line_height = 35
	
	# Your Score
	_add_stat_row(panel, "📊 YOUR SCORE:", "%d" % player_score, stats_y)
	stats_y += line_height
	
	# Your Health
	var health_color = Color(0.3, 1, 0.3, 1) if player_health > 50 else Color(1, 0.5, 0, 1)
	_add_stat_row(panel, "❤️ YOUR HEALTH:", "%d / 100" % player_health, stats_y, health_color)
	stats_y += line_height
	
	# AI Score & Health
	_add_stat_row(panel, "🤖 BOT SCORE:", "%d" % ai_score, stats_y)
	stats_y += line_height
	_add_stat_row(panel, "🤖 BOT HEALTH:", "%d / 100" % ai_health, stats_y)
	stats_y += line_height
	
	# Power-ups used
	_add_stat_row(panel, "⚡ POWER-UPS USED:", "%d" % _powerups_used, stats_y, Color(1, 0.84, 0, 1))
	stats_y += line_height + 10
	
	# Divider
	var divider = ColorRect.new()
	divider.color = Color(0, 1, 1, 0.4)
	divider.position = Vector2(40, stats_y)
	divider.size = Vector2(420, 2)
	panel.add_child(divider)
	stats_y += 15
	
	# Hint text
	var hint = Label.new()
	hint.text = "Claim your reward on the next screen!"
	hint.position = Vector2(0, stats_y)
	hint.size = Vector2(500, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 0.9))
	hint.add_theme_font_size_override("font_size", 14)
	panel.add_child(hint)
	
	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE →"
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.position = Vector2(150, 380)
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.5, 0.6, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0, 1, 1, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0, 0.7, 0.8, 1)
	btn_hover.shadow_color = Color(0, 1, 1, 0.5)
	btn_hover.shadow_size = 10
	
	continue_btn.add_theme_stylebox_override("normal", btn_style)
	continue_btn.add_theme_stylebox_override("hover", btn_hover)
	continue_btn.add_theme_stylebox_override("pressed", btn_hover)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(continue_btn)
	
	# Wait for button press
	var button_pressed = [false] # Use array to allow modification in lambda
	continue_btn.pressed.connect(func():
		button_pressed[0] = true
	)
	
	# Animate panel entrance
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait for user to click continue
	while not button_pressed[0]:
		await get_tree().process_frame
	
	# Clean up
	overlay.queue_free()
	panel.queue_free()
	print("[CBTutorialArena] Post-game closed, continuing to landing...")

func _add_stat_row(parent: Node, label_text: String, value_text: String, y_pos: float, value_color: Color = Color(1, 1, 1, 1)) -> void:
	"""Add a stat row to the postgame panel"""
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(50, y_pos)
	label.size = Vector2(200, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.position = Vector2(280, y_pos)
	value.size = Vector2(170, 30)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 16)
	parent.add_child(value)

func _show_rewards_popup() -> void:
	"""Show tutorial rewards with card and XP"""
	print("[CBTutorialArena] Showing rewards popup...")
	
	var popup_scene = load("res://scene/tutorial_rewards_popup.tscn")
	if not popup_scene:
		push_error("[CBTutorialArena] Could not load rewards popup!")
		_return_to_landing()
		return
	
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	# Set card image - The Magician 1 for Code Breaker
	var card_image = popup.get_node_or_null("Panel/VBox/CardPanel/CardImage")
	if card_image:
		var card_tex = load("res://asset/reward_background_cards/the magician card 1.jpeg")
		if card_tex:
			card_image.texture = card_tex
	
	# Set card name
	var card_name = popup.get_node_or_null("Panel/VBox/CardNameLabel")
	if card_name:
		card_name.text = "✨ THE MAGICIAN 1 ✨"
	
	# Set XP
	var xp_label = popup.get_node_or_null("Panel/VBox/XPLabel")
	if xp_label:
		xp_label.text = "+100 XP"
	
	# Set Agent01 dialog text - Pokemon style!
	var dialog_text = popup.get_node_or_null("Panel/VBox/DialogBox/HBox/DialogText")
	if dialog_text:
		dialog_text.text = "Excellent work, Agent! Your typing skills are impressive! Take this Magician card - it holds special power for those who master the code!"
	
	# Add XP to player
	if TutorialManager:
		TutorialManager.add_xp(100, "Code Breaker Tutorial")
		print("[CBTutorialArena] Added 100 XP!")
	
	# Connect claim button
	var claim_btn = popup.get_node_or_null("Panel/VBox/ClaimButton")
	if claim_btn:
		claim_btn.pressed.connect(func():
			popup.queue_free()
			_return_to_landing()
		)

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

# =============================================================================
# ANIMATION EFFECTS (SAME AS REAL ARENA)
# =============================================================================

func _shake_node(node: Node, intensity: float = 10.0, duration: float = 0.3) -> void:
	"""Shake a node horizontally"""
	if not node or not node is Control:
		return
	
	var original_pos = node.position
	var shake_count = 8
	var shake_interval = duration / shake_count
	
	for i in shake_count:
		var offset = randf_range(-intensity, intensity)
		node.position.x = original_pos.x + offset
		await get_tree().create_timer(shake_interval).timeout
	
	node.position = original_pos

func _shake_screen(intensity: float = 15.0, duration: float = 0.4) -> void:
	"""Shake the entire screen"""
	var original_pos = position
	var shake_count = 10
	var shake_interval = duration / shake_count
	
	for i in shake_count:
		var offset_x = randf_range(-intensity, intensity)
		var offset_y = randf_range(-intensity, intensity)
		position = original_pos + Vector2(offset_x, offset_y)
		await get_tree().create_timer(shake_interval).timeout
	
	position = original_pos

func _spawn_success_particles(at_position: Vector2) -> void:
	"""Spawn sparkle/star particles for correct answer"""
	var particle_count = 15
	
	for i in particle_count:
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(randf_range(0.5, 1.0), randf_range(0.8, 1.0), randf_range(0.0, 0.3))
		particle.position = at_position
		add_child(particle)
		
		# Random direction and speed
		var angle = randf_range(0, TAU)
		var speed = randf_range(100, 300)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(0.5, 1.0)
		
		# Animate particle
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + velocity * lifetime, lifetime)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime)
		tween.tween_property(particle, "scale", Vector2.ZERO, lifetime)
		
		# Cleanup after animation
		tween.finished.connect(func(): particle.queue_free())

func _spawn_damage_explosion(at_position: Vector2, is_critical: bool = false) -> void:
	"""Spawn explosion particles for damage"""
	var particle_count = 25 if is_critical else 12
	var base_color = Color.RED if is_critical else Color.ORANGE
	
	for i in particle_count:
		var particle = ColorRect.new()
		particle.size = Vector2(randf_range(6, 12), randf_range(6, 12))
		particle.color = base_color.lerp(Color.YELLOW, randf())
		particle.position = at_position
		add_child(particle)
		
		# Explosive outward motion
		var angle = randf_range(0, TAU)
		var speed = randf_range(150, 400) if is_critical else randf_range(100, 250)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(0.4, 0.8)
		
		# Animate explosion
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + velocity * lifetime, lifetime)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime * 0.7)
		tween.tween_property(particle, "rotation", randf_range(-PI, PI), lifetime)
		
		# Cleanup
		tween.finished.connect(func(): particle.queue_free())
