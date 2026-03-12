extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")


@onready var _room_id_label: Label = $RoomHeader/RoomIDLabel
@onready var _room_state_label: Label = $RoomHeader/RoomStateLabel
@onready var _host_username: Label = $CardsContainer/HostCard/Username
@onready var _host_level: Label = $CardsContainer/HostCard/Level
@onready var _host_status: Label = $CardsContainer/HostCard/StatusLabel
@onready var _client_username: Label = $CardsContainer/ClientCard/Username
@onready var _client_level: Label = $CardsContainer/ClientCard/Level
@onready var _client_status: Label = $CardsContainer/ClientCard/StatusLabel
@onready var _host_card_node: NinePatchRect = $CardsContainer/HostCard
@onready var _client_card_node: NinePatchRect = $CardsContainer/ClientCard
@onready var _message_label: Label = $MessageLabel
@onready var _start_btn: Button = $ButtonPanel/StartButton
@onready var _leave_btn: Button = $ButtonPanel/LeaveButton

var _client_animations_played: bool = false

# =============================================================================
# ARCHITECTURE: WebSocket Relay (Option B - No Port Forwarding Required)
# - RTDB: Room state, player info, ready status (UI coordination) - Legacy
# - WebSocket Relay: Both players connect to relay server for gameplay
# =============================================================================
const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const POLL_INTERVAL := 2.0
const ROOMS_PATH := "/codebreaker_rooms"

# Theme colors (Cyber Neon)
const COLOR_ACCENT := Color(0, 0.819608, 1, 1)       # cyan
const COLOR_DANGER := Color(1, 0.356863, 0.431373, 1) # pink-red
const COLOR_MUTED  := Color(0.560784, 0.639216, 0.678431, 1) # muted gray-blue

var _room_id: String = ""
var _is_host: bool = false
var _client_ready_via_relay: bool = false
var _client_ready_relay_value: bool = false
var _last_client_present: bool = false
var _poll_timer: Timer
var _transitioning_to_arena: bool = false

# WebSocket Relay
var _relay_client: Node = null
var _relay_connected: bool = false
var _connection_timeout: float = 10.0

# Heartbeat
var _heartbeat_timer: Timer = null
var _lobby_server_url: String = ""
const HEARTBEAT_INTERVAL := 30.0

# Game state
var _game_start_time: int = 0
var _latest_host_data: Dictionary = {}
var _latest_client_data: Dictionary = {}


func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_room_init"):
		init = get_tree().get_meta("code_breaker_room_init")
		get_tree().set_meta("code_breaker_room_init", null)

	var room_id: String   = str(init.get("room_id", "local"))
	var host_name: String = str(init.get("host_name", "Host"))
	var is_host: bool     = bool(init.get("is_host", false))

	_room_id = room_id
	_is_host = is_host

	print("[CodeBreakerRoom] Initialized - Room: %s, Host: %s, Is Host: %s" % [_room_id, host_name, _is_host])
	print("[CodeBreakerRoom] Using WebSocket Relay (Option B - No Port Forwarding)")

	_initialize_lobby_config()

	_SessionStore.save_session(
		_room_id,
		_lobby_server_url,
		Auth.current_local_id if Auth else "unknown",
		Auth.current_username if Auth else "Player",
		"room"
	)

	_room_id_label.text    = ""
	_room_state_label.text = "WAITING"

	_host_username.text = host_name
	_host_level.text    = ""
	_host_status.text   = "READY"

	_client_username.text = "."
	_client_level.text    = "."
	_client_status.text   = "Searching.."

	_message_label.text = "Waiting for player to join..."

	# -------------------------------------------------------------------------
	# Buttons: connect signals only — ALL visual styling lives in the .tscn
	# -------------------------------------------------------------------------
	_start_btn.pressed.connect(_on_start_pressed)
	_leave_btn.pressed.connect(_leave_room)

	# Polling
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot  = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_fetch_room()

	if _is_host:
		_start_heartbeat()

	await _setup_relay_connection()

	_configure_buttons()

	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize(RTDB_BASE, ROOMS_PATH, _room_id)


# =============================================================================
# BUTTON CONFIGURATION
# Script only controls: text, disabled state, toggle_mode, signal wiring.
# All StyleBoxFlat/color overrides are defined in the .tscn.
# =============================================================================

