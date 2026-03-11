extends Node2D

# === Game Constants ===
const ENEMY_SCENES = {
	"virus": preload("res://scene/enemy_virus.tscn"),
	"worm": preload("res://scene/enemy_worm.tscn"),
	"trojan": preload("res://scene/enemy_trojan.tscn"),
	"ransomware": preload("res://scene/enemy_ransomware.tscn")
}
const ENEMY_SCRIPT = preload("res://script/defuse_trojan_enemy.gd")
const PROJECTILE_SCENE = preload("res://scene/projectile.tscn")

# IT 323 - Information Assurance & Security 1 (Curriculum-Based Keywords)
const COMMANDS: Array = [
	# ═══════════════════════════════════════════════════════════════
	# 1.1-1.2 Introduction to IAS & Data/Network Security
	# ═══════════════════════════════════════════════════════════════
	"firewall", "antivirus", "encryption", "phishing", "malware",
	"intrusion", "vulnerability", "exploit", "patch", "breach",
	
	# ═══════════════════════════════════════════════════════════════
	# 2.1 CIA Triad - Confidentiality, Integrity, Availability
	# ═══════════════════════════════════════════════════════════════
	"confidentiality", "integrity", "availability", "authenticate",
	"authorize", "audit", "classify", "access",
	
	# ═══════════════════════════════════════════════════════════════
	# 2.2 Assets and Threats
	# ═══════════════════════════════════════════════════════════════
	"trojan", "worm", "virus", "ransomware", "spyware",
	"rootkit", "botnet", "keylogger", "adware", "backdoor",
	
	# ═══════════════════════════════════════════════════════════════
	# 7.1-7.2 Authentication
	# ═══════════════════════════════════════════════════════════════
	"password", "biometric", "token", "otp",
	"mfa", "session", "logout", "hash", "salt", "bruteforce"
]

const ENEMY_TYPES: Array = ["trojan", "worm", "virus", "ransomware"]

# === Multiplayer (Relay) ===
const PLAYER_POSITIONS_2: Array[Vector2] = [Vector2(450, 591), Vector2(750, 591)]
const PLAYER_POSITIONS_3: Array[Vector2] = [Vector2(450, 591), Vector2(600, 591), Vector2(750, 591)]

const ENEMY_STATE_SEND_INTERVAL := 0.12
const ARENA_SYNC_THROTTLE := 1.0

var _mode: String = "single"
var _multiplayer: bool = false
var _room_id: String = ""
var _player_id: String = ""
var _is_host_mp: bool = false
var _lobby_server_url: String = ""
var _relay_client: Node = null
var _relay_connected: bool = false

var _room_data: Dictionary = {}
var _players_ordered: Array = [] # ordered slots: [host, client, client2]
var _player_nodes: Dictionary = {} # player_id -> Node2D

var _enemy_id_counter: int = 0
var _enemies_by_id: Dictionary = {} # enemy_id -> Node2D

var _enemy_state_timer: Timer
var _last_sync_request_ms: int = 0
var _last_wave_seen: int = 1

# === Post-game analytics (per-player) ===
var _scores_by_player: Dictionary = {} # player_id -> int
var _typing_total_keys: int = 0
var _typing_correct_keys: int = 0
var _typing_wrong_keys: int = 0
var _typing_current_streak: int = 0
var _typing_longest_streak: int = 0
var _last_key_error: bool = false

var _match_start_ms: int = 0
var _awaiting_postgame: bool = false
var _pending_player_stats: Dictionary = {} # player_id -> {wpm, accuracy_pct, longest_streak}
var _postgame_transitioned: bool = false

# === Game State ===
var health: int = 100
var max_health: int = 100
var score: int = 0
var wave: int = 1
var enemies_destroyed: int = 0
var combo_count: int = 0
var game_over: bool = false
var game_paused: bool = false

# Typing state
var current_target: Node2D = null
var typed_text: String = ""

# Inactivity Timer
var inactivity_timer: float = 0.0
const INACTIVITY_TIMEOUT: float = 3.0  # Reset after 3 seconds of no typing
var last_keypress_time: float = 0.0
var inactivity_warning_shown: bool = false

# Spawning
var spawn_timer: float = 0.0
var base_spawn_interval: float = 2.5
var min_spawn_interval: float = 0.8
var enemies_per_wave: int = 5
var enemies_spawned_this_wave: int = 0
var wave_spawning_complete: bool = false # True when all enemies for wave have been spawned

# Parallax scrolling
var scroll_speed: float = 50.0

# === Node References (using proper Godot nodes) ===
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var spawn_points: Node2D = $GameLayer/SpawnPoints
@onready var enemy_container: Node2D = $GameLayer/EnemyContainer
@onready var targeting_beam: Line2D = $GameLayer/TargetingBeam
@onready var player_sprite: Node2D = $GameLayer/Player
@onready var effects_layer: Node2D = $EffectsLayer

# UI References
@onready var health_bar: ProgressBar = $CanvasLayer/UI/HealthContainer/HealthBar
@onready var health_label: Label = $CanvasLayer/UI/HealthLabel
@onready var score_label: Label = $CanvasLayer/UI/ScoreContainer/ScoreLabel
@onready var wave_label: Label = $CanvasLayer/UI/ScoreContainer/WaveLabel
@onready var combo_label: Label = $CanvasLayer/UI/ScoreContainer/ComboLabel
@onready var typed_display: RichTextLabel = $CanvasLayer/UI/TypingContainer/TypedDisplay
@onready var target_word: Label = $CanvasLayer/UI/TypingContainer/TargetWord
@onready var inactivity_warning: Label = $CanvasLayer/UI/InactivityWarning
@onready var game_over_panel: Panel = $CanvasLayer/GameOverPanel

# Menu
@onready var menu_button: Button = $CanvasLayer/UI/TopBar/MenuButton
@onready var menu_panel: Control = $MenuPanel

# Audio
@onready var bg_music: AudioStreamPlayer = $AudioPlayers/BGMusic
@onready var type_sfx: AudioStreamPlayer = $AudioPlayers/TypeSFX
@onready var destroy_sfx: AudioStreamPlayer = $AudioPlayers/DestroySFX
@onready var destroy_sfx2: AudioStreamPlayer = $AudioPlayers/DestroySFX2
@onready var spawn_sfx: AudioStreamPlayer = $AudioPlayers/SpawnSFX
@onready var game_over_sfx: AudioStreamPlayer = $AudioPlayers/GameOverSFX

# === Lifecycle ===
func _ready() -> void:
	_setup_ui()
	_setup_multiplayer_from_meta()
	_start_game()
	_apply_shop_cosmetics()

	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)

	if bg_music:
		bg_music.play()
		if menu_panel and menu_panel.has_method("set_target_music"):
			menu_panel.set_target_music(bg_music)

	# ✅ FIX: Connect the exit signal so solo + multiplayer both work
	if menu_panel and menu_panel.has_signal("exit_match_requested"):
		if not menu_panel.exit_match_requested.is_connected(_on_exit_match_requested):
			menu_panel.exit_match_requested.connect(_on_exit_match_requested)

	if _multiplayer:
		_setup_players_in_arena()
		_setup_relay_for_arena()
		_announce_arena_ready()
	
