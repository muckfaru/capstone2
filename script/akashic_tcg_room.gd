extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")


# Room-scoped RTDB chat (same RoomChat component as Code Breaker)
const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const ROOMS_PATH := "/akashic_tcg_rooms"

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

const POLL_INTERVAL := 2.0

# Theme colors (Cyber Neon)
const COLOR_ACCENT := Color(0, 0.819608, 1, 1) # cyan
const COLOR_DANGER := Color(1, 0.356863, 0.431373, 1) # pink-red
const COLOR_MUTED := Color(0.560784, 0.639216, 0.678431, 1) # muted gray-blue

var _multiplayer_config: Node = null
var _lobby_server_url: String = ""

var _room_id: String = ""
var _is_host: bool = false
var _player_id: String = ""
var _last_client_present: bool = false
var _poll_timer: Timer

var _transitioning_to_loading: bool = false
var _game_start_time: int = 0

# Heartbeat (host only)
var _heartbeat_timer: Timer = null
const HEARTBEAT_INTERVAL := 30.0

# Relay connection
var _relay_client: Node = null
var _relay_connected: bool = false
var _connection_timeout: float = 10.0

# Cache latest player cards
var _latest_host_data: Dictionary = {}
var _latest_client_data: Dictionary = {}

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_room_init"):
		init = get_tree().get_meta("tgc_room_init")
		get_tree().set_meta("tgc_room_init", null)

	_room_id = str(init.get("room_id", ""))
	_is_host = bool(init.get("is_host", false))
	var host_name: String = str(init.get("host_name", "Host"))
	_lobby_server_url = str(init.get("lobby_server_url", ""))

	_player_id = Auth.current_local_id if Auth else "unknown"
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, "room")

	_initialize_lobby_config_if_needed()

	_room_id_label.text = ""
	_room_state_label.text = "WAITING"

	_host_username.text = host_name
	_host_level.text = ""
	_host_status.text = "READY"

	_client_username.text = "."
	_client_level.text = "."
	_client_status.text = "Searching.."
	_client_status.add_theme_color_override("font_color", COLOR_MUTED)

	_message_label.text = "Waiting for player to join..."

	_start_btn.pressed.connect(_on_start_pressed)
	_leave_btn.pressed.connect(_leave_room)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_fetch_room()

	if _is_host:
		_start_heartbeat()

	await _setup_relay_connection()
	_configure_buttons()

	# Initialize embedded room chat with this room context (room-only chat)
	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize(RTDB_BASE, ROOMS_PATH, _room_id)

func _go_to_reconnect(reason: String, phase: String) -> void:
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, phase)
	# Best-effort cleanup
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	get_tree().set_meta("tgc_reconnect_init", {
		"room_id": _room_id,
		"lobby_server_url": _lobby_server_url,
		"player_id": _player_id,
		"username": username,
		"is_host": _is_host,
		"relay_client": null,
		"host_data": _latest_host_data,
		"client_data": _latest_client_data,
		"game_start_time": _game_start_time,
		"reason": reason,
		"phase": phase,
	})
	var reconnect_scene := load("res://scene/akashic_tcg_reconnect.tscn")
	if reconnect_scene:
		get_tree().change_scene_to_packed(reconnect_scene)
	else:
		push_error("[TGC Room] akashic_tcg_reconnect.tscn not found")

func _initialize_lobby_config_if_needed() -> void:
	if _lobby_server_url != "":
		return
	if has_node("/root/MultiplayerConfig"):
		_multiplayer_config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = _multiplayer_config.get_lobby_url()
	else:
		var script = load("res://script/MultiplayerConfig.gd")
		if script:
			_multiplayer_config = script.new()
			add_child(_multiplayer_config)
			_lobby_server_url = _multiplayer_config.get_lobby_url()

func _on_poll_timeout() -> void:
	_fetch_room()

