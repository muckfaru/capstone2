extends Control

# ============================================================================
# CRYPTO SORTER — Symmetric vs Asymmetric Encryption Classification Game
# Covers syllabus: 5.1 Introduction to Key Public-Key Cryptography
#                  5.2 Public-Key Encryption Algorithms
# Students learn by sorting algorithms, matching properties, and answering
# challenge questions about symmetric & asymmetric encryption.
# ============================================================================

# ── Scene Node References ─────────────────────────────────────────────────
@onready var quit_btn: Button = $MainVBox/TopBar/TopHBox/QuitButton
@onready var score_label: Label = $MainVBox/TopBar/TopHBox/ScoreLabel
@onready var wave_label: Label = $MainVBox/TopBar/TopHBox/WaveLabel
@onready var combo_label: Label = $MainVBox/TopBar/TopHBox/ComboLabel
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
var audio_wave_complete: AudioStreamPlayer
var audio_victory: AudioStreamPlayer
var audio_game_over: AudioStreamPlayer
var audio_bgm: AudioStreamPlayer

# ── Game State ────────────────────────────────────────────────────────────
enum Phase { INTRO, SORTING, MATCHING, CHALLENGE, RESULTS, COMPLETE }
var current_phase: Phase = Phase.INTRO
var current_wave: int = 0
var max_waves: int = 5
var score: int = 0
var max_score: int = 500
var combo: int = 0
var best_combo: int = 0
var correct_answers: int = 0
var total_answers: int = 0
var hearts: int = 3
var time_elapsed_ms: int = 0
var _game_start_ticks: int = 0

# ── GameMode multiplayer ─────────────────────────────────────────────────
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# ── Wave-specific data ────────────────────────────────────────────────────
var phase_items: Array = []
var current_phase_item: int = 0
var _pending_wave: int = 0

# ── Sorting game data ───────────────────────────────────────────────────

const ALGORITHMS := [
	{"name": "AES (Advanced Encryption Standard)", "type": "symmetric",
	 "hint": "Uses the same key for encryption and decryption. Fast, used for bulk data.",
	 "detail": "AES is a block cipher with key sizes of 128, 192, or 256 bits. It's the gold standard for symmetric encryption."},
	{"name": "RSA (Rivest-Shamir-Adleman)", "type": "asymmetric",
	 "hint": "Uses a public/private key pair. Based on factoring large primes.",
	 "detail": "RSA uses two keys: a public key anyone can see, and a private key kept secret. Security relies on the difficulty of factoring large numbers."},
	{"name": "DES (Data Encryption Standard)", "type": "symmetric",
	 "hint": "Older algorithm using a 56-bit key. Now considered insecure.",
	 "detail": "DES was the standard from the 1970s but is now broken due to its short 56-bit key length."},
	{"name": "Diffie-Hellman Key Exchange", "type": "asymmetric",
	 "hint": "Allows two parties to establish a shared secret over an insecure channel.",
	 "detail": "Diffie-Hellman is not encryption itself, but a key exchange protocol using asymmetric math (discrete logarithm problem)."},
	{"name": "3DES (Triple DES)", "type": "symmetric",
	 "hint": "Applies DES three times with different keys for stronger encryption.",
	 "detail": "3DES improved DES by applying it three times, effectively giving a 112-bit security level."},
	{"name": "ECC (Elliptic Curve Cryptography)", "type": "asymmetric",
	 "hint": "Uses elliptic curves for smaller keys with equivalent security to RSA.",
	 "detail": "ECC provides the same security as RSA with much smaller key sizes (256-bit ECC ≈ 3072-bit RSA)."},
	{"name": "Blowfish", "type": "symmetric",
	 "hint": "Fast block cipher with variable key length (32-448 bits).",
	 "detail": "Blowfish was designed as a free alternative to existing algorithms. Replaced by its successor Twofish."},
	{"name": "ElGamal Encryption", "type": "asymmetric",
	 "hint": "Based on Diffie-Hellman, used for encryption and digital signatures.",
	 "detail": "ElGamal extends the Diffie-Hellman concept to provide both encryption and signing capabilities."},
	{"name": "RC4 (Rivest Cipher 4)", "type": "symmetric",
	 "hint": "Stream cipher once used in SSL/WEP. Now deprecated due to vulnerabilities.",
	 "detail": "RC4 generates a pseudorandom stream XORed with plaintext. Vulnerabilities led to its deprecation."},
	{"name": "DSA (Digital Signature Algorithm)", "type": "asymmetric",
	 "hint": "Used only for digital signatures, not encryption. Based on discrete logarithms.",
	 "detail": "DSA is a Federal standard for digital signatures, providing authentication and integrity."},
	{"name": "ChaCha20", "type": "symmetric",
	 "hint": "Modern stream cipher used in TLS 1.3 and WireGuard VPN.",
	 "detail": "ChaCha20 is a fast, secure alternative to AES, especially on devices without hardware AES support."},
	{"name": "Twofish", "type": "symmetric",
	 "hint": "AES finalist. Block cipher with 256-bit key, successor to Blowfish.",
	 "detail": "Twofish was an AES candidate. It supports key sizes up to 256 bits and is unpatented."},
]

