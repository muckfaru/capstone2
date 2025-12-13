extends Control

# ============================================
# PHISHING LAB - Gmail-Style Email Interface
# WITH XP TRACKING SYSTEM
# ============================================

@onready var timer_label: Label = $TopBar/HBox/TimerLabel
@onready var progress_label: Label = $TopBar/HBox/ProgressLabel
@onready var back_button: Button = $TopBar/HBox/BackButton

# Gmail header elements
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

# Action buttons (Gmail style at bottom)
@onready var reply_button: Button = $EmailViewer/VBox/ActionBar/HBox/ReplyBtn
@onready var spam_button: Button = $EmailViewer/VBox/ActionBar/HBox/SpamBtn
@onready var delete_button: Button = $EmailViewer/VBox/ActionBar/HBox/DeleteBtn

# Reply form popup
@onready var reply_overlay: ColorRect = $ReplyOverlay
@onready var reply_popup: PanelContainer = $ReplyOverlay/ReplyPopup
@onready var name_input: LineEdit = $ReplyOverlay/ReplyPopup/VBox/FormFields/VBox/NameField/Input
@onready var email_input: LineEdit = $ReplyOverlay/ReplyPopup/VBox/FormFields/VBox/EmailField/Input
@onready var address_input: LineEdit = $ReplyOverlay/ReplyPopup/VBox/FormFields/VBox/AddressField/Input
@onready var password_input: LineEdit = $ReplyOverlay/ReplyPopup/VBox/FormFields/VBox/PasswordField/Input
@onready var submit_reply_button: Button = $ReplyOverlay/ReplyPopup/VBox/ButtonContainer/SubmitButton
@onready var cancel_reply_button: Button = $ReplyOverlay/ReplyPopup/VBox/ButtonContainer/CancelButton

# Feedback popup
@onready var feedback_overlay: ColorRect = $FeedbackOverlay
@onready var feedback_popup: PanelContainer = $FeedbackOverlay/FeedbackPopup
@onready var feedback_icon: Label = $FeedbackOverlay/FeedbackPopup/VBox/IconLabel
@onready var feedback_message: Label = $FeedbackOverlay/FeedbackPopup/VBox/MessageLabel
@onready var ok_button: Button = $FeedbackOverlay/FeedbackPopup/VBox/OKButton

# Game state
const TIME_LIMIT := 90.0
const TUTORIAL_ID := "intermediate_phishing"  # Tutorial identifier for XP system
var time_remaining := TIME_LIMIT
var emails_analyzed := 0
var total_emails := 8
var current_email_index := 0
var score := 0
var max_score := 0  # Will be calculated based on total emails

