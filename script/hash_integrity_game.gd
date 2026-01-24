extends Control

# Game State
var level = 1
var score = 0
var lives = 3
var time_left = 30
var selected_algo = "SHA-256"
var current_file = {}
var original_hash = ""
var received_hash = ""
var is_tampered = false
var is_transferring = false
var challenge_mode = ""

# File database
var files = [
	{"name": "config.txt", "content": "server_ip=192.168.1.1", "icon": "📄"},
	{"name": "user_data.json", "content": '{"users":["alice","bob"]}', "icon": "📋"},
	{"name": "payment.dat", "content": "amount=500&recipient=alice", "icon": "💳"},
	{"name": "update.exe", "content": "binary_executable_data", "icon": "⚙️"},
	{"name": "certificate.pem", "content": "-----BEGIN CERTIFICATE-----", "icon": "🔐"},
	{"name": "backup.tar", "content": "compressed_backup_data", "icon": "📦"},
	{"name": "credentials.xml", "content": "<user>admin</user><pass>secret</pass>", "icon": "🔑"},
	{"name": "database.sql", "content": "SELECT * FROM users WHERE admin=1", "icon": "🗄️"}
]

# Algorithm properties
var algorithms = {
	"MD5": {"strength": "broken", "color": Color(1, 0.3, 0.3), "collision_chance": 0.8},
	"SHA-1": {"strength": "weak", "color": Color(1, 0.7, 0.3), "collision_chance": 0.3},
	"SHA-256": {"strength": "strong", "color": Color(0.3, 1, 0.3), "collision_chance": 0.0}
}

# Challenges
var challenges = [
	{"name": "Speed Run", "desc": "Detect 5 tampered files in 20 seconds", "time": 20, "target": 5},
	{"name": "Perfect Score", "desc": "No mistakes allowed for 10 files", "mistakes": 0, "target": 10},
	{"name": "Algorithm Master", "desc": "Use only SHA-256 for 8 files", "algo": "SHA-256", "target": 8},
	{"name": "Under Pressure", "desc": "15 second time limit per file", "time_per_file": 15, "target": 5}
]

var current_challenge = null
var challenge_progress = 0

# Node references
@onready var intro_screen = $IntroScreen
@onready var game_screen = $GameScreen
@onready var game_over_screen = $GameOverScreen
@onready var victory_screen = $VictoryScreen
@onready var verification_panel = $GameScreen/VerificationPanel
@onready var game_timer = $GameTimer
@onready var transfer_timer = $TransferTimer

# UI References
@onready var level_label = $GameScreen/TopBar/HBoxContainer/LevelLabel
@onready var score_label = $GameScreen/TopBar/HBoxContainer/ScoreLabel
@onready var lives_label = $GameScreen/TopBar/HBoxContainer/LivesLabel
@onready var timer_label = $GameScreen/TopBar/HBoxContainer/TimerLabel
@onready var file_icon = $GameScreen/GameZones/FileStorage/VBoxContainer/FileIcon
@onready var file_name = $GameScreen/GameZones/FileStorage/VBoxContainer/FileName
@onready var file_content = $GameScreen/GameZones/FileStorage/VBoxContainer/FileContent
@onready var original_hash_label = $GameScreen/GameZones/FileStorage/VBoxContainer/OriginalHash
@onready var current_algo_label = $GameScreen/GameZones/HashGenerator/VBoxContainer/CurrentAlgo
@onready var hash_status_label = $GameScreen/GameZones/HashGenerator/VBoxContainer/StatusLabel
@onready var network_status = $GameScreen/GameZones/Network/VBoxContainer/StatusLabel
@onready var attacker_status = $GameScreen/GameZones/Attacker/VBoxContainer/StatusLabel
@onready var original_hash_verify = $GameScreen/VerificationPanel/VBoxContainer/HBoxContainer/OriginalHashPanel/Hash
@onready var received_hash_verify = $GameScreen/VerificationPanel/VBoxContainer/HBoxContainer/ReceivedHashPanel/Hash
@onready var match_status = $GameScreen/VerificationPanel/VBoxContainer/MatchStatus
@onready var feedback_label = $GameScreen/VerificationPanel/VBoxContainer/FeedbackLabel
@onready var final_score_label = $GameOverScreen/VBoxContainer/FinalScore
@onready var victory_score_label = $VictoryScreen/VBoxContainer/FinalScore

