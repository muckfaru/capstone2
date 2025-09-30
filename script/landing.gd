extends Control

# === UI References ===
@onready var username_input: Label = $NinePatchRect/usernameInput
@onready var level_input: Label = $NinePatchRect/levelInput
@onready var wins_input: Label = $NinePatchRect/winsInput
@onready var losses_input: Label = $NinePatchRect/losesInput
@onready var status_label: Label = $NinePatchRect/StatusLabel
@onready var profile_pic: TextureRect = $NinePatchRect/ProfilePic
@onready var change_btn: Button = $NinePatchRect/ChangeAvatarButton
@onready var avatar_picker: PopupPanel = $NinePatchRect/AvatarPicker
@onready var avatar_grid: GridContainer = $NinePatchRect/AvatarPicker/GridContainer

# === Avatars & User Data ===
var avatars: Dictionary = {} # { "filename.png": Texture2D }
var selected_avatar: String = ""
var last_avatar_change: int = 0
var avatar_cooldown: int = 2592000 # 30 days

# Firestore base
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"


# === Lifecycle ===
func _ready() -> void:
	_load_avatars()
	change_btn.pressed.connect(_on_change_avatar_pressed)
	# Load avatar + data from Firestore kapag login
	_load_user_data()


# === Load avatars from folder ===
func _load_avatars() -> void:
	var dir := DirAccess.open("res://asset/avatars")
	if dir == null:
		push_error("⚠️ Avatar folder not found: res://asset/avatars")
		return

	avatars.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["png", "jpg", "jpeg", "webp"]:
			var tex := load("res://asset/avatars/" + file_name)
			if tex:
				avatars[file_name] = tex

				var btn := TextureButton.new()
				btn.texture_normal = tex
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				btn.custom_minimum_size = Vector2(64, 64)
				btn.pressed.connect(func(): _on_avatar_selected(file_name))
				avatar_grid.add_child(btn)

		file_name = dir.get_next()
	dir.list_dir_end()


# === Change avatar button ===
func _on_change_avatar_pressed() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_avatar_change < avatar_cooldown:
		var remaining = int((avatar_cooldown - (current_time - last_avatar_change)) / 86400)
		status_label.text = "⏳ You can change avatar again in %d days." % remaining
		return

	avatar_picker.popup_centered()


# === User selects avatar ===
func _on_avatar_selected(file_name: String) -> void:
	if avatars.has(file_name):
		profile_pic.texture = avatars[file_name]
		selected_avatar = file_name
		last_avatar_change = Time.get_unix_time_from_system()
		avatar_picker.hide()
		status_label.text = "✅ Avatar updated!"
		# Save to Firestore
		_save_avatar_to_firestore(file_name)


# === Save avatar to Firestore ===
func _save_avatar_to_firestore(file_name: String) -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in, cannot save avatar")
		return

	var url = "%s/%s?updateMask.fieldPaths=avatar&updateMask.fieldPaths=last_avatar_change" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"avatar": { "stringValue": file_name },
			"last_avatar_change": { "integerValue": str(last_avatar_change) }
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result, response_code, headers, body):
		if response_code == 200:
			status_label.text = "✅ Avatar saved to Firestore"
			Auth.current_avatar = file_name
		else:
			var msg = body.size() > 0 and body.get_string_from_utf8() or "Unknown error"
			status_label.text = "❌ Failed to save avatar"
			push_error("Firestore error: %s" % msg)
	)

	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


# === Load avatar from Firestore ===
func _load_user_data() -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	var url = "%s/%s" % [firestore_base_url, user_id]
	var headers = ["Authorization: Bearer %s" % id_token]

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result, response_code, headers, body):
		if response_code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data.has("fields"):
				if data["fields"].has("avatar"):
					selected_avatar = data["fields"]["avatar"]["stringValue"]
					if avatars.has(selected_avatar):
						profile_pic.texture = avatars[selected_avatar]
						Auth.current_avatar = selected_avatar

				if data["fields"].has("last_avatar_change"):
					last_avatar_change = int(data["fields"]["last_avatar_change"]["integerValue"])
		else:
			push_error("⚠️ Failed to load user data: %s" % response_code)
	)

	http.request(url, headers, HTTPClient.METHOD_GET)
