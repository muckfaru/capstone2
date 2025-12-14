extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/LoginButton
@onready var google_login_btn: TextureButton = $VideoStreamPlayer/GoogleLoginButton

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
# 🔹 Google OAuth Login Flow
# ------------------------------------------------------
func _on_google_login_pressed():
	message_label.text = "⏳ Opening Google Sign-In..."
	oauth_helper.start_google_login()
	message_label.text = "🌐 Waiting for browser redirect..."


func _on_google_code_received(code: String):
	message_label.text = "⏳ Exchanging code for token..."
	Auth.exchange_google_code(code)
	message_label.text = "⏳ Logging in with Google..."


# ------------------------------------------------------
# 🔹 FIXED: Auth Response from Firebase
# ------------------------------------------------------
func _on_auth_response(response_code: int, response: Dictionary):
	print("Auth Response:", response_code, response)

	if response_code == 200:
		if response.has("idToken"):
			message_label.text = "✅ Login successful!"
			Auth.current_id_token = response["idToken"]
			if response.has("localId"):
				Auth.current_local_id = response["localId"]

			# Mark user as online
			Auth.set_user_online()

			# Check Firestore to determine routing
			_check_firestore_username_and_route()
			return
		else:
			message_label.text = "❌ Unexpected response: " + str(response)
	else:
		var error_msg = response.get("error", {}).get("message", "Unknown error")
		message_label.text = "❌ Login failed: " + error_msg


# ------------------------------------------------------
# 🔹 FIXED: Check Firestore and Route Correctly
# ------------------------------------------------------
func _check_firestore_username_and_route():
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("Missing auth data after sign in")
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
	http.request_completed.connect(func(_result, response_code, _headers_r, body_r, req=http):
		req.queue_free()
		var text = body_r.get_string_from_utf8()
		print("🔍 Firestore check: ", response_code, " | ", text)

		if response_code == 200:
			# ✅ User document exists
			var resp = JSON.parse_string(text)
			print("📦 Parsed response type: ", typeof(resp))
			print("📦 Response data: ", resp)
			
			# Check if username field exists and has a value
			if typeof(resp) == TYPE_DICTIONARY and resp.has("fields"):
				var fields = resp["fields"]
				print("📦 Fields: ", fields)
				
				if fields.has("username") and fields["username"].has("stringValue"):
					var username = fields["username"]["stringValue"]
					print("✅ Existing user found with username: ", username)
					# Existing user with username - try to resume any Code Breaker session first
					if _maybe_resume_code_breaker_session():
						return
					get_tree().change_scene_to_file("res://scene/landing.tscn")
				else:
					print("🆕 User document exists but no username found")
					# User exists but no username - go to intro
					get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
			else:
				print("⚠️ Invalid response structure")
				get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
		else:
			# 🆕 User document doesn't exist (404 or other error)
			print("🆕 User document not found (", response_code, "), showing intro scene")
			get_tree().change_scene_to_file("res://scene/intro_scene.tscn")
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _maybe_resume_code_breaker_session() -> bool:
	if not Auth or Auth.current_local_id == "":
		return false

	var session := _SessionStore.load_session()
	if session.is_empty():
		return false

	var room_id := str(session.get("room_id", "")).strip_edges()
	if room_id == "":
		return false

	var session_player_id := str(session.get("player_id", ""))
	if session_player_id != "" and session_player_id != "unknown" and session_player_id != Auth.current_local_id:
		# Belongs to another account; clear and ignore.
		_SessionStore.clear_session()
		return false

	var lobby_url := ""
	if typeof(MultiplayerConfig) != TYPE_NIL and MultiplayerConfig:
		lobby_url = str(MultiplayerConfig.get_lobby_url())
	if lobby_url.strip_edges() == "":
		lobby_url = str(session.get("lobby_server_url", ""))
	if lobby_url.strip_edges() == "":
		return false

	print("[Login] 🔄 Resuming Code Breaker session into reconnect. Room: ", room_id)
	var init := {
		"room_id": room_id,
		"lobby_server_url": lobby_url,
		"player_id": Auth.current_local_id,
		"username": Auth.current_username,
		"is_host": false,
		"relay_client": null,
		"host_data": {},
		"client_data": {},
		"game_start_time": 0,
		"reason": "Resume after relogin"
	}
	get_tree().set_meta("code_breaker_reconnect_init", init)
	var reconnect_scene := load("res://scene/code_breaker_reconnect.tscn")
	if reconnect_scene:
		get_tree().change_scene_to_packed(reconnect_scene)
		return true
	return false


# ------------------------------------------------------
# 🔹 Navigate to Signup Scene
# ------------------------------------------------------
func _on_sign_up_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/signup.tscn")
