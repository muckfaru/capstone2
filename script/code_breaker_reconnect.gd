extends Control

@onready var _status_label: Label = $StatusLabel
@onready var _retry_button: Button = $RetryButton
@onready var _back_button: Button = $BackButton

const MAX_ATTEMPTS := 10
const ATTEMPT_DELAY := 2.0

var _room_id: String = ""
var _lobby_server_url: String = ""
var _player_id: String = ""
var _username: String = ""
var _is_host: bool = false
var _relay_client: Node = null
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _game_start_time: int = 0
var _reason: String = ""

var _cancelled := false
var _running := false

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("code_breaker_reconnect_init"):
		init = get_tree().get_meta("code_breaker_reconnect_init")
		get_tree().set_meta("code_breaker_reconnect_init", null)

	_room_id = str(init.get("room_id", ""))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_player_id = str(init.get("player_id", ""))
	_username = str(init.get("username", ""))
	_is_host = bool(init.get("is_host", false))
	_relay_client = init.get("relay_client", null)
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_game_start_time = int(init.get("game_start_time", 0))
	_reason = str(init.get("reason", ""))

	if _username == "":
		_username = Auth.current_username if Auth else "Player"
	if _player_id == "":
		_player_id = Auth.current_local_id if Auth else "unknown"

	_retry_button.pressed.connect(_on_retry_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_retry_button.disabled = true
	_back_button.disabled = true

	if _reason != "":
		_status_label.text = "Reconnecting… (" + _reason + ")"
	else:
		_status_label.text = "Reconnecting…"

	# Adopt relay_client if it's attached to root
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	_start_reconnect_loop()

func _on_retry_pressed() -> void:
	_cancelled = false
	_start_reconnect_loop()

func _on_back_pressed() -> void:
	_cancelled = true
	_go_to_room()

func _start_reconnect_loop() -> void:
	if _running:
		return
	_running = true
	_retry_button.disabled = true
	_back_button.disabled = true
	
	await _reconnect_flow()
	_running = false

func _reconnect_flow() -> void:
	for attempt in range(MAX_ATTEMPTS):
		if _cancelled:
			return
		_status_label.text = "Reconnecting… attempt %d/%d" % [attempt + 1, MAX_ATTEMPTS]
		
		# Ensure we have a relay client, and try to connect if needed.
		_ensure_relay_client()
		await _ensure_relay_connected()
		
		var room_data = await _fetch_room_from_lobby()
		if room_data == null:
			await get_tree().create_timer(ATTEMPT_DELAY).timeout
			continue
		
		if room_data.has("error"):
			_status_label.text = "Room not found (closed). Returning…"
			await get_tree().create_timer(1.0).timeout
			_go_to_room()
			return
		
		var status := str(room_data.get("status", "waiting"))
		if status == "waiting":
			_status_label.text = "Room is waiting. You can return to room."
			_retry_button.disabled = false
			_back_button.disabled = false
			return
		
		if status == "in_game":
			_status_label.text = "Match in progress. Rejoining…"
			# Ask the other client (even if currently in Arena) to return to Loading
			# so both players re-enter Arena together after a reconnect.
			if _relay_client and _relay_client.has_method("is_relay_connected") and _relay_client.is_relay_connected():
				_relay_client.send_message({
					"type": "force_loading_sync",
					"player_id": _player_id,
					"timestamp": Time.get_ticks_msec()
				})
			_go_to_loading(room_data)
			return
		
		if status == "finished":
			_status_label.text = "Match ended. Showing results…"
			await get_tree().create_timer(0.5).timeout
			_go_to_postgame(room_data)
			return
		
		# Fallback for unknown/finished states
		_status_label.text = "Room status: %s. Returning…" % status
		await get_tree().create_timer(1.0).timeout
		_go_to_room()
		return
	
	_status_label.text = "Reconnect failed. You can retry or go back."
	_retry_button.disabled = false
	_back_button.disabled = false

func _ensure_relay_client() -> void:
	if _relay_client != null:
		return
	
	var RelayClientScript = load("res://script/WebSocketRelayClient.gd")
	if not RelayClientScript:
		push_error("[Reconnect] WebSocketRelayClient.gd not found")
		return
	
	_relay_client = RelayClientScript.new()
	add_child(_relay_client)

func _ensure_relay_connected() -> void:
	if _relay_client == null:
		return
	
	if _relay_client.has_method("is_relay_connected") and _relay_client.is_relay_connected():
		return
	
	if not _relay_client.has_signal("connected_to_relay"):
		return
	
	# Kick connect attempt (safe even if it was previously connected)
	if _relay_client.has_method("connect_to_relay") and _lobby_server_url != "" and _room_id != "":
		_relay_client.connect_to_relay(_lobby_server_url, _room_id, _player_id, _username)
	
	# Wait briefly for connection to establish
	var wait_time := 0.0
	while wait_time < 6.0:
		if _relay_client.has_method("is_relay_connected") and _relay_client.is_relay_connected():
			return
		await get_tree().create_timer(0.5).timeout
		wait_time += 0.5

func _fetch_room_from_lobby() -> Variant:
	if _lobby_server_url == "" or _room_id == "":
		return null
	
	var http := HTTPRequest.new()
	add_child(http)

	var url := _lobby_server_url + "/api/rooms/" + _room_id
	var err := http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return null

	var response: Array = await http.request_completed
	http.queue_free()

	if response.size() < 4:
		return null

	var code: int = int(response[1])
	var body: PackedByteArray = response[3]
	if code != 200:
		return null
	
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

func _go_to_loading(room_data: Dictionary) -> void:
	# Preserve full host/client dictionaries if lobby gives them
	var host_dict: Dictionary = room_data.get("host", _host_data)
	var client_dict: Dictionary = room_data.get("client", _client_data)
	var start_time := int(room_data.get("game_start_time", _game_start_time))
	
	# Reparent relay_client to root so it survives scene change
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var loading_init := {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": host_dict,
		"client_data": client_dict if client_dict != null else {},
		"game_start_time": start_time,
		"lobby_server_url": _lobby_server_url
	}
	get_tree().set_meta("code_breaker_loading_init", loading_init)

	var loading_scene := load("res://scene/code_breaker_loading.tscn")
	if loading_scene:
		get_tree().change_scene_to_packed(loading_scene)
	else:
		push_error("[Reconnect] Failed to load loading scene")
		_go_to_room()

func _go_to_room() -> void:
	var host_name := _username
	if typeof(_host_data) == TYPE_DICTIONARY and str(_host_data.get("username", "")) != "":
		host_name = str(_host_data.get("username"))
	
	var init := {
		"room_id": _room_id,
		"host_name": host_name,
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url
	}
	get_tree().set_meta("code_breaker_room_init", init)
	
	var room_scene := load("res://scene/code_breaker_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
	else:
		push_error("[Reconnect] Failed to load room scene")

func _go_to_postgame(room_data: Dictionary) -> void:
	# Try to use latest host/client dictionaries if lobby gives them
	var host_dict: Dictionary = room_data.get("host", _host_data)
	var client_val = room_data.get("client", _client_data)
	var client_dict: Dictionary = client_val if typeof(client_val) == TYPE_DICTIONARY else {}

	# Preserve relay client if present
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var postgame_init := {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": host_dict,
		"client_data": client_dict,
		"lobby_server_url": _lobby_server_url,
		"winner_id": "", # unknown from reconnect path
		"host_score": 0,
		"client_score": 0,
		"host_health": 0,
		"client_health": 0,
		"game_duration": 0.0,
		"host_powerups_used": 0,
		"client_powerups_used": 0,
		"result_unknown": true
	}
	get_tree().set_meta("code_breaker_postgame_init", postgame_init)

	var postgame_scene := load("res://scene/code_breaker_postgame.tscn")
	if postgame_scene:
		get_tree().change_scene_to_packed(postgame_scene)
	else:
		push_error("[Reconnect] Failed to load postgame scene")
		_go_to_room()
