extends Panel

@onready var friend_container: VBoxContainer = $FriendListScroll/FriendListVBox
@onready var requests_container: VBoxContainer = $FriendRequestsScroll/FriendRequestsVBox
@onready var _friend_row_template: PanelContainer = $_TemplateFriendRow
@onready var _request_row_template: PanelContainer = $_TemplateRequestRow
@onready var add_input: LineEdit = $AddFriendHBox/FriendUIDInput
@onready var add_button: Button = $AddFriendHBox/AddFriendButton

# Header buttons
@onready var close_button: Button = $closebutton
@onready var settings_button: Button = $settings
@onready var minimize_button: Button = $minimize
@onready var add_friend_toggle_btn: Button = $addfriendbutton
@onready var search_friends_btn: Button = $searchfriends
@onready var add_friend_hbox: HBoxContainer = $AddFriendHBox
@onready var exit_confirm_popup: Panel = $ExitConfirmPopup

# Own profile nodes
@onready var own_profile_pic: TextureRect = $"user profile and status/userprofile/profilepicture"
@onready var own_username_label: Label = $"user profile and status/Usernamelabel"
@onready var own_status_label: Label = $"user profile and status/statuslabel"
@onready var own_presence_dot: PanelContainer = $"user profile and status/status"

# Search state
var search_input_field: LineEdit = null
var search_active: bool = false
var unfiltered_friends: Array = []

# Own presence timer
var own_presence_timer := Timer.new()

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

# Make presence icon smaller (adjust as needed)
const PRESENCE_ICON_SIZE := 10
const PRESENCE_ICON_TOP_OFFSET := 8 # increased to align dot with username baseline

# Transparent button style
var transparent_button_style: StyleBoxFlat

# ======================================================
# 🔸 READY
# ======================================================
func _ready():
	print("[FriendList] Ready.")
	
	# Create transparent button style
	transparent_button_style = StyleBoxFlat.new()
	transparent_button_style.bg_color = Color(0, 0, 0, 0)  # Fully transparent

	# Wire up timers and buttons immediately (before any await)
	refresh_timer.wait_time = 5.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(func():
		load_friend_requests()
		_load_friend_accepts_rtdb()
		load_friend_list()
		_load_own_profile()
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
		var has_uid: bool = Auth.current_local_id != ""
		var has_token: bool = Auth.current_id_token != ""
		print("[FriendList] Add clicked target='%s' uid=%s token=%s" % [target, str(has_uid), str(has_token)])
		if target == "":
			push_warning("[FriendList] Add clicked with empty target.")
			return
		add_button.disabled = true
		send_friend_request(target)
		await get_tree().create_timer(1.0).timeout
		add_button.disabled = false
	)

	_setup_header_buttons()
	_setup_search_input()
	_load_own_profile()
	_start_own_presence_polling()

	load_friend_requests()
	load_friend_list()

	# ChatManager needs extra time — defer so _ready() has no await
	call_deferred("_init_chat_manager")


func _init_chat_manager() -> void:
	await get_tree().create_timer(3.0).timeout
	if ChatManager:
		ChatManager.set_current_user(Auth.current_username)
		print("[FriendList] ChatManager initialized, user set")
	else:
		print("[FriendList] ChatManager not ready, will retry on chat open")


