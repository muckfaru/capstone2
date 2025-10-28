extends Panel

@onready var room_list: VBoxContainer = $LobbyPanel/RoomListContainer
@onready var create_btn: Button = $LobbyPanel/CreateRoomButton
@onready var back_btn: Button = $LobbyPanel/BackButton  # Add this line

var _rooms: Array = []
const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const POLL_INTERVAL := 5.0
const ROOMS_PATH := "/codebreaker_rooms"

var _refresh_timer: Timer

func _ready() -> void:
	# Wire create room button
	if create_btn:
		create_btn.pressed.connect(_on_create_room_pressed)
	else:
		push_warning("[CodeBreakerLobby] CreateRoomButton not found")

	# Wire back button
	if back_btn:
		back_btn.pressed.connect(_on_back_button_pressed)
	else:
		push_warning("[CodeBreakerLobby] BackButton not found")

	# Poll room list periodically
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = POLL_INTERVAL
	_refresh_timer.autostart = true
	_refresh_timer.one_shot = false
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_on_refresh_timeout)

	_fetch_rooms()


# New function to handle back button
func _on_back_button_pressed() -> void:
	print("[CodeBreakerLobby] Back button pressed - returning to GameSelectPanel")
	
	# Hide this lobby
	self.visible = false
	
	# Show GameSelectPanel
	var landing = get_node_or_null("/root/Landing")
	if landing:
		var game_select = landing.get_node_or_null("VideoStreamPlayer/GameSelectPanel")
		if game_select:
			game_select.visible = true
			print("[CodeBreakerLobby] GameSelectPanel is now visible")
		else:
			push_error("[CodeBreakerLobby] GameSelectPanel not found")
	else:
		push_error("[CodeBreakerLobby] Landing node not found")


func _on_create_room_pressed() -> void:
	print("[CodeBreakerLobby] Create Room clicked")
	var popup_scene := load("res://scene/CreateRoomPopup.tscn")
	if not popup_scene:
		push_error("[CodeBreakerLobby] CreateRoomPopup.tscn not found")
		return
	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()

	if popup.has_method("init_with_username"):
		popup.init_with_username(Auth.current_username if Auth else "Player")

	popup.confirmed.connect(func(room_name: String, anonymous: bool):
		popup.queue_free()
		_create_room_and_enter(room_name, anonymous)
	)
	popup.canceled.connect(func():
		popup.queue_free()
	)


func _create_room_and_enter(room_name: String, anonymous: bool) -> void:
	var id_token := Auth.current_id_token if Auth else ""
	var uid := Auth.current_local_id if Auth else ""
	var username := Auth.current_username if Auth and Auth.current_username != "" else room_name
	var level := 0

	var body := {
		"host": {
			"uid": uid,
			"username": ("Anonymous" if anonymous else username),
			"level": level,
			"status": "ready"
		},
		"client": null,
		"state": "waiting",
		"max_players": 2,
		"visibility": "public",
		"timestamp_created": int(Time.get_unix_time_from_system())
	}

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_error("[CodeBreakerLobby] Failed to create room. HTTP " + str(code))
			return
		var resp = JSON.parse_string(resp_body.get_string_from_utf8())
		var room_id: String = str(resp.get("name", ""))
		if room_id == "":
			push_error("[CodeBreakerLobby] No room id returned from RTDB")
			return
		print("[CodeBreakerLobby] Room created in RTDB:", room_id)
		var init := {
			"room_id": room_id,
			"host_name": str(body["host"]["username"]),
			"is_host": true,
		}
		get_tree().set_meta("code_breaker_room_init", init)
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[CodeBreakerLobby] code_breaker_room.tscn not found")
	)

	var url := RTDB_BASE + ROOMS_PATH + ".json" + ("?auth=" + id_token if id_token != "" else "")
	var headers := ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func _add_room_row(entry: Dictionary) -> void:
	if not room_list:
		return
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 28)

	var idx_label := Label.new()
	idx_label.custom_minimum_size = Vector2(50, 28)
	idx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idx_label.text = str(_rooms.size())
	h.add_child(idx_label)

	var user_label := Label.new()
	user_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_label.text = str(entry.get("host", "?"))
	h.add_child(user_label)

	var players_label := Label.new()
	players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_label.custom_minimum_size = Vector2(0, 28)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	players_label.text = entry.get("players_text", "1/2")
	h.add_child(players_label)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(100, 28)
	action_btn.size_flags_horizontal = 0
	action_btn.text = "JOIN"
	action_btn.disabled = not bool(entry.get("joinable", false))
	action_btn.pressed.connect(func():
		_join_room(str(entry.get("id", "")))
	)
	h.add_child(action_btn)

	room_list.add_child(h)