const PROPERTIES := [
	{"property": "Uses ONE shared key for both encrypt and decrypt", "type": "symmetric",
	 "explanation": "Symmetric encryption means the SAME key is used on both sides."},
	{"property": "Uses a PUBLIC key and a PRIVATE key (key pair)", "type": "asymmetric",
	 "explanation": "Asymmetric uses two mathematically related but different keys."},
	{"property": "Much faster for encrypting large amounts of data", "type": "symmetric",
	 "explanation": "Symmetric algorithms are 100-1000x faster than asymmetric ones."},
	{"property": "Solves the key distribution problem", "type": "asymmetric",
	 "explanation": "Public keys can be shared openly, so no need for a secure channel to exchange keys."},
	{"property": "Key must be shared secretly before communication", "type": "symmetric",
	 "explanation": "The biggest weakness: how do you securely share the secret key?"},
	{"property": "Enables digital signatures for authentication", "type": "asymmetric",
	 "explanation": "Only the private key holder can sign; anyone with the public key can verify."},
	{"property": "Typical key sizes: 128, 192, or 256 bits", "type": "symmetric",
	 "explanation": "Symmetric keys are shorter because each bit provides ~1 bit of security."},
	{"property": "Typical key sizes: 2048 or 4096 bits", "type": "asymmetric",
	 "explanation": "Asymmetric keys must be much longer due to the math-based security model."},
	{"property": "Used for bulk data encryption (files, disks, VPNs)", "type": "symmetric",
	 "explanation": "Symmetric is preferred for speed when encrypting large data volumes."},
	{"property": "Used for key exchange, certificates, and signatures", "type": "asymmetric",
	 "explanation": "Asymmetric is used for small but critical operations like exchanging symmetric keys."},
	{"property": "Examples: AES, DES, 3DES, Blowfish, ChaCha20", "type": "symmetric",
	 "explanation": "These all use the single shared key model."},
	{"property": "Examples: RSA, ECC, Diffie-Hellman, ElGamal, DSA", "type": "asymmetric",
	 "explanation": "These all use the public/private key pair model."},
]

const CHALLENGE_QUESTIONS := [
	{
		"question": "A company needs to encrypt 10 TB of backup data. Which type should they primarily use?",
		"options": ["Symmetric (e.g., AES)", "Asymmetric (e.g., RSA)", "No encryption needed", "Both equally suitable"],
		"correct": 0,
		"explanation": "Symmetric encryption (like AES) is much faster and efficient for bulk data encryption. RSA would be impractically slow for 10 TB."
	},
	{
		"question": "Alice wants to send Bob a message that only Bob can read. They've never met. What should they use?",
		"options": ["Symmetric encryption only", "Asymmetric encryption (Bob's public key)", "Caesar cipher", "No encryption possible"],
		"correct": 1,
		"explanation": "Bob shares his public key openly. Alice encrypts with it. Only Bob's private key can decrypt. No prior key exchange needed!"
	},
	{
		"question": "In TLS/HTTPS, how are symmetric and asymmetric encryption used together?",
		"options": ["Only symmetric is used", "Only asymmetric is used", "Asymmetric for key exchange, then symmetric for data", "They alternate every packet"],
		"correct": 2,
		"explanation": "TLS uses asymmetric (RSA/ECDH) to securely exchange a symmetric session key, then uses that fast symmetric key (AES) for actual data."
	},
	{
		"question": "What is the main disadvantage of asymmetric encryption?",
		"options": ["It's not secure", "It's very slow compared to symmetric", "It requires physical key exchange", "It can only encrypt text"],
		"correct": 1,
		"explanation": "Asymmetric encryption is 100-1000x slower than symmetric. That's why it's used for small operations (key exchange, signatures) not bulk data."
	},
	{
		"question": "Which statement about key distribution is TRUE?",
		"options": [
			"Symmetric keys can be shared publicly",
			"Asymmetric public keys must be kept secret",
			"Symmetric keys must be shared via a secure channel",
			"Key distribution is equally easy for both types"
		],
		"correct": 2,
		"explanation": "Symmetric encryption's biggest challenge is securely distributing the shared secret key. Asymmetric solves this since public keys can be shared openly."
	},
	{
		"question": "Digital signatures use which type of encryption?",
		"options": ["Symmetric only", "Asymmetric (sign with private, verify with public)", "Both combined", "Neither - signatures don't use encryption"],
		"correct": 1,
		"explanation": "Digital signatures use asymmetric crypto: the sender signs with their PRIVATE key, and anyone can verify with the sender's PUBLIC key."
	},
	{
		"question": "A 256-bit AES key provides equivalent security to approximately what RSA key size?",
		"options": ["256-bit RSA", "1024-bit RSA", "15360-bit RSA", "They're not comparable"],
		"correct": 2,
		"explanation": "Due to different security models, a 256-bit symmetric key ≈ 15360-bit RSA key in equivalent security strength."
	},
	{
		"question": "Which encryption type is based on mathematical problems like factoring large primes?",
		"options": ["Symmetric", "Asymmetric", "Both", "Neither"],
		"correct": 1,
		"explanation": "Asymmetric encryption (like RSA) relies on the difficulty of mathematical problems - RSA uses prime factorization, others use discrete logarithms or elliptic curves."
	},
	{
		"question": "In a hybrid encryption system, the asymmetric algorithm encrypts the:",
		"options": ["Entire message", "Message header only", "Symmetric session key", "Digital signature"],
		"correct": 2,
		"explanation": "Hybrid encryption uses asymmetric to encrypt only the small symmetric key, then that symmetric key encrypts the actual (large) data."
	},
	{
		"question": "Why is ECC (Elliptic Curve) preferred over RSA in mobile devices?",
		"options": ["ECC is symmetric", "ECC provides same security with smaller keys (less processing)", "ECC is older and more tested", "ECC doesn't need a private key"],
		"correct": 1,
		"explanation": "ECC achieves equivalent security to RSA with much smaller keys (256-bit ECC ≈ 3072-bit RSA), making it faster and better for resource-constrained devices."
	},
]