func _configure_buttons() -> void:
	if _is_host:
		_start_btn.toggle_mode = false
		_start_btn.button_pressed = false
		_start_btn.text     = "START MATCH"
		_start_btn.disabled = true
		if _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.disconnect(_on_ready_toggled)
	else:
		_start_btn.toggle_mode  = true
		_start_btn.button_pressed = false
		_start_btn.text     = "READY"
		_start_btn.disabled = false
		_client_status.text = "NOT READY"
		_client_status.add_theme_color_override("font_color", COLOR_DANGER)
		if not _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.connect(_on_ready_toggled)


func _on_ready_toggled(pressed: bool) -> void:
	_client_status.text = ("READY" if pressed else "NOT READY")
	_start_btn.text     = ("NOT READY" if pressed else "READY")
	_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))

	_client_ready_via_relay = true

	if _relay_client and _relay_connected:
		_relay_client.send_message({
			"type":   "player_status",
			"status": ("ready" if pressed else "not_ready")
		})
		print("[CodeBreakerRoom] Ready status sent via relay: ", ("ready" if pressed else "not_ready"))
	else:
		push_warning("[CodeBreakerRoom] Relay not connected, cannot send ready status")

	if _room_id == "":
		return
	var player_id := Auth.current_local_id if Auth else ""
	if player_id == "":
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[CodeBreakerRoom] ✅ Ready status updated on server")
		else:
			push_warning("[CodeBreakerRoom] Failed to update ready status on server: ", code)
	)

	var body := {"player_id": player_id, "ready": pressed}
	var url  := _lobby_server_url + "/api/rooms/" + _room_id + "/ready"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	print("[CodeBreakerRoom] Sending ready status to lobby server: ", pressed)


# =============================================================================
# RTDB POLLING
# =============================================================================

func _on_poll_timeout() -> void:
	_fetch_room()


func _fetch_room() -> void:
	if _room_id == "":
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Lobby poll failed HTTP " + str(code))
			return
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response == null or typeof(response) != TYPE_DICTIONARY:
			push_warning("[CodeBreakerRoom] Invalid lobby response")
			return
		if response.has("error"):
			print("[CodeBreakerRoom] Room closed by lobby server: ", response.get("error"))
			_message_label.text = "Room has been closed."
			_go_to_landing()
			return
		_apply_lobby_room_snapshot(response)
	)

	var url := _lobby_server_url + "/api/rooms/" + _room_id
	http.request(url, [], HTTPClient.METHOD_GET)


