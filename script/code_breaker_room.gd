extends Control

@onready var _room_id_label: Label = $RoomHeader/RoomIDLabel
@onready var _room_state_label: Label = $RoomHeader/RoomStateLabel
@onready var _host_username: Label = $CardsContainer/HostCard/Username
@onready var _host_level: Label = $CardsContainer/HostCard/Level
@onready var _host_status: Label = $CardsContainer/HostCard/StatusLabel
@onready var _client_username: Label = $CardsContainer/ClientCard/Username
@onready var _client_level: Label = $CardsContainer/ClientCard/Level
@onready var _client_status: Label = $CardsContainer/ClientCard/StatusLabel
@onready var _message_label: Label = $MessageLabel
@onready var _start_btn: Button = $ButtonPanel/StartButton
@onready var _leave_btn: Button = $ButtonPanel/LeaveButton

# =============================================================================
# DUAL SYSTEM ARCHITECTURE:
# - RTDB: Room state, player info, ready status, chat (UI coordination)
# - ENet P2P: Direct connection for actual gameplay (arena)
# =============================================================================
const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const POLL_INTERVAL := 2.0
const ROOMS_PATH := "/codebreaker_rooms"

# Theme colors (Cyber Neon)
const COLOR_ACCENT := Color(0, 0.819608, 1, 1) # cyan
const COLOR_DANGER := Color(1, 0.356863, 0.431373, 1) # pink-red
const COLOR_MUTED := Color(0.560784, 0.639216, 0.678431, 1) # muted gray-blue

var _room_id: String = ""
var _is_host: bool = false
var _last_client_present: bool = false
var _poll_timer: Timer
var _transitioning_to_arena: bool = false

# Option A: Direct P2P Connection Info
var _host_ip: String = ""
var _host_port: int = 7777
var _enet_peer: ENetMultiplayerPeer = null
var _connection_timeout: float = 10.0  # 10 seconds timeout for connection

# Heartbeat system (Task 7)
var _heartbeat_timer: Timer = null
var _lobby_server_url: String = ""
const HEARTBEAT_INTERVAL := 30.0  # Send heartbeat every 30 seconds

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_room_init"):
		init = get_tree().get_meta("code_breaker_room_init")
		# Clear so stale data isn't reused
		get_tree().set_meta("code_breaker_room_init", null)

	var room_id: String = str(init.get("room_id", "local"))
	var host_name: String = str(init.get("host_name", "Host"))
	var is_host: bool = bool(init.get("is_host", false))

	_room_id = room_id
	_is_host = is_host
	
	# Option A: Store host connection info from lobby server
	_host_ip = str(init.get("host_ip", ""))
	_host_port = int(init.get("host_port", 7777))
	
	print("[CodeBreakerRoom] Initialized - Room: %s, Host: %s, Is Host: %s" % [_room_id, host_name, _is_host])
	if not _is_host:
		print("[CodeBreakerRoom] Client will connect to: %s:%d" % [_host_ip, _host_port])
	
	# Initialize lobby server URL for heartbeat
	_initialize_lobby_config()

	# Initially hide the randomized room id; will set actual room name after first fetch
	_room_id_label.text = ""
	_room_state_label.text = "WAITING"

	# Populate host card
	_host_username.text = host_name
	_host_level.text = ""
	_host_status.text = "READY"

	# Set client placeholder
	_client_username.text = "."
	_client_level.text = "."
	_client_status.text = "Searching.."

	_message_label.text = "Waiting for player to join..."

	# Buttons
	_start_btn.pressed.connect(_on_start_pressed)
	_leave_btn.pressed.connect(_leave_room)

	# Start polling room state
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_fetch_room()
	
	# Start heartbeat system (host only)
	if _is_host:
		_start_heartbeat()
	
	# Option A: Client connects to host's ENet server immediately
	if not _is_host:
		print("[CodeBreakerRoom] Client joining - connecting to host's ENet server...")
		await _setup_client_connection()

	# Configure action button based on role
	_configure_buttons()

	# Initialize embedded room chat with this room context
	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize(RTDB_BASE, ROOMS_PATH, _room_id)


# =============================================================================
# RTDB POLLING - Room State & Player Info (UI Coordination)
# =============================================================================

func _on_poll_timeout() -> void:
	_fetch_room()