# ======================================================
# � HEADER BUTTONS (Close / Settings / Minimize / AddFriend / Search)
# ======================================================
func _setup_header_buttons() -> void:
	# ── Close: show exit confirmation popup
	close_button.pressed.connect(func():
		exit_confirm_popup.visible = true
	)

	# ── Exit popup — YES quits the game, NO dismisses
	exit_confirm_popup.get_node("ButtonRow/YesButton").pressed.connect(func():
		get_tree().quit()
	)
	exit_confirm_popup.get_node("ButtonRow/NoButton").pressed.connect(func():
		exit_confirm_popup.visible = false
	)

	# ── Settings: open landing's MenuPanel exactly like the MenuButton does,
	#    and hide the landing MenuButton to avoid duplicates while the panel is open
	settings_button.pressed.connect(func():
		var menu_panel = get_tree().root.find_child("MenuPanel", true, false)
		if menu_panel:
			menu_panel.visible = true
			menu_panel.move_to_front()
		var menu_btn = get_tree().root.find_child("MenuButton", true, false)
		if menu_btn:
			menu_btn.visible = false
			# Restore the button once the menu panel closes
			if menu_panel and not menu_panel.has_meta("_fl_restore_connected"):
				menu_panel.set_meta("_fl_restore_connected", true)
				menu_panel.visibility_changed.connect(func():
					if not menu_panel.visible:
						menu_btn.visible = true
						menu_panel.set_meta("_fl_restore_connected", false)
				)
	)

	# ── Minimize: collapse the OS window
	minimize_button.pressed.connect(func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	)

	# ── Add Friend toggle: show/hide the AddFriendHBox input row
	add_friend_toggle_btn.pressed.connect(func():
		add_friend_hbox.visible = not add_friend_hbox.visible
		if add_friend_hbox.visible:
			add_input.grab_focus()
		else:
			add_input.text = ""
	)


# ======================================================
# 🔍 SEARCH INPUT (filter friend list in real-time)
# ======================================================
func _setup_search_input() -> void:
	# Use the pre-built SearchInputField node from the scene (fully editable in the editor)
	search_input_field = $SearchInputField
	search_input_field.text_changed.connect(_on_search_text_changed)

	# Wire search button to toggle the LineEdit
	search_friends_btn.pressed.connect(func():
		search_active = not search_active
		search_input_field.visible = search_active
		if search_active:
			search_input_field.grab_focus()
		else:
			search_input_field.text = ""
			_on_search_text_changed("")   # restore full list
	)


func _on_search_text_changed(text: String) -> void:
	var filter := text.strip_edges().to_lower()
	if filter == "":
		# Show all friends
		_update_friend_ui(unfiltered_friends if unfiltered_friends.size() > 0 else last_friend_list)
		return

	var filtered: Array = []
	for f in last_friend_list:
		if str(f).to_lower().contains(filter):
			filtered.append(f)
	_update_friend_ui(filtered)


# ======================================================
# 👤 OWN PROFILE — realtime fetch (avatar + username + presence)
# ======================================================
func _load_own_profile() -> void:
	var uid   := Auth.current_local_id
	var token := Auth.current_id_token
	if uid == "" or token == "":
		# Not authenticated yet; show cached username if available
		if Auth.current_username != "":
			own_username_label.text = str(Auth.current_username).to_upper()
		return

	# Update username label from cache immediately
	if Auth.current_username != "":
		own_username_label.text = str(Auth.current_username).to_upper()

	# Load avatar from Auth cache first (instant)
	_apply_own_avatar(str(Auth.current_avatar))

	# Then fetch fresh data from Firestore
	var url     := "%s/users/%s" % [BASE_URL, uid]
	var headers := ["Authorization: Bearer %s" % token]
	var http    := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("fields"):
			return
		var fields: Dictionary = data["fields"]

		# Username
		var uname: String = fields.get("username", {}).get("stringValue", str(Auth.current_username))
		if uname != "":
			own_username_label.text = uname.to_upper()

		# Avatar
		var avatar_file: String = fields.get("avatar", {}).get("stringValue", "")
		if avatar_file != "":
			_apply_own_avatar(avatar_file)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _apply_own_avatar(avatar_file: String) -> void:
	if not is_instance_valid(own_profile_pic):
		return
	if avatar_file == "" or avatar_file == "default.png":
		return

	var tex: Texture2D = null
	if avatar_file.begins_with("res://"):
		tex = load(avatar_file) as Texture2D
	elif avatar_file.begins_with("user://"):
		var img := Image.new()
		if img.load(avatar_file) == OK:
			img.resize(80, 80)
			tex = ImageTexture.create_from_image(img)
	else:
		var path := "res://asset/avatars/%s" % avatar_file
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D

	if tex:
		own_profile_pic.texture = tex


