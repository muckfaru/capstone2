extends Panel

@onready var room_list: VBoxContainer = $LobbyPanel/RoomListContainer
@onready var create_btn: Button = $LobbyPanel/CreateRoomButton
@onready var back_btn: Button = $LobbyPanel/BackButton

var _rooms: Array = []

var _multiplayer_config: Node = null
var _lobby_server_url: String = ""
var _poll_timer: Timer = null

const POLL_INTERVAL := 5.0

func _ready() -> void:
	_initialize_multiplayer_config()

	if create_btn:
		create_btn.pressed.connect(_on_create_room_pressed)
	else:
		push_warning("[DefuseTrojanLobby] CreateRoomButton not found")

	if back_btn:
		back_btn.pressed.connect(_on_back_button_pressed)
	else:
		push_warning("[DefuseTrojanLobby] BackButton not found")

	# Lobby always shows multiplayer rooms; CREATE opens a popup asking Single vs Multiplayer
	_start_room_polling()


func _start_singleplayer() -> void:
	get_tree().set_meta("defuse_trojan_arena_init", {
		"mode": "single"
	})
	get_tree().change_scene_to_file("res://scene/defuse_trojan_arena.tscn")


func _on_back_button_pressed() -> void:
	# Embedded panel pattern (like CodeBreakerLobby/AkashicLobby)
	self.visible = false

	var landing = get_node_or_null("/root/Landing")
	if landing:
		var game_select = landing.get_node_or_null("VideoStreamPlayer/GameSelectPanel")
		if game_select:
			game_select.visible = true
		else:
			push_error("[DefuseTrojanLobby] GameSelectPanel not found")
	else:
		push_error("[DefuseTrojanLobby] Landing node not found")


func _on_create_room_pressed() -> void:
	# First show mode selection popup (Single vs Multiplayer)
	var mode_popup_scene := load("res://scene/defuse_trojan_mode_popup.tscn")
	if not mode_popup_scene:
		push_error("[DefuseTrojanLobby] defuse_trojan_mode_popup.tscn not found")
		return
	var mode_popup: Window = mode_popup_scene.instantiate()
	add_child(mode_popup)
	mode_popup.popup_centered()

	mode_popup.single_selected.connect(func():
		_start_singleplayer()
	)
	mode_popup.multiplayer_selected.connect(func():
		_open_create_room_popup()
	)


func _open_create_room_popup() -> void:
	if _lobby_server_url == "":
		push_error("[DefuseTrojanLobby] Lobby server URL not set")
		return

	var popup_scene := load("res://scene/CreateRoomPopup.tscn")
	if not popup_scene:
		push_error("[DefuseTrojanLobby] CreateRoomPopup.tscn not found")
		return

	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()

	if popup.has_method("init_with_username"):
		popup.init_with_username(Auth.current_username if Auth else "Player")

	popup.confirmed.connect(func(room_name: String, anonymous: bool):
		popup.queue_free()
		await _create_room_and_enter(room_name, anonymous)
	)
	popup.canceled.connect(func():
		popup.queue_free()
	)


