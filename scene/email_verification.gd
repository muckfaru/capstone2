# email_verification.gd
# Handles email verification flow after user signs up
extends Control

# UI References
@onready var email_label: Label = $VideoStreamPlayer/Panel/VBoxContainer/EmailLabel
@onready var status_label: Label = $VideoStreamPlayer/Panel/VBoxContainer/StatusLabel
@onready var check_button: Button = $VideoStreamPlayer/Panel/VBoxContainer/CheckButton
@onready var resend_button: Button = $VideoStreamPlayer/Panel/VBoxContainer/ResendButton
@onready var back_button: Button = $VideoStreamPlayer/Panel/VBoxContainer/BackButton

# Firebase API Key
const FIREBASE_API_KEY := "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"

# Timer for auto-checking verification status
var check_timer: Timer
var can_resend := true

func _ready():
	print("\n=== EMAIL VERIFICATION SCENE LOADED ===")
	
	# Display the user's email
	if Auth.current_user_email != "":
		email_label.text = Auth.current_user_email
		print("📧 User email:", Auth.current_user_email)
	else:
		email_label.text = "your email"
		print("⚠️ No email found in Auth")
	
	# Debug auth state
	print("🔑 ID Token:", Auth.current_id_token.left(30) if Auth.current_id_token != "" else "MISSING")
	print("🔄 Refresh Token:", Auth.current_refresh_token.left(30) if Auth.current_refresh_token != "" else "MISSING")
	print("👤 Local ID:", Auth.current_local_id)
	
	# Setup auto-check timer (checks every 3 seconds)
	check_timer = Timer.new()
	check_timer.wait_time = 3.0
	check_timer.timeout.connect(_auto_check_verification)
	add_child(check_timer)
	check_timer.start()
	
	print("✅ Auto-check timer started (3 second interval)")
	print("=====================================\n")


# Auto-check verification (silent - no UI updates unless verified)
func _auto_check_verification():
	print("🔄 [AUTO-CHECK] Checking verification status...")
	_check_verification_status(true)


# Manual check when user clicks button
func _on_check_button_pressed():
	print("🔘 [MANUAL] User clicked verification check button")
	status_label.text = "⏳ Checking verification status..."
	check_button.disabled = true
	_check_verification_status(false)


# Main verification check flow
func _check_verification_status(silent: bool = false):
	# Validate we have auth tokens
	if Auth.current_id_token == "":
		if not silent:
			status_label.text = "❌ Not authenticated. Please sign up again."
			check_button.disabled = false
		print("❌ No ID token available")
		return
	
	if Auth.current_refresh_token == "":
		if not silent:
			status_label.text = "❌ No refresh token. Please sign up again."
			check_button.disabled = false
		print("❌ No refresh token available")
		return
	
	# Step 1: Refresh the ID token (to get latest emailVerified status)
	_refresh_token(silent)


# Refresh ID token to get updated user data
func _refresh_token(silent: bool):
	if not silent:
		print("🔄 Refreshing ID token...")
	
	var url = "https://securetoken.googleapis.com/v1/token?key=%s" % FIREBASE_API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"grant_type": "refresh_token",
		"refresh_token": Auth.current_refresh_token
	})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, response_code, _headers, body_data):
		http.queue_free()
		
		if response_code == 200:
			var response = JSON.parse_string(body_data.get_string_from_utf8())
			if response.has("id_token"):
				Auth.current_id_token = response["id_token"]
				if response.has("refresh_token"):
					Auth.current_refresh_token = response["refresh_token"]
				
				if not silent:
					print("✅ Token refreshed successfully")
				
				# Step 2: Check account info with fresh token
				_get_account_info(silent)
			else:
				if not silent:
					status_label.text = "❌ Token refresh failed"
					check_button.disabled = false
				print("❌ Token refresh response missing id_token")
		else:
			if not silent:
				status_label.text = "❌ Authentication error"
				check_button.disabled = false
			print("❌ Token refresh failed with code:", response_code)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if not silent:
			status_label.text = "❌ Connection error"
			check_button.disabled = false
		print("❌ HTTP request error:", err)


# Get account info to check emailVerified status
func _get_account_info(silent: bool):
	if not silent:
		print("📋 Getting account info...")
	
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=%s" % FIREBASE_API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"idToken": Auth.current_id_token
	})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, response_code, _headers, body_data):
		http.queue_free()
		check_button.disabled = false
		
		if response_code == 200:
			var response = JSON.parse_string(body_data.get_string_from_utf8())
			
			if response.has("users") and response["users"].size() > 0:
				var user = response["users"][0]
				var is_verified = user.get("emailVerified", false)
				
				if silent:
					print("   └─ Email verified:", is_verified)
				else:
					print("✅ Account info retrieved. Email verified:", is_verified)
				
				if is_verified:
					# 🎉 EMAIL VERIFIED!
					check_timer.stop()
					status_label.text = "✅ Email verified! Redirecting..."
					status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
					
					print("\n🎉 EMAIL VERIFIED! Redirecting to intro scene...")
					
					await get_tree().create_timer(1.5).timeout
					
					# Change to intro scene
					var result = get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
					if result != OK:
						push_error("Failed to load intro_scene.tscn")
						status_label.text = "❌ Scene load error"
				else:
					# Not verified yet
					if not silent:
						status_label.text = "⚠️ Email not verified yet. Please check your inbox."
						status_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			else:
				if not silent:
					status_label.text = "❌ Could not retrieve account info"
				print("❌ No user data in response")
		else:
			if not silent:
				status_label.text = "❌ Verification check failed"
			print("❌ Account lookup failed with code:", response_code)
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if not silent:
			status_label.text = "❌ Connection error"
		print("❌ HTTP request error:", err)


# Resend verification email
func _on_resend_button_pressed():
	print("📧 User clicked resend button")
	
	if not can_resend:
		status_label.text = "⏳ Please wait before resending..."
		print("⚠️ Resend cooldown active")
		return
	
	if Auth.current_id_token == "":
		status_label.text = "❌ Not authenticated"
		print("❌ No ID token for resend")
		return
	
	status_label.text = "📧 Sending verification email..."
	resend_button.disabled = true
	can_resend = false
	
	print("📤 Sending verification email...")
	
	# Use Auth singleton to send email
	Auth.send_verification_email(Auth.current_id_token)
	
	await get_tree().create_timer(2.0).timeout
	status_label.text = "✅ Verification email sent! Check your inbox."
	print("✅ Verification email sent")
	
	# Re-enable after 30 seconds
	await get_tree().create_timer(30.0).timeout
	can_resend = true
	resend_button.disabled = false
	print("✅ Resend cooldown expired")


# Back to login
func _on_back_button_pressed():
	print("⬅️ User clicked back button")
	if check_timer:
		check_timer.stop()
	get_tree().change_scene_to_file("res://scene/login.tscn")


# Cleanup
func _exit_tree():
	if check_timer:
		check_timer.stop()
	print("👋 Email verification scene exited")