func _fetch_room() -> void:
	if _room_id == "" or _lobby_server_url == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code == 404:
			_message_label.text = "Room closed."
			_go_to_landing()
			return
		if code != 200:
			push_warning("[TGC Room] Poll failed HTTP " + str(code))
			return
		var room_data = JSON.parse_string(body.get_string_from_utf8())
		if room_data == null or typeof(room_data) != TYPE_DICTIONARY:
			push_warning("[TGC Room] Invalid room data")
			return
		_apply_lobby_room_snapshot(room_data)
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id
	http.request(url, [], HTTPClient.METHOD_GET)

func _apply_lobby_room_snapshot(room_data: Dictionary) -> void:
	if not _transitioning_to_loading:
		var status := str(room_data.get("status", "waiting"))
		if status == "in_game":
			_transition_to_loading_from_poll(room_data)
			return

	var host_val = room_data.get("host", null)
	var client_val = room_data.get("client", null)
	var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY
	var my_uid: String = Auth.current_local_id if Auth else ""
	var my_bg: String = Auth.current_card_bg_path if Auth else ""

	if host_present:
		_latest_host_data = host_val
	if client_present:
		_latest_client_data = client_val

	var room_name := str(room_data.get("room_name", ""))
	if room_name.strip_edges() == "":
		room_name = str(host_val.get("username", "Room")) if host_present else "Room"
	_room_id_label.text = "ROOM: " + room_name

	# Host card
	if host_present:
		# Fallback: if snapshot lacks cosmetics, try cache learned via relay.
		if Auth and str(host_val.get("card_bg", "")).strip_edges() == "":
			var host_pid_cache := str(host_val.get("player_id", ""))
			var cached_bg := Auth.get_remote_card_bg(host_pid_cache)
			if cached_bg.strip_edges() != "":
				host_val["card_bg"] = cached_bg

		if my_uid != "" and str(host_val.get("player_id", "")) == my_uid:
			var snapshot_bg := str(host_val.get("card_bg", ""))
			if my_bg != "" and snapshot_bg != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				host_val["card_bg"] = my_bg

		_host_username.text = str(host_val.get("username", "Host"))
		_host_level.text = "Level: " + str(int(host_val.get("level", 1)))
		_host_status.text = "HOST"
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
		CardCosmetics.apply_card_background(_host_card_node, str(host_val.get("card_bg", "")))
	else:
		_host_username.text = "."
		_host_level.text = ""
		_host_status.text = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)
		CardCosmetics.apply_card_background(_host_card_node, "")

	# Client card
	if client_present:
		# Fallback: if snapshot lacks cosmetics, try cache learned via relay.
		if Auth and str(client_val.get("card_bg", "")).strip_edges() == "":
			var client_pid_cache := str(client_val.get("player_id", ""))
			var cached_bg2 := Auth.get_remote_card_bg(client_pid_cache)
			if cached_bg2.strip_edges() != "":
				client_val["card_bg"] = cached_bg2

		if my_uid != "" and str(client_val.get("player_id", "")) == my_uid:
			var snapshot_bg2 := str(client_val.get("card_bg", ""))
			if my_bg != "" and snapshot_bg2 != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				client_val["card_bg"] = my_bg

		_client_username.text = str(client_val.get("username", "Client"))
		_client_level.text = "Level: " + str(int(client_val.get("level", 1)))
		var client_ready := bool(client_val.get("ready", false))
		_client_status.text = ("READY" if client_ready else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if client_ready else COLOR_DANGER))
		if not _last_client_present:
			_message_label.text = "Player joined!"
			_play_client_join_animations()
		CardCosmetics.apply_card_background(_client_card_node, str(client_val.get("card_bg", "")))
	else:
		_client_username.text = "."
		_client_level.text = "."
		_client_status.text = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		if _last_client_present:
			_message_label.text = "Player left."
			_play_client_leave_animations()
		CardCosmetics.apply_card_background(_client_card_node, "")

	_last_client_present = client_present

	# Room state
	var players := int(room_data.get("current_players", 1))
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))

	# Enable/disable buttons
	if _is_host:
		var client_ready2 := client_present and bool(client_val.get("ready", false))
		_start_btn.disabled = not (client_present and client_ready2)
	else:
		_start_btn.disabled = false
		# Keep toggle label consistent for client
		if _start_btn.toggle_mode:
			_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")