# ── Own presence polling ──────────────────────────────
func _start_own_presence_polling() -> void:
	own_presence_timer.wait_time = 5.0
	own_presence_timer.autostart = true
	own_presence_timer.timeout.connect(_poll_own_presence)
	add_child(own_presence_timer)
	# Immediate first check
	_poll_own_presence()


func _poll_own_presence() -> void:
	var uid   := Auth.current_local_id
	var token := Auth.current_id_token
	if uid == "" or token == "":
		_apply_own_presence("offline")
		return

	var url  := "%s/presence/%s.json?auth=%s" % [RTDB_BASE, uid, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			_apply_own_presence("offline")
			return
		var txt: String = body.get_string_from_utf8()
		var state: String = "offline"
		if txt != "null" and txt != "":
			var parsed = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("state"):
				state = str(parsed["state"])
			elif typeof(parsed) == TYPE_STRING:
				state = parsed.strip_edges().trim_prefix("\"").trim_suffix("\"")
		_apply_own_presence(state)
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _apply_own_presence(state: String) -> void:
	if not is_instance_valid(own_presence_dot) or not is_instance_valid(own_status_label):
		return

	match state:
		"online":
			# Green dot
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.0, 0.85, 0.45, 1.0)
			sbox.corner_radius_top_left    = 40
			sbox.corner_radius_top_right   = 40
			sbox.corner_radius_bottom_right = 40
			sbox.corner_radius_bottom_left  = 40
			own_presence_dot.add_theme_stylebox_override("panel", sbox)
			own_status_label.text = "🟢 Online"
		"away":
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(1.0, 0.75, 0.0, 1.0)
			sbox.corner_radius_top_left    = 40
			sbox.corner_radius_top_right   = 40
			sbox.corner_radius_bottom_right = 40
			sbox.corner_radius_bottom_left  = 40
			own_presence_dot.add_theme_stylebox_override("panel", sbox)
			own_status_label.text = "🟡 Away"
		_:
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.55, 0.0, 0.1, 1.0)
			sbox.corner_radius_top_left    = 40
			sbox.corner_radius_top_right   = 40
			sbox.corner_radius_bottom_right = 40
			sbox.corner_radius_bottom_left  = 40
			own_presence_dot.add_theme_stylebox_override("panel", sbox)
			own_status_label.text = "🔴 Offline"


# ======================================================
# �📥 LOAD FRIEND REQUESTS
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
			# Firestore read failed; still try RTDB fallback
			_load_friend_requests_rtdb([])
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data.has("fields"):
			return

		var from_firestore: Array = []
		if data["fields"].has("requests_received"):
			var arr = data["fields"]["requests_received"].get("arrayValue", {})
			if arr.has("values"):
				for v in arr["values"]:
					var sender = v.get("stringValue", "")
					if sender != "":
						from_firestore.append(sender)

		# Merge with RTDB-based requests (works even when Firestore queries are blocked)
		_load_friend_requests_rtdb(from_firestore)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _load_friend_requests_rtdb(existing: Array) -> void:
	var token = Auth.current_id_token
	var my_username := str(Auth.current_username)
	if token == "" or my_username == "":
		_update_requests_if_changed(existing)
		return

	var url = "%s/friend_requests/%s.json?auth=%s" % [RTDB_BASE, my_username.uri_encode(), token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		var merged: Array = existing.duplicate()
		if code == 200:
			var txt: String = body.get_string_from_utf8()
			if txt != "" and txt != "null":
				var parsed = JSON.parse_string(txt)
				if typeof(parsed) == TYPE_DICTIONARY:
					for sender_name in parsed.keys():
						var s := str(sender_name)
						if s != "" and not merged.has(s):
							merged.append(s)
		_update_requests_if_changed(merged)
	)
	http.request(url, [], HTTPClient.METHOD_GET)