func _ready():
	intro_screen.visible = true
	game_screen.visible = false
	game_over_screen.visible = false
	victory_screen.visible = false

func _on_start_button_pressed():
	start_game()

func start_game():
	intro_screen.visible = false
	game_screen.visible = true
	level = 1
	score = 0
	lives = 3
	time_left = 30
	selected_algo = "SHA-256"
	update_ui()
	start_new_round()
	game_timer.start(1.0)

func start_new_round():
	# Random challenge every 3 levels
	if level % 3 == 0 and current_challenge == null:
		current_challenge = challenges[randi() % challenges.size()]
		challenge_progress = 0
		show_challenge_notification()
	
	# Select random file
	current_file = files[randi() % files.size()]
	
	# Determine if attacker will tamper (increases with level)
	var tamper_chance = min(0.4 + (level * 0.1), 0.8)
	is_tampered = randf() < tamper_chance
	
	# Update file display
	file_icon.text = current_file.icon
	file_name.text = current_file.name
	file_content.text = current_file.content.substr(0, 30) + "..."
	
	# Generate original hash
	original_hash = generate_hash(current_file.content, selected_algo)
	original_hash_label.text = original_hash
	
	# Start transfer phase
	is_transferring = true
	network_status.text = "Transferring " + current_file.name + "..."
	attacker_status.text = "Intercepting..." if is_tampered else "Monitoring..."
	hash_status_label.text = "Waiting for transfer..."
	verification_panel.visible = false
	
	transfer_timer.start()

func _on_transfer_complete():
	is_transferring = false
	network_status.text = "Transfer complete"
	hash_status_label.text = "Generating hash..."
	
	# Generate received hash
	if is_tampered:
		# Check for hash collision (algorithm weakness)
		if randf() < algorithms[selected_algo].collision_chance:
			# Collision! Same hash despite different content
			received_hash = original_hash
			attacker_status.text = "💀 COLLISION EXPLOIT!"
		else:
			# Normal tamper detection - different hash
			var tampered_content = current_file.content + "_MODIFIED_" + str(randi())
			received_hash = generate_hash(tampered_content, selected_algo)
			attacker_status.text = "Modified file"
	else:
		received_hash = original_hash
		attacker_status.text = "No tampering"
	
	# Show verification panel
	await get_tree().create_timer(1.0).timeout
	show_verification_panel()

func show_verification_panel():
	verification_panel.visible = true
	original_hash_verify.text = original_hash
	received_hash_verify.text = received_hash
	
	var hashes_match = original_hash == received_hash
	
	if hashes_match:
		match_status.text = "✓ MATCH"
		match_status.modulate = Color(0.5, 1, 0.5)
		received_hash_verify.modulate = Color(0.5, 1, 0.5)
	else:
		match_status.text = "✗ MISMATCH"
		match_status.modulate = Color(1, 0.3, 0.3)
		received_hash_verify.modulate = Color(1, 0.3, 0.3)
	
	feedback_label.text = ""