func _apply_shop_cosmetics() -> void:
	# Background swap
	var bg_val: String = ShopManager.get_equipped_value(ShopManager.SLOT_BG_DEFUSE_TROJAN)
	if bg_val != "" and ResourceLoader.exists(bg_val):
		var bg_sprite = $ParallaxBackground/ParallaxLayer/Background
		if bg_sprite and bg_sprite is Sprite2D:
			bg_sprite.texture = load(bg_val)
			print("[DT Arena] 🎨 Shop background applied: ", bg_val)

	# Skin swap (player ship)
	var skin_val: String = ShopManager.get_equipped_value(ShopManager.SLOT_SKIN_DEFUSE_TROJAN)
	if skin_val != "" and ResourceLoader.exists(skin_val):
		if skin_val.ends_with(".tres"):
			# SpriteFrames resource
			var anim_sprite = player_sprite.get_node_or_null("AnimatedSprite2D")
			if anim_sprite and anim_sprite is AnimatedSprite2D:
				var frames = load(skin_val)
				if frames is SpriteFrames:
					anim_sprite.sprite_frames = frames
					anim_sprite.play("idle")
					# Non-default skins use PNG with real transparency — remove the
					# white/black background-removal shader so dark pixels aren't stripped.
					if skin_val != "res://asset/defuse_trojan/player_frames.tres":
						anim_sprite.material = null
					print("[DT Arena] 🎨 Shop ship skin applied: ", skin_val)
		else:
			# Static texture (e.g. player_computer.jpg)
			var anim_sprite = player_sprite.get_node_or_null("AnimatedSprite2D")
			if anim_sprite and anim_sprite is AnimatedSprite2D:
				# Replace with a static Sprite2D
				var tex = load(skin_val) as Texture2D
				if tex:
					var static_sprite := Sprite2D.new()
					static_sprite.texture = tex
					static_sprite.scale = anim_sprite.scale
					static_sprite.position = anim_sprite.position
					anim_sprite.replace_by(static_sprite)
					print("[DT Arena] 🎨 Shop ship texture applied: ", skin_val)

func _setup_ui() -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	_update_ui()
	game_over_panel.visible = false
	targeting_beam.visible = false

func _start_game() -> void:
	health = max_health
	score = 0
	wave = 1
	_last_wave_seen = wave
	enemies_destroyed = 0
	enemies_spawned_this_wave = 0
	wave_spawning_complete = false
	combo_count = 0
	game_over = false
	typed_text = ""
	current_target = null
	spawn_timer = 0.0
	# Multiplayer tracking reset
	_enemies_by_id.clear()
	if _is_host_mp:
		_enemy_id_counter = 0

	# Analytics reset
	_typing_total_keys = 0
	_typing_correct_keys = 0
	_typing_wrong_keys = 0
	_typing_current_streak = 0
	_typing_longest_streak = 0
	_last_key_error = false
	_awaiting_postgame = false
	_postgame_transitioned = false
	_pending_player_stats.clear()
	_scores_by_player.clear()

	# Match start time (host is authoritative for duration in multiplayer)
	_match_start_ms = Time.get_ticks_msec()

	# Initialize per-player scores
	if _multiplayer:
		var host_slot: Dictionary = _room_data.get("host", {})
		var client_slot: Dictionary = _room_data.get("client", {})
		var client2_slot: Dictionary = _room_data.get("client2", {})
		for slot in [host_slot, client_slot, client2_slot]:
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			var pid := str(slot.get("player_id", "")).strip_edges()
			if pid != "":
				_scores_by_player[pid] = 0
	else:
		var pid2 := _player_id.strip_edges()
		if pid2 == "" and Auth:
			pid2 = Auth.current_local_id
		if pid2 == "":
			pid2 = "local"
		_player_id = pid2
		_scores_by_player[pid2] = 0
	_update_ui()
	_update_typed_display()

func _process(delta: float) -> void:
	if game_over or game_paused:
		return
	
	# Parallax scrolling effect
	parallax_bg.scroll_offset.y += scroll_speed * delta
	
	# Inactivity timer - reset typing if player is inactive
	if typed_text.length() > 0:
		inactivity_timer += delta
		
		# Show warning at 2 seconds
		if inactivity_timer >= 2.0 and not inactivity_warning_shown:
			inactivity_warning_shown = true
			if inactivity_warning:
				inactivity_warning.visible = true
				inactivity_warning.modulate = Color(1, 0.5, 0)
		
		# Timeout at 3 seconds
		if inactivity_timer >= INACTIVITY_TIMEOUT:
			print("[DefuseTrojan] ⏱️ Inactivity timeout - resetting typed text")
			_reset_typing_from_inactivity()
	else:
		inactivity_timer = 0.0
		inactivity_warning_shown = false
		if inactivity_warning:
			inactivity_warning.visible = false
	
	# Spawn/waves are host-authoritative in multiplayer.
	if (not _multiplayer) or _is_host_mp:
		# Spawn enemies only if wave spawning not complete
		if not wave_spawning_complete:
			spawn_timer += delta
			var spawn_interval = max(base_spawn_interval - (wave * 0.15), min_spawn_interval)
			
			if spawn_timer >= spawn_interval:
				spawn_timer = 0.0
				_spawn_enemy()
		else:
			# Check if all enemies are cleared - advance to next wave
			if enemy_container.get_child_count() == 0:
				_advance_to_next_wave()
	
	# Update targeting beam
	_update_targeting_beam()

func _input(event: InputEvent) -> void:
	if game_over:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		var key_string = OS.get_keycode_string(key_event.keycode)
		
		# Handle backspace
		if key_event.keycode == KEY_BACKSPACE:
			if typed_text.length() > 0:
				typed_text = typed_text.substr(0, typed_text.length() - 1)
				# If text is now empty, clear target completely
				if typed_text.length() == 0:
					_clear_typing()
				else:
					# Re-evaluate target based on new shorter text
					_reevaluate_target()
					_update_typed_display()
			return
		
		# Handle escape to clear
		if key_event.keycode == KEY_ESCAPE:
			_clear_typing()
			return
		
		# Handle letter/number input
		if key_string.length() == 1 and key_string.to_upper() in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			_typing_total_keys += 1
			_last_key_error = false
			inactivity_timer = 0.0  # Reset inactivity timer
			last_keypress_time = Time.get_ticks_msec()
			typed_text += key_string.to_upper()
			_process_typing()
			if _last_key_error:
				_typing_wrong_keys += 1
				_typing_current_streak = 0
			else:
				_typing_correct_keys += 1
				_typing_current_streak += 1
				if _typing_current_streak > _typing_longest_streak:
					_typing_longest_streak = _typing_current_streak