func _create_room_and_enter(room_name: String, anonymous: bool) -> void:
	if create_btn:
		create_btn.disabled = true
		create_btn.text = "Waking Server..."

	await _ping_server_to_wake()

	if create_btn:
		create_btn.text = "Creating..."

	var uid: String = Auth.current_local_id if Auth else "anonymous"
	var username: String = Auth.current_username if Auth and Auth.current_username != "" else room_name
	var level: int = (Auth.current_level if Auth else 1)
	var avatar: String = Auth.current_avatar if Auth and Auth.current_avatar != "" else "default.png"

	var final_room_name := room_name.strip_edges()
	if final_room_name == "":
		final_room_name = ("Anonymous" if anonymous else username)

	var body := {
		"host_id": uid,
		"host_username": ("Anonymous" if anonymous else username),
		"host_avatar": avatar,
		"host_level": level,
		"room_name": final_room_name,
		"game_type": "defuse_trojan",
		"max_players": 3,
		"host_card_bg": (Auth.current_card_bg_path if Auth else "")
	}

	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)

	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()

		if create_btn:
			create_btn.disabled = false
			create_btn.text = "CREATE ROOM"

		if code != 200:
			push_error("[DefuseTrojanLobby] Failed to create room. HTTP %d" % code)
			return

		var resp = JSON.parse_string(resp_body.get_string_from_utf8())
		if resp == null or typeof(resp) != TYPE_DICTIONARY:
			push_error("[DefuseTrojanLobby] Invalid JSON response")
			return

		var created_room_id := str(resp.get("room_id", ""))
		if created_room_id == "":
			push_error("[DefuseTrojanLobby] No room_id returned")
			return

		var init := {
			"room_id": created_room_id,
			"host_name": ("Anonymous" if anonymous else username),
			"is_host": true,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("defuse_trojan_room_init", init)

		var room_scene := load("res://scene/defuse_trojan_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[DefuseTrojanLobby] defuse_trojan_room.tscn not found")
	)

	var api_url = _multiplayer_config.get_api_endpoint("/api/rooms/create")
	var request_headers := ["Content-Type: application/json"]
	var request_error = http.request(api_url, request_headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if request_error != OK:
		http.queue_free()
		push_error("[DefuseTrojanLobby] HTTP request failed: %d" % request_error)


func _start_room_polling() -> void:
	if _poll_timer and is_instance_valid(_poll_timer):
		return
	if _lobby_server_url == "":
		push_warning("[DefuseTrojanLobby] Cannot poll rooms - lobby server URL not set")
		return

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_fetch_rooms_from_lobby)
	add_child(_poll_timer)

	_fetch_rooms_from_lobby()


func _stop_room_polling() -> void:
	if _poll_timer and is_instance_valid(_poll_timer):
		_poll_timer.stop()
		_poll_timer.queue_free()
	_poll_timer = null


func _fetch_rooms_from_lobby() -> void:
	if _lobby_server_url == "":
		return

	var url := _lobby_server_url + "/api/rooms/list?game_type=defuse_trojan"
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_result, code, _headers, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[DefuseTrojanLobby] Fetch rooms failed HTTP %d" % code)
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			push_warning("[DefuseTrojanLobby] Invalid response format")
			return

		_populate_rooms_from_lobby(data.get("rooms", []))
	)

	var err := http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		push_error("[DefuseTrojanLobby] Failed to send request: %d" % err)


func _populate_rooms_from_lobby(rooms_data) -> void:
	if room_list:
		for child in room_list.get_children():
			child.queue_free()

	_rooms.clear()

	if typeof(rooms_data) != TYPE_ARRAY or rooms_data.is_empty():
		return

	var my_uid: String = Auth.current_local_id if Auth else ""

	for room in rooms_data:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		if str(room.get("game_type", "")) != "defuse_trojan":
			continue
		if str(room.get("status", "waiting")) != "waiting":
			continue

		var room_id: String = str(room.get("room_id", ""))
		var room_name: String = str(room.get("room_name", "Unnamed Room"))
		var host_info = room.get("host", {})
		var host_pid: String = str(host_info.get("player_id", "")) if typeof(host_info) == TYPE_DICTIONARY else ""

		# Don't show rooms created by current user
		if host_pid != "" and host_pid == my_uid:
			continue

		var current_players: int = int(room.get("current_players", 1))
		# Defuse Trojan supports up to 3 players; older rooms may still report 2.
		var server_max: int = int(room.get("max_players", 3))
		var max_players: int = maxi(3, server_max)
		var joinable := current_players < max_players
		
		print("[DefuseTrojanLobby] Room %s: current=%d, server_max=%d, max=%d, joinable=%s" % [room_id, current_players, server_max, max_players, joinable])

		var entry := {
			"id": room_id,
			"room_name": room_name,
			"players_text": "%d/%d" % [current_players, max_players],
			"joinable": joinable
		}
		_rooms.append(entry)
		_add_room_row(entry)


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

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = str(entry.get("room_name", "?"))
	h.add_child(name_label)

	var players_label := Label.new()
	players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_label.custom_minimum_size = Vector2(0, 28)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	players_label.text = str(entry.get("players_text", "1/3"))
	h.add_child(players_label)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(100, 28)
	action_btn.text = "JOIN"
	var is_joinable := bool(entry.get("joinable", false))
	action_btn.disabled = not is_joinable

	# Normal style
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("b651ff")
	btn_normal.set_corner_radius_all(15)
	btn_normal.content_margin_left = 8.0
	btn_normal.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("normal", btn_normal)

	# Hover style
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color("b651ff")
	btn_hover.set_corner_radius_all(15)
	btn_hover.content_margin_left = 8.0
	btn_hover.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("hover", btn_hover)

	# Pressed style
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color("b651ff")
	btn_pressed.set_corner_radius_all(15)
	btn_pressed.content_margin_left = 8.0
	btn_pressed.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("pressed", btn_pressed)

	# Disabled style
	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.25, 0.25, 0.25, 0.7)
	btn_disabled.set_corner_radius_all(15)
	btn_disabled.content_margin_left = 8.0
	btn_disabled.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("disabled", btn_disabled)

	action_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	action_btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	action_btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	action_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

	print("[DefuseTrojanLobby] Room %s - joinable: %s, button disabled: %s" % [str(entry.get("id", "")), is_joinable, action_btn.disabled])
	action_btn.pressed.connect(func():
		var room_id := str(entry.get("id", ""))
		print("[DefuseTrojanLobby] JOIN button pressed for room: ", room_id)
		if room_id != "":
			_join_room_via_lobby(room_id)
	)
	h.add_child(action_btn)

	room_list.add_child(h)


