extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/LoginButton

var current_id_token: String = ""
var current_local_id: String = ""   # UID ng user
var email_regex := RegEx.new()

const PROJECT_ID := "YOUR_PROJECT_ID"  # <-- palitan mo dito
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready():
	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
	login_button.pressed.connect(_on_login_pressed)
	Auth.auth_response.connect(_on_auth_response)

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
		# LOGIN RESPONSE
		if response.has("idToken"):
			current_id_token = response["idToken"]
			if response.has("localId"):
				current_local_id = response["localId"]

			# check kung verified email gamit ang lookup
			Auth.check_email_verified(current_id_token)
			return

		# LOOKUP RESPONSE (dito lumalabas ang "users")
		if response.has("users"):
			var user = response["users"][0]
			if user.has("emailVerified") and user["emailVerified"] == true:
				message_label.text = "✅ Login Success!"
				# instead of direct scene load → check Firestore
				_check_firestore_user()
			else:
				message_label.text = "❌ Please verify your email."
			return
	else:
		var error_msg := "Unknown error"
		if response.has("error") and response["error"].has("message"):
			error_msg = response["error"]["message"]
		message_label.text = "❌ Login failed: %s" % error_msg

# ------------------------------------------------------
# 🔹 Firestore check kung may user document
# ------------------------------------------------------
func _check_firestore_user():
	var url = FIRESTORE_URL + "/users/" + current_local_id
	var headers = ["Authorization: Bearer " + current_id_token]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_check_user_doc)
	http.request(url, headers)

func _on_check_user_doc(result, response_code, headers, body):
	var text = body.get_string_from_utf8()
	print("Firestore check: ", response_code, " | ", text)

	if response_code == 200:
		# ✅ May existing doc → derekta sa landing
		var landing = load("res://scene/landing.tscn")
		get_tree().change_scene_to_packed(landing)
	else:
		# ❌ Walang doc → punta sa create user panel
		var createuser = load("res://scene/create_users_panel.tscn")
		get_tree().change_scene_to_packed(createuser)

# ------------------------------------------------------
func _on_sign_up_button_pressed() -> void:
	var signupScene = load("res://scene/signup.tscn")
	get_tree().change_scene_to_packed(signupScene)
