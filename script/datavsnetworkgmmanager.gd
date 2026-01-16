extends Node2D

# Preload scenes
const ATTACK_CARD = preload("res://scene/AttackCard.tscn")
const FEEDBACK_POPUP = preload("res://scene/FeedbackPopup.tscn")
const VICTORY_SCREEN = preload("res://scene/VictoryScreen.tscn")

# Game state
var current_wave = 1
var total_waves = 5
var attacks_spawned = 0
var attacks_per_wave = [3, 4, 5, 5, 6]
var time_per_attack = [5.0, 4.0, 3.5, 3.0, 2.5]
var score = 0
var combo = 0
var total_attacks = 0
var correct_attacks = 0
var data_correct = 0
var data_total = 0
var network_correct = 0
var network_total = 0

# Attack database
var attack_database = []
var available_attacks = []

# References
@onready var attack_container = $CanvasLayer/AttackContainer
@onready var spawn_timer = $SpawnTimer
@onready var system_health = $CanvasLayer/SystemHealth
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var wave_label = $CanvasLayer/WaveLabel
@onready var data_zone = $CanvasLayer/DropZones/DataZone
@onready var network_zone = $CanvasLayer/DropZones/NetworkZone
@onready var audio_success = $AudioSuccess
@onready var audio_fail = $AudioFail
@onready var audio_spawn = $AudioSpawn

func _ready():
	load_attack_data()
	setup_zones()
	update_wave_label()
	spawn_timer.wait_time = time_per_attack[0]
	spawn_attack()

func load_attack_data():
	# Load from JSON file
	var file_path = "res://data/attacks.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			attack_database = json.data
	else:
		# Fallback: Hardcoded attacks
		attack_database = get_default_attacks()
	
	# Filter attacks for wave 1
	update_available_attacks()

func get_default_attacks():
	return [
		{
			"id": 1,
			"name": "Ransomware Encryption",
			"category": "data",
			"description": "Malware encrypting employee database files!",
			"icon": "📁🔒",
			"explanation": "Ransomware targets DATA by encrypting files. Use backups and encryption defenses.",
			"cia_impact": {"C": 15, "I": 10},
			"wave_unlock": 1
		},
		{
			"id": 2,
			"name": "DDoS Attack",
			"category": "network",
			"description": "1000+ bots flooding web server with traffic!",
			"icon": "🌐💥",
			"explanation": "DDoS targets NETWORK availability by overwhelming infrastructure. Use firewalls and rate limiting.",
			"cia_impact": {"A": 20},
			"wave_unlock": 1
		},
		{
			"id": 3,
			"name": "SQL Injection",
			"category": "data",
			"description": "Hacker inserting code to extract customer records!",
			"icon": "💉📊",
			"explanation": "SQL Injection steals DATA from databases. Use input validation and parameterized queries.",
			"cia_impact": {"C": 20},
			"wave_unlock": 1
		},
		{
			"id": 4,
			"name": "Man-in-the-Middle",
			"category": "network",
			"description": "Attacker intercepting unencrypted Wi-Fi traffic!",
			"icon": "👤📡",
			"explanation": "MitM attacks exploit NETWORK vulnerabilities. Use encryption (TLS/VPN).",
			"cia_impact": {"C": 15},
			"wave_unlock": 2
		},
		{
			"id": 5,
			"name": "Insider Data Leak",
			"category": "data",
			"description": "Employee copying files to personal USB drive!",
			"icon": "💾🚨",
			"explanation": "Insider threats target DATA access. Use DLP and access controls.",
			"cia_impact": {"C": 18, "I": 5},
			"wave_unlock": 2
		},
		{
			"id": 6,
			"name": "Port Scanning",
			"category": "network",
			"description": "Unknown IP probing network for open ports!",
			"icon": "🔍🔌",
			"explanation": "Port scanning is NETWORK reconnaissance. Use firewalls and IDS.",
			"cia_impact": {},
			"wave_unlock": 2
		},
		{
			"id": 7,
			"name": "Backup Corruption",
			"category": "data",
			"description": "Malware deleting disaster recovery backups!",
			"icon": "💿❌",
			"explanation": "Backup attacks target DATA redundancy. Use immutable backups.",
			"cia_impact": {"A": 25},
			"wave_unlock": 3
		},
		{
			"id": 8,
			"name": "DNS Spoofing",
			"category": "network",
			"description": "Fake DNS redirecting traffic to malicious sites!",
			"icon": "🌐🎭",
			"explanation": "DNS spoofing corrupts NETWORK routing. Use DNSSEC.",
			"cia_impact": {"I": 15},
			"wave_unlock": 3
		},
		{
			"id": 9,
			"name": "Phishing Keylogger",
			"category": "data",
			"description": "Trojan capturing user login credentials!",
			"icon": "🎣🔑",
			"explanation": "Keyloggers steal DATA (credentials). Use 2FA and endpoint protection.",
			"cia_impact": {"C": 20},
			"wave_unlock": 4
		},
		{
			"id": 10,
			"name": "Firewall Bypass",
			"category": "network",
			"description": "Attacker tunneling through VPN to internal network!",
			"icon": "🚧🕳️",
			"explanation": "VPN attacks exploit NETWORK access controls. Use zero-trust architecture.",
			"cia_impact": {"C": 10, "I": 10},
			"wave_unlock": 4
		}
	]

func update_available_attacks():
	available_attacks.clear()
	for attack in attack_database:
		if attack.wave_unlock <= current_wave:
			available_attacks.append(attack)

func setup_zones():
	data_zone.zone_dropped.connect(_on_zone_dropped)
	network_zone.zone_dropped.connect(_on_zone_dropped)

