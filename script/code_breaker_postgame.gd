extends Control

# UI References
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_xp: Label = $HostCard/HostXP
@onready var _host_time: Label = $HostCard/HostTime
@onready var _host_powerups: Label = $HostCard/HostPowerups
@onready var _host_winner_badge: Label = $HostCard/WinnerBadge

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_xp: Label = $ClientCard/ClientXP
@onready var _client_time: Label = $ClientCard/ClientTime
@onready var _client_powerups: Label = $ClientCard/ClientPowerups
@onready var _client_winner_badge: Label = $ClientCard/WinnerBadge

@onready var _back_button: Button = $BackToLandingButton

# Game data
var _room_id: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _lobby_server_url: String = ""

# Game results
var _winner_id: String = ""
var _host_score: int = 0
var _client_score: int = 0
var _host_health: int = 0
var _client_health: int = 0
var _game_duration: float = 0.0
var _host_powerups_used: int = 0
var _client_powerups_used: int = 0
var _result_unknown: bool = false

# Colors
const COLOR_WINNER := Color(1, 0.84, 0, 1)  # Gold
const COLOR_LOSER := Color(1, 0.36, 0.43, 1)  # Pink-red
const COLOR_XP_WIN := Color(0, 1, 0.5, 1)  # Green
const COLOR_XP_LOSE := Color(0.8, 0.8, 0.8, 1)  # Grey

const XP_WINNER := 500
const XP_LOSER := 0

