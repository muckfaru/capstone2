extends Control

# UI References
@onready var _host_name_label: Label = $HeaderPanel/HostNameLabel
@onready var _timer_label: Label = $HeaderPanel/TimerLabel
@onready var _client_name_label: Label = $HeaderPanel/ClientNameLabel
@onready var _ws_indicator: ColorRect = $HeaderPanel/WSIndicator
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _p1_score: Label = $VBox/ScorePanel/ScoreP1
@onready var _p2_score: Label = $VBox/ScorePanel/ScoreP2
@onready var _p1_health: ProgressBar = $VBox/ScorePanel/P1HealthBar
@onready var _p2_health: ProgressBar = $VBox/ScorePanel/P2HealthBar
@onready var _type_area: Node = $TypeCodeArea  # TextEdit/LineEdit for typing input (guarded)

const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const ROOMS_PATH := "/codebreaker_rooms"
const GAME_DURATION := 180.0  # 3 minute match (180 seconds)

# Game state
var _room_id: String = ""
var _is_host: bool = false
var _player_id: String = ""
var _host_username: String = "Player 1"
var _client_username: String = "Player 2"
var _game_start_time: float = 0.0

# WebSocket P2P client
var _p2p_client: Node = null
var _use_production_server: bool = true

# Local game state
var _local_score: int = 0
var _local_health: int = 100
var _opponent_score: int = 0
var _opponent_health: int = 100

# Sync timer
var _sync_timer: Timer

# Typing battle state
var _snippets: Array = [
	"for i in range(5):\n\tprint(i)",
	"func add(a:int, b:int) -> int:\n\treturn a + b",
	"if x < 10 and y != 0:\n\tprint(\"ok\")",
	"var total := 0\nfor n in [1,2,3]:\n\ttotal += n",
]
var _current_snippet: String = ""
var _snippet_seq: int = 0
var _typed_text: String = ""
var _updating_input: bool = false

func _ready() -> void:
	print("[CodeBreakerArena] Arena started")
	
	# Load init data
	if get_tree().has_meta("code_breaker_arena_init"):
		var init = get_tree().get_meta("code_breaker_arena_init")
		_room_id = str(init.get("room_id", ""))
		_is_host = bool(init.get("is_host", false))
		_player_id = str(Auth.current_local_id if Auth else "unknown")
		_host_username = str(init.get("host_name", "Player 1"))
		if init.has("room_data"):
			var room_data = init.get("room_data")
			if room_data.has("host"):
				_host_username = str(room_data["host"].get("username", "Player 1"))
			if room_data.has("client"):
				_client_username = str(room_data["client"].get("username", "Player 2"))
			if room_data.has("game_start_time"):
				_game_start_time = int(room_data.get("game_start_time", 0))
		get_tree().set_meta("code_breaker_arena_init", null)
	
	# Update UI with player names
	_host_name_label.text = _host_username
	_client_name_label.text = _client_username
	_status_label.text = "Connecting via WebSocket..."
	
	# Initialize P2P WebSocket client
	_setup_p2p_connection()
	
	# Setup display timer (100ms update)
	_sync_timer = Timer.new()
	_sync_timer.wait_time = 0.1
	_sync_timer.timeout.connect(_on_display_timer_timeout)
	add_child(_sync_timer)
	_sync_timer.start()
	
	# Initial indicator
	if _ws_indicator:
		_ws_indicator.color = Color.YELLOW

	# Wire typing input changes (TextEdit/LineEdit compatible)
	if _type_area and _type_area.has_signal("text_changed"):
		# Some nodes emit text_changed(new_text), some emit without args; support both
		_type_area.text_changed.connect(func(new_text := ""):
			_on_input_text_changed(new_text)
		)
	# Prepare round if host (will broadcast snippet)
	if _is_host:
		_status_label.text = "Preparing round..."
		_start_round()
	else:
		_status_label.text = "Waiting for host to send snippet..."

func _setup_p2p_connection() -> void:
	"""Initialize P2P WebSocket connection"""
	# Load P2P client
	var p2p_script = load("res://script/P2PWebSocketClient.gd")
	_p2p_client = Node.new()
	_p2p_client.set_script(p2p_script)
	add_child(_p2p_client)
	
	# Connect signals
	if _p2p_client:
		_p2p_client.connection_established.connect(_on_p2p_connected)
		_p2p_client.opponent_action_received.connect(_on_opponent_action)
		_p2p_client.opponent_disconnected.connect(_on_opponent_disconnected)
		_p2p_client.connection_error.connect(_on_p2p_error)
		
		# Connect to signaling server
		var username = str(Auth.current_username if Auth else "Player")
		_p2p_client.connect_to_game(_room_id, _player_id, username, _is_host, _use_production_server)
		print("[Arena] P2P connection initiated for room: %s" % _room_id)

