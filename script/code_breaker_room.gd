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

	# Configure action button based on role
	_configure_buttons()

	# Initialize embedded room chat with this room context
	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize(RTDB_BASE, ROOMS_PATH, _room_id)

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
			push_warning("[CodeBreakerRoom] Poll failed HTTP " + str(code))
			return
		var node = JSON.parse_string(body.get_string_from_utf8())
		if node == null or typeof(node) != TYPE_DICTIONARY:
			_message_label.text = "Room has been closed."
			_go_to_landing()
			return
		_apply_room_snapshot(node)
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)

func _transition_to_arena_from_poll(room_data: Dictionary) -> void:
	# Called by polling client when it detects state: "in_game"
	if _transitioning_to_arena:
		return  # Already transitioning, ignore duplicate calls
	
	_transitioning_to_arena = true
	print("[CodeBreakerRoom] Client detected game start, transitioning to arena")
	
	# IMPORTANT: Setup multiplayer peer BEFORE transitioning (client path)
	await _setup_multiplayer_peer(room_data)
	
	# Prepare arena init data
	var arena_init := {
		"room_id": _room_id,
		"is_host": _is_host,
		"host_name": str(Auth.current_username if Auth else "Host"),
		"room_data": room_data,
		"peer_id": multiplayer.get_unique_id()
	}
	
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

func _leave_room() -> void:
	print("[CodeBreakerRoom] Leave Room pressed")
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

func _go_to_landing() -> void:
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)

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
		await _setup_multiplayer_peer(room_data)
		
		# Prepare arena init data
		var arena_init := {
			"room_id": _room_id,
			"is_host": _is_host,
			"host_name": str(Auth.current_username if Auth else "Host"),
			"room_data": room_data,
			"peer_id": multiplayer.get_unique_id()
		}
		
		get_tree().set_meta("code_breaker_arena_init", arena_init)
		
		# Load the updated arena scene
		var arena_scene := load("res://scene/code_breaker_arena.tscn")
		if arena_scene:
			get_tree().change_scene_to_packed(arena_scene)
	)
	
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)

func _setup_multiplayer_peer(_room_data: Dictionary) -> void:
	"""Initialize WebSocketMultiplayerPeer for the game"""
	print("[CodeBreakerRoom] Setting up multiplayer peer...")
	
	# TEMPORARY: Skip multiplayer setup for now (use ENetMultiplayerPeer for localhost testing)
	# This is a simpler alternative that works better for local testing
	var peer = ENetMultiplayerPeer.new()
	
	if _is_host:
		print("[CodeBreakerRoom] Creating ENet host on port 9999...")
		var error = peer.create_server(9999, 1)  # Max 1 client
		if error != OK:
			push_error("[CodeBreakerRoom] Failed to create ENet server: %d" % error)
			return
		print("[CodeBreakerRoom] ENet server created successfully")
		
		# Set the multiplayer peer
		get_tree().get_multiplayer().multiplayer_peer = peer
		print("[CodeBreakerRoom] Host waiting for client to connect...")
		
		# Wait for client to connect (with timeout)
		var wait_time = 0.0
		var max_wait = 10.0  # 10 seconds max
		while multiplayer.get_peers().size() == 0 and wait_time < max_wait:
			await get_tree().create_timer(0.5).timeout
			wait_time += 0.5
			if int(wait_time) % 2 == 0:
				print("[CodeBreakerRoom] Still waiting for client... %.1fs" % wait_time)
		
		if multiplayer.get_peers().size() == 0:
			push_error("[CodeBreakerRoom] Client never connected!")
			_message_label.text = "Client connection timeout. Returning to lobby..."
			await get_tree().create_timer(3.0).timeout
			_go_to_landing()
			return
		else:
			print("[CodeBreakerRoom] Client connected! Peer ID: %d" % multiplayer.get_peers()[0])
	else:
		print("[CodeBreakerRoom] Connecting to ENet host at 127.0.0.1:9999...")
		var error = peer.create_client("127.0.0.1", 9999)
		if error != OK:
			push_error("[CodeBreakerRoom] Failed to create ENet client: %d" % error)
			return
		
		# Set the multiplayer peer
		get_tree().get_multiplayer().multiplayer_peer = peer
		print("[CodeBreakerRoom] ENet client connecting...")
		
		# Wait for connection to establish
		await get_tree().create_timer(2.0).timeout
	
	print("[CodeBreakerRoom] Multiplayer ready. My Peer ID: %d, Peers: %s" % [multiplayer.get_unique_id(), str(multiplayer.get_peers())])