func _apply_lobby_room_snapshot(room_data: Dictionary) -> void:
	if not _transitioning_to_arena:
		var room_status := str(room_data.get("status", "waiting"))
		if room_status == "in_game":
			_transition_to_arena_from_poll(room_data)
			return

	var host_val   = room_data.get("host",   null)
	var client_val = room_data.get("client", null)
	var host_present:   bool = host_val   != null and typeof(host_val)   == TYPE_DICTIONARY
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY
	var my_uid: String = Auth.current_local_id  if Auth else ""
	var my_bg:  String = Auth.current_card_bg_path if Auth else ""

	if host_present:
		_latest_host_data = host_val
	if client_present:
		_latest_client_data = client_val

	var room_name := str(room_data.get("room_name", ""))
	if room_name.strip_edges() == "":
		room_name = str(host_val.get("username", "Room")) if host_present else "Room"
	_room_id_label.text = "ROOM: " + room_name

	var current_uid := Auth.current_local_id if Auth else ""

	# Host card
	if host_present:
		if Auth and str(host_val.get("card_bg", "")).strip_edges() == "":
			var cached_bg := Auth.get_remote_card_bg(str(host_val.get("player_id", "")))
			if cached_bg.strip_edges() != "":
				host_val["card_bg"] = cached_bg
		if my_uid != "" and str(host_val.get("player_id", "")) == my_uid:
			var snap_bg := str(host_val.get("card_bg", ""))
			if my_bg != "" and snap_bg != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				host_val["card_bg"] = my_bg

		_host_username.text = str(host_val.get("username", "Host"))
		_host_level.text    = "Level: " + str(int(host_val.get("level", 0)))
		_host_status.text   = str(host_val.get("status", "ready")).to_upper()
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
		CardCosmetics.apply_card_background(_host_card_node, str(host_val.get("card_bg", "")))
	else:
		_host_username.text = "."
		_host_level.text    = ""
		_host_status.text   = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)
		CardCosmetics.apply_card_background(_host_card_node, "")

	# Client card
	if client_present:
		if not _last_client_present and not _client_animations_played:
			_play_client_join_animations()
			_client_animations_played = true

		if Auth and str(client_val.get("card_bg", "")).strip_edges() == "":
			var cached_bg2 := Auth.get_remote_card_bg(str(client_val.get("player_id", "")))
			if cached_bg2.strip_edges() != "":
				client_val["card_bg"] = cached_bg2
		if my_uid != "" and str(client_val.get("player_id", "")) == my_uid:
			var snap_bg2 := str(client_val.get("card_bg", ""))
			if my_bg != "" and snap_bg2 != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				client_val["card_bg"] = my_bg

		_client_username.text = str(client_val.get("username", "."))
		_client_level.text    = "Level: " + str(int(client_val.get("level", 0)))

		var client_ready      = client_val.get("ready", false)
		var client_uid_str   := str(client_val.get("player_id", ""))
		var is_me            := (client_uid_str == my_uid)

		if is_me and not _is_host and _client_ready_via_relay:
			var btn_state := _start_btn.button_pressed
			_client_status.text = ("READY" if btn_state else "NOT READY")
			_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if btn_state else COLOR_DANGER))
		elif _is_host and _client_ready_via_relay:
			_client_status.text = ("READY" if _client_ready_relay_value else "NOT READY")
			_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if _client_ready_relay_value else COLOR_DANGER))
		else:
			_client_status.text = ("READY" if client_ready else "NOT READY")
			_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if client_ready else COLOR_DANGER))

		CardCosmetics.apply_card_background(_client_card_node, str(client_val.get("card_bg", "")))

		if not _last_client_present:
			_message_label.text = "Player joined!"
	else:
		if _last_client_present:
			_client_animations_played = false
			_play_client_leave_animations()

		_client_username.text = "."
		_client_level.text    = "."
		_client_status.text   = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		CardCosmetics.apply_card_background(_client_card_node, "")

	if _last_client_present and not client_present:
		_message_label.text = "Player left."
	_last_client_present = client_present

	var players := (1 if host_present else 0) + (1 if client_present else 0)
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))

	if host_present and str(host_val.get("player_id", "")) == current_uid and not _is_host:
		_is_host = true
		_message_label.text = "You are the host now."
		_configure_buttons()


func _sync_my_card_bg_to_lobby(bg_path: String) -> void:
	if _room_id == "" or _lobby_server_url == "":
		return
	if not Auth or Auth.current_local_id == "":
		return
	var url  := _lobby_server_url + "/api/rooms/" + _room_id + "/cosmetics"
	var body := {"player_id": Auth.current_local_id, "card_bg": bg_path}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Cosmetics update failed HTTP %d" % code)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))


func _transition_to_arena_from_poll(room_data: Dictionary) -> void:
	if _transitioning_to_arena:
		return
	_transitioning_to_arena = true
	print("[CodeBreakerRoom] Detected in_game via polling, transitioning to loading")

	var fallback_start_time: int = _game_start_time
	if fallback_start_time == 0:
		fallback_start_time = int(Time.get_unix_time_from_system())
	_game_start_time = int(room_data.get("game_start_time", fallback_start_time))

	if not _relay_client or not _relay_connected:
		_go_to_reconnect("Detected in_game, relay not connected")
		return

	if _is_host:
		_stop_heartbeat()
	_transition_to_loading()


