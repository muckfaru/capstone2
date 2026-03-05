extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")
const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")

@onready var email_input: LineEdit = $VideoStreamPlayer/FillUpForm/EmailLineEdit
@onready var password_input: LineEdit = $VideoStreamPlayer/FillUpForm/PasswordLineEdit
@onready var message_label: Label = $VideoStreamPlayer/FillUpForm/MessageLabel
@onready var login_button: Button = $VideoStreamPlayer/FillUpForm/LoginButton
@onready var google_login_btn: TextureButton = $VideoStreamPlayer/FillUpForm/GoogleLoginButton

@onready var oauth_helper = preload("res://script/auth_helper.gd").new()

var email_regex := RegEx.new()

var _google_login_pending: bool = false

func _ready():
	add_child(oauth_helper)
	oauth_helper.token_received.connect(_on_google_code_received)
	oauth_helper.login_timed_out.connect(_on_google_login_timed_out)
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
	# If already waiting from a previous click, cancel and restart
	if _google_login_pending:
		oauth_helper.cancel_login()

	_google_login_pending = true
	google_login_btn.disabled = false
	message_label.text = "⏳ Opening Google Sign-In..."
	oauth_helper.start_google_login()
	message_label.text = "🌐 Waiting for browser redirect... (click again to retry)"


func _on_google_login_timed_out() -> void:
	"""Called when OAuth helper times out (user probably closed the browser tab)."""
	_google_login_pending = false
	google_login_btn.disabled = false
	message_label.text = "⚠️ Google Sign-In timed out. Click the button to try again."


func _on_google_code_received(code: String):
	_google_login_pending = false
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
					# Existing user with username - route (resume if match still exists)
					call_deferred("_route_existing_user_after_login")
					return
				else:
					print("🆕 User document exists but no username found - NEW USER")
					# User exists but no username - NEW USER, start story!
					get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
			else:
				print("⚠️ Invalid response structure - treating as NEW USER")
				get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
		else:
			# 🆕 User document doesn't exist (404 or other error)
			print("🆕 User document not found (", response_code, "), starting story for NEW USER")
			get_tree().change_scene_to_file("res://scene/entryingtohouse.tscn")
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _route_existing_user_after_login() -> void:
	# Give Auth a frame to populate username/uid cleanly.
	await get_tree().process_frame
	var handled: bool = await _maybe_resume_code_breaker_session_checked()
	if handled:
		return
	handled = await _maybe_resume_akashic_tcg_session_checked()
	if handled:
		return
	get_tree().change_scene_to_file("res://scene/landing.tscn")


func _maybe_resume_akashic_tcg_session_checked() -> bool:
	if not Auth or Auth.current_local_id == "":
		return false

	var session := _TGCSess.load_session()
	if session.is_empty():
		return false

	var room_id := str(session.get("room_id", "")).strip_edges()
	if room_id == "":
		return false

	var session_player_id := str(session.get("player_id", ""))
	if session_player_id != "" and session_player_id != "unknown" and session_player_id != Auth.current_local_id:
		_TGCSess.clear_session()
		return false

	var saved_lobby_url := str(session.get("lobby_server_url", "")).strip_edges()
	var current_lobby_url := ""
	if typeof(MultiplayerConfig) != TYPE_NIL and MultiplayerConfig:
		current_lobby_url = str(MultiplayerConfig.get_lobby_url()).strip_edges()

	var candidates: Array[String] = []
	if saved_lobby_url != "":
		candidates.append(saved_lobby_url)
	if current_lobby_url != "" and (current_lobby_url not in candidates):
		candidates.append(current_lobby_url)
	if candidates.is_empty():
		return false

	var parsed: Variant = null
	var chosen_url := ""
	var saw_404 := false
	for url_base in candidates:
		var url := url_base + "/api/rooms/" + room_id
		var res := await _http_get_json(url)
		var code := int(res.get("code", 0))
		if code == 404:
			saw_404 = true
			continue
		if code != 200:
			continue
		var data: Variant = res.get("data", null)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if data.has("error"):
			continue
		parsed = data
		chosen_url = url_base
		break

	if parsed == null:
		if saw_404:
			print("[Login] ℹ️ Saved Akashic TCG room no longer exists. Clearing session.")
			_TGCSess.clear_session()
		return false

	var status := str(parsed.get("status", "waiting"))
	var host_dict: Dictionary = parsed.get("host", {})
	var client_val = parsed.get("client", {})
	var client_dict: Dictionary = client_val if typeof(client_val) == TYPE_DICTIONARY else {}
	var is_host := false
	if typeof(host_dict) == TYPE_DICTIONARY:
		is_host = (str(host_dict.get("player_id", "")) == Auth.current_local_id)

	var phase := str(session.get("phase", ""))

	if status == "in_game":
		print("[Login] ✅ Saved Akashic TCG match in progress. Routing to reconnect.")
		get_tree().set_meta("tgc_reconnect_init", {
			"room_id": room_id,
			"lobby_server_url": chosen_url,
			"player_id": Auth.current_local_id,
			"username": Auth.current_username,
			"is_host": is_host,
			"relay_client": null,
			"host_data": host_dict,
			"client_data": client_dict,
			"game_start_time": int(parsed.get("game_start_time", 0)),
			"reason": "Resume after login",
			"phase": phase,
		})
		get_tree().change_scene_to_file("res://scene/akashic_tcg_reconnect.tscn")
		return true

	if status == "waiting":
		print("[Login] ✅ Saved Akashic TCG room waiting. Routing to room.")
		get_tree().set_meta("tgc_room_init", {
			"room_id": room_id,
			"host_name": str(host_dict.get("username", "Host")),
			"is_host": is_host,
			"lobby_server_url": chosen_url,
		})
		get_tree().change_scene_to_file("res://scene/akashic_tcg_room.tscn")
		return true

	if status == "finished":
		print("[Login] ✅ Saved Akashic TCG match finished. Routing to postgame.")
		get_tree().set_meta("tgc_postgame_init", {
			"room_id": room_id,
			"player_id": Auth.current_local_id,
			"winner_id": "",
			"reason": "resume_finished",
			"lobby_server_url": chosen_url,
			"host_data": host_dict,
			"client_data": client_dict,
			"result_unknown": true,
		})
		get_tree().change_scene_to_file("res://scene/akashic_tcg_postgame.tscn")
		return true

	_TGCSess.clear_session()
	return false


