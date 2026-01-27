extends Control

# Defuse the Trojan - Loading screen (2-3 players)
# Goal: everyone transitions to arena at the same scheduled time.

# UI refs
@onready var _title_label: Label = $TitleLabel

@onready var _host_card: NinePatchRect = $HostCard
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_progress: ProgressBar = $HostCard/HostProgressBar

@onready var _client_card: NinePatchRect = $ClientCard
@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_progress: ProgressBar = $ClientCard/ClientProgressBar

@onready var _client2_card: NinePatchRect = $Client2Card
@onready var _client2_username: Label = $Client2Card/Client2Username
@onready var _client2_status: Label = $Client2Card/Client2Status
@onready var _client2_progress: ProgressBar = $Client2Card/Client2ProgressBar

@onready var _status_message: Label = $StatusMessage

# Colors (match Code Breaker / Akashic)
const COLOR_LOADING := Color(1, 0.36, 0.43, 1) # pink-red
const COLOR_READY := Color(0, 0.82, 1, 1) # cyan

const LOADING_TIMEOUT := 60.0
const DEFAULT_LOADING_DURATION_MS := 8000

var _room_id: String = ""
var _lobby_server_url: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false

var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _client2_data: Dictionary = {}

var _game_start_time_ms: int = 0
var _loading_duration_ms: int = DEFAULT_LOADING_DURATION_MS

var _start_time_broadcasted: bool = false

var _tick_timer: Timer
var _timeout_timer: Timer
var _transitioned: bool = false

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("defuse_trojan_loading_init"):
		var meta_value = get_tree().get_meta("defuse_trojan_loading_init")
		if meta_value != null and meta_value is Dictionary:
			init = meta_value
		get_tree().set_meta("defuse_trojan_loading_init", null)

	_room_id = str(init.get("room_id", ""))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	
	# Safely get Dictionary values (can be null even with default)
	var host_val = init.get("host_data", {})
	_host_data = host_val if host_val is Dictionary else {}
	var client_val = init.get("client_data", {})
	_client_data = client_val if client_val is Dictionary else {}
	var client2_val = init.get("client2_data", {})
	_client2_data = client2_val if client2_val is Dictionary else {}
	
	_game_start_time_ms = int(init.get("game_start_time_ms", 0))
	_loading_duration_ms = int(init.get("loading_duration_ms", DEFAULT_LOADING_DURATION_MS))

	_title_label.text = "DEFUSE THE TROJAN"
	_setup_ui_cards()

	# Adopt relay client if it is attached to root (best-effort; arena may need it later)
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	_setup_relay_handlers()

	# If we don't have a scheduled start time yet, try fetching from server once.
	# If server doesn't support it (e.g., older Render deployment), we will fall back to relay sync.
	if _game_start_time_ms <= 0 and _room_id.strip_edges() != "" and _lobby_server_url.strip_edges() != "":
		await _fetch_game_start_time_once()

	# Relay fallback: if still missing, host will pick a start time and broadcast it.
	await get_tree().create_timer(0.5).timeout
	_ensure_start_time_sync()

	_setup_timers()
	_tick_timer.start()

func _setup_ui_cards() -> void:
	# Names
	_host_username.text = str(_host_data.get("username", "Host"))
	_client_username.text = str(_client_data.get("username", "Client"))
	_client2_username.text = str(_client2_data.get("username", "Client 3"))

	# Cosmetics
	CardCosmetics.apply_card_background(_host_card, _resolve_card_bg(_host_data))
	CardCosmetics.apply_card_background(_client_card, _resolve_card_bg(_client_data))
	CardCosmetics.apply_card_background(_client2_card, _resolve_card_bg(_client2_data))

	# Visibility + layout
	var has_client := _has_player(_client_data)
	var has_client2 := _has_player(_client2_data)

	_client_card.visible = has_client
	_client2_card.visible = has_client2

	# If only 2 players, use CodeBreaker-like left vs right spacing.
	# Default layout in scene is 3-up (host left, client middle, client2 right).
	if has_client and not has_client2:
		_place_card_right(_client_card)
		_status_message.visible = true
		_status_message.text = "Syncing players..."
	elif has_client and has_client2:
		_place_card_middle(_client_card)
		_place_card_right(_client2_card)
		_status_message.visible = true
		_status_message.text = "Syncing team..."
	else:
		_status_message.visible = true
		_status_message.text = "Loading..."

	_reset_card_statuses()

