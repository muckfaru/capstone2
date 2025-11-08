extends Panel

@onready var room_list: VBoxContainer = $LobbyPanel/RoomListContainer
@onready var create_btn: Button = $LobbyPanel/CreateRoomButton
@onready var back_btn: Button = $LobbyPanel/BackButton

var _rooms: Array = []

# Option A: Pure Direct P2P Configuration
var _multiplayer_config: Node = null
var _lobby_server_url: String = ""
var _created_room_id: String = ""  # Store room ID when host creates room

# Network helper for IP detection & UPnP
var _network_helper: Node = null
var _public_ip: String = ""
var _local_ip: String = ""

# ENet server for hosting
var _enet_peer: ENetMultiplayerPeer = null

# Room polling timer
var _poll_timer: Timer = null
const POLL_INTERVAL := 5.0  # Poll lobby server every 5 seconds

func _ready() -> void:
	# Initialize multiplayer config
	_initialize_multiplayer_config()
	
	# Initialize network helper
	_initialize_network_helper()
	
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

	# Start polling lobby server for room list
	_start_room_polling()


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
	"""
	Option A: Pure Direct P2P Room Creation
	Steps:
	1. Wait for public IP (if not ready yet)
	2. Setup UPnP port forwarding
	3. Create ENet server on port 7777
	4. POST to lobby server with host IP + port
	5. Enter room scene with room_id
	"""
	print("[CodeBreakerLobby] Creating room (Option A: Direct P2P)...")
	
	# Get user info
	var uid: String = Auth.current_local_id if Auth else "anonymous"
	var username: String = Auth.current_username if Auth and Auth.current_username != "" else room_name
	var level: int = (Auth.current_level if Auth else 1)
	var avatar: String = Auth.current_avatar if Auth and Auth.current_avatar != "" else "default.png"
	
	var final_room_name := room_name.strip_edges()
	if final_room_name == "":
		final_room_name = ("Anonymous" if anonymous else username)
	
	# Step 1: Wait for public IP detection (max 3s)
	if _public_ip.is_empty():
		print("[CodeBreakerLobby] Waiting for public IP detection...")
		var wait_time = 0.0
		while _public_ip.is_empty() and wait_time < 3.0:
			await get_tree().create_timer(0.5).timeout
			wait_time += 0.5
	
	# Use best available IP (public or local fallback)
	var host_ip = get_host_ip()
	if host_ip.is_empty():
		push_error("[CodeBreakerLobby] Cannot determine host IP!")
		return
	
	var port = 7777
	var is_lan = is_lan_only()
	
	print("[CodeBreakerLobby] Host IP: %s (LAN only: %s)" % [host_ip, is_lan])
	
	# Step 2: Setup UPnP port forwarding (async, non-blocking)
	if not is_lan:
		print("[CodeBreakerLobby] Attempting UPnP port forwarding...")
		try_setup_upnp(port)
		# Don't wait for UPnP - it will complete in background
		# Game will work even if UPnP fails (if user did manual port forwarding)
	
	# Step 3: Create ENet server
	print("[CodeBreakerLobby] Creating ENet server on port %d..." % port)
	_enet_peer = ENetMultiplayerPeer.new()
	var error = _enet_peer.create_server(port, 1)  # Max 1 client
	
	if error != OK:
		push_error("[CodeBreakerLobby] Failed to create ENet server: %d" % error)
		_enet_peer = null
		return
	
	get_tree().get_multiplayer().multiplayer_peer = _enet_peer
	print("[CodeBreakerLobby] ✅ ENet server created successfully")
	
	# Step 4: POST to lobby server
	print("[CodeBreakerLobby] Registering with lobby server...")
	
	var body := {
		"host_id": uid,
		"host_username": ("Anonymous" if anonymous else username),
		"host_avatar": avatar,
		"host_level": level,
		"room_name": final_room_name,
		"game_type": "code_breaker",
		"public_ip": host_ip,
		"port": port,
		"is_lan": is_lan
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		
		if code != 200:
			push_error("[CodeBreakerLobby] Failed to register room with lobby server. HTTP %d" % code)
			# Cleanup
			if _enet_peer:
				_enet_peer.close()
				_enet_peer = null
			return
		
		var resp = JSON.parse_string(resp_body.get_string_from_utf8())
		if resp == null:
			push_error("[CodeBreakerLobby] Invalid JSON response from lobby server")
			return
		
		_created_room_id = str(resp.get("room_id", ""))
		if _created_room_id == "":
			push_error("[CodeBreakerLobby] No room_id returned from lobby server")
			return
		
		print("[CodeBreakerLobby] ✅ Room registered: %s" % _created_room_id)
		
		# Step 5: Enter room scene
		var init := {
			"room_id": _created_room_id,
			"host_name": str(body["host_username"]),
			"is_host": true,
			"host_ip": host_ip,
			"port": port,
			"is_lan": is_lan,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("code_breaker_room_init", init)
		
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[CodeBreakerLobby] code_breaker_room.tscn not found")
	)
	
	# Make API request
	var api_url = _multiplayer_config.get_api_endpoint("/api/rooms/create")
	var request_headers := ["Content-Type: application/json"]
	var request_error = http.request(api_url, request_headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	
	if request_error != OK:
		push_error("[CodeBreakerLobby] HTTP request failed: %d" % request_error)
		http.queue_free()
		if _enet_peer:
			_enet_peer.close()
			_enet_peer = null


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
	action_btn.pressed.connect(func():
		var room_id := str(entry.get("id", ""))
		if room_id != "":
			_join_room_via_lobby(room_id)
	)
	h.add_child(action_btn)
	h.add_child(action_btn)

	room_list.add_child(h)


# =============================================================================
# ROOM DISCOVERY - LOBBY SERVER API (Task 5)
# =============================================================================

func _start_room_polling() -> void:
	"""Start polling lobby server for room list every 5 seconds"""
	if _lobby_server_url == "":
		push_warning("[CodeBreakerLobby] Cannot poll rooms - lobby server URL not set")
		return
	
	# Create and setup poll timer
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_on_poll_timeout)
	add_child(_poll_timer)
	
	# Fetch immediately on start
	_fetch_rooms_from_lobby()
	
	print("[CodeBreakerLobby] Started room polling - interval: ", POLL_INTERVAL, "s")


func _on_poll_timeout() -> void:
	"""Timer callback - fetch rooms from lobby server"""
	_fetch_rooms_from_lobby()


func _fetch_rooms_from_lobby() -> void:
	"""GET /api/rooms/list from lobby server"""
	if _lobby_server_url == "":
		return
	
	var url := _lobby_server_url + "/api/rooms/list"
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_result, code, _headers, body: PackedByteArray):
		http.queue_free()
		
		if code != 200:
			push_warning("[CodeBreakerLobby] Fetch rooms failed HTTP ", code)
			return
		
		var json_str := body.get_string_from_utf8()
		var data = JSON.parse_string(json_str)
		
		if typeof(data) != TYPE_DICTIONARY:
			push_warning("[CodeBreakerLobby] Invalid response format")
			return
		
		var rooms_data = data.get("rooms", [])
		_populate_rooms_from_lobby(rooms_data)
	)
	
	var error := http.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerLobby] Failed to send request: ", error)


