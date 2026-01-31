extends Node
class_name CryptoLogic

# Simulated encryption algorithms
# In a real implementation, these would use actual crypto libraries

var symmetric_key: String = "SecretKey123"
var alice_private_key: String = "RSA:2E7B..."
var alice_public_key: String = "RSA:4A9C..."
var bob_private_key: String = "RSA:8C2D..."
var bob_public_key: String = "RSA:9F3A..."

func _ready():
	print("CryptoLogic initialized")

# Symmetric Encryption (AES simulation)
func encrypt_symmetric(plaintext: String) -> String:
	# Simulate AES encryption with visual representation
	var encrypted = "AES(" + symmetric_key + ")["
	
	# Create hex-like encrypted representation
	for i in range(min(plaintext.length(), 32)):
		encrypted += "%02X" % (plaintext.unicode_at(i % plaintext.length()) ^ symmetric_key.unicode_at(i % symmetric_key.length()))
	
	encrypted += "...]"
	return encrypted

func decrypt_symmetric(ciphertext: String) -> String:
	# In real scenario, this would actually decrypt
	# For simulation, we just return the original message
	return "✓ Decrypted: Transfer $10,000 to Account 12345"

# Asymmetric Encryption (RSA simulation)
func encrypt_asymmetric(plaintext: String) -> String:
	# Simulate RSA encryption with Bob's public key
	var encrypted = "RSA(PubB)["
	
	# Create a different visual pattern for RSA
	for i in range(min(plaintext.length(), 24)):
		var char_code = plaintext.unicode_at(i % plaintext.length())
		encrypted += "%03X" % ((char_code * 13 + 7) % 256)
	
	encrypted += "...]"
	return encrypted

func decrypt_asymmetric(ciphertext: String) -> String:
	# Decrypted with Bob's private key
	return "✓ Decrypted: Top Secret: Launch codes Alpha-7-Bravo"

# Hybrid Encryption
func encrypt_hybrid_session_key() -> String:
	# First, encrypt a session key with RSA
	return encrypt_asymmetric("SessionKey:AES256-" + str(randi() % 1000))

func encrypt_hybrid_data(session_key: String, plaintext: String) -> String:
	# Then encrypt the actual data with the session key (symmetric)
	var encrypted = "AES(Session)["
	
	for i in range(min(plaintext.length(), 28)):
		encrypted += "%02X" % ((plaintext.unicode_at(i % plaintext.length()) + i) % 256)
	
	encrypted += "...]"
	return encrypted

func decrypt_hybrid(session_key_encrypted: String, data_encrypted: String) -> String:
	# First decrypt session key with private key, then decrypt data with session key
	return "✓ Decrypted: Medical Records: Patient ID 98765 - Confidential"

# Utility functions
func get_encryption_speed(type: String) -> String:
	match type:
		"symmetric":
			return "Very Fast (1-10ms)"
		"asymmetric":
			return "Slower (100-1000ms)"
		"hybrid":
			return "Fast for data, slower for key exchange"
		_:
			return "Unknown"

func get_key_size(type: String) -> String:
	match type:
		"symmetric":
			return "128-256 bits (AES)"
		"asymmetric":
			return "2048-4096 bits (RSA)"
		_:
			return "Unknown"

func get_security_level(type: String, key_compromised: bool) -> String:
	match type:
		"symmetric":
			if key_compromised:
				return "❌ INSECURE - Key compromised"
			else:
				return "✓ Secure (if key is secret)"
		"asymmetric":
			return "✓ Secure (public key cryptography)"
		"hybrid":
			return "✓ Very Secure (combines both)"
		_:
			return "Unknown"

# Generate visual representation of encrypted data
func generate_hex_visualization(text: String, length: int = 32) -> String:
	var hex = ""
	for i in range(length):
		if i % 4 == 0 and i > 0:
			hex += " "
		hex += "%02X" % (randi() % 256)
	return hex

# Simulate encryption time (for visual feedback)
func get_encryption_duration(type: String) -> float:
	match type:
		"symmetric":
			return 0.5  # Fast
		"asymmetric":
			return 1.5  # Slower
		"hybrid":
			return 2.0  # Combined
		_:
			return 1.0

# Key exchange simulation
func simulate_key_exchange_vulnerable() -> Dictionary:
	return {
		"success": false,
		"reason": "Key exchange over untrusted network - intercepted by attacker!",
		"vulnerability": "symmetric_key_distribution"
	}

func simulate_key_exchange_secure() -> Dictionary:
	return {
		"success": true,
		"method": "Diffie-Hellman or RSA key exchange",
		"explanation": "Public key cryptography allows secure key exchange over untrusted networks"
	}

# Educational explanations
func get_explanation(concept: String) -> String:
	match concept:
		"symmetric":
			return """Symmetric Encryption (AES):
• Same key for encryption AND decryption
• Very fast and efficient
• Problem: How do you share the key securely?
• Used for: Bulk data encryption"""
		
		"asymmetric":
			return """Asymmetric Encryption (RSA):
• Public key (anyone can use to encrypt)
• Private key (only you can decrypt)
• Slower than symmetric
• Solves key distribution problem!
• Used for: Key exchange, digital signatures"""
		
		"hybrid":
			return """Hybrid Encryption (TLS/HTTPS):
1. Use RSA to securely exchange a session key
2. Use AES with that session key for data
• Fast data transfer (symmetric)
• Secure key exchange (asymmetric)
• This is how HTTPS works!"""
		
		"key_distribution":
			return """The Key Distribution Problem:
If Alice and Bob share a symmetric key, how did they
exchange it? If they sent it over the network, an
attacker could intercept it!

Solution: Asymmetric cryptography allows secure
key exchange without a pre-shared secret."""
		
		_:
			return "Unknown concept"

# Simulate performance metrics
func get_performance_comparison() -> Dictionary:
	return {
		"symmetric": {
			"speed": "10,000 operations/sec",
			"key_size": "256 bits",
			"use_case": "Bulk data encryption"
		},
		"asymmetric": {
			"speed": "100 operations/sec",
			"key_size": "2048 bits",
			"use_case": "Key exchange, signatures"
		},
		"hybrid": {
			"speed": "Near symmetric speed",
			"security": "Asymmetric level",
			"use_case": "Real-world secure communications"
		}
	}