func _reset_card_statuses() -> void:
	_set_loading(_host_status, _host_progress)
	_set_loading(_client_status, _client_progress)
	_set_loading(_client2_status, _client2_progress)

func _set_loading(label: Label, bar: ProgressBar) -> void:
	label.visible = false
	label.text = "⏳ Loading..."
	label.add_theme_color_override("font_color", COLOR_LOADING)
	bar.value = 0.0

func _set_ready(label: Label, bar: ProgressBar) -> void:
	label.visible = false
	label.text = "✅ Ready!"
	label.add_theme_color_override("font_color", COLOR_READY)
	bar.value = 100.0

func _setup_timers() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 0.05
	_tick_timer.one_shot = false
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = LOADING_TIMEOUT
	_timeout_timer.one_shot = true
	_timeout_timer.autostart = true
	_timeout_timer.timeout.connect(_on_timeout)
	add_child(_timeout_timer)

func _on_tick() -> void:
	if _transitioned:
		return

	if _game_start_time_ms <= 0:
		# Keep trying (lightweight) to sync start time, without spamming.
		_ensure_start_time_sync()
		# We still don't have schedule; keep animating gently.
		var v := fmod(float(Time.get_ticks_msec()) / 20.0, 100.0)
		_host_progress.value = v
		if _client_card.visible:
			_client_progress.value = v
		if _client2_card.visible:
			_client2_progress.value = v
		_status_message.text = "Waiting for start sync..."
		return

	var now_ms := int(Time.get_unix_time_from_system() * 1000)
	var remaining_ms := _game_start_time_ms - now_ms
	var progress := 1.0 - (float(remaining_ms) / float(max(1, _loading_duration_ms)))
	progress = clamp(progress, 0.0, 1.0)
	var percent := progress * 100.0

	_host_progress.value = percent
	if _client_card.visible:
		_client_progress.value = percent
	if _client2_card.visible:
		_client2_progress.value = percent

	if remaining_ms > 0:
		_status_message.text = "Starting in %0.1fs..." % (float(remaining_ms) / 1000.0)
	else:
		_status_message.text = "Starting..."
		_transition_to_arena()


func _setup_relay_handlers() -> void:
	if _relay_client == null:
		return
	if _relay_client.has_signal("message_received"):
		if not _relay_client.message_received.is_connected(_on_relay_message):
			_relay_client.message_received.connect(_on_relay_message)
	if _relay_client.has_signal("connected_to_relay"):
		if not _relay_client.connected_to_relay.is_connected(_on_relay_connected):
			_relay_client.connected_to_relay.connect(_on_relay_connected)


func _on_relay_connected() -> void:
	# (Re)announce and request start time if needed.
	_ensure_start_time_sync(true)


func _on_relay_message(data: Dictionary) -> void:
	var t := str(data.get("type", ""))
	match t:
		"dt_game_start_time":
			var start_ms := int(data.get("game_start_time_ms", 0))
			var dur_ms := int(data.get("loading_duration_ms", _loading_duration_ms))
			if start_ms > 0:
				_game_start_time_ms = start_ms
				_loading_duration_ms = max(1000, dur_ms)
				_status_message.text = "Starting soon..."
		"dt_game_start_time_request":
			if _is_host and _game_start_time_ms > 0 and _relay_client:
				_relay_client.send_message({
					"type": "dt_game_start_time",
					"game_start_time_ms": _game_start_time_ms,
					"loading_duration_ms": _loading_duration_ms
				})
		"dt_loading_hello":
			# Late joiner reached loading; if we're host and already have a start time, send it.
			if _is_host and _game_start_time_ms > 0 and _relay_client:
				_relay_client.send_message({
					"type": "dt_game_start_time",
					"game_start_time_ms": _game_start_time_ms,
					"loading_duration_ms": _loading_duration_ms
				})
		_:
			pass