func _update_requests_if_changed(new_requests: Array) -> void:
	if new_requests != last_request_list:
		last_request_list = new_requests.duplicate()
		print("[UI] 🔄 Friend requests changed → refreshing UI")
		_update_request_ui(new_requests)


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
			unfiltered_friends = new_friends.duplicate()
			print("[UI] 🔄 Friend list changed → refreshing UI")
			# Respect active search filter
			if search_active and is_instance_valid(search_input_field) and search_input_field.text.strip_edges() != "":
				_on_search_text_changed(search_input_field.text)
			else:
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
		var row: PanelContainer = _request_row_template.duplicate()
		row.visible = true
		row.get_node("RowHBox/SenderLabel").text = sender

		row.get_node("RowHBox/AcceptBtn").pressed.connect(func():
			accept_friend_request(sender)
			row.queue_free()
		)
		row.get_node("RowHBox/DeclineBtn").pressed.connect(func():
			decline_friend_request(sender)
			row.queue_free()
		)

		row.modulate.a = 0
		requests_container.add_child(row)
		var tween = create_tween()
		tween.tween_property(row, "modulate:a", 1.0, 0.25)


# ======================================================
# 🧾 UPDATE FRIEND LIST UI (with fade-in + BADGES)
# ======================================================
func _update_friend_ui(friends: Array) -> void:
	for child in friend_container.get_children():
		child.queue_free()
	friend_label_map.clear()

	for friend_name in friends:
		var row: PanelContainer = _friend_row_template.duplicate()
		row.visible = true
		row.get_node("RowHBox/NameLabel").text = friend_name

		# Presence icon — the script controls its text (🟢/🔴)
		var icon_lbl: Label = row.get_node("RowHBox/PresenceIcon")
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_presence_label(icon_lbl, friend_name, "offline")

		# Connect action buttons
		row.get_node("RowHBox/ProfileBtn").pressed.connect(func():
			_on_view_profile_button_pressed(friend_name)
		)
		var chat_btn: Button = row.get_node("RowHBox/ChatBtn")
		chat_btn.pressed.connect(func():
			_on_chat_button_pressed(friend_name)
		)
		row.get_node("RowHBox/UnfriendBtn").pressed.connect(func():
			unfriend_user(friend_name)
			row.queue_free()
		)

		# Store icon label for presence polling
		friend_label_map[friend_name] = icon_lbl
		_start_presence_check(friend_name, icon_lbl)

		row.modulate.a = 0
		friend_container.add_child(row)
		var tween = create_tween()
		tween.tween_property(row, "modulate:a", 1.0, 0.25)

		# Defer badge creation to next frame (don't block rendering)
		if is_instance_valid(ChatManager):
			await get_tree().process_frame
			_create_badge_for_chat_button(chat_btn, friend_name)


# -------------------------
# Helper: Create badge on chat button after it's rendered
# -------------------------
func _create_badge_for_chat_button(chat_btn: Button, friend_name: String) -> void:
	if not is_instance_valid(chat_btn):
		return
	
	var badge = BadgeNotification.new()
	badge.set_user_id(friend_name)
	badge.position = Vector2(8, -6)
	badge.z_index = 100
	chat_btn.add_child(badge)
	
	print("[FriendList] Created badge for user: ", friend_name)
	ChatManager.initialize_unread_for_friend(friend_name)


# -------------------------
# Refresh presence for all displayed friends
# -------------------------
func refresh_presence_all() -> void:
	# Create a copy of keys to avoid issues with freed nodes
	var usernames_to_check = friend_label_map.keys().duplicate()
	
	for username in usernames_to_check:
		# Check if label still exists and is valid
		if not friend_label_map.has(username):
			continue
		
		var lbl = friend_label_map[username]
		if not is_instance_valid(lbl):
			friend_label_map.erase(username)
			continue
		
		_start_presence_check(username, lbl)


# -------------------------
# Resolve username -> uid (cached) and then fetch RTDB presence
# -------------------------
func _start_presence_check(username: String, label: Control) -> void:
	# Check if label is still valid before proceeding
	if not is_instance_valid(label):
		return
	
	var token = Auth.current_id_token
	if token == "" or username == "":
		_set_presence_label(label, username, "offline")
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
			_set_presence_label(label, username, "offline")
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			_set_presence_label(label, username, "offline")
			return

		var friend_uid = arr[0]["document"]["name"].get_file()
		# cache uid for future checks (store as String explicitly)
		username_to_uid[username] = str(friend_uid)
		_fetch_presence_for_uid(friend_uid, label, username, token)
	)
	http_q.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


