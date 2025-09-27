extends Control

@onready var email_input: LineEdit = $VideoStreamPlayer/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/PasswordLineEdit
@onready var repeat_password_input: LineEdit = $VideoStreamPlayer/RepeatPasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/status
@onready var signup_button: Button = $VideoStreamPlayer/SignUpButton

# regex para sa email validation
var email_regex := RegEx.new()

func _ready():
	# compile regex (basic email validation)
	email_regex.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")

	# connect buttons
	signup_button.pressed.connect(_on_signup_pressed)
	Auth.auth_response.connect(_on_auth_response)

	# connect real-time validation
	email_input.text_changed.connect(_validate_inputs)
	password_input.text_changed.connect(_validate_inputs)
	repeat_password_input.text_changed.connect(_validate_inputs)

# real-time validation
func _validate_inputs(new_text: String = "") -> void:
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var repeat = repeat_password_input.text.strip_edges()

	if email == "" or password == "" or repeat == "":
		message_label.text = "⚠️ Please enter credentials"
		return

	# check email format
	if not email_regex.search(email):
		message_label.text = "⚠️ Invalid email format"
		return

	# kung okay lahat
	message_label.text = ""

# kapag nag click si signup
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

	Auth.sign_up(email, password)
	message_label.text = "⏳ Signing up..."

# kapag nag click si login button → balik sa login scene
func _on_login_pressed():
	var LoginScene = load("res://scene/login.tscn")
	get_tree().change_scene_to_packed(LoginScene)

# response galing kay Auth
func _on_auth_response(response_code: int, response: Dictionary):
	if response_code == 200:
		if "idToken" in response:
			message_label.text = "✅ Sign Up Success! Please check your email."
			Auth.send_verification_email(response["idToken"])
	else:
		message_label.text = "❌ Error: " + str(response)

# kapag gusto magpalit sa login scene
func _on_change_to_login_button_pressed() -> void:
	var LoginScene = load("res://scene/login.tscn")
	get_tree().change_scene_to_packed(LoginScene)
