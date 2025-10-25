extends Panel

@onready var friend_container: VBoxContainer = $FriendListVBox
@onready var requests_container: VBoxContainer = $FriendRequestsVBox
@onready var add_input: LineEdit = $AddFriendHBox/FriendUIDInput
@onready var add_button: Button = $AddFriendHBox/AddFriendButton

# 🔹 Firebase Config
const PROJECT_ID: String = "capstone-823dc"
const BASE_URL: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
const RTDB_BASE: String = "https://capstone-823dc-default-rtdb.firebaseio.com"

var refresh_timer := Timer.new()
var presence_timer := Timer.new()
var last_friend_list: Array = []
var last_request_list: Array = []
var username_to_uid: Dictionary = {}
var friend_label_map: Dictionary = {}
var currently_open_chat: String = ""

# ======================================================
# 🔸 READY
# ======================================================
func _ready():
	print("[FriendList] Ready.")
	
	# Wait longer for ChatManager to initialize
	await get_tree().create_timer(3.0).timeout
	if ChatManager and ChatManager._initialized:
		ChatManager.set_current_user(Auth.current_username)
		print("[FriendList] ChatManager initialized, user set")
	else:
		print("[FriendList] ChatManager not ready, will retry on chat open")

	refresh_timer.wait_time = 5.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(func():
		load_friend_requests()
		load_friend_list()
	)
	add_child(refresh_timer)

	presence_timer.wait_time = 3.0
	presence_timer.autostart = true
	presence_timer.timeout.connect(func():
		refresh_presence_all()
	)
	add_child(presence_timer)

	add_button.pressed.connect(func():
		var target = add_input.text.strip_edges()
		if target == "":
			return
		add_button.disabled = true
		send_friend_request(target)
		await get_tree().create_timer(1.0).timeout
		add_button.disabled = false
	)

	load_friend_requests()
	load_friend_list()


