extends Control

@onready var username_label: Label = $UsernameLabel
@onready var level_label: Label = $LevelLabel
@onready var wins_label: Label = $WinsLabel
@onready var losses_label: Label = $LossesLabel

const PROJECT_ID := "capstone-823dc"   # <-- palitan mo dito
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready():
	_load_user()

func _load_user():
	var uid = Auth.current_local_id
	var id_token = Auth.current_id_token

	if uid == "" or id_token == "":
		print("⚠️ Missing UID or token. User not logged in properly.")
		return

	var url = FIRESTORE_URL + "/users/" + uid
	var headers = ["Authorization: Bearer " + id_token]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_user_loaded)
	http.request(url, headers)

func _on_user_loaded(result, response_code, headers, body):
	var text = body.get_string_from_utf8()
	print("Landing Firestore response: ", response_code, " | ", text)

	if response_code == 200:
		var data = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY and data.has("fields"):
			var fields = data["fields"]

			var username = fields.get("username", {}).get("stringValue", "Unknown")
			var level = fields.get("level", {}).get("integerValue", "0")
			var wins = fields.get("wins", {}).get("integerValue", "0")
			var losses = fields.get("losses", {}).get("integerValue", "0")

			username_label.text = "Username: " + str(username)
			level_label.text = "Level: " + str(level)
			wins_label.text = "Wins: " + str(wins)
			losses_label.text = "Losses: " + str(losses)
	else:
		username_label.text = "⚠️ Failed to load user data"
