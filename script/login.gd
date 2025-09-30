extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/LoginButton

var email_regex := RegEx.new()

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready():
	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
	login_button.pressed.connect(_on_login_pressed)
	Auth.auth_response.connect(_on_auth_response)


# ------------------------------------------------------
# 🔹 LOGIN FLOW
# ------------------------------------------------------
func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		message_label.text = "⚠️ Please enter email and password."
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format"
		return

	message_label.text = "⏳ Logging in..."
	Auth.login(email, password)


func _on_auth_response(response_code: int, response: Dictionary):
	print("Auth Response: ", response_code, " | ", response)

	if response_code == 200:
		# ✅ LOGIN RESPONSE
		if response.has("idToken"):
			Auth.current_id_token = response["idToken"]
			if response.has("localId"):
				Auth.current_local_id = response["localId"]

			# Check email verification
			Auth.check_email_verified(Auth.current_id_token)
			return

		# ✅ LOOKUP RESPONSE
		if response.has("users"):
			var user = response["users"][0]
			if user.has("emailVerified") and user["emailVerified"] == true:
				message_label.text = "✅ Login Success!"
				_check_firestore_username()
			else:
				message_label.text = "❌ Please verify your email."
	else:
		var error_msg := "Unknown error"
		if response.has("error") and response["error"].has("message"):
			error_msg = response["error"]["message"]
		message_label.text = "❌ Login failed: %s" % error_msg


# ------------------------------------------------------
# 🔹 Firestore check kung may user document
# ------------------------------------------------------
func _check_firestore_username():
	var url = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_check_username_completed.bind(http))
	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_check_username_completed(result, response_code, headers, body, http: HTTPRequest):
	http.queue_free()

	var text = body.get_string_from_utf8()
	print("Firestore check: ", response_code, " | ", text)

	if response_code == 200:
		var response = JSON.parse_string(text)
		if typeof(response) != TYPE_DICTIONARY:
			print("❌ Invalid JSON response")
			_go_to_create_user()
			return

		if response.has("fields") and response["fields"].has("username"):
			Auth.current_username = response["fields"]["username"]["stringValue"]
			_go_to_landing()
		else:
			_go_to_create_user()
	else:
		print("Firestore doc not found or error, code:", response_code)
		_go_to_create_user()


# ------------------------------------------------------
# 🔹 Scene Navigation Helpers
# ------------------------------------------------------
func _go_to_landing():
	var landing = load("res://scene/landing.tscn")
	get_tree().change_scene_to_packed(landing)

func _go_to_create_user():
	var createuser = load("res://scene/create_users_panel.tscn")
	get_tree().change_scene_to_packed(createuser)


# ------------------------------------------------------
# 🔹 Sign Up Button
# ------------------------------------------------------
func _on_sign_up_button_pressed() -> void:
	var signupScene = load("res://scene/signup.tscn")
	get_tree().change_scene_to_packed(signupScene)