func _process_typing() -> void:
	var last_letter = typed_text.substr(typed_text.length() - 1, 1) if typed_text.length() > 0 else ""
	
	# CASE 1: Check if typed_text matches any enemy's word prefix
	var word_match = _find_matching_enemy(typed_text)
	if word_match:
		_handle_match(word_match, typed_text)
		return
	
	# CASE 2: Check if typed_text continues any enemy's stored progress
	# e.g., enemy has stored "REGE", typed_text is "REGED" -> continue
	for enemy in enemy_container.get_children():
		if enemy.has_method("get_typed_progress"):
			var stored = enemy.get_typed_progress()
			if stored.length() > 0 and typed_text == stored + last_letter:
				# This typed_text continues the stored progress
				if enemy.word.begins_with(typed_text):
					_handle_match(enemy, typed_text)
					return
	
	# CASE 3: Check if last letter can start/continue a DIFFERENT enemy
	if last_letter.length() > 0:
		# Check enemies with stored progress that can be continued with this letter
		for enemy in enemy_container.get_children():
			if enemy == current_target:
				continue
			if enemy.has_method("get_typed_progress"):
				var stored = enemy.get_typed_progress()
				if stored.length() > 0:
					var continued = stored + last_letter
					if enemy.word.begins_with(continued):
						# Can continue this enemy's stored progress
						_switch_to_enemy(enemy, continued)
						return
		
		# Check if last letter starts any enemy word
		var fresh_match = _find_matching_enemy(last_letter)
		if fresh_match and fresh_match != current_target:
			_switch_to_enemy(fresh_match, last_letter)
			return
	
	# CASE 4: No match at all - remove last letter and flash error
	_last_key_error = true
	typed_text = typed_text.substr(0, typed_text.length() - 1)
	typed_display.modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(typed_display, "modulate", Color(1, 1, 1), 0.2)
	combo_count = 0
	
	_update_typed_display()
	_update_combo_display()

func _handle_match(enemy: Node2D, text: String) -> void:
	"""Handle a successful match - update target and fire projectile"""
	var is_new_target = (current_target == null) or not is_instance_valid(current_target)
	var is_switching = not is_new_target and (enemy != current_target)
	
	if is_switching:
		if current_target.has_method("set_targeted"):
			current_target.set_targeted(false)
		current_target = enemy
		if current_target.has_method("set_targeted"):
			current_target.set_targeted(true)
			current_target.update_typed_progress(text)
		# Don't fire projectile when switching
	elif is_new_target:
		current_target = enemy
		if current_target.has_method("set_targeted"):
			current_target.set_targeted(true)
			current_target.update_typed_progress(text)
		_spawn_projectile(current_target)
	else:
		# Continuing same target
		if current_target.has_method("set_targeted"):
			current_target.update_typed_progress(text)
		
		if text == current_target.word:
			combo_count += 1
			_spawn_final_projectile(current_target)
			_clear_typing()
		else:
			_spawn_projectile(current_target)
	
	_update_typed_display()
	_update_combo_display()

func _switch_to_enemy(enemy: Node2D, new_typed_text: String) -> void:
	"""Switch to a different enemy with specified typed text"""
	if current_target and is_instance_valid(current_target) and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)
	
	current_target = enemy
	typed_text = new_typed_text
	
	if current_target.has_method("set_targeted"):
		current_target.set_targeted(true)
		current_target.update_typed_progress(typed_text)
	
	_spawn_projectile(current_target)
	_update_typed_display()
	_update_combo_display()

func _find_enemy_with_stored_progress(text: String) -> Node2D:
	"""Find an enemy that has stored progress matching the typed text, 
	OR where the text continues from their stored progress.
	Returns the closest matching enemy (nearest to player/bottom)."""
	if text.length() == 0:
		return null
	
	var closest_enemy: Node2D = null
	var closest_distance: float = INF
	
	for enemy in enemy_container.get_children():
		if enemy.has_method("get_typed_progress"):
			var stored = enemy.get_typed_progress()
			if stored.length() > 0:
				var matches = false
				# Check if stored progress begins with text (returning to previous)
				if stored.begins_with(text):
					matches = true
				# Check if typed text would CONTINUE the stored progress
				# e.g., stored="TASK", text="K", word="TASKKILL" -> "TASK"+"K"="TASKK" matches word
				var continued = stored + text
				if enemy.word.begins_with(continued):
					matches = true
				
				if matches:
					# Get distance to bottom (closer = more urgent = higher priority)
					var distance_to_bottom = get_viewport_rect().size.y - enemy.position.y
					if distance_to_bottom < closest_distance:
						closest_distance = distance_to_bottom
						closest_enemy = enemy
	
	return closest_enemy


func _spawn_projectile(target: Node2D) -> void:
	"""Spawn a projectile from player to target enemy"""
	if not target or not is_instance_valid(target):
		return
	
	# Play laser sound effect (restart each letter)
	if type_sfx:
		type_sfx.stop()
		type_sfx.play()
	
	# Rotate player to face target
	_rotate_player_to_target(target)
	
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.target = target
	projectile.global_position = player_sprite.global_position
	
	# Add to effects layer
	effects_layer.add_child(projectile)

	if _multiplayer:
		_send_shot(target, false)

func _spawn_final_projectile(target: Node2D) -> void:
	"""Spawn a projectile that will destroy enemy when it hits"""
	if not target or not is_instance_valid(target):
		return
	
	# Rotate player to face target
	_rotate_player_to_target(target)
	
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.target = target
	projectile.global_position = player_sprite.global_position
	
	# Connect to destroy enemy when hit
	projectile.hit_target.connect(_on_projectile_hit_enemy)
	
	# Add to effects layer
	effects_layer.add_child(projectile)

	if _multiplayer:
		_send_shot(target, true)

func _rotate_player_to_target(target: Node2D) -> void:
	"""Smoothly rotate player to face the target"""
	if not target or not is_instance_valid(target):
		return
	
	var direction = target.global_position - player_sprite.global_position
	var target_angle = direction.angle() + PI / 2 # Add PI/2 because sprite faces up by default
	
	# Smooth rotation using tween
	var tween = create_tween()
	tween.tween_property(player_sprite, "rotation", target_angle, 0.1).set_ease(Tween.EASE_OUT)

func _on_projectile_hit_enemy(enemy: Node2D) -> void:
	"""Called when final projectile hits enemy - destroy it"""
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("destroy"):
		return

	if _multiplayer:
		var eid := _get_enemy_id(enemy)
		if eid == "":
			return
		if _is_host_mp:
			enemy.set_meta("killed_by", _player_id)
			_destroy_enemy_authoritative(enemy, _player_id)
		else:
			_send_relay({
				"type": "dt_kill_request",
				"player_id": _player_id,
				"enemy_id": eid
			})
		return

	# Play destroy sound effect (alternate between 2 sounds)
	if randi() % 2 == 0:
		if destroy_sfx:
			destroy_sfx.play()
	else:
		if destroy_sfx2:
			destroy_sfx2.play()
	
	enemy.destroy()

func _find_matching_enemy(text: String) -> Node2D:
	if text.length() == 0:
		return null
	
	var closest_enemy: Node2D = null
	var closest_distance: float = INF
	
	for enemy in enemy_container.get_children():
		if enemy.has_method("set_targeted") and enemy.word.begins_with(text):
			# Get distance to bottom (closer = more urgent)
			var distance_to_bottom = get_viewport_rect().size.y - enemy.position.y
			if distance_to_bottom < closest_distance:
				closest_distance = distance_to_bottom
				closest_enemy = enemy
	
	return closest_enemy