const USE_CASES := [
	{"scenario": "Encrypting a hard drive with BitLocker", "type": "symmetric", "algo": "AES-256",
	 "explanation": "Disk encryption uses symmetric AES for speed. The key is protected by your password/TPM."},
	{"scenario": "Website HTTPS certificate verification", "type": "asymmetric", "algo": "RSA/ECC",
	 "explanation": "Your browser verifies the server's certificate using the server's public key."},
	{"scenario": "WhatsApp message encryption", "type": "symmetric", "algo": "AES-256 (with Signal Protocol)",
	 "explanation": "Messages use symmetric encryption for speed. The symmetric keys are exchanged using asymmetric Diffie-Hellman."},
	{"scenario": "Signing a software update package", "type": "asymmetric", "algo": "RSA/DSA",
	 "explanation": "The developer signs with their private key. Your OS verifies with the developer's public key."},
	{"scenario": "VPN tunnel data encryption", "type": "symmetric", "algo": "AES-256/ChaCha20",
	 "explanation": "VPN tunnels use symmetric encryption for the actual data stream, with asymmetric for the initial key exchange."},
	{"scenario": "Email PGP digital signature", "type": "asymmetric", "algo": "RSA/ECC",
	 "explanation": "You sign emails with your private key. Recipients verify your identity with your public key."},
	{"scenario": "Database field-level encryption", "type": "symmetric", "algo": "AES-256",
	 "explanation": "Encrypting database fields (like credit card numbers) uses fast symmetric encryption."},
	{"scenario": "SSH key authentication to a server", "type": "asymmetric", "algo": "RSA/Ed25519",
	 "explanation": "SSH uses your public key on the server and private key on your machine for passwordless login."},
]

