extends Control

# This is an IMPROVED version with better educational context

# Game state
enum GameState { MENU, TUTORIAL, PLAYING, GAME_OVER, VICTORY }
var current_state: GameState = GameState.MENU

# Player stats
var player_health: int = 100
var player_max_health: int = 100
var player_shield: int = 0
var player_level: int = 1
var experience: int = 0
var keys_collected: int = 0

# Combat
var enemies: Array = []
var combo_count: int = 0
var last_attack_time: float = 0.0

# Keys and abilities
var has_public_key: bool = false
var has_private_key: bool = false
var can_encrypt: bool = false
var can_decrypt: bool = false
var encryption_power: int = 1

# Tutorial state
var tutorial_step: int = 0
var tutorial_active: bool = false

# Boss
var boss_health: int = 0
var boss_max_health: int = 300
var boss_active: bool = false

# Waves
var current_wave: int = 0
var wave_active: bool = false
var enemies_remaining: int = 0
var spawn_timer: float = 0.0

# Node references
@onready var player_sprite = $GameArea/PlayerArea/PlayerSprite
@onready var player_health_bar = $UI/TopBar/HBoxContainer/PlayerStats/HealthBar
@onready var player_health_label = $UI/TopBar/HBoxContainer/PlayerStats/HealthLabel
@onready var level_label = $UI/TopBar/HBoxContainer/PlayerStats/LevelLabel
@onready var keys_label = $UI/TopBar/HBoxContainer/PlayerStats/KeysLabel
@onready var wave_label = $UI/TopBar/HBoxContainer/WaveInfo/WaveLabel
@onready var enemy_container = $GameArea/EnemyArea
@onready var attack_container = $GameArea/AttackArea
@onready var ability_container = $UI/BottomBar/AbilityBar
@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_text = $DialoguePanel/VBox/DialogueText
@onready var menu_panel = $MenuPanel
@onready var game_over_panel = $GameOverPanel
@onready var boss_health_bar = $UI/BossBar/VBoxContainer/BossHealthBar
@onready var tutorial_label = $UI/TutorialLabel
@onready var explanation_panel = $ExplanationPanel
@onready var explanation_text = $ExplanationPanel/VBox/ExplanationText

# Enemy types with CLEAR cyber threat explanations
var enemy_types = [
	{
		"name": "Plaintext Snooper",
		"sprite": "📄",
		"health": 25,
		"damage": 8,
		"speed": 80,
		"color": Color.RED,
		"weakness": "encrypt",
		"explanation": "This enemy reads UNENCRYPTED data!\n\n🔓 Without encryption, your messages are like postcards - anyone can read them!\n\n✅ Solution: ENCRYPT with your public key to scramble the data!",
		"real_world": "Real example: HTTP vs HTTPS. HTTP sends passwords in plaintext!"
	},
	{
		"name": "Key Thief",
		"sprite": "🔓",
		"health": 30,
		"damage": 12,
		"speed": 70,
		"color": Color.ORANGE,
		"weakness": "encrypt",
		"explanation": "This enemy tries to STEAL your private key!\n\n🔐 Your private key must NEVER be shared or stolen!\n\n✅ Keep it encrypted and protected at all times!",
		"real_world": "Real example: Hackers stealing SSH keys or crypto wallet keys!"
	},
	{
		"name": "Man-in-Middle",
		"sprite": "🎭",
		"health": 40,
		"damage": 15,
		"speed": 60,
		"color": Color.PURPLE,
		"weakness": "verify",
		"explanation": "This enemy intercepts your messages!\n\n📡 They sit between you and your friend, reading and changing messages!\n\n✅ Solution: Use public key encryption - they can't read encrypted data!",
		"real_world": "Real example: Fake WiFi hotspots at coffee shops!"
	},
	{
		"name": "Message Replayer",
		"sprite": "♻️",
		"health": 35,
		"damage": 10,
		"speed": 90,
		"color": Color.YELLOW,
		"weakness": "encrypt",
		"explanation": "This enemy records old messages and replays them!\n\n📼 They captured a valid message like 'Send $100' and replay it multiple times!\n\n✅ Solution: Encrypt with timestamps and nonces!",
		"real_world": "Real example: Recording a car key fob signal and replaying it to unlock!"
	}
]

