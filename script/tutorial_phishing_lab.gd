extends Control

# ============================================
# ENCRYPTION AUDIT LAB - Internal Email Interface
# Lessons 4.1 (Triple DES) & 4.2 (AES)
# WITH XP TRACKING SYSTEM
# ============================================

@onready var timer_label: Label = $TopBar/HBox/TimerLabel
@onready var progress_label: Label = $TopBar/HBox/ProgressLabel
@onready var back_button: Button = $TopBar/HBox/BackButton

# Email header elements
@onready var email_subject: Label = $EmailViewer/VBox/SubjectLine
@onready var sender_avatar: ColorRect = $EmailViewer/VBox/EmailHeader/HBox/Avatar
@onready var sender_name: Label = $EmailViewer/VBox/EmailHeader/HBox/SenderInfo/NameRow/SenderName
@onready var sender_email: Label = $EmailViewer/VBox/EmailHeader/HBox/SenderInfo/EmailRow/SenderEmail
@onready var to_me_label: Label = $EmailViewer/VBox/EmailHeader/HBox/SenderInfo/EmailRow/ToMe
@onready var timestamp_label: Label = $EmailViewer/VBox/EmailHeader/HBox/Timestamp
@onready var star_button: Button = $EmailViewer/VBox/EmailHeader/HBox/Actions/StarButton
@onready var reply_icon_button: Button = $EmailViewer/VBox/EmailHeader/HBox/Actions/ReplyButton
@onready var more_button: Button = $EmailViewer/VBox/EmailHeader/HBox/Actions/MoreButton

# Email body
@onready var email_body: Label = $EmailViewer/VBox/ScrollContainer/BodyContainer/BodyText

# Action buttons
@onready var reply_button: Button = $EmailViewer/VBox/ActionBar/HBox/ReplyBtn
@onready var spam_button: Button = $EmailViewer/VBox/ActionBar/HBox/SpamBtn
@onready var delete_button: Button = $EmailViewer/VBox/ActionBar/HBox/DeleteBtn

# Reply overlay (kept for scene compatibility, not used)
@onready var reply_overlay: ColorRect = $ReplyOverlay

# Feedback popup
@onready var feedback_overlay: ColorRect = $FeedbackOverlay
@onready var feedback_popup: PanelContainer = $FeedbackOverlay/FeedbackPopup
@onready var feedback_icon: Label = $FeedbackOverlay/FeedbackPopup/VBox/IconLabel
@onready var feedback_message: Label = $FeedbackOverlay/FeedbackPopup/VBox/MessageLabel
@onready var ok_button: Button = $FeedbackOverlay/FeedbackPopup/VBox/OKButton

# Game state
const TIME_LIMIT := 90.0
const TUTORIAL_ID := "intermediate_phishing"  # Keep ID for Firestore compatibility
var time_remaining := TIME_LIMIT
var emails_analyzed := 0
var total_emails := 8
var current_email_index := 0
var scenarios_reviewed := 0
var score := 0
var max_score := 0

# GameMode multiplayer
var _is_gamemode: bool = false
var _gamemode_room_code: String = ""
var _gamemode_lobby_url: String = ""
var _gamemode_start_time_ms: int = 0

# Active scenarios (randomly selected each game)
var scenarios: Array = []

