extends Node

signal auth_response(response_code: int, response: Dictionary)

const API_KEY: String = "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"

@onready var http_request: HTTPRequest = $HTTPRequest

# 🔹 Store user info globally
var current_id_token: String = ""
var current_local_id: String = ""
var current_username: String = ""
var current_avatar: String = ""

# ---------- OAuth / Token exchange config (fill these with your Web client ID & secret) ----------
const GOOGLE_OAUTH_CLIENT_ID: String = "1055956713490-tr6mh6pd994opb1hm2rmtmar1eilb3rm.apps.googleusercontent.com" # your Web client ID
const GOOGLE_OAUTH_CLIENT_SECRET: String = "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" # from Cloud Console
const REDIRECT_URI: String = "http://127.0.0.1:8765" # must match authorized redirect URIs

func _ready() -> void:
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)


# -------------------------
# SIGN UP (Email + Password)
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
# LOGIN (Email + Password)
# -------------------------
func login(email: String, password: String) -> void:
	_request(
		"https://identitytool.googleapis.com/v1/accounts:signInWithPassword?key=%s" % API_KEY,
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)


# -------------------------
# LOGIN WITH GOOGLE (Firebase id_token already obtained)
# -------------------------
func login_with_google(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=%s" % API_KEY,
		{
			"postBody": "id_token=%s&providerId=google.com" % id_token,
			"requestUri": "http://127.0.0.1", # any valid URL that's allowed in Google console
			"returnIdpCredential": true,
			"returnSecureToken": true
		}
	)


# -------------------------
# EXCHANGE AUTH CODE -> ID_TOKEN (Google OAuth2 token endpoint)
# -------------------------
func exchange_google_code(code: String) -> void:
	# Build form-encoded body
	var body_dict := {
		"code": code,
		"client_id": GOOGLE_OAUTH_CLIENT_ID,
		"client_secret": GOOGLE_OAUTH_CLIENT_SECRET,
		"redirect_uri": REDIRECT_URI,
		"grant_type": "authorization_code"
	}
	var pairs: Array = []
	for k in body_dict.keys():
		pairs.append("%s=%s" % [str(k).uri_encode(), str(body_dict[k]).uri_encode()])
	var body_str: String = "&".join(pairs)
	var headers := ["Content-Type: application/x-www-form-urlencoded"]

	# temporary HTTPRequest so we don't reuse the main one
	var req := HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(result: int, response_code: int, headers_r: PackedStringArray, body_r: PackedByteArray) -> void:
		# free node
		req.queue_free()

		# EXPLICIT TYPE to avoid inference errors
		var text: String = body_r.get_string_from_utf8()
		print("Token exchange response:", response_code, text)

		if response_code == 200:
			var resp = JSON.parse_string(text)
			if resp is Dictionary:
				if resp.has("id_token"):
					var idt: String = str(resp["id_token"])
					# sign-in to Firebase with the id_token
					login_with_google(idt)
				else:
					emit_signal("auth_response", 0, {"error": "No id_token in token response", "raw": resp})
			else:
				emit_signal("auth_response", 0, {"error": "Invalid token exchange JSON"})
		else:
			emit_signal("auth_response", response_code, {"error": text})
	)

	# PASS A STRING (not PackedByteArray) — fixes your "argument 4 should be String" error
	var err := req.request("https://oauth2.googleapis.com/token", headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		push_error("Failed to start token exchange request: %s" % err)
		req.queue_free()


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
	var body_str: String = JSON.stringify(body)
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		emit_signal("auth_response", 0, {"error": "Request failed with code %s" % err})


# -------------------------
# HANDLE RESPONSE
# -------------------------
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response: Dictionary = {}
	if body.size() > 0:
		var text: String = body.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			response = parsed

	# save tokens if present
	if response.has("idToken"):
		current_id_token = str(response["idToken"])
	if response.has("localId"):
		current_local_id = str(response["localId"])

	emit_signal("auth_response", response_code, response)
	print("Response Code: ", response_code, " | Response: ", response)
