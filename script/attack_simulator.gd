extends Node
class_name AttackSimulator

# Attacker state
var has_symmetric_key: bool = false
var has_private_keys: bool = false
var intercept_enabled: bool = true

# Attack statistics
var attacks_attempted: int = 0
var attacks_successful: int = 0
var attacks_failed: int = 0

func _ready():
	print("AttackSimulator initialized")

func set_has_symmetric_key(value: bool):
	has_symmetric_key = value
	if value:
		print("⚠️ Attacker has intercepted the symmetric key!")

func set_intercept_enabled(value: bool):
	intercept_enabled = value

# Attempt to decrypt symmetric encryption
func attempt_decrypt_symmetric(ciphertext: String) -> Dictionary:
	attacks_attempted += 1
	
	if has_symmetric_key:
		attacks_successful += 1
		return {
			"success": true,
			"method": "Symmetric key interception",
			"decrypted_message": "Transfer $10,000 to Account 12345",
			"attack_method": "Key Interception Attack",
			"explanation": """❌ ATTACK SUCCESSFUL!

The attacker intercepted the symmetric key during
the key exchange phase. With the same key used for
encryption and decryption, the attacker can read
all messages.

Why this happened:
• Symmetric keys must be shared between parties
• The key was sent over an untrusted network
• Anyone who intercepts the key can decrypt messages

Solution: Use asymmetric encryption for key exchange!""",
			"vulnerability": "Key distribution problem"
		}
	else:
		attacks_failed += 1
		return {
			"success": false,
			"method": "Brute force attempt",
			"explanation": """✓ ATTACK FAILED

Without the symmetric key, the attacker would need to:
• Try all possible keys (2^256 for AES-256)
• This would take billions of years with current hardware

The encryption is secure, but only IF the key remains secret.""",
			"time_to_crack": "Billions of years"
		}

# Attempt to decrypt asymmetric encryption
func attempt_decrypt_asymmetric(ciphertext: String) -> Dictionary:
	attacks_attempted += 1
	
	if has_private_keys:
		attacks_successful += 1
		return {
			"success": true,
			"method": "Private key theft",
			"decrypted_message": "Classified information",
			"explanation": "The attacker somehow obtained the private key!"
		}
	else:
		attacks_failed += 1
		return {
			"success": false,
			"method": "Attempted RSA factorization",
			"explanation": """✓ ATTACK FAILED - Encryption Secure!

The attacker tried to decrypt the message but failed because:

1. Message encrypted with Bob's PUBLIC key
2. Only Bob's PRIVATE key can decrypt it
3. Attacker doesn't have the private key
4. Breaking RSA-2048 would take thousands of years

Key Insight:
• Public keys can be freely shared (even with attackers!)
• Only the private key holder can decrypt
• No need for secure key exchange!

This solves the key distribution problem.""",
			"time_to_crack": "Thousands of years (RSA-2048)",
			"attack_techniques_tried": [
				"Factorization attempt (infeasible)",
				"Brute force (computationally impossible)",
				"Passive interception (useless without private key)"
			]
		}

# Attempt to decrypt hybrid encryption
func attempt_decrypt_hybrid(session_key_encrypted: String, data_encrypted: String) -> Dictionary:
	attacks_attempted += 1
	
	# Attacker can see both transmissions but can't decrypt without private key
	if has_private_keys:
		attacks_successful += 1
		return {
			"success": true,
			"explanation": "Private key compromised - both session key and data decrypted"
		}
	else:
		attacks_failed += 1
		return {
			"success": false,
			"method": "Attempted hybrid attack",
			"explanation": """✓ ATTACK FAILED - Hybrid Encryption is Secure!

The attacker intercepted:
1. Session key (encrypted with RSA/Bob's public key)
2. Data (encrypted with AES/session key)

But the attack failed because:

Step 1: Session Key Extraction
• The session key is encrypted with Bob's PUBLIC key
• Attacker cannot decrypt it without Bob's PRIVATE key
• RSA-2048 factorization: computationally infeasible

Step 2: Data Decryption (blocked)
• Even though the attacker sees the AES-encrypted data
• They don't have the session key to decrypt it
• The session key was never sent in plaintext!

Why Hybrid is Best:
✓ Secure key exchange (asymmetric)
✓ Fast data encryption (symmetric)
✓ No pre-shared secrets needed
✓ This is how TLS/HTTPS works!

Real-world examples:
• HTTPS websites
• VPN connections
• Secure messaging apps
• SSH connections""",
			"attack_surface": [
				"Session key: Protected by RSA ✓",
				"Encrypted data: Protected by AES ✓",
				"No weak points found"
			]
		}