func _on_p2p_connected() -> void:
	"""Called when WebSocket P2P connection is established"""
	print("[Arena] WebSocket P2P connection established!")
	_status_label.text = "Connected! Game starting..."
	if _ws_indicator:
		_ws_indicator.color = Color.GREEN

	# If host, initialize game state and (re)send snippet to guarantee sync
	if _is_host:
		_initialize_game_state()
		if _current_snippet == "":
			_start_round()
		else:
			_broadcast_snippet()

func _on_opponent_action(action: Dictionary) -> void:
	"""Called when opponent sends game action"""
	print("[Arena] Received opponent action: %s" % action)
	# Handle new protocol kinds first
	var kind := str(action.get("kind", ""))
	match kind:
		"snippet":
			_apply_new_snippet(str(action.get("snippet", "")), int(action.get("seq", 0)))
		"progress":
			_opponent_score = int(action.get("score", _opponent_score))
			_opponent_health = int(action.get("health", _opponent_health))
			_update_ui_display()
		"completed":
			# Host advances to next snippet when a client completes
			if _is_host:
				_start_round()
		_:
			# Back-compat for older messages
			if action.has("score"):
				_opponent_score = action.get("score", 0)
			if action.has("health"):
				_opponent_health = action.get("health", 100)
			_update_ui_display()

func _on_opponent_disconnected() -> void:
	"""Called when opponent disconnects"""
	print("[Arena] Opponent disconnected!")
	_status_label.text = "Opponent disconnected. Returning to room..."
	if _ws_indicator:
		_ws_indicator.color = Color(1, 0, 0)  # Red
	
	await get_tree().create_timer(3.0).timeout
	_leave_arena()

func _on_p2p_error(error: String) -> void:
	"""Called on WebSocket error"""
	print("[Arena] WebSocket error: %s" % error)
	_status_label.text = "Connection error: %s" % error
	if _ws_indicator:
		_ws_indicator.color = Color.RED
	
	# Fallback to RTDB polling after delay
	await get_tree().create_timer(2.0).timeout
	_fallback_to_rtdb()

func _on_display_timer_timeout() -> void:
	"""Update countdown display every 100ms"""
	var elapsed = Time.get_unix_time_from_system() - _game_start_time
	var remaining = max(0.0, GAME_DURATION - elapsed)
	
	var total_secs = int(remaining)
	var mins: int = floori(total_secs / 60.0)
	var secs: int = total_secs % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]
	
	# Check if game is over
	if remaining <= 0.0:
		_on_game_end()

func _update_ui_display() -> void:
	"""Update score and health display"""
	if _is_host:
		_p1_score.text = "P1: %d" % _local_score
		_p2_score.text = "P2: %d" % _opponent_score
		_p1_health.value = _local_health
		_p2_health.value = _opponent_health
	else:
		_p1_score.text = "P1: %d" % _opponent_score
		_p2_score.text = "P2: %d" % _local_score
		_p1_health.value = _opponent_health
		_p2_health.value = _local_health

func _initialize_game_state() -> void:
	"""Host sends initial game state"""
	_local_score = 0
	_local_health = 100
	_opponent_score = 0
	_opponent_health = 100
	
	_send_game_action({
		"score": _local_score,
		"health": _local_health
	})
	
	_status_label.text = "Match in progress..."
	_update_ui_display()

# =============================
# Typing battle mechanics
# =============================

func _start_round() -> void:
	"""Host chooses a snippet and broadcasts it; both reset progress."""
	if not _is_host:
		return
	if _snippets.is_empty():
		return
	var idx := randi() % _snippets.size()
	_current_snippet = str(_snippets[idx])
	_snippet_seq += 1
	_reset_progress_local()
	_broadcast_snippet()

func _broadcast_snippet() -> void:
	_status_label.text = "Type the snippet shown below."
	_show_snippet_in_status()
	_send_game_action({
		"kind": "snippet",
		"seq": _snippet_seq,
		"snippet": _current_snippet
	})

func _apply_new_snippet(snippet: String, seq: int) -> void:
	if snippet == "":
		return
	_current_snippet = snippet
	_snippet_seq = seq
	_reset_progress_local()
	_status_label.text = "New snippet received. Go!"
	_show_snippet_in_status()

