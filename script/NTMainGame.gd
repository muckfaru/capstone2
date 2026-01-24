extends Control

# Game State
enum GameMode { TUTORIAL, LEVEL_1, LEVEL_2, LEVEL_3, LEVEL_4 }
var current_mode = GameMode.TUTORIAL
var tutorial_step = 0
var tutorial_active = true

# Metrics
var security_level: float = 100.0
var availability_level: float = 100.0
var requests_processed: int = 0
var total_requests: int = 8  # Tutorial starts with 8
var threats_blocked: int = 0
var total_threats: int = 0
var services_maintained: int = 0
var total_services: int = 0

# Current Traffic
var current_traffic = null
var traffic_queue = []

# Pattern Tracking
var ip_tracker = {}  # Track requests from same IP
var pattern_warnings = []

# Node References
@onready var security_bar = $HUD/TopPanel/SecurityMeter
@onready var availability_bar = $HUD/TopPanel/AvailabilityMeter
@onready var request_label = $HUD/TopPanel/RequestCounter
@onready var activity_log = $HUD/ActivityLog
@onready var traffic_panel = $TrafficDisplay
@onready var source_label = $TrafficDisplay/Content/SourceLabel
@onready var destination_label = $TrafficDisplay/Content/DestinationLabel
@onready var protocol_label = $TrafficDisplay/Content/ProtocolLabel
@onready var behavior_label = $TrafficDisplay/Content/BehaviorLabel
@onready var auth_label = $TrafficDisplay/Content/AuthLabel
@onready var allow_button = $TrafficDisplay/Buttons/AllowButton
@onready var deny_button = $TrafficDisplay/Buttons/DenyButton
@onready var tutorial_panel = $TutorialPanel
@onready var tutorial_text = $TutorialPanel/TutorialText
@onready var tutorial_continue = $TutorialPanel/ContinueButton
@onready var alert_panel = $AlertPanel
@onready var alert_text = $AlertPanel/AlertText
@onready var end_report = $EndReport
@onready var level_select = $LevelSelect

func _ready():
	_setup_ui()
	_show_level_select()

func _setup_ui():
	# Connect buttons
	allow_button.pressed.connect(_on_allow_pressed)
	deny_button.pressed.connect(_on_deny_pressed)
	tutorial_continue.pressed.connect(_on_tutorial_continue)
	$AlertPanel/CloseButton.pressed.connect(_hide_alert)
	$EndReport/RestartButton.pressed.connect(_restart_level)
	$EndReport/MenuButton.pressed.connect(_show_level_select)
	
	# Level select buttons
	$LevelSelect/VBox/TutorialButton.pressed.connect(func(): _start_level(GameMode.TUTORIAL))
	$LevelSelect/VBox/Level1Button.pressed.connect(func(): _start_level(GameMode.LEVEL_1))
	$LevelSelect/VBox/Level2Button.pressed.connect(func(): _start_level(GameMode.LEVEL_2))
	$LevelSelect/VBox/Level3Button.pressed.connect(func(): _start_level(GameMode.LEVEL_3))
	$LevelSelect/VBox/Level4Button.pressed.connect(func(): _start_level(GameMode.LEVEL_4))
	
	# Hide panels initially
	tutorial_panel.hide()
	alert_panel.hide()
	end_report.hide()
	traffic_panel.hide()

func _show_level_select():
	level_select.show()
	traffic_panel.hide()
	end_report.hide()
	$HUD.hide()

func _start_level(mode: GameMode):
	current_mode = mode
	level_select.hide()
	$HUD.show()
	traffic_panel.show()
	
	# Reset game state
	security_level = 100.0
	availability_level = 100.0
	requests_processed = 0
	threats_blocked = 0
	total_threats = 0
	services_maintained = 0
	total_services = 0
	ip_tracker.clear()
	pattern_warnings.clear()
	activity_log.text = ""
	
	# Configure level
	match mode:
		GameMode.TUTORIAL:
			tutorial_active = true
			tutorial_step = 0
			total_requests = 8
			_generate_tutorial_traffic()
		GameMode.LEVEL_1:
			tutorial_active = false
			total_requests = 30
			_generate_level_traffic(0.8, 0.05, 0.10, 0.05)
		GameMode.LEVEL_2:
			tutorial_active = false
			total_requests = 50
			_generate_level_traffic(0.6, 0.15, 0.15, 0.10)
		GameMode.LEVEL_3:
			tutorial_active = false
			total_requests = 60
			_generate_level_traffic(0.5, 0.20, 0.20, 0.10)
		GameMode.LEVEL_4:
			tutorial_active = false
			total_requests = 75
			_generate_level_traffic(0.4, 0.25, 0.25, 0.10)
	
	_update_ui()
	_load_next_traffic()