# ======================================================
# 📥 LOAD FRIEND REQUESTS
# ======================================================
func load_friend_requests() -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "":
		push_warning("⚠️ Missing Auth info.")
		return

	var url = "%s/users/%s" % [BASE_URL, uid]
	var headers = ["Authorization: Bearer %s" % token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data.has("fields"):
			return

		var new_requests: Array = []
		if data["fields"].has("requests_received"):
			var arr = data["fields"]["requests_received"].get("arrayValue", {})
			if arr.has("values"):
				for v in arr["values"]:
					var sender = v.get("stringValue", "")
					if sender != "":
						new_requests.append(sender)

		if new_requests != last_request_list:
			last_request_list = new_requests.duplicate()
			print("[UI] 🔄 Friend requests changed → refreshing UI")
			_update_request_ui(new_requests)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


# ======================================================
# 📜 LOAD FRIEND LIST
# ======================================================
func load_friend_list() -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "":
		return

	var url = "%s/users/%s" % [BASE_URL, uid]
	var headers = ["Authorization: Bearer %s" % token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data.has("fields"):
			return

		var new_friends: Array = []
		if data["fields"].has("friends"):
			var arr = data["fields"]["friends"].get("arrayValue", {})
			if arr.has("values"):
				for v in arr["values"]:
					var friend_name = v.get("stringValue", "")
					if friend_name != "":
						new_friends.append(friend_name)

		if new_friends != last_friend_list:
			last_friend_list = new_friends.duplicate()
			print("[UI] 🔄 Friend list changed → refreshing UI")
			_update_friend_ui(new_friends)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


# ======================================================
# 🧾 UPDATE FRIEND REQUESTS UI (with fade-in)
# ======================================================
func _update_request_ui(requests: Array) -> void:
	for child in requests_container.get_children():
		child.queue_free()

	for sender in requests:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = sender
		hbox.add_child(lbl)

		var accept_btn = Button.new()
		accept_btn.text = "✅"
		accept_btn.pressed.connect(func():
			accept_friend_request(sender)
			hbox.queue_free()
		)
		hbox.add_child(accept_btn)

		var decline_btn = Button.new()
		decline_btn.text = "❌"
		decline_btn.pressed.connect(func():
			decline_friend_request(sender)
			hbox.queue_free()
		)
		hbox.add_child(decline_btn)

		hbox.modulate.a = 0
		requests_container.add_child(hbox)
		var tween = create_tween()
		tween.tween_property(hbox, "modulate:a", 1.0, 0.25)


# ======================================================
# 🧾 UPDATE FRIEND LIST UI (with fade-in + BADGES)
# ======================================================
func _update_friend_ui(friends: Array) -> void:
	for child in friend_container.get_children():
		child.queue_free()
	friend_label_map.clear()

	for name in friends:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = name
		hbox.add_child(lbl)

		var chat_btn = Button.new()
		chat_btn.text = "💬"
		chat_btn.tooltip_text = "Chat"
		chat_btn.custom_minimum_size = Vector2(40, 30)
		chat_btn.pressed.connect(func():
			_on_chat_button_pressed(name)
		)
		hbox.add_child(chat_btn)
		
		# 🔴 ADD BADGE TO CHAT BUTTON
		if is_instance_valid(ChatManager):
			# Wait for button to be added to tree and have size
			await get_tree().process_frame
			
			var badge = BadgeNotification.new()
			badge.set_user_id(name)
			# Position badge at top-right corner of button
			badge.position = Vector2(chat_btn.size.x - 22, -8)
			badge.z_index = 100
			chat_btn.add_child(badge)
			
			print("[FriendList] Created badge for user: ", name)
			
			# Initialize unread tracking for this friend
			ChatManager.initialize_unread_for_friend(name)
			
			# Update badge position when button resizes
			chat_btn.resized.connect(func():
				if is_instance_valid(badge):
					badge.position = Vector2(chat_btn.size.x - 22, -8)
			)

		var unfriend_btn = Button.new()
		unfriend_btn.text = "❌"
		unfriend_btn.tooltip_text = "Unfriend"
		unfriend_btn.pressed.connect(func():
			unfriend_user(name)
			hbox.queue_free()
		)
		hbox.add_child(unfriend_btn)

		friend_label_map[name] = lbl
		_start_presence_check(name, lbl)

		hbox.modulate.a = 0
		friend_container.add_child(hbox)
		var tween = create_tween()
		tween.tween_property(hbox, "modulate:a", 1.0, 0.25)


# -------------------------
# Resolve username -> uid (cached) and then fetch RTDB presence
# -------------------------
func _start_presence_check(username: String, label: Label) -> void:
	var token = Auth.current_id_token
	if token == "" or username == "":
		label.text = "🔴 %s" % username
		return

	# if cached uid exists, fetch presence directly
	if username_to_uid.has(username):
		var cached_uid: String = str(username_to_uid[username])
		_fetch_presence_for_uid(cached_uid, label, username, token)
		return

	# else resolve uid via runQuery and cache it
	var query_url = "%s:runQuery" % BASE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": username}
				}
			},
			"limit": 1
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var http_q := HTTPRequest.new()
	add_child(http_q)
	http_q.request_completed.connect(func(_r, code, _h, body):
		http_q.queue_free()
		if code != 200:
			label.text = "🔴 %s" % username
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			label.text = "🔴 %s" % username
			return

		var friend_uid = arr[0]["document"]["name"].get_file()
		# cache uid for future checks (store as String explicitly)
		username_to_uid[username] = str(friend_uid)
		_fetch_presence_for_uid(friend_uid, label, username, token)
	)
	http_q.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# -------------------------
# Refresh presence for all displayed friends
# -------------------------
func refresh_presence_all() -> void:
	# iterate a shallow copy to avoid mutation issues
	for username in friend_label_map.keys():
		var lbl = friend_label_map[username]
		_start_presence_check(username, lbl)