# ============================================
# SCENARIO POOL: 18 scenarios (6 per verdict)
# verdict: "approve" = secure, "flag" = weak/vulnerable, "reject" = broken/deprecated
# ============================================
var all_scenarios := [
	# ── SECURE (Approve) ──────────────────────
	{
		"from_name": "Database Team",
		"from_email": "db-admin@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Config: Customer Database",
		"timestamp": "9:15 AM (2 hours ago)",
		"body": "Hi Security Team,\n\nWe're implementing AES-256-CBC encryption for our customer database.\n\nConfiguration:\n- Algorithm: AES-256\n- Mode: CBC (Cipher Block Chaining)\n- Key Size: 256 bits\n- IV: Randomly generated per record\n- Key Storage: Hardware Security Module (HSM)\n- Padding: PKCS7\n\nPlease review and approve.\n\nDatabase Team",
		"verdict": "approve",
		"details": [
			"• AES-256 is the gold standard for symmetric encryption",
			"• CBC mode with random IVs prevents pattern analysis",
			"• 256-bit key length provides maximum AES security",
			"• HSM key storage is best practice",
			"• PKCS7 padding is standard and secure"
		]
	},
	{
		"from_name": "API Development",
		"from_email": "api-team@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Config: REST API Layer",
		"timestamp": "11:30 AM (1 hour ago)",
		"body": "Security Team,\n\nProposing AES-128-GCM for our REST API encryption layer.\n\nConfiguration:\n- Algorithm: AES-128\n- Mode: GCM (Galois/Counter Mode)\n- Key Size: 128 bits\n- Authentication Tag: 128-bit\n- Nonce: 96-bit, unique per message\n\nGCM provides both encryption and authentication.\n\nBest regards,\nAPI Team",
		"verdict": "approve",
		"details": [
			"• AES-128 provides strong encryption (still unbroken)",
			"• GCM mode provides authenticated encryption (AEAD)",
			"• 96-bit unique nonces prevent replay attacks",
			"• Authentication tag ensures data integrity",
			"• Industry standard for API/TLS communications"
		]
	},
	{
		"from_name": "Payment Systems",
		"from_email": "payments@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Review: Legacy Payment Terminal",
		"timestamp": "Dec 10 (1 day ago)",
		"body": "Hi Security,\n\nOur ATM payment terminals currently use Triple DES (3TDEA) for transaction encryption.\n\nCurrent Config:\n- Algorithm: Triple DES (3-key)\n- Key Size: 168 bits (3 independent 56-bit keys)\n- Mode: CBC\n- Compliance: ANSI X9.52 standard\n\nWe have an AES migration planned for Q3 next year. Requesting continued approval until migration.\n\nPayment Systems Team",
		"verdict": "approve",
		"details": [
			"• Triple DES with 3 independent keys is still acceptable",
			"• 168-bit effective key length provides adequate security",
			"• CBC mode is appropriate for payment transactions",
			"• ANSI X9.52 compliance maintained",
			"• Migration plan to AES shows good security roadmap"
		]
	},
	{
		"from_name": "Cloud Infrastructure",
		"from_email": "cloud-ops@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Config: Cloud Storage Files",
		"timestamp": "Dec 9 (2 days ago)",
		"body": "Security Team,\n\nImplementing encryption at rest for our cloud storage.\n\nConfiguration:\n- Algorithm: AES-256\n- Mode: GCM\n- Key Management: AWS KMS with automatic rotation\n- Key Rotation: Every 90 days\n- Envelope Encryption: Yes (data key + master key)\n\nAll files encrypted before upload.\n\nCloud Infrastructure Team",
		"verdict": "approve",
		"details": [
			"• AES-256-GCM provides authenticated encryption",
			"• AWS KMS key management is industry standard",
			"• 90-day key rotation limits exposure window",
			"• Envelope encryption adds additional security layer",
			"• Encryption at rest protects data if storage is compromised"
		]
	},
	{
		"from_name": "Communications Team",
		"from_email": "comms@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Setup: Internal Chat System",
		"timestamp": "Dec 8 (3 days ago)",
		"body": "Hi Security,\n\nSetting up encryption for our internal messaging platform.\n\nConfiguration:\n- Algorithm: AES-192\n- Mode: CBC with HMAC-SHA256 authentication\n- Key Size: 192 bits\n- IV: Random per message, prepended to ciphertext\n- Key Exchange: ECDH (Elliptic Curve Diffie-Hellman)\n\nPlease approve.\n\nCommunications Team",
		"verdict": "approve",
		"details": [
			"• AES-192 provides strong encryption between AES-128 and AES-256",
			"• CBC with HMAC provides encrypt-then-MAC security",
			"• Random IVs prevent pattern analysis across messages",
			"• ECDH key exchange is secure and efficient",
			"• Proper IV handling (prepended to ciphertext)"
		]
	},
	{
		"from_name": "Banking Integration",
		"from_email": "banking-it@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Review: Interbank Transfer System",
		"timestamp": "Dec 7 (4 days ago)",
		"body": "Security Team,\n\nOur interbank transfer middleware uses Triple DES as required by the banking partner.\n\nConfiguration:\n- Algorithm: Triple DES (3-key variant)\n- Key Size: Three independent 56-bit keys\n- Mode: CBC\n- Key Exchange: Secure key ceremony with dual control\n- Compliance: PCI DSS, ISO 8583\n\nThe banking partner requires 3DES until their 2026 AES upgrade.\n\nBanking Integration Team",
		"verdict": "approve",
		"details": [
			"• Triple DES 3-key variant maintains adequate security",
			"• Dual-control key ceremony is excellent key management",
			"• PCI DSS and ISO 8583 compliance verified",
			"• Partner requirement justifies continued 3DES use",
			"• Planned partner migration to AES in 2026"
		]
	},
	# ── WEAK / VULNERABLE (Flag) ──────────────
	{
		"from_name": "Media Department",
		"from_email": "media@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Setup: Media Asset Storage",
		"timestamp": "10:45 AM (1 hour ago)",
		"body": "Security Team,\n\nWe need to encrypt our media files (images, videos) in storage.\n\nProposed Config:\n- Algorithm: AES-256\n- Mode: ECB (Electronic Codebook)\n- Key Size: 256 bits\n- Key Storage: Config file on server\n\nWe chose ECB for its simplicity and speed.\n\nMedia Team",
		"verdict": "flag",
		"details": [
			"• ECB mode does NOT hide data patterns!",
			"• Identical plaintext blocks produce identical ciphertext",
			"• Images encrypted with ECB still show visual patterns",
			"• Should use CBC or GCM mode instead",
			"• AES-256 key strength is good, but mode is the problem"
		]
	},
	{
		"from_name": "Mobile App Team",
		"from_email": "mobile-dev@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: Mobile App Data",
		"timestamp": "2:00 PM (30 min ago)",
		"body": "Hi Security,\n\nWe've added AES-128 encryption to our mobile app for local data.\n\nConfig:\n- Algorithm: AES-128\n- Mode: CBC\n- Key: Hardcoded in source code (Base64 encoded)\n- IV: Fixed value for consistency\n\nThe key is in our MobileEncryption.java class:\nprivate static final String KEY = \"aGFyZGNvZGVkS2V5MTIz\";\n\nMobile Dev Team",
		"verdict": "flag",
		"details": [
			"• Hardcoded keys can be extracted from app binaries!",
			"• Fixed IV reuse allows pattern analysis attacks",
			"• Base64 encoding is NOT encryption or obfuscation",
			"• Key should be derived from user password or stored in keystore",
			"• AES-128 algorithm choice is fine, but key management is poor"
		]
	},
	{
		"from_name": "Legacy Systems",
		"from_email": "legacy@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Review: Invoice Processing System",
		"timestamp": "Dec 10 (1 day ago)",
		"body": "Security Team,\n\nOur invoice processing system uses Triple DES encryption.\n\nConfiguration:\n- Algorithm: Triple DES (2-key variant / 2TDEA)\n- Effective Key Size: 112 bits\n- Mode: CBC\n- Key Storage: Encrypted database\n\nNote: We use the 2-key variant where Key1 = Key3.\n\nLegacy Systems Team",
		"verdict": "flag",
		"details": [
			"• 2-key Triple DES (2TDEA) provides only 112-bit security",
			"• NIST deprecated 2-key 3DES after 2023",
			"• Vulnerable to meet-in-the-middle attacks with reduced complexity",
			"• Should upgrade to 3-key variant or migrate to AES",
			"• CBC mode and encrypted key storage are good practices"
		]
	},
	{
		"from_name": "Backend Services",
		"from_email": "backend@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Config: Session Token Storage",
		"timestamp": "Dec 9 (2 days ago)",
		"body": "Hi Security,\n\nWe store encrypted session tokens using AES.\n\nConfiguration:\n- Algorithm: AES-256\n- Mode: CBC\n- No additional authentication (MAC/HMAC)\n- IV: Random, stored with ciphertext\n- Padding: PKCS7\n\nWe encrypt and store; no need for MAC since we trust our own database, right?\n\nBackend Team",
		"verdict": "flag",
		"details": [
			"• CBC without MAC is vulnerable to padding oracle attacks!",
			"• Attacker can decrypt data by manipulating ciphertext + observing errors",
			"• Should add HMAC-SHA256 (Encrypt-then-MAC) or use GCM mode",
			"• 'Trust our own database' is not a valid security assumption",
			"• AES-256, random IV, and PKCS7 are otherwise correct choices"
		]
	},
	{
		"from_name": "IoT Department",
		"from_email": "iot-team@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: Smart Sensor Data",
		"timestamp": "Dec 8 (3 days ago)",
		"body": "Security,\n\nOur IoT sensors encrypt telemetry data before transmission.\n\nConfig:\n- Algorithm: AES-128\n- Mode: CBC\n- IV: 0x00000000000000000000000000000000 (static)\n- Key: Derived from device serial number\n- Update Frequency: Every 5 seconds\n\nWe use a zero IV for simplicity since each device has a unique key.\n\nIoT Team",
		"verdict": "flag",
		"details": [
			"• Static zero IV makes CBC vulnerable to pattern leakage!",
			"• First blocks of identical messages produce identical ciphertext",
			"• Key derived from serial number is predictable if serial is known",
			"• Should use random IV per message or counter-based mode (CTR/GCM)",
			"• AES-128 algorithm choice is appropriate for IoT devices"
		]
	},
	{
		"from_name": "QA Environment",
		"from_email": "qa-ops@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption Setup: QA Test Environment",
		"timestamp": "Dec 7 (4 days ago)",
		"body": "Hi Security,\n\nWe've set up Triple DES encryption for our QA test environment.\n\nConfiguration:\n- Algorithm: Triple DES (3-key)\n- Mode: CBC\n- Key Storage: keys.properties file (plaintext)\n- Location: /etc/app/keys.properties\n- File permissions: readable by app service account\n\nSample from config:\n3des.key1=A1B2C3D4E5F6A7B8\n3des.key2=1A2B3C4D5E6F7A8B\n3des.key3=F1E2D3C4B5A6F7E8\n\nQA Team",
		"verdict": "flag",
		"details": [
			"• Encryption keys stored in plaintext files are easily stolen!",
			"• Anyone with file system access can read the keys",
			"• QA environment should still follow security practices",
			"• Keys should be in HSM, vault, or at minimum encrypted config",
			"• Triple DES 3-key and CBC mode choices are otherwise acceptable"
		]
	},
	# ── BROKEN / DEPRECATED (Reject) ──────────
	{
		"from_name": "E-Commerce Team",
		"from_email": "ecommerce@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: Credit Card Storage",
		"timestamp": "10:00 AM (2 hours ago)",
		"body": "Security Team,\n\nWe're implementing encryption for stored credit card numbers.\n\nProposed Config:\n- Algorithm: DES (Data Encryption Standard)\n- Key Size: 56 bits\n- Mode: ECB\n- Purpose: PCI compliance for card-on-file\n\nDES has been a proven standard since 1977. Should be reliable.\n\nE-Commerce Team",
		"verdict": "reject",
		"details": [
			"• Single DES was cracked in 1999 (brute-forced in 22 hours)!",
			"• 56-bit key is far too small for modern computing",
			"• ECB mode makes it even worse (pattern leakage)",
			"• DES was officially retired by NIST in 2005",
			"• PCI DSS requires AES-128 minimum for card data",
			"• Must use AES-256 for credit card encryption"
		]
	},
	{
		"from_name": "Health IT",
		"from_email": "health-it@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: Patient Medical Records",
		"timestamp": "Dec 10 (1 day ago)",
		"body": "Hi Security,\n\nOur medical records system needs encryption for HIPAA compliance.\n\nConfig:\n- Algorithm: DES\n- Key Size: 56 bits\n- Mode: ECB\n- Records: Patient names, diagnoses, prescriptions\n\nWe found DES libraries in our existing Java framework, so it's the easiest to implement.\n\nHealth IT Team",
		"verdict": "reject",
		"details": [
			"• DES is completely broken and NIST-deprecated since 2005!",
			"• 56-bit keys can be brute-forced in hours with modern hardware",
			"• ECB mode leaks patterns in structured medical data",
			"• HIPAA requires strong encryption — DES does NOT qualify",
			"• 'Easy to implement' does NOT equal secure",
			"• Patient data requires AES-128 or AES-256"
		]
	},
	{
		"from_name": "Web Team",
		"from_email": "webdev@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "API Security: Login Endpoint",
		"timestamp": "3:30 PM (15 min ago)",
		"body": "Security Team,\n\nOur login API currently sends credentials over HTTP.\n\nCurrent Setup:\n- Protocol: HTTP (port 80)\n- Encryption: None (plaintext)\n- Password: Sent in POST body as plain text\n- Justification: Internal network only, behind firewall\n\nWe think the firewall provides enough protection. TLS would add latency.\n\nWeb Development Team",
		"verdict": "reject",
		"details": [
			"• Plaintext credentials can be intercepted by anyone on network!",
			"• 'Internal network only' is NOT a security guarantee",
			"• Insiders and compromised devices can sniff traffic",
			"• TLS latency is negligible (<2ms) with modern hardware",
			"• Every login endpoint MUST use HTTPS/TLS",
			"• Violates defense-in-depth security principles"
		]
	},
	{
		"from_name": "Embedded Systems",
		"from_email": "embedded@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: Firmware Update Channel",
		"timestamp": "Dec 9 (2 days ago)",
		"body": "Hi Security,\n\nWe encrypt firmware updates sent to our embedded devices.\n\nConfig:\n- Algorithm: DES\n- Key: 0x0101010101010101\n- Mode: CBC\n- Purpose: Prevent unauthorized firmware modification\n\nThis key was chosen because it's easy to remember and type during device provisioning.\n\nEmbedded Systems Team",
		"verdict": "reject",
		"details": [
			"• 0x0101010101010101 is a known DES weak key!",
			"• DES weak keys produce identical encryption and decryption",
			"• Single DES is already broken regardless of key choice",
			"• 'Easy to remember' keys are trivial to guess",
			"• Firmware encryption needs AES-GCM (authenticated encryption)",
			"• Compromised firmware = complete device takeover"
		]
	},
	{
		"from_name": "Finance Department",
		"from_email": "finance-it@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Data Protection: Financial Reports",
		"timestamp": "Dec 8 (3 days ago)",
		"body": "Security Team,\n\nWe need to protect our quarterly financial reports stored on the shared drive.\n\nProposed Solution:\n- Algorithm: ROT13 encoding\n- Implementation: Simple letter substitution (A->N, B->O, etc.)\n- Advantage: Very fast, no key management needed\n- Coverage: All .xlsx and .pdf financial files\n\nROT13 is encryption because it transforms the data, right?\n\nFinance IT",
		"verdict": "reject",
		"details": [
			"• ROT13 is NOT encryption — it's a simple letter substitution!",
			"• ROT13 applied twice returns the original text",
			"• Provides ZERO security — any attacker can reverse it instantly",
			"• No key = no encryption by definition",
			"• Financial data requires AES-256 encryption",
			"• This would be a critical compliance violation"
		]
	},
	{
		"from_name": "Cloud Migration",
		"from_email": "cloud-migration@securecorp.com",
		"to": "security-review@securecorp.com",
		"subject": "Encryption: New Cloud Storage Solution",
		"timestamp": "Dec 7 (4 days ago)",
		"body": "hi security,\n\nim setting up encryption for our new cloud storage platform.\n\nplan:\n- algorithm: DES (64-bit block, 56-bit key)\n- mode: CBC\n- storage: AWS S3 buckets\n- data: employee HR records, contracts, payroll\n\nDES should be fine since we're also using S3 bucket policies for access control. the bucket is private so encryption doesn't need to be super strong.\n\nthx,\nCloud Migration",
		"verdict": "reject",
		"details": [
			"• Single DES is broken — NEVER use it for new systems!",
			"• 56-bit key can be brute-forced in hours (modern GPUs)",
			"• 'Bucket is private' does NOT make weak encryption acceptable",
			"• HR/payroll data is highly sensitive — requires strong encryption",
			"• AWS S3 offers AES-256 server-side encryption by default!",
			"• Access control and encryption are DIFFERENT security layers"
		]
	}
]

