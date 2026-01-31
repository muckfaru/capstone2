extends Node
class_name GameManager

# Game state enumeration
enum GameState {
	TUTORIAL,
	LEVEL_1_SYMMETRIC,
	LEVEL_2_ASYMMETRIC,
	LEVEL_3_HYBRID,
	COMPLETED
}

enum EncryptionType {
	NONE,
	SYMMETRIC,
	ASYMMETRIC,
	HYBRID
}

# Current game state
var current_state: GameState = GameState.TUTORIAL
var current_level: int = 1
var attacker_present: bool = false
var attacker_has_symmetric_key: bool = false

# Node references
var crypto_logic: CryptoLogic
var attack_simulator: AttackSimulator
var ui_manager: UIManager

# Level configuration
var level_config = {
	1: {
		"name": "Level 1: Symmetric Encryption Basics",
		"tutorial": "Alice and Bob share a secret key. Choose symmetric encryption to send the message quickly.",
		"attacker_active": false,
		"show_symmetric": true,
		"show_asymmetric": false,
		"show_hybrid": false,
		"message": "\"Transfer $10,000 to Account 12345\""
	},
	2: {
		"name": "Level 2: The Key Distribution Problem",
		"tutorial": "An attacker intercepted the key exchange! Symmetric encryption is now compromised. Try asymmetric encryption.",
		"attacker_active": true,
		"attacker_has_key": true,
		"show_symmetric": true,
		"show_asymmetric": true,
		"show_hybrid": false,
		"message": "\"Top Secret: Launch codes Alpha-7-Bravo\""
	},
	3: {
		"name": "Level 3: Hybrid Encryption - Best of Both Worlds",
		"tutorial": "Use hybrid encryption: Asymmetric to exchange a session key, then symmetric for the data. This is how HTTPS works!",
		"attacker_active": true,
		"attacker_has_key": false,
		"show_symmetric": true,
		"show_asymmetric": true,
		"show_hybrid": true,
		"message": "\"Medical Records: Patient ID 98765 - Confidential\""
	}
}

func _ready():
	# Get references to sibling nodes
	crypto_logic = get_node_or_null("../CryptoLogic")
	attack_simulator = get_node_or_null("../AttackSimulator")
	ui_manager = get_node_or_null("../UIManager")
	
	if not crypto_logic:
		push_error("GameManager: Could not find CryptoLogic node")
	if not attack_simulator:
		push_error("GameManager: Could not find AttackSimulator node")
	if not ui_manager:
		push_error("GameManager: Could not find UIManager node")
		return
	
	# Connect signals
	connect_ui_signals()
	
	# Start the game
	start_level(1)

func connect_ui_signals():
	var root = get_parent()
	if not root:
		push_error("GameManager: No parent node found")
		return
	
	var symmetric_btn = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/SymmetricButton")
	var asymmetric_btn = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/AsymmetricButton")
	var hybrid_btn = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/HybridButton")
	var next_btn = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/NextLevelButton")
	var close_feedback = root.get_node_or_null("FeedbackPanel/VBox/CloseButton")
	
	if symmetric_btn:
		symmetric_btn.pressed.connect(_on_symmetric_pressed)
	else:
		push_error("GameManager: Could not find SymmetricButton")
	
	if asymmetric_btn:
		asymmetric_btn.pressed.connect(_on_asymmetric_pressed)
	else:
		push_error("GameManager: Could not find AsymmetricButton")
	
	if hybrid_btn:
		hybrid_btn.pressed.connect(_on_hybrid_pressed)
	else:
		push_error("GameManager: Could not find HybridButton")
	
	if next_btn:
		next_btn.pressed.connect(_on_next_level_pressed)
	else:
		push_error("GameManager: Could not find NextLevelButton")
	
	if close_feedback:
		close_feedback.pressed.connect(_on_close_feedback)
	else:
		push_error("GameManager: Could not find CloseButton")

func start_level(level: int):
	current_level = level
	
	if level > 3:
		show_game_complete()
		return
	
	var config = level_config[level]
	
	# Update UI
	ui_manager.set_level_title(config["name"])
	ui_manager.set_tutorial_text(config["tutorial"])
	ui_manager.set_message(config["message"])
	ui_manager.reset_transmission()
	
	# Configure visibility
	ui_manager.show_symmetric_key(config["show_symmetric"])
	ui_manager.show_asymmetric_keys(config["show_asymmetric"])
	ui_manager.show_hybrid_button(config["show_hybrid"])
	
	# Configure attacker
	attacker_present = config["attacker_active"]
	attacker_has_symmetric_key = config.get("attacker_has_key", false)
	
	if attacker_present and attacker_has_symmetric_key:
		attack_simulator.set_has_symmetric_key(true)
	
	# Enable/disable buttons
	ui_manager.enable_encryption_buttons(true)
	ui_manager.show_next_level_button(false)
	
	print("Started level ", level, ": ", config["name"])

