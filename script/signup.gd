extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var repeat_password_input: LineEdit = $VideoStreamPlayer/RepeatPasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/status
@onready var signup_button: Button = $VideoStreamPlayer/SignUpButton
@onready var google_signup_btn: TextureButton = $VideoStreamPlayer/GoogleLoginButton
@onready var animated_sprite: AnimatedSprite2D = $VideoStreamPlayer/AnimatedSprite2D
@onready var fill_up_form: PanelContainer = $VideoStreamPlayer/FillUpForm

# All form elements to hide/show
@onready var form_elements = [
	$VideoStreamPlayer/FillUpForm,
	$VideoStreamPlayer/EmailLabel,
	$VideoStreamPlayer/EmailLabel2,
	$VideoStreamPlayer/PasswordLabel,
	$VideoStreamPlayer/RepeatPasswordLabel,
	$VideoStreamPlayer/EmailLineEdit,
	$VideoStreamPlayer/PasswordLineEdit,
	$VideoStreamPlayer/RepeatPasswordLineEdit,
	$VideoStreamPlayer/TermsCheckBox,
	$VideoStreamPlayer/TermsLabel,
	$VideoStreamPlayer/TermsLink,
	$VideoStreamPlayer/PrivacyLabel,
	$VideoStreamPlayer/PrivacyLink,
	$VideoStreamPlayer/SignUpButton,
	$VideoStreamPlayer/OrDividerLeft,
	$VideoStreamPlayer/OrLabel,
	$VideoStreamPlayer/OrDividerRight,
	$VideoStreamPlayer/GoogleLoginButton,
	$VideoStreamPlayer/FacebookLoginButton,
	$VideoStreamPlayer/UsernameLabel2,
	$VideoStreamPlayer/ChangeToLoginButton,
	$VideoStreamPlayer/BackButton
]

@onready var oauth_helper = preload("res://script/auth_helper.gd").new()

var email_regex := RegEx.new()
var is_loading := true
var is_google_signup := false
var pending_signup_email := ""  # Store email for 2FA verification
var pending_signup_password := ""  # Store password temporarily

func _ready():
	_hide_form_elements()
	
	animated_sprite.visible = true
	animated_sprite.frame = 0
	animated_sprite.play("default")
	
	_monitor_animation_progress()
	
	add_child(oauth_helper)
	oauth_helper.token_received.connect(_on_google_code_received)
	Auth.auth_response.connect(_on_auth_response)

	if not signup_button.pressed.is_connected(_on_signup_pressed):
		signup_button.pressed.connect(_on_signup_pressed)
	
	google_signup_btn.pressed.connect(_on_google_signup_pressed)

	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
	email_input.text_changed.connect(_validate_inputs)
	password_input.text_changed.connect(_validate_inputs)
	repeat_password_input.text_changed.connect(_validate_inputs)


func _hide_form_elements():
	var sprite_x = animated_sprite.position.x
	
	for element in form_elements:
		if element:
			element.visible = false
			if not element.has_meta("original_x"):
				element.set_meta("original_x", element.position.x)
			element.position.x = sprite_x


func _show_form_elements():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	for element in form_elements:
		if element and element.has_meta("original_x"):
			element.visible = true
			var target_x = element.get_meta("original_x")
			tween.tween_property(element, "position:x", target_x, 0.8)


func _monitor_animation_progress():
	while animated_sprite.frame < 6:
		await get_tree().process_frame
	
	animated_sprite.stop()
	animated_sprite.frame = 6
	
	_on_loading_complete()


func _on_loading_complete():
	if is_loading:
		is_loading = false
		print("Loading complete - showing form")
		
		await get_tree().create_timer(0.5).timeout
		_show_form_elements()


# ------------------------------------------------------
# 🔹 Google OAuth2 Sign Up Flow
# ------------------------------------------------------
func _on_google_signup_pressed():
	is_google_signup = true
	message_label.text = "⏳ Opening Google Sign-In..."
	oauth_helper.start_google_login()
	message_label.text = "🌐 Waiting for browser to redirect..."


func _on_google_code_received(code: String):
	message_label.text = "⏳ Exchanging code for tokens..."
	Auth.exchange_google_code(code)
	message_label.text = "⏳ Signing in with Google..."