func _fetch_room() -> void:
	if _room_id == "":
		return
	
	# Option A: Poll LOBBY SERVER for room state (not RTDB)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Lobby poll failed HTTP " + str(code))
			# Don't auto-leave on HTTP errors (server might be restarting)
			return
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response == null or typeof(response) != TYPE_DICTIONARY:
			push_warning("[CodeBreakerRoom] Invalid lobby response")
			return
		
		# Check if room still exists in lobby
		if response.has("error"):
			print("[CodeBreakerRoom] Room closed by lobby server: ", response.get("error"))
			_message_label.text = "Room has been closed."
			_go_to_landing()
			return
		
		# Apply room state from lobby server
		_apply_lobby_room_snapshot(response)
	)
	
	# GET /api/rooms/{room_id} endpoint
	var url := _lobby_server_url + "/api/rooms/" + _room_id
	http.request(url, [], HTTPClient.METHOD_GET)

func _apply_lobby_room_snapshot(room_data: Dictionary) -> void:
	"""
	Apply room state from lobby server polling.
	Lobby server format:
	{
		room_id, room_name, game_type,
		host: { uid, username, avatar, level, status, public_ip, port, is_lan },
		client: { uid, username, avatar, level, status } | null,
		status: "waiting" | "in_game" | "finished",
		current_players, max_players, created_at, last_heartbeat
	}
	"""
	
	# Check if game has started
	if not _transitioning_to_arena:
		var room_status := str(room_data.get("status", "waiting"))
		if room_status == "in_game":
			# Transition to arena if not already there
			_transition_to_arena_from_poll(room_data)
			return
	
	var host_val = room_data.get("host", null)
	var client_val = room_data.get("client", null)
	var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY

	# Update header with room name
	var room_name := str(room_data.get("room_name", ""))
	if room_name.strip_edges() == "":
		if host_present:
			room_name = str(host_val.get("username", "Room"))
		else:
			room_name = "Room"
	_room_id_label.text = "ROOM: " + room_name

	var current_uid := Auth.current_local_id if Auth else ""

	# Host UI
	if host_present:
		_host_username.text = str(host_val.get("username", "Host"))
		var host_lvl_val = host_val.get("level", 0)
		_host_level.text = "Level: " + str(int(host_lvl_val))
		var host_status_str := str(host_val.get("status", "ready"))
		_host_status.text = host_status_str.to_upper()
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		_host_username.text = "."
		_host_level.text = ""
		_host_status.text = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)

	# Client UI
	if client_present:
		_client_username.text = str(client_val.get("username", "."))
		var client_lvl_val = client_val.get("level", 0)
		_client_level.text = "Level: " + str(int(client_lvl_val))
		var c_status := str(client_val.get("status", "not_ready"))
		_client_status.text = ("READY" if c_status == "ready" else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if c_status == "ready" else COLOR_DANGER))
		if not _last_client_present:
			_message_label.text = "Player joined!"

		# If we are the client, mirror ready state into toggle button
		if not _is_host:
			var client_uid := str(client_val.get("uid", ""))
			var my_uid := Auth.current_local_id if Auth else ""
			if client_uid == my_uid and _start_btn.toggle_mode:
				var is_ready := str(client_val.get("status", "not_ready")) == "ready"
				if _start_btn.button_pressed != is_ready:
					_start_btn.button_pressed = is_ready
				# Button shows the ACTION (opposite of current state)
				_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
	else:
		_client_username.text = "."
		_client_level.text = "."
		_client_status.text = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		if _last_client_present:
			_message_label.text = "Player left."
	_last_client_present = client_present

	# State + Start/Ready button enablement
	var players := (1 if host_present else 0) + (1 if client_present else 0)
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))
	
	# If we see host now equals our uid, flip _is_host (promoted)
	if host_present:
		var host_uid := str(host_val.get("uid", ""))
		if host_uid == current_uid and not _is_host:
			_is_host = true
			_message_label.text = "You are the host now."
			_configure_buttons()