func spawn_attack():
	if attacks_spawned >= attacks_per_wave[current_wave - 1]:
		return
	
	if available_attacks.is_empty():
		return
	
	var attack_data = available_attacks[randi() % available_attacks.size()]
	var card = ATTACK_CARD.instantiate()
	
	# Set attack data
	card.attack_data = attack_data
	card.alert_number = total_attacks + 1
	card.time_limit = time_per_attack[current_wave - 1]
	
	# Position at top center (centered horizontally)
	card.position = Vector2(960 - 175, 200)  # Center of screen minus half card width
	
	# Connect signals
	card.card_expired.connect(_on_card_expired)
	
	attack_container.add_child(card)
	
	# Animate down to middle area
	var tween = create_tween()
	tween.tween_property(card, "position:y", 400, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	attacks_spawned += 1
	total_attacks += 1
	
	# Track category stats
	if attack_data.category == "data":
		data_total += 1
	else:
		network_total += 1
	
	if audio_spawn:
		audio_spawn.play()

func _on_spawn_timer_timeout():
	spawn_attack()

func _on_zone_dropped(card, zone_type):
	var attack_data = card.attack_data
	var is_correct = (attack_data.category == zone_type)
	
	# Remove card
	card.queue_free()
	
	if is_correct:
		handle_correct_answer(attack_data, card)
	else:
		handle_wrong_answer(attack_data, zone_type, card)
	
	# Check wave completion
	if attacks_spawned >= attacks_per_wave[current_wave - 1]:
		if attack_container.get_child_count() <= 1:  # Only the card being removed
			complete_wave()

func handle_correct_answer(attack_data, card):
	# Update stats
	correct_attacks += 1
	if attack_data.category == "data":
		data_correct += 1
	else:
		network_correct += 1
	
	# Calculate score
	var time_bonus = 0
	if card.time_remaining > card.time_limit * 0.75:
		time_bonus = 5
	
	combo += 1
	var combo_bonus = 0
	if combo >= 3:
		combo_bonus = int(combo * 2.5)
	
	score += 10 + time_bonus + combo_bonus
	update_score_label()
	
	# Show feedback
	show_feedback(true, attack_data.name + " neutralized!", attack_data.explanation)
	
	if audio_success:
		audio_success.play()
	
	# Visual effect on zone
	if attack_data.category == "data":
		data_zone.show_success_effect()
	else:
		network_zone.show_success_effect()

func handle_wrong_answer(attack_data, wrong_zone, card):
	# Reset combo
	combo = 0
	score = max(0, score - 15)
	update_score_label()
	
	# Damage CIA
	var cia_impact = attack_data.get("cia_impact", {})
	for cia_type in cia_impact.keys():
		system_health.reduce_cia(cia_type, cia_impact[cia_type])
	
	# Show feedback
	var wrong_category = "Network" if wrong_zone == "network" else "Data"
	var correct_category = "DATA" if attack_data.category == "data" else "NETWORK"
	var message = "Wrong! %s targets %s Security, not %s." % [attack_data.name, correct_category, wrong_category]
	show_feedback(false, "❌ MISROUTED ATTACK!", message + "\n\n" + attack_data.explanation)
	
	if audio_fail:
		audio_fail.play()
	
	# Visual effect
	if wrong_zone == "data":
		data_zone.show_fail_effect()
	else:
		network_zone.show_fail_effect()
	
	# Check game over
	if system_health.is_system_critical():
		game_over()

func _on_card_expired(card):
	# Treat as wrong answer with maximum damage
	var attack_data = card.attack_data
	combo = 0
	score = max(0, score - 20)
	update_score_label()
	
	# Double damage for timeout
	var cia_impact = attack_data.get("cia_impact", {})
	for cia_type in cia_impact.keys():
		system_health.reduce_cia(cia_type, cia_impact[cia_type] * 1.5)
	
	show_feedback(false, "⏱️ TIMEOUT!", "Failed to respond! " + attack_data.name + " succeeded.\n\n" + attack_data.explanation)
	
	if audio_fail:
		audio_fail.play()
	
	card.queue_free()
	
	if system_health.is_system_critical():
		game_over()
	elif attacks_spawned >= attacks_per_wave[current_wave - 1]:
		if attack_container.get_child_count() <= 1:
			complete_wave()

func complete_wave():
	spawn_timer.stop()
	
	if current_wave >= total_waves:
		show_victory()
	else:
		current_wave += 1
		attacks_spawned = 0
		update_available_attacks()
		update_wave_label()
		
		# Update spawn timer speed
		spawn_timer.wait_time = time_per_attack[current_wave - 1]
		
		# Show wave transition
		await get_tree().create_timer(1.5).timeout
		show_feedback(true, "WAVE %d COMPLETE!" % (current_wave - 1), "Prepare for wave %d..." % current_wave)
		await get_tree().create_timer(2.0).timeout
		
		spawn_timer.start()
		spawn_attack()

func show_feedback(is_success, title, message):
	var popup = FEEDBACK_POPUP.instantiate()
	popup.setup(is_success, title, message)
	$CanvasLayer.add_child(popup)

func show_victory():
	var victory = VICTORY_SCREEN.instantiate()
	var accuracy = int((float(correct_attacks) / float(total_attacks)) * 100) if total_attacks > 0 else 0
	victory.setup(score, accuracy, data_correct, data_total, network_correct, network_total)
	add_child(victory)

func game_over():
	spawn_timer.stop()
	show_feedback(false, "💀 SYSTEM COMPROMISED!", "CIA Triad integrity lost. Mission failed.\n\nBetter luck next time!")
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func update_score_label():
	score_label.text = "SCORE: %d" % score
	if combo >= 3:
		score_label.text += " 🔥x%d" % combo

func update_wave_label():
	wave_label.text = "WAVE %d/%d" % [current_wave, total_waves]