func _ready() -> void:
	print("[PostGame] Scene initialized")
	
	# Get init data from arena
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_postgame_init"):
		init = get_tree().get_meta("code_breaker_postgame_init")
		get_tree().set_meta("code_breaker_postgame_init", null)
	
	_room_id = str(init.get("room_id", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	
	_winner_id = str(init.get("winner_id", ""))
	_host_score = int(init.get("host_score", 0))
	_client_score = int(init.get("client_score", 0))
	_host_health = int(init.get("host_health", 0))
	_client_health = int(init.get("client_health", 0))
	_game_duration = float(init.get("game_duration", 0.0))
	_host_powerups_used = int(init.get("host_powerups_used", 0))
	_client_powerups_used = int(init.get("client_powerups_used", 0))
	_result_unknown = bool(init.get("result_unknown", false))
	
	print("[PostGame] 🎮 Init data:")
	print("  Winner: %s" % _winner_id)
	print("  Host Score: %d | Client Score: %d" % [_host_score, _client_score])
	print("  Host Health: %d | Client Health: %d" % [_host_health, _client_health])
	print("  Game Duration: %.2fs" % _game_duration)
	
	# Adopt relay_client if needed
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)
		print("[PostGame] ✅ Adopted relay client from root")
	
	# Setup UI with results
	_setup_ui()
	
	# Connect button
	_back_button.pressed.connect(_on_back_to_landing_pressed)
	
	# Animate in
	_animate_in()

func _setup_ui() -> void:
	"""Setup UI with game results"""
	# Determine winners and losers based on winner_id
	var host_player_id: String = str(_host_data.get("player_id", ""))
	var client_player_id: String = str(_client_data.get("player_id", ""))

	# Default: hide badges until explicitly shown
	_host_winner_badge.visible = false
	_client_winner_badge.visible = false

	# If we don't know the winner (reconnect-after-finished path), show a neutral result.
	if _result_unknown or _winner_id == "" or (host_player_id != "" and client_player_id != "" and _winner_id != host_player_id and _winner_id != client_player_id):
		_host_username.text = str(_host_data.get("username", "Host"))
		_client_username.text = str(_client_data.get("username", "Client"))

		_host_status.text = "🏁 MATCH ENDED"
		_client_status.text = "🏁 MATCH ENDED"
		_host_status.add_theme_color_override("font_color", COLOR_WINNER)
		_client_status.add_theme_color_override("font_color", COLOR_WINNER)

		_host_xp.text = "XP: +0"
		_client_xp.text = "XP: +0"
		_host_xp.add_theme_color_override("font_color", COLOR_XP_LOSE)
		_client_xp.add_theme_color_override("font_color", COLOR_XP_LOSE)

		_host_time.text = "Time: %s" % _format_time(_game_duration)
		_client_time.text = "Time: %s" % _format_time(_game_duration)
		_host_powerups.text = "Power-ups: %d" % _host_powerups_used
		_client_powerups.text = "Power-ups: %d" % _client_powerups_used
		return
	
	print("[PostGame] DEBUG - Winner ID: %s" % _winner_id)
	print("[PostGame] DEBUG - Host Player ID: %s" % host_player_id)
	print("[PostGame] DEBUG - Client Player ID: %s" % client_player_id)
	
	var host_won: bool = _winner_id == host_player_id
	var client_won: bool = _winner_id == client_player_id
	
	print("[PostGame] DEBUG - Host Won: %s | Client Won: %s" % [host_won, client_won])
	
	# Host Card
	_host_username.text = str(_host_data.get("username", "Host"))
	_host_status.text = "❌ DEFEATED" if not host_won else "✅ VICTORY"
	_host_status.add_theme_color_override("font_color", COLOR_WINNER if host_won else COLOR_LOSER)
	
	var host_xp = XP_WINNER if host_won else XP_LOSER
	_host_xp.text = "XP: +%d" % host_xp
	_host_xp.add_theme_color_override("font_color", COLOR_XP_WIN if host_won else COLOR_XP_LOSE)
	
	_host_time.text = "Time: %s" % _format_time(_game_duration)
	_host_powerups.text = "Power-ups: %d" % _host_powerups_used
	
	if host_won:
		_host_winner_badge.visible = true
	
	# Client Card
	_client_username.text = str(_client_data.get("username", "Client"))
	_client_status.text = "❌ DEFEATED" if not client_won else "✅ VICTORY"
	_client_status.add_theme_color_override("font_color", COLOR_WINNER if client_won else COLOR_LOSER)
	
	var client_xp = XP_WINNER if client_won else XP_LOSER
	_client_xp.text = "XP: +%d" % client_xp
	_client_xp.add_theme_color_override("font_color", COLOR_XP_WIN if client_won else COLOR_XP_LOSE)
	
	_client_time.text = "Time: %s" % _format_time(_game_duration)
	_client_powerups.text = "Power-ups: %d" % _client_powerups_used
	
	if client_won:
		_client_winner_badge.visible = true

func _animate_in() -> void:
	"""Animate cards and results in"""
	# Fade in both cards with a slight bounce
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Host card animation
	var host_card = $HostCard
	host_card.modulate.a = 0.0
	tween.tween_property(host_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(host_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))
	
	# Client card animation
	var client_card = $ClientCard
	client_card.modulate.a = 0.0
	tween.tween_property(client_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(client_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))
	
	# Button animation
	var button = _back_button
	button.modulate.a = 0.0
	await tween.finished
	
	tween = create_tween()
	tween.tween_property(button, "modulate:a", 1.0, 0.3)

func _format_time(seconds: float) -> String:
	"""Format seconds to M:SS format"""
	var mins = int(seconds / 60.0)
	var secs = int(seconds) % 60
	return "%dm %ds" % [mins, secs]

func _on_back_to_landing_pressed() -> void:
	"""Handle back to landing button press"""
	print("[PostGame] 🔙 Back to Landing pressed")
	
	# Clean up relay connection
	if _relay_client:
		if _relay_client.message_received.is_connected(_on_relay_message):
			_relay_client.message_received.disconnect(_on_relay_message)
		_relay_client.queue_free()
	
	# Clear postgame data
	get_tree().root.set_meta("code_breaker_lobby_init", null)
	get_tree().root.set_meta("arena_init", null)
	
	# Load landing
	var landing_scene := load("res://scene/landing.tscn")
	if landing_scene:
		get_tree().change_scene_to_packed(landing_scene)
	else:
		push_error("[PostGame] Failed to load landing scene!")

func _on_relay_message(data: Dictionary) -> void:
	"""Handle any relay messages (for future use like friend notifications)"""
	var msg_type = data.get("type", "")
	print("[PostGame] 📨 Received relay message: %s" % msg_type)
