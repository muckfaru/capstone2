# main_game.gd
extends Control

# Game modes
enum GameMode { TUTORIAL, CHALLENGE }
var game_mode: GameMode = GameMode.TUTORIAL

# Game state
var current_phase: int = 0
var game_state: String = "intro"
var network_data: Array = []
var attacker_knowledge: Array = []

# Challenge mode variables
var current_wave: int = 0
var max_waves: int = 5
var wave_timer: float = 0.0
var wave_duration: float = 30.0  # 30 seconds per wave
var score: int = 0
var lives: int = 3
var incoming_attacks: Array = []
var attack_spawn_timer: float = 0.0
var attack_spawn_interval: float = 3.0

# Phase data
var phases = [
	{
		"title": "Phase 1: The Unsafe Approach",
		"objective": "Try sending the session key directly",
		"explanation": "In this phase, you'll see why sending secrets in plaintext is dangerous.",
		"success": "Sending secrets directly over a public network allows attackers to steal them."
	},
	{
		"title": "Phase 2: Public Key Distribution",
		"objective": "Server shares its public key",
		"explanation": "Watch as the server sends its public key. Notice that the attacker can see it too.",
		"success": "Public keys are designed to be shared openly. They give no advantage to attackers."
	},
	{
		"title": "Phase 3: Secure Key Exchange",
		"objective": "Encrypt the session key with server's public key",
		"explanation": "Now encrypt your session key using the server's public key before sending.",
		"success": "Only the private key can decrypt what the public key encrypts. The attacker is helpless!"
	},
	{
		"title": "Phase 4: Secure Session Established",
		"objective": "Communication is now secure",
		"explanation": "With the session key safely exchanged, fast symmetric encryption protects all messages.",
		"success": "🎉 Secure communication established! The attacker remains blind to your data."
	}
]

# Challenge attack types
var attack_types = [
	{"name": "MITM", "defense": "encrypt", "description": "Man-in-the-Middle Attack!", "color": Color.RED},
	{"name": "REPLAY", "defense": "verify", "description": "Replay Attack Detected!", "color": Color.ORANGE},
	{"name": "SNIFF", "defense": "secure", "description": "Packet Sniffer Active!", "color": Color.PURPLE},
	{"name": "SPOOF", "defense": "auth", "description": "Identity Spoofing!", "color": Color.YELLOW}
]

# Node references - Tutorial Mode
@onready var phase_title = $MarginContainer/VBoxContainer/PhaseInfo/VBoxContainer/PhaseTitle
@onready var phase_objective = $MarginContainer/VBoxContainer/PhaseInfo/VBoxContainer/PhaseObjective
@onready var phase_explanation = $MarginContainer/VBoxContainer/PhaseInfo/VBoxContainer/ExplanationPanel/ExplanationText
@onready var network_container = $MarginContainer/VBoxContainer/GameGrid/NetworkArea/VBoxContainer/ScrollContainer/VBoxContainer
@onready var attacker_container = $MarginContainer/VBoxContainer/AttackerArea/VBoxContainer/ScrollContainer/VBoxContainer
@onready var feedback_panel = $FeedbackPanel
@onready var feedback_label = $FeedbackPanel/FeedbackLabel
@onready var btn_send_plaintext = $MarginContainer/VBoxContainer/GameGrid/ClientArea/VBoxContainer/ActionButtons/BtnSendPlaintext
@onready var btn_send_encrypted = $MarginContainer/VBoxContainer/GameGrid/ClientArea/VBoxContainer/ActionButtons/BtnSendEncrypted
@onready var btn_next_phase = $BottomControls/BtnNextPhase
@onready var btn_play_again = $BottomControls/BtnPlayAgain
@onready var btn_challenge_mode = $BottomControls/BtnChallengeMode
@onready var completion_panel = $CompletionPanel
@onready var server_status = $MarginContainer/VBoxContainer/GameGrid/ServerArea/VBoxContainer/ServerStatus

# Challenge mode UI
@onready var challenge_hud = $ChallengeHUD
@onready var wave_label = $ChallengeHUD/VBoxContainer/HBoxContainer/WaveLabel
@onready var timer_label = $ChallengeHUD/VBoxContainer/HBoxContainer/TimerLabel
@onready var score_label = $ChallengeHUD/VBoxContainer/HBoxContainer/ScoreLabel
@onready var lives_label = $ChallengeHUD/VBoxContainer/HBoxContainer/LivesLabel
@onready var command_input = $ChallengeHUD/CommandInput
@onready var attack_container = $AttackContainer

func _ready():
	if game_mode == GameMode.TUTORIAL:
		setup_tutorial_mode()
	challenge_hud.visible = false
	attack_container.visible = false

func setup_tutorial_mode():
	update_phase_display()
	update_ui_state()
	feedback_panel.visible = false
	completion_panel.visible = false

func _process(delta):
	if game_mode == GameMode.CHALLENGE and game_state == "playing":
		process_challenge_mode(delta)

