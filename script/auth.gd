extends Node

signal auth_response(response_code: int, response: Dictionary)

const API_KEY := "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"

@onready var http_request: HTTPRequest = $HTTPRequest

# 🔹 Store user info globally
var current_id_token: String = ""
var current_local_id: String = ""

func _ready() -> void:
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

# -------------------------
# SIGN UP
# -------------------------
func sign_up(email: String, password: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % API_KEY,
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)

# -------------------------
# LOGIN
# -------------------------
func login(email: String, password: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s" % API_KEY,
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)

# -------------------------
# SEND EMAIL VERIFICATION
# -------------------------
func send_verification_email(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=%s" % API_KEY,
		{
			"requestType": "VERIFY_EMAIL",
			"idToken": id_token
		}
	)

# -------------------------
# CHECK EMAIL VERIFIED
# -------------------------
func check_email_verified(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=%s" % API_KEY,
		{ "idToken": id_token }
	)

# -------------------------
# PRIVATE HELPER
# -------------------------
func _request(url: String, body: Dictionary) -> void:
	var headers := ["Content-Type: application/json"]
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		emit_signal("auth_response", 0, {"error": "Request failed with code %s" % err})

# -------------------------
# HANDLE RESPONSE
# -------------------------
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response := {}
	if body.size() > 0:
		response = JSON.parse_string(body.get_string_from_utf8())

	# 🔹 Save tokens if available
	if response.has("idToken"):
		current_id_token = response["idToken"]
	if response.has("localId"):
		current_local_id = response["localId"]

	emit_signal("auth_response", response_code, response)
	print("Response Code: ", response_code, " | Response: ", response)
