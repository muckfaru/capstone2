extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")

# UI References
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_progress: ProgressBar = $HostCard/HostProgressBar

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_progress: ProgressBar = $ClientCard/ClientProgressBar

@onready var _status_message: Label = $StatusMessage

# Colors
const COLOR_LOADING := Color(1, 0.36, 0.43, 1)  # Pink-red
const COLOR_READY := Color(0, 0.82, 1, 1)  # Cyan

# Loading state
var _room_id: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _game_start_time: int = 0
var _lobby_server_url: String = ""

# Loading progress
var _self_loaded: bool = false
var _opponent_loaded: bool = false
var _loading_progress: float = 0.0
var _countdown_started: bool = false

# Timers
var _progress_timer: Timer
var _timeout_timer: Timer
var _transition_timer: Timer
var _retry_timer: Timer

const LOADING_TIMEOUT := 60.0  # Increased to 60s for better stability
const TRANSITION_DELAY := 2.0  # Wait 2s after both ready
const RETRY_INTERVAL := 2.0    # Retry message every 2 seconds
const MAX_RETRIES := 5         # Retry up to 5 times before timeout
const RELAY_SETTLING_DELAY := 10.0 # Wait 10s for relay to stabilize

var _retry_count: int = 0      # How many times we've retried
var _message_sent: bool = false # Did we already send loading status?

func _ready() -> void:
	print("[Loading] Scene initialized")
	 
	# Get init data from room
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_loading_init"):
		init = get_tree().get_meta("code_breaker_loading_init")
		get_tree().set_meta("code_breaker_loading_init", null)
	
	_room_id = str(init.get("room_id", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_game_start_time = int(init.get("game_start_time", 0))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	# Persist last known session so relogin can resume to reconnect
	_SessionStore.save_session(
		_room_id,
		_lobby_server_url,
		_player_id,
		Auth.current_username if Auth else "Player",
		"loading"
	)
	
	print("[Loading] 🎮 Init data:")
	print("  Player ID: %s" % _player_id)
	print("  Is Host: %s" % _is_host)
	print("  Host Data: %s" % _host_data)
	print("  Client Data: %s" % _client_data)
	
	if _relay_client == null:
		push_error("[Loading] No relay client! Going to reconnect...")
		_go_to_reconnect("Missing relay client")
		return
	
	# Adopt relay_client if it's attached to root
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)
		print("[Loading] ✅ Adopted relay client from root")
	
	# Check if relay is actually connected
	if _relay_client and _relay_client.has_method("is_relay_connected"):
		var relay_connected = _relay_client.is_relay_connected()
		print("[Loading] Relay connection status: %s" % ("CONNECTED" if relay_connected else "DISCONNECTED"))
		if not relay_connected:
			push_warning("[Loading] ⚠️ Relay not connected! This may cause sync issues.")
	
	print("[Loading] Room: %s | Player: %s | Is Host: %s" % [_room_id, _player_id, _is_host])
	
	# Setup UI
	_setup_ui()
	
	# Connect relay signals
	if not _relay_client.message_received.is_connected(_on_relay_message):
		_relay_client.message_received.connect(_on_relay_message)
	
	# Setup timers
	_setup_timers()
	
	# Start loading simulation
	_simulate_loading()
	
	# IMPORTANT: Wait longer for relay to be fully connected before sending first message
	# This prevents race condition where message arrives before opponent's relay is ready
	print("[Loading] ⏳ Waiting 1.5s for relay to stabilize...")
	await get_tree().create_timer(1.5).timeout
	print("[Loading] ✅ Relay settling delay complete, now sending loading status...")
	
	# Send "I'm loading" message
	_send_loading_status("loading")

func _setup_ui() -> void:
	"""Setup player cards - Left is YOU, Right is OPPONENT"""
	if _is_host:
		# I am host - show myself on left, client on right
		_host_username.text = str(_host_data.get("username", "Host"))
		_host_status.text = "⏳ Loading..."
		_host_status.add_theme_color_override("font_color", COLOR_LOADING)
		_host_progress.value = 0.0
		
		_client_username.text = str(_client_data.get("username", "Client"))
		_client_status.text = "⏳ Loading..."
		_client_status.add_theme_color_override("font_color", COLOR_LOADING)
		_client_progress.value = 0.0
	else:
		# I am client - show myself on left, host on right
		_host_username.text = str(_client_data.get("username", "Client"))
		_host_status.text = "⏳ Loading..."
		_host_status.add_theme_color_override("font_color", COLOR_LOADING)
		_host_progress.value = 0.0
		
		_client_username.text = str(_host_data.get("username", "Host"))
		_client_status.text = "⏳ Loading..."
		_client_status.add_theme_color_override("font_color", COLOR_LOADING)
		_client_progress.value = 0.0
	
	_status_message.text = "Preparing arena..."

func _setup_timers() -> void:
	"""Setup loading and timeout timers"""
	# Progress animation timer (update progress bar)
	_progress_timer = Timer.new()
	_progress_timer.wait_time = 0.05  # 50ms updates
	_progress_timer.autostart = false
	_progress_timer.one_shot = false
	_progress_timer.timeout.connect(_on_progress_tick)
	add_child(_progress_timer)
	
	# Timeout timer (45s max with buffer)
	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = LOADING_TIMEOUT
	_timeout_timer.autostart = true
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_loading_timeout)
	add_child(_timeout_timer)
	
	# Transition timer (wait before going to arena)
	_transition_timer = Timer.new()
	_transition_timer.wait_time = TRANSITION_DELAY
	_transition_timer.autostart = false
	_transition_timer.one_shot = true
	_transition_timer.timeout.connect(_transition_to_arena)
	add_child(_transition_timer)
	
	# Retry timer (resend loading status if needed)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_INTERVAL
	_retry_timer.autostart = false
	_retry_timer.one_shot = false
	_retry_timer.timeout.connect(_on_retry_timeout)
	add_child(_retry_timer)