# -------------------------
# Query RTDB presence path and update label
# -------------------------
func _fetch_presence_for_uid(uid: String, label: Label, username: String, token: String) -> void:
	var url = "%s/presence/%s.json?auth=%s" % [RTDB_BASE, uid, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			label.text = "🔴 %s" % username
			return

		var txt: String = body.get_string_from_utf8()
		var parsed = null
		if txt != "null" and txt != "":
			var try_parse = JSON.parse_string(txt)
			if typeof(try_parse) == TYPE_DICTIONARY:
				parsed = try_parse
			else:
				var raw: String = txt
				if raw.begins_with("\"") and raw.ends_with("\"") and raw.length() >= 2:
					raw = raw.substr(1, raw.length() - 2)
				raw = raw.strip_edges()
				parsed = {"state": raw}

		var state := ""
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("state"):
			state = str(parsed["state"])
		else:
			state = "offline"

		if state == "online":
			label.text = "🟢 %s" % username
		else:
			label.text = "🔴 %s" % username
	)
	http.request(url, [], HTTPClient.METHOD_GET)


# ======================================================
# 💔 UNFRIEND USER
# ======================================================
func unfriend_user(friend_name: String) -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "":
		return

	print("[FriendList] Unfriending:", friend_name)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var query_url = "%s:runQuery" % BASE_URL
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": friend_name}
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
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			return

		var friend_uid = arr[0]["document"]["name"].get_file()
		var my_name = Auth.current_username

		var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
		var commit_body = {
			"writes": [
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, uid],
						"fieldTransforms": [{
							"fieldPath": "friends",
							"removeAllFromArray": {"values": [{"stringValue": friend_name}]}
						}]
					}
				},
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, friend_uid],
						"fieldTransforms": [{
							"fieldPath": "friends",
							"removeAllFromArray": {"values": [{"stringValue": my_name}]}
						}]
					}
				}
			]
		}
		var http_commit := HTTPRequest.new()
		add_child(http_commit)
		http_commit.request_completed.connect(func(_r2, code2, _h2, _b2):
			http_commit.queue_free()
			if code2 == 200:
				print("[FriendList] Unfriended:", friend_name)
				await get_tree().create_timer(0.4).timeout
				load_friend_list()
		)
		http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# ➕ SEND FRIEND REQUEST
# ======================================================
func send_friend_request(target_username: String) -> void:
	if target_username == "" or target_username == Auth.current_username:
		push_error("[FriendList] Invalid target.")
		return

	var token = Auth.current_id_token
	var sender_uid = Auth.current_local_id
	if token == "" or sender_uid == "":
		return

	print("[FriendRequest] Sending to:", target_username)
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
		"Authorization: Bearer %s" % token
	]

	var http_query := HTTPRequest.new()
	add_child(http_query)
	http_query.request_completed.connect(func(_r, code, _h, body):
		http_query.queue_free()
		if code != 200:
			push_warning("[FriendRequest] Query failed.")
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			push_warning("[FriendRequest] User not found.")
			return

		var target_uid = arr[0]["document"]["name"].get_file()
		var sender_url = "%s/users/%s" % [BASE_URL, sender_uid]
		var http_sender := HTTPRequest.new()
		add_child(http_sender)
		http_sender.request_completed.connect(func(_r2, code2, _h2, body2):
			http_sender.queue_free()
			if code2 != 200:
				return

			var data2 = JSON.parse_string(body2.get_string_from_utf8())
			var sender_name = data2["fields"]["username"]["stringValue"]

			var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
			var commit_body = {
				"writes": [{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, target_uid],
						"fieldTransforms": [{
							"fieldPath": "requests_received",
							"append_missing_elements": {
								"values": [{"stringValue": sender_name}]
							}
						}]
					}
				}]
			}
			var http_commit := HTTPRequest.new()
			add_child(http_commit)
			http_commit.request_completed.connect(func(_r3, code3, _h3, _b3):
				http_commit.queue_free()
				if code3 == 200:
					print("[FriendRequest] Friend request sent to:", target_username)
					add_input.text = ""
			)
			http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
		)
		http_sender.request(sender_url, headers, HTTPClient.METHOD_GET)
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# 🤝 ACCEPT FRIEND REQUEST
# ======================================================
func accept_friend_request(sender_name: String) -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "":
		return

	print("[FriendRequest] Accepting:", sender_name)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var query_url = "%s:runQuery" % BASE_URL
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

	var http_query := HTTPRequest.new()
	add_child(http_query)
	http_query.request_completed.connect(func(_r, code, _h, body):
		http_query.queue_free()
		if code != 200:
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			return

		var sender_uid = arr[0]["document"]["name"].get_file()
		var my_name = Auth.current_username

		var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
		var commit_body = {
			"writes": [
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, uid],
						"fieldTransforms": [
							{
								"fieldPath": "friends",
								"appendMissingElements": {"values": [{"stringValue": sender_name}]}
							},
							{
								"fieldPath": "requests_received",
								"removeAllFromArray": {"values": [{"stringValue": sender_name}]}
							}
						]
					}
				},
				{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, sender_uid],
						"fieldTransforms": [{
							"fieldPath": "friends",
							"appendMissingElements": {"values": [{"stringValue": my_name}]}
						}]
					}
				}
			]
		}
		var http_commit := HTTPRequest.new()
		add_child(http_commit)
		http_commit.request_completed.connect(func(_r2, code2, _h2, _b2):
			http_commit.queue_free()
			if code2 == 200:
				print("[FriendRequest] Accepted:", sender_name)
				await get_tree().create_timer(0.5).timeout
				load_friend_requests()
				load_friend_list()
		)
		http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# ======================================================
