extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var repeat_password_input: LineEdit = $VideoStreamPlayer/RepeatPasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/status
@onready var signup_button: Button = $VideoStreamPlayer/SignUpButton
@onready var google_signup_btn: TextureButton = $VideoStreamPlayer/GoogleLoginButton

# path to your helper (adjust if different)
@onready var oauth_helper = preload("res://script/auth_helper.gd").new()

var email_regex := RegEx.new()

func _ready():
	# init
	add_child(oauth_helper)
	oauth_helper.token_received.connect(_on_google_code_received)
	Auth.auth_response.connect(_on_auth_response)

	signup_button.pressed.connect(_on_signup_pressed)
	google_signup_btn.pressed.connect(_on_google_signup_pressed)

	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
	email_input.text_changed.connect(_validate_inputs)
	password_input.text_changed.connect(_validate_inputs)
	repeat_password_input.text_changed.connect(_validate_inputs)


# ------------------------------------------------------
# 🔹 Google OAuth2 Sign Up Flow (starts local server + opens browser)
# ------------------------------------------------------
func _on_google_signup_pressed():
	message_label.text = "⏳ Opening Google Sign-In..."
	oauth_helper.start_google_login()
	message_label.text = "🌐 Waiting for browser to redirect..."


# called when the helper emits the authorization code
func _on_google_code_received(code: String):
	message_label.text = "⏳ Exchanging code for tokens..."
	# Ask Auth singleton to exchange code -> token (it will call login_with_google when id_token is received)
	Auth.exchange_google_code(code)
	message_label.text = "⏳ Signing in with Google..."


# ------------------------------------------------------
# 🔹 Validation & Signup
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
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var repeat = repeat_password_input.text.strip_edges()

	if email == "" or password == "" or repeat == "":
		message_label.text = "⚠️ Please enter credentials"
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format"
		return

	if password != repeat:
		message_label.text = "❌ Passwords do not match!"
		return

	message_label.text = "⏳ Creating account..."
	Auth.sign_up(email, password)


# ------------------------------------------------------
# 🔹 Firebase Auth Response
# ------------------------------------------------------
func _on_auth_response(response_code: int, response: Dictionary):
	print("Auth response:", response_code, response)

	if response_code == 200:
		# If Firebase returned idToken it's a sign-in / sign-up success
		if response.has("idToken"):
			# If this sign-in is from Google provider
			if response.has("providerId") and response["providerId"] == "google.com":
				message_label.text = "✅ Google Sign-In Success!"
				Auth.current_id_token = response["idToken"]
				if response.has("localId"):
					Auth.current_local_id = response["localId"]
				# after successful Firebase sign-in, check Firestore for document
				_check_firestore_username_and_route()
				return

			# Otherwise, email signup -> send verification
			message_label.text = "✅ Account created! Please verify your email."
			Auth.send_verification_email(response["idToken"])
			var LoginScene = load("res://scene/login.tscn")
			get_tree().change_scene_to_packed(LoginScene)
		else:
			message_label.text = "❌ Unexpected response: " + str(response)
	else:
		message_label.text = "❌ Signup failed: " + str(response.get("error", {}).get("message", "Unknown error"))


func _check_firestore_username_and_route():
	# After successful sign-in, check if user doc exists; goto create_user or landing accordingly
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("Missing auth state after Google sign-in")
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
	http.request_completed.connect(func(result, response_code, headers_r, body_r, req=http):
		req.queue_free()
		var text = body_r.get_string_from_utf8()
		print("Firestore check: ", response_code, " | ", text)
		if response_code == 200:
			var resp = JSON.parse_string(text)
			if typeof(resp) == TYPE_DICTIONARY and resp.has("fields") and resp["fields"].has("username"):
				# go to landing if username exists
				var landing = load("res://scene/landing.tscn")
				get_tree().change_scene_to_packed(landing)
			else:
				var createuser = load("res://scene/create_users_panel.tscn")
				get_tree().change_scene_to_packed(createuser)
		else:
			# doc not found or error -> create user
			var createuser = load("res://scene/create_users_panel.tscn")
			get_tree().change_scene_to_packed(createuser)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)