func _on_symmetric_pressed():
	ui_manager.enable_encryption_buttons(false)
	
	# Simulate encryption and transmission
	var encrypted = crypto_logic.encrypt_symmetric("Transfer $10,000 to Account 12345")
	ui_manager.show_transmission(encrypted, "Symmetric")
	
	await get_tree().create_timer(1.0).timeout
	
	# Check if attacker can decrypt
	if attacker_present and attacker_has_symmetric_key:
		ui_manager.show_attacker_indicator(true)
		await get_tree().create_timer(1.5).timeout
		
		var attack_result = attack_simulator.attempt_decrypt_symmetric(encrypted)
		handle_encryption_result(false, attack_result)
	else:
		# Success - receiver decrypts
		var decrypted = crypto_logic.decrypt_symmetric(encrypted)
		ui_manager.show_received_message(decrypted)
		await get_tree().create_timer(0.5).timeout
		
		handle_encryption_result(true, {
			"success": true,
			"method": "Symmetric",
			"speed": "Fast",
			"security": "High (when key is secure)"
		})

func _on_asymmetric_pressed():
	ui_manager.enable_encryption_buttons(false)
	
	# Simulate asymmetric encryption
	var encrypted = crypto_logic.encrypt_asymmetric("Top Secret: Launch codes")
	ui_manager.show_transmission(encrypted, "Asymmetric")
	
	await get_tree().create_timer(1.5).timeout
	
	# Attacker tries to decrypt (will fail without private key)
	if attacker_present:
		ui_manager.show_attacker_indicator(true)
		await get_tree().create_timer(1.5).timeout
		
		var attack_result = attack_simulator.attempt_decrypt_asymmetric(encrypted)
		
		if not attack_result["success"]:
			# Attacker failed, receiver succeeds
			var decrypted = crypto_logic.decrypt_asymmetric(encrypted)
			ui_manager.show_received_message(decrypted)
			ui_manager.show_attacker_indicator(false)
			await get_tree().create_timer(0.5).timeout
			
			handle_encryption_result(true, {
				"success": true,
				"method": "Asymmetric (RSA)",
				"speed": "Slower than symmetric",
				"security": "High - No key exchange needed!"
			})
	else:
		var decrypted = crypto_logic.decrypt_asymmetric(encrypted)
		ui_manager.show_received_message(decrypted)
		await get_tree().create_timer(0.5).timeout
		
		handle_encryption_result(true, {
			"success": true,
			"method": "Asymmetric",
			"speed": "Moderate",
			"security": "High"
		})

func _on_hybrid_pressed():
	ui_manager.enable_encryption_buttons(false)
	
	# Simulate hybrid encryption
	ui_manager.set_network_status("Step 1: Exchanging session key with RSA...")
	await get_tree().create_timer(1.0).timeout
	
	var session_key_encrypted = crypto_logic.encrypt_asymmetric("SessionKey:AES256-XYZ")
	ui_manager.show_transmission(session_key_encrypted, "RSA")
	
	await get_tree().create_timer(1.5).timeout
	
	ui_manager.set_network_status("Step 2: Encrypting data with session key (AES)...")
	await get_tree().create_timer(1.0).timeout
	
	var data_encrypted = crypto_logic.encrypt_symmetric("Medical Records: Patient ID 98765")
	ui_manager.show_transmission(data_encrypted, "AES")
	
	await get_tree().create_timer(1.5).timeout
	
	# Attacker tries to intercept
	if attacker_present:
		ui_manager.show_attacker_indicator(true)
		await get_tree().create_timer(1.5).timeout
		
		var attack_result = attack_simulator.attempt_decrypt_hybrid(session_key_encrypted, data_encrypted)
		
		if not attack_result["success"]:
			# Success!
			var decrypted = crypto_logic.decrypt_hybrid(session_key_encrypted, data_encrypted)
			ui_manager.show_received_message(decrypted)
			ui_manager.show_attacker_indicator(false)
			await get_tree().create_timer(0.5).timeout
			
			handle_encryption_result(true, {
				"success": true,
				"method": "Hybrid (RSA + AES)",
				"speed": "Fast data transfer + Secure key exchange",
				"security": "✓ Best of both worlds! This is how HTTPS/TLS works!"
			})

func handle_encryption_result(success: bool, details: Dictionary):
	if success:
		ui_manager.show_feedback(
			true,
			"✓ SUCCESS - Message Delivered Securely!",
			"Encryption Method: " + details["method"],
			"Speed: " + details["speed"] + "\nSecurity: " + details["security"]
		)
		
		# Show next level button if not on last level
		if current_level < 3:
			ui_manager.show_next_level_button(true)
	else:
		ui_manager.show_feedback(
			false,
			"✗ ATTACK SUCCESSFUL - Message Compromised!",
			details.get("attack_method", "Unknown attack"),
			details.get("explanation", "The attacker was able to decrypt your message.")
		)
		
		# Re-enable buttons to try again
		ui_manager.enable_encryption_buttons(true)

func _on_next_level_pressed():
	start_level(current_level + 1)

func _on_close_feedback():
	ui_manager.hide_feedback()

func show_game_complete():
	ui_manager.show_feedback(
		true,
		"🎓 CONGRATULATIONS!",
		"You've mastered cryptographic concepts!",
		"You now understand:\n• Symmetric encryption (fast, shared key)\n• Asymmetric encryption (secure, no key exchange)\n• Hybrid encryption (real-world solution)\n\nThis is how secure communications work on the internet!"
	)
