extends Panel

signal decision_made(action, scenario)

@onready var user_name_label = $VBox/Header/UserName
@onready var role_label = $VBox/Header/Role
@onready var auth_label = $VBox/AuthSection/AuthLevel
@onready var location_label = $VBox/Context/Location
@onready var device_label = $VBox/Context/Device
@onready var time_label = $VBox/Context/Time
@onready var resource_label = $VBox/RequestSection/Resource
@onready var risk_label = $VBox/RequestSection/Risk
@onready var warnings_container = $VBox/Warnings
@onready var warnings_label = $VBox/Warnings/WarningText

@onready var grant_button = $VBox/Actions/GrantButton
@onready var deny_button = $VBox/Actions/DenyButton
@onready var mfa_button = $VBox/Actions/MFAButton

@onready var timer_label = $VBox/Header/Timer
@onready var timer = $DecisionTimer

var current_scenario: Scenario

func setup(scenario: Scenario):
	current_scenario = scenario
	
	# User info
	user_name_label.text = scenario.user_name
	role_label.text = scenario.user_role.to_upper()
	role_label.modulate = scenario.role_color
	
	# Authentication
	var auth_stars = ""
	for i in range(scenario.auth_level):
		auth_stars += "⭐"
	var auth_text = ""
	match scenario.auth_level:
		1:
			auth_text = "Password Only"
		2:
			auth_text = "Password + MFA"
		3:
			auth_text = "Hardware Token"
	
	if not scenario.auth_passed:
		auth_text += " (MFA FAILED)"
		auth_label.modulate = Color.RED
	else:
		auth_label.modulate = Color.WHITE
	
	auth_label.text = auth_text + " " + auth_stars
	
	# Context
	location_label.text = "📍 " + scenario.location
	device_label.text = "💻 " + scenario.device
	time_label.text = "🕐 " + scenario.time
	
	# Resource request
	resource_label.text = "📊 " + scenario.requested_resource
	
	match scenario.risk_level:
		"low":
			risk_label.text = "Risk: 🟢 LOW"
			risk_label.modulate = Color.GREEN
		"medium":
			risk_label.text = "Risk: 🟡 MEDIUM"
			risk_label.modulate = Color.YELLOW
		"high":
			risk_label.text = "Risk: 🔴 HIGH"
			risk_label.modulate = Color.ORANGE
		"critical":
			risk_label.text = "Risk: 🔴 CRITICAL"
			risk_label.modulate = Color.RED
	
	# Warnings
	if scenario.context_flags.size() > 0:
		warnings_container.visible = true
		var warning_text = "⚠️ WARNINGS:\n"
		for flag in scenario.context_flags:
			warning_text += "• " + _format_flag(flag) + "\n"
		warnings_label.text = warning_text
	else:
		warnings_container.visible = false
	
	# Start timer
	timer.wait_time = scenario.time_limit
	timer.start()
	
	# Enable buttons
	_enable_buttons(true)

func _format_flag(flag: String) -> String:
	match flag:
		"unusual_time":
			return "Unusual login time"
		"new_device":
			return "New/unknown device"
		"public_network":
			return "Public WiFi network"
		"personal_device":
			return "Personal device (not company-issued)"
		"wrong_location":
			return "Unexpected geographic location"
		"mfa_failed":
			return "MFA challenge FAILED"
		"contract_expired":
			return "Contract expired"
		"wrong_department":
			return "Request outside user's department"
		"unusual_request":
			return "Unusual request for this user"
		"large_download":
			return "Large data download"
		"privilege_escalation":
			return "Requesting elevated privileges"
		"social_engineering":
			return "Claimed 'urgent CEO request'"
		"destructive_action":
			return "Destructive action requested"
		"unapproved_software":
			return "Software not in approved list"
		"unknown_device":
			return "Device not in system records"
		_:
			return flag.capitalize()

func _process(_delta):
	if timer.time_left > 0:
		timer_label.text = "Time: %.1f s" % timer.time_left
		
		# Color code timer
		if timer.time_left < 5:
			timer_label.modulate = Color.RED
		elif timer.time_left < 10:
			timer_label.modulate = Color.YELLOW
		else:
			timer_label.modulate = Color.WHITE

func _on_grant_button_pressed():
	_make_decision("grant")

func _on_deny_button_pressed():
	_make_decision("deny")

func _on_mfa_button_pressed():
	_make_decision("require_mfa")

func _make_decision(action: String):
	timer.stop()
	_enable_buttons(false)
	emit_signal("decision_made", action, current_scenario)

func _enable_buttons(enabled: bool):
	grant_button.disabled = not enabled
	deny_button.disabled = not enabled
	mfa_button.disabled = not enabled

func _on_decision_timer_timeout():
	# Auto-deny on timeout
	_make_decision("timeout")