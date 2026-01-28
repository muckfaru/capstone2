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
@onready var quit_btn: Button = $TextureRect/Quit

func _ready():
	load_attack_data()
	setup_zones()
	update_wave_label()
	spawn_timer.wait_time = time_per_attack[0]
	spawn_attack()
	quit_btn.pressed.connect(_on_quit_pressed)

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

func _on_quit_pressed() -> void:
	"""Return to mode selection from anywhere in the game"""
	print("[Network Defense] Quit button pressed, returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	
func get_default_attacks():
	return [
		# WAVE 1 - Basic DATA attacks (Easy to understand)
		{
			"id": 1,
			"name": "Ransomware Encryption",
			"category": "data",
			"description": "Malware encrypting employee database files!",
			"icon": "📁🔒",
			"explanation": "Ransomware locks your DATA files. Think of it like someone putting a padlock on your filing cabinet. Use backups to recover!",
			"cia_impact": {"C": 15, "I": 10},
			"wave_unlock": 1
		},
		{
			"id": 2,
			"name": "USB Virus",
			"category": "data",
			"description": "Infected USB drive copying files from computers!",
			"icon": "💾🦠",
			"explanation": "A virus on a USB stick steals DATA when plugged in. Like a thief copying files from your desk. Use antivirus protection!",
			"cia_impact": {"C": 18},
			"wave_unlock": 1
		},
		{
			"id": 3,
			"name": "Password Theft",
			"category": "data",
			"description": "Keylogger recording usernames and passwords!",
			"icon": "🔑💀",
			"explanation": "Someone is stealing your login DATA. Like writing down passwords from your keyboard. Use strong unique passwords!",
			"cia_impact": {"C": 20},
			"wave_unlock": 1
		},
		
		# WAVE 1 - Basic NETWORK attacks
		{
			"id": 4,
			"name": "DDoS Attack",
			"category": "network",
			"description": "1000+ bots flooding web server with traffic!",
			"icon": "🌐💥",
			"explanation": "Too many fake visitors crashing your NETWORK. Like thousands of people blocking a store entrance. Use traffic filters!",
			"cia_impact": {"A": 20},
			"wave_unlock": 1
		},
		{
			"id": 5,
			"name": "WiFi Jamming",
			"category": "network",
			"description": "Signal blocker disrupting wireless connections!",
			"icon": "📡❌",
			"explanation": "Someone is blocking your WiFi NETWORK signals. Like jamming a radio frequency. Use wired connections as backup!",
			"cia_impact": {"A": 18},
			"wave_unlock": 1
		},
		{
			"id": 6,
			"name": "Spam Email Flood",
			"category": "network",
			"description": "Millions of junk emails overloading mail server!",
			"icon": "📧🌊",
			"explanation": "Too many spam emails clogging your NETWORK email system. Like mailbox stuffing. Use spam filters!",
			"cia_impact": {"A": 15},
			"wave_unlock": 1
		},
		
		# WAVE 2 - Intermediate DATA attacks
		{
			"id": 7,
			"name": "SQL Injection",
			"category": "data",
			"description": "Hacker inserting code to extract customer records!",
			"icon": "💉📊",
			"explanation": "Attacker tricks your database to reveal DATA. Like asking a trick question to get secret info. Validate all inputs!",
			"cia_impact": {"C": 20},
			"wave_unlock": 2
		},
		{
			"id": 8,
			"name": "Insider Data Leak",
			"category": "data",
			"description": "Employee copying files to personal USB drive!",
			"icon": "💾🚨",
			"explanation": "Someone inside is stealing DATA files. Like an employee photocopying documents. Monitor file access!",
			"cia_impact": {"C": 18, "I": 5},
			"wave_unlock": 2
		},
		{
			"id": 9,
			"name": "Cloud Storage Hack",
			"category": "data",
			"description": "Weak password exposed company cloud files!",
			"icon": "☁️🔓",
			"explanation": "Your online DATA storage was accessed. Like someone guessing your locker combination. Use 2-factor authentication!",
			"cia_impact": {"C": 22},
			"wave_unlock": 2
		},
		
		# WAVE 2 - Intermediate NETWORK attacks
		{
			"id": 10,
			"name": "Man-in-the-Middle",
			"category": "network",
			"description": "Attacker intercepting unencrypted WiFi traffic!",
			"icon": "👤📡",
			"explanation": "Someone is eavesdropping on your NETWORK connection. Like tapping a phone line. Use encrypted connections (HTTPS)!",
			"cia_impact": {"C": 15},
			"wave_unlock": 2
		},
		{
			"id": 11,
			"name": "Port Scanning",
			"category": "network",
			"description": "Unknown IP probing network for open ports!",
			"icon": "🔍🔌",
			"explanation": "Someone is checking your NETWORK for weak points. Like a burglar testing doors and windows. Use firewalls!",
			"cia_impact": {},
			"wave_unlock": 2
		},
		{
			"id": 12,
			"name": "Rogue WiFi Hotspot",
			"category": "network",
			"description": "Fake 'Free WiFi' stealing login credentials!",
			"icon": "📶🎭",
			"explanation": "A fake WiFi NETWORK pretending to be real. Like a fake ATM stealing card info. Verify network names!",
			"cia_impact": {"C": 20},
			"wave_unlock": 2
		},
		
		# WAVE 3 - Advanced DATA attacks
		{
			"id": 13,
			"name": "Backup Corruption",
			"category": "data",
			"description": "Malware deleting disaster recovery backups!",
			"icon": "💿❌",
			"explanation": "Your backup DATA copies are being destroyed. Like burning your emergency file copies. Use offline backups!",
			"cia_impact": {"A": 25},
			"wave_unlock": 3
		},
		{
			"id": 14,
			"name": "Database Modification",
			"category": "data",
			"description": "Attacker changing prices in product database!",
			"icon": "📊✏️",
			"explanation": "Someone is altering your stored DATA. Like changing numbers in your ledger. Use database integrity checks!",
			"cia_impact": {"I": 20},
			"wave_unlock": 3
		},
		{
			"id": 15,
			"name": "Photo Metadata Leak",
			"category": "data",
			"description": "Uploaded images revealing GPS locations!",
			"icon": "📸🗺️",
			"explanation": "Hidden DATA in photos shows private locations. Like photos accidentally showing your address. Strip metadata!",
			"cia_impact": {"C": 12},
			"wave_unlock": 3
		},
		
		# WAVE 3 - Advanced NETWORK attacks
		{
			"id": 16,
			"name": "DNS Spoofing",
			"category": "network",
			"description": "Fake DNS redirecting traffic to malicious sites!",
			"icon": "🌐🎭",
			"explanation": "Your NETWORK address book is being faked. Like changing road signs to wrong destinations. Use secure DNS!",
			"cia_impact": {"I": 15},
			"wave_unlock": 3
		},
		{
			"id": 17,
			"name": "IP Spoofing",
			"category": "network",
			"description": "Attacker faking trusted IP address!",
			"icon": "🎭🌐",
			"explanation": "Someone pretends to be a trusted NETWORK device. Like using a fake ID badge. Verify device identities!",
			"cia_impact": {"I": 18},
			"wave_unlock": 3
		},
		{
			"id": 18,
			"name": "Cable Tap",
			"category": "network",
			"description": "Physical device attached to network cable!",
			"icon": "🔌👀",
			"explanation": "A spy device is reading NETWORK cable data. Like wiretapping a phone. Secure physical access to cables!",
			"cia_impact": {"C": 22},
			"wave_unlock": 3
		},
		
		# WAVE 4 & 5 - Expert level attacks
		{
			"id": 19,
			"name": "Document Forgery",
			"category": "data",
			"description": "Fake invoices inserted into accounting system!",
			"icon": "📄🖊️",
			"explanation": "Someone is adding false DATA documents. Like forging checks in your checkbook. Use digital signatures!",
			"cia_impact": {"I": 25},
			"wave_unlock": 4
		},
		{
			"id": 20,
			"name": "VPN Tunnel Breach",
			"category": "network",
			"description": "Attacker exploiting weak VPN encryption!",
			"icon": "🚧🕳️",
			"explanation": "Your secure NETWORK tunnel has a hole. Like a secret passage being discovered. Update VPN security!",
			"cia_impact": {"C": 20, "I": 10},
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
	
	# Position at top center (1080x720 resolution)
	# Card is 350 wide, so center is 1080/2 - 350/2 = 540 - 175 = 365
	card.position = Vector2(365, 100)
	
	# Connect signals
	card.card_expired.connect(_on_card_expired)
	
	attack_container.add_child(card)
	
	# Animate down to middle area (avoid drop zones at y=520)
	var tween = create_tween()
	tween.tween_property(card, "position:y", 280, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
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

func handle_wrong_answer(attack_data, wrong_zone, _card):
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
	show_feedback(false, "MISROUTED ATTACK!", message + "\n\n" + attack_data.explanation)
	
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
	
	show_feedback(false, "⏱ TIMEOUT!", "Failed to respond! " + attack_data.name + " succeeded.\n\n" + attack_data.explanation)
	
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
	$CanvasLayer.add_child(popup)
	popup.setup(is_success, title, message)

func show_victory():
	spawn_timer.stop()
	
	var victory = VICTORY_SCREEN.instantiate()
	$CanvasLayer.add_child(victory)  # Add to CanvasLayer instead of Main
	
	# Wait for the victory screen to be ready
	await victory.ready
	
	var accuracy = int((float(correct_attacks) / float(total_attacks)) * 100) if total_attacks > 0 else 0
	victory.setup(score, accuracy, data_correct, data_total, network_correct, network_total)

func game_over():
	spawn_timer.stop()
	show_feedback(false, "SYSTEM COMPROMISED!", "CIA Triad integrity lost. Mission failed.\n\nBetter luck next time!")
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func update_score_label():
	score_label.text = "SCORE: %d" % score
	if combo >= 3:
		score_label.text += " 🔥x%d" % combo

func update_wave_label():
	wave_label.text = "WAVE %d/%d" % [current_wave, total_waves]

func _input(event):
	# Press ESC to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_quit_pressed()
