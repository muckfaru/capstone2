extends Panel

@onready var friend_container: VBoxContainer = $FriendListVBox
@onready var requests_container: VBoxContainer = $FriendRequestsVBox
@onready var add_input: LineEdit = $AddFriendHBox/FriendUIDInput
@onready var add_button: Button = $AddFriendHBox/AddFriendButton

# 🔹 Firebase Config
const PROJECT_ID: String = "capstone-823dc"
const BASE_URL: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID


# ======================================================
# 🔸 READY
# ======================================================
func _ready() -> void:
	add_button.pressed.connect(func(): send_friend_request(add_input.text.strip_edges()))
	load_friend_requests()
	print("[FriendList] Ready.")


# ======================================================
# 📥 LOAD FRIEND REQUESTS (for current user)
# ======================================================
func load_friend_requests() -> void:
	for child in requests_container.get_children():
		child.queue_free()

	print("[DEBUG] Loading requests...")

	var user_uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	print("[DEBUG] UID:", user_uid)
	print("[DEBUG] Token:", id_token.substr(0, 10), "...")

	if id_token == "" or user_uid == "":
		push_error("⚠️ Missing Auth info.")
		return

	var url = "%s/users/%s" % [BASE_URL, user_uid]
	print("[DEBUG] GET:", url)
	var headers = ["Authorization: Bearer %s" % id_token]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()

		print("[DEBUG] HTTP CODE:", code)
		print("[DEBUG] BODY:", body.get_string_from_utf8())

		if code != 200:
			push_warning("⚠️ Failed to load friend requests.")
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data or not data.has("fields"):
			push_warning("⚠️ Invalid Firestore data.")
			return

		var requests: Array = []
		if data["fields"].has("requests_received"):
			var arr_val = data["fields"]["requests_received"].get("arrayValue", {})
			if arr_val.has("values"):
				for v in arr_val["values"]:
					if v.has("stringValue"):
						requests.append(v["stringValue"])

		print("[DEBUG] Requests found:", requests)

		for sender_uid in requests:
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = sender_uid
			label.custom_minimum_size = Vector2(180, 24)
			hbox.add_child(label)

			var accept_btn = Button.new()
			accept_btn.text = "Accept"
			accept_btn.pressed.connect(func():
				accept_friend_request(sender_uid)
				hbox.queue_free()
			)
			hbox.add_child(accept_btn)

			var decline_btn = Button.new()
			decline_btn.text = "Decline"
			decline_btn.pressed.connect(func():
				decline_friend_request(sender_uid)
				hbox.queue_free()
			)
			hbox.add_child(decline_btn)

			requests_container.add_child(hbox)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


# ======================================================
# 📩 SEND FRIEND REQUEST (Firestore arrayUnion version)
# ======================================================
func send_friend_request(target_username: String) -> void:
	if target_username == "" or target_username == Auth.current_local_id:
		push_error("⚠️ Invalid input.")
		return

	var sender_uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	if id_token == "" or sender_uid == "":
		push_error("⚠️ Missing Auth info.")
		return

	print("[FriendRequest] Searching username:", target_username)

	# Step 1️⃣ — Find target user by username
	var query_url = "%s:runQuery" % BASE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": target_username}
				}
			},
			"limit": 1
		}
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var http_query := HTTPRequest.new()
	add_child(http_query)

	http_query.request_completed.connect(func(_r, code, _h, body):
		http_query.queue_free()
		print("[DEBUG] Query CODE:", code)
		print("[DEBUG] Query BODY:", body.get_string_from_utf8())

		if code != 200:
			push_warning("⚠️ Firestore query failed.")
			return

		var data_array = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data_array) != TYPE_ARRAY or data_array.size() == 0 or not data_array[0].has("document"):
			push_warning("❌ Username not found: %s" % target_username)
			return

		# Extract UID of receiver (target)
		var doc_path = data_array[0]["document"]["name"]
		var target_uid = doc_path.get_file()
		print("[DEBUG] Found UID:", target_uid)

		# Step 2️⃣ — Get sender's username (for display instead of UID)
		var sender_url = "%s/users/%s" % [BASE_URL, sender_uid]
		var http_sender := HTTPRequest.new()
		add_child(http_sender)

		http_sender.request_completed.connect(func(_r2, code2, _h2, body2):
			http_sender.queue_free()
			if code2 != 200:
				push_warning("⚠️ Failed to get sender username.")
				return

			var sender_data = JSON.parse_string(body2.get_string_from_utf8())
			if not sender_data.has("fields") or not sender_data["fields"].has("username"):
				push_warning("⚠️ Sender has no username field.")
				return

			var sender_username = sender_data["fields"]["username"]["stringValue"]
			print("[DEBUG] Sender username:", sender_username)

			# Step 3️⃣ — Append sender's USERNAME into receiver’s requests_received (arrayUnion)
			var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
			var commit_body = {
				"writes": [
					{
						"transform": {
							"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, target_uid],
							"fieldTransforms": [
								{
									"fieldPath": "requests_received",
									"appendMissingElements": {
										"values": [
											{"stringValue": sender_username}
										]
									}
								}
							]
						}
					}
				]
			}

			var http_commit := HTTPRequest.new()
			add_child(http_commit)

			http_commit.request_completed.connect(func(_r3, code3, _h3, body3):
				http_commit.queue_free()
				print("[DEBUG] COMMIT CODE:", code3)
				print("[DEBUG] COMMIT BODY:", body3.get_string_from_utf8())

				if code3 == 200:
					print("✅ Friend request sent successfully to:", target_username)
					add_input.text = ""
				else:
					push_warning("⚠️ Failed to update requests_received.")
			)

			http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
		)

		http_sender.request(sender_url, headers, HTTPClient.METHOD_GET)
	)

	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# 🤝 ACCEPT FRIEND REQUEST (Firestore arrayUnion + arrayRemove via Commit API)
