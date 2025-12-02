extends Control

# ============================================
# PHISHING LAB - Email Security Training
# Students identify phishing vs legitimate emails
# Critical skill: 90% of breaches start with phishing!
# ============================================

@onready var timer_label: Label = $WindowDialog/VBox/TitleBar/MarginContainer/HBox/TimerLabel
@onready var progress_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ProgressLabel
@onready var from_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/EmailPanel/MarginContainer/EmailContent/FromLabel
@onready var subject_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/EmailPanel/MarginContainer/EmailContent/SubjectLabel
@onready var body_label: Label = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/EmailPanel/MarginContainer/EmailContent/BodyScroll/BodyLabel
@onready var safe_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/SafeButton
@onready var phishing_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/ButtonContainer/PhishingButton
@onready var back_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/MainVBox/BottomButtons/BackButton
@onready var feedback_popup: PanelContainer = $DarkOverlay/FeedbackPopup
@onready var feedback_icon: Label = $DarkOverlay/FeedbackPopup/VBox/IconLabel
@onready var feedback_message: Label = $DarkOverlay/FeedbackPopup/VBox/MessageLabel
@onready var red_flags_label: Label = $DarkOverlay/FeedbackPopup/VBox/RedFlagsLabel
@onready var ok_button: Button = $DarkOverlay/FeedbackPopup/VBox/OKButton
@onready var dark_overlay: ColorRect = $DarkOverlay

# Game state
const TIME_LIMIT := 90.0
var time_remaining := TIME_LIMIT
var emails_analyzed := 0
var total_emails := 8
var current_email_index := 0
var score := 0

# Email data
var emails := [
	{
		"from": "security@paypa1-secure.tk",
		"subject": "🚨 URGENT: Verify Your Account Now!",
		"body": "Dear Customer,\n\nYour PayPal account will be SUSPENDED in 24 hours if you don't verify your identity immediately!\n\nClick here to verify: http://paypal-verify.tk/login\n\nBest regards,\nPayPal Security Team",
		"is_phishing": true,
		"red_flags": [
			"• Generic greeting ('Dear Customer')",
			"• Urgent threatening language",
			"• Fake domain (.tk instead of .com)",
			"• Typo in sender: 'paypa1' not 'paypal'",
			"• Suspicious link domain"
		]
	},
	{
		"from": "noreply@netflix.com",
		"subject": "Your Netflix receipt",
		"body": "Hi Sarah,\n\nYour $15.99 payment for Netflix Premium was processed successfully on November 29, 2025.\n\nWatch history this month:\n- Stranger Things S4\n- The Crown S6\n\nThank you for being a member!\n\nThe Netflix Team",
		"is_phishing": false,
		"legitimate_signs": [
			"• Personal greeting (uses your name)",
			"• No urgent action required",
			"• Official @netflix.com domain",
			"• Specific transaction details",
			"• No suspicious links"
		]
	},
	{
		"from": "it-support@company-email.com",
		"subject": "Password Expiration Warning",
		"body": "Your company password will expire tomorrow.\n\nPlease click this link to update your password: http://bit.ly/pwdreset2025\n\nIT Support",
		"is_phishing": true,
		"red_flags": [
			"• Suspicious shortened URL (bit.ly)",
			"• Generic 'IT Support' signature",
			"• Unexpected password reset request",
			"• No company branding or logo",
			"• Creates false urgency"
		]
	},
	{
		"from": "support@amazon.com",
		"subject": "Your Amazon.com order #402-1849302-7829103",
		"body": "Hello John,\n\nYour order has been shipped!\n\nOrder Details:\n- Wireless Mouse (Black) - $24.99\n- Delivery: Dec 2, 2025\n- Track package: [View in Amazon account]\n\nAmazon Customer Service",
		"is_phishing": false,
		"legitimate_signs": [
			"• Real Amazon order number format",
			"• Personal name used",
			"• Specific product details",
			"• No external links (directs to account)",
			"• Official @amazon.com domain"
		]
	},
	{
		"from": "prize-winner@lottery-international.org",
		"subject": "🎉 YOU'VE WON $1,000,000! Claim Now!",
		"body": "CONGRATULATIONS!\n\nYou have been selected as the WINNER of our International Lottery!\n\nPrize: $1,000,000 USD\n\nTo claim your prize, send your:\n- Full name\n- Address\n- Bank account number\n- Social security number\n\nReply within 48 hours or forfeit!",
		"is_phishing": true,
		"red_flags": [
			"• 'Too good to be true' prize",
			"• Requests sensitive information",
			"• Suspicious sender domain (.org)",
			"• High-pressure deadline",
			"• You never entered a lottery!",
			"• Requests bank/SSN info via email"
		]
	},
	{
		"from": "notifications@github.com",
		"subject": "[GitHub] Password changed successfully",
		"body": "Hi @username,\n\nYour GitHub password was changed on November 29, 2025 at 10:45 AM PST.\n\nIf you didn't make this change, please secure your account immediately:\nhttps://github.com/settings/security\n\nGitHub Security Team",
		"is_phishing": false,
		"legitimate_signs": [
			"• Official @github.com domain",
			"• Specific date/time of action",
			"• Includes your GitHub username",
			"• Legitimate security link",
			"• Standard security notification"
		]
	},
	{
		"from": "ceo@company.com",
		"subject": "URGENT: Wire Transfer Needed",
		"body": "I'm in a meeting and need you to process an urgent wire transfer immediately.\n\nAmount: $50,000\nAccount: [Bank details attached]\n\nThis is confidential. Don't discuss with anyone.\n\n- CEO",
		"is_phishing": true,
		"red_flags": [
			"• CEO Fraud / Business Email Compromise",
			"• Creates false urgency",
			"• Requests large money transfer",
			"• Orders to keep it secret",
			"• Unusual request from executive",
			"• Should verify via phone call!"
		]
	},
	{
		"from": "team@slack.com",
		"subject": "You're invited to join Engineering Team workspace",
		"body": "Hi Alex,\n\nJohn Doe invited you to join the 'Engineering Team' workspace on Slack.\n\nClick to join: https://slack.com/accept-invite/T01234/B56789\n\nWorkspace: Engineering Team (acme-corp.slack.com)\n\nThe Slack Team",
		"is_phishing": false,
		"legitimate_signs": [
			"• Official @slack.com domain",
			"• Specific workspace name shown",
			"• Legitimate Slack invite URL structure",
			"• Names who invited you",
			"• Standard Slack invite format"
		]
	}
]