func _reset_progress_local() -> void:
	_typed_text = ""
	_set_input_text("")
	_update_ui_display()

func _show_snippet_in_status() -> void:
	if _status_label:
		var preview := _current_snippet
		if preview.length() > 200:
			preview = preview.substr(0, 200) + "…"
		_status_label.text = "Type this:\n" + preview

func _on_input_text_changed(new_text: String = "") -> void:
	if _updating_input:
		return
	if _current_snippet == "":
		return
	var text := new_text
	if text == "":
		text = _get_input_text()

	# Compute how much of the prefix is correct
	var correct_len := _common_prefix_len(text, _current_snippet)

	# Penalize on mistakes (trim back to correct prefix)
	if correct_len < text.length():
		_local_health = max(0, _local_health - 1)
		text = _current_snippet.substr(0, correct_len)
		_set_input_text(text)

	# Reward correct new characters
	var delta: int = int(max(0, correct_len - _typed_text.length()))
	if delta > 0:
		_local_score += delta
		_typed_text = text
		_update_ui_display()

	# Broadcast progress (score/health)
	_send_game_action({
		"kind": "progress",
		"score": _local_score,
		"health": _local_health
	})

	# Completed the snippet?
	if _typed_text == _current_snippet:
		_local_score += 10  # completion bonus
		_update_ui_display()
		_send_game_action({
			"kind": "progress",
			"score": _local_score,
			"health": _local_health
		})
		_send_game_action({
			"kind": "completed",
			"seq": _snippet_seq
		})
		if _is_host:
			await get_tree().create_timer(0.5).timeout
			_start_round()

func _common_prefix_len(a: String, b: String) -> int:
	var n: int = int(min(a.length(), b.length()))
	var i := 0
	while i < n and a[i] == b[i]:
		i += 1
	return i

func _set_input_text(text: String) -> void:
	if not _type_area:
		return
	_updating_input = true
	if _type_area.has_method("set_text"):
		_type_area.call("set_text", text)
	else:
		_type_area.set("text", text)
	_updating_input = false

func _get_input_text() -> String:
	if not _type_area:
		return _typed_text
	if _type_area.has_method("get_text"):
		return str(_type_area.call("get_text"))
	var val = _type_area.get("text")
	return str(val) if typeof(val) == TYPE_STRING else _typed_text

func send_player_action(score: int, health: int) -> void:
	"""Called by game logic to send player action"""
	_local_score = score
	_local_health = health
	_send_game_action({
		"score": score,
		"health": health
	})

func _send_game_action(action: Dictionary) -> void:
	"""Send action to opponent via P2P"""
	if _p2p_client:
		_p2p_client.send_game_action(action)

func _on_game_end() -> void:
	"""Game timer reached zero"""
	_sync_timer.stop()
	_status_label.text = "Match Complete!"
	_timer_label.text = "00:00"
	
	# Disconnect WebSocket
	if _p2p_client:
		_p2p_client.disconnect_game()
	
	# Return to room after delay
	await get_tree().create_timer(3.0).timeout
	_leave_arena()

func _fallback_to_rtdb() -> void:
	"""Fallback to RTDB polling if WebSocket fails"""
	print("[Arena] Falling back to RTDB polling")
	_status_label.text = "Using RTDB fallback..."
	
	# Start RTDB polling every 1s
	var rtdb_timer = Timer.new()
	rtdb_timer.wait_time = 1.0
	rtdb_timer.timeout.connect(_poll_rtdb_state)
	add_child(rtdb_timer)
	rtdb_timer.start()

func _poll_rtdb_state() -> void:
	"""Poll game state from RTDB (fallback mode)"""
	if _room_id == "":
		return
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			if _ws_indicator:
				_ws_indicator.color = Color.YELLOW
			return
		
		if _ws_indicator:
			_ws_indicator.color = Color.GREEN
		
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("game_state"):
			return
		
		var game_state = data.get("game_state", {})
		if _is_host:
			_opponent_score = game_state.get("client_score", 0)
			_opponent_health = game_state.get("client_health", 100)
		else:
			_opponent_score = game_state.get("host_score", 0)
			_opponent_health = game_state.get("host_health", 100)
		
		_update_ui_display()
	)
	
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + "/game_state.json"
	http.request(url, [], HTTPClient.METHOD_GET)

func _leave_arena() -> void:
	"""Clean up and return to room"""
	if _p2p_client:
		_p2p_client.disconnect_game()
	
	var room_scene := load("res://scene/code_breaker_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
