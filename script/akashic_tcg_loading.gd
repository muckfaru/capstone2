extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")


# Minimal loading/sync screen for Akashic TCG (Milestone 1)
# Reuses the same relay handshake idea as Code Breaker: both players announce "loading" then "ready".

@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_progress: ProgressBar = $HostCard/HostProgressBar

@onready var _left_card_node: NinePatchRect = $HostCard

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_progress: ProgressBar = $ClientCard/ClientProgressBar

@onready var _right_card_node: NinePatchRect = $ClientCard

@onready var _status_message: Label = $StatusMessage

const COLOR_LOADING := Color(1, 0.36, 0.43, 1)
const COLOR_READY := Color(0, 0.82, 1, 1)

const LOADING_TIMEOUT := 60.0
const TRANSITION_DELAY := 2.0
const RETRY_INTERVAL := 2.0
const MAX_RETRIES := 5

var _room_id: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}
var _game_start_time: int = 0
var _lobby_server_url: String = ""

var _self_loaded := false
var _opponent_loaded := false
var _loading_progress := 0.0
var _countdown_started := false

var _progress_timer: Timer
var _timeout_timer: Timer
var _transition_timer: Timer
var _retry_timer: Timer
var _retry_count := 0

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_loading_init"):
		init = get_tree().get_meta("tgc_loading_init")
		get_tree().set_meta("tgc_loading_init", null)

	_room_id = str(init.get("room_id", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_game_start_time = int(init.get("game_start_time", 0))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, "loading")

	if _relay_client == null:
		push_error("[TGC Loading] Missing relay client")
		_go_to_room("Missing relay")
		return

	# Adopt relay client if it is attached to root
	if _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	_setup_ui()

	if not _relay_client.message_received.is_connected(_on_relay_message):
		_relay_client.message_received.connect(_on_relay_message)
	if _relay_client.has_signal("connected_to_relay"):
		if not _relay_client.connected_to_relay.is_connected(_on_relay_connected_for_loading):
			_relay_client.connected_to_relay.connect(_on_relay_connected_for_loading)
	if _relay_client.has_signal("disconnected_from_relay"):
		if not _relay_client.disconnected_from_relay.is_connected(_on_relay_disconnected_for_loading):
			_relay_client.disconnected_from_relay.connect(_on_relay_disconnected_for_loading)

	_setup_timers()
	_simulate_loading()

	await get_tree().create_timer(1.5).timeout
	_send_loading_status("loading")
	_retry_timer.start()

func _setup_ui() -> void:
	# Left card = YOU, Right card = OPPONENT
	var left_bg := ""
	var right_bg := ""
	if _is_host:
		_host_username.text = str(_host_data.get("username", "Host"))
		_client_username.text = str(_client_data.get("username", "Client"))
		left_bg = str(_host_data.get("card_bg", ""))
		right_bg = str(_client_data.get("card_bg", ""))
	else:
		_host_username.text = str(_client_data.get("username", "Client"))
		_client_username.text = str(_host_data.get("username", "Host"))
		left_bg = str(_client_data.get("card_bg", ""))
		right_bg = str(_host_data.get("card_bg", ""))

	_host_status.text = "⏳ Loading..."
	_client_status.text = "⏳ Loading..."
	_host_status.add_theme_color_override("font_color", COLOR_LOADING)
	_client_status.add_theme_color_override("font_color", COLOR_LOADING)
	_host_progress.value = 0.0
	_client_progress.value = 0.0

	_status_message.visible = true
	_status_message.text = "Syncing players..."

	# Fallback: if lobby snapshot didn't have cosmetics yet, at least show local equipped background.
	if Auth and left_bg.strip_edges() == "" and Auth.current_card_bg_path.strip_edges() != "":
		left_bg = Auth.current_card_bg_path
	# Fallback: if opponent bg missing, try relay-learned cache.
	if Auth and right_bg.strip_edges() == "":
		var opp_pid := ""
		if _is_host:
			opp_pid = str(_client_data.get("player_id", ""))
		else:
			opp_pid = str(_host_data.get("player_id", ""))
		right_bg = Auth.get_remote_card_bg(opp_pid)

	CardCosmetics.apply_card_background(_left_card_node, left_bg)
	CardCosmetics.apply_card_background(_right_card_node, right_bg)

func _setup_timers() -> void:
	_progress_timer = Timer.new()
	_progress_timer.wait_time = 0.05
	_progress_timer.one_shot = false
	_progress_timer.autostart = false
	_progress_timer.timeout.connect(_on_progress_tick)
	add_child(_progress_timer)

	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = LOADING_TIMEOUT
	_timeout_timer.one_shot = true
	_timeout_timer.autostart = true
	_timeout_timer.timeout.connect(_on_loading_timeout)
	add_child(_timeout_timer)

	_transition_timer = Timer.new()
	_transition_timer.wait_time = TRANSITION_DELAY
	_transition_timer.one_shot = true
	_transition_timer.autostart = false
	_transition_timer.timeout.connect(_transition_to_arena)
	add_child(_transition_timer)

	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_INTERVAL
	_retry_timer.one_shot = false
	_retry_timer.autostart = false
	_retry_timer.timeout.connect(_on_retry_timeout)
	add_child(_retry_timer)

func _simulate_loading() -> void:
	_loading_progress = 0.0
	_progress_timer.start()

	await get_tree().create_timer(0.5).timeout
	_loading_progress = 30.0
	await get_tree().create_timer(0.5).timeout
	_loading_progress = 60.0
	await get_tree().create_timer(0.5).timeout
	_loading_progress = 100.0

	_self_loaded = true
	_send_loading_status("ready")
	_send_status_request()
	_update_self_status()
	_check_both_ready()

func _on_progress_tick() -> void:
	var target := _loading_progress if not _self_loaded else 100.0
	var my_bar := _host_progress if _is_host else _client_progress
	if my_bar.value < target:
		my_bar.value = min(my_bar.value + 2.0, target)

func _send_loading_status(status: String) -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "loading_status",
		"player_id": _player_id,
		"status": status,
		"timestamp": Time.get_ticks_msec()
	})