# EDUCATIONAL tutorial steps
var tutorial_steps = [
	{
		"title": "🌐 The Problem: Sending Secrets",
		"message": "Imagine you want to send a SECRET MESSAGE to your friend Bob.\n\nBut there are SPIES watching the network!\n\nIf you send it normally, they can READ EVERYTHING! 😱",
		"visual": "show_plaintext_danger",
		"action_needed": false
	},
	{
		"title": "🔑 The Solution: Public & Private Keys",
		"message": "Here's the MAGIC:\n\n🔑 PUBLIC KEY = A padlock you give to EVERYONE\n🔐 PRIVATE KEY = The ONLY key that opens that padlock\n\nAnyone can LOCK messages (encrypt)\nOnly YOU can UNLOCK them (decrypt)!",
		"visual": "show_key_analogy",
		"action_needed": false
	},
	{
		"title": "🔒 Try Encrypting!",
		"message": "You found a PUBLIC KEY!\n\nWhen you press [E], you ENCRYPT enemy data:\n\n📝 Original → 🔒 Scrambled Gibberish\n\nEven if enemies see it, they can't read it!\n\nTry it now - press [E] to encrypt!",
		"visual": "highlight_encrypt",
		"action_needed": true,
		"action_key": "encrypt"
	},
	{
		"title": "🔓 Decryption Heals",
		"message": "You found the PRIVATE KEY!\n\nYour private key can DECRYPT data:\n\n🔒 Scrambled → 📝 Original Message\n\nIn this game, decrypting = recovering/healing data!\n\nPress [D] to decrypt and heal!",
		"visual": "highlight_decrypt",
		"action_needed": true,
		"action_key": "decrypt"
	},
	{
		"title": "🎓 What You Learned!",
		"message": "✅ PUBLIC KEY encrypts (locks) data\n✅ PRIVATE KEY decrypts (unlocks) data\n✅ Enemies can't read encrypted data\n✅ This is how HTTPS, SSH, and crypto work!\n\nNow fight the boss!",
		"visual": "show_summary",
		"action_needed": false
	}
]

func _ready():
	show_menu()
	if boss_health_bar:
		boss_health_bar.get_parent().visible = false
	if tutorial_label:
		tutorial_label.visible = false
	explanation_panel.visible = false

func _process(delta):
	if current_state == GameState.PLAYING and not tutorial_active:
		process_combat(delta)
		process_abilities()
	elif current_state == GameState.TUTORIAL:
		process_tutorial_input()

func show_menu():
	current_state = GameState.MENU
	menu_panel.visible = true
	game_over_panel.visible = false
	dialogue_panel.visible = false

func start_game():
	current_state = GameState.TUTORIAL
	menu_panel.visible = false
	tutorial_active = true
	tutorial_step = 0
	
	# Reset everything
	player_health = player_max_health
	player_level = 1
	experience = 0
	keys_collected = 0
	current_wave = 0
	has_public_key = false
	has_private_key = false
	can_encrypt = false
	can_decrypt = false
	encryption_power = 1
	
	update_ui()
	clear_all_enemies()
	
	# Start tutorial
	show_tutorial_step(0)

func show_tutorial_step(step: int):
	if step >= tutorial_steps.size():
		# Tutorial complete, start game
		end_tutorial()
		return
	
	tutorial_step = step
	var step_data = tutorial_steps[step]
	
	explanation_panel.visible = true
	explanation_text.text = "[b]" + step_data["title"] + "[/b]\n\n" + step_data["message"]
	
	# Execute visual demonstration
	if step_data.has("visual"):
		call(step_data["visual"])

func process_tutorial_input():
	var step_data = tutorial_steps[tutorial_step]
	
	if step_data.has("action_needed") and step_data["action_needed"]:
		# Wait for player to perform action
		if step_data["action_key"] == "encrypt" and Input.is_key_pressed(KEY_E):
			show_encrypt_explanation()
			await get_tree().create_timer(3.0).timeout
			next_tutorial_step()
		elif step_data["action_key"] == "decrypt" and Input.is_key_pressed(KEY_D):
			show_decrypt_explanation()
			await get_tree().create_timer(3.0).timeout
			next_tutorial_step()
	else:
		# Just waiting for continue
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			next_tutorial_step()

func next_tutorial_step():
	show_tutorial_step(tutorial_step + 1)

