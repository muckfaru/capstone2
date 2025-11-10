extends Node

"""
MultiplayerConfig.gd
Configuration for lobby server URLs and multiplayer settings.
Option A: Pure Direct P2P Architecture
"""

enum Mode {
	LOCALHOST,   # Development: localhost (PC only)
	LAN,         # LAN Testing: Local network IP (same WiFi)
	TUNNEL,      # Testing: NodeTunnel or ngrok
	PRODUCTION   # Deployed: Cloud server (Render, Railway, etc.)
}

const LOBBY_URLS = {
	Mode.LOCALHOST: "http://localhost:8080",
	Mode.LAN: "http://192.168.100.49:8080",  # PC's local IP (update if needed)
	Mode.TUNNEL: "https://your-tunnel-url.onrender.com",  # Update with actual tunnel URL
	Mode.PRODUCTION: "https://codebreaker-lobby.onrender.com"  # ✅ Render.com deployed!
}

const DEFAULT_PORT := 7777
const HEARTBEAT_INTERVAL := 30.0  # seconds

var current_mode: Mode = Mode.LOCALHOST  # Use localhost for testing updated server
var custom_tunnel_url: String = ""

## Get the lobby server base URL
func get_lobby_url() -> String:
	if current_mode == Mode.TUNNEL and custom_tunnel_url != "":
		return custom_tunnel_url
	
	return LOBBY_URLS.get(current_mode, LOBBY_URLS[Mode.LOCALHOST])


## Set the mode (LOCALHOST, TUNNEL, or PRODUCTION)
func set_mode(mode: Mode) -> void:
	current_mode = mode
	print("[MultiplayerConfig] Mode set to: %s" % Mode.keys()[mode])


## Set custom tunnel URL (for NodeTunnel or ngrok)
func set_tunnel_url(url: String) -> void:
	custom_tunnel_url = url
	current_mode = Mode.TUNNEL
	print("[MultiplayerConfig] Tunnel URL set to: %s" % url)


## Get the full API endpoint
func get_api_endpoint(path: String) -> String:
	var base_url = get_lobby_url()
	# Remove trailing slash from base_url if present
	if base_url.ends_with("/"):
		base_url = base_url.substr(0, base_url.length() - 1)
	
	# Ensure path starts with /
	if not path.begins_with("/"):
		path = "/" + path
	
	return base_url + path


## Print current config
func print_config() -> void:
	print("[MultiplayerConfig] === Current Configuration ===")
	print("  Mode: %s" % Mode.keys()[current_mode])
	print("  Lobby URL: %s" % get_lobby_url())
	print("  Default Port: %d" % DEFAULT_PORT)
	print("  Heartbeat Interval: %.1fs" % HEARTBEAT_INTERVAL)