func _transition_to_arena_from_poll(room_data: Dictionary) -> void:
	# Called by polling client when it detects state: "in_game"
	if _transitioning_to_arena:
		return  # Already transitioning, ignore duplicate calls
	
	_transitioning_to_arena = true
	print("[CodeBreakerRoom] Client detected game start, transitioning to arena")
	
	# IMPORTANT: Verify multiplayer peer BEFORE transitioning (client path)
	_setup_multiplayer_peer(room_data)
	
	# Prepare arena init data
	var arena_init := {
		"room_id": _room_id,
		"is_host": _is_host,
		"host_name": str(Auth.current_username if Auth else "Host"),
		"room_data": room_data,
		"peer_id": multiplayer.get_unique_id()
	}
	
	# Stop heartbeat before arena transition
	if _is_host:
		_stop_heartbeat()
	
	# Store meta data safely
	if get_tree():
		get_tree().set_meta("code_breaker_arena_init", arena_init)
	
	# Load and transition to arena
	var arena_scene := load("res://scene/code_breaker_arena.tscn")
	if arena_scene and get_tree():
		get_tree().change_scene_to_packed(arena_scene)
	else:
		push_error("[CodeBreakerRoom] Failed to transition to arena - scene or tree invalid")
		_transitioning_to_arena = false

func _apply_room_snapshot(node: Dictionary) -> void:
	# Check if game has started
	if not _transitioning_to_arena:
		var room_state := str(node.get("state", "waiting"))
		if room_state == "in_game":
			# Transition to arena if not already there
			_transition_to_arena_from_poll(node)
			return
	
	var host_val = node.get("host", null)
	var client_val = node.get("client", null)
	var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY and host_val.size() > 0
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0

	# Update header with room name (fallback to host username)
	var host_name_for_room := "Host"
	if host_present:
		host_name_for_room = str(host_val.get("username", "Host"))
	var room_name := str(node.get("room_name", host_name_for_room))
	if room_name.strip_edges() == "":
		room_name = host_name_for_room
	# Show only the actual room name provided by the host, with prefix
	_room_id_label.text = "ROOM: " + room_name

	var current_uid := Auth.current_local_id if Auth else ""

	# If host is absent but client exists and it's us, promote self to host
	if not host_present and client_present and not _is_host:
		var client_uid := str(client_val.get("uid", ""))
		if client_uid == current_uid and current_uid != "":
			_message_label.text = "Host left. Promoting you to host..."
			var id_token := Auth.current_id_token if Auth else ""
			if id_token != "":
				_promote_self_to_host(client_val, id_token)
				return
			# If no token, just update local UI; lobby will reflect on next poll
			_is_host = true

	# Host UI
	if host_present:
		_host_username.text = str(host_val.get("username", "Host"))
		var host_lvl_val = host_val.get("level", 0)
		_host_level.text = "Level: " + str(int(host_lvl_val))
		_host_status.text = str(host_val.get("status", "READY")).to_upper()
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		_host_username.text = "."
		_host_level.text = ""
		_host_status.text = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)

	# Client UI
	if client_present:
		_client_username.text = str(client_val.get("username", "."))
		var client_lvl_val = client_val.get("level", 0)
		_client_level.text = "Level: " + str(int(client_lvl_val))
		var c_status := str(client_val.get("status", "not_ready"))
		_client_status.text = ("READY" if c_status == "ready" else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if c_status == "ready" else COLOR_DANGER))
		if not _last_client_present:
			_message_label.text = "Player joined!"

		# If we are the client, mirror ready state into toggle button
		if not _is_host:
			var client_uid2 := str(client_val.get("uid", ""))
			var my_uid := Auth.current_local_id if Auth else ""
			if client_uid2 == my_uid and _start_btn.toggle_mode:
				var is_ready := str(client_val.get("status", "not_ready")) == "ready"
				if _start_btn.button_pressed != is_ready:
					_start_btn.button_pressed = is_ready
				# Button shows the ACTION (opposite of current state)
				_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
	else:
		_client_username.text = "."
		_client_level.text = "."
		_client_status.text = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		if _last_client_present:
			_message_label.text = "Player left."
	_last_client_present = client_present

	# State + Start/Ready button enablement
	var players := (1 if host_present else 0) + (1 if client_present else 0)
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))
	# If we see host now equals our uid, flip _is_host
	if host_present:
		var host_uid := str(host_val.get("uid", ""))
		if host_uid == current_uid and not _is_host:
			_is_host = true
			_message_label.text = "You are the host now."
			_configure_buttons()
	# Enable/disable based on role
	if _is_host:
		var client_ready := client_present and (str(client_val.get("status", "not_ready")) == "ready")
		_start_btn.disabled = not (client_present and client_ready)
	else:
		_start_btn.disabled = false