# ------------------------------------------------------
# 🔹 Validation and Sign Up
# ------------------------------------------------------
func _validate_inputs(_t: String = ""):
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var repeat = repeat_password_input.text.strip_edges()

	if email == "" or password == "" or repeat == "":
		message_label.text = "⚠️ Please fill all fields."
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format."
		return

	message_label.text = ""


func _on_signup_pressed():
	print("🔘 Sign up button pressed!")
	is_google_signup = false
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var repeat = repeat_password_input.text.strip_edges()
	
	print("Email:", email)
	print("Password length:", password.length())
	print("Repeat password length:", repeat.length())

	if email == "" or password == "" or repeat == "":
		message_label.text = "⚠️ Please enter credentials"
		print("⚠️ Empty fields detected")
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format"
		print("⚠️ Invalid email format")
		return

	if password != repeat:
		message_label.text = "❌ Passwords do not match!"
		print("❌ Passwords don't match")
		return

	# Store credentials for after verification
	pending_signup_email = email
	pending_signup_password = password
	
	message_label.text = "⏳ Creating account..."
	print("✅ Validation passed, calling Auth.sign_up()...")
	
	Auth.sign_up(email, password)


# ------------------------------------------------------
# 🔹 Auth Response Handling with 2FA
# ------------------------------------------------------
func _on_auth_response(response_code: int, response: Dictionary):
	print("=== AUTH RESPONSE DEBUG ===")
	print("Response code:", response_code)
	print("Response data:", response)
	print("Is Google signup:", is_google_signup)
	print("=========================")

	if response_code == 200:
		if response.has("idToken"):
			Auth.current_id_token = response["idToken"]
			if response.has("localId"):
				Auth.current_local_id = response["localId"]
			
			# Mark user as online
			Auth.set_user_online()
			
			if is_google_signup:
				# Google OAuth - check Firestore
				message_label.text = "✅ Google Sign-In Success!"
				_check_firestore_username_and_route()
			else:
				# Email/Password signup - send verification email
				message_label.text = "✅ Account created!"
				
				# Send Firebase verification email (built-in)
				Auth.send_verification_email(response["idToken"])
				
				# Wait then go to 2FA verification scene
				await get_tree().create_timer(1.0).timeout
				message_label.text = "📧 Verification email sent!"
				
				await get_tree().create_timer(1.5).timeout
				
				# Reset visuals
				modulate.a = 1.0
				scale = Vector2(1.0, 1.0)
				
				# Go to email verification scene
				print("🎬 Redirecting to email verification scene")
				get_tree().change_scene_to_file("res://scene/email_verification.tscn")
		else:
			message_label.text = "❌ Unexpected response: " + str(response)
			print("⚠️ Missing idToken in response:", response)
	else:
		var error_msg = response.get("error", {}).get("message", "Unknown error")
		message_label.text = "❌ Signup failed: " + error_msg
		print("❌ Auth error:", error_msg)


# ------------------------------------------------------
# 🔹 Check Firestore for existing user (Google OAuth only)
# ------------------------------------------------------
func _check_firestore_username_and_route():
	print("🔍 Starting Firestore check...")
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("Missing auth state after Google sign-in")
		message_label.text = "❌ Auth error. Please try again."
		return

	const PROJECT_ID := "capstone-823dc"
	var FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
	var url = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, response_code, _headers_r, body_r):
		http.queue_free()
		var text = body_r.get_string_from_utf8()
		print("🔍 Firestore check (Google): ", response_code, " | ", text)
		
		if response_code == 200:
			var resp = JSON.parse_string(text)
			
			if typeof(resp) == TYPE_DICTIONARY and resp.has("fields"):
				var fields = resp["fields"]
				
				if fields.has("username") and fields["username"].has("stringValue"):
					var username = fields["username"]["stringValue"]
					print("✅ Existing Google user with username: ", username)
					print("🏠 Changing to landing.tscn...")
					get_tree().change_scene_to_file("res://scene/landing.tscn")
				else:
					print("🆕 Google user exists but no username - NEW USER")
					print("📖 Starting story cutscene for NEW USER...")
					get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
			else:
				print("⚠️ Invalid response structure - NEW USER")
				get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
		else:
			print("🆕 New Google user (", response_code, "), starting story")
			get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to check Firestore: ", err)
		http.queue_free()
		message_label.text = "❌ Connection error"


func _on_change_to_login_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/login.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/login.tscn")