# Wave tutorial content
const WAVE_TUTORIALS := {
	1: {
		"title": "📖 WAVE 1: SORT THE ALGORITHMS",
		"content": "[color=#aabbcc]You'll see cryptographic algorithm names one at a time.\nDecide if each one is [color=#00ffff]SYMMETRIC[/color] (one shared key) or [color=#ff88ff]ASYMMETRIC[/color] (public + private key pair).\n\n[color=#88ff88][b]Tips to remember:[/b][/color]\n• Symmetric = same key both sides (AES, DES, Blowfish, ChaCha20)\n• Asymmetric = key PAIR (RSA, ECC, DH, ElGamal, DSA)\n• If the hint mentions \"shared key\" or \"fast\" → likely Symmetric\n• If it mentions \"key pair\" or \"public/private\" → likely Asymmetric[/color]",
		"example": "[color=#ffcc00]Example:[/color] \"AES\" → Uses one shared key → [color=#00ffff]SYMMETRIC[/color]\n\"RSA\" → Uses public/private key pair → [color=#ff88ff]ASYMMETRIC[/color]"
	},
	2: {
		"title": "📖 WAVE 2: MATCH THE PROPERTIES",
		"content": "[color=#aabbcc]You'll see properties/characteristics of encryption.\nDecide which TYPE of encryption has that property.\n\n[color=#88ff88][b]Key differences:[/b][/color]\n• Symmetric: Fast, short keys (128-256 bit), bulk data, key distribution problem\n• Asymmetric: Slow, long keys (2048-4096 bit), key exchange, digital signatures\n• ANY mention of \"one key\" or \"shared\" = Symmetric\n• ANY mention of \"pair\" or \"public\" or \"signature\" = Asymmetric[/color]",
		"example": "[color=#ffcc00]Example:[/color] \"Uses one shared key\" → [color=#00ffff]SYMMETRIC[/color]\n\"Enables digital signatures\" → [color=#ff88ff]ASYMMETRIC[/color]"
	},
	3: {
		"title": "📖 WAVE 3: REAL-WORLD SCENARIOS",
		"content": "[color=#aabbcc]Real-world use cases! Decide which encryption type is PRIMARILY used.\n\n[color=#88ff88][b]Think about what's happening:[/b][/color]\n• Encrypting large data (files, disks, streams) → Symmetric (speed!)\n• Verifying identity or signing → Asymmetric (authentication!)\n• Key exchange or certificates → Asymmetric\n• VPN/messaging data → Symmetric (but key exchange was asymmetric)\n\n[color=#ff8888]Tricky cases:[/color] Many real systems use BOTH, but ask about the PRIMARY use.[/color]",
		"example": "[color=#ffcc00]Example:[/color] \"Encrypting a hard drive\" → bulk data → [color=#00ffff]SYMMETRIC[/color]\n\"SSH key authentication\" → identity verification → [color=#ff88ff]ASYMMETRIC[/color]"
	},
	4: {
		"title": "📖 WAVE 4: CHALLENGE QUESTIONS",
		"content": "[color=#aabbcc]Multiple-choice questions testing deeper understanding!\n\n[color=#88ff88][b]Key concepts to remember:[/b][/color]\n• Hybrid encryption: Asymmetric exchanges the symmetric key, then symmetric encrypts data\n• TLS/HTTPS uses BOTH types together\n• Key sizes: 256-bit AES ≈ 15360-bit RSA in equivalent security\n• Asymmetric is 100-1000x slower than symmetric\n• Digital signatures = sign with private key, verify with public key[/color]",
		"example": "[color=#ffcc00]Remember:[/color] When in doubt, think about SPEED vs TRUST.\nNeed speed for data? → Symmetric. Need trust without meeting? → Asymmetric."
	},
	5: {
		"title": "📖 WAVE 5: FINAL MIXED CHALLENGE",
		"content": "[color=#aabbcc]Everything combined! Algorithms, properties, and challenge questions mixed together.\n\n[color=#88ff88][b]Final review:[/b][/color]\n\n[color=#00ffff]SYMMETRIC[/color] = One key, fast, bulk data\n  AES, DES, 3DES, Blowfish, ChaCha20, Twofish, RC4\n\n[color=#ff88ff]ASYMMETRIC[/color] = Key pair, solves distribution, signatures\n  RSA, ECC, DH, ElGamal, DSA\n\n[color=#ffcc00]HYBRID[/color] = Real systems use BOTH together![/color]",
		"example": "[color=#ffcc00]You've got this![/color] Apply everything you've learned across all waves."
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
		print("[CryptoSorter] GameMode detected — room: %s" % _gamemode_room_code)
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
	audio_wave_complete = _create_audio("res://asset/minigamessoundsfx/wave_complete.mp3", -5.0)
	audio_victory = _create_audio("res://asset/minigamessoundsfx/victory.mp3", -3.0)
	audio_game_over = _create_audio("res://asset/minigamessoundsfx/game_over.mp3", -3.0)
	var bgm_paths = ["res://asset/minigamessoundsfx/bgm_loop.mp3", "res://asset/minigamessoundsfx/lobby_bgm.mp3"]
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
	_game_start_ticks = Time.get_ticks_msec()
	_show_wave_tutorial(1)


# ============================================================================
# WAVE TUTORIAL (scene panel — shown before each wave)
# ============================================================================
func _show_wave_tutorial(wave: int) -> void:
	_pending_wave = wave
	var data: Dictionary = WAVE_TUTORIALS.get(wave, {})
	if data.is_empty():
		_start_wave(wave)
		return
	tutorial_title.text = data.get("title", "")
	tutorial_content.text = data.get("content", "")
	tutorial_example.text = data.get("example", "")
	tutorial_panel.visible = true


func _on_tutorial_got_it() -> void:
	tutorial_panel.visible = false
	_start_wave(_pending_wave)


# ============================================================================
# WAVE START
# ============================================================================
func _start_wave(wave: int) -> void:
	current_wave = wave
	_clear_content()
	wave_label.text = "📊 Wave: %d/5" % wave
	feedback_label.text = ""
	next_btn.visible = false

	match wave:
		1: _setup_sorting_wave()
		2: _setup_matching_wave()
		3: _setup_usecase_wave()
		4: _setup_challenge_wave()
		5: _setup_final_wave()


# ============================================================================
# WAVE 1: SORT ALGORITHMS
# ============================================================================
func _setup_sorting_wave() -> void:
	current_phase = Phase.SORTING
	title_label.text = "WAVE 1: SORT THE ALGORITHMS"
	instruction_label.text = "[center][color=#aabbcc]Classify each algorithm as [color=#00ffff]SYMMETRIC[/color] or [color=#ff88ff]ASYMMETRIC[/color][/color][/center]"
	var shuffled := ALGORITHMS.duplicate()
	shuffled.shuffle()
	phase_items = shuffled.slice(0, 6)
	current_phase_item = 0
	_show_sort_item()


func _show_sort_item() -> void:
	_clear_content()
	if current_phase_item >= phase_items.size():
		_wave_complete()
		return

	var item: Dictionary = phase_items[current_phase_item]

	var card := _create_styled_panel(Color(0.08, 0.08, 0.15, 0.95))
	content_area.add_child(card)
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card.add_child(card_vbox)

	var progress_lbl := Label.new()
	progress_lbl.text = "Algorithm %d of %d" % [current_phase_item + 1, phase_items.size()]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	card_vbox.add_child(progress_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	card_vbox.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "💡 " + item["hint"]
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 15)
	hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(hint_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	content_area.add_child(btn_row)

	var sym_btn := _create_choice_button("🔑 SYMMETRIC", Color(0, 0.5, 0.7, 0.9), Vector2(260, 80))
	sym_btn.pressed.connect(func(): _check_sort_answer("symmetric", item))
	btn_row.add_child(sym_btn)

	var asym_btn := _create_choice_button("🔐 ASYMMETRIC", Color(0.5, 0.1, 0.5, 0.9), Vector2(260, 80))
	asym_btn.pressed.connect(func(): _check_sort_answer("asymmetric", item))
	btn_row.add_child(asym_btn)


func _check_sort_answer(chosen: String, item: Dictionary) -> void:
	total_answers += 1
	if chosen == item["type"]:
		_on_correct(item.get("detail", ""))
	else:
		var correct_type := "SYMMETRIC" if item["type"] == "symmetric" else "ASYMMETRIC"
		_on_wrong("This is %s. %s" % [correct_type, item.get("detail", "")])

	current_phase_item += 1
	await get_tree().create_timer(2.0).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_sort_item()


# ============================================================================
# WAVE 2: MATCH PROPERTIES
# ============================================================================
func _setup_matching_wave() -> void:
	current_phase = Phase.MATCHING
	title_label.text = "WAVE 2: MATCH THE PROPERTIES"
	instruction_label.text = "[center][color=#aabbcc]Which encryption type has this property?[/color][/center]"
	var shuffled := PROPERTIES.duplicate()
	shuffled.shuffle()
	phase_items = shuffled.slice(0, 6)
	current_phase_item = 0
	_show_match_item()


func _show_match_item() -> void:
	_clear_content()
	if current_phase_item >= phase_items.size():
		_wave_complete()
		return

	var item: Dictionary = phase_items[current_phase_item]

	var card := _create_styled_panel(Color(0.08, 0.08, 0.15, 0.95))
	content_area.add_child(card)
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card.add_child(card_vbox)

	var progress_lbl := Label.new()
	progress_lbl.text = "Property %d of %d" % [current_phase_item + 1, phase_items.size()]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	card_vbox.add_child(progress_lbl)

	var prop_lbl := Label.new()
	prop_lbl.text = "\"" + item["property"] + "\""
	prop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prop_lbl.add_theme_font_size_override("font_size", 22)
	prop_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	prop_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(prop_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	content_area.add_child(btn_row)

	var sym_btn := _create_choice_button("🔑 SYMMETRIC", Color(0, 0.5, 0.7, 0.9), Vector2(260, 80))
	sym_btn.pressed.connect(func(): _check_match_answer("symmetric", item))
	btn_row.add_child(sym_btn)

	var asym_btn := _create_choice_button("🔐 ASYMMETRIC", Color(0.5, 0.1, 0.5, 0.9), Vector2(260, 80))
	asym_btn.pressed.connect(func(): _check_match_answer("asymmetric", item))
	btn_row.add_child(asym_btn)


func _check_match_answer(chosen: String, item: Dictionary) -> void:
	total_answers += 1
	if chosen == item["type"]:
		_on_correct(item.get("explanation", ""))
	else:
		var correct_type := "SYMMETRIC" if item["type"] == "symmetric" else "ASYMMETRIC"
		_on_wrong("This is %s. %s" % [correct_type, item.get("explanation", "")])

	current_phase_item += 1
	await get_tree().create_timer(2.0).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_match_item()


# ============================================================================
# WAVE 3: USE CASES
# ============================================================================
func _setup_usecase_wave() -> void:
	current_phase = Phase.SORTING
	title_label.text = "WAVE 3: REAL-WORLD SCENARIOS"
	instruction_label.text = "[center][color=#aabbcc]Which encryption type is primarily used in this scenario?[/color][/center]"
	var shuffled := USE_CASES.duplicate()
	shuffled.shuffle()
	phase_items = shuffled.slice(0, 6)
	current_phase_item = 0
	_show_usecase_item()


func _show_usecase_item() -> void:
	_clear_content()
	if current_phase_item >= phase_items.size():
		_wave_complete()
		return

	var item: Dictionary = phase_items[current_phase_item]

	var card := _create_styled_panel(Color(0.08, 0.08, 0.15, 0.95))
	content_area.add_child(card)
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card.add_child(card_vbox)

	var progress_lbl := Label.new()
	progress_lbl.text = "Scenario %d of %d" % [current_phase_item + 1, phase_items.size()]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	card_vbox.add_child(progress_lbl)

	var scenario_lbl := Label.new()
	scenario_lbl.text = "📋 " + item["scenario"]
	scenario_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_lbl.add_theme_font_size_override("font_size", 22)
	scenario_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	scenario_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(scenario_lbl)

	var algo_lbl := Label.new()
	algo_lbl.text = "Common algorithm: " + item["algo"]
	algo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	algo_lbl.add_theme_font_size_override("font_size", 14)
	algo_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	card_vbox.add_child(algo_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	content_area.add_child(btn_row)

	var sym_btn := _create_choice_button("🔑 SYMMETRIC", Color(0, 0.5, 0.7, 0.9), Vector2(260, 80))
	sym_btn.pressed.connect(func(): _check_usecase_answer("symmetric", item))
	btn_row.add_child(sym_btn)

	var asym_btn := _create_choice_button("🔐 ASYMMETRIC", Color(0.5, 0.1, 0.5, 0.9), Vector2(260, 80))
	asym_btn.pressed.connect(func(): _check_usecase_answer("asymmetric", item))
	btn_row.add_child(asym_btn)


func _check_usecase_answer(chosen: String, item: Dictionary) -> void:
	total_answers += 1
	if chosen == item["type"]:
		_on_correct(item.get("explanation", ""))
	else:
		var correct_type := "SYMMETRIC" if item["type"] == "symmetric" else "ASYMMETRIC"
		_on_wrong("This is primarily %s. %s" % [correct_type, item.get("explanation", "")])

	current_phase_item += 1
	await get_tree().create_timer(2.0).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_usecase_item()


# ============================================================================
# WAVE 4: CHALLENGE QUESTIONS
# ============================================================================
func _setup_challenge_wave() -> void:
	current_phase = Phase.CHALLENGE
	title_label.text = "WAVE 4: CHALLENGE QUESTIONS"
	instruction_label.text = "[center][color=#aabbcc]Test your understanding of symmetric vs asymmetric encryption![/color][/center]"
	var shuffled := CHALLENGE_QUESTIONS.duplicate()
	shuffled.shuffle()
	phase_items = shuffled.slice(0, 5)
	current_phase_item = 0
	_show_challenge_item()


func _show_challenge_item() -> void:
	_clear_content()
	if current_phase_item >= phase_items.size():
		_wave_complete()
		return

	var item: Dictionary = phase_items[current_phase_item]

	var card := _create_styled_panel(Color(0.08, 0.08, 0.15, 0.95))
	content_area.add_child(card)
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card.add_child(card_vbox)

	var progress_lbl := Label.new()
	progress_lbl.text = "Question %d of %d" % [current_phase_item + 1, phase_items.size()]
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	card_vbox.add_child(progress_lbl)

	var q_lbl := Label.new()
	q_lbl.text = item["question"]
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 20)
	q_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(q_lbl)

	var options_vbox := VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 8)
	options_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_area.add_child(options_vbox)

	var options: Array = item["options"]
	for i in range(options.size()):
		var opt_btn := _create_choice_button("%s) %s" % [["A", "B", "C", "D"][i], options[i]], Color(0.1, 0.15, 0.25, 0.9), Vector2(600, 50))
		opt_btn.pressed.connect(func(): _check_challenge_answer(i, item))
		options_vbox.add_child(opt_btn)


func _check_challenge_answer(chosen_idx: int, item: Dictionary) -> void:
	total_answers += 1
	if chosen_idx == item["correct"]:
		_on_correct(item.get("explanation", ""))
	else:
		var correct_letter = ["A", "B", "C", "D"][item["correct"]]
		_on_wrong("Correct answer: %s. %s" % [correct_letter, item.get("explanation", "")])

	current_phase_item += 1
	await get_tree().create_timer(2.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_challenge_item()


# ============================================================================
# WAVE 5: FINAL MIXED
# ============================================================================
func _setup_final_wave() -> void:
	current_phase = Phase.CHALLENGE
	title_label.text = "WAVE 5: FINAL CHALLENGE"
	instruction_label.text = "[center][color=#ffcc00]Mixed challenge — algorithms, properties, use cases, and questions![/color][/center]"

	phase_items = []
	var algos := ALGORITHMS.duplicate()
	algos.shuffle()
	for i in range(2):
		phase_items.append({"type": "sort", "data": algos[i]})

	var props := PROPERTIES.duplicate()
	props.shuffle()
	for i in range(2):
		phase_items.append({"type": "match", "data": props[i]})

	var qs := CHALLENGE_QUESTIONS.duplicate()
	qs.shuffle()
	for i in range(2):
		phase_items.append({"type": "challenge", "data": qs[i]})

	phase_items.shuffle()
	current_phase_item = 0
	_show_final_item()


func _show_final_item() -> void:
	_clear_content()
	if current_phase_item >= phase_items.size():
		_wave_complete()
		return

	var mixed: Dictionary = phase_items[current_phase_item]
	match mixed["type"]:
		"sort": _show_final_sort(mixed["data"])
		"match": _show_final_match(mixed["data"])
		"challenge": _show_final_challenge(mixed["data"])


func _show_final_sort(item: Dictionary) -> void:
	var card := _create_styled_panel(Color(0.08, 0.06, 0.15, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var type_lbl := Label.new()
	type_lbl.text = "🔀 CLASSIFY THIS ALGORITHM"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	vbox.add_child(type_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "💡 " + item["hint"]
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	content_area.add_child(btn_row)

	var sym_btn := _create_choice_button("🔑 SYMMETRIC", Color(0, 0.5, 0.7, 0.9), Vector2(260, 70))
	sym_btn.pressed.connect(func(): _check_final_sort("symmetric", item))
	btn_row.add_child(sym_btn)

	var asym_btn := _create_choice_button("🔐 ASYMMETRIC", Color(0.5, 0.1, 0.5, 0.9), Vector2(260, 70))
	asym_btn.pressed.connect(func(): _check_final_sort("asymmetric", item))
	btn_row.add_child(asym_btn)


func _check_final_sort(chosen: String, item: Dictionary) -> void:
	total_answers += 1
	if chosen == item["type"]:
		_on_correct(item.get("detail", ""))
	else:
		_on_wrong("This is %s. %s" % [item["type"].to_upper(), item.get("detail", "")])
	current_phase_item += 1
	await get_tree().create_timer(2.0).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_final_item()


func _show_final_match(item: Dictionary) -> void:
	var card := _create_styled_panel(Color(0.08, 0.06, 0.15, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var type_lbl := Label.new()
	type_lbl.text = "🎯 MATCH THIS PROPERTY"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	vbox.add_child(type_lbl)

	var prop_lbl := Label.new()
	prop_lbl.text = "\"" + item["property"] + "\""
	prop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prop_lbl.add_theme_font_size_override("font_size", 20)
	prop_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	prop_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(prop_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	content_area.add_child(btn_row)

	var sym_btn := _create_choice_button("🔑 SYMMETRIC", Color(0, 0.5, 0.7, 0.9), Vector2(260, 70))
	sym_btn.pressed.connect(func(): _check_final_match("symmetric", item))
	btn_row.add_child(sym_btn)

	var asym_btn := _create_choice_button("🔐 ASYMMETRIC", Color(0.5, 0.1, 0.5, 0.9), Vector2(260, 70))
	asym_btn.pressed.connect(func(): _check_final_match("asymmetric", item))
	btn_row.add_child(asym_btn)


func _check_final_match(chosen: String, item: Dictionary) -> void:
	total_answers += 1
	if chosen == item["type"]:
		_on_correct(item.get("explanation", ""))
	else:
		_on_wrong("This is %s. %s" % [item["type"].to_upper(), item.get("explanation", "")])
	current_phase_item += 1
	await get_tree().create_timer(2.0).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_final_item()


func _show_final_challenge(item: Dictionary) -> void:
	var card := _create_styled_panel(Color(0.08, 0.06, 0.15, 0.95))
	content_area.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var type_lbl := Label.new()
	type_lbl.text = "❓ CHALLENGE QUESTION"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(type_lbl)

	var q_lbl := Label.new()
	q_lbl.text = item["question"]
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_size_override("font_size", 20)
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(q_lbl)

	var options_vbox := VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 6)
	options_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_area.add_child(options_vbox)

	var options: Array = item["options"]
	for i in range(options.size()):
		var opt_btn := _create_choice_button("%s) %s" % [["A", "B", "C", "D"][i], options[i]], Color(0.1, 0.15, 0.25, 0.9), Vector2(600, 45))
		opt_btn.pressed.connect(func(): _check_final_challenge(i, item))
		options_vbox.add_child(opt_btn)


func _check_final_challenge(chosen_idx: int, item: Dictionary) -> void:
	total_answers += 1
	if chosen_idx == item["correct"]:
		_on_correct(item.get("explanation", ""))
	else:
		_on_wrong("Correct: %s. %s" % [["A", "B", "C", "D"][item["correct"]], item.get("explanation", "")])
	current_phase_item += 1
	await get_tree().create_timer(2.5).timeout
	if hearts <= 0:
		_game_over()
		return
	_show_final_item()


# ============================================================================
# CORRECT / WRONG HANDLERS
# ============================================================================
func _on_correct(explanation: String) -> void:
	correct_answers += 1
	combo += 1
	if combo > best_combo:
		best_combo = combo

	var base_points := 15
	var combo_bonus := mini(combo * 3, 30)
	var points := base_points + combo_bonus
	score += points

	_play_sfx(audio_correct)
	feedback_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	feedback_label.text = "✅ CORRECT! +%d pts (Combo x%d) — %s" % [points, combo, explanation]
	_update_hud()


func _on_wrong(explanation: String) -> void:
	combo = 0
	hearts -= 1

	_play_sfx(audio_wrong)
	feedback_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	feedback_label.text = "❌ WRONG! -❤️ — %s" % explanation
	_update_hud()


func _wave_complete() -> void:
	_play_sfx(audio_wave_complete)
	feedback_label.add_theme_color_override("font_color", Color(0, 1, 1))
	feedback_label.text = "🎉 WAVE %d COMPLETE! Score: %d" % [current_wave, score]

	if current_wave >= max_waves:
		await get_tree().create_timer(1.5).timeout
		_victory()
	else:
		next_btn.text = "NEXT WAVE →"
		next_btn.visible = true


# ============================================================================
# RESULTS / VICTORY / GAME OVER (scene panel)
# ============================================================================
func _victory() -> void:
	current_phase = Phase.COMPLETE
	_clear_content()
	_play_sfx(audio_victory)

	var accuracy: float = (float(correct_answers) / float(max(total_answers, 1))) * 100.0

	# XP award
	var base_xp := 50
	var wave_xp := current_wave * 10
	var score_xp := int((float(score) / max_score) * 40)
	var accuracy_xp := int(accuracy * 0.5)
	var total_xp := base_xp + wave_xp + score_xp + accuracy_xp
	var xp_awarded := TutorialManager.award_minigame_xp("advanced_crypto_sorter", total_xp, score)
	if xp_awarded > 0:
		MinigameRewards.try_grant_rewards("advanced_crypto_sorter", score, xp_awarded, self)

	if _is_gamemode:
		_submit_gamemode_score(score, max_score)
		return

	_show_results(true, xp_awarded)


func _game_over() -> void:
	current_phase = Phase.RESULTS
	_clear_content()
	_play_sfx(audio_game_over)

	var partial_xp := current_wave * 5 + int(float(score) / 20.0)
	TutorialManager.add_xp(partial_xp, "Crypto Sorter (Attempt)")
	TutorialManager.mark_minigame_attempted("advanced_crypto_sorter", partial_xp)

	if _is_gamemode:
		_submit_gamemode_score(score, max_score)
		return

	_show_results(false, partial_xp)


func _show_results(is_victory: bool, xp: int) -> void:
	var accuracy: float = (float(correct_answers) / float(max(total_answers, 1))) * 100.0
	@warning_ignore("integer_division")
	var secs: int = int(time_elapsed_ms / 1000)

	results_title.text = "🏆 MISSION COMPLETE!" if is_victory else "💀 MISSION FAILED"
	results_title.add_theme_color_override("font_color", Color(0, 1, 1) if is_victory else Color(1, 0.3, 0.3))

	@warning_ignore("integer_division")
	results_stats.text = """[center][color=#00ffff][b]MISSION REPORT[/b][/color]

[b]Score:[/b] %d / %d
[b]Waves Completed:[/b] %d / %d
[b]Accuracy:[/b] %.1f%% (%d / %d correct)
[b]Best Combo:[/b] %d
[b]Time:[/b] %d:%02d
[b]XP Earned:[/b] %d[/center]""" % [score, max_score, current_wave, max_waves, accuracy, correct_answers, total_answers, best_combo, secs / 60, secs % 60, xp]

	results_button.text = "FINISH →" if is_victory else "TRY AGAIN 🔄"
	results_panel.visible = true


func _on_results_btn_pressed() -> void:
	if current_phase == Phase.COMPLETE:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	else:
		get_tree().reload_current_scene()


# ============================================================================
# GAMEMODE SCORE SUBMISSION
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
		print("[CryptoSorter] GameMode score submitted → %d" % code)
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
			_game_start_ticks = Time.get_ticks_msec()
			_show_wave_tutorial(1)
		Phase.COMPLETE:
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		Phase.RESULTS:
			get_tree().reload_current_scene()
		_:
			if current_wave < max_waves:
				_show_wave_tutorial(current_wave + 1)
			else:
				_victory()


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
	wave_label.text = "📊 Wave: %d/5" % current_wave
	combo_label.text = "🔥 Combo: %d" % combo
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
	style.border_color = Color(0, 1, 1, 0.3)
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
	hover_style.border_color = Color(0, 1, 1, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)
	return btn