# -------------------------
# Query RTDB presence path and update label
# -------------------------
func _fetch_presence_for_uid(uid: String, label: Control, username: String, token: String) -> void:
	var url = "%s/presence/%s.json?auth=%s" % [RTDB_BASE, uid, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			_set_presence_label(label, username, "offline")
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

		# Check if label is still valid before updating
		if not is_instance_valid(label):
			return

		if state == "online":
			_set_presence_label(label, username, "online")
		else:
			_set_presence_label(label, username, "offline")
	)
	http.request(url, [], HTTPClient.METHOD_GET)


# ======================================================
# Helpers for presence label formatting (icon-only)
# ======================================================
func _format_presence(_username: String, state: String) -> String:
	return "🟢" if state == "online" else "🔴"

func _set_presence_label(label, username: String, state: String) -> void:
	if is_instance_valid(label) and label is Label:
		label.text = _format_presence(username, state)


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
		push_warning("[FriendRequest] Missing Auth token/uid. uid='%s' token_present=%s" % [str(sender_uid), str(token != "")])
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
			print("[FriendRequest] ❌ runQuery failed. code=%s body=%s" % [str(code), body.get_string_from_utf8()])
			# Firestore rules often block list/runQuery. Fall back to RTDB request bus.
			if code == 403:
				_send_friend_request_rtdb(target_username)
			return

		var arr = JSON.parse_string(body.get_string_from_utf8())
		if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
			print("[FriendRequest] ❌ User not found via runQuery: '%s'" % target_username)
			return
		if not arr[0].has("document") or not arr[0]["document"].has("name"):
			print("[FriendRequest] ❌ Unexpected runQuery result: %s" % body.get_string_from_utf8())
			return

		var target_uid = arr[0]["document"]["name"].get_file()
		print("[FriendRequest] ✅ Resolved target uid=%s for username=%s" % [str(target_uid), target_username])
		var sender_name := str(Auth.current_username)
		if sender_name == "":
			print("[FriendRequest] ❌ Sender username missing; cannot send request.")
			return

		_ensure_requests_received_field(target_uid, headers, func():
			print("[FriendRequest] Target field ready; committing request...")
			var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
			var commit_body = {
				"writes": [{
					"transform": {
						"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, target_uid],
						"fieldTransforms": [{
							"fieldPath": "requests_received",
							"appendMissingElements": {
								"values": [{"stringValue": sender_name}]
							}
						}]
					}
				}]
			}
			var http_commit := HTTPRequest.new()
			add_child(http_commit)
			http_commit.request_completed.connect(func(_r3, code3, _h3, b3):
				http_commit.queue_free()
				if code3 == 200:
					print("[FriendRequest] Friend request sent to:", target_username)
					add_input.text = ""
					# Optional verification fetch (may fail if rules block reading other users)
					var verify_url = "%s/users/%s" % [BASE_URL, target_uid]
					var http_verify := HTTPRequest.new()
					add_child(http_verify)
					http_verify.request_completed.connect(func(_vr, vcode, _vh, vbody):
						http_verify.queue_free()
						print("[FriendRequest] Verify GET target code=%s body=%s" % [str(vcode), vbody.get_string_from_utf8()])
					)
					http_verify.request(verify_url, headers, HTTPClient.METHOD_GET)
				else:
					print("[FriendRequest] ❌ Commit failed. code=%s body=%s" % [str(code3), b3.get_string_from_utf8()])
			)
			http_commit.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))
		)
	)
	http_query.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


func _send_friend_request_rtdb(target_username: String) -> void:
	var token = Auth.current_id_token
	var sender_name := str(Auth.current_username)
	if token == "" or sender_name == "" or target_username == "":
		print("[FriendRequest] RTDB fallback missing auth/username")
		return
	if target_username == sender_name:
		print("[FriendRequest] RTDB fallback cannot send to self")
		return

	var url = "%s/friend_requests/%s/%s.json?auth=%s" % [RTDB_BASE, target_username.uri_encode(), sender_name.uri_encode(), token]
	var body = {
		"timestamp": Time.get_unix_time_from_system()
	}
	var headers = ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp):
		http.queue_free()
		if code == 200:
			print("[FriendRequest] ✅ RTDB request queued for:", target_username)
			add_input.text = ""
		else:
			print("[FriendRequest] ❌ RTDB request failed. code=%s body=%s" % [str(code), resp.get_string_from_utf8()])
	)
	http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(body))