func _ready() -> void:
	print("🎣 Phishing Lab Ready")
	
	# Shuffle emails for variety
	emails.shuffle()
	
	# Setup UI
	dark_overlay.visible = false
	_update_progress_label()
	
	# Show first email
	_show_email(0)
	
	# Connect OK button (not in scene file)
	ok_button.pressed.connect(_on_ok_pressed)


func _process(delta: float) -> void:
	if time_remaining > 0 and emails_analyzed < total_emails:
		time_remaining -= delta
		_update_timer_display()
		
		if time_remaining <= 0:
			_on_time_expired()


func _show_email(index: int) -> void:
	if index >= emails.size():
		return
	
	current_email_index = index
	var email = emails[index]
	
	# Update existing labels
	from_label.text = "From: " + email["from"]
	subject_label.text = "Subject: " + email["subject"]
	body_label.text = email["body"]
	
	# Enable classification buttons
	safe_button.disabled = false
	phishing_button.disabled = false


func _on_safe_pressed() -> void:
	_check_answer(false)


func _on_phishing_pressed() -> void:
	_check_answer(true)


func _on_ok_pressed() -> void:
	# Hide feedback popup
	dark_overlay.visible = false
	
	# Check if we need to move to next email or show results
	if emails_analyzed >= total_emails:
		_show_final_results()
	else:
		# Move to next email
		_show_email(current_email_index + 1)


func _check_answer(user_said_phishing: bool) -> void:
	safe_button.disabled = true
	phishing_button.disabled = true
	
	var email = emails[current_email_index]
	var correct = (user_said_phishing == email["is_phishing"])
	
	if correct:
		score += 150
		emails_analyzed += 1
		_update_progress_label()
		
		var explanation = ""
		if email["is_phishing"]:
			explanation = "🚨 CORRECT! This WAS phishing!\n\nRed Flags:\n" + "\n".join(email["red_flags"])
		else:
			explanation = "✅ CORRECT! This email was legitimate.\n\nLegitimate Signs:\n" + "\n".join(email["legitimate_signs"])
		
		_show_feedback(true, explanation)
		# OK button will advance to next email
	else:
		score -= 50
		var explanation = ""
		if email["is_phishing"]:
			explanation = "❌ WRONG! This WAS phishing!\n\nYou missed these red flags:\n" + "\n".join(email["red_flags"])
		else:
			explanation = "❌ WRONG! This was legitimate!\n\nLegitimate signs:\n" + "\n".join(email["legitimate_signs"])
		
		_show_feedback(false, explanation)
		# OK button will advance to next email


