extends Panel

@onready var friend_container: VBoxContainer = $FriendListVBox
@onready var requests_container: VBoxContainer = $FriendRequestsVBox
@onready var add_input: LineEdit = $AddFriendHBox/FriendUIDInput
@onready var add_button: Button = $AddFriendHBox/AddFriendButton

# 🔹 Firebase Config
const PROJECT_ID := "capstone-823dc"
const DB_URL := "https://capstone-823dc-default-rtdb.firebaseio.com"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

var ws_main := WebSocketPeer.new()
var is_connected := false


# ======================================================
# 🔹 READY
# ======================================================
func _ready() -> void:
	print("[FriendList] Ready.")
	add_button.pressed.connect(func(): send_friend_request(add_input.text.strip_edges()))
	start_realtime_listener()


# ======================================================
# 🌐 START REALTIME LISTENER
# ======================================================
func start_realtime_listener() -> void:
	var ws_url = "wss://%s-default-rtdb.firebaseio.com/.ws?v=5&ns=%s-default-rtdb" % [PROJECT_ID, PROJECT_ID]
	print("[Realtime] Connecting to:", ws_url)

	ws_main = WebSocketPeer.new()
	var err = ws_main.connect_to_url(ws_url)
	if err != OK:
		push_error("❌ Failed to connect main RTDB WebSocket.")
		return

	is_connected = true
	print("[Realtime] ✅ Main WebSocket connected.")

	await get_tree().create_timer(1.0).timeout

	var uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	if uid == "" or id_token == "":
		push_warning("⚠️ Missing Auth info.")
		return

	# Step 1️⃣ Authenticate WebSocket
	var auth_msg = {
		"t": "d",
		"d": {
			"r": 1,
			"a": "auth",
			"b": {"cred": id_token}
		}
	}
	ws_main.put_packet(JSON.stringify(auth_msg).to_utf8_buffer())
	print("[Realtime] 🔐 Sent auth handshake")

	await get_tree().create_timer(0.6).timeout

	# Step 2️⃣ Subscribe to friend_requests
	var sub_requests = {
		"t": "d",
		"d": {
			"r": 2,
			"a": "listen", # <--- critical change here
			"b": {
				"p": "/friend_requests/%s" % uid,
				"q": {},
				"t": "once"
			}
		}
	}
	ws_main.put_packet(JSON.stringify(sub_requests).to_utf8_buffer())
	print("[Realtime] 📡 Listening to friend_requests/%s" % uid)

	await get_tree().create_timer(0.3).timeout

	# Step 3️⃣ Subscribe to friends
	var sub_friends = {
		"t": "d",
		"d": {
			"r": 3,
			"a": "listen", # <--- same change here
			"b": {
				"p": "/friends/%s" % uid,
				"q": {},
				"t": "once"
			}
		}
	}
	ws_main.put_packet(JSON.stringify(sub_friends).to_utf8_buffer())
	print("[Realtime] 📡 Listening to friends/%s" % uid)


# ======================================================
# 🔁 PROCESS LOOP – Keep websocket alive
# ======================================================
func _process(_delta: float) -> void:
	if not is_connected:
		return
	ws_main.poll()

	while ws_main.get_ready_state() == WebSocketPeer.STATE_OPEN and ws_main.get_available_packet_count() > 0:
		var msg = ws_main.get_packet().get_string_from_utf8()
		handle_realtime_message(msg)