func _generate_tutorial_traffic():
	traffic_queue.clear()
	
	# Tutorial Step 1: Obviously legitimate
	traffic_queue.append({
		"source": "Internal-10.0.1.45",
		"destination": "Email Server (Port 25)",
		"protocol": "SMTP",
		"behavior": "Normal frequency",
		"auth": "Authenticated user",
		"is_malicious": false,
		"threat_level": 0,
		"service_impact": 15,
		"explanation": "This is normal business traffic. Internal source, standard email protocol, authenticated.",
		"hint": "✓ Internal source + Standard protocol = SAFE"
	})
	
	# Tutorial Step 2: Obviously malicious
	traffic_queue.append({
		"source": "External-203.45.67.89 (Russia)",
		"destination": "Admin Panel (Port 22)",
		"protocol": "SSH - Multiple failed logins",
		"behavior": "Brute force pattern",
		"auth": "Failed authentication (15 attempts)",
		"is_malicious": true,
		"threat_level": 15,
		"service_impact": 0,
		"explanation": "This is a brute force attack. External source trying to break into admin access.",
		"hint": "⚠ External + Failed logins + Admin panel = BLOCK"
	})
	
	# Tutorial Step 3: Legitimate external
	traffic_queue.append({
		"source": "External-52.10.34.12 (AWS)",
		"destination": "Web Server (Port 443)",
		"protocol": "HTTPS",
		"behavior": "Normal frequency",
		"auth": "Valid SSL certificate",
		"is_malicious": false,
		"threat_level": 0,
		"service_impact": 20,
		"explanation": "This is a legitimate customer accessing your website. External doesn't always mean bad!",
		"hint": "? External source, but accessing public web server normally"
	})
	
	# Tutorial Step 4: Reconnaissance scan
	traffic_queue.append({
		"source": "External-198.22.45.78",
		"destination": "Multiple ports scanned",
		"protocol": "TCP SYN packets",
		"behavior": "Port scanning detected",
		"auth": "No authentication",
		"is_malicious": true,
		"threat_level": 10,
		"service_impact": 0,
		"explanation": "Port scanning is reconnaissance - attackers probing for vulnerabilities.",
		"hint": "⚠ Port scanning = Reconnaissance attack"
	})
	
	# Tutorial Step 5: Suspicious timing but legitimate
	traffic_queue.append({
		"source": "Internal-10.0.3.22 (IT Admin)",
		"destination": "Database Server (Port 3306)",
		"protocol": "MySQL",
		"behavior": "Unusual timing (3:15 AM)",
		"auth": "Valid admin credentials",
		"is_malicious": false,
		"threat_level": 0,
		"service_impact": 18,
		"explanation": "This looks suspicious (3 AM), but it's a scheduled backup. Context matters!",
		"hint": "? Unusual timing, but IT admin with valid credentials"
	})
	
	# Tutorial Step 6: Insider threat
	traffic_queue.append({
		"source": "Internal-10.0.2.88 (Finance Dept)",
		"destination": "External - Dropbox.com",
		"protocol": "HTTPS",
		"behavior": "Large file upload (2.3 GB)",
		"auth": "Authenticated user",
		"is_malicious": true,
		"threat_level": 18,
		"service_impact": 5,
		"explanation": "Data exfiltration! Employee uploading huge files to personal cloud = policy violation.",
		"hint": "⚠ Internal + Large upload to external = Data theft risk"
	})
	
	# Tutorial Step 7: Malware callback
	traffic_queue.append({
		"source": "Internal-10.0.4.15",
		"destination": "External-185.34.22.90 (Unknown)",
		"protocol": "HTTPS (encrypted)",
		"behavior": "Periodic callbacks (every 60s)",
		"auth": "No authentication required",
		"is_malicious": true,
		"threat_level": 20,
		"service_impact": 3,
		"explanation": "Malware command & control traffic. Infected machine calling home for instructions.",
		"hint": "⚠ Periodic callbacks to unknown external IP = Malware C2"
	})
	
	# Tutorial Step 8: Normal VPN
	traffic_queue.append({
		"source": "External-74.125.88.45 (Remote Worker)",
		"destination": "VPN Gateway (Port 1194)",
		"protocol": "OpenVPN",
		"behavior": "Normal frequency",
		"auth": "Valid VPN certificate",
		"is_malicious": false,
		"threat_level": 0,
		"service_impact": 20,
		"explanation": "Remote employee connecting via VPN. This is expected business traffic.",
		"hint": "✓ VPN connection with valid certificate = Legitimate remote access"
	})

