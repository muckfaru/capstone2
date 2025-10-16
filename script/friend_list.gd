extends Control

# === UI References ===
@onready var http_main: HTTPRequest = $HTTPRequest_Main
@onready var http_friend: HTTPRequest = $HTTPRequest_Friends
@onready var http_request: HTTPRequest = $HTTPRequest_Requests
@onready var friend_list_vbox: VBoxContainer = $FriendListVBox
@onready var friend_requests_vbox: VBoxContainer = $FriendRequestsVBox
@onready var friend_uid_input: LineEdit = $AddFriendHBox/FriendUIDInput
@onready var add_friend_button: Button = $AddFriendHBox/AddFriendButton

# === Firebase Config ===
const DB_URL := "https://capstone-823dc-default-rtdb.firebaseio.com"

# === Auth info (loaded from Auth singleton) ===
var uid: String = ""
var id_token: String = ""

# Poll interval (seconds)
const REFRESH_INTERVAL := 3.0

# Flag to avoid overlapping refresh requests
var _is_refreshing: bool = false

# ---------------------------------------------------
func _ready():
	print("[FriendSystem] 🔄 Polling mode initialized (no SDK)")

	# Load Auth info (from Auth singleton)
	if Engine.has_singleton("Auth"):
		var auth = Engine.get_singleton("Auth")
		uid = auth.current_local_id
		id_token = auth.current_id_token
		print("[FriendSystem] ✅ Auth loaded → UID:", uid)
	else:
		push_error("❌ Auth singleton not found.")
		return

	add_friend_button.pressed.connect(_on_add_friend_pressed)

	# Set online status
	_set_online_status(true)

	# Start automatic polling
	_poll_loop()


# ---------------------------------------------------
# AUTO REFRESH LOOP (runs every 3s safely)
# ---------------------------------------------------
func _poll_loop():
	while is_inside_tree():
		if not _is_refreshing:
			await refresh_friend_lists()
		await get_tree().create_timer(REFRESH_INTERVAL).timeout


# ---------------------------------------------------
# REFRESH FRIEND + REQUEST LISTS
# ---------------------------------------------------
func refresh_friend_lists():
	if uid == "" or id_token == "":
		return

	if _is_refreshing:
		print("[FriendSystem] ⏳ Skipping refresh — still loading...")
		return

	_is_refreshing = true
	print("[FriendSystem] Refreshing friend lists...")

	_clear_container(friend_list_vbox)
	_clear_container(friend_requests_vbox)

	# --- FRIENDS ---
	var friends_url = "%s/users/%s/friends.json?auth=%s" % [DB_URL, uid, id_token]
	var err = http_friend.request(friends_url)
	if err != OK:
		push_error("[ERROR] Failed to request friends.")
		_is_refreshing = false
		return

	var result = await http_friend.request_completed
	var friends_body = result[3].get_string_from_utf8()
	var friends_data = JSON.parse_string(friends_body)

	if typeof(friends_data) == TYPE_DICTIONARY:
		for friend_uid in friends_data.keys():
			_add_friend_item(friend_uid)
	else:
		print("[FriendSystem] No friends found.")

	# --- REQUESTS ---
	var req_url = "%s/users/%s/requests_received.json?auth=%s" % [DB_URL, uid, id_token]
	var req_err = http_request.request(req_url)
	if req_err != OK:
		push_error("[ERROR] Failed to request friend requests.")
		_is_refreshing = false
		return

	var req_result = await http_request.request_completed
	var req_body = req_result[3].get_string_from_utf8()
	var req_data = JSON.parse_string(req_body)

	if typeof(req_data) == TYPE_DICTIONARY:
		for sender_uid in req_data.keys():
			_add_request_item(sender_uid)
	else:
		print("[FriendSystem] No friend requests found.")

	_is_refreshing = false
	print("[FriendSystem] ✅ Refresh done.")


# ---------------------------------------------------
# ADD FRIEND
# ---------------------------------------------------
func _on_add_friend_pressed():
	var target_uid = friend_uid_input.text.strip_edges()
	if target_uid == "" or target_uid == uid:
		return

	print("[FriendSystem] Sending friend request to:", target_uid)
	await _send_friend_request(uid, target_uid)
	friend_uid_input.text = ""


func _send_friend_request(from_uid: String, to_uid: String):
	print("[FriendSystem] Sending friend request...")

	# Fetch usernames
	var from_name = await _get_username(from_uid)
	var to_name = await _get_username(to_uid)

	if from_name == "" or to_name == "":
		push_warning("[FriendSystem] Missing usernames! Aborting request.")
		return

	var payload = JSON.stringify(true)

	# Write requests using usernames as keys
	var outgoing_url = "%s/users/%s/requests_sent/%s.json?auth=%s" % [DB_URL, from_uid, to_name, id_token]
	var incoming_url = "%s/users/%s/requests_received/%s.json?auth=%s" % [DB_URL, to_uid, from_name, id_token]

	await http_main.request(outgoing_url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, payload)
	await http_main.request_completed
	await http_main.request(incoming_url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, payload)
	await http_main.request_completed

	print("[FriendSystem] ✅ Friend request sent from %s → %s" % [from_name, to_name])