func _on_refresh_timeout() -> void:
	_fetch_rooms()

func _fetch_rooms() -> void:
	var url := RTDB_BASE + ROOMS_PATH + ".json"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerLobby] Fetch rooms failed HTTP " + str(code))
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		_populate_rooms_from_data(data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _populate_rooms_from_data(data) -> void:
	for c in room_list.get_children():
		c.queue_free()
	_rooms.clear()

	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return

	for room_id in data.keys():
		var node = data[room_id]
		if typeof(node) != TYPE_DICTIONARY:
			continue
		if node.get("visibility", "public") != "public":
			continue
		var host_val = node.get("host", null)
		var client_val = node.get("client", null)
		var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY and host_val.size() > 0
		var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0
		var host_dict: Dictionary = (host_val if host_present else {})
		var host_name := str(host_dict.get("username", "?"))
		var players_count := (1 if host_present else 0) + (1 if client_present else 0)
		var players_text := str(players_count) + "/2"
		var current_uid := Auth.current_local_id if Auth else ""
		var joinable: bool = (players_count < 2) and host_present and (str(host_dict.get("uid", "")) != current_uid)
		var entry := {
			"id": room_id,
			"host": host_name,
			"players_text": players_text,
			"joinable": joinable
		}
		_rooms.append(entry)
		_add_room_row(entry)

func _join_room(room_id: String) -> void:
	if room_id == "":
		return
	var id_token := Auth.current_id_token if Auth else ""
	var uid := Auth.current_local_id if Auth else ""
	var username := Auth.current_username if Auth else "Player"
	var level := 0
	var get_http := HTTPRequest.new()
	add_child(get_http)
	get_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		get_http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerLobby] Failed to read room before join " + str(code))
			return
		var node = JSON.parse_string(body.get_string_from_utf8())
		if not node or typeof(node) != TYPE_DICTIONARY:
			return
		if node.get("client", null) != null:
			push_warning("[CodeBreakerLobby] Room already has a client")
			_fetch_rooms()
			return
		var host_name_in_room := str(node.get("host", {}).get("username", ""))
		var client_username := ("Anonymous" if host_name_in_room == "Anonymous" else username)
		var patch_body := {
			"client": {"uid": uid, "username": client_username, "level": level, "status": "not_ready"}
		}
		var patch_http := HTTPRequest.new()
		add_child(patch_http)
		patch_http.request_completed.connect(func(_r2, code2, _h2, _b2):
			patch_http.queue_free()
			if code2 != 200:
				push_error("[CodeBreakerLobby] Join failed HTTP " + str(code2))
				return
			var init := {"room_id": room_id, "host_name": str(node.get("host", {}).get("username", "Host")), "is_host": false}
			get_tree().set_meta("code_breaker_room_init", init)
			var room_scene := load("res://scene/code_breaker_room.tscn")
			if room_scene:
				get_tree().change_scene_to_packed(room_scene)
			else:
				push_error("[CodeBreakerLobby] code_breaker_room.tscn not found")
		)
		var patch_url := RTDB_BASE + ROOMS_PATH + "/" + room_id + ".json" + ("?auth=" + id_token if id_token != "" else "")
		patch_http.request(patch_url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_body))
	)
	var get_url := RTDB_BASE + ROOMS_PATH + "/" + room_id + ".json"
	get_http.request(get_url, [], HTTPClient.METHOD_GET)