func _ready() -> void:
	print("� Encryption Audit Lab Ready")
	
	if not _verify_nodes():
		push_error("Critical nodes missing! Check scene structure.")
		return
	
	# GameMode detection
	_is_gamemode = get_tree().has_meta("gamemode_room_code")
	if _is_gamemode:
		_gamemode_room_code = str(get_tree().get_meta("gamemode_room_code", ""))
		_gamemode_lobby_url = str(get_tree().get_meta("gamemode_lobby_url", ""))
		_gamemode_start_time_ms = int(get_tree().get_meta("gamemode_start_time_ms", 0))
		print("[GameMode] Encryption Audit Lab running in game mode (room: %s)" % _gamemode_room_code)
		if back_button:
			back_button.visible = false
	
	# Select random scenarios from pool
	_select_random_scenarios()
	
	# Calculate max possible score
	max_score = total_emails * 150
	
	if reply_overlay:
		reply_overlay.visible = false
	feedback_overlay.visible = false
	_update_progress_label()
	
	_show_email(0)
	
	# Connect buttons: Approve / Flag / Reject
	reply_button.pressed.connect(_on_approve_pressed)
	spam_button.pressed.connect(_on_flag_pressed)
	delete_button.pressed.connect(_on_reject_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _select_random_scenarios() -> void:
	randomize()
	var approve_pool: Array = []
	var flag_pool: Array = []
	var reject_pool: Array = []
	for s in all_scenarios:
		match s["verdict"]:
			"approve": approve_pool.append(s)
			"flag": flag_pool.append(s)
			"reject": reject_pool.append(s)
	approve_pool.shuffle()
	flag_pool.shuffle()
	reject_pool.shuffle()
	# Pick at least 2 from each category, then 2 more random
	scenarios = []
	for i in range(min(3, approve_pool.size())):
		scenarios.append(approve_pool[i])
	for i in range(min(3, flag_pool.size())):
		scenarios.append(flag_pool[i])
	for i in range(min(2, reject_pool.size())):
		scenarios.append(reject_pool[i])
	# If we have fewer than 8, fill from remaining
	var remaining: Array = []
	for s in all_scenarios:
		if s not in scenarios:
			remaining.append(s)
	remaining.shuffle()
	while scenarios.size() < total_emails and remaining.size() > 0:
		scenarios.append(remaining.pop_front())
	scenarios.shuffle()
	total_emails = scenarios.size()
	print("🎲 Selected %d random scenarios for this session" % total_emails)

func _verify_nodes() -> bool:
	var nodes_to_check = [
		["timer_label", timer_label],
		["progress_label", progress_label],
		["email_subject", email_subject],
		["sender_name", sender_name],
		["sender_email", sender_email],
		["to_me_label", to_me_label],
		["timestamp_label", timestamp_label],
		["email_body", email_body],
		["reply_button", reply_button],
		["spam_button", spam_button],
		["delete_button", delete_button],
		["back_button", back_button]
	]
	
	var all_valid = true
	for node_info in nodes_to_check:
		if node_info[1] == null:
			push_error("Node '%s' is null!" % node_info[0])
			all_valid = false
	
	return all_valid

func _process(delta: float) -> void:
	if time_remaining > 0 and emails_analyzed < total_emails:
		time_remaining -= delta
		_update_timer_display()
		
		if time_remaining <= 0:
			_on_time_expired()

func _show_email(index: int) -> void:
	if index >= scenarios.size():
		return
	
	current_email_index = index
	var scenario = scenarios[index]
	
	if email_subject:
		email_subject.text = scenario["subject"]
	if sender_name:
		sender_name.text = scenario["from_name"]
	if sender_email:
		sender_email.text = "<" + scenario["from_email"] + ">"
	if to_me_label:
		to_me_label.text = "to security-review"
	if timestamp_label:
		timestamp_label.text = scenario["timestamp"]
	if email_body:
		email_body.text = scenario["body"]
	
	# Set avatar color based on sender
	if sender_avatar:
		var hash_val = scenario["from_name"].hash()
		var colors = [
			Color(0.2, 0.6, 0.9),
			Color(0.9, 0.3, 0.3),
			Color(0.3, 0.8, 0.4),
			Color(0.9, 0.7, 0.2),
			Color(0.7, 0.3, 0.9),
		]
		sender_avatar.color = colors[hash_val % colors.size()]
	
	# Enable buttons
	if reply_button:
		reply_button.disabled = false
	if spam_button:
		spam_button.disabled = false
	if delete_button:
		delete_button.disabled = false

func _on_approve_pressed() -> void:
	_check_answer_action("approve")

func _on_flag_pressed() -> void:
	_check_answer_action("flag")

func _on_reject_pressed() -> void:
	_check_answer_action("reject")

func _check_answer_action(action: String) -> void:
	if reply_button:
		reply_button.disabled = true
	if spam_button:
		spam_button.disabled = true
	if delete_button:
		delete_button.disabled = true
	
	var scenario = scenarios[current_email_index]
	var verdict: String = scenario["verdict"]
	var correct = false
	var explanation = ""
	var detail_text = "\n".join(scenario["details"])
	
	scenarios_reviewed += 1
	
	if action == verdict:
		# Correct answer
		correct = true
		score += 150
		emails_analyzed += 1
		match verdict:
			"approve":
				explanation = "✅ CORRECT! This encryption configuration is secure.\n\nSecure Practices:\n" + detail_text
			"flag":
				explanation = "✅ CORRECT! This config has vulnerabilities that need attention.\n\nSecurity Concerns:\n" + detail_text
			"reject":
				explanation = "✅ CORRECT! This encryption is broken/deprecated and must be rejected.\n\nCritical Issues:\n" + detail_text
	else:
		# Wrong answer
		correct = false
		match [action, verdict]:
			# Approve something that should be flagged
			["approve", "flag"]:
				score -= 50
				explanation = "❌ WRONG! You approved a vulnerable configuration!\n\nThis should have been FLAGGED.\n\nSecurity Concerns:\n" + detail_text
			# Approve something that should be rejected
			["approve", "reject"]:
				score -= 100
				explanation = "⚠️ DANGEROUS! You approved BROKEN encryption!\n\nThis must be REJECTED immediately.\n\nCritical Issues:\n" + detail_text
			# Flag something that's actually secure
			["flag", "approve"]:
				score -= 25
				explanation = "❌ Overly cautious! This configuration is actually secure.\n\nSecure Practices:\n" + detail_text
			# Flag something that should be rejected
			["flag", "reject"]:
				score -= 50
				explanation = "❌ Not strict enough! This should be REJECTED outright.\n\nCritical Issues:\n" + detail_text
			# Reject something that's secure
			["reject", "approve"]:
				score -= 50
				explanation = "❌ Unnecessary rejection! This configuration is secure.\n\nSecure Practices:\n" + detail_text
			# Reject something that should be flagged
			["reject", "flag"]:
				score -= 25
				explanation = "❌ Too strict! This has issues but shouldn't be fully rejected.\n\nSecurity Concerns:\n" + detail_text
	
	_update_progress_label()
	_show_feedback(correct, explanation)

func _show_feedback(correct: bool, message: String) -> void:
	if not feedback_overlay or not feedback_popup:
		return
	
	feedback_overlay.visible = true
	
	if correct:
		if feedback_icon:
			feedback_icon.text = "✓"
			feedback_icon.add_theme_color_override("font_color", Color(0, 0.8, 0))
		if feedback_message:
			feedback_message.text = message
			feedback_message.add_theme_color_override("font_color", Color(0, 0.6, 0))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.8, 1, 0.8)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(0, 0.6, 0)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		feedback_popup.add_theme_stylebox_override("panel", style)
	else:
		if feedback_icon:
			feedback_icon.text = "✗"
			feedback_icon.add_theme_color_override("font_color", Color(0.8, 0, 0))
		if feedback_message:
			feedback_message.text = message
			feedback_message.add_theme_color_override("font_color", Color(0.6, 0, 0))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 0.8, 0.8)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(0.8, 0, 0)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		feedback_popup.add_theme_stylebox_override("panel", style)

