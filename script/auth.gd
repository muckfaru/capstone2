extends Node 

signal auth_response(response_code: int, response: Dictionary)  
# Signal na magbabalik ng response kapag may natapos na authentication request

const API_KEY: String = "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"  
# Firebase Web API key (galing sa Firebase project)

@onready var http_request: HTTPRequest = $HTTPRequest  
# Reference sa HTTPRequest node sa scene (para sa mga web request)

# 🔹 Mga variable para i-store ang user info globally
var current_id_token: String = ""   # Token para sa authentication
var current_local_id: String = ""   # Unique ID ng user sa Firebase
var current_username: String = ""   # Username (kung meron)
var current_avatar: String = ""     # Avatar ng user (optional)

# ---------- Google OAuth config ----------
const GOOGLE_OAUTH_CLIENT_ID: String = "1055956713490-tr6mh6pd994opb1hm2rmtmar1eilb3rm.apps.googleusercontent.com"
const GOOGLE_OAUTH_CLIENT_SECRET: String = "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"
const REDIRECT_URI: String = "http://127.0.0.1:8765"  # Dapat pareho sa nakalagay sa Google Console mo

func _ready() -> void:
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)
		# Kapag natapos ang HTTP request, tatawagin ang _on_request_completed()


# -------------------------
# SIGN UP (Gumawa ng bagong account gamit email + password)
# -------------------------
func sign_up(email: String, password: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % API_KEY,  # Endpoint ng Firebase sign-up
		{
			"email": email,                  # Email ng user
			"password": password,            # Password ng user
			"returnSecureToken": true        # Para bumalik ang ID token at refresh token
		}
	)


# -------------------------
# LOGIN (Email + Password)
# -------------------------
func login(email: String, password: String) -> void:
	_request(
		"https://identitytool.googleapis.com/v1/accounts:signInWithPassword?key=%s" % API_KEY,  # Firebase login endpoint
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)


# -------------------------
# LOGIN WITH GOOGLE (gamit ang Firebase id_token)
# -------------------------
func login_with_google(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=%s" % API_KEY,  # Endpoint para sa OAuth provider login
		{
			"postBody": "id_token=%s&providerId=google.com" % id_token,  # Ipadala ang id_token na galing sa Google
			"requestUri": "http://127.0.0.1",  # Dapat valid URL (kahit localhost)
			"returnIdpCredential": true,        # Para makuha ang provider info
			"returnSecureToken": true           # Para makuha rin ang Firebase token
		}
	)


# -------------------------
# EXCHANGE AUTH CODE -> ID_TOKEN (Google OAuth2 token endpoint)
# -------------------------
func exchange_google_code(code: String) -> void:
	# Gawa ng HTTP body (x-www-form-urlencoded)
	var body_dict := {
		"code": code,
		"client_id": GOOGLE_OAUTH_CLIENT_ID,
		"client_secret": GOOGLE_OAUTH_CLIENT_SECRET,
		"redirect_uri": REDIRECT_URI,
		"grant_type": "authorization_code"  # Required ni Google
	}

	# I-convert ang dictionary sa URL-encoded string
	var pairs: Array = []
	for k in body_dict.keys():
		pairs.append("%s=%s" % [str(k).uri_encode(), str(body_dict[k]).uri_encode()])
	var body_str: String = "&".join(pairs)
	var headers := ["Content-Type: application/x-www-form-urlencoded"]

	# Gumawa ng temporary HTTPRequest node (para hindi magulo ang main http_request)
	var req := HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(result: int, response_code: int, headers_r: PackedStringArray, body_r: PackedByteArray) -> void:
		req.queue_free()  # Burahin matapos gamitin

		var text: String = body_r.get_string_from_utf8()
		print("Token exchange response:", response_code, text)

		if response_code == 200:  # Success
			var resp = JSON.parse_string(text)
			if resp is Dictionary:
				if resp.has("id_token"):
					var idt: String = str(resp["id_token"])
					login_with_google(idt)  # Kapag may id_token, mag-login sa Firebase
				else:
					emit_signal("auth_response", 0, {"error": "Walang id_token sa token response", "raw": resp})
			else:
				emit_signal("auth_response", 0, {"error": "Maling token exchange JSON"})
		else:
			emit_signal("auth_response", response_code, {"error": text})
	)

	# Magpadala ng POST request sa Google token endpoint
	var err := req.request("https://oauth2.googleapis.com/token", headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		push_error("Hindi makapagsimula ng token exchange request: %s" % err)
		req.queue_free()


# -------------------------
# MAGPADALA NG EMAIL VERIFICATION
# -------------------------
func send_verification_email(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=%s" % API_KEY,
		{
			"requestType": "VERIFY_EMAIL",  # Ipadadala ang email verification link
			"idToken": id_token
		}
	)


# -------------------------
# CHECK KUNG NA-VERIFY ANG EMAIL
# -------------------------
func check_email_verified(id_token: String) -> void:
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=%s" % API_KEY,
		{ "idToken": id_token }  # Tingnan ang status ng email verification
	)


# -------------------------
# HELPER FUNCTION PARA SA HTTP REQUESTS
# -------------------------
func _request(url: String, body: Dictionary) -> void:
	var headers := ["Content-Type: application/json"]  # JSON format ang body
	var body_str: String = JSON.stringify(body)
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		emit_signal("auth_response", 0, {"error": "Nabigo ang request, code: %s" % err})


# -------------------------
# CALLBACK PAGTAPOS NG HTTP REQUEST
# -------------------------
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response: Dictionary = {}
	if body.size() > 0:
		var text: String = body.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			response = parsed  # I-save ang parsed JSON response

	# Kung may idToken sa response, i-store
	if response.has("idToken"):
		current_id_token = str(response["idToken"])
	if response.has("localId"):
		current_local_id = str(response["localId"])

	emit_signal("auth_response", response_code, response)  # I-send pabalik ang resulta
	print("Response Code: ", response_code, " | Response: ", response)
