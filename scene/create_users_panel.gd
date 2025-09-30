extends Control

@onready var username_input: LineEdit = $NinePatchRect/UsernameLineEdit
@onready var save_button: Button = $NinePatchRect/ConfirmButton
@onready var message_label: Label = $NinePatchRect/CreateUserLabel

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready():
	save_button.pressed.connect(_on_save_pressed)

func _on_save_pressed():
	var username = username_input.text.strip_edges()
	if username == "":
		message_label.text = "⚠️ Please enter a username."
		return
	
	message_label.text = "⏳ Saving username..."

	var url = "%s/users?documentId=%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var body = {
		"fields": {
			"username": {"stringValue": username},
			"level": {"integerValue": 1},
			"wins": {"integerValue": 0},
			"losses": {"integerValue": 0}
		}
	}

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http, body))
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_request_completed(result, response_code, headers, body, http: HTTPRequest, original_body: Dictionary):
	http.queue_free()

	var text = body.get_string_from_utf8()
	print("Firestore save response:", response_code, text)

	if response_code == 200:
		var response = JSON.parse_string(text)
		if response and response.has("fields"):
			Auth.current_username = response["fields"]["username"]["stringValue"]
			message_label.text = "✅ Username saved!"
			_go_to_landing()
	elif response_code == 409:
		# Doc already exists → fallback to PATCH
		print("⚠️ Doc already exists, switching to PATCH update...")
		_patch_existing_user(original_body)
	else:
		message_label.text = "❌ Failed to save username. (%s)" % response_code

# ------------------------------------------------------
# 🔹 PATCH fallback
# ------------------------------------------------------
func _patch_existing_user(body: Dictionary):
	var url = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_patch_completed.bind(http))
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _on_patch_completed(result, response_code, headers, body, http: HTTPRequest):
	http.queue_free()

	var text = body.get_string_from_utf8()
	print("Firestore PATCH response:", response_code, text)

	if response_code == 200:
		var response = JSON.parse_string(text)
		if response and response.has("fields"):
			Auth.current_username = response["fields"]["username"]["stringValue"]
			message_label.text = "✅ Username updated!"
			_go_to_landing()
	else:
		message_label.text = "❌ Failed to update username. (%s)" % response_code

# ------------------------------------------------------
# 🔹 Helper to go to landing scene
# ------------------------------------------------------
func _go_to_landing():
	var landing = load("res://scene/landing.tscn")
	get_tree().change_scene_to_packed(landing)