func _play_client_join_animations() -> void:
	# Keep parity with Code Breaker room UI: slide in client banners and fade card in.
	var username_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/Username/AnimationPlayer")
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play("usrreadyani")

	var status_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/StatusLabel/AnimationPlayer")
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play("usersearchingani")

	var card_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/AnimationPlayer")
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play("usercardani")


func _play_client_leave_animations() -> void:
	var username_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/Username/AnimationPlayer")
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play_backwards("usrreadyani")

	var status_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/StatusLabel/AnimationPlayer")
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play_backwards("usersearchingani")

	var card_anim: AnimationPlayer = get_node_or_null("CardsContainer/ClientCard/AnimationPlayer")
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play_backwards("usercardani")


func _sync_my_card_bg_to_lobby(bg_path: String) -> void:
	if _room_id == "" or _lobby_server_url == "":
		return
	if not Auth or Auth.current_local_id == "":
		return

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/cosmetics"
	var body := {
		"player_id": Auth.current_local_id,
		"card_bg": bg_path
	}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Cosmetics update failed HTTP %d" % code)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))

func _configure_buttons() -> void:
	if _is_host:
		_start_btn.toggle_mode = false
		_start_btn.text = "START MATCH"
		_start_btn.disabled = true
	else:
		_start_btn.toggle_mode = true
		_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
		_start_btn.disabled = false
		if not _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.connect(_on_ready_toggled)

func _on_ready_toggled(pressed: bool) -> void:
	_client_status.text = ("READY" if pressed else "NOT READY")
	_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))
	_start_btn.text = ("NOT READY" if pressed else "READY")
	_post_ready_status(pressed)

func _post_ready_status(is_ready: bool) -> void:
	if _lobby_server_url == "" or _room_id == "" or _player_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	var body := {"player_id": _player_id, "ready": is_ready}
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
		# Poll to reflect on host UI
		_fetch_room()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/ready"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_start_pressed() -> void:
	if not _is_host:
		return
	if _transitioning_to_loading:
		return
	if not _relay_client or not _relay_connected:
		_message_label.text = "Relay not connected."
		return

	_transitioning_to_loading = true
	_game_start_time = int(Time.get_unix_time_from_system())

	# Tell opponent via relay (best effort)
	_relay_client.send_message({
		"type": "game_start",
		"game_start_time": _game_start_time,
		"player_id": _player_id
	})

	# Update lobby server status
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Failed to set in_game HTTP " + str(code))
			_transitioning_to_loading = false
			return
		_transition_to_loading()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/status"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"status": "in_game"}))

func _transition_to_loading_from_poll(_room_data: Dictionary) -> void:
	if _transitioning_to_loading:
		return
	_transitioning_to_loading = true
	if _game_start_time == 0:
		_game_start_time = int(Time.get_unix_time_from_system())
	if not _relay_client or not _relay_connected:
		_message_label.text = "Relay disconnected. Reconnecting..."
		_go_to_reconnect("Relay disconnected", "room")
		return
	_transition_to_loading()

func _transition_to_loading() -> void:
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, "loading")
	if _is_host:
		_stop_heartbeat()

	# Preserve relay client across scene change
	if _relay_client and _relay_client.get_parent() != get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var init := {
		"room_id": _room_id,
		"is_host": _is_host,
		"player_id": _player_id,
		"host_data": _latest_host_data,
		"client_data": _latest_client_data,
		"game_start_time": _game_start_time,
		"lobby_server_url": _lobby_server_url,
		"relay_client": _relay_client
	}
	get_tree().set_meta("tgc_loading_init", init)
	var loading_scene := load("res://scene/akashic_tcg_loading.tscn")
	if loading_scene:
		get_tree().change_scene_to_packed(loading_scene)
	else:
		push_error("[TGC Room] akashic_tcg_loading.tscn not found")
		_transitioning_to_loading = false

func _leave_room() -> void:
	if _is_host:
		_stop_heartbeat()
	_TGCSess.clear_session()
	_post_leave_to_server()

func _post_leave_to_server() -> void:
	if _lobby_server_url == "" or _room_id == "" or _player_id == "":
		_go_to_landing()
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
		_go_to_landing()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"player_id": _player_id}))

