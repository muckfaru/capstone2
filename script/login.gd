extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/LoginButton

var current_id_token: String = ""
var email_regex := RegEx.new()

func _ready():
	# compile regex (basic email validation)
	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")

	# connect button
	login_button.pressed.connect(_on_login_pressed)
	Auth.auth_response.connect(_on_auth_response)

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	# validation bago mag proceed
	if email == "" or password == "":
		message_label.text = "⚠️ Please enter email and password."
		return

	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format"
		return

	message_label.text = "⏳ Logging in..."
	Auth.login(email, password)  # tawag ng signInWithPassword

func _on_auth_response(response_code: int, response: Dictionary):
	print("Auth Response: ", response_code, " | ", response)

	if response_code == 200:
		# LOGIN RESPONSE
		if response.has("idToken"):
			current_id_token = response["idToken"]
			# check kung verified email gamit ang lookup
			Auth.check_email_verified(current_id_token)
			return

		# LOOKUP RESPONSE (dito lumalabas ang "users")
		if response.has("users"):
			var user = response["users"][0]
			if user.has("emailVerified") and user["emailVerified"] == true:
				message_label.text = "✅ Login Success!"
				# redirect to landing scene
				var landingScene = load("res://scene/landing.tscn")
				get_tree().change_scene_to_packed(landingScene)
			else:
				message_label.text = "❌ Please verify your email."
			return
	else:
		var error_msg := "Unknown error"
		if response.has("error") and response["error"].has("message"):
			error_msg = response["error"]["message"]
		message_label.text = "❌ Login failed: %s" % error_msg

func _on_sign_up_button_pressed() -> void:
	var signupScene = load("res://scene/signup.tscn")
	get_tree().change_scene_to_packed(signupScene)