func _clear_typing() -> void:
	typed_text = ""
	if current_target and is_instance_valid(current_target):
		current_target.set_targeted(false)
	current_target = null
	targeting_beam.visible = false
	_update_typed_display()

func _reset_typing_from_inactivity() -> void:
	"""Reset typing due to inactivity timeout"""
	typed_text = ""
	if current_target and is_instance_valid(current_target):
		current_target.set_targeted(false)
		# Clear stored progress on timeout
		if current_target.has_method("update_typed_progress"):
			current_target.update_typed_progress("")
	current_target = null
	combo_count = 0  # Reset combo on timeout
	inactivity_timer = 0.0
	inactivity_warning_shown = false
	if inactivity_warning:
		inactivity_warning.visible = false
	targeting_beam.visible = false
	# Flash screen yellow
	typed_display.modulate = Color(1, 1, 0.3)
	var tween = create_tween()
	tween.tween_property(typed_display, "modulate", Color(1, 1, 1), 0.3)
	_update_typed_display()
	_update_combo_display()

func _reevaluate_target() -> void:
	"""Re-evaluate which enemy should be targeted based on current typed_text"""
	if typed_text.length() == 0:
		_clear_typing()
		return
	
	var best_match = _find_matching_enemy(typed_text)
	
	if best_match:
		# If current target doesn't match anymore, switch
		if current_target and is_instance_valid(current_target):
			if not current_target.word.begins_with(typed_text):
				# Current target no longer matches, switch to best_match
				current_target.set_targeted(false)
				current_target = best_match
				current_target.set_targeted(true)
				current_target.update_typed_progress(typed_text)
		else:
			# No current target, set the best match
			current_target = best_match
			current_target.set_targeted(true)
			current_target.update_typed_progress(typed_text)
	else:
		# No enemy matches anymore, clear target
		if current_target and is_instance_valid(current_target):
			current_target.set_targeted(false)
		current_target = null

func _update_typed_display() -> void:
	# Use RichTextLabel for colored typing
	if typed_text.length() > 0:
		typed_display.text = "[center][color=#00ffcc]%s[/color]_[/center]" % typed_text
	else:
		typed_display.text = "[center][color=#666666]TYPE TO ATTACK[/color][/center]"
	
	if current_target and is_instance_valid(current_target):
		target_word.text = "TARGET: %s" % current_target.word
		target_word.visible = true
	else:
		target_word.visible = false

func _update_targeting_beam() -> void:
	"""Targeting beam disabled - projectiles show direction instead"""
	targeting_beam.visible = false

func _update_combo_display() -> void:
	if not combo_label:
		print("[DefuseTrojan] ⚠️ combo_label is null!")
		return
	
	if combo_count >= 3:
		combo_label.visible = true
		combo_label.text = "COMBO x%d" % combo_count
		print("[DefuseTrojan] ⭐ Combo displayed: x%d" % combo_count)
		# Color based on combo level
		if combo_count >= 10:
			combo_label.add_theme_color_override("font_color", Color(1, 0, 0.5))
		elif combo_count >= 5:
			combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
		else:
			combo_label.add_theme_color_override("font_color", Color(0, 1, 0.8))
	else:
		combo_label.visible = false

# === Enemy Management ===
func _spawn_enemy() -> void:
	# In multiplayer, only host spawns enemies.
	if _multiplayer and not _is_host_mp:
		return

	var enemies_this_wave = enemies_per_wave + wave
	
	if enemies_spawned_this_wave >= enemies_this_wave:
		# All enemies for this wave have been spawned
		wave_spawning_complete = true
		return
	
	# Pick random type first, then get correct scene
	var enemy_type = ENEMY_TYPES[randi() % ENEMY_TYPES.size()]
	var enemy_scene = ENEMY_SCENES.get(enemy_type, ENEMY_SCENES["virus"])
	var enemy = enemy_scene.instantiate()
	
	# Attach enemy script for behavior
	enemy.set_script(ENEMY_SCRIPT)
	
	# Use Marker2D spawn points
	var spawn_markers = spawn_points.get_children()
	var spawn_point = spawn_markers[randi() % spawn_markers.size()] as Marker2D
	enemy.position = spawn_point.position
	
	# Set random word and type
	var word = COMMANDS[randi() % COMMANDS.size()]
	
	enemy.set_word(word)
	enemy.set_enemy_type(enemy_type)
	
	# Play spawn sound effect
	if spawn_sfx:
		spawn_sfx.play()
	
	# Increase speed with waves
	enemy.speed += wave * 8

	# Multiplayer: assign an ID and announce spawn.
	if _multiplayer:
		_enemy_id_counter += 1
		var enemy_id := str(_enemy_id_counter)
		_set_enemy_id(enemy, enemy_id)
		_enemies_by_id[enemy_id] = enemy
		_send_relay({
			"type": "dt_enemy_spawn",
			"enemy_id": enemy_id,
			"enemy_type": enemy_type,
			"word": word,
			"x": enemy.position.x,
			"y": enemy.position.y,
			"speed": enemy.speed,
			"wave": wave
		})
	
	# Connect signals
	enemy.reached_bottom.connect(_on_enemy_reached_bottom)
	enemy.destroyed.connect(_on_enemy_destroyed)
	
	enemy_container.add_child(enemy)
	enemies_spawned_this_wave += 1

func _advance_to_next_wave() -> void:
	"""Called when all enemies in current wave are destroyed"""
	wave += 1
	enemies_spawned_this_wave = 0
	wave_spawning_complete = false
	spawn_timer = 0.0
	_show_wave_notification()

func _destroy_enemy(enemy: Node2D) -> void:
	if enemy and is_instance_valid(enemy):
		enemy.destroy()
		_clear_typing()

func _on_enemy_reached_bottom(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.is_queued_for_deletion():
		return

	if _multiplayer and not _is_host_mp:
		# Host decides damage/removal.
		if enemy and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.queue_free()
		return

	if game_over:
		# Arena is shutting down; best-effort cleanup only.
		if _multiplayer:
			var eid_over := _get_enemy_id(enemy)
			if eid_over != "":
				_enemies_by_id.erase(eid_over)
		if enemy and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.queue_free()
		return

	# Remove the enemy immediately (before any awaits) to avoid double-free races.
	if enemy == current_target:
		_clear_typing()

	# Remove on all clients (host-authoritative)
	if _multiplayer:
		var eid := _get_enemy_id(enemy)
		if eid != "":
			_send_relay({
				"type": "dt_enemy_remove",
				"enemy_id": eid,
				"reason": "bottom"
			})
			_enemies_by_id.erase(eid)

	if enemy and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.queue_free()
	
	# Damage player
	var damage = 15 + (wave * 2)
	health -= damage
	health = max(0, health)
	combo_count = 0 # Reset combo
	
	# Screen shake effect
	_screen_shake()
	
	# Flash player red
	player_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.15).timeout
	player_sprite.modulate = Color(1, 1, 1)
	
	_update_ui()
	_update_combo_display()
	
	if health <= 0:
		_game_over()

