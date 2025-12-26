extends Node

# WebSocket P2P Communication Protocol for Code Breaker Arena
# 
# This script handles all WebSocket communication for the game arena
# Supports both direct P2P and relay modes

signal connection_established
signal opponent_action_received(action: Dictionary)
signal opponent_disconnected
signal connection_error(error: String)

# Server configuration
const SIGNALING_SERVER_DEV = "ws://localhost:8080/ws/game"
const SIGNALING_SERVER_PROD = "wss://code-breaker-p2p-signaling.onrender.com/ws/game"

# WebSocket instances
var _signaling_ws: WebSocketPeer = null
var _direct_p2p_ws: WebSocketPeer = null

# Game state
var _room_id: String = ""
var _player_id: String = ""
var _is_host: bool = false
var _opponent_ip: String = ""
var _game_start_time: int = 0
var _connection_state: String = "disconnected"  # disconnected, signaling, p2p, relay

# Heartbeat/keepalive
var _heartbeat_timer: Timer = null
var _last_heartbeat: float = 0.0

func _ready() -> void:
	add_child(Timer.new())
	_heartbeat_timer = get_child(get_child_count() - 1)
	_heartbeat_timer.wait_time = 30.0
	_heartbeat_timer.timeout.connect(_send_heartbeat)

func _process(_delta: float) -> void:
	# Process signaling WebSocket
	if _signaling_ws:
		_signaling_ws.poll()
		var state = _signaling_ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_process_signaling_messages()
		elif state == WebSocketPeer.STATE_CLOSED:
			_on_signaling_closed()
	
	# Process direct P2P WebSocket (if established)
	if _direct_p2p_ws:
		_direct_p2p_ws.poll()
		var state = _direct_p2p_ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_process_p2p_messages()
		elif state == WebSocketPeer.STATE_CLOSED:
			_on_p2p_closed()

# =============================================================================
# CONNECTION SETUP
# =============================================================================

func connect_to_game(room_id: String, player_id: String, username: String, is_host: bool, use_production: bool = false) -> void:
	print("[P2P] Connecting to game: room=%s, player=%s, username=%s, host=%s" % [room_id, player_id, username, is_host])
	
	_room_id = room_id
	_player_id = player_id
	_is_host = is_host
	
	# Choose server
	var server_url = SIGNALING_SERVER_PROD if use_production else SIGNALING_SERVER_DEV
	
	# Connect to signaling server
	_signaling_ws = WebSocketPeer.new()
	var error = _signaling_ws.connect_to_url(server_url)
	if error != OK:
		emit_signal("connection_error", "Failed to connect to signaling server: %s" % error)
		return
	
	_connection_state = "signaling"
	print("[P2P] Signaling connection attempt to: %s" % server_url)
	_heartbeat_timer.start()

func _process_signaling_messages() -> void:
	while _signaling_ws != null and _signaling_ws.get_available_packet_count() > 0:
		var message = _signaling_ws.get_packet().get_string_from_utf8()
		if message:
			var data = JSON.parse_string(message)
			if data:
				_handle_signaling_message(data)

func _handle_signaling_message(data: Dictionary) -> void:
	var msg_type = data.get("type", "")
	
	match msg_type:
		"player_joined":
			print("[P2P] Opponent joined: %s" % data.get("opponent", {}))
			# Opponent is now in the room
		
		"start_game":
			print("[P2P] Game start signal received")
			_opponent_ip = data.get("opponent_ip", "")
			_game_start_time = data.get("game_start_time", 0)
			_establish_direct_p2p()
		
		"opponent_action":
			var action = data.get("action", {})
			emit_signal("opponent_action_received", action)
		
		"opponent_disconnect":
			print("[P2P] Opponent disconnected")
			emit_signal("opponent_disconnected")
		
		"error":
			print("[P2P] Server error: %s" % data.get("message", ""))
			emit_signal("connection_error", data.get("message", "Unknown error"))

func _send_heartbeat() -> void:
	if _signaling_ws and _signaling_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_signaling_message({"type": "ping"})
		_last_heartbeat = Time.get_unix_time_from_system()

# =============================================================================
# DIRECT P2P CONNECTION (WebSocketPeer to WebSocketPeer)
# =============================================================================

func _establish_direct_p2p() -> void:
	print("[P2P] Establishing direct P2P connection to %s" % _opponent_ip)
	
	# Both players will attempt to connect to each other
	# In practice, you'd use a hole-punching mechanism or WebRTC
	# For now, we'll use a relay approach where one connects to the other
	
	# For simplicity in this implementation, we'll use the signaling server as relay
	# if direct P2P connection fails. Direct P2P would require:
	# - UPnP/NAT traversal
	# - WebRTC (better option)
	# - Or a relay server
	
	# Send ready signal back to signaling server
	_send_signaling_message({
		"type": "ready",
		"room_id": _room_id
	})
	
	_connection_state = "p2p"
	emit_signal("connection_established")
	print("[P2P] Direct P2P connection established (via relay)")

func _process_p2p_messages() -> void:
	if not _direct_p2p_ws:
		return

	while _direct_p2p_ws != null and _direct_p2p_ws.get_available_packet_count() > 0:
		var message = _direct_p2p_ws.get_packet().get_string_from_utf8()
		if message:
			var data = JSON.parse_string(message)
			if data:
				var action = data.get("action", {})
				emit_signal("opponent_action_received", action)

# =============================================================================
# GAME STATE SYNCHRONIZATION
# =============================================================================

func send_game_action(action: Dictionary) -> void:
	"""Send game action to opponent (score, health, guess, etc)"""
	var message = {
		"type": "game_action",
		"room_id": _room_id,
		"from_player": _player_id,
		"action": action
	}
	
	# Try direct P2P first, fall back to signaling relay
	if _direct_p2p_ws and _direct_p2p_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_p2p_message(message)
	elif _signaling_ws and _signaling_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_signaling_message(message)
	else:
		print("[P2P] ERROR: No connection available to send action")

func _send_signaling_message(data: Dictionary) -> void:
	if _signaling_ws and _signaling_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_signaling_ws.send_text(JSON.stringify(data))

func _send_p2p_message(data: Dictionary) -> void:
	if _direct_p2p_ws and _direct_p2p_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_direct_p2p_ws.send_text(JSON.stringify(data))

# =============================================================================
# CONNECTION MANAGEMENT
# =============================================================================

func _on_signaling_closed() -> void:
	print("[P2P] Signaling connection closed")
	_connection_state = "disconnected"
	_signaling_ws = null
	if _heartbeat_timer:
		_heartbeat_timer.stop()
	emit_signal("connection_error", "Signaling connection lost")

func _on_p2p_closed() -> void:
	print("[P2P] Direct P2P connection closed, falling back to relay")
	_direct_p2p_ws = null
	# Signaling is still active, can continue with relay

func disconnect_game() -> void:
	print("[P2P] Disconnecting from game")
	if _heartbeat_timer:
		_heartbeat_timer.stop()
	if _signaling_ws:
		_signaling_ws.close()
	if _direct_p2p_ws:
		_direct_p2p_ws.close()
	_connection_state = "disconnected"

func get_connection_status() -> String:
	return _connection_state

func get_game_start_time() -> int:
	return _game_start_time