func _show_feedback(correct: bool, message: String) -> void:
	dark_overlay.visible = true
	
	if correct:
		feedback_icon.text = "✓"
		feedback_icon.add_theme_color_override("font_color", Color(0, 0.8, 0))
		feedback_message.text = message
		feedback_message.add_theme_color_override("font_color", Color(0, 0.6, 0))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.8, 1, 0.8)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(0, 0.6, 0)
		feedback_popup.add_theme_stylebox_override("panel", style)
	else:
		feedback_icon.text = "✗"
		feedback_icon.add_theme_color_override("font_color", Color(0.8, 0, 0))
		feedback_message.text = message
		feedback_message.add_theme_color_override("font_color", Color(0.6, 0, 0))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 0.8, 0.8)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(0.8, 0, 0)
		feedback_popup.add_theme_stylebox_override("panel", style)
	
	feedback_popup.scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(feedback_popup, "scale", Vector2.ONE, 0.3)


func _update_timer_display() -> void:
	var seconds = int(time_remaining)
	timer_label.text = "%ds" % seconds
	
	if time_remaining > 60:
		timer_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
	elif time_remaining > 30:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0, 0))


func _update_progress_label() -> void:
	progress_label.text = "Emails Analyzed: %d/%d | Score: %d" % [emails_analyzed, total_emails, score]


func _on_all_emails_analyzed() -> void:
	print("[Phishing Lab] All emails analyzed! Score:", score)


func _show_final_results() -> void:
	var percentage = (score * 100.0) / (total_emails * 150)  # Max: 150 per email
	var grade = "F"
	
	if percentage >= 90:
		grade = "A"
	elif percentage >= 80:
		grade = "B"
	elif percentage >= 70:
		grade = "C"
	elif percentage >= 60:
		grade = "D"
	
	var message = """🎓 PHISHING LAB COMPLETE!

Final Score: %d points
Accuracy: %.1f%%
Grade: %s

%s

Click OK to return to menu.""" % [
		score,
		percentage,
		grade,
		"EXCELLENT! You're a phishing detection expert!" if grade == "A" else
		"GOOD JOB! Keep practicing!" if grade in ["B", "C"] else
		"NEEDS IMPROVEMENT. Review the red flags!"
	]
	
	feedback_icon.text = "🎓"
	feedback_icon.add_theme_color_override("font_color", Color(0, 0.5, 1))
	feedback_message.text = message
	feedback_message.add_theme_color_override("font_color", Color.BLACK)
	red_flags_label.visible = false
	dark_overlay.visible = true
	
	# Save tutorial result
	var tutorial_mgr = get_node("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.save_tutorial_result("beginner_phishing", score, total_emails * 150)
		await tutorial_mgr.save_completed
	
	# Disconnect OK button from next email, connect to exit
	if ok_button.pressed.is_connected(_on_ok_pressed):
		ok_button.pressed.disconnect(_on_ok_pressed)
	ok_button.pressed.connect(_on_back_pressed)


func _on_time_expired() -> void:
	time_remaining = 0
	timer_label.text = "0s"
	safe_button.disabled = true
	phishing_button.disabled = true
	
	feedback_icon.text = "⏰"
	feedback_message.text = "TIME'S UP!\n\nYou analyzed %d/%d emails.\nFinal Score: %d\n\nPhishing is dangerous - take your time in real life!" % [emails_analyzed, total_emails, score]
	_show_feedback(false, "")
	
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scene/landing.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")


func _on_next_pressed() -> void:
	# Save tutorial result
	var tutorial_mgr = get_node("/root/TutorialManager")
	tutorial_mgr.save_tutorial_result("beginner_phishing", score, total_emails * 150)
	
	# Go to next tutorial
	get_tree().change_scene_to_file("res://scene/tutorial_malware_types.tscn")