func _ensure_start_time_sync(force: bool = false) -> void:
	# Host chooses a start time if none exists, then broadcasts once.
	if _relay_client == null:
		return
	if _game_start_time_ms <= 0:
		if _is_host:
			var now_ms := int(Time.get_unix_time_from_system() * 1000)
			_game_start_time_ms = now_ms + _loading_duration_ms
			_start_time_broadcasted = false
		else:
			# Ask host for a start time.
			if force or not _start_time_broadcasted:
				_relay_client.send_message({"type": "dt_game_start_time_request"})
				_start_time_broadcasted = true
				_relay_client.send_message({"type": "dt_loading_hello"})
			return

	# Broadcast start time once (host), and also on force (reconnect).
	if _is_host and (_start_time_broadcasted == false or force):
		_relay_client.send_message({
			"type": "dt_game_start_time",
			"game_start_time_ms": _game_start_time_ms,
			"loading_duration_ms": _loading_duration_ms
		})
		_relay_client.send_message({"type": "dt_loading_hello"})
		_start_time_broadcasted = true

func _on_timeout() -> void:
	if _transitioned:
		return
	_status_message.text = "Loading timeout. Returning..."
	await get_tree().create_timer(1.0).timeout
	_return_to_room()

func _transition_to_arena() -> void:
	_transitioned = true
	if _tick_timer:
		_tick_timer.stop()
	if _timeout_timer:
		_timeout_timer.stop()

	# Reparent relay_client to root so it survives scene changes.
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	get_tree().set_meta("defuse_trojan_arena_init", {
		"mode": "multiplayer",
		"room_id": _room_id,
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"room_data": {
			"room_id": _room_id,
			"host": _host_data,
			"client": _client_data,
			"client2": _client2_data,
			"status": "in_game",
			"game_start_time_ms": _game_start_time_ms
		}
	})

	get_tree().change_scene_to_file("res://scene/defuse_trojan_arena.tscn")

func _return_to_room() -> void:
	# Preserve relay client if present.
	if _relay_client and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	get_tree().set_meta("defuse_trojan_room_init", {
		"room_id": _room_id,
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url,
		"relay_client": _relay_client,
		"from_loading": true
	})
	get_tree().change_scene_to_file("res://scene/defuse_trojan_room.tscn")

func _has_player(slot: Dictionary) -> bool:
	return str(slot.get("player_id", "")).strip_edges() != ""

func _resolve_card_bg(slot: Dictionary) -> String:
	var bg := str(slot.get("card_bg", ""))
	if Auth == null:
		return bg
	if bg.strip_edges() != "":
		return bg
	var pid := str(slot.get("player_id", ""))
	if pid.strip_edges() == "":
		return ""
	if pid == Auth.current_local_id and Auth.current_card_bg_path.strip_edges() != "":
		return Auth.current_card_bg_path
	return Auth.get_remote_card_bg(pid)

func _place_card_right(card: Control) -> void:
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -360.0
	card.offset_right = -100.0
	card.offset_top = -150.0
	card.offset_bottom = 250.0

func _place_card_middle(card: Control) -> void:
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -130.0
	card.offset_right = 130.0
	card.offset_top = -150.0
	card.offset_bottom = 250.0

func _place_card_right_default(card: Control) -> void:
	_place_card_right(card)

func _fetch_game_start_time_once() -> void:
	var url := _lobby_server_url + "/api/rooms/" + _room_id
	var http := HTTPRequest.new()
	add_child(http)

	var err := http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()
	if typeof(result) != TYPE_ARRAY or result.size() < 4:
		return
	var code := int(result[1])
	var body: PackedByteArray = result[3]
	if code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_game_start_time_ms = int(data.get("game_start_time_ms", 0))