# ======================================================
# 🧠 HANDLE REALTIME DATABASE MESSAGES
# ======================================================
func handle_realtime_message(message: String) -> void:
	if message == "":
		return

	var parsed = JSON.parse_string(message)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	# 🔹 Debug raw packet type
	if parsed.has("t"):
		print("[Realtime] 🧭 Message type:", parsed["t"])

	# ==================================================
	# Firebase 'data' packets come as t: "d"
	# ==================================================
	if parsed.has("t") and parsed["t"] == "d" and parsed.has("d"):
		var d = parsed["d"]

		# Case 1️⃣: 'control' messages like auth ok / ready
		if d.has("a") and d["a"] == "c":
			print("[Realtime] 🔌 Control message received (connected).")
			return

		# Case 2️⃣: 'put' = new or changed data
		if d.has("a") and d["a"] == "put":
			var path = d["b"].get("p", "")
			var data = d["b"].get("d", {})
			print("[Realtime] 🔔 Incoming realtime update:")
			print(" ├ Path:", path)
			print(" └ Data:", data)

			# If it's under friend_requests/<uid>
			if path.begins_with("/friend_requests/"):
				for sender_name in data.keys():
					print("[Realtime] 📨 New friend request received from:", sender_name)
					_add_request_to_ui(sender_name)

			# If it's under friends/<uid>
			elif path.begins_with("/friends/"):
				for friend_name in data.keys():
					print("[Realtime] 👥 Friend list update: now includes", friend_name)
					_add_friend_to_ui(friend_name)

		# Case 3️⃣: 'listen_cancel' or 'auth_revoked'
		if d.has("a") and d["a"] == "cancel":
			print("[Realtime] ⚠️ Listener cancelled — reauth needed!")


# ======================================================
# 🧾 UPDATE FRIEND REQUESTS UI
# ======================================================
func update_friend_requests_ui(requests_dict: Dictionary) -> void:
	for child in requests_container.get_children():
		child.queue_free()

	for sender in requests_dict.keys():
		if requests_dict[sender] == true:
			var hbox = HBoxContainer.new()

			var lbl = Label.new()
			lbl.text = sender
			lbl.custom_minimum_size = Vector2(150, 24)
			hbox.add_child(lbl)

			var accept_btn = Button.new()
			accept_btn.text = "✅"
			accept_btn.pressed.connect(func(): accept_friend(sender))
			hbox.add_child(accept_btn)

			requests_container.add_child(hbox)

	print("[UI] Friend request list updated. Requests:", requests_dict.keys())


# ======================================================
# 🧾 UPDATE FRIEND LIST UI
# ======================================================
func update_friend_ui(friend_dict: Dictionary) -> void:
	for child in friend_container.get_children():
		child.queue_free()

	for friend_name in friend_dict.keys():
		if friend_dict[friend_name] == true:
			var hbox = HBoxContainer.new()

			var lbl = Label.new()
			lbl.text = friend_name
			lbl.custom_minimum_size = Vector2(150, 24)
			hbox.add_child(lbl)

			var btn = Button.new()
			btn.text = "❌"
			btn.tooltip_text = "Unfriend"
			btn.pressed.connect(func(): unfriend_user(friend_name))
			hbox.add_child(btn)

			friend_container.add_child(hbox)

	print("[UI] Friend list updated. Friends:", friend_dict.keys())


# ======================================================
# ➕ SEND FRIEND REQUEST
# ======================================================
func send_friend_request(target_username: String) -> void:
	if target_username == "" or target_username == Auth.current_username:
		push_warning("⚠️ Invalid target.")
		return

	var id_token = Auth.current_id_token
	var sender_uid = Auth.current_local_id
	if id_token == "" or sender_uid == "":
		push_warning("⚠️ Missing Auth.")
		return

	print("[Friend] Sending request to:", target_username)

	# Step 1️⃣ — Query target UID by username
	var query_url = "%s:runQuery" % FIRESTORE_URL
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
		if code != 200:
			push_warning("❌ Query failed.")
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0 or not arr[0].has("document"):
			push_warning("⚠️ User not found.")
			return

		var target_uid = arr[0]["document"]["name"].get_file()
		print("[Friend] Found UID:", target_uid)
		update_requests_realtime(target_uid, Auth.current_username, id_token)
	)

	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# 🔁 UPDATE REQUESTS IN REALTIME DB
# ======================================================
func update_requests_realtime(target_uid: String, sender_username: String, id_token: String) -> void:
	var url = "%s/friend_requests/%s/%s.json?auth=%s" % [DB_URL, target_uid, sender_username, id_token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, [], HTTPClient.METHOD_PUT, "true")
	print("[Realtime] Sent friend request to:", target_uid)


