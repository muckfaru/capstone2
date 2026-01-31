extends Panel

signal decision_made(action: String, scenario: Scenario)

const DECISION_TIME = 20.0

var current_scenario: Scenario
var time_remaining: float = DECISION_TIME

@onready var user_name_label = $VBox/Header/UserName
@onready var role_label = $VBox/Header/Role
@onready var timer_label = $VBox/Header/Timer
@onready var auth_level_label = $VBox/AuthSection/AuthLevel
@onready var location_label = $VBox/Context/Location
@onready var device_label = $VBox/Context/Device
@onready var time_label = $VBox/Context/Time
@onready var resource_label = $VBox/RequestSection/Resource
@onready var risk_label = $VBox/RequestSection/Risk
@onready var warnings_container = $VBox/Warnings
@onready var warning_text = $VBox/Warnings/WarningText
@onready var drop_zone = $VBox/DropZoneSection/DropZone
@onready var confirm_button = $VBox/ConfirmButton
@onready var hint_label = $VBox/HintLabel
@onready var decision_timer = $DecisionTimer

# Optional: If you have a separate label on the confirm button
@onready var confirm_label = $VBox/ConfirmButton/Label  # Adjust path if different

func _ready():
	add_to_group("request_card")
	confirm_button.visible = false
	
	# Optional: Hide the button's built-in text since you have a label
	confirm_button.text = ""

func setup(scenario: Scenario):
	print("\n" + "=".repeat(50))
	print("RequestCard: SETUP NEW SCENARIO")
	print("=".repeat(50))
	
	current_scenario = scenario
	time_remaining = scenario.time_limit
	
	# STEP 1: Reset EVERYTHING first
	print("RequestCard: Step 1 - Resetting UI...")
	_reset_ui()
	
	# STEP 2: Populate data
	print("RequestCard: Step 2 - Populating data...")
	user_name_label.text = scenario.user_name
	role_label.text = scenario.user_role.to_upper()
	role_label.modulate = scenario.role_color
	
	var auth_stars = ""
	var auth_display = ""
	
	match scenario.auth_level:
		1:
			auth_stars = "⭐"
			auth_display = "Password Only"
		2:
			auth_stars = "⭐⭐"
			auth_display = "Two-Factor Auth"
		3:
			auth_stars = "⭐⭐⭐"
			auth_display = "Hardware Token MFA"
		_:
			auth_stars = "⭐"
			auth_display = "Unknown"
	
	# Handle authentication status display
	if not scenario.auth_passed:
		# If auth_level_label is a RichTextLabel
		if auth_level_label is RichTextLabel:
			auth_level_label.text = "Authentication: " + auth_display + " " + auth_stars + " [color=red](FAILED)[/color]"
		# If auth_level_label is a regular Label
		else:
			auth_level_label.text = "Authentication: " + auth_display + " " + auth_stars + " (FAILED)"
			auth_level_label.modulate = Color.RED
	else:
		auth_level_label.text = "Authentication: " + auth_display + " " + auth_stars
		auth_level_label.modulate = Color.WHITE
	
	location_label.text = "📍 " + scenario.location
	device_label.text = "💻 " + scenario.device
	time_label.text = "🕐 " + scenario.time
	resource_label.text = "📊 " + scenario.requested_resource
	
	var risk_color = Color.WHITE
	var risk_icon = "🟢"
	match scenario.risk_level:
		"low":
			risk_color = Color.GREEN
			risk_icon = "🟢"
		"medium":
			risk_color = Color.YELLOW
			risk_icon = "🟡"
		"high":
			risk_color = Color.ORANGE
			risk_icon = "🟠"
		"critical":
			risk_color = Color.RED
			risk_icon = "🔴"
	
	risk_label.text = "Risk: " + risk_icon + " " + scenario.risk_level.to_upper()
	risk_label.modulate = risk_color
	
	if scenario.context_flags.size() > 0:
		warnings_container.visible = true
		
		# Check if warning_text is RichTextLabel or Label
		if warning_text is RichTextLabel:
			var warning_html = "[color=orange]⚠️ WARNINGS:[/color]\n"
			for flag in scenario.context_flags:
				var flag_text = _format_context_flag(flag)
				warning_html += "• " + flag_text + "\n"
			warning_text.text = warning_html
		else:
			var warning_plain = "⚠️ WARNINGS:\n"
			for flag in scenario.context_flags:
				var flag_text = _format_context_flag(flag)
				warning_plain += "• " + flag_text + "\n"
			warning_text.text = warning_plain
			warning_text.modulate = Color.ORANGE
	else:
		warnings_container.visible = false
	
	print("RequestCard: Step 3 - Starting timer...")
	decision_timer.start(scenario.time_limit)
	
	print("RequestCard: Setup complete!")
	print("=".repeat(50) + "\n")