func _ensure_requests_received_field(target_uid: String, headers: Array, on_ready: Callable) -> void:
	# If the user doc doesn't have requests_received yet, Firestore transform may fail.
	# We initialize it once (only when missing) to an empty array.
	var url = "%s/users/%s" % [BASE_URL, target_uid]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			print("[FriendRequest] ❌ Target doc fetch failed. code=%s body=%s" % [str(code), body.get_string_from_utf8()])
			return

		var doc = JSON.parse_string(body.get_string_from_utf8())
		var needs_init := true
		if typeof(doc) == TYPE_DICTIONARY and doc.has("fields"):
			var fields = doc["fields"]
			if typeof(fields) == TYPE_DICTIONARY and fields.has("requests_received"):
				var rr = fields["requests_received"]
				if typeof(rr) == TYPE_DICTIONARY and rr.has("arrayValue"):
					needs_init = false

		if not needs_init:
			print("[FriendRequest] Target already has requests_received field.")
			on_ready.call()
			return

		print("[FriendRequest] Target missing requests_received; initializing...")

		var patch_url = "%s/users/%s?updateMask.fieldPaths=requests_received" % [BASE_URL, target_uid]
		var patch_body = {
			"fields": {
				"requests_received": {"arrayValue": {"values": []}}
			}
		}
		var http_patch := HTTPRequest.new()
		add_child(http_patch)
		http_patch.request_completed.connect(func(_r2, code2, _h2, body2):
			http_patch.queue_free()
			if code2 != 200:
				print("[FriendRequest] ❌ Target init failed. code=%s body=%s" % [str(code2), body2.get_string_from_utf8()])
				return
			print("[FriendRequest] ✅ Target init success.")
			on_ready.call()
		)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(patch_body))
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


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
			# If Firestore query is blocked, accept via owner-only Firestore update + RTDB notification.
			if code == 403:
				print("[FriendRequest] Firestore query blocked; accepting via RTDB fallback")
				_accept_friend_request_owner_only(sender_name)
				return
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


func _accept_friend_request_owner_only(sender_name: String) -> void:
	var token = Auth.current_id_token
	var my_username := str(Auth.current_username)
	if token == "" or my_username == "":
		return

	# 1) Add sender to MY Firestore friends list (owner-only write).
	_append_friend_to_my_firestore(sender_name)

	# 2) Remove incoming request from RTDB queue.
	_remove_friend_request_rtdb(my_username, sender_name)

	# 3) Notify sender via RTDB so they can add me locally.
	var url = "%s/friend_accepts/%s/%s.json?auth=%s" % [RTDB_BASE, sender_name.uri_encode(), my_username.uri_encode(), token]
	var body = {"timestamp": Time.get_unix_time_from_system()}
	var headers = ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp):
		http.queue_free()
		if code == 200:
			print("[FriendRequest] ✅ RTDB accept notify sent to:", sender_name)
		else:
			print("[FriendRequest] ❌ RTDB accept notify failed. code=%s body=%s" % [str(code), resp.get_string_from_utf8()])
	)
	http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(body))

	await get_tree().create_timer(0.5).timeout
	load_friend_requests()
	load_friend_list()


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

	# Also remove from RTDB queue (covers locked-down Firestore setups)
	_remove_friend_request_rtdb(str(Auth.current_username), sender_name)


