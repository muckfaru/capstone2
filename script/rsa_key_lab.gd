extends Control

# ============================================================================
# RSA KEY LAB — Interactive Cryptography Lab
# Covers syllabus: 6.1 Public Key Cryptography / RSA steps
#                  6.2 RSA Public-Key Algorithm details
#                  6.3 Diffie-Hellman Algorithm
#                  6.4 Cryptography in Practice
#
# Students perform RSA key generation step-by-step, simulate Diffie-Hellman
# key exchange, and apply cryptography in practical scenarios.
# ============================================================================

# ── Scene Node References ─────────────────────────────────────────────────
@onready var quit_btn: Button = $MainVBox/TopBar/TopHBox/QuitButton
@onready var score_label: Label = $MainVBox/TopBar/TopHBox/ScoreLabel
@onready var phase_label: Label = $MainVBox/TopBar/TopHBox/PhaseLabel
@onready var hearts_label: Label = $MainVBox/TopBar/TopHBox/HeartsLabel
@onready var timer_label: Label = $MainVBox/TopBar/TopHBox/TimerLabel
@onready var title_label: Label = $MainVBox/TitleLabel
@onready var instruction_label: RichTextLabel = $MainVBox/InstructionLabel
@onready var content_area: VBoxContainer = $MainVBox/ContentScroll/ContentArea
@onready var feedback_label: Label = $MainVBox/BottomBar/BottomVBox/FeedbackLabel
@onready var next_btn: Button = $MainVBox/BottomBar/BottomVBox/NextButton

# Overlay panels (defined in .tscn)
@onready var intro_panel: Panel = $IntroPanel
@onready var tutorial_panel: Panel = $TutorialPanel
@onready var tutorial_title: Label = $TutorialPanel/TutorialVBox/TutorialTitle
@onready var tutorial_content: RichTextLabel = $TutorialPanel/TutorialVBox/TutorialContent
@onready var tutorial_example: RichTextLabel = $TutorialPanel/TutorialVBox/TutorialExample
@onready var results_panel: Panel = $ResultsPanel
@onready var results_title: Label = $ResultsPanel/ResultsVBox/ResultsTitle
@onready var results_stats: RichTextLabel = $ResultsPanel/ResultsVBox/ResultsStats
@onready var results_button: Button = $ResultsPanel/ResultsVBox/ResultsButton

# ── Audio Players ─────────────────────────────────────────────────────────
var audio_correct: AudioStreamPlayer
var audio_wrong: AudioStreamPlayer
var audio_step_complete: AudioStreamPlayer
var audio_victory: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_bgm: AudioStreamPlayer

# ── Game State ────────────────────────────────────────────────────────────
enum Phase {
	INTRO,
	RSA_LEARN,        # 6.1 — Learn RSA steps (guided walkthrough)
	RSA_PRACTICE,     # 6.2 — Practice RSA key gen (player does the math)
	DH_LEARN,         # 6.3 — Diffie-Hellman interactive simulation
	DH_PRACTICE,      # 6.3 — DH challenge
	PRACTICE_QUIZ,    # 6.4 — Cryptography in practice scenarios
	RESULTS,
	COMPLETE
}
var current_phase: Phase = Phase.INTRO
var current_step: int = 0
var score: int = 0
var max_score: int = 500
var hearts: int = 3
var combo: int = 0
var best_combo: int = 0
var correct_answers: int = 0
var total_answers: int = 0
var time_elapsed_ms: int = 0

# ── GameMode multiplayer ─────────────────────────────────────────────────
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# ── RSA Lab Data ─────────────────────────────────────────────────────────
var rsa_p: int = 0
var rsa_q: int = 0
var rsa_n: int = 0
var rsa_phi: int = 0
var rsa_e: int = 0
var rsa_d: int = 0

const SMALL_PRIMES := [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]

# ── DH Lab Data ──────────────────────────────────────────────────────────
var dh_p: int = 0
var dh_g: int = 0
var dh_alice_secret: int = 0
var dh_bob_secret: int = 0
var dh_alice_public: int = 0
var dh_bob_public: int = 0
var dh_shared_secret: int = 0

# ── Phase items ──────────────────────────────────────────────────────────
var phase_items: Array = []
var current_phase_item: int = 0
var _pending_phase: Phase = Phase.INTRO

# ── RSA Practice problems ────────────────────────────────────────────────
const RSA_PROBLEMS := [
	{"p": 3, "q": 11, "e": 7, "desc": "Classic small RSA"},
	{"p": 5, "q": 7, "e": 5, "desc": "Tiny prime pair"},
	{"p": 7, "q": 11, "e": 13, "desc": "Moderate difficulty"},
	{"p": 5, "q": 13, "e": 7, "desc": "Odd pair"},
	{"p": 11, "q": 3, "e": 7, "desc": "Reversed order"},
	{"p": 7, "q": 13, "e": 5, "desc": "Larger modulus"},
]