func _reset_ui():
	"""Reset ALL UI to initial state"""
	print("  _reset_ui: Clearing drop zone...")
	drop_zone.clear_decision()
	
	print("  _reset_ui: Deselecting panels...")
	var all_panels = get_tree().get_nodes_in_group("decision_panels")
	for panel in all_panels:
		panel.deselect()
	
	print("  _reset_ui: Resetting buttons...")
	confirm_button.visible = false
	confirm_button.disabled = false
	confirm_button.scale = Vector2(1, 1)
	
	hint_label.visible = true
	hint_label.text = "💡 Click a decision panel below"
	
	drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Reset label colors
	auth_level_label.modulate = Color.WHITE
	if not (warning_text is RichTextLabel):
		warning_text.modulate = Color.WHITE

func _format_context_flag(flag: String) -> String:
	match flag:
		"public_network": return "Public/Unsecured Network"
		"personal_device": return "Personal Device (Not Company Issued)"
		"contract_expired": return "Contract Expired - Access Should Be Revoked"
		"unusual_time": return "Unusual Access Time"
		"wrong_department": return "Wrong Department for This Resource"
		"mfa_failed": return "Multi-Factor Authentication FAILED"
		"wrong_location": return "Unusual Geographic Location"
		"unknown_device": return "Unrecognized Device"
		"unusual_request": return "Unusual Resource Request"
		"large_download": return "Unusually Large Data Download"
		"privilege_escalation": return "Attempting Privilege Escalation"
		"social_engineering": return "Possible Social Engineering Attack"
		"destructive_action": return "DESTRUCTIVE ACTION - High Risk"
		"unapproved_software": return "Unapproved Software Installation"
		"wrong_network": return "Wrong Network Segment"
		_: return flag.replace("_", " ").capitalize()

func _process(_delta):
	if decision_timer.time_left > 0:
		time_remaining = decision_timer.time_left
		timer_label.text = "Time: %.1fs" % time_remaining
		
		if time_remaining < 5:
			timer_label.modulate = Color.RED
		elif time_remaining < 10:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = Color(1, 0.8, 0.3)

func _on_drop_zone_decision_dropped(action: String):
	print("RequestCard: Received decision: ", action)
	
	# Show the confirm button (with your custom texture + label)
	confirm_button.visible = true
	hint_label.visible = false
	
	# Just do the pulse animation
	var tween = create_tween()
	tween.tween_property(confirm_button, "scale", Vector2(1.05, 1.05), 0.2)
	tween.tween_property(confirm_button, "scale", Vector2(1.0, 1.0), 0.2)

func _on_confirm_button_pressed():
	var action = drop_zone.get_current_decision()
	
	if action.is_empty():
		return
	
	print("\nRequestCard: CONFIRMING: ", action, "\n")
	
	var mapped_action = action
	if action == "mfa":
		mapped_action = "require_mfa"
	
	decision_timer.stop()
	confirm_button.disabled = true
	drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var all_panels = get_tree().get_nodes_in_group("decision_panels")
	for panel in all_panels:
		panel.deselect()
	
	emit_signal("decision_made", mapped_action, current_scenario)

func _on_decision_timer_timeout():
	print("\nRequestCard: TIME EXPIRED!\n")
	emit_signal("decision_made", "timeout", current_scenario)