func _promote_self_to_host(client_val: Dictionary, id_token: String) -> void:
	# Move client payload to host and clear client
	var patch_obj := {
		"host": client_val,
		"client": null,
		"state": "waiting"
	}
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
	var url: String = RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))

func _configure_buttons() -> void:
	if _is_host:
		_start_btn.toggle_mode = false
		_start_btn.text = "START MATCH"
		_start_btn.disabled = true  # until client present and ready
	else:
		_start_btn.toggle_mode = true
		# Maintain current pressed state; update label accordingly
		# Button shows the ACTION (opposite of current state)
		_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
		_start_btn.disabled = false
		if not _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.connect(_on_ready_toggled)

func _on_ready_toggled(pressed: bool) -> void:
	# Update UI text immediately
	# Status displays the current state; button shows the action to switch
	_client_status.text = ("READY" if pressed else "NOT READY")
	_start_btn.text = ("NOT READY" if pressed else "READY")
	_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))
	# Patch RTDB at client node
	if _room_id == "":
		return
	var id_token := Auth.current_id_token if Auth else ""
	if id_token == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
	)
	var patch := {"status": ("ready" if pressed else "not_ready")}
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + "/client.json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch))


# =============================================================================
# ROOM MANAGEMENT - Leave, Delete, Patch (RTDB)
# =============================================================================

func _leave_room() -> void:
	print("[CodeBreakerRoom] Leave Room pressed")
	
	# Stop heartbeat if host
	if _is_host:
		_stop_heartbeat()
	
	var id_token := Auth.current_id_token if Auth else ""
	if _room_id == "":
		_go_to_landing()
		return
	if id_token == "":
		push_warning("[CodeBreakerRoom] No id_token; leaving without RTDB cleanup")
		_go_to_landing()
		return

	# Read room to decide whether to delete or just clear our slot
	var get_http := HTTPRequest.new()
	add_child(get_http)
	get_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		get_http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Could not read room before leave: HTTP " + str(code))
			_go_to_landing()
			return
		var node = JSON.parse_string(body.get_string_from_utf8())
		if typeof(node) != TYPE_DICTIONARY:
			_go_to_landing()
			return

		var host_val = node.get("host", null)
		var client_val = node.get("client", null)
		var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY and host_val.size() > 0
		var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0

		# Decide on operation
		if _is_host:
			if not client_present:
				_delete_room(id_token)
			else:
				_patch_room({"host": null, "state": "waiting"}, id_token)
		else:
			if not host_present:
				_delete_room(id_token)
			else:
				_patch_room({"client": null, "state": "waiting"}, id_token)
	)
	var get_url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	get_http.request(get_url, [], HTTPClient.METHOD_GET)

func _patch_room(patch_obj: Dictionary, id_token: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Leave PATCH failed HTTP " + str(code))
		_go_to_landing()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))

func _delete_room(id_token: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Leave DELETE failed HTTP " + str(code))
		_go_to_landing()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, [], HTTPClient.METHOD_DELETE)


# =============================================================================
# NAVIGATION
# =============================================================================

func _go_to_landing() -> void:
	# Stop heartbeat before leaving
	if _is_host:
		_stop_heartbeat()
	
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)


# =============================================================================
# GAME START - Host triggers arena transition (RTDB state + ENet P2P)
# =============================================================================

func _on_start_pressed() -> void:
	print("[CodeBreakerRoom] Start Match pressed by host")
	if not _is_host:
		push_warning("[CodeBreakerRoom] Only host can start match")
		return
	if _room_id == "":
		return
	
	var id_token := Auth.current_id_token if Auth else ""
	if id_token == "":
		push_warning("[CodeBreakerRoom] No id_token to start match")
		return
	
	# Update room state to "in_game" and initialize game countdown
	var patch_obj := {
		"state": "in_game",
		"game_start_time": int(Time.get_unix_time_from_system())
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[CodeBreakerRoom] Failed to update room state: HTTP " + str(code))
			return
		# Transition to arena
		_transition_to_arena()
	)
	
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))