func _apply_room_snapshot(node: Dictionary) -> void:
	if not _transitioning_to_arena:
		var room_state := str(node.get("state", "waiting"))
		if room_state == "in_game":
			_transition_to_arena_from_poll(node)
			return

	var host_val   = node.get("host",   null)
	var client_val = node.get("client", null)
	var host_present:   bool = host_val   != null and typeof(host_val)   == TYPE_DICTIONARY and host_val.size()   > 0
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0

	var host_name_for_room := "Host"
	if host_present:
		host_name_for_room = str(host_val.get("username", "Host"))
	var room_name := str(node.get("room_name", host_name_for_room))
	if room_name.strip_edges() == "":
		room_name = host_name_for_room
	_room_id_label.text = "ROOM: " + room_name

	var current_uid := Auth.current_local_id if Auth else ""

	if not host_present and client_present and not _is_host:
		var client_uid := str(client_val.get("uid", ""))
		if client_uid == current_uid and current_uid != "":
			_message_label.text = "Host left. Promoting you to host..."
			var id_token := Auth.current_id_token if Auth else ""
			if id_token != "":
				_promote_self_to_host(client_val, id_token)
				return
			_is_host = true

	if host_present:
		_host_username.text = str(host_val.get("username", "Host"))
		_host_level.text    = "Level: " + str(int(host_val.get("level", 0)))
		_host_status.text   = str(host_val.get("status", "READY")).to_upper()
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		_host_username.text = "."
		_host_level.text    = ""
		_host_status.text   = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)

	if client_present:
		_client_username.text = str(client_val.get("username", "."))
		_client_level.text    = "Level: " + str(int(client_val.get("level", 0)))
		var c_status := str(client_val.get("status", "not_ready"))
		_client_status.text = ("READY" if c_status == "ready" else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if c_status == "ready" else COLOR_DANGER))
		if not _last_client_present:
			_message_label.text = "Player joined!"
		if not _is_host:
			var client_uid2 := str(client_val.get("uid", ""))
			var my_uid := Auth.current_local_id if Auth else ""
			if client_uid2 == my_uid and _start_btn.toggle_mode:
				var is_ready := c_status == "ready"
				if _start_btn.button_pressed != is_ready:
					_start_btn.button_pressed = is_ready
				_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
	else:
		_client_username.text = "."
		_client_level.text    = "."
		_client_status.text   = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		if _last_client_present:
			_message_label.text = "Player left."
	_last_client_present = client_present

	var players := (1 if host_present else 0) + (1 if client_present else 0)
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))

	if host_present:
		var host_uid := str(host_val.get("uid", ""))
		if host_uid == current_uid and not _is_host:
			_is_host = true
			_message_label.text = "You are the host now."
			_configure_buttons()

	if _is_host:
		var client_ready := client_present and (str(client_val.get("status", "not_ready")) == "ready")
		_start_btn.disabled = not (client_present and client_ready)
	else:
		_start_btn.disabled = false


func _promote_self_to_host(client_val: Dictionary, id_token: String) -> void:
	var patch_obj := {"host": client_val, "client": null, "state": "waiting"}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Promote to host failed HTTP " + str(code))
			return
		_is_host = true
		_message_label.text = "You are the host now."
		_fetch_room()
		_configure_buttons()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))


# =============================================================================
# ROOM MANAGEMENT
# =============================================================================

func _leave_room() -> void:
	print("[CodeBreakerRoom] Leave Room pressed")
	_SessionStore.clear_session()

	if _is_host:
		_stop_heartbeat()

	if _relay_client and _relay_client.is_relay_connected():
		_relay_client.disconnect_from_relay()

	var player_id := Auth.current_local_id if Auth else ""
	if _room_id == "" or player_id == "":
		push_warning("[CodeBreakerRoom] No room_id or player_id; going to landing")
		_go_to_landing()
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Leave request failed: HTTP " + str(code))
			_go_to_landing()
			return
		var response = JSON.parse_string(_body.get_string_from_utf8())
		if typeof(response) != TYPE_DICTIONARY:
			_go_to_landing()
			return
		if response.get("promoted_to_host", false):
			_is_host = true
			_message_label.text = "Previous host left. You are now the host!"
			_configure_buttons()
		_go_to_landing()
	)

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"player_id": player_id}))


# =============================================================================
# NAVIGATION
# =============================================================================

func _go_to_landing() -> void:
	if _is_host:
		_stop_heartbeat()
	_SessionStore.clear_session()
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)