func _on_enemy_destroyed(enemy: Node2D, points: int) -> void:
	if _multiplayer and not _is_host_mp:
		# Score is host-authoritative; visuals already handled.
		if enemy and is_instance_valid(enemy):
			var eid := _get_enemy_id(enemy)
			if eid != "":
				_enemies_by_id.erase(eid)
		return

	# Combo bonus
	var combo_multiplier = 1.0 + (combo_count * 0.1)
	var final_points = int(points * combo_multiplier)

	var by_pid := _player_id
	if enemy and is_instance_valid(enemy) and enemy.has_meta("killed_by"):
		by_pid = str(enemy.get_meta("killed_by"))
	if by_pid.strip_edges() == "":
		by_pid = _player_id
	if by_pid.strip_edges() == "":
		by_pid = "local"
	_scores_by_player[by_pid] = int(_scores_by_player.get(by_pid, 0)) + final_points
	# Local HUD shows my score.
	score = int(_scores_by_player.get(_player_id, int(_scores_by_player.get("local", 0))))
	enemies_destroyed += 1
	_update_ui()

	if _multiplayer:
		var eid := _get_enemy_id(enemy)
		if eid != "":
			_send_relay({
				"type": "dt_enemy_destroy",
				"enemy_id": eid,
				"by": by_pid,
				"points": final_points
			})
			_enemies_by_id.erase(eid)
			_broadcast_enemy_state() # push state immediately after a kill


# === Multiplayer Helpers ===
func _setup_multiplayer_from_meta() -> void:
	if not get_tree().has_meta("defuse_trojan_arena_init"):
		return
	var init: Dictionary = get_tree().get_meta("defuse_trojan_arena_init")
	get_tree().set_meta("defuse_trojan_arena_init", null)

	_mode = str(init.get("mode", "single"))
	_multiplayer = (_mode == "multiplayer")
	_room_id = str(init.get("room_id", ""))
	_player_id = str(init.get("player_id", ""))
	_is_host_mp = bool(init.get("is_host", false))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_room_data = init.get("room_data", {})
	_relay_client = init.get("relay_client", null)

	# Fallback: if relay_client wasn't passed, try finding it in root.
	if _relay_client == null:
		for child in get_tree().root.get_children():
			if child != null and child.get_script() != null and str(child.get_script().resource_path).ends_with("WebSocketRelayClient.gd"):
				_relay_client = child
				break


func _setup_players_in_arena() -> void:
	_player_nodes.clear()
	_players_ordered.clear()

	var host_slot: Dictionary = _room_data.get("host", {})
	var client_slot: Dictionary = _room_data.get("client", {})
	var client2_slot: Dictionary = _room_data.get("client2", {})
	_players_ordered = [host_slot, client_slot, client2_slot]

	var present: Array = []
	for slot in _players_ordered:
		if typeof(slot) == TYPE_DICTIONARY and str(slot.get("player_id", "")).strip_edges() != "":
			present.append(slot)

	var positions: Array[Vector2] = PLAYER_POSITIONS_3
	if present.size() <= 2:
		positions = PLAYER_POSITIONS_2

	var second_pid := ""
	if str(client_slot.get("player_id", "")).strip_edges() != "":
		second_pid = str(client_slot.get("player_id"))
	elif str(client2_slot.get("player_id", "")).strip_edges() != "":
		second_pid = str(client2_slot.get("player_id"))

	# Local player uses the built-in Player node.
	var host_pid := str(host_slot.get("player_id", ""))
	if _player_id.strip_edges() == "" and Auth:
		_player_id = Auth.current_local_id

	var local_pos: Vector2 = positions[0]
	if present.size() <= 2:
		if _player_id == host_pid:
			local_pos = positions[0]
		else:
			local_pos = positions[1]
	else:
		# 3 players: host=0, client=1, client2=2
		if _player_id == host_pid:
			local_pos = positions[0]
		elif _player_id == str(client_slot.get("player_id", "")):
			local_pos = positions[1]
		else:
			local_pos = positions[2]

	player_sprite.position = local_pos
	_player_nodes[_player_id] = player_sprite

	# Spawn remote player avatars.
	var PlayerScene := load("res://scene/defuse_trojan_player.tscn")
	if PlayerScene == null:
		return

	if present.size() <= 2:
		# Two players: host left, other right.
		_spawn_remote_player(PlayerScene, host_pid, positions[0])
		_spawn_remote_player(PlayerScene, second_pid, positions[1])
	else:
		_spawn_remote_player(PlayerScene, host_pid, positions[0])
		_spawn_remote_player(PlayerScene, str(client_slot.get("player_id", "")), positions[1])
		_spawn_remote_player(PlayerScene, str(client2_slot.get("player_id", "")), positions[2])


func _spawn_remote_player(player_scene: PackedScene, pid: String, pos: Vector2) -> void:
	if pid.strip_edges() == "" or pid == _player_id:
		return
	if _player_nodes.has(pid):
		return
	var remote = player_scene.instantiate()
	remote.name = "RemotePlayer_%s" % pid
	remote.position = pos
	$GameLayer.add_child(remote)
	_player_nodes[pid] = remote


func _setup_relay_for_arena() -> void:
	if _relay_client == null:
		return

	# Ensure relay client survives scene changes
	if _relay_client.get_parent() == get_tree().root:
		get_tree().root.remove_child(_relay_client)
		add_child(_relay_client)

	if _relay_client.has_signal("connected_to_relay"):
		if not _relay_client.connected_to_relay.is_connected(_on_relay_connected):
			_relay_client.connected_to_relay.connect(_on_relay_connected)
	if _relay_client.has_signal("disconnected_from_relay"):
		if not _relay_client.disconnected_from_relay.is_connected(_on_relay_disconnected):
			_relay_client.disconnected_from_relay.connect(_on_relay_disconnected)
	if _relay_client.has_signal("message_received"):
		if not _relay_client.message_received.is_connected(_on_relay_message):
			_relay_client.message_received.connect(_on_relay_message)

	if _relay_client.has_method("is_relay_connected"):
		_relay_connected = _relay_client.is_relay_connected()

	if _is_host_mp:
		_enemy_state_timer = Timer.new()
		_enemy_state_timer.wait_time = ENEMY_STATE_SEND_INTERVAL
		_enemy_state_timer.one_shot = false
		_enemy_state_timer.autostart = true
		_enemy_state_timer.timeout.connect(_broadcast_enemy_state)
		add_child(_enemy_state_timer)


func _announce_arena_ready() -> void:
	if not _multiplayer or _relay_client == null:
		return
	_send_relay({
		"type": "dt_arena_hello",
		"player_id": _player_id
	})

	# Client requests a full sync at start; host will respond.
	if not _is_host_mp:
		_request_full_sync()


func _on_relay_connected() -> void:
	_relay_connected = true
	_announce_arena_ready()


func _on_relay_disconnected() -> void:
	_relay_connected = false


