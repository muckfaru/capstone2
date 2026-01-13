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

# CMD commands for virus removal - educational content
const COMMANDS: Array = [
	# Basic commands
	"TASKKILL", "NETSTAT", "SFC", "CHKDSK", "ATTRIB",
	"DEL", "RD", "CLS", "IPCONFIG", "PING",
	# Intermediate commands
	"TRACERT", "SHUTDOWN", "MSCONFIG", "REGEDIT", "DISKPART",
	"FORMAT", "XCOPY", "ROBOCOPY", "WMIC", "POWERSHELL",
	# Advanced commands (longer = harder)
	"SYSTEMINFO", "DRIVERQUERY", "TASKLIST", "NETSH", "BCDEDIT",
	"SCHTASKS", "TAKEOWN", "ICACLS", "CERTUTIL", "CIPHER"
]

const ENEMY_TYPES: Array = ["trojan", "worm", "virus", "ransomware"]

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

# Spawning
var spawn_timer: float = 0.0
var base_spawn_interval: float = 2.5
var min_spawn_interval: float = 0.8
var enemies_per_wave: int = 5
var enemies_spawned_this_wave: int = 0

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
@onready var game_over_panel: Panel = $CanvasLayer/GameOverPanel

# Audio
@onready var type_sfx: AudioStreamPlayer = $AudioPlayers/TypeSFX
@onready var destroy_sfx: AudioStreamPlayer = $AudioPlayers/DestroySFX

# === Lifecycle ===
func _ready() -> void:
	_setup_ui()
	_start_game()
	
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
	enemies_destroyed = 0
	enemies_spawned_this_wave = 0
	combo_count = 0
	game_over = false
	typed_text = ""
	current_target = null
	spawn_timer = 0.0
	_update_ui()
	_update_typed_display()

func _process(delta: float) -> void:
	if game_over or game_paused:
		return
	
	# Parallax scrolling effect
	parallax_bg.scroll_offset.y += scroll_speed * delta
	
	# Spawn enemies
	spawn_timer += delta
	var spawn_interval = max(base_spawn_interval - (wave * 0.15), min_spawn_interval)
	
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_enemy()
	
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
				_update_typed_display()
			return
		
		# Handle escape to clear
		if key_event.keycode == KEY_ESCAPE:
			_clear_typing()
			return
		
		# Handle letter/number input
		if key_string.length() == 1 and key_string.to_upper() in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			typed_text += key_string.to_upper()
			_process_typing()

func _process_typing() -> void:
	# If no target, find one that starts with typed text
	if current_target == null or not is_instance_valid(current_target):
		current_target = _find_matching_enemy(typed_text)
	
	if current_target and is_instance_valid(current_target):
		var enemy = current_target as Node2D
		
		# Check if current typed text matches target word
		if enemy.word.begins_with(typed_text):
			# Correct keystroke!
			if enemy.has_method("set_targeted"):
				enemy.set_targeted(true)
				enemy.update_typed_progress(typed_text)
			
			# Check for complete match
			if typed_text == enemy.word:
				combo_count += 1
				# Spawn final projectile that will destroy enemy on hit
				_spawn_final_projectile(enemy)
				_clear_typing()
			else:
				# Spawn regular projectile on correct keystroke
				_spawn_projectile(enemy)
		else:
			# Wrong keystroke - remove the last typed letter and try to find new target
			typed_text = typed_text.substr(0, typed_text.length() - 1)
			
			# Try to find enemy matching current text
			var new_target = _find_matching_enemy(typed_text + OS.get_keycode_string(0))
			if new_target == null:
				# No match at all - flash error
				typed_display.modulate = Color(1, 0.3, 0.3)
				var tween = create_tween()
				tween.tween_property(typed_display, "modulate", Color(1, 1, 1), 0.2)
				combo_count = 0
	else:
		# No current target - try to find one matching typed text
		current_target = _find_matching_enemy(typed_text)
		
		if current_target and is_instance_valid(current_target):
			# Found a new target
			current_target.set_targeted(true)
			current_target.update_typed_progress(typed_text)
			_spawn_projectile(current_target)
		elif typed_text.length() > 0:
			# No matching enemy - remove last letter and flash error
			typed_text = typed_text.substr(0, typed_text.length() - 1)
			typed_display.modulate = Color(1, 0.3, 0.3)
			var tween = create_tween()
			tween.tween_property(typed_display, "modulate", Color(1, 1, 1), 0.2)
	
	_update_typed_display()
	_update_combo_display()


func _spawn_projectile(target: Node2D) -> void:
	"""Spawn a projectile from player to target enemy"""
	if not target or not is_instance_valid(target):
		return
	
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.target = target
	projectile.global_position = player_sprite.global_position
	
	# Add to effects layer
	effects_layer.add_child(projectile)

func _spawn_final_projectile(target: Node2D) -> void:
	"""Spawn a projectile that will destroy enemy when it hits"""
	if not target or not is_instance_valid(target):
		return
	
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.target = target
	projectile.global_position = player_sprite.global_position
	
	# Connect to destroy enemy when hit
	projectile.hit_target.connect(_on_projectile_hit_enemy)
	
	# Add to effects layer
	effects_layer.add_child(projectile)

func _on_projectile_hit_enemy(enemy: Node2D) -> void:
	"""Called when final projectile hits enemy - destroy it"""
	if enemy and is_instance_valid(enemy) and enemy.has_method("destroy"):
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
	if combo_count >= 3:
		combo_label.visible = true
		combo_label.text = "COMBO x%d" % combo_count
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
	if enemies_spawned_this_wave >= enemies_per_wave + wave:
		# Wave complete, advance
		wave += 1
		enemies_spawned_this_wave = 0
		_show_wave_notification()
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
	
	# Increase speed with waves
	enemy.speed += wave * 8
	
	# Connect signals
	enemy.reached_bottom.connect(_on_enemy_reached_bottom)
	enemy.destroyed.connect(_on_enemy_destroyed)
	
	enemy_container.add_child(enemy)
	enemies_spawned_this_wave += 1

func _destroy_enemy(enemy: Node2D) -> void:
	if enemy and is_instance_valid(enemy):
		enemy.destroy()
		_clear_typing()

func _on_enemy_reached_bottom(enemy: Node2D) -> void:
	if game_over:
		return
	
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
	
	if enemy == current_target:
		_clear_typing()
	
	enemy.queue_free()
	
	if health <= 0:
		_game_over()

func _on_enemy_destroyed(enemy: Node2D, points: int) -> void:
	# Combo bonus
	var combo_multiplier = 1.0 + (combo_count * 0.1)
	var final_points = int(points * combo_multiplier)
	score += final_points
	enemies_destroyed += 1
	_update_ui()

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
	
	# Clear remaining enemies
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	
	targeting_beam.visible = false
	
	# Show game over panel
	game_over_panel.visible = true
	var final_score_label = game_over_panel.get_node_or_null("VBoxContainer/FinalScoreLabel")
	if final_score_label:
		final_score_label.text = "FINAL SCORE: %d" % score
	
	var stats_label = game_over_panel.get_node_or_null("VBoxContainer/StatsLabel")
	if stats_label:
		stats_label.text = "Waves: %d | Destroyed: %d" % [wave, enemies_destroyed]

func _on_retry_pressed() -> void:
	game_over_panel.visible = false
	for enemy in enemy_container.get_children():
		enemy.queue_free()
	_start_game()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")