func end_tutorial():
	current_state = GameState.PLAYING
	tutorial_active = false
	explanation_panel.visible = false
	
	# Give player both keys
	has_public_key = true
	has_private_key = true
	can_encrypt = true
	can_decrypt = true
	keys_collected = 2
	
	update_abilities()
	update_ui()
	
	# Start first wave
	start_wave(1)

# Visual demonstrations
func show_plaintext_danger():
	# Show a message being sent in plaintext
	var msg = Label.new()
	msg.text = "📝 Password: MySecret123"
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color.RED)
	msg.position = Vector2(400, 300)
	attack_container.add_child(msg)
	
	await get_tree().create_timer(1.0).timeout
	
	var spy = Label.new()
	spy.text = "👁️ SPY SAW IT!"
	spy.add_theme_font_size_override("font_size", 20)
	spy.add_theme_color_override("font_color", Color.RED)
	spy.position = Vector2(400, 350)
	attack_container.add_child(spy)

func show_key_analogy():
	# Show padlock visualization
	var public = Label.new()
	public.text = "🔑 PUBLIC KEY\n(Padlock - anyone can close it)"
	public.add_theme_font_size_override("font_size", 18)
	public.add_theme_color_override("font_color", Color.YELLOW)
	public.position = Vector2(300, 250)
	attack_container.add_child(public)
	
	var private = Label.new()
	private.text = "🔐 PRIVATE KEY\n(Only key that opens it)"
	private.add_theme_font_size_override("font_size", 18)
	private.add_theme_color_override("font_color", Color.CYAN)
	private.position = Vector2(600, 250)
	attack_container.add_child(private)

func show_encrypt_explanation():
	clear_tutorial_visuals()
	
	var before = Label.new()
	before.text = "📝 Secret Message"
	before.add_theme_font_size_override("font_size", 20)
	before.position = Vector2(300, 250)
	attack_container.add_child(before)
	
	await get_tree().create_timer(1.0).timeout
	
	var encrypt_effect = Label.new()
	encrypt_effect.text = "🔒 ENCRYPTING..."
	encrypt_effect.add_theme_font_size_override("font_size", 24)
	encrypt_effect.add_theme_color_override("font_color", Color.GREEN)
	encrypt_effect.position = Vector2(400, 300)
	attack_container.add_child(encrypt_effect)
	
	await get_tree().create_timer(1.0).timeout
	
	before.queue_free()
	encrypt_effect.queue_free()
	
	var after = Label.new()
	after.text = "🔒 Xj9mK2pQ7wZ..."
	after.add_theme_font_size_override("font_size", 20)
	after.add_theme_color_override("font_color", Color.GREEN)
	after.position = Vector2(300, 250)
	attack_container.add_child(after)
	
	var spy = Label.new()
	spy.text = "👁️ Spy: \"I can't read this!\""
	spy.add_theme_font_size_override("font_size", 16)
	spy.add_theme_color_override("font_color", Color.GRAY)
	spy.position = Vector2(300, 300)
	attack_container.add_child(spy)

func show_decrypt_explanation():
	clear_tutorial_visuals()
	
	var encrypted = Label.new()
	encrypted.text = "🔒 Xj9mK2pQ7wZ..."
	encrypted.add_theme_font_size_override("font_size", 20)
	encrypted.position = Vector2(300, 250)
	attack_container.add_child(encrypted)
	
	await get_tree().create_timer(1.0).timeout
	
	var decrypt_effect = Label.new()
	decrypt_effect.text = "🔓 DECRYPTING..."
	decrypt_effect.add_theme_font_size_override("font_size", 24)
	decrypt_effect.add_theme_color_override("font_color", Color.CYAN)
	decrypt_effect.position = Vector2(400, 300)
	attack_container.add_child(decrypt_effect)
	
	await get_tree().create_timer(1.0).timeout
	
	encrypted.queue_free()
	decrypt_effect.queue_free()
	
	var decrypted = Label.new()
	decrypted.text = "📝 Secret Message (Recovered!)"
	decrypted.add_theme_font_size_override("font_size", 20)
	decrypted.add_theme_color_override("font_color", Color.CYAN)
	decrypted.position = Vector2(300, 250)
	attack_container.add_child(decrypted)

func highlight_encrypt():
	tutorial_label.text = "Press [E] to ENCRYPT and attack!"
	tutorial_label.visible = true