func _simulate_loading() -> void:
	"""Simulate loading progress with progress bar animation"""
	print("[Loading] 🔄 Starting loading simulation...")
	_loading_progress = 0.0
	_progress_timer.start()
	
	# Simulate loading tasks
	await get_tree().create_timer(0.5).timeout
	_loading_progress = 30.0  # "Loading assets..."
	print("[Loading] Progress: 30%")
	
	await get_tree().create_timer(0.5).timeout
	_loading_progress = 60.0  # "Initializing game..."
	print("[Loading] Progress: 60%")
	
	await get_tree().create_timer(0.5).timeout
	_loading_progress = 100.0  # "Ready!"
	print("[Loading] Progress: 100%")
	
	# Mark self as loaded
	_self_loaded = true
	print("[Loading] ✅ Self loaded! Sending ready status...")
	_send_loading_status("ready")
	_update_self_status()
	_check_both_ready()  # Check if opponent is already ready
	
	print("[Loading] Self loading complete!")

func _on_progress_tick() -> void:
	"""Update progress bars smoothly"""
	# Update own progress bar
	var target_progress := _loading_progress if not _self_loaded else 100.0
	var current_progress := _host_progress.value if _is_host else _client_progress.value
	
	if current_progress < target_progress:
		var new_progress = min(current_progress + 2.0, target_progress)
		if _is_host:
			_host_progress.value = new_progress
		else:
			_client_progress.value = new_progress

func _send_loading_status(status: String) -> void:
	"""Send loading status to opponent via relay"""
	if _relay_client:
		_relay_client.send_message({
			"type": "loading_status",
			"player_id": _player_id,
			"status": status,
			"timestamp": Time.get_ticks_msec()
		})
		print("[Loading] 📤 Sent status: %s (attempt %d/%d) connected=%s" % [
			status, 
			_retry_count + 1, 
			MAX_RETRIES,
			_relay_client.is_relay_connected()
		])
		_message_sent = true
		
		# Start retry timer if not already running and we haven't exceeded max retries
		if _retry_timer.is_stopped() and _retry_count < MAX_RETRIES:
			_retry_timer.start()
	else:
		push_error("[Loading] ❌ No relay client to send message!")

func _on_relay_message(data: Dictionary) -> void:
	"""Handle relay messages from opponent"""
	var msg_type = data.get("type", "")
	var msg_timestamp = data.get("timestamp", 0)
	var delay_ms = Time.get_ticks_msec() - msg_timestamp if msg_timestamp > 0 else 0
	print("[Loading] 📨 Received relay message: %s (delay: %dms)" % [msg_type, delay_ms])
	
	match msg_type:
		"loading_status":
			var status = data.get("status", "")
			var _sender_id = data.get("player_id", "")
			
			print("[Loading] Opponent status: %s" % status)
			
			if status == "ready":
				_opponent_loaded = true
				print("[Loading] ✅ Opponent is ready!")
				_update_opponent_status()
				_check_both_ready()

		"force_loading_sync":
			# Opponent is (re)joining and wants BOTH clients to sync via Loading.
			# If we were about to transition, cancel and wait again.
			print("[Loading] 🔁 Received force_loading_sync - resetting ready state")
			if _transition_timer and not _transition_timer.is_stopped():
				_transition_timer.stop()
			_countdown_started = false
			_opponent_loaded = false
			_update_opponent_loading()
			_status_message.text = "Resyncing players…"
			_send_loading_status("loading" if not _self_loaded else "ready")
		
		"player_disconnected":
			print("[Loading] ⚠️ Opponent disconnected!")
			_status_message.text = "Opponent disconnected. Reconnecting..."
			await get_tree().create_timer(1.0).timeout
			_go_to_reconnect("Opponent disconnected")

func _update_opponent_loading() -> void:
	"""Update opponent status to LOADING"""
	if _is_host:
		_client_status.text = "⏳ Loading..."
		_client_status.add_theme_color_override("font_color", COLOR_LOADING)
		_client_progress.value = 0.0
	else:
		_host_status.text = "⏳ Loading..."
		_host_status.add_theme_color_override("font_color", COLOR_LOADING)
		_host_progress.value = 0.0