func _transition_to_arena() -> void:
	# Fetch current room data to pass to arena
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
		
		# Initialize multiplayer peer BEFORE scene change
		_setup_multiplayer_peer(room_data)
		
		# Prepare arena init data
		var arena_init := {
			"room_id": _room_id,
			"is_host": _is_host,
			"host_name": str(Auth.current_username if Auth else "Host"),
			"room_data": room_data,
			"peer_id": multiplayer.get_unique_id()
		}
		
		# Stop heartbeat before arena transition
		if _is_host:
			_stop_heartbeat()
		
		get_tree().set_meta("code_breaker_arena_init", arena_init)
		
		# Load the updated arena scene
		var arena_scene := load("res://scene/code_breaker_arena.tscn")
		if arena_scene:
			get_tree().change_scene_to_packed(arena_scene)
	)
	
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)


# =============================================================================
# DIRECT P2P CONNECTION - ENet Multiplayer (Option A Architecture)
# =============================================================================

func _setup_client_connection() -> void:
	"""Client connects to host's ENet server when entering room scene"""
	if _host_ip.is_empty():
		push_error("[CodeBreakerRoom] No host IP provided!")
		_show_connection_error("Invalid host IP")
		return
	
	print("[CodeBreakerRoom] Client connecting to host at %s:%d..." % [_host_ip, _host_port])
	
	_enet_peer = ENetMultiplayerPeer.new()
	var error = _enet_peer.create_client(_host_ip, _host_port)
	if error != OK:
		push_error("[CodeBreakerRoom] Failed to create ENet client: %d" % error)
		_show_connection_error("Connection failed - Host may need port forwarding")
		return
	
	# Set the multiplayer peer
	get_tree().get_multiplayer().multiplayer_peer = _enet_peer
	
	print("[CodeBreakerRoom] ENet client created, waiting for connection...")
	
	# Wait for connection to establish
	var connected = false
	var wait_time = 0.0
	
	while wait_time < _connection_timeout:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
		
		# Check if we're connected (we should have a server peer ID of 1)
		if multiplayer.get_unique_id() != 1 and multiplayer.get_peers().size() > 0:
			connected = true
			break
		
		if int(wait_time) % 2 == 0:
			print("[CodeBreakerRoom] Connection attempt... %.1fs" % wait_time)
	
	if not connected:
		push_error("[CodeBreakerRoom] Connection timeout!")
		_message_label.text = "Connection failed - Host may need port forwarding.\nCheck router settings or try LAN connection."
		# Remove client from server room since connection failed
		await _notify_server_client_left()
		# Wait 3 seconds before returning to lobby
		await get_tree().create_timer(3.0).timeout
		_go_to_landing()
		return
	
	print("[CodeBreakerRoom] ✅ Client connected successfully! Peer ID: %d" % multiplayer.get_unique_id())
	_message_label.text = "Connected! Waiting for host to start..."

func _setup_multiplayer_peer(_room_data: Dictionary) -> void:
	"""Setup Direct P2P ENet Connection (Option A) - Called before arena transition"""
	print("[CodeBreakerRoom] Verifying multiplayer peer for arena transition...")
	
	# For clients, connection is already established in _ready()
	# For hosts, ENet server is already running from lobby
	# This function just verifies everything is ready
	
	if _is_host:
		# Host: Verify ENet server is running and client is connected
		var existing_peer = get_tree().get_multiplayer().multiplayer_peer
		if not existing_peer or not existing_peer is ENetMultiplayerPeer:
			push_error("[CodeBreakerRoom] Host: No ENet server found!")
			_show_connection_error("Server error")
			return
		
		_enet_peer = existing_peer
		
		# Verify client is still connected
		if multiplayer.get_peers().size() == 0:
			push_error("[CodeBreakerRoom] Client disconnected before arena transition!")
			_show_connection_error("Client disconnected")
			return
		
		print("[CodeBreakerRoom] Host ready. Client peer ID: %d" % multiplayer.get_peers()[0])
	
	else:
		# Client: Verify connection is still alive
		if not _enet_peer or not multiplayer.has_multiplayer_peer():
			push_error("[CodeBreakerRoom] Client: Connection lost!")
			_show_connection_error("Connection lost")
			return
		
		# Verify we're still connected to host
		if multiplayer.get_peers().size() == 0:
			push_error("[CodeBreakerRoom] Lost connection to host!")
			_show_connection_error("Connection lost")
			return
		
		print("[CodeBreakerRoom] Client ready. Connected to host (peer ID: 1)")
	
	print("[CodeBreakerRoom] ✅ Multiplayer ready for arena. My Peer ID: %d, Peers: %s" % [multiplayer.get_unique_id(), str(multiplayer.get_peers())])


