extends Node2D

# Game States
enum GameState { TUTORIAL, DES_PHASE, DES_FAILED, AES_PHASE, VICTORY }
var current_state = GameState.TUTORIAL

# Encryption Properties
var encryption_type = "DES"
var key_size = 56
var encryption_rounds = 10
var shield_strength = 100.0
var max_shield = 100.0

# Enemy System
var enemies = []
var enemy_speed_multiplier = 1.0
var attack_power = 1.0

# Typing System
var current_command = ""
var available_commands = []
var command_queue = []

# Tutorial Progress
var tutorial_step = 0

# References
@onready var shield_bar = $UI/ShieldBar
@onready var command_input = $UI/CommandInput
@onready var command_list = $UI/CommandList
@onready var status_label = $UI/StatusLabel
@onready var phase_label = $UI/PhaseLabel
@onready var explanation_panel = $UI/ExplanationPanel
@onready var encryption_visual = $EncryptionVisual
@onready var enemy_container = $EnemyContainer

func _ready():
	# Add delay to ensure all nodes are ready
	await get_tree().process_frame
	setup_ui()
	start_tutorial()

func setup_ui():
	# Check if nodes exist before accessing
	if command_input:
		command_input.text_submitted.connect(_on_command_submitted)
		command_input.grab_focus()
	if shield_bar:
		shield_bar.max_value = max_shield
		shield_bar.value = shield_strength
	if explanation_panel:
		explanation_panel.hide()

func start_tutorial():
	current_state = GameState.TUTORIAL
	if phase_label:
		phase_label.text = "TUTORIAL - Understanding DES"
	show_explanation("Welcome to Encryption Battle!\n\nYou'll defend encrypted data by typing cryptography commands.\n\nFirst, let's see how DES encryption works with a 56-bit key.\n\nPress ENTER to continue...")
	if explanation_panel:
		await explanation_panel.confirmed
		start_des_phase()
	else:
		start_des_phase()

func start_des_phase():
	current_state = GameState.DES_PHASE
	encryption_type = "DES"
	key_size = 56
	encryption_rounds = 10
	shield_strength = 100.0
	attack_power = 15.0  # DES is vulnerable
	
	if phase_label:
		phase_label.text = "PHASE 1: DES (56-bit) - Defend the Data!"
	if encryption_visual:
		encryption_visual.set_encryption_type("DES", key_size)
	
	available_commands = ["KEY_56", "ROUND_10", "SUBSTITUTION", "PERMUTATION"]
	update_command_list()
	
	spawn_enemies()
	if status_label:
		status_label.text = "Type commands to strengthen encryption!"

func start_aes_phase():
	current_state = GameState.AES_PHASE
	encryption_type = "AES"
	key_size = 256
	encryption_rounds = 14
	shield_strength = 100.0
	attack_power = 2.0  # AES is strong
	
	if phase_label:
		phase_label.text = "PHASE 2: AES (256-bit) - Same Attackers, Better Defense!"
	if encryption_visual:
		encryption_visual.set_encryption_type("AES", key_size)
	
	available_commands = ["KEY_256", "ROUND_14", "SUBSTITUTION", "MIXCOLUMNS", "SHIFTROWS"]
	update_command_list()
	
	# Clear old enemies
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	
	spawn_enemies()
	if status_label:
		status_label.text = "AES encryption active - much stronger defense!"

func spawn_enemies():
	enemies.clear()
	
	# Spawn 3 enemy types
	var enemy_types = [
		{"name": "Legacy Attacker", "speed": 0.5, "color": Color.ORANGE},
		{"name": "GPU Attacker", "speed": 1.0, "color": Color.RED},
		{"name": "Advanced Attacker", "speed": 1.5, "color": Color.DARK_RED}
	]
	
	for i in range(3):
		var enemy = preload("res://scene/DsvsAesEnemy.tscn").instantiate()
		enemy.position = Vector2(1000, 200 + i * 150)
		enemy.setup(enemy_types[i]["name"], enemy_types[i]["speed"], enemy_types[i]["color"])
		enemy_container.add_child(enemy)
		enemies.append(enemy)

func update_command_list():
	if command_list:
		command_list.text = "Available Commands:\n"
		for cmd in available_commands:
			command_list.text += "• " + cmd + "\n"

func _on_command_submitted(text: String):
	var cmd = text.to_upper().strip_edges()
	if command_input:
		command_input.clear()
	
	if cmd in available_commands:
		execute_command(cmd)
	else:
		if status_label:
			status_label.text = "Invalid command! Check the list."
		flash_screen(Color.RED)

func execute_command(cmd: String):
	if status_label:
		status_label.text = "✓ " + cmd + " executed!"
	flash_screen(Color.GREEN)
	
	# Strengthen shield
	shield_strength = min(shield_strength + 10, max_shield)
	
	# Push enemies back
	for enemy in enemies:
		enemy.push_back(50)
	
	# Visual feedback
	if encryption_visual:
		encryption_visual.pulse()

func _process(delta):
	if current_state == GameState.DES_PHASE or current_state == GameState.AES_PHASE:
		# Enemies attack
		for enemy in enemies:
			if enemy.is_attacking():
				shield_strength -= attack_power * delta
		
		if shield_bar:
			shield_bar.value = shield_strength
		
		# Check failure
		if shield_strength <= 0:
			if current_state == GameState.DES_PHASE:
				des_failed()
			else:
				aes_failed()
		
		# Check victory (all enemies pushed back enough)
		var all_far = true
		for enemy in enemies:
			if enemy.position.x < 900:
				all_far = false
		
		if all_far and current_state == GameState.AES_PHASE:
			victory()

func des_failed():
	current_state = GameState.DES_FAILED
	if status_label:
		status_label.text = "ENCRYPTION BROKEN!"
	
	show_explanation(
		"DES ENCRYPTION FAILED\n\n" +
		"Even with perfect typing, DES cannot resist modern attacks.\n\n" +
		"Why?\n" +
		"• 56-bit keys = only 72 quadrillion possibilities\n" +
		"• Modern computers can test billions of keys per second\n" +
		"• Can be broken in hours or days\n\n" +
		"Let's try again with AES - designed for modern threats!\n\n" +
		"Press ENTER to continue..."
	)
	if explanation_panel:
		await explanation_panel.confirmed
		start_aes_phase()
	else:
		await get_tree().create_timer(2.0).timeout
		start_aes_phase()

func aes_failed():
	if status_label:
		status_label.text = "Keep typing commands!"
	shield_strength = 20.0  # Give some recovery

func victory():
	current_state = GameState.VICTORY
	if status_label:
		status_label.text = "VICTORY! Data Secured!"
	
	show_explanation(
		"AES ENCRYPTION SUCCESS!\n\n" +
		"The same attackers couldn't break AES.\n\n" +
		"Why?\n" +
		"• 256-bit keys = 2^256 possibilities (astronomically large)\n" +
		"• Would take billions of years with all computers on Earth\n" +
		"• Designed with modern cryptanalysis in mind\n\n" +
		"Key Lesson:\n" +
		"Encryption strength isn't about effort alone—\n" +
		"it's about algorithm design.\n\n" +
		"DES was obsolete. AES is the modern standard.\n\n" +
		"🔓 UNLOCKED: Next cryptography topics!"
	)

func show_explanation(text: String):
	if explanation_panel:
		explanation_panel.show()
		var label = explanation_panel.get_node("MarginContainer/VBoxContainer/Label")
		if label:
			label.text = text

func flash_screen(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.color.a = 0.3
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)
