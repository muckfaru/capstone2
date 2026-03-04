extends Panel

@onready var room_list: VBoxContainer = $LobbyPanel/RoomListContainer
@onready var create_btn: Button = $LobbyPanel/CreateRoomButton
@onready var back_btn: Button = $LobbyPanel/BackButton # Added back button reference
var _rooms: Array = []

var _multiplayer_config: Node = null
var _lobby_server_url: String = ""

const POLL_INTERVAL := 5.0
var _poll_timer: Timer = null

# Tutorial check variables
var _tutorial_checked := false
var _tutorial_completed := false

func _ready() -> void:
	_initialize_multiplayer_config()
	print("[AkashicLobby] Lobby URL: ", _lobby_server_url)
	
	# Wire create room button
	if create_btn:
		create_btn.pressed.connect(_on_create_room_pressed)
	else:
		push_warning("[AkashicLobby] CreateRoomButton not found")

	# Wire back button
	if back_btn:
		back_btn.pressed.connect(_on_back_button_pressed)
	else:
		push_warning("[AkashicLobby] BackButton not found")

	# Poll room list periodically (tutorial check moved to landing.gd)
	_start_room_polling()


# 🔹 Back button function (copied and adapted)
func _on_back_button_pressed() -> void:
	print("[AkashicLobby] Back button pressed - returning to GameSelectPanel")
	
	# Hide this lobby
	self.visible = false
	
	# Show GameSelectPanel
	var landing = get_node_or_null("/root/Landing")
	if landing:
		var game_select = landing.get_node_or_null("VideoStreamPlayer/GameSelectPanel")
		if game_select:
			game_select.visible = true
			print("[AkashicLobby] GameSelectPanel is now visible")
		else:
			push_error("[AkashicLobby] GameSelectPanel not found")
	else:
		push_error("[AkashicLobby] Landing node not found")


func _on_create_room_pressed() -> void:
	print("[AkashicLobby] Create Room clicked")
	var popup_scene := load("res://scene/CreateRoomPopup.tscn")
	if not popup_scene:
		push_error("[AkashicLobby] CreateRoomPopup.tscn not found")
		return
	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()

	# Initialize with current username when available
	if popup.has_method("init_with_username"):
		popup.init_with_username(Auth.current_username if Auth else "Player")

	# Wait for confirmation
	popup.confirmed.connect(func(room_name: String, anonymous: bool):
		popup.queue_free()
		_create_room_and_enter(room_name, anonymous)
	)
	popup.canceled.connect(func():
		popup.queue_free()
	)


func _create_room_and_enter(room_name: String, anonymous: bool) -> void:
	if _lobby_server_url == "":
		push_error("[AkashicLobby] Lobby server URL not set")
		return
	
	if create_btn:
		create_btn.disabled = true
		create_btn.text = "Waking server..."
	await _ping_server_to_wake()
	if create_btn:
		create_btn.text = "Creating room..."
	
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
		"game_type": "akashic_tcg",
		"host_card_bg": (Auth.current_card_bg_path if Auth else "")
	}
	
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, resp_body: PackedByteArray):
		if create_btn:
			create_btn.disabled = false
			create_btn.text = "CREATE ROOM"
		
		http.queue_free()
		if code != 200:
			push_error("[AkashicLobby] Failed to create room. HTTP %d" % code)
			return
		var resp = JSON.parse_string(resp_body.get_string_from_utf8())
		if resp == null or typeof(resp) != TYPE_DICTIONARY:
			push_error("[AkashicLobby] Invalid JSON response")
			return
		var room_id: String = str(resp.get("room_id", ""))
		if room_id == "":
			push_error("[AkashicLobby] No room_id returned")
			return
		print("[AkashicLobby] ✅ Room created: ", room_id)
		var init := {
			"room_id": room_id,
			"host_name": ("Anonymous" if anonymous else username),
			"is_host": true,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("tgc_room_init", init)
		var room_scene := load("res://scene/akashic_tcg_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[AkashicLobby] akashic_tcg_room.tscn not found")
	)
	
	var api_url = _multiplayer_config.get_api_endpoint("/api/rooms/create")
	var headers := ["Content-Type: application/json"]
	var request_error = http.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if request_error != OK:
		push_error("[AkashicLobby] HTTP request failed: %d" % request_error)
		http.queue_free()


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
	players_label.text = entry.get("players_text", "1/2")
	h.add_child(players_label)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(100, 28)
	action_btn.size_flags_horizontal = 0
	action_btn.text = "JOIN"
	action_btn.disabled = not bool(entry.get("joinable", false))

	# Normal style
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("bd0003")
	btn_normal.set_corner_radius_all(15)
	btn_normal.content_margin_left = 8.0
	btn_normal.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("normal", btn_normal)

	# Hover style
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color("bd0003")
	btn_hover.set_corner_radius_all(15)
	btn_hover.content_margin_left = 8.0
	btn_hover.content_margin_right = 8.0
	action_btn.add_theme_stylebox_override("hover", btn_hover)

	# Pressed style
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color("bd0003")
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

	action_btn.pressed.connect(func():
		_join_room_via_lobby(str(entry.get("id", "")))
	)
	h.add_child(action_btn)

	room_list.add_child(h)