# ======================================================
# 💔 UNFRIEND
# ======================================================
func unfriend_user(friend_name: String) -> void:
	var uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "%s/friends/%s/%s.json?auth=%s" % [DB_URL, uid, friend_name, id_token]

	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, [], HTTPClient.METHOD_DELETE)
	print("💔 Unfriended:", friend_name)


# ======================================================
# ✅ ACCEPT FRIEND REQUEST
# ======================================================
func accept_friend(sender_name: String) -> void:
	var uid = Auth.current_local_id
	var id_token = Auth.current_id_token
	if uid == "" or id_token == "":
		push_warning("⚠️ Missing Auth info.")
		return

	print("[Realtime] Accepting friend request from:", sender_name)

	var remove_url = "%s/friend_requests/%s/%s.json?auth=%s" % [DB_URL, uid, sender_name, id_token]
	var http_remove := HTTPRequest.new()
	add_child(http_remove)

	http_remove.request_completed.connect(func(_r, code, _h, _b):
		http_remove.queue_free()
		if code == 200:
			print("✅ Removed friend request from:", sender_name)
			_add_each_other_as_friends(uid, sender_name, id_token)
		else:
			push_warning("❌ Failed to remove request (%s)" % code)
	)

	http_remove.request(remove_url, [], HTTPClient.METHOD_DELETE)


# ======================================================
# 🔗 ADD EACH OTHER AS FRIENDS (Realtime)
# ======================================================
func _add_each_other_as_friends(uid: String, sender_name: String, id_token: String) -> void:
	var query_url = "%s:runQuery" % FIRESTORE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": sender_name}
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
		if code != 200:
			push_warning("❌ Failed to find sender UID.")
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0 or not arr[0].has("document"):
			push_warning("⚠️ Sender UID not found.")
			return

		var sender_uid = arr[0]["document"]["name"].get_file()
		print("[Realtime] Found sender UID:", sender_uid)

		var user_name = Auth.current_username
		var paths = [
			["%s/friends/%s/%s.json?auth=%s" % [DB_URL, uid, sender_name, id_token], "true"],
			["%s/friends/%s/%s.json?auth=%s" % [DB_URL, sender_uid, user_name, id_token], "true"]
		]

		for p in paths:
			var http_add := HTTPRequest.new()
			add_child(http_add)
			http_add.request(p[0], [], HTTPClient.METHOD_PUT, p[1])

		print("✅ Added each other as friends:", sender_name)
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))
	
	# ======================================================
# 📨 ADD REQUEST TO UI
# ======================================================
func _add_request_to_ui(sender_name: String) -> void:
	var hbox = HBoxContainer.new()

	var lbl = Label.new()
	lbl.text = sender_name
	lbl.custom_minimum_size = Vector2(150, 24)
	hbox.add_child(lbl)

	var accept_btn = Button.new()
	accept_btn.text = "✅"
	accept_btn.pressed.connect(func():
		accept_friend(sender_name)
		hbox.queue_free()
	)
	hbox.add_child(accept_btn)

	requests_container.add_child(hbox)
	print("[UI] 📨 Friend request UI updated with:", sender_name)


# ======================================================
# 👥 ADD FRIEND TO UI
# ======================================================
func _add_friend_to_ui(friend_name: String) -> void:
	var hbox = HBoxContainer.new()

	var lbl = Label.new()
	lbl.text = friend_name
	lbl.custom_minimum_size = Vector2(150, 24)
	hbox.add_child(lbl)

	var unfriend_btn = Button.new()
	unfriend_btn.text = "❌"
	unfriend_btn.pressed.connect(func():
		unfriend_user(friend_name)
		hbox.queue_free()
	)
	hbox.add_child(unfriend_btn)

	friend_container.add_child(hbox)
	print("[UI] 👥 Friend added to UI:", friend_name)