func _populate_rooms_from_lobby(rooms_data) -> void:
	"""Populate room list from lobby server response"""
	# Clear existing room list UI
	for child in room_list.get_children():
		child.queue_free()
	
	_rooms.clear()
	
	if typeof(rooms_data) != TYPE_ARRAY or rooms_data.is_empty():
		print("[CodeBreakerLobby] No rooms available")
		return
	
	var current_uid: String = Auth.current_local_id if Auth else ""
	
	for room in rooms_data:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		
		var room_id: String = room.get("id", "")
		var room_name: String = room.get("room_name", "Unnamed Room")
		var host_info = room.get("host", {})
		var host_username: String = host_info.get("username", "Unknown") if typeof(host_info) == TYPE_DICTIONARY else "Unknown"
		var host_uid: String = host_info.get("uid", "") if typeof(host_info) == TYPE_DICTIONARY else ""
		var player_count: int = room.get("player_count", 1)
		var max_players: int = 2
		var status: String = room.get("status", "waiting")
		
		# Only show rooms that are waiting for players
		if status != "waiting":
			continue
		
		# Don't show rooms created by current user
		if host_uid == current_uid:
			continue
		
		var players_text := str(player_count) + "/" + str(max_players)
		var joinable: bool = (player_count < max_players)
		
		var entry := {
			"id": room_id,
			"room_name": room_name,
			"host_username": host_username,
			"players_text": players_text,
			"joinable": joinable,
			"host_ip": room.get("public_ip", ""),
			"host_port": room.get("port", 7777)
		}
		
		_rooms.append(entry)
		_add_room_row(entry)
	
	print("[CodeBreakerLobby] Loaded ", _rooms.size(), " rooms from lobby server")