func _get_username(target_uid: String) -> String:
	if target_uid == "" or id_token == "":
		return ""

	var url = "%s/users/%s/username.json?auth=%s" % [DB_URL, target_uid, id_token]
	var err = http_main.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[FriendSystem] ❌ Failed to start username request for %s" % target_uid)
		return ""

	var result = await http_main.request_completed
	var body_bytes = result[3]
	if body_bytes.size() == 0:
		push_warning("[FriendSystem] ⚠ No username found for UID %s" % target_uid)
		return ""

	var username = body_bytes.get_string_from_utf8().strip_edges().replace('"', '')
	if username == "null" or username == "":
		push_warning("[FriendSystem] ⚠ Username is empty/null for %s" % target_uid)
		return ""
	print("[FriendSystem] 🔍 Username fetched:", username)
	return username



# ---------------------------------------------------
# ACCEPT / DECLINE / UNFRIEND
# ---------------------------------------------------
func _accept_friend_request(sender_name: String):
	print("[FriendSystem] Accepting friend request from:", sender_name)

	var my_name = await _get_username(uid)
	if my_name == "":
		push_error("[FriendSystem] Can't get current username.")
		return

	var payload = JSON.stringify(true)

	# Add both users to each other's friend lists
	var my_friend_url = "%s/users/%s/friends/%s.json?auth=%s" % [DB_URL, uid, sender_name, id_token]
	var their_friend_url = "%s/users/%s/friends/%s.json?auth=%s" % [DB_URL, sender_name, my_name, id_token]

	await http_main.request(my_friend_url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, payload)
	await http_main.request_completed
	await http_main.request(their_friend_url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, payload)
	await http_main.request_completed

	# Delete the pending requests
	var incoming_url = "%s/users/%s/requests_received/%s.json?auth=%s" % [DB_URL, uid, sender_name, id_token]
	var outgoing_url = "%s/users/%s/requests_sent/%s.json?auth=%s" % [DB_URL, sender_name, my_name, id_token]

	await http_main.request(incoming_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed
	await http_main.request(outgoing_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed

	print("[FriendSystem] ✅ Friend request accepted between %s and %s" % [my_name, sender_name])
	refresh_friend_lists()



func _decline_friend(sender_uid: String):
	print("[FriendSystem] Declining:", sender_uid)
	var in_url = "%s/users/%s/requests_received/%s.json?auth=%s" % [DB_URL, uid, sender_uid, id_token]
	var out_url = "%s/users/%s/requests_sent/%s.json?auth=%s" % [DB_URL, sender_uid, uid, id_token]
	http_main.request(in_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed
	http_main.request(out_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed
	refresh_friend_lists()


func _unfriend(friend_name: String):
	print("[FriendSystem] Unfriending:", friend_name)

	var my_name = await _get_username(uid)
	if my_name == "":
		push_error("[FriendSystem] Can't get current username.")
		return

	var a_url = "%s/users/%s/friends/%s.json?auth=%s" % [DB_URL, uid, friend_name, id_token]
	var b_url = "%s/users/%s/friends/%s.json?auth=%s" % [DB_URL, friend_name, my_name, id_token]

	await http_main.request(a_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed
	await http_main.request(b_url, [], HTTPClient.METHOD_DELETE)
	await http_main.request_completed

	print("[FriendSystem] 🗑 Unfriended:", friend_name)
	refresh_friend_lists()




# ---------------------------------------------------
# PRESENCE SYSTEM (simple online/offline flag)
# ---------------------------------------------------
func _set_online_status(is_online: bool) -> void:
	if uid == "" or id_token == "":
		return

	var url = "%s/users/%s/status.json?auth=%s" % [DB_URL, uid, id_token]
	var status = "offline"
	if is_online:
		status = "online"

	var payload = JSON.stringify(status)
	var err = http_main.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, payload)
	if err != OK:
		push_error("[Presence] Failed to set status: %s" % err)
	else:
		print("[Presence] %s → %s" % [uid, status])


func _notification(what):
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE]:
		_set_online_status(false)


# ---------------------------------------------------
# UI HELPERS
# ---------------------------------------------------
func _clear_container(container: Node):
	for c in container.get_children():
		c.queue_free()


func _add_friend_item(friend_uid: String):
	var hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = friend_uid
	hbox.add_child(name_label)

	var remove_btn = Button.new()
	remove_btn.text = "Unfriend"
	remove_btn.pressed.connect(func(): _unfriend(friend_uid))
	hbox.add_child(remove_btn)

	friend_list_vbox.add_child(hbox)


func _add_request_item(sender_uid: String):
	var hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = sender_uid
	hbox.add_child(name_label)

	var accept_btn = Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(func(): _accept_friend_request(sender_uid))
	hbox.add_child(accept_btn)

	var decline_btn = Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(func(): _decline_friend(sender_uid))
	hbox.add_child(decline_btn)

	friend_requests_vbox.add_child(hbox)    
	
	
	
	
	