func highlight_decrypt():
	tutorial_label.text = "Press [D] to DECRYPT and heal!"
	tutorial_label.visible = true

func show_summary():
	clear_tutorial_visuals()
	
	var summary = Label.new()
	summary.text = """🎓 CRYPTOGRAPHY SUMMARY

🔑 Public Key = Lock (Encrypt)
🔐 Private Key = Unlock (Decrypt)

Real World Uses:
• HTTPS (secure websites)
• SSH (remote access)  
• Bitcoin (crypto wallets)
• Signal/WhatsApp (messaging)"""
	summary.add_theme_font_size_override("font_size", 16)
	summary.position = Vector2(300, 200)
	attack_container.add_child(summary)

func clear_tutorial_visuals():
	for child in attack_container.get_children():
		child.queue_free()

func process_combat(delta):
	# Spawn enemies
	if wave_active and enemies_remaining > 0:
		spawn_timer += delta
		if spawn_timer >= 2.5:
			spawn_timer = 0.0
			spawn_enemy()
	
	# Move enemies toward player
	for enemy in enemies:
		if is_instance_valid(enemy.node):
			enemy.position.x -= enemy.speed * delta
			enemy.node.position.x = enemy.position.x
			
			# Check if enemy reached player
			if enemy.position.x <= 150:
				take_damage(enemy.damage)
				
				# Show what this enemy does
				show_enemy_explanation(enemy.data)
				
				enemy.node.queue_free()
				enemies.erase(enemy)
				enemies_remaining -= 1
	
	# Check wave completion
	if wave_active and enemies_remaining <= 0 and enemies.size() == 0:
		complete_wave()
	
	# Reset combo if too much time passed
	if Time.get_ticks_msec() - last_attack_time > 2000:
		combo_count = 0

func show_enemy_explanation(enemy_data: Dictionary):
	# Show brief explanation of what this enemy does
	var explain = Label.new()
	explain.text = enemy_data["name"] + " hit you!\n" + enemy_data["explanation"].split("\n")[0]
	explain.add_theme_font_size_override("font_size", 14)
	explain.add_theme_color_override("font_color", Color.RED)
	explain.position = Vector2(200, 400)
	attack_container.add_child(explain)
	
	var tween = create_tween()
	tween.tween_property(explain, "modulate:a", 0.0, 3.0)
	tween.tween_callback(explain.queue_free)

func spawn_enemy():
	var enemy_data = enemy_types[randi() % enemy_types.size()].duplicate()
	
	var enemy = {
		"data": enemy_data,
		"health": enemy_data.health,
		"position": Vector2(1100, randf_range(150, 400)),
		"speed": enemy_data.speed,
		"damage": enemy_data.damage,
		"node": create_enemy_node(enemy_data)
	}
	
	enemies.append(enemy)
	enemy_container.add_child(enemy.node)
	enemy.node.position = enemy.position
	enemies_remaining -= 1

func create_enemy_node(enemy_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	var sprite_label = Label.new()
	sprite_label.text = enemy_data.sprite
	sprite_label.add_theme_font_size_override("font_size", 48)
	sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var name_label = Label.new()
	name_label.text = enemy_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	vbox.add_child(sprite_label)
	vbox.add_child(name_label)
	panel.add_child(vbox)
	
	# Make enemy clickable to show explanation
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			show_full_enemy_explanation(enemy_data)
	)
	
	var style = StyleBoxFlat.new()
	style.bg_color = enemy_data.color
	style.border_color = enemy_data.color.lightened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func show_full_enemy_explanation(enemy_data: Dictionary):
	explanation_panel.visible = true
	explanation_text.text = "[b]" + enemy_data["name"] + "[/b]\n\n" + enemy_data["explanation"] + "\n\n[i]" + enemy_data["real_world"] + "[/i]"

func process_abilities():
	# Encrypt ability (E key)
	if Input.is_key_pressed(KEY_E) and can_encrypt:
		use_encrypt()
	
	# Decrypt ability (D key)
	if Input.is_key_pressed(KEY_D) and can_decrypt:
		use_decrypt()