func _join_room_via_lobby(room_id: String) -> void:
	"""POST /api/rooms/{id}/join to get host connection info"""
	if room_id == "":
		push_warning("[CodeBreakerLobby] Cannot join - no room ID")
		return
	
	if _lobby_server_url == "":
		push_error("[CodeBreakerLobby] Cannot join - lobby server URL not set")
		return
	
	var url := _lobby_server_url + "/api/rooms/" + room_id + "/join"
	var http := HTTPRequest.new()
	add_child(http)
	
	var uid: String = Auth.current_local_id if Auth else ""
	var username: String = Auth.current_username if Auth else "Player"
	var avatar: String = Auth.current_avatar if Auth else "avatar1.png"
	var level: int = Auth.current_level if Auth else 1
	
	var body := {
		"client_id": uid,
		"client_username": username,
		"client_avatar": avatar,
		"client_level": level
	}
	
	http.request_completed.connect(func(_result, code, _headers, response_body: PackedByteArray):
		http.queue_free()
		
		if code != 200:
			push_error("[CodeBreakerLobby] Join room failed HTTP ", code)
			return
		
		var json_str := response_body.get_string_from_utf8()
		var data = JSON.parse_string(json_str)
		
		if typeof(data) != TYPE_DICTIONARY:
			push_error("[CodeBreakerLobby] Invalid join response")
			return
		
		var host_ip: String = data.get("host_ip", "")
		var host_port: int = data.get("host_port", 7777)
		var host_name: String = data.get("host_username", "Host")
		
		if host_ip == "":
			push_error("[CodeBreakerLobby] No host IP received")
			return
		
		print("[CodeBreakerLobby] Joining room - Host: ", host_name, " at ", host_ip, ":", host_port)
		
		# Store connection info and transition to room scene
		var init := {
			"room_id": room_id,
			"host_name": host_name,
			"host_ip": host_ip,
			"host_port": host_port,
			"is_host": false
		}
		get_tree().set_meta("code_breaker_room_init", init)
		
		# Load room scene
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[CodeBreakerLobby] code_breaker_room.tscn not found")
	)
	
	var headers := ["Content-Type: application/json"]
	var error := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	
	if error != OK:
		http.queue_free()
		push_error("[CodeBreakerLobby] Failed to send join request: ", error)


# =============================================================================
# NETWORK HELPER FUNCTIONS (Option A: Pure Direct P2P)
# =============================================================================

func _initialize_multiplayer_config() -> void:
	"""Initialize MultiplayerConfig for lobby server URL"""
	var MultiplayerConfigScript = load("res://script/MultiplayerConfig.gd")
	if not MultiplayerConfigScript:
		push_error("[CodeBreakerLobby] MultiplayerConfig.gd not found!")
		return
	
	_multiplayer_config = MultiplayerConfigScript.new()
	add_child(_multiplayer_config)
	
	# Set mode: LAN for same WiFi testing, LOCALHOST for PC-only dev
	_multiplayer_config.set_mode(_multiplayer_config.Mode.LAN)
	
	# Get lobby server URL
	_lobby_server_url = _multiplayer_config.get_lobby_url()
	
	print("[CodeBreakerLobby] Multiplayer config initialized")
	print("[CodeBreakerLobby] Lobby server: %s" % _lobby_server_url)