# ======================================================
func accept_friend_request(sender_username: String) -> void:
	var receiver_uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	if id_token == "" or receiver_uid == "":
		push_error("⚠️ Missing Auth info.")
		return

	print("[FriendRequest] Accepting request from:", sender_username)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	# Step 1️⃣ — Get sender UID from username
	var query_url = "%s:runQuery" % BASE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": sender_username}
				}
			},
			"limit": 1
		}
	}

	var http_query := HTTPRequest.new()
	add_child(http_query)
	http_query.request_completed.connect(func(_r, code, _h, body):
		http_query.queue_free()
		if code != 200:
			push_warning("⚠️ Firestore query failed.")
			return

		var data_array = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data_array) != TYPE_ARRAY or data_array.size() == 0:
			push_warning("❌ Username not found: %s" % sender_username)
			return

		var sender_uid = data_array[0]["document"]["name"].get_file()
		print("[DEBUG] Found sender UID:", sender_uid)

		# Step 2️⃣ — Get receiver’s username
		var receiver_url = "%s/users/%s" % [BASE_URL, receiver_uid]
		var http_receiver := HTTPRequest.new()
		add_child(http_receiver)
		http_receiver.request_completed.connect(func(_r2, code2, _h2, body2):
			http_receiver.queue_free()
			if code2 != 200:
				push_warning("⚠️ Failed to get receiver username.")
				return

			var receiver_data = JSON.parse_string(body2.get_string_from_utf8())
			if not receiver_data.has("fields") or not receiver_data["fields"].has("username"):
				push_warning("⚠️ Receiver has no username field.")
				return

			var receiver_username = receiver_data["fields"]["username"]["stringValue"]

			# Step 3️⃣ — Commit updates (arrayUnion + arrayRemove)
			var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
			var commit_body = {
				"writes": [
					# A: Add sender to receiver’s friends
					{
						"transform": {
							"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, receiver_uid],
							"fieldTransforms": [
								{
									"fieldPath": "friends",
									"appendMissingElements": {
										"values": [{"stringValue": sender_username}]
									}
								}
							]
						}
					},
					# B: Add receiver to sender’s friends
					{
						"transform": {
							"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, sender_uid],
							"fieldTransforms": [
								{
									"fieldPath": "friends",
									"appendMissingElements": {
										"values": [{"stringValue": receiver_username}]
									}
								}
							]
						}
					},
					# C: Remove sender from receiver’s requests_received
					{
						"transform": {
							"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, receiver_uid],
							"fieldTransforms": [
								{
									"fieldPath": "requests_received",
									"removeAllFromArray": {
										"values": [{"stringValue": sender_username}]
									}
								}
							]
						}
					}
				]
			}

			var http_commit := HTTPRequest.new()
			add_child(http_commit)
			http_commit.request_completed.connect(func(_r3, code3, _h3, body3):
				http_commit.queue_free()
				print("[DEBUG] COMMIT CODE:", code3)
				print("[DEBUG] COMMIT BODY:", body3.get_string_from_utf8())
				if code3 == 200:
					print("✅ Friend request accepted successfully!")
					load_friend_requests()
				else:
					push_warning("⚠️ Failed to accept friend request.")
			)
			http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
		)
		http_receiver.request(receiver_url, headers, HTTPClient.METHOD_GET)
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# ❌ DECLINE REQUEST
# ======================================================
func decline_friend_request(sender_username: String) -> void:
	var receiver_uid = Auth.current_local_id
	var id_token = Auth.current_id_token

	if id_token == "" or receiver_uid == "":
		push_error("⚠️ Missing auth info.")
		return

	print("[FriendRequest] Declining request from:", sender_username)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	# Step 1️⃣ — Get sender UID from username
	var query_url = "%s:runQuery" % BASE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": sender_username}
				}
			},
			"limit": 1
		}
	}

	var http_query := HTTPRequest.new()
	add_child(http_query)
	http_query.request_completed.connect(func(_r, code, _h, body):
		http_query.queue_free()

		if code != 200:
			push_warning("⚠️ Firestore query failed.")
			return

		var data_array = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data_array) != TYPE_ARRAY or data_array.size() == 0:
			push_warning("❌ Username not found: %s" % sender_username)
			return

		var sender_uid = data_array[0]["document"]["name"].get_file()
		print("[DEBUG] Found sender UID:", sender_uid)

		# Step 2️⃣ — Prepare commit body to remove request
		var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
		var commit_body = {
			"writes": [
				# A: Remove sender from receiver’s requests_received
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, receiver_uid],
						"fieldTransforms": [
							{
								"fieldPath": "requests_received",
								"removeAllFromArray": {
									"values": [{"stringValue": sender_username}]
								}
							}
						]
					}
				},

				# (Optional) B: Remove receiver from sender’s requests_sent
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, sender_uid],
						"fieldTransforms": [
							{
								"fieldPath": "requests_sent",
								"removeAllFromArray": {
									"values": [{"stringValue": Auth.current_username}]
								}
							}
						]
					}
				}
			]
		}

		var http_commit := HTTPRequest.new()
		add_child(http_commit)
		http_commit.request_completed.connect(func(_r2, code2, _h2, body2):
			http_commit.queue_free()

			print("[DEBUG] DECLINE CODE:", code2)
			print("[DEBUG] DECLINE BODY:", body2.get_string_from_utf8())

			if code2 == 200:
				print("❌ Friend request declined successfully.")
				load_friend_requests()
			else:
				push_warning("⚠️ Failed to decline friend request.")
		)
		http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))
