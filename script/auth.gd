extends Node

signal auth_response(response_code: int, response: Dictionary)
signal email_verification_sent(success: bool)
signal email_verification_status(is_verified: bool)

# 🔹 Firebase & Google OAuth config
const API_KEY: String = "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"
const GOOGLE_OAUTH_CLIENT_ID: String = "1055956713490-tr6mh6pd994opb1hm2rmtmar1eilb3rm.apps.googleusercontent.com"
const GOOGLE_OAUTH_CLIENT_SECRET: String = "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"
const REDIRECT_URI: String = "http://127.0.0.1:8765"

@onready var http_request: HTTPRequest = $HTTPRequest

# 🔸 Auth Data (accessible globally)
var current_id_token: String = ""
var current_refresh_token: String = ""  # ✨ Added for email verification
var current_local_id: String = ""
var current_username: String = ""
var current_user_email: String = ""  # ✨ Added to store user email
var current_avatar: String = ""
var current_level: int = 0

# Equipped cosmetics (loaded from Firestore user doc)
var current_card_bg_path: String = ""

# Remote cosmetics cache (learned via relay messages)
var remote_card_bg_by_player_id: Dictionary = {}

func set_remote_card_bg(player_id: String, bg_path: String) -> void:
	if player_id.strip_edges() == "":
		return
	remote_card_bg_by_player_id[player_id] = bg_path

func get_remote_card_bg(player_id: String) -> String:
	if player_id.strip_edges() == "":
		return ""
	return str(remote_card_bg_by_player_id.get(player_id, ""))

# ✅ NEW: Welcome Tutorial Cache
var welcome_tutorial_completed: bool = false
var welcome_tutorial_loaded: bool = false  # Track if we've loaded this from Firestore

func _ready() -> void:
	# Connect signal for request
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# Register as global singleton (para ma-access kahit saan)
	if not Engine.has_singleton("Auth"):
		Engine.register_singleton("Auth", self)
		print("[DEBUG] ✅ Auth singleton registered globally.")

	print("[DEBUG] Auth.gd ready!")

# -------------------------
# ✅ NEW: WELCOME TUTORIAL CACHE FUNCTIONS
# -------------------------
func reset_welcome_cache() -> void:
	"""Call this when user logs in successfully"""
	welcome_tutorial_completed = false
	welcome_tutorial_loaded = false
	print("[Auth] 🔄 Reset welcome tutorial cache for new login")

func set_welcome_tutorial_status(completed: bool) -> void:
	"""Call this when loading user data from Firestore"""
	welcome_tutorial_completed = completed
	welcome_tutorial_loaded = true
	print("[Auth] 💾 Welcome tutorial status cached: %s" % ("completed" if completed else "not completed"))

func mark_welcome_tutorial_complete() -> void:
	"""Call this when user completes the welcome tutorial"""
	welcome_tutorial_completed = true
	print("[Auth] ✅ Welcome tutorial marked as completed in cache")

# -------------------------
# 🔐 SIGN UP
# -------------------------
func sign_up(email: String, password: String) -> void:
	print("[AUTH] Signing up:", email)
	current_user_email = email  # ✨ Store email
	reset_welcome_cache()  # ✅ Reset cache on new signup
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % API_KEY,
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)

# -------------------------
# 🔓 LOGIN (Email + Password)
# -------------------------
func login(email: String, password: String) -> void:
	print("[AUTH] Logging in:", email)
	current_user_email = email  # ✨ Store email
	reset_welcome_cache()  # ✅ Reset cache on new login
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s" % API_KEY,
		{
			"email": email,
			"password": password,
			"returnSecureToken": true
		}
	)

# -------------------------
# 🌐 LOGIN WITH GOOGLE (Firebase)
# -------------------------
func login_with_google(id_token: String) -> void:
	print("[AUTH] Logging in with Google token...")
	reset_welcome_cache()  # ✅ Reset cache on Google login
	_request(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=%s" % API_KEY,
		{
			"postBody": "id_token=%s&providerId=google.com" % id_token,
			"requestUri": "http://127.0.0.1",
			"returnIdpCredential": true,
			"returnSecureToken": true
		}
	)