func _generate_level_traffic(normal_pct: float, recon_pct: float, attack_pct: float, insider_pct: float):
	traffic_queue.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(total_requests):
		var roll = rng.randf()
		var traffic = {}
		
		if roll < normal_pct:
			traffic = _create_normal_traffic(rng)
		elif roll < normal_pct + recon_pct:
			traffic = _create_recon_traffic(rng)
		elif roll < normal_pct + recon_pct + attack_pct:
			traffic = _create_attack_traffic(rng)
		else:
			traffic = _create_insider_traffic(rng)
		
		traffic_queue.append(traffic)
	
	# Shuffle to randomize order
	traffic_queue.shuffle()

func _create_normal_traffic(rng: RandomNumberGenerator) -> Dictionary:
	var templates = [
		{
			"source": "Internal-10.0.%d.%d" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "Email Server (Port 25)",
			"protocol": "SMTP",
			"behavior": "Normal frequency",
			"auth": "Authenticated user",
			"is_malicious": false,
			"service_impact": 15
		},
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(50, 200), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Web Server (Port 443)",
			"protocol": "HTTPS",
			"behavior": "Normal frequency",
			"auth": "Valid SSL certificate",
			"is_malicious": false,
			"service_impact": 18
		},
		{
			"source": "Internal-10.0.%d.%d" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "File Server (Port 445)",
			"protocol": "SMB",
			"behavior": "Normal frequency",
			"auth": "Domain authenticated",
			"is_malicious": false,
			"service_impact": 12
		},
		{
			"source": "External-%d.%d.%d.%d (CDN)" % [rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Web Server (Port 443)",
			"protocol": "HTTPS",
			"behavior": "API requests",
			"auth": "Valid API key",
			"is_malicious": false,
			"service_impact": 20
		}
	]
	
	var traffic = templates[rng.randi_range(0, templates.size() - 1)].duplicate()
	traffic["threat_level"] = 0
	return traffic

func _create_recon_traffic(rng: RandomNumberGenerator) -> Dictionary:
	var templates = [
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(180, 220), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Multiple ports scanned",
			"protocol": "TCP SYN packets",
			"behavior": "Port scanning detected",
			"auth": "No authentication",
			"is_malicious": true,
			"threat_level": 10,
			"service_impact": 2
		},
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(100, 150), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "DNS Server",
			"protocol": "DNS",
			"behavior": "Zone transfer attempt",
			"auth": "Unauthorized",
			"is_malicious": true,
			"threat_level": 12,
			"service_impact": 1
		},
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(50, 99), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Web Server",
			"protocol": "HTTP",
			"behavior": "Directory enumeration",
			"auth": "No authentication",
			"is_malicious": true,
			"threat_level": 8,
			"service_impact": 3
		}
	]
	
	var traffic = templates[rng.randi_range(0, templates.size() - 1)].duplicate()
	total_threats += 1
	return traffic

func _create_attack_traffic(rng: RandomNumberGenerator) -> Dictionary:
	var templates = [
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(150, 220), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Web Server (Port 443)",
			"protocol": "HTTPS",
			"behavior": "SQL injection attempts",
			"auth": "No authentication",
			"is_malicious": true,
			"threat_level": 18,
			"service_impact": 2
		},
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(80, 120), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Admin Panel (Port 22)",
			"protocol": "SSH",
			"behavior": "Brute force (50+ attempts)",
			"auth": "Failed authentication",
			"is_malicious": true,
			"threat_level": 20,
			"service_impact": 1
		},
		{
			"source": "Internal-10.0.%d.%d" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "External-%d.%d.%d.%d (Unknown)" % [rng.randi_range(180, 220), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"protocol": "HTTPS (encrypted)",
			"behavior": "Periodic callbacks (every 60s)",
			"auth": "No authentication",
			"is_malicious": true,
			"threat_level": 22,
			"service_impact": 3
		},
		{
			"source": "External-%d.%d.%d.%d" % [rng.randi_range(1, 50), rng.randi_range(1, 255), rng.randi_range(1, 255), rng.randi_range(1, 255)],
			"destination": "Web Server",
			"protocol": "HTTP",
			"behavior": "DDoS pattern (1000+ req/sec)",
			"auth": "No authentication",
			"is_malicious": true,
			"threat_level": 15,
			"service_impact": 5
		}
	]
	
	var traffic = templates[rng.randi_range(0, templates.size() - 1)].duplicate()
	total_threats += 1
	return traffic