# ── Practice / real-world questions (6.4) ────────────────────────────────
const PRACTICE_SCENARIOS := [
	{
		"scenario": "You're setting up HTTPS for your website. The browser requests your server's certificate. What does the certificate contain?",
		"options": ["The server's private key", "The server's public key + identity info", "The symmetric session key", "The user's password hash"],
		"correct": 1,
		"explanation": "An SSL/TLS certificate contains the server's PUBLIC key and identity information, signed by a trusted Certificate Authority (CA). The private key NEVER leaves the server."
	},
	{
		"scenario": "During a TLS handshake, the client generates a pre-master secret. How is it securely sent to the server?",
		"options": ["It's sent in plaintext", "Encrypted with the server's public key (RSA)", "Hashed with SHA-256", "Sent via a separate channel"],
		"correct": 1,
		"explanation": "The client encrypts the pre-master secret with the server's RSA public key. Only the server's private key can decrypt it, establishing the shared secret for symmetric encryption."
	},
	{
		"scenario": "Modern TLS 1.3 uses Ephemeral Diffie-Hellman (ECDHE) instead of RSA key exchange. Why?",
		"options": ["ECDHE is simpler to implement", "ECDHE provides Forward Secrecy", "RSA is broken", "ECDHE doesn't need certificates"],
		"correct": 1,
		"explanation": "Forward Secrecy means if the server's private key is compromised later, past sessions remain secure because ECDHE generates unique keys per session that aren't derived from the long-term key."
	},
	{
		"scenario": "Alice signs a document with her private key. What can Bob verify using Alice's public key?",
		"options": ["The document was encrypted by Alice", "The document hasn't been tampered with AND it came from Alice", "The document is confidential", "The document was sent recently"],
		"correct": 1,
		"explanation": "Digital signatures provide both Authentication (it's from Alice) and Integrity (it hasn't been modified). The public key verification confirms both properties."
	},
	{
		"scenario": "A company uses RSA-2048 to protect their data. An employee suggests switching to ECC-256. Is this a good idea?",
		"options": ["No — 256 bits is much weaker than 2048", "Yes — ECC-256 provides equivalent security to RSA-3072", "No — ECC is not standardized", "Yes — but only for symmetric encryption"],
		"correct": 1,
		"explanation": "ECC-256 provides ~128 bits of security, equivalent to RSA-3072. ECC is more efficient (smaller keys, faster operations), making it better for mobile and IoT devices."
	},
	{
		"scenario": "A VPN connection is being established. The initial key exchange uses RSA. What encryption is used for the actual data tunnel?",
		"options": ["RSA encrypts all data", "AES-256 (symmetric) for the data stream", "Diffie-Hellman encrypts the data", "No encryption after key exchange"],
		"correct": 1,
		"explanation": "RSA (asymmetric) is only used to exchange the symmetric key. The actual data is encrypted with AES-256 (symmetric) because it's 100-1000x faster — this is hybrid encryption."
	},
	{
		"scenario": "Why can't you use Diffie-Hellman alone to send an encrypted email?",
		"options": ["DH is too slow", "DH only exchanges keys — it doesn't encrypt data", "DH requires both parties to be online simultaneously", "DH only works with 1024-bit keys"],
		"correct": 2,
		"explanation": "Classic Diffie-Hellman requires both parties to exchange public values in real-time (interactive protocol). Email is asynchronous. For email, you'd use RSA or a stored public key."
	},
	{
		"scenario": "Bitcoin uses ECDSA (Elliptic Curve Digital Signature Algorithm). What does signing a transaction prove?",
		"options": ["The transaction amount is correct", "The sender owns the private key for that Bitcoin address", "The transaction is encrypted", "The blockchain is secure"],
		"correct": 1,
		"explanation": "ECDSA proves the sender has the private key corresponding to their public Bitcoin address, authorizing the transaction without revealing the private key."
	},
	{
		"scenario": "In PGP email encryption, you encrypt the message body with AES, then encrypt the AES key with the recipient's RSA public key. Why not encrypt everything with RSA?",
		"options": ["RSA can only encrypt small data (< key size)", "RSA is insecure for large data", "There's no reason — RSA works for everything", "AES is required by law"],
		"correct": 0,
		"explanation": "RSA can only encrypt data smaller than the key size (e.g., 245 bytes for RSA-2048). So we use hybrid encryption: RSA encrypts only the small symmetric key, AES encrypts the large message."
	},
	{
		"scenario": "A Man-in-the-Middle attack on Diffie-Hellman works by the attacker doing DH with both parties separately. How do we prevent this?",
		"options": ["Use larger prime numbers", "Authenticate the public values using digital certificates", "Use DH over HTTPS only", "Run DH twice in sequence"],
		"correct": 1,
		"explanation": "Plain DH has no authentication — you don't know who you're exchanging keys with. Using certificates (signed by a CA) to authenticate the DH public values prevents MITM attacks."
	},
]

# Phase tutorial content
const PHASE_TUTORIALS := {
	"rsa_learn": {
		"title": "📖 PHASE 1: RSA KEY GENERATION",
		"content": "[color=#aabbcc]You'll walk through the [b]6 steps of RSA key generation[/b] with guided explanations.\n\nAfter reading each step's explanation, answer a question to confirm understanding.\n\n[color=#88ff88][b]The 6 RSA steps:[/b][/color]\n1. Choose two prime numbers (p, q)\n2. Compute n = p × q (modulus)\n3. Compute φ(n) = (p−1)(q−1) (Euler's totient)\n4. Choose e (public exponent, coprime to φ(n))\n5. Compute d (private exponent, d×e ≡ 1 mod φ(n))\n6. Build the complete key pair!\n\n[color=#ffcc00]We use small numbers for learning. Real RSA uses 2048+ bit primes![/color][/color]",
		"example": "[color=#00ffff]Public Key = (e, n)[/color] — share openly, used to encrypt\n[color=#ff88ff]Private Key = (d, n)[/color] — keep secret, used to decrypt"
	},
	"rsa_practice": {
		"title": "📖 PHASE 2: RSA PRACTICE",
		"content": "[color=#aabbcc]Now [b]YOU[/b] compute RSA values!\n\nGiven prime numbers p and q, you'll be asked to calculate:\n• [color=#00ffff]n = p × q[/color] (the modulus)\n• [color=#00ffff]φ(n) = (p-1)(q-1)[/color] (Euler's totient)\n• [color=#00ffff]d[/color] (the private exponent where d×e ≡ 1 mod φ(n))\n\n[color=#88ff88][b]Tips:[/b][/color]\n• n is just multiplication\n• φ(n): subtract 1 from each prime THEN multiply\n• d: find the number where (d × e) mod φ(n) = 1[/color]",
		"example": "[color=#ffcc00]Example:[/color] p=3, q=11 → n=33, φ(n)=2×10=20\nIf e=7, then d=3 because 3×7=21, 21 mod 20=1 ✓"
	},
	"dh_learn": {
		"title": "📖 PHASE 3: DIFFIE-HELLMAN KEY EXCHANGE",
		"content": "[color=#aabbcc]Diffie-Hellman lets two people create a [b]shared secret[/b] over a public channel!\n\n[color=#88ff88][b]The magic:[/b][/color]\n1. Agree on public values: prime p, generator g\n2. Each person picks a SECRET random number\n3. Each computes a PUBLIC value from their secret\n4. Exchange public values (anyone can see these!)\n5. Each computes the SAME shared secret!\n\n[color=#ffcc00]An eavesdropper sees the public values but CANNOT compute the shared secret.[/color]\nThis relies on the [b]Discrete Logarithm Problem[/b].\n\n[color=#ff8888]Used in: TLS, VPNs, Signal, WhatsApp, SSH[/color][/color]",
		"example": "[color=#00ffff]Alice[/color]: secret a → computes A = g^a mod p → sends A\n[color=#ff88ff]Bob[/color]: secret b → computes B = g^b mod p → sends B\nBoth compute: s = (other's public)^(own secret) mod p → [color=#88ff88]SAME![/color]"
	},
	"dh_practice": {
		"title": "📖 PHASE 4: DH PRACTICE",
		"content": "[color=#aabbcc]Now compute Diffie-Hellman values yourself!\n\nGiven public parameters (p, g) and secret values, calculate:\n• [color=#00ffff]A = g^a mod p[/color] (Alice's public value)\n• [color=#ff88ff]B = g^b mod p[/color] (Bob's public value)\n• [color=#ffcc00]s = B^a mod p = A^b mod p[/color] (shared secret)\n\n[color=#88ff88][b]How to compute g^a mod p manually:[/b][/color]\n1. Calculate g^a (power)\n2. Divide by p\n3. The remainder is your answer![/color]",
		"example": "[color=#ffcc00]Example:[/color] g=5, a=4, p=23\n5^4 = 625, 625 mod 23 = 625 - 27×23 = 625-621 = 4"
	},
	"practice_quiz": {
		"title": "📖 PHASE 5: CRYPTOGRAPHY IN PRACTICE",
		"content": "[color=#aabbcc]Apply your RSA and DH knowledge to [b]real-world scenarios![/b]\n\n[color=#88ff88][b]Key concepts to remember:[/b][/color]\n• [color=#00ffff]TLS/HTTPS[/color]: Uses certificates (RSA/ECC public keys) + DH key exchange + AES data\n• [color=#ff88ff]Digital Signatures[/color]: Sign with private key, verify with public key\n• [color=#ffcc00]Hybrid Encryption[/color]: Asymmetric for key exchange, symmetric for data\n• [color=#ff8888]Forward Secrecy[/color]: Ephemeral DH keys so past sessions stay safe\n• [color=#88ff88]Certificates[/color]: CA-signed identity + public key, prevents MITM\n\nRSA can only encrypt data smaller than key size → always use hybrid![/color]",
		"example": "[color=#ffcc00]Think:[/color] Is this about IDENTITY/TRUST? → Asymmetric (RSA, certificates)\nIs this about SPEED/DATA? → Symmetric (AES)\nIs this about KEY EXCHANGE? → DH or RSA key transport"
	},
}


# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	randomize()
	_load_audio_files()

	# GameMode detection
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[RSAKeyLab] GameMode detected — room: %s" % _gamemode_room_code)
		quit_btn.visible = false

	# Hide game UI, show intro
	_hide_all_overlays()
	intro_panel.visible = true
	next_btn.visible = false


func _process(delta: float) -> void:
	if current_phase != Phase.INTRO and current_phase != Phase.COMPLETE and current_phase != Phase.RESULTS:
		time_elapsed_ms += int(delta * 1000.0)
		@warning_ignore("integer_division")
		var secs: int = time_elapsed_ms / 1000
		@warning_ignore("integer_division")
		timer_label.text = "⏱ %d:%02d" % [secs / 60, secs % 60]


# ============================================================================
# AUDIO
# ============================================================================
func _load_audio_files() -> void:
	audio_correct = _create_audio("res://asset/minigamessoundsfx/tama.mp3", -5.0)
	audio_wrong = _create_audio("res://asset/minigamessoundsfx/error buzz.mp3", -5.0)
	audio_step_complete = _create_audio("res://asset/minigamessoundsfx/wave_complete.mp3", -5.0)
	audio_victory = _create_audio("res://asset/minigamessoundsfx/victory.mp3", -3.0)
	audio_game_over = _create_audio("res://asset/minigamessoundsfx/game_over.mp3", -3.0)
	var bgm_paths := ["res://asset/minigamessoundsfx/bgm_loop.mp3", "res://asset/minigamessoundsfx/lobby_bgm.mp3"]
	for p in bgm_paths:
		if ResourceLoader.exists(p):
			audio_bgm = _create_audio(p, -15.0)
			break