# -------------------------
# 🔁 EXCHANGE GOOGLE AUTH CODE → ID_TOKEN
# -------------------------
func exchange_google_code(code: String) -> void:
	print("[OAUTH] Exchanging Google code → Firebase token...")

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

	var req := HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(_r, response_code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()

		var text := body.get_string_from_utf8()
		print("[OAUTH] Token exchange response:", response_code, text)

		if response_code == 200:
			var resp = JSON.parse_string(text)
			if resp is Dictionary and resp.has("id_token"):
				login_with_google(str(resp["id_token"]))
			else:
				push_warning("[OAUTH] Missing id_token in Google response.")
				emit_signal("auth_response", 0, {"error": "Missing id_token", "raw": resp})
		else:
			push_warning("[OAUTH] Token exchange failed (%s)" % response_code)
			emit_signal("auth_response", response_code, {"error": text})
	)

	var err := req.request("https://oauth2.googleapis.com/token", headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		push_error("[OAUTH] ❌ Failed to start token exchange (code: %s)" % err)
		req.queue_free()

# -------------------------
# 📧 SEND EMAIL VERIFICATION (Updated)
# -------------------------
func send_verification_email(id_token: String) -> void:
	print("[AUTH] 📧 Sending verification email...")
	
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=%s" % API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"requestType": "VERIFY_EMAIL",
		"idToken": id_token
	})
	
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, body_data):
		req.queue_free()
		
		if response_code == 200:
			print("[AUTH] ✅ Verification email sent successfully!")
			emit_signal("email_verification_sent", true)
		else:
			var response = JSON.parse_string(body_data.get_string_from_utf8())
			print("[AUTH] ❌ Failed to send verification email:", response)
			emit_signal("email_verification_sent", false)
	)
	
	var err = req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("[AUTH] ❌ Failed to send verification email request:", err)
		emit_signal("email_verification_sent", false)

# -------------------------
# 🔍 CHECK EMAIL VERIFIED (Updated with callback)
# -------------------------
func check_email_verified(id_token: String, callback: Callable = Callable()) -> void:
	print("[AUTH] 🔍 Checking email verification status...")
	
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=%s" % API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"idToken": id_token})
	
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, body_data):
		req.queue_free()
		
		if response_code == 200:
			var response = JSON.parse_string(body_data.get_string_from_utf8())
			if response.has("users") and response["users"].size() > 0:
				var user = response["users"][0]
				var is_verified = user.get("emailVerified", false)
				
				print("[AUTH] Email verified status:", is_verified)
				emit_signal("email_verification_status", is_verified)
				
				if callback.is_valid():
					callback.call(is_verified)
			else:
				print("[AUTH] ⚠️ No user data found")
				emit_signal("email_verification_status", false)
				if callback.is_valid():
					callback.call(false)
		else:
			print("[AUTH] ❌ Verification check failed:", response_code)
			emit_signal("email_verification_status", false)
			if callback.is_valid():
				callback.call(false)
	)
	
	req.request(url, headers, HTTPClient.METHOD_POST, body)

# -------------------------
# 🔄 REFRESH ID TOKEN (New - needed for verification)
# -------------------------
func refresh_id_token(callback: Callable = Callable()) -> void:
	if current_refresh_token == "":
		print("[AUTH] ⚠️ No refresh token available")
		if callback.is_valid():
			callback.call(false, "")
		return
	
	print("[AUTH] 🔄 Refreshing ID token...")
	
	var url = "https://securetoken.googleapis.com/v1/token?key=%s" % API_KEY
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"grant_type": "refresh_token",
		"refresh_token": current_refresh_token
	})
	
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, body_data):
		req.queue_free()
		
		if response_code == 200:
			var response = JSON.parse_string(body_data.get_string_from_utf8())
			if response.has("id_token"):
				current_id_token = response["id_token"]
				if response.has("refresh_token"):
					current_refresh_token = response["refresh_token"]
				
				print("[AUTH] ✅ Token refreshed successfully")
				if callback.is_valid():
					callback.call(true, current_id_token)
			else:
				print("[AUTH] ❌ Token refresh failed - missing id_token")
				if callback.is_valid():
					callback.call(false, "")
		else:
			print("[AUTH] ❌ Token refresh failed:", response_code)
			if callback.is_valid():
				callback.call(false, "")
	)
	
	req.request(url, headers, HTTPClient.METHOD_POST, body)