func _initialize_network_helper() -> void:
	"""Initialize NetworkHelper for public IP detection"""
	var NetworkHelperScript = load("res://script/NetworkHelper.gd")
	if not NetworkHelperScript:
		push_error("[CodeBreakerLobby] NetworkHelper.gd not found!")
		return
	
	_network_helper = NetworkHelperScript.new()
	add_child(_network_helper)
	
	# Connect signals
	_network_helper.public_ip_detected.connect(_on_public_ip_detected)
	_network_helper.public_ip_failed.connect(_on_public_ip_failed)
	_network_helper.upnp_completed.connect(_on_upnp_completed)
	
	# Start detection immediately (async, non-blocking)
	_network_helper.detect_public_ip()
	
	# Also get local IP (synchronous)
	_local_ip = _network_helper.get_local_ip()
	
	print("[CodeBreakerLobby] Network helper initialized")
	print("[CodeBreakerLobby] Local IP: %s" % _local_ip)


func _on_public_ip_detected(ip: String) -> void:
	"""Called when public IP is successfully detected"""
	_public_ip = ip
	print("[CodeBreakerLobby] ✅ Public IP detected: %s" % ip)
	
	# You can show a notification to user here
	# e.g., "Ready to host - IP: xxx.xxx"


func _on_public_ip_failed(error: String) -> void:
	"""Called when public IP detection fails"""
	push_warning("[CodeBreakerLobby] ⚠️ Public IP detection failed: %s" % error)
	push_warning("[CodeBreakerLobby] Will use local IP as fallback: %s" % _local_ip)
	
	# Fallback: use local IP (works for LAN only)
	_public_ip = _local_ip


func get_host_ip() -> String:
	"""Get the best IP to use for hosting (public or local)"""
	# If we have public IP, use it
	if _public_ip != "":
		return _public_ip
	
	# Fallback to local IP (LAN only)
	if _local_ip != "":
		return _local_ip
	
	# Last resort: try to detect local IP again
	if _network_helper:
		return _network_helper.get_local_ip()
	
	return ""


func is_lan_only() -> bool:
	"""Check if we're in LAN-only mode (no public IP)"""
	return _public_ip.is_empty() or _public_ip.begins_with("192.168.") or _public_ip.begins_with("10.")


func _on_upnp_completed(success: bool, message: String) -> void:
	"""Called when UPnP port forwarding completes (success or failure)"""
	if success:
		print("[CodeBreakerLobby] ✅ UPnP: %s" % message)
		# You can show a success notification here
		# e.g., "Port opened automatically!"
	else:
		print("[CodeBreakerLobby] ⚠️ UPnP: %s" % message)
		# Show manual port forwarding instructions
		_show_manual_port_forwarding_info()


func _show_manual_port_forwarding_info() -> void:
	"""Show instructions for manual port forwarding"""
	print("[CodeBreakerLobby] Manual port forwarding required:")
	print("  1. Open your router admin page (usually 192.168.1.1 or 192.168.0.1)")
	print("  2. Find 'Port Forwarding' or 'Virtual Server' settings")
	print("  3. Add rule: External Port 7777 → Internal IP %s → Internal Port 7777" % _local_ip)
	print("  4. Protocol: TCP")
	print("  5. Save and restart router if needed")
	
	# TODO: Show in-game UI popup with instructions
	# For now, just print to console


func try_setup_upnp(port: int = 7777) -> void:
	"""Attempt to setup UPnP port forwarding"""
	if not _network_helper:
		push_error("[CodeBreakerLobby] Network helper not initialized!")
		return
	
	print("[CodeBreakerLobby] Attempting UPnP port forwarding for port %d..." % port)
	_network_helper.setup_upnp_port_forwarding(port)


func cleanup_upnp(port: int = 7777) -> void:
	"""Clean up UPnP port mapping when leaving"""
	if _network_helper:
		_network_helper.cleanup_upnp_port_forwarding(port)