# 🚫 DECLINE FRIEND REQUEST
# ======================================================
func decline_friend_request(sender_name: String) -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "":
		return

	print("[FriendRequest] Declining:", sender_name)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
	var commit_body = {
		"writes": [{
			"transform": {
				"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, uid],
				"fieldTransforms": [{
					"fieldPath": "requests_received",
					"removeAllFromArray": {"values": [{"stringValue": sender_name}]}
				}]
			}
		}]
	}

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[FriendRequest] Declined friend request from:", sender_name)
			load_friend_requests()
	)
	http.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))


# ======================================================
# 💬 CHAT BUTTON HANDLER (TOGGLE)
# ======================================================
func _on_chat_button_pressed(friend_username: String) -> void:
	print("[FriendList] Chat button pressed for: ", friend_username)
	
	# If same friend, toggle close
	if currently_open_chat == friend_username:
		print("[FriendList] Closing chat with: ", friend_username)
		var chat_panel = get_tree().root.find_child("ChatPanel", true, false)
		if chat_panel:
			chat_panel.visible = false
		currently_open_chat = ""
		return
	
	# Otherwise, open new chat
	if ChatManager.current_user_id == "":
		ChatManager.set_current_user(Auth.current_username)
	
	# Mark chat as read when opening
	ChatManager.mark_chat_as_read(friend_username)
	
	# Try multiple ways to find ChatPanel
	var chat_panel = get_tree().root.find_child("ChatPanel", true, false)
	
	if not chat_panel:
		print("[FriendList] ChatPanel not found with find_child, trying get_node...")
		try_to_find_chat_panel(friend_username)
		return
	
	print("[FriendList] ChatPanel found!")
	if chat_panel.has_method("open_chat_with"):
		chat_panel.open_chat_with(friend_username, friend_username)
		chat_panel.visible = true
		currently_open_chat = friend_username
		print("[FriendList] Chat opened with: ", friend_username)
	else:
		push_error("[FriendList] ChatPanel doesn't have 'open_chat_with' method")


func try_to_find_chat_panel(friend_username: String) -> void:
	# Try different paths based on your scene structure
	var possible_paths = [
		"/root/ChatPanel",
		"/root/Landing/ChatPanel",
		"/root/MainScene/ChatPanel",
		"/root/UI/ChatPanel",
	]
	
	for path in possible_paths:
		if get_tree().root.has_node(path):
			var chat_panel = get_tree().root.get_node(path)
			print("[FriendList] Found ChatPanel at: ", path)
			if chat_panel.has_method("open_chat_with"):
				chat_panel.open_chat_with(friend_username, friend_username)
				chat_panel.visible = true
				return
			return
	
	# Last resort: print all nodes to debug
	print("[FriendList] ChatPanel not found at any known path!")
	print("[FriendList] Available nodes in scene tree:")
	debug_print_tree(get_tree().root, 0)


func debug_print_tree(node: Node, depth: int) -> void:
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		debug_print_tree(child, depth + 1)