func _go_to_landing() -> void:
	# Best-effort relay cleanup
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	_TGCSess.clear_session()
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)

func _start_heartbeat() -> void:
	if _heartbeat_timer:
		_heartbeat_timer.queue_free()
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.autostart = true
	add_child(_heartbeat_timer)
	_heartbeat_timer.timeout.connect(_send_heartbeat)
	_send_heartbeat()

func _stop_heartbeat() -> void:
	if _heartbeat_timer:
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null

func _send_heartbeat() -> void:
	if _lobby_server_url == "" or _room_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/heartbeat"
	http.request(url, [], HTTPClient.METHOD_POST)

func _setup_relay_connection() -> void:
	print("[TGC Room] Connecting to relay...")
	if _lobby_server_url == "" or _room_id == "":
		return
	var username: String = Auth.current_username if Auth else "Player"
	
	var RelayClientScript = load("res://script/WebSocketRelayClient.gd")
	if not RelayClientScript:
		push_error("[TGC Room] WebSocketRelayClient.gd not found")
		return
	_relay_client = RelayClientScript.new()
	add_child(_relay_client)
	_relay_client.connected_to_relay.connect(_on_relay_connected)
	_relay_client.disconnected_from_relay.connect(_on_relay_disconnected)
	_relay_client.message_received.connect(_on_relay_message_received)
	_relay_client.error_occurred.connect(_on_relay_error)
	_relay_client.connect_to_relay(_lobby_server_url, _room_id, _player_id, username)
	
	var wait_time := 0.0
	while wait_time < _connection_timeout and not _relay_connected:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
	
	if not _relay_connected:
		_message_label.text = "Relay connection failed."
		push_error("[TGC Room] Relay connection timeout")
		return
	_message_label.text = ("Connected! Waiting for player..." if _is_host else "Connected! Ready up.")

func _on_relay_connected() -> void:
	_relay_connected = true
	print("[TGC Room] ✅ Relay connected")
	# Share cosmetics via relay so opponents can see them even if lobby snapshot is stale.
	if _relay_client and Auth:
		_relay_client.send_message({
			"type": "cosmetics_update",
			"player_id": Auth.current_local_id,
			"card_bg": Auth.current_card_bg_path
		})
		_relay_client.send_message({
			"type": "cosmetics_request",
			"player_id": Auth.current_local_id
		})

func _on_relay_disconnected() -> void:
	_relay_connected = false
	print("[TGC Room] Relay disconnected")
	if not _transitioning_to_loading:
		_message_label.text = "Disconnected. Reconnecting..."
		_go_to_reconnect("Relay disconnected", "room")

func _on_relay_error(message: String) -> void:
	push_error("[TGC Room] Relay error: " + message)

func _on_relay_message_received(data: Dictionary) -> void:
	var msg_type = str(data.get("type", ""))
	match msg_type:
		"cosmetics_request":
			if _relay_client and Auth:
				_relay_client.send_message({
					"type": "cosmetics_update",
					"player_id": Auth.current_local_id,
					"card_bg": Auth.current_card_bg_path
				})
		"cosmetics_update":
			if Auth:
				var pid := str(data.get("player_id", ""))
				if pid != "" and pid != Auth.current_local_id:
					Auth.set_remote_card_bg(pid, str(data.get("card_bg", "")))
					_fetch_room()
		"player_connected":
			_message_label.text = "Player connected!"
			_fetch_room()
		"player_disconnected":
			_message_label.text = "Player disconnected."
			_fetch_room()
		"host_promotion":
			var new_host_id := str(data.get("new_host_id", ""))
			if new_host_id == _player_id:
				_is_host = true
				_configure_buttons()
				_start_heartbeat()
				_message_label.text = "You are host now."
		"game_start":
			# Host broadcasted; client can pick up start time
			_game_start_time = int(data.get("game_start_time", 0))
			# Polling will transition too; but if we already got start, allow early transition
			if not _transitioning_to_loading:
				_transitioning_to_loading = true
				_transition_to_loading()
			
		_:
			pass