func use_encrypt():
	if enemies.size() == 0:
		return
	
	# Find nearest enemy
	var nearest = enemies[0]
	var nearest_dist = nearest.position.x
	
	for enemy in enemies:
		if enemy.position.x < nearest_dist:
			nearest = enemy
			nearest_dist = enemy.position.x
	
	# Deal damage
	var damage = 15 * encryption_power
	if nearest.data.weakness == "encrypt":
		damage *= 2
		show_floating_text("ENCRYPTED!", nearest.position, Color.YELLOW)
		show_floating_text("(They can't read it!)", nearest.position + Vector2(0, 30), Color.GREEN)
	
	nearest.health -= damage
	combo_count += 1
	last_attack_time = Time.get_ticks_msec()
	
	# Visual effect showing encryption
	var effect = create_effect("🔒", nearest.position, Color.GREEN)
	attack_container.add_child(effect)
	
	# Show educational feedback
	var edu_feedback = Label.new()
	edu_feedback.text = "Data encrypted!"
	edu_feedback.add_theme_font_size_override("font_size", 12)
	edu_feedback.add_theme_color_override("font_color", Color.GREEN)
	edu_feedback.position = nearest.position + Vector2(-30, -60)
	attack_container.add_child(edu_feedback)
	
	var tween = create_tween()
	tween.tween_property(edu_feedback, "modulate:a", 0.0, 2.0)
	tween.tween_callback(edu_feedback.queue_free)
	
	show_floating_text(str(-damage), nearest.position, Color.WHITE)
	
	# Check if enemy died
	if nearest.health <= 0:
		on_enemy_defeated(nearest)

func use_decrypt():
	# Heal player
	var heal_amount = 10
	player_health = min(player_health + heal_amount, player_max_health)
	update_ui()
	
	# Visual effect
	var effect = create_effect("🔓", player_sprite.global_position, Color.CYAN)
	attack_container.add_child(effect)
	
	show_floating_text("+" + str(heal_amount) + " HP", player_sprite.global_position, Color.GREEN)
	
	# Educational feedback
	var edu_feedback = Label.new()
	edu_feedback.text = "Data decrypted & recovered!"
	edu_feedback.add_theme_font_size_override("font_size", 14)
	edu_feedback.add_theme_color_override("font_color", Color.CYAN)
	edu_feedback.position = player_sprite.global_position + Vector2(-60, -60)
	attack_container.add_child(edu_feedback)
	
	var tween = create_tween()
	tween.tween_property(edu_feedback, "modulate:a", 0.0, 2.0)
	tween.tween_callback(edu_feedback.queue_free)

func create_effect(emoji: String, pos: Vector2, color: Color) -> Label:
	var label = Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y - 50, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
	
	return label