# -------------------------
# 🔹 Realtime Database config for presence
# -------------------------
const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"

# -------------------------
# 🔔 Presence helpers (online/offline)
# -------------------------
func set_user_online() -> void:
	_set_presence("online")
	publish_public_profile({})

func set_user_offline() -> void:
	_set_presence("offline")

# Write a public-readable profile snapshot to RTDB so friends can view it
# Call with extra = {"wins":n, "losses":n, "total_xp":n} after full data loads
func publish_public_profile(extra: Dictionary) -> void:
	if current_local_id == "" or current_id_token == "" or current_username == "":
		return
	var data: Dictionary = {
		"username": current_username,
		"avatar": current_avatar,
		"level": current_level
	}
	for k in extra.keys():
		data[k] = extra[k]
	var url := "%s/public_profiles/%s.json?auth=%s" % [RTDB_BASE, current_username.uri_encode(), current_id_token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
	var err := req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify(data))
	if err != OK:
		req.queue_free()

func _set_presence(state: String) -> void:
	if current_local_id == "" or current_id_token == "":
		push_warning("[AUTH] Missing auth state, cannot set presence.")
		return

	var payload = {"state": state, "last_seen": str(Time.get_unix_time_from_system())}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]

	# Write presence by UID (existing path)
	var url := "%s/presence/%s.json?auth=%s" % [RTDB_BASE, current_local_id, current_id_token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body_r):
		req.queue_free()
		if code == 200:
			print("[AUTH] Presence updated (%s): %s" % [state, current_local_id])
		else:
			var txt = body_r.get_string_from_utf8() if body_r.size() > 0 else "no body"
			push_warning("[AUTH] Failed to update presence (%s): %s" % [code, txt])
	)
	var err := req.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		push_error("[AUTH] Failed to start presence request: %s" % err)
		req.queue_free()

	# Also write presence by username so friends can read it without uid resolution
	if current_username == "":
		return
	var name_url := "%s/presence_by_name/%s.json?auth=%s" % [RTDB_BASE, current_username.uri_encode(), current_id_token]
	var req2 := HTTPRequest.new()
	add_child(req2)
	req2.request_completed.connect(func(_r2, _c2, _h2, _b2):
		req2.queue_free()
	)
	var err2 := req2.request(name_url, headers, HTTPClient.METHOD_PUT, body)
	if err2 != OK:
		req2.queue_free()

# -------------------------
# 🧰 GENERIC REQUEST HANDLER
# -------------------------
func _request(url: String, body: Dictionary) -> void:
	var headers := ["Content-Type: application/json"]
	var body_str := JSON.stringify(body)
	print("[HTTP] Request →", url)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		push_error("[AUTH] ❌ Failed to start request (%s)" % err)
		emit_signal("auth_response", 0, {"error": "Request failed: %s" % err})

# -------------------------
# 📬 RESPONSE HANDLER (Updated to store refresh token)
# -------------------------
func _on_request_completed(_result: int, response_code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var response := {}
	if body.size() > 0:
		var text := body.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			response = parsed

	# ✨ Store tokens
	if response.has("idToken"):
		current_id_token = str(response["idToken"])
	if response.has("localId"):
		current_local_id = str(response["localId"])
	if response.has("refreshToken"):  # ✨ Store refresh token
		current_refresh_token = str(response["refreshToken"])
	if response.has("email"):  # ✨ Store email from response
		current_user_email = str(response["email"])

	print("\n[AUTH RESPONSE]")
	print("Code:", response_code)
	print("Local ID:", current_local_id)
	print("Email:", current_user_email)
	print("ID Token:", current_id_token.left(25), "...")
	print("Has Refresh Token:", current_refresh_token != "")
	print("Welcome Cache Loaded:", welcome_tutorial_loaded)  # ✅ NEW: Debug info
	print()

	emit_signal("auth_response", response_code, response)
