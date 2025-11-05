extends Node

## Multiplayer Manager - Handles WebSocket peer setup for Code Breaker Arena
## Uses WebSocketMultiplayerPeer for Godot's built-in multiplayer system

signal connection_ready
signal connection_failed(error: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const DEFAULT_PORT := 9999
const MAX_CLIENTS := 2  # 1v1 only

var multiplayer_peer: WebSocketMultiplayerPeer = null
var _is_host: bool = false
var _room_id: String = ""

func setup_host(room_id: String, port: int = DEFAULT_PORT) -> bool:
	"""Setup as host (server)"""
	print("[MultiplayerManager] Setting up as host on port %d" % port)
	
	_is_host = true
	_room_id = room_id
	
	multiplayer_peer = WebSocketMultiplayerPeer.new()
	
	# Create server (no TLS for local network)
	var error = multiplayer_peer.create_server(port)
	if error != OK:
		print("[MultiplayerManager] Failed to create server: %d" % error)
		emit_signal("connection_failed", "Failed to create server: %d" % error)
		return false
	
	# Set as the multiplayer peer
	get_tree().get_multiplayer().multiplayer_peer = multiplayer_peer
	
	# Connect signals
	get_tree().get_multiplayer().peer_connected.connect(_on_peer_connected)
	get_tree().get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)
	
	print("[MultiplayerManager] Host server created on port %d" % port)
	print("[MultiplayerManager] Waiting for client to connect...")
	
	# Host emits connection_ready immediately (server is listening)
	# The actual peer connection will trigger peer_connected signal
	emit_signal("connection_ready")
	return true

func setup_client(host_address: String, port: int = DEFAULT_PORT) -> bool:
	"""Setup as client"""
	print("[MultiplayerManager] Connecting to host: %s:%d" % [host_address, port])
	
	_is_host = false
	
	multiplayer_peer = WebSocketMultiplayerPeer.new()
	
	# Create client connection (no TLS for local network)
	var url = "ws://%s:%d" % [host_address, port]
	var error = multiplayer_peer.create_client(url)
	
	if error != OK:
		print("[MultiplayerManager] Failed to create client: %d" % error)
		emit_signal("connection_failed", "Failed to connect: %d" % error)
		return false
	
	# Set as the multiplayer peer
	get_tree().get_multiplayer().multiplayer_peer = multiplayer_peer
	
	# Connect signals
	get_tree().get_multiplayer().connected_to_server.connect(_on_connected_to_server)
	get_tree().get_multiplayer().connection_failed.connect(_on_connection_failed)
	get_tree().get_multiplayer().server_disconnected.connect(_on_server_disconnected)
	
	print("[MultiplayerManager] Connecting to host...")
	return true

func disconnect_peer() -> void:
	"""Disconnect from multiplayer session"""
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	
	get_tree().get_multiplayer().multiplayer_peer = null
	print("[MultiplayerManager] Disconnected")

func is_host() -> bool:
	return _is_host

func get_room_id() -> String:
	return _room_id

# =============================================================================
# SIGNAL CALLBACKS
# =============================================================================

func _on_peer_connected(id: int) -> void:
	print("[MultiplayerManager] Peer connected: %d" % id)
	emit_signal("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("[MultiplayerManager] Peer disconnected: %d" % id)
	emit_signal("peer_disconnected", id)

func _on_connected_to_server() -> void:
	print("[MultiplayerManager] Successfully connected to server")
	emit_signal("connection_ready")

func _on_connection_failed() -> void:
	print("[MultiplayerManager] Connection to server failed")
	emit_signal("connection_failed", "Could not connect to host")

func _on_server_disconnected() -> void:
	print("[MultiplayerManager] Disconnected from server")
	emit_signal("peer_disconnected", 1)

# =============================================================================
# HELPER METHODS
# =============================================================================

func get_local_ip() -> String:
	"""Get local network IP address"""
	var addresses = IP.get_local_addresses()
	for address in addresses:
		# Filter out localhost and IPv6
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"

func get_peer_count() -> int:
	"""Get number of connected peers"""
	return get_tree().get_multiplayer().get_peers().size()