func _on_relay_message(data: Dictionary) -> void:
	var t := str(data.get("type", ""))
	match t:
		"dt_arena_hello", "dt_arena_sync_request":
			if _is_host_mp:
				_send_arena_full_sync(str(data.get("player_id", "")))
		"dt_arena_sync":
			if not _is_host_mp:
				_apply_arena_full_sync(data)
		"dt_enemy_spawn":
			if not _is_host_mp:
				_spawn_enemy_from_relay(data)
		"dt_enemy_state":
			if not _is_host_mp:
				_apply_enemy_state(data)
		"dt_enemy_destroy":
			if not _is_host_mp:
				_apply_enemy_destroy(data)
		"dt_enemy_remove":
			if not _is_host_mp:
				_apply_enemy_remove(data)
		"dt_shot":
			# Both host and clients should render other players' projectiles.
			_apply_remote_shot(data)
		"dt_kill_request":
			if _is_host_mp:
				_handle_kill_request(data)
		"dt_match_end":
			if not _is_host_mp:
				_apply_match_end_and_send_stats(data)
		"dt_player_stats":
			if _is_host_mp:
				_collect_player_stats(data)
		"dt_postgame":
			_apply_postgame_and_transition(data)
		_:
			pass


func _send_relay(payload: Dictionary) -> void:
	if _relay_client == null:
		return
	if _relay_client.has_method("send_message"):
		_relay_client.send_message(payload)


func _request_full_sync() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_sync_request_ms < int(ARENA_SYNC_THROTTLE * 1000.0):
		return
	_last_sync_request_ms = now_ms
	_send_relay({
		"type": "dt_arena_sync_request",
		"player_id": _player_id
	})


func _send_arena_full_sync(_to_player_id: String) -> void:
	# Relay doesn't support direct messaging; broadcast is fine.
	var enemies: Array = []
	for enemy in enemy_container.get_children():
		var eid := _get_enemy_id(enemy)
		if eid == "":
			continue
		enemies.append({
			"enemy_id": eid,
			"enemy_type": str(enemy.enemy_type),
			"word": str(enemy.word),
			"x": enemy.position.x,
			"y": enemy.position.y,
			"speed": float(enemy.speed)
		})

	_send_relay({
		"type": "dt_arena_sync",
		"wave": wave,
		"health": health,
		"score": score,
		"scores": _scores_by_player,
		"wave_spawning_complete": wave_spawning_complete,
		"enemies_spawned_this_wave": enemies_spawned_this_wave,
		"enemies": enemies
	})


func _apply_arena_full_sync(data: Dictionary) -> void:
	# Reset local enemies to match host snapshot
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	_enemies_by_id.clear()

	var prev_wave := wave
	wave = int(data.get("wave", wave))
	health = int(data.get("health", health))
	var scores_any = data.get("scores", null)
	if typeof(scores_any) == TYPE_DICTIONARY:
		_scores_by_player = scores_any
	score = int(_scores_by_player.get(_player_id, int(data.get("score", score))))
	wave_spawning_complete = bool(data.get("wave_spawning_complete", wave_spawning_complete))
	enemies_spawned_this_wave = int(data.get("enemies_spawned_this_wave", enemies_spawned_this_wave))
	_update_ui()
	if wave != prev_wave:
		_last_wave_seen = wave
		_show_wave_notification()

	var enemies: Array = data.get("enemies", [])
	for e in enemies:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		_spawn_enemy_from_relay(e)


func _spawn_enemy_from_relay(data: Dictionary) -> void:
	var enemy_id := str(data.get("enemy_id", data.get("id", "")))
	if enemy_id == "":
		return
	if _enemies_by_id.has(enemy_id):
		return

	var enemy_type := str(data.get("enemy_type", "virus"))
	var word := str(data.get("word", ""))
	var x := float(data.get("x", 0.0))
	var y := float(data.get("y", 0.0))
	var sp := float(data.get("speed", 0.0))

	var enemy_scene = ENEMY_SCENES.get(enemy_type, ENEMY_SCENES["virus"])
	var enemy = enemy_scene.instantiate()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = Vector2(x, y)
	enemy.set_word(word)
	enemy.set_enemy_type(enemy_type)
	enemy.speed = sp
	# Client: do not simulate downward motion; host will send positions.
	enemy.speed = 0.0

	_set_enemy_id(enemy, enemy_id)
	_enemies_by_id[enemy_id] = enemy

	enemy.reached_bottom.connect(_on_enemy_reached_bottom)
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy_container.add_child(enemy)


func _apply_enemy_state(data: Dictionary) -> void:
	var prev_wave := wave
	wave = int(data.get("wave", wave))
	health = int(data.get("health", health))
	# If the host says we're dead, stop local gameplay immediately (postgame will arrive via dt_match_end/dt_postgame).
	if health <= 0 and not game_over:
		game_over = true
		targeting_beam.visible = false
		_clear_typing()
	var scores_any = data.get("scores", null)
	if typeof(scores_any) == TYPE_DICTIONARY:
		_scores_by_player = scores_any
	score = int(_scores_by_player.get(_player_id, int(data.get("score", score))))
	wave_spawning_complete = bool(data.get("wave_spawning_complete", wave_spawning_complete))
	enemies_spawned_this_wave = int(data.get("enemies_spawned_this_wave", enemies_spawned_this_wave))
	_update_ui()
	if wave != prev_wave and wave != _last_wave_seen:
		_last_wave_seen = wave
		_show_wave_notification()

	var enemies: Array = data.get("enemies", [])
	var seen: Dictionary = {}
	for e in enemies:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var eid := str(e.get("id", e.get("enemy_id", "")))
		if eid == "":
			continue
		seen[eid] = true
		var enemy_any = _enemies_by_id.get(eid, null)
		if enemy_any == null or not is_instance_valid(enemy_any):
			# Stale mapping (freed instance) or missing enemy; clean up and resync.
			_enemies_by_id.erase(eid)
			_request_full_sync()
			continue
		var enemy := enemy_any as Node2D
		if enemy == null:
			_enemies_by_id.erase(eid)
			_request_full_sync()
			continue
		enemy.position = Vector2(float(e.get("x", enemy.position.x)), float(e.get("y", enemy.position.y)))

	# Reconcile: if we have enemies not in snapshot, request sync.
	for eid in _enemies_by_id.keys():
		if not seen.has(eid):
			_request_full_sync()
			break


func _apply_enemy_destroy(data: Dictionary) -> void:
	var eid := str(data.get("enemy_id", ""))
	if eid == "":
		return
	var enemy_any = _enemies_by_id.get(eid, null)
	if enemy_any == null or not is_instance_valid(enemy_any):
		_enemies_by_id.erase(eid)
		if current_target != null and not is_instance_valid(current_target):
			_clear_typing()
		return
	var enemy := enemy_any as Node2D
	if enemy and enemy.has_method("destroy"):
		_enemies_by_id.erase(eid)
		if enemy == current_target:
			_clear_typing()
		enemy.destroy()
	# Best-effort: update local score immediately if points were included.
	var by_pid := str(data.get("by", ""))
	var pts := int(data.get("points", 0))
	if by_pid != "" and pts > 0:
		_scores_by_player[by_pid] = int(_scores_by_player.get(by_pid, 0)) + pts
		score = int(_scores_by_player.get(_player_id, score))
		_update_ui()