func _create_insider_traffic(rng: RandomNumberGenerator) -> Dictionary:
	var templates = [
		{
			"source": "Internal-10.0.%d.%d (HR Dept)" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "External - Google Drive",
			"protocol": "HTTPS",
			"behavior": "Large file upload (1.8 GB)",
			"auth": "Authenticated user",
			"is_malicious": true,
			"threat_level": 18,
			"service_impact": 8
		},
		{
			"source": "Internal-10.0.%d.%d (Admin)" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "Database Server",
			"protocol": "MySQL",
			"behavior": "Unusual timing (2:30 AM)",
			"auth": "Valid admin credentials",
			"is_malicious": false,
			"threat_level": 0,
			"service_impact": 15
		},
		{
			"source": "Internal-10.0.%d.%d" % [rng.randi_range(1, 5), rng.randi_range(10, 250)],
			"destination": "External - Pastebin.com",
			"protocol": "HTTPS",
			"behavior": "Code repository upload",
			"auth": "Authenticated user",
			"is_malicious": true,
			"threat_level": 16,
			"service_impact": 5
		}
	]
	
	var traffic = templates[rng.randi_range(0, templates.size() - 1)].duplicate()
	if traffic.is_malicious:
		total_threats += 1
	else:
		total_services += 1
	return traffic

func _load_next_traffic():
	if traffic_queue.is_empty():
		_end_level()
		return
	
	current_traffic = traffic_queue.pop_front()
	
	# Track traffic count if not malicious (for service metrics)
	if not current_traffic.is_malicious:
		total_services += 1
	
	# Display traffic
	source_label.text = "SOURCE: " + current_traffic.source
	destination_label.text = "DESTINATION: " + current_traffic.destination
	protocol_label.text = "PROTOCOL: " + current_traffic.protocol
	behavior_label.text = "BEHAVIOR: " + current_traffic.behavior
	auth_label.text = "AUTH: " + current_traffic.auth
	
	# Show tutorial if active
	if tutorial_active and tutorial_step < 8:
		_show_tutorial_hint()

func _show_tutorial_hint():
	allow_button.disabled = true
	deny_button.disabled = true
	tutorial_panel.show()
	
	var hint = current_traffic.get("hint", "")
	tutorial_text.text = hint

func _on_tutorial_continue():
	tutorial_panel.hide()
	allow_button.disabled = false
	deny_button.disabled = false

func _on_allow_pressed():
	_process_decision(true)

func _on_deny_pressed():
	_process_decision(false)

func _process_decision(allowed: bool):
	requests_processed += 1
	
	var correct = false
	var feedback = ""
	
	if allowed:
		# Player chose to ALLOW
		if current_traffic.is_malicious:
			# Bad decision - allowed threat
			security_level -= current_traffic.threat_level
			security_level = max(0, security_level)
			feedback = "⚠ THREAT ALLOWED: " + current_traffic.get("destination", "Unknown target")
			_add_log(feedback, Color.RED)
			
			if tutorial_active:
				_show_alert("INCORRECT: This was malicious traffic!\n\n" + current_traffic.get("explanation", ""))
		else:
			# Good decision - allowed legitimate
			availability_level = min(100, availability_level + 2)
			correct = true
			services_maintained += 1
			feedback = "✓ Service maintained: " + current_traffic.get("protocol", "")
			_add_log(feedback, Color.GREEN)
			
			if tutorial_active:
				_show_alert("CORRECT: This was legitimate traffic.\n\n" + current_traffic.get("explanation", ""))
	else:
		# Player chose to DENY
		if current_traffic.is_malicious:
			# Good decision - blocked threat
			security_level = min(100, security_level + 2)
			correct = true
			threats_blocked += 1
			feedback = "✓ Threat blocked: " + current_traffic.get("protocol", "")
			_add_log(feedback, Color.GREEN)
			
			if tutorial_active:
				_show_alert("CORRECT: You blocked a threat!\n\n" + current_traffic.get("explanation", ""))
		else:
			# Bad decision - blocked legitimate
			availability_level -= current_traffic.service_impact
			availability_level = max(0, availability_level)
			feedback = "⚠ SERVICE DISRUPTED: " + current_traffic.get("destination", "")
			_add_log(feedback, Color.ORANGE)
			
			if tutorial_active:
				_show_alert("INCORRECT: This was legitimate traffic.\n\n" + current_traffic.get("explanation", ""))
	
	_update_ui()
	
	# Check for game over
	if security_level <= 0:
		_trigger_game_over("SECURITY BREACH", "Security dropped to 0%. Network compromised!")
		return
	
	if availability_level <= 0:
		_trigger_game_over("BUSINESS SHUTDOWN", "Availability dropped to 0%. All services offline!")
		return
	
	# Continue to next traffic (with delay in tutorial)
	if tutorial_active:
		tutorial_step += 1
		await get_tree().create_timer(0.5).timeout
	
	_load_next_traffic()