func _start_room_polling() -> void:
	if _lobby_server_url == "":
		push_warning("[AkashicLobby] Cannot poll rooms - lobby server URL not set")
		return
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = true
	_poll_timer.one_shot = false
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_fetch_rooms_from_lobby()

func _on_poll_timeout() -> void:
	_fetch_rooms_from_lobby()

func _fetch_rooms_from_lobby() -> void:
	if _lobby_server_url == "":
		return
	var url := _lobby_server_url + "/api/rooms/list?game_type=akashic_tcg"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code, _headers, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[AkashicLobby] Fetch rooms failed HTTP %d" % code)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			push_warning("[AkashicLobby] Invalid response format")
			return
		var rooms_data = data.get("rooms", [])
		_populate_rooms_from_lobby(rooms_data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _populate_rooms_from_lobby(rooms_data) -> void:
	# Clear list
	if room_list:
		for c in room_list.get_children():
			c.queue_free()
	_rooms.clear()
	
	if typeof(rooms_data) != TYPE_ARRAY or rooms_data.is_empty():
		return
	
	var current_uid: String = Auth.current_local_id if Auth else ""
	for room in rooms_data:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		if str(room.get("game_type", "")) != "akashic_tcg":
			continue
		if str(room.get("status", "waiting")) != "waiting":
			continue
		var room_id: String = str(room.get("room_id", ""))
		if room_id == "":
			continue
		var room_name: String = str(room.get("room_name", "Unnamed Room"))
		var host_info = room.get("host", {})
		var host_username: String = str(host_info.get("username", "Host")) if typeof(host_info) == TYPE_DICTIONARY else "Host"
		# /list response hides host uid; prevent joining own room is best-effort (handled server-side anyway)
		var player_count: int = int(room.get("current_players", 1))
		var max_players: int = int(room.get("max_players", 2))
		var joinable: bool = player_count < max_players
		# If we can't see host uid, allow join button; server will reject if needed
		var entry := {
			"id": room_id,
			"room_name": room_name,
			"players_text": str(player_count) + "/" + str(max_players),
			"joinable": joinable,
			"host_username": host_username,
			"_current_uid": current_uid
		}
		_rooms.append(entry)
		_add_room_row(entry)

func _join_room_via_lobby(room_id: String) -> void:
	if room_id == "":
		return
	if _lobby_server_url == "":
		push_error("[AkashicLobby] Cannot join - lobby server URL not set")
		return

	var uid: String = Auth.current_local_id if Auth else ""
	var username: String = Auth.current_username if Auth else "Player"
	var avatar: String = Auth.current_avatar if Auth else "avatar1.png"
	var level: int = Auth.current_level if Auth else 1

	# Validate room before join (prevents joining your own room; avoids full rooms)
	var get_http := HTTPRequest.new()
	add_child(get_http)
	get_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		get_http.queue_free()
		if code != 200:
			push_warning("[AkashicLobby] Could not read room before join HTTP %d" % code)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data == null or typeof(data) != TYPE_DICTIONARY:
			return
		var host = data.get("host", {})
		if typeof(host) == TYPE_DICTIONARY:
			var host_id := str(host.get("player_id", ""))
			if host_id != "" and host_id == uid and uid != "":
				push_warning("[AkashicLobby] Refusing to join your own room")
				return
		if data.get("client", null) != null:
			push_warning("[AkashicLobby] Room already full")
			_fetch_rooms_from_lobby()
			return
		_post_join_room(room_id, uid, username, avatar, level)
	)
	get_http.request(_lobby_server_url + "/api/rooms/" + room_id, [], HTTPClient.METHOD_GET)