func _show_connection_error(message: String) -> void:
	"""Show connection error and return to lobby after delay"""
	_message_label.text = message
	await get_tree().create_timer(5.0).timeout
	_go_to_landing()


# =============================================================================
# HEARTBEAT SYSTEM (Task 7) - Keep room alive in lobby server
# =============================================================================

func _initialize_lobby_config() -> void:
	"""Initialize MultiplayerConfig to get lobby server URL"""
	# Use the autoload instance (configured by ForceNetworkMode)
	if has_node("/root/MultiplayerConfig"):
		var config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = config.get_lobby_url()
		print("[CodeBreakerRoom] Using MultiplayerConfig autoload")
		print("[CodeBreakerRoom] Lobby server URL: ", _lobby_server_url)
	else:
		push_error("[CodeBreakerRoom] MultiplayerConfig autoload not found!")
		# Fallback: create new instance
		var MultiplayerConfigScript = load("res://script/MultiplayerConfig.gd")
		if MultiplayerConfigScript:
			var config = Node.new()
			config.set_script(MultiplayerConfigScript)
			add_child(config)
			_lobby_server_url = config.get_lobby_url()
			config.queue_free()
			push_warning("[CodeBreakerRoom] Using fallback MultiplayerConfig instance")


func _start_heartbeat() -> void:
	"""Start sending heartbeats to lobby server (host only)"""
	if not _is_host:
		return
	
	if _lobby_server_url == "":
		push_warning("[CodeBreakerRoom] Cannot start heartbeat - lobby server URL not set")
		return
	
	if _room_id == "":
		push_warning("[CodeBreakerRoom] Cannot start heartbeat - no room ID")
		return
	
	# Create heartbeat timer
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
	add_child(_heartbeat_timer)
	
	print("[CodeBreakerRoom] Heartbeat started - interval: %.0fs" % HEARTBEAT_INTERVAL)
	
	# Send initial heartbeat immediately
	_send_heartbeat()


func _on_heartbeat_timeout() -> void:
	"""Timer callback - send heartbeat"""
	_send_heartbeat()


func _send_heartbeat() -> void:
	"""POST /api/rooms/{id}/heartbeat to keep room alive"""
	if _lobby_server_url == "" or _room_id == "":
		return
	
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/heartbeat"
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_result, code, _headers, _body):
		http.queue_free()
		
		if code == 200:
			print("[CodeBreakerRoom] Heartbeat sent successfully")
		elif code == 404:
			push_warning("[CodeBreakerRoom] Room not found in lobby server - may have expired")
		else:
			push_warning("[CodeBreakerRoom] Heartbeat failed HTTP ", code)
	)
	
	var headers := ["Content-Type: application/json"]
	var error := http.request(url, headers, HTTPClient.METHOD_POST, "{}")
	
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerRoom] Failed to send heartbeat request: ", error)


func _stop_heartbeat() -> void:
	"""Stop heartbeat timer (called on room exit)"""
	if _heartbeat_timer and is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null
		print("[CodeBreakerRoom] Heartbeat stopped")


func _notify_server_client_left() -> void:
	"""Notify lobby server that client left (failed to connect)"""
	if _lobby_server_url == "" or _room_id == "":
		return
	
	if _is_host:
		return  # Only clients call this
	
	print("[CodeBreakerRoom] Notifying server that client is leaving...")
	
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	var http := HTTPRequest.new()
	add_child(http)
	
	var headers := ["Content-Type: application/json"]
	var error := http.request(url, headers, HTTPClient.METHOD_POST, "{}")
	
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerRoom] Failed to send leave notification: ", error)
		return
	
	# Wait for response
	var response = await http.request_completed
	http.queue_free()
	
	var code = response[1]
	if code == 200:
		print("[CodeBreakerRoom] ✅ Notified server that client left")
	else:
		push_warning("[CodeBreakerRoom] Failed to notify server of client leave: HTTP ", code)