func _go_to_reconnect(reason: String) -> void:
	if _is_host:
		_stop_heartbeat()
	if _lobby_server_url == "" or _room_id == "":
		_go_to_landing()
		return

	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var host_data   := _latest_host_data   if typeof(_latest_host_data)   == TYPE_DICTIONARY else {}
	var client_data := _latest_client_data if typeof(_latest_client_data) == TYPE_DICTIONARY else {}

	var init := {
		"room_id":          _room_id,
		"lobby_server_url": _lobby_server_url,
		"player_id":        Auth.current_local_id if Auth else "unknown",
		"username":         Auth.current_username if Auth else "Player",
		"is_host":          _is_host,
		"relay_client":     _relay_client,
		"host_data":        host_data,
		"client_data":      client_data,
		"game_start_time":  _game_start_time,
		"reason":           reason
	}
	get_tree().set_meta("code_breaker_reconnect_init", init)

	var reconnect_scene := load("res://scene/code_breaker_reconnect.tscn")
	if reconnect_scene:
		get_tree().change_scene_to_packed(reconnect_scene)
	else:
		push_error("[CodeBreakerRoom] code_breaker_reconnect.tscn not found")
		_go_to_landing()


# =============================================================================
# GAME START
# =============================================================================

func _on_start_pressed() -> void:
	print("[CodeBreakerRoom] Start Match pressed by host")
	if not _is_host or _room_id == "" or _transitioning_to_arena:
		return

	_transitioning_to_arena = true
	_game_start_time = int(Time.get_unix_time_from_system())
	print("[CodeBreakerRoom] 🎮 Starting game! Time: %d" % _game_start_time)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Failed to update room status: HTTP %d" % code)
			_transitioning_to_arena = false
			return
		print("[CodeBreakerRoom] ✅ Room status updated to 'in_game'")
		if _relay_client and _relay_connected:
			_relay_client.send_message({"type": "game_start", "game_start_time": _game_start_time})
			print("[CodeBreakerRoom] 📤 Sent game_start to client")
		_transition_to_loading()
	)

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/status"
	var err  := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"status": "in_game", "game_start_time": _game_start_time}))
	if err != OK:
		http.queue_free()
		_transitioning_to_arena = false


func _transition_to_loading() -> void:
	print("[CodeBreakerRoom] Transitioning to loading screen...")
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var host_data := {
		"player_id": str(_latest_host_data.get("player_id", "")),
		"username":  str(_latest_host_data.get("username", "Host")),
		"level":     int(_latest_host_data.get("level", 1))
	}
	var client_data := {
		"player_id": str(_latest_client_data.get("player_id", "")),
		"username":  str(_latest_client_data.get("username", "Client")),
		"level":     int(_latest_client_data.get("level", 1))
	}

	get_tree().set_meta("code_breaker_loading_init", {
		"room_id":          _room_id,
		"relay_client":     _relay_client,
		"player_id":        Auth.current_local_id if Auth else "unknown",
		"is_host":          _is_host,
		"host_data":        host_data,
		"client_data":      client_data,
		"game_start_time":  _game_start_time,
		"lobby_server_url": _lobby_server_url
	})

	var loading_scene := load("res://scene/code_breaker_loading.tscn")
	if loading_scene:
		get_tree().change_scene_to_packed(loading_scene)
	else:
		push_error("[CodeBreakerRoom] Failed to load loading scene!")
		_transitioning_to_arena = false


func _transition_to_arena() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Failed to fetch room before arena transition: HTTP " + str(code))
			return
		var room_data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(room_data) != TYPE_DICTIONARY:
			push_warning("[CodeBreakerRoom] Invalid room data before transition")
			return
		_setup_multiplayer_peer(room_data)
		if _is_host:
			_stop_heartbeat()
		get_tree().set_meta("code_breaker_arena_init", {
			"room_id":   _room_id,
			"is_host":   _is_host,
			"host_name": str(Auth.current_username if Auth else "Host"),
			"room_data": room_data,
			"peer_id":   multiplayer.get_unique_id()
		})
		var arena_scene := load("res://scene/code_breaker_arena.tscn")
		if arena_scene:
			get_tree().change_scene_to_packed(arena_scene)
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)


# =============================================================================
# WEBSOCKET RELAY
# =============================================================================