func process_challenge_mode(delta):
	# Update wave timer
	wave_timer += delta
	var remaining = wave_duration - wave_timer
	timer_label.text = "⏱️ Time: " + str(int(remaining)) + "s"
	
	if remaining <= 0:
		complete_wave()
		return
	
	# Spawn attacks
	attack_spawn_timer += delta
	if attack_spawn_timer >= attack_spawn_interval:
		attack_spawn_timer = 0.0
		spawn_attack()
	
	# Update existing attacks
	for attack in incoming_attacks:
		attack.progress += delta * 0.1
		if attack.progress >= 1.0:
			# Attack reached target - lose life
			lives -= 1
			lives_label.text = "❤️ Lives: " + str(lives)
			incoming_attacks.erase(attack)
			attack.node.queue_free()
			
			if lives <= 0:
				game_over()
			return

func spawn_attack():
	var attack_type = attack_types[randi() % attack_types.size()]
	var attack = {
		"type": attack_type,
		"progress": 0.0,
		"node": create_attack_node(attack_type)
	}
	incoming_attacks.append(attack)
	attack_container.add_child(attack.node)

func create_attack_node(attack_type: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	var label = Label.new()
	label.text = attack_type["description"]
	label.add_theme_color_override("font_color", attack_type["color"])
	
	var defense_label = Label.new()
	defense_label.text = "Type: " + attack_type["defense"]
	defense_label.add_theme_font_size_override("font_size", 12)
	
	vbox.add_child(label)
	vbox.add_child(defense_label)
	panel.add_child(vbox)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	style.border_color = attack_type["color"]
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func start_challenge_mode():
	game_mode = GameMode.CHALLENGE
	game_state = "playing"
	current_wave = 1
	score = 0
	lives = 3
	wave_timer = 0.0
	incoming_attacks.clear()
	
	# Hide tutorial UI
	$MarginContainer.visible = false
	feedback_panel.visible = false
	completion_panel.visible = false
	btn_next_phase.visible = false
	btn_play_again.visible = false
	btn_challenge_mode.visible = false
	
	# Show challenge UI
	challenge_hud.visible = true
	attack_container.visible = true
	command_input.visible = true
	command_input.grab_focus()
	
	update_challenge_hud()

func update_challenge_hud():
	wave_label.text = "🌊 Wave: " + str(current_wave) + "/" + str(max_waves)
	score_label.text = "⭐ Score: " + str(score)
	lives_label.text = "❤️ Lives: " + str(lives)
	timer_label.text = "⏱️ Time: " + str(int(wave_duration)) + "s"

func complete_wave():
	current_wave += 1
	wave_timer = 0.0
	incoming_attacks.clear()
	for child in attack_container.get_children():
		child.queue_free()
	
	if current_wave > max_waves:
		challenge_complete()
	else:
		# Increase difficulty
		attack_spawn_interval = max(1.0, attack_spawn_interval - 0.3)
		score += 100
		update_challenge_hud()
		show_wave_banner()

func show_wave_banner():
	var banner = Label.new()
	banner.text = "WAVE " + str(current_wave) + " START!"
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", Color.YELLOW)
	banner.position = Vector2(get_viewport_rect().size.x / 2 - 150, get_viewport_rect().size.y / 2)
	add_child(banner)
	
	await get_tree().create_timer(2.0).timeout
	banner.queue_free()

func challenge_complete():
	game_state = "complete"
	challenge_hud.visible = false
	attack_container.visible = false
	command_input.visible = false
	
	var final_score = score + (lives * 50)
	
	show_completion_screen("🏆 CHALLENGE COMPLETE! 🏆", 
		"Final Score: " + str(final_score) + "\nWaves Completed: " + str(max_waves) + 
		"\nLives Remaining: " + str(lives))

func game_over():
	game_state = "failed"
	challenge_hud.visible = false
	attack_container.visible = false
	command_input.visible = false
	
	show_completion_screen("💀 GAME OVER 💀", 
		"Score: " + str(score) + "\nWaves Completed: " + str(current_wave - 1) + "/" + str(max_waves))

func show_completion_screen(title_text: String, description_text: String):
	completion_panel.visible = true
	completion_panel.get_node("VBoxContainer/Title").text = title_text
	completion_panel.get_node("VBoxContainer/Description").text = description_text
	btn_play_again.visible = true

func _on_command_input_text_submitted(new_text: String):
	var command = new_text.strip_edges().to_lower()
	command_input.text = ""
	
	# Check if command matches any incoming attack
	for attack in incoming_attacks:
		if attack.type["defense"] == command:
			# Successful defense!
			score += 10
			update_challenge_hud()
			incoming_attacks.erase(attack)
			
			# Visual feedback
			var tween = create_tween()
			tween.tween_property(attack.node, "modulate", Color.GREEN, 0.2)
			tween.tween_callback(attack.node.queue_free)
			
			return
	
	# Wrong command - visual feedback
	var tween = create_tween()
	tween.tween_property(command_input, "modulate", Color.RED, 0.1)
	tween.tween_property(command_input, "modulate", Color.WHITE, 0.1)

func update_phase_display():
	var phase = phases[current_phase]
	phase_title.text = phase["title"]
	phase_objective.text = "🎯 " + phase["objective"]
	phase_explanation.text = "💡 " + phase["explanation"]

func update_ui_state():
	btn_send_plaintext.visible = false
	btn_send_encrypted.visible = false
	btn_next_phase.visible = false
	btn_play_again.visible = false
	btn_challenge_mode.visible = false
	
	match current_phase:
		0:
			if game_state != "failed":
				btn_send_plaintext.visible = true
		2:
			if game_state == "playing":
				btn_send_encrypted.visible = true
	
	if game_state in ["failed", "success"] and current_phase < phases.size() - 1:
		btn_next_phase.visible = true
	
	if game_state == "complete" and game_mode == GameMode.TUTORIAL:
		btn_play_again.visible = true
		btn_challenge_mode.visible = true
		completion_panel.visible = true

func add_network_data(data_type: String, content: String, encrypted: bool):
	var data_panel = create_data_panel(content, encrypted)
	network_container.add_child(data_panel)
	
	var tween = create_tween()
	data_panel.modulate.a = 0
	tween.tween_property(data_panel, "modulate:a", 1.0, 0.5)

func add_attacker_knowledge(knowledge: String):
	var label = Label.new()
	label.text = knowledge
	label.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	
	var panel = PanelContainer.new()
	panel.add_child(label)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.1, 0.1, 0.5)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	attacker_container.add_child(panel)
	
	var tween = create_tween()
	panel.modulate.a = 0
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)

