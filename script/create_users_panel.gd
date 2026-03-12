extends Control

@onready var username_input: LineEdit = $NinePatchRect/UsernameLineEdit
@onready var save_button: Button = $NinePatchRect/ConfirmButton
@onready var message_label: Label = $NinePatchRect/MessageLabel

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	message_label.text = ""


# -------------------------
# MAIN SAVE LOGIC (Entry point)
# -------------------------
func _on_save_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	if username == "":
		message_label.text = "⚠️ Please enter a username."
		return
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		message_label.text = "⚠️ Missing Auth info. Please log in again."
		return

	message_label.text = "⏳ Checking existing profile..."

	# Step 1: Check kung existing user doc
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = ["Authorization: Bearer %s" % Auth.current_id_token]

	var req := HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(_r, code, _h, _body):
		req.queue_free()

		if code == 200:
			print("✅ Existing user found, redirecting to mode_selection.tscn...")
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
			return

		print("🆕 No existing user doc, checking if username is taken...")
		message_label.text = "⏳ Checking username availability..."
		_check_username_taken(username)
	)

	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to start user check request: %s" % err)
		req.queue_free()


const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"

# -------------------------
# CHECK IF USERNAME IS TAKEN (RTDB usernames index)
# -------------------------
func _check_username_taken(username: String) -> void:
	var rtdb_url := "%s/usernames/%s.json?auth=%s" % [
		RTDB_BASE,
		username.to_lower().uri_encode(),
		Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()

		if code != 200:
			# Cannot verify — block creation to be safe
			print("⚠️ RTDB username check failed (HTTP %d)" % code)
			message_label.text = "❌ Unable to verify username. Check connection and try again."
			return

		var parsed = JSON.parse_string(resp_body.get_string_from_utf8())
		# RTDB returns JSON null when path doesn't exist (username is free)
		if parsed != null:
			message_label.text = "❌ Username already taken. Please choose another."
			print("❌ Username '%s' is already taken." % username)
		else:
			print("✅ Username available, creating new Firestore doc...")
			_create_new_user(username)
	)

	var err := http.request(rtdb_url, [], HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to start RTDB username check: %s" % err)
		http.queue_free()
		message_label.text = "❌ Connection error. Please try again."


# -------------------------
# CREATE NEW USER DOC (Only called if not found)
# -------------------------
func _create_new_user(username: String) -> void:
	message_label.text = "⏳ Creating new profile..."

	var body := {
		"fields": {
			"username": {"stringValue": username},
			"avatar": {"stringValue": "default.png"},
			"wins": {"integerValue": 0},
			"losses": {"integerValue": 0},
			"level": {"integerValue": 1},
			"friends": {"arrayValue": {"values": []}},
			"requests_received": {"arrayValue": {"values": []}}
		}
	}

	var url: String = "%s/users?documentId=%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_r, code, _h, _response_body):
		http.queue_free()

		var text: String = _response_body.get_string_from_utf8()
		print("Firestore Response:", code, text)

		if code == 200 or code == 201:
			# Register username in RTDB usernames index for future duplicate checks
			var rtdb_url2 := "%s/usernames/%s.json?auth=%s" % [
				RTDB_BASE,
				username.to_lower().uri_encode(),
				Auth.current_id_token
			]
			var rtdb_http := HTTPRequest.new()
			add_child(rtdb_http)
			rtdb_http.request_completed.connect(func(_r2, _c2, _h2, _b2): rtdb_http.queue_free())
			rtdb_http.request(rtdb_url2, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, '"%s"' % Auth.current_local_id)

			message_label.text = "✅ Profile created successfully!"
			# Navigate to mode selection instead of landing
			get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		else:
			message_label.text = "❌ Failed to create profile (%s)" % code
			push_warning(text)
	)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore POST request: %s" % err)
		http.queue_free()
