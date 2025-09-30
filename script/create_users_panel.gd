extends Control

@onready var username_input: LineEdit = $NinePatchRect/UsernameLineEdit
@onready var save_button: Button = $NinePatchRect/ConfirmButton
@onready var message_label: Label = $NinePatchRect/MessageLabel

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready():
	save_button.pressed.connect(_on_save_pressed)

func _on_save_pressed():
	var username = username_input.text.strip_edges()
	if username == "":
		message_label.text = "⚠️ Please enter a username."
		return
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		message_label.text = "⚠️ Auth missing. Login again."
		return

	message_label.text = "⏳ Saving profile..."

	var body = {
		"fields": {
			"username": {"stringValue": username},
			"avatar": {"stringValue": "default.png"},
			"level": {"integerValue": 1},
			"wins": {"integerValue": 0},
			"losses": {"integerValue": 0},
			"last_avatar_change": {"integerValue": "0"}
		}
	}

	var url = "%s/users?documentId=%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_post_completed.bind(http, body))
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_post_completed(result, response_code, headers, body, http: HTTPRequest, original_body: Dictionary):
	http.queue_free()
	var text = body.get_string_from_utf8()
	print("Firestore POST response:", response_code, text)

	if response_code == 200 or response_code == 201:
		var resp = JSON.parse_string(text)
		if typeof(resp) == TYPE_DICTIONARY and resp.has("fields"):
			var f = resp["fields"]
			Auth.current_username = f.get("username", {}).get("stringValue", "")
			Auth.current_avatar = f.get("avatar", {}).get("stringValue", "default.png")
			message_label.text = "✅ Profile created!"
			get_tree().change_scene_to_packed(load("res://scene/landing.tscn"))
	elif response_code == 409:
		_patch_existing_user(original_body)
	else:
		message_label.text = "❌ Failed to save profile (%s)." % response_code

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
	if response_code == 200:
		var resp = JSON.parse_string(body.get_string_from_utf8())
		var f = resp.get("fields", {})
		Auth.current_username = f.get("username", {}).get("stringValue", "")
		Auth.current_avatar = f.get("avatar", {}).get("stringValue", "default.png")
		message_label.text = "✅ Profile updated!"
		get_tree().change_scene_to_packed(load("res://scene/landing.tscn"))
	else:
		message_label.text = "❌ Failed to update profile (%s)." % response_code