# OLD WebSocket setup code (replaced with simpler ENet for local testing)
# To re-enable WebSocket P2P, uncomment the _setup_multiplayer_peer_websocket function below
# and call it instead of the ENet version above

func _setup_multiplayer_peer_websocket(_room_data: Dictionary) -> void:
	"""WebSocket multiplayer setup (for LAN/Internet play) - Currently disabled"""
	# Load multiplayer manager script
	var mp_manager_script = load("res://script/MultiplayerManager.gd")
	var mp_manager = Node.new()
	mp_manager.set_script(mp_manager_script)
	add_child(mp_manager)
	
	# Setup callbacks
	var status = {"ready": false}
	mp_manager.connection_ready.connect(func():
		print("[CodeBreakerRoom] Multiplayer connection ready!")
		status["ready"] = true
	)
	mp_manager.connection_failed.connect(func(error):
		push_error("[CodeBreakerRoom] Multiplayer connection failed: %s" % error)
	)
	
	if _is_host:
		# Host creates server and publishes IP to RTDB
		var success = mp_manager.setup_host(_room_id, 9999)
		if not success:
			push_error("[CodeBreakerRoom] Failed to setup host")
			return
		
		# Publish host IP for client discovery
		var network_discovery = load("res://script/NetworkDiscovery.gd").new()
		add_child(network_discovery)
		var local_ip = network_discovery.get_local_network_ip()
		var id_token = Auth.current_id_token if Auth else ""
		network_discovery.publish_host_ip(_room_id, local_ip, 9999, id_token)
		
		print("[CodeBreakerRoom] Host server created at %s:9999, waiting for client..." % local_ip)
	else:
		# Client fetches host IP from RTDB and connects
		var network_discovery = load("res://script/NetworkDiscovery.gd").new()
		add_child(network_discovery)
		
		# Wait for host IP (use dictionary to avoid capture issue)
		var ip_data = {"ip": ""}
		network_discovery.host_ip_received.connect(func(ip):
			ip_data["ip"] = ip
		)
		network_discovery.discovery_failed.connect(func(error):
			push_error("[CodeBreakerRoom] Network discovery failed: %s" % error)
		)
		
		network_discovery.get_host_ip(_room_id)
		
		# Wait for IP (discovery timeout 5s)
		var discovery_timeout = 5.0
		var discovery_elapsed = 0.0
		while ip_data["ip"].is_empty() and discovery_elapsed < discovery_timeout:
			await get_tree().create_timer(0.1).timeout
			discovery_elapsed += 0.1
		
		if ip_data["ip"].is_empty():
			push_error("[CodeBreakerRoom] Failed to discover host IP")
			return
		
		var success = mp_manager.setup_client(ip_data["ip"], 9999)
		if not success:
			push_error("[CodeBreakerRoom] Failed to connect to host")
			return
		print("[CodeBreakerRoom] Client connecting to host at %s:9999..." % ip_data["ip"])
	
	# Wait for connection to be ready (increased timeout)
	var timeout = 15.0
	var elapsed = 0.0
	while not status["ready"] and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if elapsed > 0 and int(elapsed) % 2 == 0:
			print("[CodeBreakerRoom] Still waiting for connection... %.1fs" % elapsed)
	
	if not status["ready"]:
		push_error("[CodeBreakerRoom] Multiplayer connection timeout after %.1fs" % timeout)
		_message_label.text = "Connection failed. Returning to lobby..."
		await get_tree().create_timer(3.0).timeout
		_go_to_landing()
		return
	
	print("[CodeBreakerRoom] Multiplayer peer connected! Peer ID: %d" % multiplayer.get_unique_id())
	
	# Verify connection is active
	if multiplayer.multiplayer_peer == null:
		push_error("[CodeBreakerRoom] Multiplayer peer is null after setup!")
		return
	
	# Keep the manager alive for the arena
	mp_manager.name = "MultiplayerManager"
	mp_manager.reparent(get_tree().root)