func _send_status_request() -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "loading_status_request",
		"player_id": _player_id,
		"timestamp": Time.get_ticks_msec()
	})

func _on_relay_connected_for_loading() -> void:
	_send_loading_status("ready" if _self_loaded else "loading")
	_send_status_request()

func _on_relay_disconnected_for_loading() -> void:
	_go_to_reconnect("Relay disconnected", "loading")

func _go_to_reconnect(reason: String, phase: String) -> void:
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, phase)
	# Best-effort cleanup
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	get_tree().set_meta("tgc_reconnect_init", {
		"room_id": _room_id,
		"lobby_server_url": _lobby_server_url,
		"player_id": _player_id,
		"username": username,
		"is_host": _is_host,
		"relay_client": null,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"reason": reason,
		"phase": phase,
	})
	var reconnect_scene := load("res://scene/akashic_tcg_reconnect.tscn")
	if reconnect_scene:
		get_tree().change_scene_to_packed(reconnect_scene)
	else:
		push_error("[TGC Loading] akashic_tcg_reconnect.tscn not found")

func _on_relay_message(data: Dictionary) -> void:
	# Ignore self echo
	if str(data.get("player_id", "")) == _player_id:
		return
	var t := str(data.get("type", ""))
	match t:
		"loading_status":
			var status := str(data.get("status", "loading"))
			_opponent_loaded = (status == "ready")
			_update_opponent_status(status)
			_check_both_ready()
		"loading_status_request":
			_send_loading_status("ready" if _self_loaded else "loading")
		_:
			pass

func _update_self_status() -> void:
	var my_status := _host_status if _is_host else _client_status
	my_status.text = "✅ Ready"
	my_status.add_theme_color_override("font_color", COLOR_READY)
	_status_message.text = "Waiting for opponent..." if not _opponent_loaded else "Both ready!"

func _update_opponent_status(status: String) -> void:
	var opp_status := _client_status if _is_host else _host_status
	if status == "ready":
		opp_status.text = "✅ Ready"
		opp_status.add_theme_color_override("font_color", COLOR_READY)
		_status_message.text = "Both ready!"
	else:
		opp_status.text = "⏳ Loading..."
		opp_status.add_theme_color_override("font_color", COLOR_LOADING)
		_status_message.text = "Waiting for opponent..."

func _check_both_ready() -> void:
	if _countdown_started:
		return
	if _self_loaded and _opponent_loaded:
		_countdown_started = true
		_retry_timer.stop()
		_status_message.text = "Starting match..."
		_transition_timer.start()

func _on_retry_timeout() -> void:
	if _self_loaded and _opponent_loaded:
		_retry_timer.stop()
		return
	_retry_count += 1
	_send_loading_status("ready" if _self_loaded else "loading")
	_send_status_request()
	if _retry_count >= MAX_RETRIES:
		_retry_timer.stop()

func _on_loading_timeout() -> void:
	push_warning("[TGC Loading] Timeout")
	_go_to_reconnect("Timeout", "loading")

func _transition_to_arena() -> void:
	# Preserve relay across transition
	if _relay_client and _relay_client.get_parent() != get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var init := {
		"room_id": _room_id,
		"is_host": _is_host,
		"player_id": _player_id,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": _game_start_time,
		"lobby_server_url": _lobby_server_url,
		"relay_client": _relay_client
	}
	get_tree().set_meta("tgc_arena_init", init)

	var arena_scene := load("res://scene/akashic_tcg_arena.tscn")
	if arena_scene:
		get_tree().change_scene_to_packed(arena_scene)
	else:
		push_error("[TGC Loading] akashic_tcg_arena.tscn not found")
		_go_to_room("Missing arena")

func _go_to_room(reason: String) -> void:
	print("[TGC Loading] Returning to room: ", reason)
	# Detach relay so room can adopt it if needed
	if _relay_client and _relay_client.get_parent() != get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var init := {
		"room_id": _room_id,
		"host_name": str(_host_data.get("username", "Host")),
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url
	}
	get_tree().set_meta("tgc_room_init", init)
	var room_scene := load("res://scene/akashic_tcg_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
	else:
		push_error("[TGC Loading] akashic_tcg_room.tscn not found")