func _apply_enemy_remove(data: Dictionary) -> void:
	var eid := str(data.get("enemy_id", ""))
	if eid == "":
		return
	var enemy_any = _enemies_by_id.get(eid, null)
	if enemy_any == null or not is_instance_valid(enemy_any):
		_enemies_by_id.erase(eid)
		if current_target != null and not is_instance_valid(current_target):
			_clear_typing()
		return
	var enemy := enemy_any as Node2D
	if enemy == null:
		_enemies_by_id.erase(eid)
		return
	_enemies_by_id.erase(eid)
	if enemy == current_target:
		_clear_typing()
	enemy.queue_free()


func _handle_kill_request(data: Dictionary) -> void:
	var eid := str(data.get("enemy_id", ""))
	var by_pid := str(data.get("player_id", ""))
	if eid == "" or by_pid == "":
		return
	var enemy_any = _enemies_by_id.get(eid, null)
	if enemy_any == null or not is_instance_valid(enemy_any):
		_enemies_by_id.erase(eid)
		return
	var enemy := enemy_any as Node2D
	if enemy == null:
		_enemies_by_id.erase(eid)
		return
	_destroy_enemy_authoritative(enemy, by_pid)


func _destroy_enemy_authoritative(enemy: Node2D, by_pid: String) -> void:
	var eid := _get_enemy_id(enemy)
	if eid == "":
		return
	
	# Play destroy sound effect (alternate between 2 sounds)
	if randi() % 2 == 0:
		if destroy_sfx:
			destroy_sfx.play()
	else:
		if destroy_sfx2:
			destroy_sfx2.play()
	
	enemy.set_meta("killed_by", by_pid)
	# Broadcast destroy first so clients can start animation quickly.
	_send_relay({
		"type": "dt_enemy_destroy",
		"enemy_id": eid,
		"by": by_pid
	})
	_enemies_by_id.erase(eid)
	enemy.destroy()


func _broadcast_enemy_state() -> void:
	if not _multiplayer or not _is_host_mp:
		return
	if _relay_client == null:
		return

	var enemies: Array = []
	for enemy in enemy_container.get_children():
		var eid := _get_enemy_id(enemy)
		if eid == "":
			continue
		enemies.append({
			"id": eid,
			"x": enemy.position.x,
			"y": enemy.position.y
		})

	_send_relay({
		"type": "dt_enemy_state",
		"wave": wave,
		"health": health,
		"score": score,
		"scores": _scores_by_player,
		"wave_spawning_complete": wave_spawning_complete,
		"enemies_spawned_this_wave": enemies_spawned_this_wave,
		"enemies": enemies
	})


func _apply_match_end_and_send_stats(data: Dictionary) -> void:
	# Host ended the match; respond with this client's typing analytics.
	if _awaiting_postgame:
		return
	_awaiting_postgame = true
	game_over = true
	# Clear enemies locally for cleanliness.
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	_enemies_by_id.clear()
	_clear_typing()

	var duration_ms := int(data.get("duration_ms", 0))
	var local_stats := _build_local_typing_stats(duration_ms)
	local_stats["type"] = "dt_player_stats"
	local_stats["player_id"] = _player_id
	_send_relay(local_stats)


func _collect_player_stats(data: Dictionary) -> void:
	var pid := str(data.get("player_id", "")).strip_edges()
	if pid == "":
		return
	_pending_player_stats[pid] = {
		"wpm": float(data.get("wpm", 0.0)),
		"accuracy_pct": float(data.get("accuracy_pct", 0.0)),
		"longest_streak": int(data.get("longest_streak", 0))
	}


func _apply_postgame_and_transition(data: Dictionary) -> void:
	# All peers transition using the host-provided payload.
	_go_to_postgame(data)


func _build_local_typing_stats(duration_ms: int) -> Dictionary:
	var minutes: float = maxf(0.01, float(duration_ms) / 60000.0)
	var wpm: float = (float(_typing_correct_keys) / 5.0) / minutes
	var total := _typing_correct_keys + _typing_wrong_keys
	var accuracy := 0.0
	if total > 0:
		accuracy = (float(_typing_correct_keys) / float(total)) * 100.0
	return {
		"wpm": wpm,
		"accuracy_pct": accuracy,
		"longest_streak": _typing_longest_streak
	}


func _host_finalize_and_broadcast_postgame() -> void:
	if _awaiting_postgame:
		return
	_awaiting_postgame = true
	var duration_ms: int = maxi(0, Time.get_ticks_msec() - _match_start_ms)

	# Ensure host stats exist.
	_pending_player_stats[_player_id] = _build_local_typing_stats(duration_ms)

	# Ask clients to send stats.
	_send_relay({
		"type": "dt_match_end",
		"mode": _mode,
		"duration_ms": duration_ms,
		"wave_reached": wave,
		"scores": _scores_by_player
	})

	# Wait briefly for client responses.
	await get_tree().create_timer(1.0).timeout

	# Build ordered player list.
	var players: Array = []
	if _multiplayer:
		for slot_name in ["host", "client", "client2"]:
			var slot: Dictionary = _room_data.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			var pid := str(slot.get("player_id", "")).strip_edges()
			if pid == "":
				continue
			players.append({
				"player_id": pid,
				"username": str(slot.get("username", "Player"))
			})
	else:
		players.append({"player_id": _player_id, "username": (Auth.current_username if Auth else "Player")})

	var stats_by_pid: Dictionary = {}
	for p in players:
		var pid2 := str(p.get("player_id", ""))
		var s: Dictionary = _pending_player_stats.get(pid2, {})
		stats_by_pid[pid2] = {
			"score": int(_scores_by_player.get(pid2, 0)),
			"wpm": float(s.get("wpm", 0.0)),
			"accuracy_pct": float(s.get("accuracy_pct", 0.0)),
			"longest_streak": int(s.get("longest_streak", 0))
		}

	var payload := {
		"type": "dt_postgame",
		"mode": _mode,
		"duration_ms": duration_ms,
		"wave_reached": wave,
		"players": players,
		"stats_by_player_id": stats_by_pid
	}

	# Host transitions too, using the same payload.
	_send_relay(payload)
	_go_to_postgame(payload)


func _send_shot(target: Node2D, is_final: bool) -> void:
	if not _multiplayer:
		return
	var eid := _get_enemy_id(target)
	if eid == "":
		return
	_send_relay({
		"type": "dt_shot",
		"player_id": _player_id,
		"enemy_id": eid,
		"final": is_final
	})


func _apply_remote_shot(data: Dictionary) -> void:
	var pid := str(data.get("player_id", ""))
	var eid := str(data.get("enemy_id", ""))
	if pid == "" or eid == "":
		return
	if pid == _player_id:
		return
	var shooter_any = _player_nodes.get(pid, null)
	var enemy_any = _enemies_by_id.get(eid, null)
	if shooter_any == null or not is_instance_valid(shooter_any) or enemy_any == null or not is_instance_valid(enemy_any):
		if enemy_any != null and not is_instance_valid(enemy_any):
			_enemies_by_id.erase(eid)
		# We might be out of sync (late join) - ask for a snapshot.
		if not _is_host_mp:
			_request_full_sync()
		return
	var shooter := shooter_any as Node2D
	var enemy := enemy_any as Node2D
	if shooter == null or enemy == null:
		return

	# Rotate remote player towards target for better readability.
	_rotate_player_node_to_target(shooter, enemy)
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.target = enemy
	projectile.global_position = shooter.global_position
	effects_layer.add_child(projectile)