func _remove_friend_request_rtdb(target_username: String, sender_name: String) -> void:
	var token = Auth.current_id_token
	if token == "" or target_username == "" or sender_name == "":
		return
	var url = "%s/friend_requests/%s/%s.json?auth=%s" % [RTDB_BASE, target_username.uri_encode(), sender_name.uri_encode(), token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			print("[FriendRequest] ✅ RTDB request removed for sender:", sender_name)
		else:
			print("[FriendRequest] ❌ RTDB remove failed. code=%s body=%s" % [str(code), body.get_string_from_utf8()])
	)
	http.request(url, [], HTTPClient.METHOD_DELETE)


func _append_friend_to_my_firestore(friend_name: String) -> void:
	var uid = Auth.current_local_id
	var token = Auth.current_id_token
	if uid == "" or token == "" or friend_name == "":
		return

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	var commit_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents:commit" % PROJECT_ID
	var commit_body = {
		"writes": [
			{
				"transform": {
					"document": "projects/%s/databases/(default)/documents/users/%s" % [PROJECT_ID, uid],
					"fieldTransforms": [
						{
							"fieldPath": "friends",
							"appendMissingElements": {"values": [{"stringValue": friend_name}]}
						}
					]
				}
			}
		]
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			print("[FriendList] ✅ Added friend to my Firestore doc:", friend_name)
			load_friend_list()
		else:
			print("[FriendList] ❌ Failed to add friend to my Firestore doc. code=%s body=%s" % [str(code), body.get_string_from_utf8()])
	)
	http.request(commit_url, headers, HTTPClient.METHOD_POST, JSON.stringify(commit_body))


func _load_friend_accepts_rtdb() -> void:
	var token = Auth.current_id_token
	var my_username := str(Auth.current_username)
	if token == "" or my_username == "":
		return

	var url = "%s/friend_accepts/%s.json?auth=%s" % [RTDB_BASE, my_username.uri_encode(), token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return
		var txt: String = body.get_string_from_utf8()
		if txt == "" or txt == "null":
			return
		var parsed = JSON.parse_string(txt)
		if typeof(parsed) != TYPE_DICTIONARY:
			return

		for accepter in parsed.keys():
			var friend_name := str(accepter)
			if friend_name == "":
				continue
			print("[FriendList] ✅ Detected accept from:", friend_name)
			_append_friend_to_my_firestore(friend_name)
			# Remove the accept notification after processing
			var del_url = "%s/friend_accepts/%s/%s.json?auth=%s" % [RTDB_BASE, my_username.uri_encode(), friend_name.uri_encode(), token]
			var http_del := HTTPRequest.new()
			add_child(http_del)
			http_del.request_completed.connect(func(_r2, _c2, _h2, _b2):
				http_del.queue_free()
			)
			http_del.request(del_url, [], HTTPClient.METHOD_DELETE)
	)
	http.request(url, [], HTTPClient.METHOD_GET)


# ======================================================
# 💬 CHAT BUTTON HANDLER (TOGGLE)
# ======================================================
func _on_chat_button_pressed(friend_username: String) -> void:
	print("[FriendList] Chat button pressed for: ", friend_username)
	
	# If same friend, toggle close
	if currently_open_chat == friend_username:
		print("[FriendList] Closing chat with: ", friend_username)
		var open_chat_panel = get_tree().root.find_child("ChatPanel", true, false)
		if open_chat_panel:
			open_chat_panel.visible = false
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


# ======================================================
# 🎫 VIEW PLAYER PROFILE BUTTON HANDLER
# ======================================================
func _on_view_profile_button_pressed(friend_username: String) -> void:
	print("[FriendList] View profile pressed for: ", friend_username)
	
	# Try to find ViewPlayerProfileModal in the scene tree
	var modal = get_tree().root.find_child("ViewPlayerProfileModal", true, false)
	
	if not modal:
		push_error("[FriendList] ViewPlayerProfileModal not found in scene tree")
		debug_print_tree(get_tree().root, 0)
		return
	
	# Call display_player_profile on the modal
	if modal.has_method("display_player_profile"):
		print("[FriendList] Displaying profile for: ", friend_username)
		modal.display_player_profile(friend_username)
		# Wait for profile data to load before showing
		await get_tree().create_timer(0.5).timeout
		modal.popup_centered()
	else:
		push_error("[FriendList] Modal doesn't have 'display_player_profile' method")