func _post_join_room(room_id: String, uid: String, username: String, avatar: String, level: int) -> void:
	var url := _lobby_server_url + "/api/rooms/" + room_id + "/join"
	var http := HTTPRequest.new()
	add_child(http)
	var body := {
		"client_id": uid,
		"client_username": username,
		"client_avatar": avatar,
		"client_level": level,
		"client_card_bg": (Auth.current_card_bg_path if Auth else "")
	}
	http.request_completed.connect(func(_result, code, _headers, response_body: PackedByteArray):
		http.queue_free()
		var raw := response_body.get_string_from_utf8()
		if code != 200:
			push_error("[AkashicLobby] Join failed HTTP %d response: %s" % [code, raw])
			return
		var resp = JSON.parse_string(raw)
		if typeof(resp) != TYPE_DICTIONARY:
			push_error("[AkashicLobby] Invalid join response")
			return
		var host_name: String = str(resp.get("host_username", "Host"))
		var init := {
			"room_id": room_id,
			"host_name": host_name,
			"is_host": false,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("tgc_room_init", init)
		var room_scene := load("res://scene/akashic_tcg_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[AkashicLobby] akashic_tcg_room.tscn not found")
	)
	var headers := ["Content-Type: application/json"]
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		push_error("[AkashicLobby] Failed to send join request: %d" % err)

func _initialize_multiplayer_config() -> void:
	if has_node("/root/MultiplayerConfig"):
		_multiplayer_config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = _multiplayer_config.get_lobby_url()
	else:
		push_error("[AkashicLobby] MultiplayerConfig autoload not found!")
		var script = load("res://script/MultiplayerConfig.gd")
		if script:
			_multiplayer_config = script.new()
			add_child(_multiplayer_config)
			_lobby_server_url = _multiplayer_config.get_lobby_url()

func _ping_server_to_wake() -> void:
	if _multiplayer_config == null:
		return
	var ping_http := HTTPRequest.new()
	ping_http.timeout = 60.0
	add_child(ping_http)
	var done := {"ok": false}
	ping_http.request_completed.connect(func(_r: int, _code: int, _h: PackedStringArray, _b: PackedByteArray):
		done["ok"] = true
		ping_http.queue_free()
	)
	var ping_url = _multiplayer_config.get_api_endpoint("/ping")
	ping_http.request(ping_url)
	var wait_time := 0.0
	while not done["ok"] and wait_time < 5.0:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
	await get_tree().create_timer(0.5).timeout


# ============================================
# TUTORIAL SYSTEM FUNCTIONS
# ============================================

func _check_tutorial_status() -> void:
	"""Check if player has completed the AkashicTCG tutorial"""
	print("[AkashicLobby] Checking tutorial status...")
	
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[AkashicLobby] No auth state, skipping tutorial check")
		_tutorial_checked = true
		_tutorial_completed = true
		_start_room_polling()
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % user_id
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		_tutorial_checked = true
		
		if code != 200:
			print("[AkashicLobby] Could not fetch user data, assuming first time")
			_tutorial_completed = false
			_show_tutorial_prompt()
			return
		
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("fields"):
			print("[AkashicLobby] Invalid response, assuming first time")
			_tutorial_completed = false
			_show_tutorial_prompt()
			return
		
		var fields = json["fields"]
		if fields.has("akashic_tcg_tutorial_completed"):
			var val = fields["akashic_tcg_tutorial_completed"]
			if val.has("booleanValue") and val["booleanValue"] == true:
				print("[AkashicLobby] ✅ Tutorial already completed")
				_tutorial_completed = true
				_start_room_polling()
				return
		
		print("[AkashicLobby] 🆕 First time player detected!")
		_tutorial_completed = false
		_show_tutorial_prompt()
	)
	
	var headers = ["Authorization: Bearer %s" % id_token]
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[AkashicLobby] Failed to check tutorial status")
		http.queue_free()
		_tutorial_checked = true
		_tutorial_completed = true
		_start_room_polling()


func _show_tutorial_prompt() -> void:
	"""Show Pokemon-style tutorial prompt popup"""
	print("[AkashicLobby] Showing tutorial prompt...")
	
	var popup_scene = load("res://scene/akashic_tcg_tutorial_prompt.tscn")
	if not popup_scene:
		push_error("[AkashicLobby] Tutorial prompt scene not found!")
		_start_room_polling()
		return
	
	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()
	
	# Get button references
	var yes_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/YesButton")
	var no_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/NoButton")
	
	if yes_btn:
		yes_btn.pressed.connect(func():
			popup.queue_free()
			_go_to_tutorial()
		)
	
	if no_btn:
		no_btn.pressed.connect(func():
			popup.queue_free()
			_skip_tutorial()
		)


func _go_to_tutorial() -> void:
	"""Navigate to the tutorial arena"""
	print("[AkashicLobby] 🎮 Going to tutorial arena...")
	var tutorial_scene = load("res://scene/akashic_tcg_tutorial_arena.tscn")
	if tutorial_scene:
		get_tree().change_scene_to_packed(tutorial_scene)
	else:
		push_error("[AkashicLobby] Tutorial arena scene not found!")
		_start_room_polling()


func _skip_tutorial() -> void:
	"""Player chose to skip tutorial, mark as complete and continue"""
	print("[AkashicLobby] Player skipped tutorial")
	_tutorial_completed = true
	
	# Mark as complete in Firestore so we don't ask again
	_mark_tutorial_skipped()
	
	# Continue to normal lobby
	_start_room_polling()


func _mark_tutorial_skipped() -> void:
	"""Mark tutorial as completed in Firestore when skipped"""
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=akashic_tcg_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"akashic_tcg_tutorial_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[AkashicLobby] ✅ Tutorial skip saved to Firestore")
		else:
			push_warning("[AkashicLobby] Failed to save tutorial skip")
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		http.queue_free()