func _create_audio(path: String, vol: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = vol
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(player)
	return player

func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and not player.playing:
		player.play()


# ============================================================================
# OVERLAY MANAGEMENT
# ============================================================================
func _hide_all_overlays() -> void:
	intro_panel.visible = false
	tutorial_panel.visible = false
	results_panel.visible = false


# ============================================================================
# INTRO (scene panel)
# ============================================================================
func _on_start_pressed() -> void:
	intro_panel.visible = false
	_show_phase_tutorial("rsa_learn", Phase.RSA_LEARN)


# ============================================================================
# PHASE TUTORIAL (scene panel — shown before each phase)
# ============================================================================
func _show_phase_tutorial(key: String, next_phase: Phase) -> void:
	_pending_phase = next_phase
	var data: Dictionary = PHASE_TUTORIALS.get(key, {})
	if data.is_empty():
		_start_phase(next_phase)
		return
	tutorial_title.text = data.get("title", "")
	tutorial_content.text = data.get("content", "")
	tutorial_example.text = data.get("example", "")
	tutorial_panel.visible = true


func _on_tutorial_got_it() -> void:
	tutorial_panel.visible = false
	_start_phase(_pending_phase)


func _start_phase(phase: Phase) -> void:
	match phase:
		Phase.RSA_LEARN: _start_rsa_learn()
		Phase.RSA_PRACTICE: _start_rsa_practice()
		Phase.DH_LEARN: _start_dh_learn()
		Phase.DH_PRACTICE: _start_dh_practice()
		Phase.PRACTICE_QUIZ: _start_practice_quiz()


# ============================================================================
# PHASE 1: RSA LEARN (Guided walkthrough)
# ============================================================================
func _start_rsa_learn() -> void:
	current_phase = Phase.RSA_LEARN
	phase_label.text = "📊 Phase: 1/5"
	title_label.text = "PHASE 1: RSA KEY GENERATION"
	current_step = 0

	rsa_p = 3
	rsa_q = 11
	rsa_n = rsa_p * rsa_q  # 33
	rsa_phi = (rsa_p - 1) * (rsa_q - 1)  # 20
	rsa_e = 7
	rsa_d = _mod_inverse(rsa_e, rsa_phi)  # 3

	_show_rsa_learn_step()


func _show_rsa_learn_step() -> void:
	_clear_content()
	feedback_label.text = ""
	next_btn.visible = false

	var steps := [
		{
			"title": "Step 1: Choose Two Prime Numbers (p, q)",
			"content": "[color=#aabbcc]RSA starts by selecting two [color=#ffcc00]distinct prime numbers[/color].\n\nIn real RSA, these are [b]very large[/b] (1024+ bits each). For learning, we'll use small primes.\n\n[color=#00ffff]We choose: p = %d, q = %d[/color]\n\n[color=#88ff88][b]Why primes?[/b][/color] The security of RSA depends on the difficulty of factoring the product of two large primes. If someone can factor n back into p × q, they break RSA![/color]" % [rsa_p, rsa_q],
			"question": "Why must p and q be PRIME numbers?",
			"options": ["Primes are faster to compute", "Factoring the product of two primes is mathematically difficult", "Primes make smaller keys", "It's just a convention"],
			"correct": 1,
		},
		{
			"title": "Step 2: Compute n = p × q (The Modulus)",
			"content": "[color=#aabbcc]Multiply p and q to get [color=#ffcc00]n[/color], the modulus.\n\n[color=#00ffff]n = p × q = %d × %d = %d[/color]\n\nThis [b]n[/b] is part of BOTH the public and private keys.\n• Public key = (e, n)\n• Private key = (d, n)\n\n[color=#88ff88][b]Key insight:[/b][/color] n is public — everyone knows it. But factoring it back into p × q is computationally infeasible when p and q are large (300+ digits each in practice).[/color]" % [rsa_p, rsa_q, rsa_n],
			"question": "What is n = %d × %d?" % [rsa_p, rsa_q],
			"options": [str(rsa_n), str(rsa_p + rsa_q), str(rsa_p * rsa_q + 1), str((rsa_p - 1) * (rsa_q - 1))],
			"correct": 0,
		},
		{
			"title": "Step 3: Compute φ(n) = (p-1)(q-1) (Euler's Totient)",
			"content": "[color=#aabbcc]Calculate [color=#ffcc00]Euler's Totient Function[/color] φ(n):\n\n[color=#00ffff]φ(n) = (p - 1) × (q - 1) = (%d - 1) × (%d - 1) = %d × %d = %d[/color]\n\nφ(n) counts how many numbers less than n are [b]coprime[/b] (share no common factors) with n.\n\n[color=#88ff88][b]Why does this matter?[/b][/color] The totient is used to find the decryption key d. It's the \"hidden value\" that only someone who knows p and q can compute. Since p and q are secret, φ(n) is also secret![/color]" % [rsa_p, rsa_q, rsa_p - 1, rsa_q - 1, rsa_phi],
			"question": "What is φ(n) = (%d-1) × (%d-1)?" % [rsa_p, rsa_q],
			"options": [str(rsa_phi), str(rsa_n), str(rsa_p * rsa_q - 1), str(rsa_p + rsa_q - 2)],
			"correct": 0,
		},
		{
			"title": "Step 4: Choose e (Public Exponent)",
			"content": "[color=#aabbcc]Choose [color=#ffcc00]e[/color] such that:\n• 1 < e < φ(n) = %d\n• e is [b]coprime[/b] with φ(n) — meaning gcd(e, φ(n)) = 1\n\n[color=#00ffcc]Common choices in practice:[/color] e = 3, e = 17, e = 65537\nMost systems use [b]e = 65537[/b] (good balance of security and speed).\n\n[color=#00ffff]We choose: e = %d[/color]\nCheck: gcd(%d, %d) = %d ✅\n\n[color=#88ff88][b]e is the PUBLIC exponent[/b][/color] — part of the public key (e, n) that everyone can see.[/color]" % [rsa_phi, rsa_e, rsa_e, rsa_phi, _gcd(rsa_e, rsa_phi)],
			"question": "What condition must e satisfy with φ(n)?",
			"options": ["e must equal φ(n)", "gcd(e, φ(n)) must equal 1 (coprime)", "e must divide φ(n) evenly", "e must be larger than φ(n)"],
			"correct": 1,
		},
		{
			"title": "Step 5: Compute d (Private Exponent)",
			"content": "[color=#aabbcc]Find [color=#ffcc00]d[/color] such that:\n[color=#ff8888](d × e) mod φ(n) = 1[/color]\n\nThis means d is the [b]modular multiplicative inverse[/b] of e mod φ(n).\n\n[color=#00ffff]d × %d ≡ 1 (mod %d)[/color]\n[color=#00ffff]d = %d[/color]\n\nCheck: %d × %d = %d, and %d mod %d = 1 ✅\n\n[color=#88ff88][b]d is the PRIVATE exponent[/b][/color] — part of the private key (d, n). Only you know d![/color]" % [rsa_e, rsa_phi, rsa_d, rsa_d, rsa_e, rsa_d * rsa_e, rsa_d * rsa_e, rsa_phi],
			"question": "What is d if (d × %d) mod %d = 1?" % [rsa_e, rsa_phi],
			"options": [str(rsa_d), str(rsa_e), str(rsa_phi), str(rsa_n)],
			"correct": 0,
		},
		{
			"title": "Step 6: The Complete RSA Key Pair!",
			"content": "[color=#aabbcc]🎉 [b]RSA Key Generation Complete![/b]\n\n[color=#00ffff][b]PUBLIC KEY:[/b]  (e, n) = (%d, %d)[/color]\n→ Share this with everyone! Used to [b]encrypt[/b] messages to you.\n\n[color=#ff88ff][b]PRIVATE KEY:[/b] (d, n) = (%d, %d)[/color]\n→ Keep this SECRET! Used to [b]decrypt[/b] messages.\n\n[color=#ffcc00][b]How Encryption Works:[/b][/color]\n• Encrypt: ciphertext = message^e mod n\n• Decrypt: message = ciphertext^d mod n\n\n[color=#88ff88]Example: Encrypt message m = 4:\n• cipher = 4^%d mod %d = %d\n• decrypt back = cipher^%d mod %d = 4 ✅[/color][/color]" % [rsa_e, rsa_n, rsa_d, rsa_n, rsa_e, rsa_n, int(pow(4, rsa_e)) % rsa_n, rsa_d, rsa_n],
			"question": "In RSA, the PUBLIC key is used to _____ and the PRIVATE key to _____.",
			"options": ["Decrypt, Encrypt", "Encrypt, Decrypt", "Sign, Encrypt", "Hash, Verify"],
			"correct": 1,
		},
	]

	if current_step >= steps.size():
		_play_sfx(audio_step_complete)
		feedback_label.add_theme_color_override("font_color", Color(0, 1, 1))
		feedback_label.text = "🎉 RSA Learn phase complete! Moving to Practice..."
		next_btn.text = "PRACTICE RSA →"
		next_btn.visible = true
		return

	var step: Dictionary = steps[current_step]
	instruction_label.text = "[center][color=#ffcc00]Step %d of 6 — Read carefully, then answer the question![/color][/center]" % [current_step + 1]

	var step_title := Label.new()
	step_title.text = step["title"]
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_title.add_theme_font_size_override("font_size", 22)
	step_title.add_theme_color_override("font_color", Color(0, 1, 1))
	content_area.add_child(step_title)

	var panel := _create_styled_panel(Color(0.06, 0.08, 0.15, 0.95))
	content_area.add_child(panel)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.add_theme_font_size_override("normal_font_size", 16)
	rich.text = step["content"]
	panel.add_child(rich)

	var q_panel := _create_styled_panel(Color(0.1, 0.08, 0.15, 0.95))
	content_area.add_child(q_panel)
	var q_vbox := VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 8)
	q_panel.add_child(q_vbox)

	var q_lbl := Label.new()
	q_lbl.text = "❓ " + step["question"]
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 18)
	q_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_vbox.add_child(q_lbl)

	var options: Array = step["options"]
	for i in range(options.size()):
		var opt_btn := _create_choice_button("%s) %s" % [["A", "B", "C", "D"][i], options[i]], Color(0.1, 0.15, 0.25, 0.9), Vector2(550, 45))
		var correct_idx: int = step["correct"]
		opt_btn.pressed.connect(func(): _check_rsa_learn_answer(i, correct_idx))
		q_vbox.add_child(opt_btn)


