extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/LoginButton
@onready var google_login_btn: TextureButton = $VideoStreamPlayer/GoogleLoginButton

# helper for OAuth2
@onready var oauth_helper = preload("res://script/auth_helper.gd").new()

var email_regex := RegEx.new()

func _ready():
	add_child(oauth_helper)
	oauth_helper.token_received.connect(_on_google_code_received)
	Auth.auth_response.connect(_on_auth_response)

	login_button.pressed.connect(_on_login_pressed)
	google_login_btn.pressed.connect(_on_google_login_pressed)

	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")


# ------------------------------------------------------
# 🔹 Email/Password Login
# ------------------------------------------------------
func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		message_label.text = "⚠️ Please enter email and password."
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format."
		return

	message_label.text = "⏳ Logging in..."
	Auth.login(email, password)


# ------------------------------------------------------
# 🔹 Google OAuth Login Flow (same as signup)
# ------------------------------------------------------
func _on_google_login_pressed():
	message_label.text = "⏳ Opening Google Sign-In..."
	oauth_helper.start_google_login()
	message_label.text = "🌐 Waiting for browser to redirect..."


func _on_google_code_received(code: String):
	message_label.text = "⏳ Exchanging code for tokens..."
	Auth.exchange_google_code(code)
	message_label.text = "⏳ Signing in with Google..."


# ------------------------------------------------------
# 🔹 Firebase Auth Response
# ------------------------------------------------------
func _on_auth_response(response_code: int, response: Dictionary):
	print("Auth Response:", response_code, response)

	if response_code == 200:
		if response.has("idToken"):
			message_label.text = "✅ Login successful!"
			Auth.current_id_token = response["idToken"]
			if response.has("localId"):
				Auth.current_local_id = response["localId"]

			_check_firestore_username_and_route()
			return
		else:
			message_label.text = "❌ Unexpected Firebase response: " + str(response)
	else:
		var error_msg = response.get("error", {}).get("message", "Unknown error")
		message_label.text = "❌ Login failed: " + error_msg


# ------------------------------------------------------
# 🔹 Firestore Check (Same as signup)
# ------------------------------------------------------
func _check_firestore_username_and_route():
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("Missing auth state after sign-in")
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
				var landing = load("res://scene/landing.tscn")
				get_tree().change_scene_to_packed(landing)
			else:
				var createuser = load("res://scene/create_users_panel.tscn")
				get_tree().change_scene_to_packed(createuser)
		else:
			var createuser = load("res://scene/create_users_panel.tscn")
			get_tree().change_scene_to_packed(createuser)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)
