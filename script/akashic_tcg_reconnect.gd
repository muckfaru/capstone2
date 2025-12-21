extends Control

const _SessionStore = preload("res://script/AkashicTCGSessionStore.gd")

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
var _last_phase: String = ""

var _cancelled := false
var _running := false

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_reconnect_init"):
		init = get_tree().get_meta("tgc_reconnect_init")
		get_tree().set_meta("tgc_reconnect_init", null)

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
	_last_phase = str(init.get("phase", ""))

	if _username == "":
		_username = Auth.current_username if Auth else "Player"
	if _player_id == "":
		_player_id = Auth.current_local_id if Auth else "unknown"

	# Persist so relaunch can resume the right stage (keep last known phase)
	var persist_phase := _last_phase if _last_phase.strip_edges() != "" else "reconnect"
	_SessionStore.save_session(_room_id, _lobby_server_url, _player_id, _username, persist_phase)

	_retry_button.pressed.connect(_on_retry_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_retry_button.disabled = true
	_back_button.disabled = true

	_status_label.text = ("Reconnecting… (%s)" % _reason) if _reason != "" else "Reconnecting…"

	# Adopt relay_client if it was preserved
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	_start_reconnect_loop()

func _on_retry_pressed() -> void:
	_cancelled = false
	_start_reconnect_loop()

func _on_back_pressed() -> void:
	_cancelled = true
	_go_to_landing()

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

		_ensure_relay_client()
		await _ensure_relay_connected()

		var room_data: Variant = await _fetch_room_from_lobby()
		if room_data == null:
			await get_tree().create_timer(ATTEMPT_DELAY).timeout
			continue

		if room_data.has("error"):
			_status_label.text = "Room not found (closed). Returning…"
			await get_tree().create_timer(1.0).timeout
			_go_to_landing()
			return

		var status := str(room_data.get("status", "waiting"))
		var host_dict = room_data.get("host", null)
		if typeof(host_dict) == TYPE_DICTIONARY:
			_is_host = (str(host_dict.get("player_id", "")) == _player_id)
		_host_data = host_dict if typeof(host_dict) == TYPE_DICTIONARY else {}
		var client_val = room_data.get("client", null)
		_client_data = client_val if typeof(client_val) == TYPE_DICTIONARY else {}
		_game_start_time = int(room_data.get("game_start_time", _game_start_time))

		if status == "waiting":
			_status_label.text = "Room is waiting. Returning…"
			await get_tree().create_timer(0.5).timeout
			_go_to_room()
			return

		if status == "in_game":
			_status_label.text = "Match in progress. Rejoining…"
			# Decide target: if we were in loading previously, go loading; otherwise go arena.
			var session := _SessionStore.load_session()
			var phase := str(session.get("phase", ""))
			if phase == "" or phase == "reconnect":
				phase = _last_phase
			if phase == "loading":
				_go_to_loading()
			else:
				_go_to_arena()
			return

		if status == "finished":
			_status_label.text = "Match ended. Showing results…"
			await get_tree().create_timer(0.5).timeout
			_go_to_postgame("", "resume_finished")
			return

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
		push_error("[TGC Reconnect] WebSocketRelayClient.gd not found")
		return
	_relay_client = RelayClientScript.new()
	add_child(_relay_client)

func _ensure_relay_connected() -> void:
	if _relay_client == null:
		return
	if _relay_client.has_method("is_relay_connected") and _relay_client.is_relay_connected():
		return
	if _lobby_server_url == "" or _room_id == "":
		return
	if _relay_client.has_method("connect_to_relay"):
		_relay_client.connect_to_relay(_lobby_server_url, _room_id, _player_id, _username)
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
		if code == 404:
			return {"error": "not_found"}
		return null
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

func _go_to_loading() -> void:
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)
	get_tree().set_meta("tgc_loading_init", {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"lobby_server_url": _lobby_server_url,
		"resume": true,
	})
	var loading_scene := load("res://scene/akashic_tcg_loading.tscn")
	if loading_scene:
		get_tree().change_scene_to_packed(loading_scene)
	else:
		push_error("[TGC Reconnect] Failed to load loading scene")
		_go_to_room()

func _go_to_arena() -> void:
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)
	get_tree().set_meta("tgc_arena_init", {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"lobby_server_url": _lobby_server_url,
		"resume": true,
	})
	var arena_scene := load("res://scene/akashic_tcg_arena.tscn")
	if arena_scene:
		get_tree().change_scene_to_packed(arena_scene)
	else:
		push_error("[TGC Reconnect] Failed to load arena scene")
		_go_to_room()

func _go_to_room() -> void:
	var host_name := _username
	if typeof(_host_data) == TYPE_DICTIONARY and str(_host_data.get("username", "")) != "":
		host_name = str(_host_data.get("username"))
	get_tree().set_meta("tgc_room_init", {
		"room_id": _room_id,
		"host_name": host_name,
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url,
	})
	var room_scene := load("res://scene/akashic_tcg_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
	else:
		push_error("[TGC Reconnect] Failed to load room scene")

func _go_to_postgame(winner_id: String, reason: String) -> void:
	get_tree().set_meta("tgc_postgame_init", {
		"room_id": _room_id,
		"player_id": _player_id,
		"winner_id": winner_id,
		"reason": reason,
		"lobby_server_url": _lobby_server_url,
		"host_data": _host_data,
		"client_data": _client_data,
		"result_unknown": true,
	})
	var post_scene := load("res://scene/akashic_tcg_postgame.tscn")
	if post_scene:
		get_tree().change_scene_to_packed(post_scene)
	else:
		push_error("[TGC Reconnect] Failed to load postgame")

func _go_to_landing() -> void:
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)