func _on_ok_pressed() -> void:
	if feedback_overlay:
		feedback_overlay.visible = false
	
	if scenarios_reviewed >= total_emails:
		_show_final_results()
	else:
		_show_email(current_email_index + 1)

func _update_timer_display() -> void:
	if not timer_label:
		return
	
	var seconds = int(time_remaining)
	timer_label.text = "⏱ %ds" % seconds
	
	if time_remaining > 60:
		timer_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
	elif time_remaining > 30:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0, 0))

func _update_progress_label() -> void:
	if progress_label:
		progress_label.text = "� %d/%d | Score: %d" % [emails_analyzed, total_emails, score]

func _calculate_xp(final_score: int, max_possible_score: int) -> int:
	"""
	Calculate XP based on performance
	XP Range: 100-200 based on percentage score
	"""
	var percentage = (float(final_score) / max_possible_score) * 100.0 if final_score > 0 else 0.0
	percentage = clamp(percentage, 0.0, 100.0)
	
	# Linear scale from 100 XP (0%) to 200 XP (100%)
	var xp = int(100 + (percentage / 100.0) * 100)
	return clamp(xp, 100, 200)

func _show_final_results() -> void:
	var percentage = (float(score) / max_score) * 100.0 if score > 0 else 0.0
	percentage = clamp(percentage, 0.0, 100.0)
	var grade = "F"
	
	if percentage >= 90:
		grade = "A"
	elif percentage >= 80:
		grade = "B"
	elif percentage >= 70:
		grade = "C"
	elif percentage >= 60:
		grade = "D"
	
	var xp_earned = _calculate_xp(score, max_score)
	var passed = percentage >= 70.0
	var status_emoji = "🎉" if passed else "📚"
	var status_text = "PASSED!" if passed else "NEEDS IMPROVEMENT"
	
	var message = """🔐 ENCRYPTION AUDIT COMPLETE!

Final Score: %d / %d points
Accuracy: %.1f%%
Grade: %s

💎 XP Earned: %d XP

%s %s

%s

Click OK to return to menu.""" % [
		score,
		max_score,
		percentage,
		grade,
		xp_earned,
		status_emoji,
		status_text,
		"EXCELLENT! You're an encryption audit expert!" if grade == "A" else
		"GOOD JOB! Keep studying DES, Triple DES, and AES!" if grade in ["B", "C"] else
		"Review the encryption standards and try again!"
	]
	
	if feedback_icon:
		if passed:
			feedback_icon.text = "🎉"
			feedback_icon.add_theme_color_override("font_color", Color(0, 0.8, 0))
		else:
			feedback_icon.text = "📚"
			feedback_icon.add_theme_color_override("font_color", Color(1, 0.6, 0))
	
	if feedback_message:
		feedback_message.text = message
		feedback_message.add_theme_color_override("font_color", Color.BLACK)
	
	if feedback_overlay:
		feedback_overlay.visible = true
	
	# Style the popup based on pass/fail
	var style = StyleBoxFlat.new()
	if passed:
		style.bg_color = Color(0.9, 1, 0.9)
		style.border_color = Color(0, 0.8, 0)
	else:
		style.bg_color = Color(1, 0.95, 0.8)
		style.border_color = Color(1, 0.6, 0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	feedback_popup.add_theme_stylebox_override("panel", style)
	
	# Check first-time before saving
	var _first_clear: bool = MinigameRewards.is_first_completion(TUTORIAL_ID)
	print("📊 Saving tutorial results...")
	print("   Tutorial ID: %s" % TUTORIAL_ID)
	print("   Score: %d / %d" % [score, max_score])
	print("   Percentage: %.1f%%" % percentage)
	print("   XP Earned: %d" % xp_earned)
	print("   Passed: %s" % passed)
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.save_tutorial_result(TUTORIAL_ID, score, max_score)
		if tutorial_mgr.has_signal("save_completed"):
			await tutorial_mgr.save_completed
			print("✅ Tutorial results saved successfully!")
	else:
		push_error("❌ TutorialManager not found!")
	
	# Show reward popup on first completion
	if _first_clear and not _is_gamemode:
		MinigameRewards.try_grant_rewards(TUTORIAL_ID, score, xp_earned, self)
	
	# In GameMode, submit score and go to leaderboard
	if _is_gamemode:
		# Reconnect OK button to submit
		if ok_button and ok_button.pressed.is_connected(_on_ok_pressed):
			ok_button.pressed.disconnect(_on_ok_pressed)
		if ok_button:
			ok_button.pressed.connect(func(): _submit_gamemode_score(score, max_score))
		return
	
	# Reconnect OK button to return to menu
	if ok_button and ok_button.pressed.is_connected(_on_ok_pressed):
		ok_button.pressed.disconnect(_on_ok_pressed)
	if ok_button:
		ok_button.pressed.connect(_on_back_pressed)

func _on_time_expired() -> void:
	time_remaining = 0
	if timer_label:
		timer_label.text = "⏱ 0s"
	if reply_button:
		reply_button.disabled = true
	if spam_button:
		spam_button.disabled = true
	if delete_button:
		delete_button.disabled = true
	
	# Show final results when time expires
	_show_final_results()

func _on_back_pressed() -> void:
	if _is_gamemode:
		return
	get_tree().change_scene_to_file("res://scene/phishing_intro.tscn")


# ============================================
# GAMEMODE MULTIPLAYER
# ============================================

func _submit_gamemode_score(final_score: int, final_max_score: int) -> void:
	var time_taken_ms := Time.get_ticks_msec() - _gamemode_start_time_ms
	var url := _gamemode_lobby_url + "/api/gamemode/%s/submit" % _gamemode_room_code
	var body := JSON.stringify({
		"player_id": Auth.current_local_id,
		"score": final_score,
		"max_score": final_max_score,
		"time_taken_ms": time_taken_ms
	})

	if ok_button:
		ok_button.disabled = true
		ok_button.text = "Submitting..."

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		print("[GameMode] Encryption Audit score submitted: %d/%d (time: %dms) → status %d" % [final_score, final_max_score, time_taken_ms, code])
		_go_to_leaderboard()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func _go_to_leaderboard() -> void:
	get_tree().set_meta("gamemode_leaderboard_room_code", _gamemode_room_code)
	get_tree().set_meta("gamemode_leaderboard_lobby_url", _gamemode_lobby_url)
	get_tree().change_scene_to_file("res://scene/gamemode_leaderboard.tscn")