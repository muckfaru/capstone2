extends Node

"""
TEMPORARY: Force LAN mode for testing
Add as autoload in Project Settings
"""

func _ready() -> void:
	# Force PRODUCTION mode for cloud deployment (different networks)
	# Change to LAN for same WiFi testing
	if has_node("/root/MultiplayerConfig"):
		var config = get_node("/root/MultiplayerConfig")
		config.set_mode(config.Mode.PRODUCTION)  # Changed from LAN to PRODUCTION
		print("🔧 [ForceNetworkMode] FORCED PRODUCTION MODE!")
		print("🔧 Lobby URL: ", config.get_lobby_url())