func _rotate_player_node_to_target(player_node: Node2D, target: Node2D) -> void:
	if player_node == null or target == null:
		return
	if not is_instance_valid(player_node) or not is_instance_valid(target):
		return
	var direction = target.global_position - player_node.global_position
	var target_angle = direction.angle() + PI / 2
	var tween = create_tween()
	tween.tween_property(player_node, "rotation", target_angle, 0.1).set_ease(Tween.EASE_OUT)


func _set_enemy_id(enemy, enemy_id: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("set_meta"):
		enemy.set_meta("enemy_id", enemy_id)


func _get_enemy_id(enemy) -> String:
	# NOTE: keep this untyped; relay timing can cause references to be freed.
	if enemy == null or not is_instance_valid(enemy):
		return ""
	if enemy.has_method("has_meta") and enemy.has_meta("enemy_id"):
		return str(enemy.get_meta("enemy_id"))
	return ""

func _screen_shake() -> void:
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

# === UI Updates ===
func _update_ui() -> void:
	health_bar.value = health
	health_label.text = "HP: %d/%d" % [health, max_health]
	score_label.text = "SCORE: %d" % score
	wave_label.text = "WAVE: %d" % wave
	
	# Health bar color based on health
	var health_percent = float(health) / float(max_health)
	var style = StyleBoxFlat.new()
	if health_percent > 0.6:
		style.bg_color = Color(0, 0.9, 0.5)
	elif health_percent > 0.3:
		style.bg_color = Color(1, 0.8, 0)
	else:
		style.bg_color = Color(1, 0.2, 0.2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	health_bar.add_theme_stylebox_override("fill", style)

func _show_wave_notification() -> void:
	var notif = Label.new()
	notif.text = "WAVE %d" % wave
	notif.add_theme_font_size_override("font_size", 48)
	notif.add_theme_color_override("font_color", Color(0, 1, 1))
	notif.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	notif.add_theme_constant_override("outline_size", 6)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.size = Vector2(400, 60)
	notif.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 30)
	$CanvasLayer.add_child(notif)
	
	# Animate
	notif.modulate.a = 0
	notif.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(notif, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	await tween.finished
	await get_tree().create_timer(1.0).timeout
	tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 0.5)
	await tween.finished
	notif.queue_free()

# === Game Over ===
func _game_over() -> void:
	game_over = true
	
	# Play game over sound effect and stop background music
	if bg_music:
		bg_music.stop()
	if game_over_sfx:
		game_over_sfx.play()

	# Multiplayer: host drives post-game transition.
	if _multiplayer:
		if _is_host_mp:
			# Call directly (not deferred) so we always kick off the coroutine.
			_host_finalize_and_broadcast_postgame()
		return
	
	# Clear remaining enemies
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	
	targeting_beam.visible = false
	
	# Solo: go straight to post-game screen.
	var duration_ms: int = maxi(0, Time.get_ticks_msec() - _match_start_ms)
	var local_typing := _build_local_typing_stats(duration_ms)
	var players := [{"player_id": _player_id, "username": (Auth.current_username if Auth else "Player")}]
	var stats_by_pid := {
		_player_id: {
			"score": int(_scores_by_player.get(_player_id, score)),
			"wpm": float(local_typing.get("wpm", 0.0)),
			"accuracy_pct": float(local_typing.get("accuracy_pct", 0.0)),
			"longest_streak": int(local_typing.get("longest_streak", 0))
		}
	}
	_go_to_postgame({
		"mode": "solo",
		"duration_ms": duration_ms,
		"wave_reached": wave,
		"players": players,
		"stats_by_player_id": stats_by_pid
	})

func _on_retry_pressed() -> void:
	game_over_panel.visible = false
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	_start_game()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")

func _on_menu_button_pressed() -> void:
	if menu_panel:
		menu_panel.visible = !menu_panel.visible
		if menu_panel.visible:
			menu_panel.move_to_front()
		print("[DefuseTrojan] 🎮 Menu panel toggled: %s" % ("VISIBLE" if menu_panel.visible else "HIDDEN"))


func _go_to_postgame(payload: Dictionary) -> void:
	if _postgame_transitioned:
		return
	_postgame_transitioned = true
	# Pass relay client through so the session can be resumed/closed cleanly.
	# IMPORTANT: it must not be a child of this arena scene when we change scenes,
	# otherwise it will be freed and become an invalid instance in postgame.
	var relay_any = _relay_client
	if relay_any != null and is_instance_valid(relay_any):
		var parent := relay_any.get_parent()
		if parent != null and parent != get_tree().root:
			parent.remove_child(relay_any)
			get_tree().root.add_child(relay_any)
	else:
		relay_any = null
	var init := {
		"mode": str(payload.get("mode", _mode)),
		"duration_ms": int(payload.get("duration_ms", 0)),
		"wave_reached": int(payload.get("wave_reached", wave)),
		"players": payload.get("players", []),
		"stats_by_player_id": payload.get("stats_by_player_id", {}),
		"relay_client": relay_any
	}
	get_tree().set_meta("defuse_trojan_postgame_init", init)
	get_tree().change_scene_to_file("res://scene/defuse_trojan_postgame.tscn")
	
func _on_exit_match_requested() -> void:
	print("[DefuseTrojan] 🚪 Exit match requested — forfeiting")
	game_over = true

	if bg_music:
		bg_music.stop()

	# Clear enemies
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	_enemies_by_id.clear()
	targeting_beam.visible = false
	_clear_typing()

	var duration_ms: int = maxi(0, Time.get_ticks_msec() - _match_start_ms)

	if _multiplayer and _is_host_mp:
		# Multiplayer host: broadcast forfeit then go to postgame
		_host_finalize_and_broadcast_postgame()
		return
	elif _multiplayer and not _is_host_mp:
		# Multiplayer client: notify host and leave
		_send_relay({
			"type": "dt_player_forfeit",
			"player_id": _player_id
		})

	# Solo OR multiplayer client fallback: go straight to postgame
	var local_typing := _build_local_typing_stats(duration_ms)
	var players := [{"player_id": _player_id, "username": (Auth.current_username if Auth else "Player")}]
	var stats_by_pid := {
		_player_id: {
			"score": int(_scores_by_player.get(_player_id, score)),
			"wpm": float(local_typing.get("wpm", 0.0)),
			"accuracy_pct": float(local_typing.get("accuracy_pct", 0.0)),
			"longest_streak": int(local_typing.get("longest_streak", 0))
		}
	}
	_go_to_postgame({
		"mode": _mode,
		"duration_ms": duration_ms,
		"wave_reached": wave,
		"players": players,
		"stats_by_player_id": stats_by_pid
	})