# Simulate different attack types
func simulate_attack_type(attack: String) -> Dictionary:
	match attack:
		"eavesdropping":
			return {
				"name": "Passive Eavesdropping",
				"description": "Attacker listens to network traffic",
				"success_against": ["Unencrypted", "Weak encryption"],
				"fails_against": ["Properly encrypted traffic"]
			}
		
		"mitm":
			return {
				"name": "Man-in-the-Middle Attack",
				"description": "Attacker intercepts and possibly modifies traffic",
				"success_against": ["Unencrypted", "No authentication"],
				"fails_against": ["Authenticated encryption", "Certificate pinning"]
			}
		
		"key_theft":
			return {
				"name": "Key Theft",
				"description": "Attacker steals cryptographic keys",
				"success_against": ["Any encryption if key is stolen"],
				"prevention": ["Hardware security modules", "Key management"]
			}
		
		"brute_force":
			return {
				"name": "Brute Force Attack",
				"description": "Trying all possible keys",
				"success_against": ["Weak keys", "Short passwords"],
				"fails_against": ["AES-256", "RSA-2048+"],
				"time_required": "Billions of years for modern algorithms"
			}
		
		_:
			return {"name": "Unknown attack"}

# Get attack statistics
func get_statistics() -> Dictionary:
	return {
		"total_attempts": attacks_attempted,
		"successful": attacks_successful,
		"failed": attacks_failed,
		"success_rate": (float(attacks_successful) / max(attacks_attempted, 1)) * 100.0
	}

# Educational: Show what attacker can see
func what_attacker_sees(encryption_type: String, encrypted_data: String) -> String:
	match encryption_type:
		"symmetric":
			if has_symmetric_key:
				return """Attacker's View:
📡 Intercepted: Encrypted data
🔑 Attacker has: Symmetric key (intercepted earlier!)
💀 Result: Can decrypt everything!

The attacker sees:
• %s
• Can decrypt to plaintext: "Transfer $10,000..."

Lesson: Symmetric encryption is only secure if the key
exchange is secure. This is the KEY DISTRIBUTION PROBLEM.""" % encrypted_data
			else:
				return """Attacker's View:
📡 Intercepted: %s
🔑 Attacker has: Nothing useful
✓ Result: Just sees encrypted gibberish

Without the key, this is computationally secure.""" % encrypted_data
		
		"asymmetric":
			return """Attacker's View:
📡 Intercepted: %s
🔓 Attacker knows: Bob's public key (everyone does!)
🔑 Attacker needs: Bob's private key (impossible to get)
✓ Result: Cannot decrypt!

Public key is PUBLIC - that's the point!
Only the private key holder can decrypt.""" % encrypted_data
		
		"hybrid":
			return """Attacker's View:
📡 Intercepted TWO transmissions:
1. Session key (RSA encrypted): Cannot decrypt
2. Data (AES encrypted): Cannot decrypt without session key

Attacker is blocked at BOTH steps:
• Can't get session key (needs private key)
• Can't decrypt data (needs session key)

Double protection! This is why hybrid is used in production."""
		
		_:
			return "Unknown encryption type"

# Simulate common cryptographic attacks
func simulate_timing_attack() -> Dictionary:
	return {
		"name": "Timing Attack",
		"type": "Side-channel attack",
		"description": "Analyzing encryption/decryption time to extract keys",
		"mitigation": "Constant-time implementations"
	}

func simulate_replay_attack() -> Dictionary:
	return {
		"name": "Replay Attack",
		"description": "Re-sending captured encrypted messages",
		"mitigation": "Nonces, timestamps, sequence numbers"
	}

# Reset attacker state
func reset():
	has_symmetric_key = false
	has_private_keys = false
	attacks_attempted = 0
	attacks_successful = 0
	attacks_failed = 0
	print("AttackSimulator reset")