func create_data_panel(content: String, encrypted: bool) -> PanelContainer:
	var label = Label.new()
	label.text = content
	
	var panel = PanelContainer.new()
	panel.add_child(label)
	
	var style = StyleBoxFlat.new()
	if encrypted:
		style.bg_color = Color(0.1, 0.3, 0.1, 0.5)
		style.border_color = Color(0.2, 0.8, 0.2)
	else:
		style.bg_color = Color(0.3, 0.1, 0.1, 0.5)
		style.border_color = Color(0.8, 0.2, 0.2)
	
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func show_feedback(message: String, is_success: bool):
	feedback_label.text = message
	feedback_panel.visible = true
	
	var style = StyleBoxFlat.new()
	if is_success:
		style.bg_color = Color(0.1, 0.3, 0.1, 0.8)
		style.border_color = Color(0.2, 0.8, 0.2)
	else:
		style.bg_color = Color(0.3, 0.1, 0.1, 0.8)
		style.border_color = Color(0.8, 0.2, 0.2)
	
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	feedback_panel.add_theme_stylebox_override("panel", style)

func clear_network():
	for child in network_container.get_children():
		child.queue_free()

func clear_attacker():
	for child in attacker_container.get_children():
		child.queue_free()

# Button handlers
func _on_btn_send_plaintext_pressed():
	add_network_data("plaintext", "🔓 SessionKey_ABC123", false)
	add_attacker_knowledge("🔓 Session Key: ABC123 (STOLEN!)")
	
	await get_tree().create_timer(1.5).timeout
	game_state = "failed"
	show_feedback(phases[0]["success"], false)
	update_ui_state()

func _on_btn_send_encrypted_pressed():
	add_network_data("encrypted", "🔒 [Encrypted: SessionKey]", true)
	add_attacker_knowledge("❌ Encrypted blob (cannot decrypt)")
	
	await get_tree().create_timer(1.5).timeout
	game_state = "success"
	server_status.text = "✅ Session Key Received!"
	server_status.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	show_feedback(phases[2]["success"], true)
	update_ui_state()

func _on_btn_next_phase_pressed():
	if current_phase < phases.size() - 1:
		current_phase += 1
		game_state = "playing"
		clear_network()
		feedback_panel.visible = false
		server_status.text = ""
		
		update_phase_display()
		update_ui_state()
		
		if current_phase == 1:
			await get_tree().create_timer(0.5).timeout
			server_sends_public_key()
		elif current_phase == 3:
			game_state = "success"
			show_feedback(phases[3]["success"], true)
			await get_tree().create_timer(2.0).timeout
			game_state = "complete"
			update_ui_state()

func server_sends_public_key():
	add_network_data("public_key", "📢 Server Public Key", false)
	add_attacker_knowledge("📢 Server Public Key (useless alone)")
	
	await get_tree().create_timer(1.5).timeout
	game_state = "success"
	show_feedback(phases[1]["success"], true)
	update_ui_state()

func _on_btn_play_again_pressed():
	get_tree().reload_current_scene()

func _on_btn_challenge_mode_pressed():
	start_challenge_mode()