func _join_room_via_lobby(room_id: String) -> void:
	if room_id == "" or _lobby_server_url == "":
		push_error("[DefuseTrojanLobby] Cannot join - missing room_id or lobby_server_url")
		return

	print("[DefuseTrojanLobby] Attempting to join room: ", room_id)
	
	var url := _lobby_server_url + "/api/rooms/" + room_id + "/join"
	var http := HTTPRequest.new()
	add_child(http)

	var uid: String = Auth.current_local_id if Auth else ""
	var username: String = Auth.current_username if Auth else "Player"
	var avatar: String = Auth.current_avatar if Auth else "default.png"
	var level: int = Auth.current_level if Auth else 1

	var body := {
		"client_id": uid,
		"client_username": username,
		"client_avatar": avatar,
		"client_level": level,
		"client_card_bg": (Auth.current_card_bg_path if Auth else "")
	}

	http.request_completed.connect(func(_result, code, _headers, response_body: PackedByteArray):
		http.queue_free()
		var response_str := response_body.get_string_from_utf8()
		
		if code != 200:
			push_error("[DefuseTrojanLobby] Join room failed HTTP %d: %s" % [code, response_str])
			# Show error to user
			var error_data = JSON.parse_string(response_str)
			var error_msg := "Failed to join room"
			if typeof(error_data) == TYPE_DICTIONARY:
				error_msg = str(error_data.get("error", error_msg))
			print("[DefuseTrojanLobby] Join error: ", error_msg)
			return

		var data = JSON.parse_string(response_str)
		if typeof(data) != TYPE_DICTIONARY:
			push_error("[DefuseTrojanLobby] Invalid join response")
			return

		var host_name: String = str(data.get("host_username", "Host"))
		var init := {
			"room_id": room_id,
			"host_name": host_name,
			"is_host": false,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("defuse_trojan_room_init", init)

		var room_scene := load("res://scene/defuse_trojan_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[DefuseTrojanLobby] defuse_trojan_room.tscn not found")
	)

	var headers := ["Content-Type: application/json"]
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		push_error("[DefuseTrojanLobby] Failed to send join request: %d" % err)


func _initialize_multiplayer_config() -> void:
	if has_node("/root/MultiplayerConfig"):
		_multiplayer_config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = _multiplayer_config.get_lobby_url()
	else:
		var cfg_script = load("res://script/MultiplayerConfig.gd")
		if cfg_script:
			_multiplayer_config = cfg_script.new()
			add_child(_multiplayer_config)
			_lobby_server_url = _multiplayer_config.get_lobby_url()
		else:
			push_error("[DefuseTrojanLobby] MultiplayerConfig not found")
			_lobby_server_url = ""


func _ping_server_to_wake() -> void:
	if _multiplayer_config == null:
		return

	var ping_http := HTTPRequest.new()
	ping_http.timeout = 60.0
	add_child(ping_http)

	var state := {"completed": false}
	ping_http.request_completed.connect(func(_r: int, _code: int, _h: PackedStringArray, _body: PackedByteArray):
		state["completed"] = true
		ping_http.queue_free()
	)

	var ping_url = _multiplayer_config.get_api_endpoint("/ping")
	ping_http.request(ping_url)

	var wait_time := 0.0
	while not state["completed"] and wait_time < 5.0:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5

	await get_tree().create_timer(0.5).timeout