func show_floating_text(text: String, pos: Vector2, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.position = pos + Vector2(randf_range(-20, 20), -30)
	attack_container.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func on_enemy_defeated(enemy):
	# Check if boss was defeated
	if enemy.has("is_boss") and enemy.is_boss:
		victory()
		return
	
	# Add experience
	experience += 15
	if experience >= player_level * 50:
		level_up()
	
	# Visual
	show_floating_text("DEFEATED!", enemy.position, Color.RED)
	show_floating_text("Threat neutralized!", enemy.position + Vector2(0, 30), Color.GREEN)
	enemy.node.queue_free()
	enemies.erase(enemy)

func level_up():
	player_level += 1
	experience = 0
	player_max_health += 20
	player_health = player_max_health
	encryption_power += 1
	
	show_floating_text("LEVEL UP!", player_sprite.global_position, Color.GOLD)
	show_floating_text("Encryption stronger!", player_sprite.global_position + Vector2(0, 30), Color.YELLOW)
	update_ui()

func take_damage(damage: int):
	player_health -= damage
	player_health = max(0, player_health)
	update_ui()
	
	# Flash player
	var tween = create_tween()
	tween.tween_property(player_sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.1)
	
	if player_health <= 0:
		game_over()

func start_wave(wave_num: int):
	current_wave = wave_num
	wave_active = true
	enemies_remaining = 4 + (wave_num * 2)
	spawn_timer = 0.0
	update_ui()

func complete_wave():
	wave_active = false
	
	if current_wave >= 3 and not boss_active:
		start_boss_fight()
	else:
		# Small delay before next wave
		await get_tree().create_timer(2.0).timeout
		start_wave(current_wave + 1)

func start_boss_fight():
	boss_active = true
	boss_health = boss_max_health
	if boss_health_bar:
		boss_health_bar.get_parent().visible = true
	update_ui()
	
	# Show boss explanation
	explanation_panel.visible = true
	explanation_text.text = "[b]👾 MASTER HACKER - FINAL BOSS![/b]\n\nThis is the ultimate cyber threat!\n\nUses all attack types combined.\n\nRemember:\n🔒 Encrypt to attack\n🔓 Decrypt to heal\n\nGood luck!"
	
	await get_tree().create_timer(3.0).timeout
	explanation_panel.visible = false
	
	spawn_boss()

func spawn_boss():
	var boss_data = {
		"name": "Master Hacker",
		"sprite": "👾",
		"health": boss_max_health,
		"damage": 20,
		"speed": 30,
		"color": Color.DARK_RED,
		"weakness": "encrypt",
		"explanation": "The ultimate cyber threat!",
		"real_world": "Represents APT (Advanced Persistent Threats)"
	}
	
	var boss = {
		"data": boss_data,
		"health": boss_max_health,
		"position": Vector2(1100, 300),
		"speed": boss_data.speed,
		"damage": boss_data.damage,
		"node": create_boss_node(boss_data),
		"is_boss": true
	}
	
	enemies.append(boss)
	enemy_container.add_child(boss.node)
	boss.node.position = boss.position

func create_boss_node(boss_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 150)
	
	var vbox = VBoxContainer.new()
	
	var sprite_label = Label.new()
	sprite_label.text = boss_data.sprite
	sprite_label.add_theme_font_size_override("font_size", 72)
	sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var name_label = Label.new()
	name_label.text = boss_data.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	vbox.add_child(sprite_label)
	vbox.add_child(name_label)
	panel.add_child(vbox)
	
	var style = StyleBoxFlat.new()
	style.bg_color = boss_data.color
	style.border_color = Color.RED
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func update_ui():
	if player_health_label:
		player_health_label.text = "❤️ Health: " + str(player_health) + " / " + str(player_max_health)
	if player_health_bar:
		player_health_bar.value = (float(player_health) / float(player_max_health)) * 100
	if level_label:
		level_label.text = "⭐ Level: " + str(player_level)
	if keys_label:
		keys_label.text = "🔑 Keys: " + str(keys_collected)
	if wave_label:
		wave_label.text = "🌊 Wave: " + str(current_wave)
	
	if boss_active and enemies.size() > 0 and boss_health_bar:
		var boss = enemies[0]
		if boss.has("is_boss"):
			boss_health_bar.value = (float(boss.health) / float(boss_max_health)) * 100

func update_abilities():
	# Clear ability bar
	for child in ability_container.get_children():
		child.queue_free()
	
	# Add available abilities with educational labels
	if can_encrypt:
		var btn = Button.new()
		btn.text = "🔒 Encrypt [E]\nLock data"
		btn.custom_minimum_size = Vector2(150, 60)
		btn.pressed.connect(use_encrypt)
		ability_container.add_child(btn)
	
	if can_decrypt:
		var btn = Button.new()
		btn.text = "🔓 Decrypt [D]\nUnlock & heal"
		btn.custom_minimum_size = Vector2(150, 60)
		btn.pressed.connect(use_decrypt)
		ability_container.add_child(btn)

func game_over():
	current_state = GameState.GAME_OVER
	game_over_panel.visible = true
	$GameOverPanel/VBox/ScoreLabel.text = "Waves Survived: " + str(current_wave) + "\nLevel Reached: " + str(player_level) + "\n\nYou learned about encryption!\n🔐 Keep your private keys safe!"

func victory():
	current_state = GameState.VICTORY
	game_over_panel.visible = true
	$GameOverPanel/VBox/TitleLabel.text = "🎉 VICTORY! 🎉"
	$GameOverPanel/VBox/ScoreLabel.text = "You defeated the Master Hacker!\nFinal Level: " + str(player_level) + "\n\n🎓 YOU MASTERED:\n✅ Public key encryption\n✅ Private key decryption\n✅ Cyber threat defense\n\nThis is how HTTPS, SSH,\nand Bitcoin work!"

func clear_all_enemies():
	for enemy in enemies:
		if is_instance_valid(enemy.node):
			enemy.node.queue_free()
	enemies.clear()

func _on_start_button_pressed():
	start_game()

func _on_continue_button_pressed():
	next_tutorial_step()

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	get_tree().quit()

func _on_explanation_close_pressed():
	explanation_panel.visible = false
