extends PopupPanel

var profile_pic: TextureRect
var username_label: Label
var level_label: Label
var wins_label: Label
var losses_label: Label
var winrate_label: Label
var match_played_label: Label
var close_btn: Button

var avatars: Dictionary = {}
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"
var http: HTTPRequest

func _ready() -> void:
	# Get nodes dynamically instead of using @onready
	profile_pic = get_node_or_null("ProfilePanel/UserPanel/ProfilePic")
	username_label = get_node_or_null("ProfilePanel/UserPanel/usernameInput")
	level_label = get_node_or_null("ProfilePanel/UserPanel/levelInput")
	wins_label = get_node_or_null("ProfilePanel/UserPanel/winsInput")
	losses_label = get_node_or_null("ProfilePanel/UserPanel/losesInput")
	winrate_label = get_node_or_null("ProfilePanel/UserPanel/winrateInput")
	match_played_label = get_node_or_null("ProfilePanel/UserPanel/MatchPlayedInput")
	close_btn = get_node_or_null("ProfilePanel/MatchHistoyPanel/MatchHistoyHeader/CloseViewPlayerProfile")
	
	_load_avatars()
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("[ViewPlayerProfile] Warning: close_btn not found")
	
	print("[ViewPlayerProfile] Modal ready and initialized")

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
		file_name = dir.get_next()
	dir.list_dir_end()

func display_player_profile(player_username: String) -> void:
	print("[ViewPlayerProfile] Fetching profile for: ", player_username)
	var token = Auth.current_id_token
	if token == "":
		push_error("⚠️ Not authenticated")
		return

	# Query for player by username
	var query_url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents:runQuery"
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": player_username}
				}
			},
			"limit": 1
		}
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_player_data_received)
	http.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))

func _on_player_data_received(result, response_code, _headers, body) -> void:
	if response_code != 200:
		push_error("⚠️ Failed to fetch player data")
		if http:
			http.queue_free()
		return

	var arr = JSON.parse_string(body.get_string_from_utf8())
	if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
		push_error("⚠️ Player not found")
		if http:
			http.queue_free()
		return

	var player_data = arr[0]["document"]["fields"]
	print("[ViewPlayerProfile] Player data received: ", player_data.keys())
	
	# Update UI with player data - check if nodes exist first
	if username_label and player_data.has("username"):
		username_label.text = player_data["username"]["stringValue"]
		print("[ViewPlayerProfile] Set username: ", username_label.text)
	
	if level_label and player_data.has("level"):
		level_label.text = str(player_data["level"]["integerValue"])
	
	if wins_label and player_data.has("wins"):
		wins_label.text = str(player_data["wins"]["integerValue"])
	
	if losses_label and player_data.has("losses"):
		losses_label.text = str(player_data["losses"]["integerValue"])
	
	if winrate_label and player_data.has("wins") and player_data.has("losses"):
		var wins = int(player_data["wins"]["integerValue"])
		var losses = int(player_data["losses"]["integerValue"])
		var total = wins + losses
		var wr = 0
		if total > 0:
			wr = int((float(wins) / float(total)) * 100)
		winrate_label.text = str(wr)
	
	if match_played_label and player_data.has("wins") and player_data.has("losses"):
		var total = int(player_data["wins"]["integerValue"]) + int(player_data["losses"]["integerValue"])
		match_played_label.text = str(total)
	
	# Load and display avatar
	if profile_pic and player_data.has("avatar"):
		var avatar_name = player_data["avatar"]["stringValue"]
		if avatars.has(avatar_name):
			profile_pic.texture = avatars[avatar_name]
			print("[ViewPlayerProfile] Avatar loaded: ", avatar_name)
	
	if http:
		http.queue_free()

func _on_close_pressed() -> void:
	hide()
