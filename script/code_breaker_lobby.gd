extends Panel

@onready var room_list: VBoxContainer = $LobbyPanel/RoomListContainer
@onready var create_btn: Button = $LobbyPanel/CreateRoomButton
@onready var back_btn: Button = $LobbyPanel/BackButton

var _rooms: Array = []

# Option A: Pure Direct P2P Configuration
var _multiplayer_config: Node = null
var _lobby_server_url: String = ""
var _created_room_id: String = ""  # Store room ID when host creates room

# Option B: Relay architecture - no ENet/IP detection needed
# Players connect directly to relay server

# Room polling timer
var _poll_timer: Timer = null
const POLL_INTERVAL := 5.0  # Poll lobby server every 5 seconds

func _ready() -> void:
	# Initialize multiplayer config
	_initialize_multiplayer_config()
	
	# FORCE DEBUG: Print actual URL being used
	print("🔍 [DEBUG] Lobby URL after init: ", _lobby_server_url)
	
	# Option B: No network helper needed for relay architecture
	
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
	Option B: Relay Server Architecture
	Steps:
	1. Ping server to wake it up (if sleeping on Render free tier)
	2. Register room with lobby server (no IP/port needed)
	3. Enter room scene with room_id
	4. Room scene connects both players to relay server
	"""
	print("[CodeBreakerLobby] Creating room (Option B: Relay)...")
	
	# STEP 1: Wake up server if sleeping (Render.com free tier fix)
	if create_btn:
		create_btn.disabled = true
		create_btn.text = "Waking up server..."
	
	await _ping_server_to_wake()
	
	# STEP 2: Continue with room creation
	if create_btn:
		create_btn.text = "Creating room..."
	
	# Get user info
	var uid: String = Auth.current_local_id if Auth else "anonymous"
	var username: String = Auth.current_username if Auth and Auth.current_username != "" else room_name
	var level: int = (Auth.current_level if Auth else 1)
	var avatar: String = Auth.current_avatar if Auth and Auth.current_avatar != "" else "default.png"
	
	var final_room_name := room_name.strip_edges()
	if final_room_name == "":
		final_room_name = ("Anonymous" if anonymous else username)
	
	print("[CodeBreakerLobby] Registering room with lobby server...")
	
	# Register room (relay architecture - no IP/port needed)
	var body := {
		"host_id": uid,
		"host_username": ("Anonymous" if anonymous else username),
		"host_avatar": avatar,
		"host_level": level,
		"room_name": final_room_name,
		"game_type": "code_breaker"
		# No public_ip, port, or is_lan needed for relay
	}
	
	var http := HTTPRequest.new()
	http.timeout = 30.0  # Increased timeout for server wake-up
	add_child(http)
	
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, resp_body: PackedByteArray):
		print("🔍 [DEBUG] HTTP Response - Code: ", code, " Body: ", resp_body.get_string_from_utf8())
		
		# Re-enable create button
		if create_btn:
			create_btn.disabled = false
			create_btn.text = "Create Room"
		
		if code != 200:
			push_error("[CodeBreakerLobby] Failed to register room with lobby server. HTTP %d" % code)
			http.queue_free()
			return
		
		var resp = JSON.parse_string(resp_body.get_string_from_utf8())
		if resp == null:
			push_error("[CodeBreakerLobby] Invalid JSON response from lobby server")
			http.queue_free()
			return
		
		_created_room_id = str(resp.get("room_id", ""))
		if _created_room_id == "":
			push_error("[CodeBreakerLobby] No room_id returned from lobby server")
			http.queue_free()
			return
		
		print("[CodeBreakerLobby] ✅ Room registered: %s" % _created_room_id)
		
		# Enter room scene (relay will connect in room scene)
		var init := {
			"room_id": _created_room_id,
			"host_name": str(username if not anonymous else "Anonymous"),
			"is_host": true,
			"lobby_server_url": _lobby_server_url
		}
		get_tree().set_meta("code_breaker_room_init", init)
		
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			http.queue_free()
			get_tree().change_scene_to_packed(room_scene)
		else:
			push_error("[CodeBreakerLobby] code_breaker_room.tscn not found")
			http.queue_free()
	)
	
	# Make API request
	var api_url = _multiplayer_config.get_api_endpoint("/api/rooms/create")
	print("🔍 [DEBUG] API URL: ", api_url)
	print("🔍 [DEBUG] Request body: ", JSON.stringify(body))
	
	var request_headers := ["Content-Type: application/json"]
	var request_error = http.request(api_url, request_headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	
	if request_error != OK:
		push_error("[CodeBreakerLobby] HTTP request failed: %d" % request_error)
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
	action_btn.pressed.connect(func():
		var room_id := str(entry.get("id", ""))
		if room_id != "":
			print("[CodeBreakerLobby] JOIN button clicked for room: ", room_id)
			_join_room_via_lobby(room_id)
	)
	h.add_child(action_btn)  # Fixed: removed duplicate add_child

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
	"""Process room list from lobby server and populate UI"""
	# Clear existing rooms
	if room_list:
		for child in room_list.get_children():
			child.queue_free()
	
	_rooms.clear()
	
	if typeof(rooms_data) != TYPE_ARRAY or rooms_data.is_empty():
		print("[CodeBreakerLobby] No rooms available")
		return
	
	print("🔍 [DEBUG] Processing ", rooms_data.size(), " rooms from server")
	
	var current_uid: String = Auth.current_local_id if Auth else ""
	print("🔍 [DEBUG] Current user UID: ", current_uid)
	
	for room in rooms_data:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		
		var room_id: String = room.get("room_id", "")  # Fixed: server returns "room_id", not "id"
		var room_name: String = room.get("room_name", "Unnamed Room")
		var host_info = room.get("host", {})
		var host_username: String = host_info.get("username", "Unknown") if typeof(host_info) == TYPE_DICTIONARY else "Unknown"
		var host_uid: String = host_info.get("uid", "") if typeof(host_info) == TYPE_DICTIONARY else ""
		var player_count: int = room.get("current_players", 1)  # Fixed: server returns "current_players", not "player_count"
		var max_players: int = room.get("max_players", 2)  # Also read from server response
		var status: String = room.get("status", "waiting")
		
		print("🔍 [DEBUG] Room: ", room_id, " | Host: ", host_username, " (uid:", host_uid, ") | Players: ", player_count, "/", max_players, " | Status: ", status)
		
		# Only show rooms that are waiting for players
		if status != "waiting":
			print("🔍 [DEBUG] Skipping room (not waiting): ", room_id)
			continue
		
		# Don't show rooms created by current user
		if host_uid == current_uid and host_uid != "":
			print("🔍 [DEBUG] Skipping own room: ", room_id)
			continue
		
		var players_text := str(player_count) + "/" + str(max_players)
		var joinable: bool = (player_count < max_players)
		
		print("🔍 [DEBUG] Adding room to list - Joinable: ", joinable)
		
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

	# Debug: print join request details
	print("🔍 [DEBUG] JOIN API URL: ", url)
	print("🔍 [DEBUG] JOIN Request body: ", JSON.stringify(body))

	http.request_completed.connect(func(_result, code, _headers, response_body: PackedByteArray):
		http.queue_free()
		
		var raw := response_body.get_string_from_utf8()
		print("🔍 [DEBUG] JOIN HTTP Response code:", code, " body:", raw)

		if code != 200:
			push_error("[CodeBreakerLobby] Join room failed HTTP ", code, " response:", raw)
			return
		
		var json_str := response_body.get_string_from_utf8()
		var data = JSON.parse_string(json_str)
		
		if typeof(data) != TYPE_DICTIONARY:
			push_error("[CodeBreakerLobby] Invalid join response")
			return
		
		# Option B: Relay architecture - no IP/port needed
		var host_name: String = data.get("host_username", "Host")
		
		print("[CodeBreakerLobby] Joining room - Host: ", host_name, " (relay mode)")
		
		# Store connection info and transition to room scene
		var init := {
			"room_id": room_id,
			"host_name": host_name,
			"is_host": false,
			"lobby_server_url": _lobby_server_url
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
	# Use the autoload instance (configured by ForceNetworkMode)
	if has_node("/root/MultiplayerConfig"):
		_multiplayer_config = get_node("/root/MultiplayerConfig")
		_lobby_server_url = _multiplayer_config.get_lobby_url()
		print("[CodeBreakerLobby] Using MultiplayerConfig autoload")
		print("[CodeBreakerLobby] Lobby URL: ", _lobby_server_url)
	else:
		push_error("[CodeBreakerLobby] MultiplayerConfig autoload not found!")
		# Fallback: create new instance
		var MultiplayerConfigScript = load("res://script/MultiplayerConfig.gd")
		if MultiplayerConfigScript:
			_multiplayer_config = MultiplayerConfigScript.new()
			add_child(_multiplayer_config)
			_lobby_server_url = _multiplayer_config.get_lobby_url()
			push_warning("[CodeBreakerLobby] Using fallback MultiplayerConfig instance")
	
	print("[CodeBreakerLobby] Multiplayer config initialized")
	print("[CodeBreakerLobby] Lobby server: %s" % _lobby_server_url)

# =============================================================================
# SERVER WAKE-UP LOGIC (Render.com Free Tier Fix)
# =============================================================================

func _ping_server_to_wake() -> void:
	"""
	Ping the server to wake it up if it's sleeping (Render.com free tier).
	Render free tier sleeps after 15 minutes of inactivity.
	First request after sleep takes 30-60 seconds to wake up.
	"""
	print("[CodeBreakerLobby] 🔔 Pinging server to wake up...")
	
	var ping_http := HTTPRequest.new()
	ping_http.timeout = 60.0  # Long timeout for wake-up
	add_child(ping_http)
	
	var ping_state := {"completed": false}  # Use dictionary to avoid capture reassignment
	
	ping_http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, _body: PackedByteArray):
		if code == 200:
			print("[CodeBreakerLobby] ✅ Server is awake!")
		else:
			print("[CodeBreakerLobby] ⚠️ Ping returned code: %d (server might still be waking up)" % code)
		ping_state["completed"] = true
		ping_http.queue_free()
	)
	
	# Send ping request
	var ping_url = _multiplayer_config.get_api_endpoint("/ping")
	print("[CodeBreakerLobby] Ping URL: ", ping_url)
	ping_http.request(ping_url)
	
	# Wait for response (max 60 seconds)
	var wait_time := 0.0
	while not ping_state["completed"] and wait_time < 5.0:
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5
		
		# Update button text with countdown
		if create_btn and wait_time < 5.0:
			var remaining := int(5.0 - wait_time)
			create_btn.text = "Creating Room... (%ds)" % remaining
	
	if not ping_state["completed"]:
		print("[CodeBreakerLobby] ⚠️ Ping timeout, but continuing anyway...")
		if is_instance_valid(ping_http):
			ping_http.queue_free()
	
	# Small delay to ensure server is fully ready
	await get_tree().create_timer(1.0).timeout
	print("[CodeBreakerLobby] ✅ Ready to create room!")


# Option B: No network helper needed for relay architecture
# All network complexity handled by relay server
# No port forwarding, UPnP, or IP detection needed