func _update_self_status() -> void:
	"""Update own status to READY"""
	if _is_host:
		_host_status.text = "✅ Ready!"
		_host_status.add_theme_color_override("font_color", COLOR_READY)
		_host_progress.value = 100.0
	else:
		_client_status.text = "✅ Ready!"
		_client_status.add_theme_color_override("font_color", COLOR_READY)
		_client_progress.value = 100.0

func _update_opponent_status() -> void:
	"""Update opponent status to READY"""
	if _is_host:
		_client_status.text = "✅ Ready!"
		_client_status.add_theme_color_override("font_color", COLOR_READY)
		_client_progress.value = 100.0
	else:
		_host_status.text = "✅ Ready!"
		_host_status.add_theme_color_override("font_color", COLOR_READY)
		_host_progress.value = 100.0

func _check_both_ready() -> void:
	"""Check if both players are ready, then transition"""
	if _self_loaded and _opponent_loaded and not _countdown_started:
		_countdown_started = true
		_progress_timer.stop()
		_timeout_timer.stop()
		_retry_timer.stop()  # Stop retrying once both are ready
		
		print("[Loading] ✅ Both players ready! Starting in %ds..." % TRANSITION_DELAY)
		_status_message.text = "Both players ready! Starting match..."
		
		# Start transition countdown
		_transition_timer.start()

func _on_retry_timeout() -> void:
	"""Retry sending loading status if opponent hasn't responded"""
	if _countdown_started or not _message_sent:
		_retry_timer.stop()
		return  # Already transitioned or haven't sent initial message
	
	_retry_count += 1
	
	if _retry_count < MAX_RETRIES:
		print("[Loading] 🔄 Retry #%d: Re-sending loading status..." % _retry_count)
		_send_loading_status("loading" if not _self_loaded else "ready")
	else:
		print("[Loading] ⚠️ Max retries exceeded! Waiting for timeout...")
		_retry_timer.stop()

func _on_loading_timeout() -> void:
	"""Handle loading timeout (45 seconds)"""
	if _countdown_started:
		return  # Already transitioning
	
	_retry_timer.stop()
	
	print("[Loading] ⏰ Loading timeout after %ds!" % LOADING_TIMEOUT)
	_status_message.text = "Loading timeout. Reconnecting..."
	
	await get_tree().create_timer(1.0).timeout
	_go_to_reconnect("Loading timeout")

func _go_to_reconnect(reason: String) -> void:
	print("[Loading] 🔄 Going to reconnect scene. Reason: ", reason)
	
	# Disconnect relay signals
	if _relay_client and _relay_client.message_received.is_connected(_on_relay_message):
		_relay_client.message_received.disconnect(_on_relay_message)
	
	# Preserve relay client if present
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)
	
	var init := {
		"room_id": _room_id,
		"lobby_server_url": _lobby_server_url,
		"player_id": _player_id,
		"username": Auth.current_username if Auth else "Player",
		"is_host": _is_host,
		"relay_client": _relay_client,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"reason": reason
	}
	get_tree().set_meta("code_breaker_reconnect_init", init)
	
	var reconnect_scene := load("res://scene/code_breaker_reconnect.tscn")
	if reconnect_scene:
		get_tree().change_scene_to_packed(reconnect_scene)
	else:
		push_error("[Loading] code_breaker_reconnect.tscn not found; returning to room")
		_return_to_room()

func _transition_to_arena() -> void:
	"""Transition to arena scene"""
	print("[Loading] 🎮 Transitioning to arena...")
	
	# Disconnect relay signals
	if _relay_client and _relay_client.message_received.is_connected(_on_relay_message):
		_relay_client.message_received.disconnect(_on_relay_message)
	
	# IMPORTANT: Reparent relay_client to root so it doesn't get freed with the loading scene
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)
	
	# Pass data to arena
	var arena_init := {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"lobby_server_url": _lobby_server_url
	}
	get_tree().set_meta("code_breaker_arena_init", arena_init)
	
	# Load arena
	var arena_scene := load("res://scene/code_breaker_arena.tscn")
	if arena_scene:
		get_tree().change_scene_to_packed(arena_scene)
	else:
		push_error("[Loading] Failed to load arena scene!")
		_return_to_room()

func _return_to_room() -> void:
	"""Return to room on error"""
	print("[Loading] Returning to room...")
	
	# Disconnect relay signals
	if _relay_client and _relay_client.message_received.is_connected(_on_relay_message):
		_relay_client.message_received.disconnect(_on_relay_message)
	
	# Pass data back to room
	var room_init := {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"lobby_server_url": _lobby_server_url,
		"from_loading": true,
		"is_host": _is_host
	}
	get_tree().set_meta("code_breaker_room_init", room_init)
	
	# Load room
	var room_scene := load("res://scene/code_breaker_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