func _add_log(message: String, color: Color):
	var color_hex = color.to_html(false)
	activity_log.text += "[color=#" + color_hex + "]• " + message + "[/color]\n"
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	activity_log.scroll_to_line(activity_log.get_line_count())

func _update_ui():
	security_bar.value = security_level
	availability_bar.value = availability_level
	request_label.text = "Requests: %d / %d" % [requests_processed, total_requests]
	
	# Color code the meters
	if security_level < 30:
		security_bar.modulate = Color.RED
	elif security_level < 60:
		security_bar.modulate = Color.ORANGE
	else:
		security_bar.modulate = Color.GREEN
	
	if availability_level < 30:
		availability_bar.modulate = Color.RED
	elif availability_level < 60:
		availability_bar.modulate = Color.ORANGE
	else:
		availability_bar.modulate = Color.GREEN

func _show_alert(message: String):
	alert_text.text = message
	alert_panel.show()

func _hide_alert():
	alert_panel.hide()

func _trigger_game_over(title: String, message: String):
	_show_end_report(title, message)

func _end_level():
	var grade = _calculate_grade()
	var title = "SHIFT COMPLETE"
	var message = _generate_report(grade)
	_show_end_report(title, message)

func _calculate_grade() -> String:
	var threat_pct = 0.0
	if total_threats > 0:
		threat_pct = float(threats_blocked) / float(total_threats)
	
	var service_pct = 0.0
	if total_services > 0:
		service_pct = float(services_maintained) / float(total_services)
	
	var avg_score = (threat_pct + service_pct) / 2.0 * 100.0
	
	if avg_score >= 90:
		return "A"
	elif avg_score >= 80:
		return "B"
	elif avg_score >= 70:
		return "C"
	elif avg_score >= 60:
		return "D"
	else:
		return "F"

func _generate_report(grade: String) -> String:
	var report = "════════════════════════════════\n"
	report += "    SHIFT PERFORMANCE REPORT\n"
	report += "════════════════════════════════\n\n"
	report += "Final Security:      %.0f%%\n" % security_level
	report += "Final Availability:  %.0f%%\n\n" % availability_level
	report += "Threats Blocked:     %d / %d (%.0f%%)\n" % [threats_blocked, total_threats, (float(threats_blocked) / max(1, total_threats)) * 100]
	report += "Services Maintained: %d / %d (%.0f%%)\n\n" % [services_maintained, total_services, (float(services_maintained) / max(1, total_services)) * 100]
	report += "Grade: %s\n\n" % grade
	
	if security_level <= 0:
		report += "CRITICAL FAILURE:\nNetwork security compromised.\nMultiple breaches detected.\n"
	elif availability_level <= 0:
		report += "CRITICAL FAILURE:\nAll services offline.\nBusiness operations halted.\n"
	elif grade == "A":
		report += "Excellent work! You maintained\nboth security and availability.\n"
	elif grade == "B":
		report += "Good performance. Review the\ntraffic you allowed or blocked.\n"
	elif grade == "C":
		report += "Passing, but improvement needed.\nPractice pattern recognition.\n"
	else:
		report += "Additional training recommended.\nFocus on decision-making skills.\n"
	
	return report

func _show_end_report(title: String, message: String):
	traffic_panel.hide()
	$EndReport/TitleLabel.text = title
	$EndReport/ReportText.text = message
	end_report.show()

func _restart_level():
	end_report.hide()
	_start_level(current_mode)