extends Node

"""
WebSocketRelayClient.gd
Client for WebSocket-based multiplayer relay (Option B Architecture)

Connects to relay server at /ws/relay/:room_id
Both host and client use this for gameplay communication
"""

signal connected_to_relay
signal disconnected_from_relay
signal message_received(data: Dictionary)
signal error_occurred(message: String)

var _ws: WebSocketPeer = null
var _connected: bool = false
var _room_id: String = ""
var _player_id: String = ""
var _username: String = ""
var _relay_url: String = ""

func _ready() -> void:
	set_process(false)

func connect_to_relay(relay_url: String, room_id: String, player_id: String, username: String) -> void:
	"""Connect to WebSocket relay server"""
	if _connected:
		push_warning("[WebSocketRelay] Already connected")
		return
	
	_relay_url = relay_url
	_room_id = room_id
	_player_id = player_id
	_username = username
	
	# Convert HTTP URL to WebSocket URL
	var ws_url = _relay_url.replace("https://", "wss://").replace("http://", "ws://")
	ws_url += "/ws/relay/" + room_id
	ws_url += "?player_id=" + player_id + "&username=" + username
	
	print("[WebSocketRelay] Connecting to: ", ws_url)
	
	_ws = WebSocketPeer.new()
	var error = _ws.connect_to_url(ws_url)
	
	if error != OK:
		push_error("[WebSocketRelay] Failed to connect: ", error)
		error_occurred.emit("Connection failed")
		return
	
	set_process(true)
	print("[WebSocketRelay] Connection initiated...")

func disconnect_from_relay() -> void:
	"""Disconnect from relay server"""
	if _ws:
		_ws.close()
		_ws = null
	_connected = false
	set_process(false)
	print("[WebSocketRelay] Disconnected")

func send_message(data: Dictionary) -> void:
	"""Send message to other player(s) via relay"""
	if not _connected or not _ws:
		push_warning("[WebSocketRelay] Not connected, cannot send message")
		return
	
	var json = JSON.stringify(data)
	var error = _ws.send_text(json)
	
	if error != OK:
		push_error("[WebSocketRelay] Failed to send message: ", error)

func is_relay_connected() -> bool:
	return _connected

func _process(_delta: float) -> void:
	if not _ws:
		return
	
	_ws.poll()
	
	var state = _ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			print("[WebSocketRelay] ✅ Connected to relay server!")
			connected_to_relay.emit()
		
		# Receive messages
		while _ws.get_available_packet_count() > 0:
			var packet = _ws.get_packet()
			var json_str = packet.get_string_from_utf8()
			
			var data = JSON.parse_string(json_str)
			if typeof(data) == TYPE_DICTIONARY:
				_handle_message(data)
			else:
				push_warning("[WebSocketRelay] Invalid message format")
	
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = _ws.get_close_code()
		var reason = _ws.get_close_reason()
		print("[WebSocketRelay] Connection closed. Code: %d, Reason: %s" % [code, reason])
		
		if _connected:
			_connected = false
			disconnected_from_relay.emit()
		
		set_process(false)

func _handle_message(data: Dictionary) -> void:
	"""Handle incoming message from relay"""
	var msg_type = data.get("type", "")
	
	match msg_type:
		"connected":
			print("[WebSocketRelay] Welcome message received")
		
		"player_connected":
			var other_player = data.get("username", "Player")
			var count = data.get("players_count", 0)
			print("[WebSocketRelay] %s joined the room (%d/2 players)" % [other_player, count])
		
		"player_disconnected":
			var other_player = data.get("username", "Player")
			print("[WebSocketRelay] %s left the room" % other_player)
		
		"error":
			var err_msg = data.get("message", "Unknown error")
			push_error("[WebSocketRelay] Server error: ", err_msg)
			error_occurred.emit(err_msg)
		
		_:
			# Game-specific message, emit for handling
			message_received.emit(data)