func _setup_relay_connection() -> void:
	print("[CodeBreakerRoom] Connecting to WebSocket relay...")
	var player_id: String = Auth.current_local_id if Auth else "unknown"
	var username:  String = Auth.current_username  if Auth else "Player"

	var RelayClientScript = load("res://script/WebSocketRelayClient.gd")
	if not RelayClientScript:
		push_error("[CodeBreakerRoom] WebSocketRelayClient.gd not found!")
		_show_connection_error("Relay client error")
		return

	_relay_client = RelayClientScript.new()
	add_child(_relay_client)
	_relay_client.connected_to_relay.connect(_on_relay_connected)
	_relay_client.disconnected_from_relay.connect(_on_relay_disconnected)
	_relay_client.message_received.connect(_on_relay_message_received)
	_relay_client.error_occurred.connect(_on_relay_error)
	_relay_client.connect_to_relay(_lobby_server_url, _room_id, player_id, username)

	var wait_time := 0.0
	while wait_time < _connection_timeout and not _relay_connected:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
		if int(wait_time) % 2 == 0:
			print("[CodeBreakerRoom] Waiting for relay connection... %.1fs" % wait_time)

	if not _relay_connected:
		push_error("[CodeBreakerRoom] Relay connection timeout!")
		_message_label.text = "Connection failed - Could not reach relay server."
		if not _is_host:
			await _notify_server_client_left()
		await get_tree().create_timer(3.0).timeout
		_go_to_reconnect("Relay timeout")
		return

	print("[CodeBreakerRoom] ✅ Connected to relay!")
	_message_label.text = "Connected! Waiting for other player..." if _is_host else "Connected! Waiting for host to start..."


func _on_relay_connected() -> void:
	_relay_connected = true
	print("[CodeBreakerRoom] Relay connection established")
	if _relay_client and Auth:
		_relay_client.send_message({"type": "cosmetics_update", "player_id": Auth.current_local_id, "card_bg": Auth.current_card_bg_path})
		_relay_client.send_message({"type": "cosmetics_request", "player_id": Auth.current_local_id})


func _on_relay_disconnected() -> void:
	_relay_connected = false
	print("[CodeBreakerRoom] Relay connection lost")
	if not _transitioning_to_arena:
		_go_to_reconnect("Relay disconnected")


func _on_relay_message_received(data: Dictionary) -> void:
	var msg_type = data.get("type", "")
	print("[CodeBreakerRoom] Received relay message: ", msg_type)
	match msg_type:
		"cosmetics_request":
			if _relay_client and Auth:
				_relay_client.send_message({"type": "cosmetics_update", "player_id": Auth.current_local_id, "card_bg": Auth.current_card_bg_path})
		"cosmetics_update":
			if Auth:
				var pid := str(data.get("player_id", ""))
				if pid != "" and pid != Auth.current_local_id:
					Auth.set_remote_card_bg(pid, str(data.get("card_bg", "")))
					_fetch_room()
		"player_connected":
			print("[CodeBreakerRoom] %s joined (%d/2)" % [data.get("username", "Player"), data.get("players_count", 0)])
			_message_label.text = "Player joined! Ready to start."
			_fetch_room()
		"player_disconnected":
			print("[CodeBreakerRoom] %s left" % data.get("username", "Player"))
			_message_label.text = "Other player disconnected."
			_fetch_room()
		"host_promotion":
			var new_host_id = data.get("new_host_id", "")
			var my_id = Auth.current_local_id if Auth else ""
			if new_host_id == my_id:
				print("[CodeBreakerRoom] 🎖️ You have been promoted to host!")
				_is_host = true
				_message_label.text = "Previous host left. You are now the host!"
				_configure_buttons()
			_fetch_room()
		"player_left":
			print("[CodeBreakerRoom] %s left the room" % data.get("username", "Player"))
			_message_label.text = "%s has left the room." % data.get("username", "Player")
			_fetch_room()
		"player_status":
			var status = data.get("status", "not_ready")
			if _is_host:
				_client_ready_via_relay    = true
				_client_ready_relay_value  = (status == "ready")
				_client_status.text        = ("READY" if status == "ready" else "NOT READY")
				_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if status == "ready" else COLOR_DANGER))
				_start_btn.disabled        = (status != "ready")
				_message_label.text = "Client is ready! You can start." if status == "ready" else "Waiting for client to be ready..."
		"game_start":
			print("[CodeBreakerRoom] 🎮 Host started the game!")
			_game_start_time = int(data.get("game_start_time", Time.get_unix_time_from_system()))
			await get_tree().create_timer(0.5).timeout
			_transition_to_loading()
		_:
			print("[CodeBreakerRoom] Unknown message type: ", msg_type)


