extends Node

"""
TEMPORARY: Force LAN mode for testing
Add as autoload in Project Settings
"""

func _ready() -> void:
	# Force LAN mode globally
	if has_node("/root/MultiplayerConfig"):
		var config = get_node("/root/MultiplayerConfig")
		config.set_mode(config.Mode.LAN)
		print("🔧 [ForceNetworkMode] FORCED LAN MODE!")
		print("🔧 Lobby URL: ", config.get_lobby_url())