func _maybe_resume_code_breaker_session_checked() -> bool:
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

	# Try both session-stored URL and current config URL (localhost vs production mismatch).
	var saved_lobby_url := str(session.get("lobby_server_url", "")).strip_edges()
	var current_lobby_url := ""
	if typeof(MultiplayerConfig) != TYPE_NIL and MultiplayerConfig:
		current_lobby_url = str(MultiplayerConfig.get_lobby_url()).strip_edges()

	var candidates: Array[String] = []
	if saved_lobby_url != "":
		candidates.append(saved_lobby_url)
	if current_lobby_url != "" and (current_lobby_url not in candidates):
		candidates.append(current_lobby_url)
	if candidates.is_empty():
		return false

	var parsed: Variant = null
	var chosen_url := ""
	var saw_404 := false
	for url_base in candidates:
		var url := url_base + "/api/rooms/" + room_id
		var res := await _http_get_json(url)
		var code := int(res.get("code", 0))
		if code == 404:
			saw_404 = true
			continue
		if code != 200:
			continue
		var data: Variant = res.get("data", null)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if data.has("error"):
			continue
		parsed = data
		chosen_url = url_base
		break

	if parsed == null:
		# If room is definitely gone, clear session so we don't keep reconnecting.
		if saw_404:
			print("[Login] ℹ️ Saved Code Breaker room no longer exists. Clearing session.")
			_SessionStore.clear_session()
		return false

	var status := str(parsed.get("status", "waiting"))
	if status == "finished":
		print("[Login] ✅ Saved Code Breaker match finished. Routing to postgame.")
		var host_dict_finished: Dictionary = parsed.get("host", {})
		var client_val_finished = parsed.get("client", {})
		var client_dict_finished: Dictionary = client_val_finished if typeof(client_val_finished) == TYPE_DICTIONARY else {}
		var is_host_finished := false
		if typeof(host_dict_finished) == TYPE_DICTIONARY:
			is_host_finished = (str(host_dict_finished.get("player_id", "")) == Auth.current_local_id)
		var postgame_init := {
			"room_id": room_id,
			"relay_client": null,
			"player_id": Auth.current_local_id,
			"is_host": is_host_finished,
			"host_data": host_dict_finished,
			"client_data": client_dict_finished,
			"lobby_server_url": chosen_url,
			"winner_id": "",
			"host_score": 0,
			"client_score": 0,
			"host_health": 0,
			"client_health": 0,
			"game_duration": 0.0,
			"host_powerups_used": 0,
			"client_powerups_used": 0,
			"result_unknown": true
		}
		get_tree().set_meta("code_breaker_postgame_init", postgame_init)
		var post_scene := load("res://scene/code_breaker_postgame.tscn")
		if post_scene:
			get_tree().change_scene_to_packed(post_scene)
			return true
		return false

	if status == "waiting":
		print("[Login] 🔄 Saved Code Breaker room still waiting. Routing to room.")
		var host_dict: Dictionary = parsed.get("host", {})
		var is_host := false
		if typeof(host_dict) == TYPE_DICTIONARY:
			is_host = (str(host_dict.get("player_id", "")) == Auth.current_local_id)
		var room_init := {
			"room_id": room_id,
			"host_name": str(host_dict.get("username", "Host")),
			"is_host": is_host,
			"lobby_server_url": chosen_url
		}
		get_tree().set_meta("code_breaker_room_init", room_init)
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
			return true
		return false

	if status == "in_game":
		print("[Login] 🔄 Match in progress. Routing to reconnect. Room: ", room_id)
		var host_dict2: Dictionary = parsed.get("host", {})
		var is_host2 := false
		if typeof(host_dict2) == TYPE_DICTIONARY:
			is_host2 = (str(host_dict2.get("player_id", "")) == Auth.current_local_id)
		var init := {
			"room_id": room_id,
			"lobby_server_url": chosen_url,
			"player_id": Auth.current_local_id,
			"username": Auth.current_username,
			"is_host": is_host2,
			"relay_client": null,
			"host_data": host_dict2,
			"client_data": parsed.get("client", {}) if parsed.get("client", null) != null else {},
			"game_start_time": int(parsed.get("game_start_time", 0)),
			"reason": "Resume after relogin"
		}
		get_tree().set_meta("code_breaker_reconnect_init", init)
		var reconnect_scene := load("res://scene/code_breaker_reconnect.tscn")
		if reconnect_scene:
			get_tree().change_scene_to_packed(reconnect_scene)
			return true
		return false

	# Unknown status: clear to avoid loops
	_SessionStore.clear_session()
	return false


func _http_get_json(url: String) -> Dictionary:
	var http_req := HTTPRequest.new()
	add_child(http_req)
	var err := http_req.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		http_req.queue_free()
		return {"code": 0, "data": null}
	var result: Array = await http_req.request_completed
	http_req.queue_free()
	var code := int(result[1])
	var body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return {"code": code, "data": parsed}


# ------------------------------------------------------
# 🔹 Navigate to Signup Scene
# ------------------------------------------------------
func _on_sign_up_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/signup.tscn")