# Email data with realistic Gmail formatting
var emails := [
	{
		"from_name": "PayPal Security",
		"from_email": "security@paypa1-secure.tk",
		"to": "you@yourcompany.com",
		"subject": "🚨 URGENT: Verify Your Account Now!",
		"timestamp": "9:29 PM (20 hours ago)",
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
		"from_name": "Netflix",
		"from_email": "noreply@netflix.com",
		"to": "sarah.johnson@email.com",
		"subject": "Your Netflix receipt",
		"timestamp": "Nov 29 (2 days ago)",
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
		"from_name": "IT Support",
		"from_email": "it-support@company-email.com",
		"to": "employees@company.com",
		"subject": "Password Expiration Warning",
		"timestamp": "Dec 10 (1 day ago)",
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
		"from_name": "Amazon",
		"from_email": "support@amazon.com",
		"to": "john.doe@email.com",
		"subject": "Your Amazon.com order #402-1849302-7829103",
		"timestamp": "Dec 1 (10 days ago)",
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
		"from_name": "International Lottery Commission",
		"from_email": "prize-winner@lottery-international.org",
		"to": "lucky.winner@email.com",
		"subject": "🎉 YOU'VE WON $1,000,000! Claim Now!",
		"timestamp": "Dec 9 (2 days ago)",
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
		"from_name": "GitHub",
		"from_email": "notifications@github.com",
		"to": "developer@email.com",
		"subject": "[GitHub] Password changed successfully",
		"timestamp": "Nov 29 (12 days ago)",
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
		"from_name": "CEO",
		"from_email": "ceo@company.com",
		"to": "finance@company.com",
		"subject": "URGENT: Wire Transfer Needed",
		"timestamp": "10:15 AM (3 hours ago)",
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
		"from_name": "Slack",
		"from_email": "team@slack.com",
		"to": "alex.chen@company.com",
		"subject": "You're invited to join Engineering Team workspace",
		"timestamp": "Dec 8 (3 days ago)",
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
	print("📧 Gmail-Style Phishing Lab Ready")
	
	if not _verify_nodes():
		push_error("Critical nodes missing! Check scene structure.")
		return
	
	emails.shuffle()
	
	# Calculate max possible score
	max_score = total_emails * 150  # Best action is 150 points per email
	
	reply_overlay.visible = false
	feedback_overlay.visible = false
	_update_progress_label()
	
	_show_email(0)
	
	# Connect buttons
	reply_button.pressed.connect(_on_reply_pressed)
	spam_button.pressed.connect(_on_spam_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	submit_reply_button.pressed.connect(_on_submit_reply_pressed)
	cancel_reply_button.pressed.connect(_on_cancel_reply_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	back_button.pressed.connect(_on_back_pressed)

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
	if index >= emails.size():
		return
	
	current_email_index = index
	var email = emails[index]
	
	if email_subject:
		email_subject.text = email["subject"]
	if sender_name:
		sender_name.text = email["from_name"]
	if sender_email:
		sender_email.text = "<" + email["from_email"] + ">"
	if to_me_label:
		to_me_label.text = "to me"
	if timestamp_label:
		timestamp_label.text = email["timestamp"]
	if email_body:
		email_body.text = email["body"]
	
	# Set avatar color based on sender
	if sender_avatar:
		var hash_val = email["from_name"].hash()
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

func _on_reply_pressed() -> void:
	_show_reply_form()

func _on_spam_pressed() -> void:
	_check_answer_action("spam")

func _on_delete_pressed() -> void:
	_check_answer_action("delete")

func _show_reply_form() -> void:
	if reply_overlay:
		reply_overlay.visible = true
	if name_input:
		name_input.text = ""
		name_input.grab_focus()
		name_input.text_changed.connect(_on_form_field_changed)
	if email_input:
		email_input.text = ""
		email_input.text_changed.connect(_on_form_field_changed)
	if address_input:
		address_input.text = ""
		address_input.text_changed.connect(_on_form_field_changed)
	if password_input:
		password_input.text = ""
		password_input.text_changed.connect(_on_form_field_changed)
	
	if submit_reply_button:
		submit_reply_button.disabled = true
	
	_validate_form()

func _on_submit_reply_pressed() -> void:
	var email = emails[current_email_index]
	
	if reply_overlay:
		reply_overlay.visible = false
	
	_disconnect_form_signals()
	
	if email["is_phishing"]:
		_check_answer_action("replied_with_info")
	else:
		_check_answer_action("reply")

func _on_cancel_reply_pressed() -> void:
	if reply_overlay:
		reply_overlay.visible = false
	_disconnect_form_signals()

func _check_answer_action(action: String) -> void:
	if reply_button:
		reply_button.disabled = true
	if spam_button:
		spam_button.disabled = true
	if delete_button:
		delete_button.disabled = true
	
	var email = emails[current_email_index]
	var correct = false
	var explanation = ""
	
	match action:
		"replied_with_info":
			correct = false
			score -= 100
			explanation = "⚠️ DANGER! You gave your information to a PHISHING email!\n\n"
			explanation += "Never share personal info via email reply!\n\n"
			explanation += "Red Flags you missed:\n" + "\n".join(email["red_flags"])
		
		"reply":
			if email["is_phishing"]:
				correct = false
				score -= 50
				explanation = "❌ WRONG! You replied to a PHISHING email!\n\n"
				explanation += "Red Flags:\n" + "\n".join(email["red_flags"])
			else:
				correct = true
				score += 150
				emails_analyzed += 1
				explanation = "✅ CORRECT! Safe to reply to legitimate email.\n\n"
				explanation += "Legitimate Signs:\n" + "\n".join(email["legitimate_signs"])
		
		"delete":
			if email["is_phishing"]:
				correct = true
				score += 100
				emails_analyzed += 1
				explanation = "✅ GOOD! Deleting suspicious emails is smart!\n\n"
				explanation += "Red Flags you spotted:\n" + "\n".join(email["red_flags"])
			else:
				correct = false
				score -= 25
				explanation = "❌ Be careful! This was a legitimate email.\n\n"
				explanation += "Legitimate Signs:\n" + "\n".join(email["legitimate_signs"])
		
		"spam":
			if email["is_phishing"]:
				correct = true
				score += 150
				emails_analyzed += 1
				explanation = "✅ EXCELLENT! Marking phishing as spam protects you!\n\n"
				explanation += "Red Flags you spotted:\n" + "\n".join(email["red_flags"])
			else:
				correct = false
				score -= 50
				explanation = "❌ WRONG! This was legitimate, not spam.\n\n"
				explanation += "Legitimate Signs:\n" + "\n".join(email["legitimate_signs"])
	
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
	
	if emails_analyzed >= total_emails:
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
		progress_label.text = "📧 %d/%d | Score: %d" % [emails_analyzed, total_emails, score]

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
	
	# Calculate XP earned
	var xp_earned = _calculate_xp(score, max_score)
	
	# Determine pass/fail
	var passed = percentage >= 70.0
	var status_emoji = "🎉" if passed else "📚"
	var status_text = "PASSED!" if passed else "NEEDS IMPROVEMENT"
	
	var message = """🎓 PHISHING LAB COMPLETE!

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
		"EXCELLENT! You're a phishing detection expert!" if grade == "A" else
		"GOOD JOB! Keep practicing!" if grade in ["B", "C"] else
		"Review the red flags and try again!"
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
	
	# Save results to TutorialManager
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
	get_tree().change_scene_to_file("res://scene/phishing_intro.tscn")

func _on_form_field_changed(_new_text: String) -> void:
	_validate_form()

func _validate_form() -> void:
	if not submit_reply_button:
		return
	
	var all_filled = true
	
	if name_input and name_input.text.strip_edges() == "":
		all_filled = false
	if email_input and email_input.text.strip_edges() == "":
		all_filled = false
	if address_input and address_input.text.strip_edges() == "":
		all_filled = false
	if password_input and password_input.text.strip_edges() == "":
		all_filled = false
	
	submit_reply_button.disabled = not all_filled
	
	if all_filled:
		submit_reply_button.modulate = Color(1, 1, 1, 1)
	else:
		submit_reply_button.modulate = Color(0.7, 0.7, 0.7, 0.8)

func _disconnect_form_signals() -> void:
	if name_input and name_input.text_changed.is_connected(_on_form_field_changed):
		name_input.text_changed.disconnect(_on_form_field_changed)
	if email_input and email_input.text_changed.is_connected(_on_form_field_changed):
		email_input.text_changed.disconnect(_on_form_field_changed)
	if address_input and address_input.text_changed.is_connected(_on_form_field_changed):
		address_input.text_changed.disconnect(_on_form_field_changed)
	if password_input and password_input.text_changed.is_connected(_on_form_field_changed):
		password_input.text_changed.disconnect(_on_form_field_changed)