func _on_decision_made(accept: bool):
	var hashes_match = original_hash == received_hash
	var correct_decision = false
	
	# Correct decision logic
	if accept and hashes_match and not is_tampered:
		correct_decision = true
	elif not accept and (not hashes_match or is_tampered):
		correct_decision = true
	
	if correct_decision:
		score += 100
		challenge_progress += 1
		feedback_label.text = "✓ Correct! " + ("File is trusted." if hashes_match else "Tampering detected!")
		feedback_label.modulate = Color(0.5, 1, 0.5)
		
		# Check challenge completion
		if current_challenge and check_challenge_complete():
			score += 500
			show_challenge_complete()
			current_challenge = null
		
		# Level up
		if score >= level * 500:
			level += 1
			if level > 10:
				game_won()
				return
			show_level_up_message()
		
		await get_tree().create_timer(2.0).timeout
		start_new_round()
	else:
		lives -= 1
		feedback_label.text = "✗ Wrong! " + get_failure_reason()
		feedback_label.modulate = Color(1, 0.3, 0.3)
		
		if lives <= 0:
			game_over()
		else:
			await get_tree().create_timer(2.5).timeout
			start_new_round()
	
	update_ui()

func get_failure_reason() -> String:
	if is_tampered and original_hash == received_hash:
		return "Hash collision! Use stronger algorithm!"
	elif original_hash != received_hash:
		return "Hash mismatch means tampering!"
	else:
		return "Check the integrity carefully!"

func _on_algo_button_pressed(algo: String):
	if not is_transferring:
		selected_algo = algo
		current_algo_label.text = algo
		current_algo_label.modulate = algorithms[algo].color

func generate_hash(data: String, algo: String) -> String:
	var hash = ""
	var length = 32 if algo == "MD5" else (40 if algo == "SHA-1" else 64)
	var base_code = 0
	
	for c in data:
		base_code += c.unicode_at(0)
	
	for i in range(length):
		var char_code = (base_code * (i + 1) * 13) % 16
		hash += "%x" % char_code
	
	return hash

func update_ui():
	level_label.text = "Level: " + str(level)
	score_label.text = "Score: " + str(score)
	
	var hearts = ""
	for i in range(3):
		hearts += "❤️" if i < lives else "🖤"
	lives_label.text = "Lives: " + hearts
	
	timer_label.text = "Time: " + str(time_left) + "s"

func _on_game_timer_timeout():
	time_left -= 1
	update_ui()
	
	if time_left <= 0:
		lives -= 1
		if lives <= 0:
			game_over()
		else:
			time_left = 30
			start_new_round()

func show_challenge_notification():
	var notif = Label.new()
	notif.text = "🎯 CHALLENGE: " + current_challenge.name
	notif.add_theme_font_size_override("font_size", 24)
	notif.modulate = Color(1, 1, 0)
	notif.position = Vector2(400, 300)
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 2.0)
	tween.tween_callback(notif.queue_free)

func check_challenge_complete() -> bool:
	if not current_challenge:
		return false
	
	if "target" in current_challenge:
		return challenge_progress >= current_challenge.target
	
	return false

func show_challenge_complete():
	var notif = Label.new()
	notif.text = "🏆 CHALLENGE COMPLETE! +500 BONUS!"
	notif.add_theme_font_size_override("font_size", 28)
	notif.modulate = Color(1, 0.84, 0)
	notif.position = Vector2(350, 300)
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "position:y", 200, 1.0)
	tween.tween_property(notif, "modulate:a", 0.0, 1.0)
	tween.tween_callback(notif.queue_free)

func show_level_up_message():
	var notif = Label.new()
	notif.text = "🎉 LEVEL UP! Now Level " + str(level)
	notif.add_theme_font_size_override("font_size", 26)
	notif.modulate = Color(0, 1, 1)
	notif.position = Vector2(400, 300)
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_property(notif, "modulate:a", 0.0, 1.0)
	tween.tween_callback(notif.queue_free)

func game_over():
	game_timer.stop()
	game_screen.visible = false
	game_over_screen.visible = true
	final_score_label.text = "Final Score: " + str(score)

func game_won():
	game_timer.stop()
	game_screen.visible = false
	victory_screen.visible = true
	victory_score_label.text = "Final Score: " + str(score)

func _on_restart_pressed():
	game_over_screen.visible = false
	victory_screen.visible = false
	current_challenge = null
	start_game()