func _check_rsa_learn_answer(chosen: int, correct: int) -> void:
	total_answers += 1
	if chosen == correct:
		_on_correct("Great! You understand this step.")
		score += 10
	else:
		_on_wrong("Review the explanation above and try to remember this for the practice phase!")

	current_step += 1
	await get_tree().create_timer(1.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_rsa_learn_step()


# ============================================================================
# PHASE 2: RSA PRACTICE
# ============================================================================
func _start_rsa_practice() -> void:
	current_phase = Phase.RSA_PRACTICE
	phase_label.text = "📊 Phase: 2/5"
	title_label.text = "PHASE 2: RSA PRACTICE"
	instruction_label.text = "[center][color=#ff88ff]Now YOU compute the RSA values! Solve each step.[/color][/center]"

	var problems := RSA_PROBLEMS.duplicate()
	problems.shuffle()
	phase_items = problems.slice(0, 3)
	current_phase_item = 0
	_show_rsa_practice_problem()


func _show_rsa_practice_problem() -> void:
	_clear_content()
	feedback_label.text = ""
	next_btn.visible = false

	if current_phase_item >= phase_items.size():
		_play_sfx(audio_step_complete)
		feedback_label.add_theme_color_override("font_color", Color(0, 1, 1))
		feedback_label.text = "🎉 RSA Practice complete! Moving to Diffie-Hellman..."
		next_btn.text = "DIFFIE-HELLMAN →"
		next_btn.visible = true
		return

	var prob: Dictionary = phase_items[current_phase_item]
	var p: int = prob["p"]
	var q: int = prob["q"]
	var e_val: int = prob["e"]
	var n_val := p * q
	var phi_val := (p - 1) * (q - 1)
	var d_val := _mod_inverse(e_val, phi_val)

	var step_type := current_phase_item % 3

	var card := _create_styled_panel(Color(0.06, 0.08, 0.15, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var prob_lbl := Label.new()
	prob_lbl.text = "Problem %d of %d — %s" % [current_phase_item + 1, phase_items.size(), prob["desc"]]
	prob_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prob_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	vbox.add_child(prob_lbl)

	var given_lbl := RichTextLabel.new()
	given_lbl.bbcode_enabled = true
	given_lbl.fit_content = true
	given_lbl.scroll_active = false
	given_lbl.add_theme_font_size_override("normal_font_size", 17)

	var question_text: String
	var correct_answer: int
	var wrong_answers: Array

	match step_type:
		0:
			given_lbl.text = "[color=#aabbcc]Given: [color=#ffcc00]p = %d[/color], [color=#ffcc00]q = %d[/color]\nCompute [color=#00ffff]n = p × q[/color][/color]" % [p, q]
			question_text = "What is n?"
			correct_answer = n_val
			wrong_answers = [p + q, p * q + 1, (p - 1) * (q - 1)]
		1:
			given_lbl.text = "[color=#aabbcc]Given: [color=#ffcc00]p = %d[/color], [color=#ffcc00]q = %d[/color], n = %d\nCompute [color=#00ffff]φ(n) = (p-1)(q-1)[/color][/color]" % [p, q, n_val]
			question_text = "What is φ(n)?"
			correct_answer = phi_val
			wrong_answers = [n_val, n_val - 1, p * q - p - q]
		_:
			given_lbl.text = "[color=#aabbcc]Given: [color=#ffcc00]e = %d[/color], [color=#ffcc00]φ(n) = %d[/color]\nFind [color=#00ffff]d[/color] such that (d × e) mod φ(n) = 1[/color]" % [e_val, phi_val]
			question_text = "What is d?"
			correct_answer = d_val
			wrong_answers = [e_val, phi_val, phi_val - e_val]

	vbox.add_child(given_lbl)

	var options_array: Array = [correct_answer]
	for w in wrong_answers:
		if w != correct_answer and w not in options_array:
			options_array.append(w)
	while options_array.size() < 4:
		var rand_val := correct_answer + randi_range(-5, 10)
		if rand_val > 0 and rand_val != correct_answer and rand_val not in options_array:
			options_array.append(rand_val)
	options_array.shuffle()

	var q_lbl := Label.new()
	q_lbl.text = "❓ " + question_text
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 20)
	q_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	content_area.add_child(q_lbl)

	var opts_vbox := VBoxContainer.new()
	opts_vbox.add_theme_constant_override("separation", 8)
	opts_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_area.add_child(opts_vbox)

	for i in range(options_array.size()):
		var opt_btn := _create_choice_button("%s) %d" % [["A", "B", "C", "D"][i], options_array[i]], Color(0.1, 0.15, 0.25, 0.9), Vector2(400, 50))
		var opt_val: int = options_array[i]
		opt_btn.pressed.connect(func(): _check_rsa_practice(opt_val, correct_answer))
		opts_vbox.add_child(opt_btn)


func _check_rsa_practice(chosen: int, correct: int) -> void:
	total_answers += 1
	if chosen == correct:
		_on_correct("Correct computation!")
		score += 20
	else:
		_on_wrong("The correct answer is %d." % correct)

	current_phase_item += 1
	await get_tree().create_timer(1.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_rsa_practice_problem()


# ============================================================================
# PHASE 3: DIFFIE-HELLMAN LEARN
# ============================================================================
func _start_dh_learn() -> void:
	current_phase = Phase.DH_LEARN
	phase_label.text = "📊 Phase: 3/5"
	title_label.text = "PHASE 3: DIFFIE-HELLMAN KEY EXCHANGE"
	current_step = 0

	dh_p = 23
	dh_g = 5
	dh_alice_secret = 6
	dh_bob_secret = 15
	dh_alice_public = int(pow(dh_g, dh_alice_secret)) % dh_p
	dh_bob_public = int(pow(dh_g, dh_bob_secret)) % dh_p
	dh_shared_secret = int(pow(dh_bob_public, dh_alice_secret)) % dh_p

	_show_dh_learn_step()


func _show_dh_learn_step() -> void:
	_clear_content()
	feedback_label.text = ""
	next_btn.visible = false

	var steps := [
		{
			"title": "Step 1: Agree on Public Parameters",
			"content": "[color=#aabbcc]Alice and Bob publicly agree on two numbers:\n\n[color=#ffcc00]p = %d[/color] (a large prime number — the modulus)\n[color=#ffcc00]g = %d[/color] (a generator / primitive root of p)\n\n[color=#88ff88][b]These are PUBLIC[/b][/color] — anyone can see p and g.\nAn eavesdropper knowing p and g still can't determine the shared secret!\n\n[b]Real-world DH[/b] uses p with 2048+ bits (600+ digits) and carefully chosen generators.[/color]" % [dh_p, dh_g],
			"question": "In Diffie-Hellman, p and g are:",
			"options": ["Secret values known only to Alice", "Public values that anyone can see", "Encrypted before sharing", "Generated by a trusted third party"],
			"correct": 1,
		},
		{
			"title": "Step 2: Generate Private Secrets",
			"content": "[color=#aabbcc]Each person picks a [color=#ff8888]SECRET[/color] random number:\n\n[color=#00ffff]Alice's secret: a = %d[/color] (only Alice knows this!)\n[color=#ff88ff]Bob's secret: b = %d[/color] (only Bob knows this!)\n\n[color=#88ff88][b]These NEVER leave their respective computers.[/b][/color]\nThe security of DH depends on these secrets remaining private.\n\nEven if an attacker sees everything exchanged publicly, they cannot determine a or b due to the [b]Discrete Logarithm Problem[/b].[/color]" % [dh_alice_secret, dh_bob_secret],
			"question": "Alice and Bob's secret values (a, b) are:",
			"options": ["Shared with each other", "Sent encrypted to a server", "Never transmitted — kept private forever", "Published after the exchange"],
			"correct": 2,
		},
		{
			"title": "Step 3: Compute Public Values",
			"content": "[color=#aabbcc]Each person computes their [color=#ffcc00]public value[/color]:\n\n[color=#00ffff]Alice computes: A = g^a mod p = %d^%d mod %d = %d[/color]\n[color=#ff88ff]Bob computes: B = g^b mod p = %d^%d mod %d = %d[/color]\n\nThey exchange A and B [b]publicly[/b].\n\n[color=#88ff88][b]The magic:[/b][/color] An eavesdropper sees A=%d, B=%d, g=%d, p=%d, but CANNOT compute a or b!\nThis is the [b]Discrete Logarithm Problem[/b] — given g^x mod p, finding x is computationally infeasible for large values.[/color]" % [dh_g, dh_alice_secret, dh_p, dh_alice_public, dh_g, dh_bob_secret, dh_p, dh_bob_public, dh_alice_public, dh_bob_public, dh_g, dh_p],
			"question": "Alice's public value A = g^a mod p = %d^%d mod %d = ?" % [dh_g, dh_alice_secret, dh_p],
			"options": [str(dh_alice_public), str(dh_bob_public), str(dh_g * dh_alice_secret), str(dh_p - dh_alice_secret)],
			"correct": 0,
		},
		{
			"title": "Step 4: Compute the Shared Secret!",
			"content": "[color=#aabbcc]Now each person computes the [color=#ffcc00]SHARED SECRET[/color]:\n\n[color=#00ffff]Alice computes: s = B^a mod p = %d^%d mod %d = %d[/color]\n[color=#ff88ff]Bob computes: s = A^b mod p = %d^%d mod %d = %d[/color]\n\n[color=#88ff88][b]🎉 THEY GET THE SAME NUMBER![/b][/color]\n\n[b]Why it works mathematically:[/b]\n• Alice computes: (g^b)^a mod p = g^(ab) mod p\n• Bob computes: (g^a)^b mod p = g^(ab) mod p\n• Both = g^(a×b) mod p = [color=#ffcc00]%d[/color]\n\nThis shared secret is now used as a symmetric key for AES![/color]" % [dh_bob_public, dh_alice_secret, dh_p, dh_shared_secret, dh_alice_public, dh_bob_secret, dh_p, dh_shared_secret, dh_shared_secret],
			"question": "The shared secret s = B^a mod p = %d^%d mod %d = ?" % [dh_bob_public, dh_alice_secret, dh_p],
			"options": [str(dh_shared_secret), str(dh_alice_public + dh_bob_public), str(dh_p), str(dh_alice_secret * dh_bob_secret)],
			"correct": 0,
		},
	]

	if current_step >= steps.size():
		_play_sfx(audio_step_complete)
		feedback_label.add_theme_color_override("font_color", Color(0, 1, 1))
		feedback_label.text = "🎉 DH Learn phase complete! Now practice DH computations..."
		next_btn.text = "DH PRACTICE →"
		next_btn.visible = true
		return

	var step: Dictionary = steps[current_step]
	instruction_label.text = "[center][color=#ffcc00]DH Step %d of 4[/color][/center]" % [current_step + 1]

	var step_title := Label.new()
	step_title.text = step["title"]
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_title.add_theme_font_size_override("font_size", 22)
	step_title.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	content_area.add_child(step_title)

	var panel := _create_styled_panel(Color(0.06, 0.1, 0.08, 0.95))
	content_area.add_child(panel)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.add_theme_font_size_override("normal_font_size", 16)
	rich.text = step["content"]
	panel.add_child(rich)

	var q_panel := _create_styled_panel(Color(0.1, 0.08, 0.1, 0.95))
	content_area.add_child(q_panel)
	var q_vbox := VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 8)
	q_panel.add_child(q_vbox)

	var q_lbl := Label.new()
	q_lbl.text = "❓ " + step["question"]
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 18)
	q_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_vbox.add_child(q_lbl)

	var options: Array = step["options"]
	for i in range(options.size()):
		var opt_btn := _create_choice_button("%s) %s" % [["A", "B", "C", "D"][i], options[i]], Color(0.1, 0.15, 0.2, 0.9), Vector2(500, 45))
		var correct_idx: int = step["correct"]
		opt_btn.pressed.connect(func(): _check_dh_learn_answer(i, correct_idx))
		q_vbox.add_child(opt_btn)


func _check_dh_learn_answer(chosen: int, correct: int) -> void:
	total_answers += 1
	if chosen == correct:
		_on_correct("Excellent! You're mastering Diffie-Hellman!")
		score += 10
	else:
		_on_wrong("Review the step above carefully.")

	current_step += 1
	await get_tree().create_timer(1.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_dh_learn_step()


# ============================================================================
# PHASE 4: DH PRACTICE
# ============================================================================
func _start_dh_practice() -> void:
	current_phase = Phase.DH_PRACTICE
	phase_label.text = "📊 Phase: 4/5"
	title_label.text = "PHASE 4: DH PRACTICE"
	instruction_label.text = "[center][color=#ffcc00]Compute Diffie-Hellman values yourself![/color][/center]"

	phase_items = []
	var dh_problems := [
		{"p": 23, "g": 5, "a": 4, "b": 3},
		{"p": 29, "g": 2, "a": 5, "b": 7},
		{"p": 17, "g": 3, "a": 6, "b": 4},
	]
	for prob in dh_problems:
		var A_val = int(pow(prob["g"], prob["a"])) % prob["p"]
		var B_val = int(pow(prob["g"], prob["b"])) % prob["p"]
		var s_val = int(pow(B_val, prob["a"])) % prob["p"]
		phase_items.append({
			"p": prob["p"], "g": prob["g"], "a": prob["a"], "b": prob["b"],
			"A": A_val, "B": B_val, "s": s_val
		})

	current_phase_item = 0
	_show_dh_practice_problem()


func _show_dh_practice_problem() -> void:
	_clear_content()
	feedback_label.text = ""
	next_btn.visible = false

	if current_phase_item >= phase_items.size():
		_play_sfx(audio_step_complete)
		feedback_label.add_theme_color_override("font_color", Color(0, 1, 1))
		feedback_label.text = "🎉 DH Practice complete! Final phase: Cryptography in Practice..."
		next_btn.text = "PRACTICE QUIZ →"
		next_btn.visible = true
		return

	var prob: Dictionary = phase_items[current_phase_item]
	var step_type := current_phase_item % 3

	var card := _create_styled_panel(Color(0.06, 0.1, 0.08, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var prob_lbl := Label.new()
	prob_lbl.text = "DH Problem %d of %d" % [current_phase_item + 1, phase_items.size()]
	prob_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prob_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	vbox.add_child(prob_lbl)

	var given_lbl := RichTextLabel.new()
	given_lbl.bbcode_enabled = true
	given_lbl.fit_content = true
	given_lbl.scroll_active = false
	given_lbl.add_theme_font_size_override("normal_font_size", 17)

	var question_text: String
	var correct_answer: int
	var wrong_1: int
	var wrong_2: int
	var wrong_3: int

	match step_type:
		0:
			given_lbl.text = "[color=#aabbcc]Public: p = %d, g = %d\nAlice's secret: a = %d\nCompute [color=#00ffff]Alice's public value: A = g^a mod p[/color][/color]" % [prob["p"], prob["g"], prob["a"]]
			question_text = "What is A = %d^%d mod %d?" % [prob["g"], prob["a"], prob["p"]]
			correct_answer = prob["A"]
			wrong_1 = prob["g"] * prob["a"]
			wrong_2 = (prob["A"] + 3) % prob["p"]
			wrong_3 = prob["p"] - prob["A"]
		1:
			given_lbl.text = "[color=#aabbcc]Public: p = %d, g = %d\nBob's secret: b = %d\nCompute [color=#ff88ff]Bob's public value: B = g^b mod p[/color][/color]" % [prob["p"], prob["g"], prob["b"]]
			question_text = "What is B = %d^%d mod %d?" % [prob["g"], prob["b"], prob["p"]]
			correct_answer = prob["B"]
			wrong_1 = prob["g"] * prob["b"]
			wrong_2 = (prob["B"] + 5) % prob["p"]
			wrong_3 = prob["p"] - prob["B"]
		_:
			given_lbl.text = "[color=#aabbcc]Alice's public A = %d, Bob's secret b = %d, p = %d\nCompute [color=#ffcc00]Shared secret: s = A^b mod p[/color][/color]" % [prob["A"], prob["b"], prob["p"]]
			question_text = "What is s = %d^%d mod %d?" % [prob["A"], prob["b"], prob["p"]]
			correct_answer = prob["s"]
			wrong_1 = prob["A"] * prob["b"]
			wrong_2 = (prob["s"] + 4) % prob["p"]
			wrong_3 = prob["A"] + prob["b"]

	vbox.add_child(given_lbl)

	var options_array: Array = [correct_answer]
	for w in [wrong_1, wrong_2, wrong_3]:
		if w != correct_answer and w > 0 and w not in options_array:
			options_array.append(w)
	while options_array.size() < 4:
		var rand_val := correct_answer + randi_range(1, 10)
		if rand_val not in options_array and rand_val > 0:
			options_array.append(rand_val)
	options_array.shuffle()

	var q_lbl := Label.new()
	q_lbl.text = "❓ " + question_text
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 20)
	q_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	content_area.add_child(q_lbl)

	var opts_vbox := VBoxContainer.new()
	opts_vbox.add_theme_constant_override("separation", 8)
	opts_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_area.add_child(opts_vbox)

	for i in range(options_array.size()):
		var opt_btn := _create_choice_button("%s) %d" % [["A", "B", "C", "D"][i], options_array[i]], Color(0.1, 0.15, 0.2, 0.9), Vector2(400, 50))
		var opt_val: int = options_array[i]
		opt_btn.pressed.connect(func(): _check_dh_practice(opt_val, correct_answer))
		opts_vbox.add_child(opt_btn)


func _check_dh_practice(chosen: int, correct: int) -> void:
	total_answers += 1
	if chosen == correct:
		_on_correct("Correct DH computation!")
		score += 20
	else:
		_on_wrong("The correct answer is %d." % correct)

	current_phase_item += 1
	await get_tree().create_timer(1.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_dh_practice_problem()


# ============================================================================
# PHASE 5: CRYPTOGRAPHY IN PRACTICE (6.4)
# ============================================================================
func _start_practice_quiz() -> void:
	current_phase = Phase.PRACTICE_QUIZ
	phase_label.text = "📊 Phase: 5/5"
	title_label.text = "PHASE 5: CRYPTOGRAPHY IN PRACTICE"
	instruction_label.text = "[center][color=#ff8888]Apply RSA and DH knowledge to real-world scenarios![/color][/center]"

	var shuffled := PRACTICE_SCENARIOS.duplicate()
	shuffled.shuffle()
	phase_items = shuffled.slice(0, 6)
	current_phase_item = 0
	_show_practice_item()


func _show_practice_item() -> void:
	_clear_content()
	feedback_label.text = ""
	next_btn.visible = false

	if current_phase_item >= phase_items.size():
		_play_sfx(audio_step_complete)
		await get_tree().create_timer(1.0).timeout
		_victory()
		return

	var item: Dictionary = phase_items[current_phase_item]

	var card := _create_styled_panel(Color(0.08, 0.06, 0.12, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var progress_lbl := Label.new()
	progress_lbl.text = "Scenario %d of %d" % [current_phase_item + 1, phase_items.size()]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	vbox.add_child(progress_lbl)

	var scenario_lbl := Label.new()
	scenario_lbl.text = "📋 " + item["scenario"]
	scenario_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_lbl.add_theme_font_size_override("font_size", 18)
	scenario_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	scenario_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(scenario_lbl)

	var opts_vbox := VBoxContainer.new()
	opts_vbox.add_theme_constant_override("separation", 8)
	opts_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_area.add_child(opts_vbox)

	var options: Array = item["options"]
	for i in range(options.size()):
		var opt_btn := _create_choice_button("%s) %s" % [["A", "B", "C", "D"][i], options[i]], Color(0.1, 0.12, 0.2, 0.9), Vector2(600, 50))
		var correct_idx: int = item["correct"]
		opt_btn.pressed.connect(func(): _check_practice_answer(i, correct_idx, item))
		opts_vbox.add_child(opt_btn)


func _check_practice_answer(chosen: int, correct: int, item: Dictionary) -> void:
	total_answers += 1
	if chosen == correct:
		_on_correct(item.get("explanation", ""))
		score += 25
	else:
		var correct_letter = ["A", "B", "C", "D"][correct]
		_on_wrong("Correct: %s. %s" % [correct_letter, item.get("explanation", "")])

	current_phase_item += 1
	await get_tree().create_timer(2.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_practice_item()


# ============================================================================
# CORRECT / WRONG
# ============================================================================
func _on_correct(explanation: String) -> void:
	correct_answers += 1
	combo += 1
	if combo > best_combo:
		best_combo = combo
	_play_sfx(audio_correct)
	feedback_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	feedback_label.text = "✅ CORRECT! (Combo x%d) — %s" % [combo, explanation]
	_update_hud()


func _on_wrong(explanation: String) -> void:
	combo = 0
	hearts -= 1
	_play_sfx(audio_wrong)
	feedback_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	feedback_label.text = "❌ WRONG! -❤️ — %s" % explanation
	_update_hud()


# ============================================================================
# VICTORY / GAME OVER (scene panel)
# ============================================================================
func _victory() -> void:
	current_phase = Phase.COMPLETE
	_clear_content()
	_play_sfx(audio_victory)

	var accuracy: float = (float(correct_answers) / float(max(total_answers, 1))) * 100.0
	var base_xp := 60
	var phase_xp := 40
	var accuracy_xp := int(accuracy * 0.5)
	var total_xp := base_xp + phase_xp + accuracy_xp
	var xp_awarded := TutorialManager.award_minigame_xp("advanced_rsa_key_lab", total_xp, score)
	if xp_awarded > 0:
		MinigameRewards.try_grant_rewards("advanced_rsa_key_lab", score, xp_awarded, self)

	if _is_gamemode:
		_submit_gamemode_score(score, max_score)
		return

	_show_results(true, xp_awarded)


func _game_over() -> void:
	current_phase = Phase.RESULTS
	_clear_content()
	_play_sfx(audio_game_over)

	var partial_xp := int(float(score) / 15.0) + 5
	TutorialManager.add_xp(partial_xp, "RSA Key Lab (Attempt)")

	if _is_gamemode:
		_submit_gamemode_score(score, max_score)
		return

	_show_results(false, partial_xp)


func _show_results(is_victory: bool, xp: int) -> void:
	var accuracy: float = (float(correct_answers) / float(max(total_answers, 1))) * 100.0
	@warning_ignore("integer_division")
	var secs: int = int(time_elapsed_ms / 1000)

	results_title.text = "🏆 LAB COMPLETE!" if is_victory else "💀 LAB FAILED"
	results_title.add_theme_color_override("font_color", Color(0.7, 0.5, 1) if is_victory else Color(1, 0.3, 0.3))

	@warning_ignore("integer_division")
	results_stats.text = """[center][color=#bb88ff][b]LAB REPORT[/b][/color]

[b]Score:[/b] %d / %d
[b]Accuracy:[/b] %.1f%% (%d / %d correct)
[b]Best Combo:[/b] %d
[b]Time:[/b] %d:%02d
[b]XP Earned:[/b] %d[/center]""" % [score, max_score, accuracy, correct_answers, total_answers, best_combo, secs / 60, secs % 60, xp]

	results_button.text = "FINISH →" if is_victory else "TRY AGAIN 🔄"
	results_panel.visible = true


func _on_results_btn_pressed() -> void:
	if current_phase == Phase.COMPLETE:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	else:
		get_tree().reload_current_scene()


# ============================================================================
# GAMEMODE
# ============================================================================
func _submit_gamemode_score(final_score: int, max_sc: int) -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": final_score,
		"max_score": max_sc,
		"time_taken_ms": time_taken_ms
	})
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
		print("[RSAKeyLab] GameMode score submitted → %d" % code)
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")


# ============================================================================
# NAVIGATION
# ============================================================================
func _on_next_pressed() -> void:
	match current_phase:
		Phase.INTRO:
			_show_phase_tutorial("rsa_learn", Phase.RSA_LEARN)
		Phase.RSA_LEARN:
			_show_phase_tutorial("rsa_practice", Phase.RSA_PRACTICE)
		Phase.RSA_PRACTICE:
			_show_phase_tutorial("dh_learn", Phase.DH_LEARN)
		Phase.DH_LEARN:
			_show_phase_tutorial("dh_practice", Phase.DH_PRACTICE)
		Phase.DH_PRACTICE:
			_show_phase_tutorial("practice_quiz", Phase.PRACTICE_QUIZ)
		Phase.COMPLETE:
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Phase.RESULTS:
			get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	if _is_gamemode:
		return
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_gamemode:
			return
		_on_quit_pressed()


# ============================================================================
# UI HELPERS
# ============================================================================
func _update_hud() -> void:
	score_label.text = "🏆 Score: %d" % score
	hearts_label.text = "❤️ x%d" % hearts


func _clear_content() -> void:
	for child in content_area.get_children():
		child.queue_free()


func _create_styled_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	style.border_width_left = 1; style.border_width_top = 1
	style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.3, 1, 0.3)
	style.content_margin_left = 20; style.content_margin_top = 16
	style.content_margin_right = 20; style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_choice_button(text: String, color: Color, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.border_color = Color(0.5, 0.3, 1, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)
	return btn


# ============================================================================
# MATH HELPERS
# ============================================================================
func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func _mod_inverse(e_val: int, phi: int) -> int:
	var t := 0
	var new_t := 1
	var r := phi
	var new_r := e_val
	while new_r != 0:
		@warning_ignore("integer_division")
		var quotient := r / new_r
		var temp_t := t - quotient * new_t
		t = new_t
		new_t = temp_t
		var temp_r := r - quotient * new_r
		r = new_r
		new_r = temp_r
	if t < 0:
		t = t + phi
	return t