func _on_relay_error(error_message: String) -> void:
	push_error("[CodeBreakerRoom] Relay error: ", error_message)
	_show_connection_error("Relay error: " + error_message)


func _setup_multiplayer_peer(_room_data: Dictionary) -> void:
	print("[CodeBreakerRoom] Verifying relay connection for arena transition...")
	if not _relay_client or not _relay_connected:
		push_error("[CodeBreakerRoom] Relay not connected!")
		_show_connection_error("Relay connection lost")
		return
	print("[CodeBreakerRoom] ✅ Relay ready for arena")


func _show_connection_error(message: String) -> void:
	_message_label.text = message
	await get_tree().create_timer(2.0).timeout
	_go_to_reconnect(message)


# =============================================================================
# ANIMATIONS
# =============================================================================

func _play_client_join_animations() -> void:
	print("[CodeBreakerRoom] Playing client join animations")
	var username_anim = $CardsContainer/ClientCard/Username/AnimationPlayer
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play("usrreadyani")
	var status_anim = $CardsContainer/ClientCard/StatusLabel/AnimationPlayer
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play("usersearchingani")
	var card_anim = $CardsContainer/ClientCard/AnimationPlayer
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play("usercardani")


func _play_client_leave_animations() -> void:
	print("[CodeBreakerRoom] Playing client leave animations")
	var username_anim = $CardsContainer/ClientCard/Username/AnimationPlayer
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play_backwards("usrreadyani")
	var status_anim = $CardsContainer/ClientCard/StatusLabel/AnimationPlayer
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play_backwards("usersearchingani")
	var card_anim = $CardsContainer/ClientCard/AnimationPlayer
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play_backwards("usercardani")


# =============================================================================
# HEARTBEAT
# =============================================================================

func _initialize_lobby_config() -> void:
	if has_node("/root/MultiplayerConfig"):
		var config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = config.get_lobby_url()
		print("[CodeBreakerRoom] Lobby server URL: ", _lobby_server_url)
	else:
		push_error("[CodeBreakerRoom] MultiplayerConfig autoload not found!")
		var MultiplayerConfigScript = load("res://script/MultiplayerConfig.gd")
		if MultiplayerConfigScript:
			var config = Node.new()
			config.set_script(MultiplayerConfigScript)
			add_child(config)
			_lobby_server_url = config.get_lobby_url()
			config.queue_free()
			push_warning("[CodeBreakerRoom] Using fallback MultiplayerConfig instance")


func _start_heartbeat() -> void:
	if not _is_host or _lobby_server_url == "" or _room_id == "":
		return
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
	add_child(_heartbeat_timer)
	print("[CodeBreakerRoom] Heartbeat started - interval: %.0fs" % HEARTBEAT_INTERVAL)
	_send_heartbeat()


func _on_heartbeat_timeout() -> void:
	_send_heartbeat()


func _send_heartbeat() -> void:
	if _lobby_server_url == "" or _room_id == "":
		return
	var url  := _lobby_server_url + "/api/rooms/" + _room_id + "/heartbeat"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code, _headers, _body):
		http.queue_free()
		if code == 200:
			print("[CodeBreakerRoom] Heartbeat sent successfully")
		elif code == 404:
			push_warning("[CodeBreakerRoom] Room not found - may have expired")
		else:
			push_warning("[CodeBreakerRoom] Heartbeat failed HTTP ", code)
	)
	var error := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerRoom] Failed to send heartbeat: ", error)


func _stop_heartbeat() -> void:
	if _heartbeat_timer and is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null
		print("[CodeBreakerRoom] Heartbeat stopped")


func _notify_server_client_left() -> void:
	if _lobby_server_url == "" or _room_id == "" or _is_host:
		return
	print("[CodeBreakerRoom] Notifying server that client is leaving...")
	var url  := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	var http := HTTPRequest.new()
	add_child(http)
	var error := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerRoom] Failed to send leave notification: ", error)
		return
	var response = await http.request_completed
	http.queue_free()
	var code = response[1]
	if code == 200:
		print("[CodeBreakerRoom] ✅ Notified server that client left")
	else:
		push_warning("[CodeBreakerRoom] Failed to notify server of client leave: HTTP ", code)