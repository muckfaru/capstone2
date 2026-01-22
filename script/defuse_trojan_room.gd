extends Control

const POLL_INTERVAL := 2.0
const LOADING_DURATION_MS := 8000

# Theme colors (Cyber Neon) - match Code Breaker / Akashic
const COLOR_ACCENT := Color(0, 0.819608, 1, 1) # cyan
const COLOR_DANGER := Color(1, 0.356863, 0.431373, 1) # pink-red
const COLOR_MUTED := Color(0.560784, 0.639216, 0.678431, 1) # muted gray-blue

@onready var _room_id_label: Label = $RoomHeader/RoomIDLabel
@onready var _room_state_label: Label = $RoomHeader/RoomStateLabel

@onready var _host_username: Label = $CardsContainer/HostCard/Username
@onready var _host_level: Label = $CardsContainer/HostCard/Level
@onready var _host_status: Label = $CardsContainer/HostCard/StatusLabel
@onready var _host_card_node: NinePatchRect = $CardsContainer/HostCard

@onready var _client_username: Label = $CardsContainer/ClientCard/Username
@onready var _client_level: Label = $CardsContainer/ClientCard/Level
@onready var _client_status: Label = $CardsContainer/ClientCard/StatusLabel
@onready var _client_card_node: NinePatchRect = $CardsContainer/ClientCard

@onready var _client2_username: Label = $CardsContainer/Client2Card/Username
@onready var _client2_level: Label = $CardsContainer/Client2Card/Level
@onready var _client2_status: Label = $CardsContainer/Client2Card/StatusLabel
@onready var _client2_card_node: NinePatchRect = $CardsContainer/Client2Card

@onready var _message_label: Label = $MessageLabel
@onready var _start_btn: Button = $ButtonPanel/StartButton
@onready var _leave_btn: Button = $ButtonPanel/LeaveButton

var _room_id: String = ""
var _is_host: bool = false
var _lobby_server_url: String = ""
var _player_id: String = ""

var _poll_timer: Timer
var _transitioning: bool = false

var _latest_room_data: Dictionary = {}

# Relay connection (for cosmetics sync like CodeBreaker/Akashic)
var _relay_client: Node = null
var _relay_connected: bool = false

var _last_client1_present: bool = false
var _last_client2_present: bool = false

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("defuse_trojan_room_init"):
		init = get_tree().get_meta("defuse_trojan_room_init")
		get_tree().set_meta("defuse_trojan_room_init", null)

	_room_id = str(init.get("room_id", ""))
	_is_host = bool(init.get("is_host", false))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_player_id = Auth.current_local_id if Auth else "unknown"
	var host_name: String = str(init.get("host_name", "Host"))

	_room_id_label.text = "ROOM: " + (_room_id if _room_id != "" else "(local)")
	_room_state_label.text = "WAITING"

	_host_username.text = host_name
	_host_level.text = ""
	_host_status.text = "HOST"
	_host_status.add_theme_color_override("font_color", COLOR_ACCENT)

	_client_username.text = "."
	_client_level.text = "."
	_client_status.text = "Searching.."
	_client_status.add_theme_color_override("font_color", COLOR_MUTED)

	_client2_username.text = "."
	_client2_level.text = "."
	_client2_status.text = "Searching.."
	_client2_status.add_theme_color_override("font_color", COLOR_MUTED)

	_message_label.text = "Waiting for players..."

	_start_btn.pressed.connect(_on_start_pressed)
	_leave_btn.pressed.connect(_on_leave_pressed)

	_configure_buttons()

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_fetch_room)
	add_child(_poll_timer)

	_fetch_room()
	_setup_relay_connection()

	# Initialize embedded room chat with this room context (best-effort; shares same RoomChat UI)
	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize("https://capstone-823dc-default-rtdb.firebaseio.com", "/defuse_trojan_rooms", _room_id)


func _configure_buttons() -> void:
	if _is_host:
		_start_btn.toggle_mode = false
		_start_btn.text = "START MATCH"
		_start_btn.disabled = true
	else:
		_start_btn.toggle_mode = true
		_start_btn.disabled = false
		# Button shows the ACTION (opposite of current state)
		_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
		if not _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.connect(_on_ready_toggled)


func _on_ready_toggled(pressed: bool) -> void:
	# Button shows the ACTION (opposite of current state)
	_start_btn.text = ("NOT READY" if pressed else "READY")

	# Best-effort: update my card status immediately, polling will confirm
	var my_slot := _get_my_slot()
	if my_slot == "client":
		_client_status.text = ("READY" if pressed else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))
	elif my_slot == "client2":
		_client2_status.text = ("READY" if pressed else "NOT READY")
		_client2_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))

	if _room_id == "" or _lobby_server_url == "" or _player_id == "":
		return

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/ready"
	var http := HTTPRequest.new()
	add_child(http)
	var body := {
		"player_id": _player_id,
		"ready": pressed
	}
	var headers := ["Content-Type: application/json"]
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	# Ask host UI to reflect quickly
	_fetch_room()


func _setup_relay_connection() -> void:
	if _lobby_server_url.strip_edges() == "" or _room_id.strip_edges() == "":
		return
	var RelayClientScript := load("res://script/WebSocketRelayClient.gd")
	if not RelayClientScript:
		return
	_relay_client = RelayClientScript.new()
	add_child(_relay_client)
	_relay_client.connected_to_relay.connect(_on_relay_connected)
	_relay_client.disconnected_from_relay.connect(_on_relay_disconnected)
	_relay_client.message_received.connect(_on_relay_message_received)
	_relay_client.error_occurred.connect(func(_msg: String):
		_relay_connected = false
	)
	var pid: String = _player_id
	var uname: String = Auth.current_username if Auth else "Player"
	_relay_client.connect_to_relay(_lobby_server_url, _room_id, pid, uname)


func _on_relay_connected() -> void:
	_relay_connected = true
	# Share cosmetics so others can render even if snapshot is stale.
	if _relay_client and Auth:
		_relay_client.send_message({
			"type": "cosmetics_update",
			"player_id": Auth.current_local_id,
			"card_bg": Auth.current_card_bg_path
		})
		_relay_client.send_message({
			"type": "cosmetics_request",
			"player_id": Auth.current_local_id
		})


func _on_relay_disconnected() -> void:
	_relay_connected = false


func _on_relay_message_received(data: Dictionary) -> void:
	var msg_type := str(data.get("type", ""))
	match msg_type:
		"cosmetics_request":
			if _relay_client and Auth:
				_relay_client.send_message({
					"type": "cosmetics_update",
					"player_id": Auth.current_local_id,
					"card_bg": Auth.current_card_bg_path
				})
		"cosmetics_update":
			if Auth:
				var pid := str(data.get("player_id", ""))
				if pid != "" and pid != Auth.current_local_id:
					Auth.set_remote_card_bg(pid, str(data.get("card_bg", "")))
					_fetch_room()
		"host_promotion":
			var new_host_id := str(data.get("new_host_id", ""))
			if Auth and new_host_id == Auth.current_local_id:
				_is_host = true
				_configure_buttons()
				_fetch_room()
			else:
				_fetch_room()
		_:
			pass


func _fetch_room() -> void:
	if _room_id == "" or _lobby_server_url == "":
		return

	var url := _lobby_server_url + "/api/rooms/" + _room_id
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			return
		if data.has("error"):
			_message_label.text = "Room closed."
			_transition_back_to_landing()
			return
		_apply_snapshot(data)
	)

	http.request(url, [], HTTPClient.METHOD_GET)


func _apply_snapshot(room_data: Dictionary) -> void:
	_latest_room_data = room_data
	var room_name := str(room_data.get("room_name", ""))
	if room_name.strip_edges() != "":
		_room_id_label.text = "ROOM: " + room_name

	var status := str(room_data.get("status", "waiting"))
	_room_state_label.text = status.to_upper()

	# If host started the game, everyone transitions
	if status == "in_game" and not _transitioning:
		_transitioning = true
		_transition_to_loading(room_data)
		return

	var host_val = room_data.get("host", null)
	var c1_val = room_data.get("client", null)
	var c2_val = room_data.get("client2", null)
	var my_uid: String = Auth.current_local_id if Auth else _player_id
	var my_bg: String = Auth.current_card_bg_path if Auth else ""

	# Host card
	if typeof(host_val) == TYPE_DICTIONARY:
		# Cosmetics fallback + self sync
		if Auth and str(host_val.get("card_bg", "")).strip_edges() == "":
			var host_pid_cache := str(host_val.get("player_id", ""))
			var cached_bg: String = str(Auth.get_remote_card_bg(host_pid_cache))
			if cached_bg.strip_edges() != "":
				host_val["card_bg"] = cached_bg
		if my_uid != "" and str(host_val.get("player_id", "")) == my_uid:
			var snapshot_bg := str(host_val.get("card_bg", ""))
			if my_bg != "" and snapshot_bg != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				host_val["card_bg"] = my_bg

		_host_username.text = str(host_val.get("username", "Host"))
		_host_level.text = "Level: " + str(int(host_val.get("level", 1)))
		CardCosmetics.apply_card_background(_host_card_node, str(host_val.get("card_bg", "")))
		_host_status.text = "HOST"
		_host_status.add_theme_color_override("font_color", COLOR_ACCENT)
		# Promotion detection if host changed
		if my_uid != "" and str(host_val.get("player_id", "")) == my_uid and not _is_host:
			_is_host = true
			_configure_buttons()
	else:
		_host_username.text = "."
		_host_level.text = ""
		_host_status.text = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)
		CardCosmetics.apply_card_background(_host_card_node, "")

	# Client 1 card
	if typeof(c1_val) == TYPE_DICTIONARY:
		var c1_present := true
		if not _last_client1_present:
			_message_label.text = "Player joined!"
			_play_client_join_animations("ClientCard")
		_last_client1_present = c1_present

		# Cosmetics fallback + self sync
		if Auth and str(c1_val.get("card_bg", "")).strip_edges() == "":
			var c1_pid_cache := str(c1_val.get("player_id", ""))
			var cached_bg1: String = str(Auth.get_remote_card_bg(c1_pid_cache))
			if cached_bg1.strip_edges() != "":
				c1_val["card_bg"] = cached_bg1
		if my_uid != "" and str(c1_val.get("player_id", "")) == my_uid:
			var snapshot_bg1 := str(c1_val.get("card_bg", ""))
			if my_bg != "" and snapshot_bg1 != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				c1_val["card_bg"] = my_bg

		_client_username.text = str(c1_val.get("username", "Player"))
		_client_level.text = "Level: " + str(int(c1_val.get("level", 1)))
		var c1_ready := bool(c1_val.get("ready", false))
		_client_status.text = ("READY" if c1_ready else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if c1_ready else COLOR_DANGER))
		CardCosmetics.apply_card_background(_client_card_node, str(c1_val.get("card_bg", "")))
	else:
		if _last_client1_present:
			_message_label.text = "Player left."
			_play_client_leave_animations("ClientCard")
		_last_client1_present = false
		CardCosmetics.apply_card_background(_client_card_node, "")
		_client_username.text = "."
		_client_level.text = "."
		_client_status.text = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)

	# Client 2 card
	if typeof(c2_val) == TYPE_DICTIONARY:
		var c2_present := true
		if not _last_client2_present:
			_message_label.text = "Player joined!"
			_play_client_join_animations("Client2Card")
		_last_client2_present = c2_present

		# Cosmetics fallback + self sync
		if Auth and str(c2_val.get("card_bg", "")).strip_edges() == "":
			var c2_pid_cache := str(c2_val.get("player_id", ""))
			var cached_bg2: String = str(Auth.get_remote_card_bg(c2_pid_cache))
			if cached_bg2.strip_edges() != "":
				c2_val["card_bg"] = cached_bg2
		if my_uid != "" and str(c2_val.get("player_id", "")) == my_uid:
			var snapshot_bg2 := str(c2_val.get("card_bg", ""))
			if my_bg != "" and snapshot_bg2 != my_bg:
				_sync_my_card_bg_to_lobby(my_bg)
				c2_val["card_bg"] = my_bg

		_client2_username.text = str(c2_val.get("username", "Player"))
		_client2_level.text = "Level: " + str(int(c2_val.get("level", 1)))
		var c2_ready := bool(c2_val.get("ready", false))
		_client2_status.text = ("READY" if c2_ready else "NOT READY")
		_client2_status.add_theme_color_override("font_color", (COLOR_ACCENT if c2_ready else COLOR_DANGER))
		CardCosmetics.apply_card_background(_client2_card_node, str(c2_val.get("card_bg", "")))
	else:
		if _last_client2_present:
			_message_label.text = "Player left."
			_play_client_leave_animations("Client2Card")
		_last_client2_present = false
		CardCosmetics.apply_card_background(_client2_card_node, "")
		_client2_username.text = "."
		_client2_level.text = "."
		_client2_status.text = "Searching.."
		_client2_status.add_theme_color_override("font_color", COLOR_MUTED)

	var current_players: int = int(room_data.get("current_players", 1))
	var can_start := _is_host and status == "waiting" and current_players >= 2 and _are_all_present_clients_ready(room_data)
	if _is_host:
		_start_btn.disabled = not can_start
		_message_label.text = ("All players ready. You can start." if can_start else "Waiting for all players to ready up...")
	else:
		_message_label.text = "Toggle READY, then wait for host." 


func _play_client_join_animations(card_name: String) -> void:
	var username_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/Username/AnimationPlayer" % card_name)
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play("usrreadyani")

	var status_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/StatusLabel/AnimationPlayer" % card_name)
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play("usersearchingani")

	var card_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/AnimationPlayer" % card_name)
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play("usercardani")


func _play_client_leave_animations(card_name: String) -> void:
	var username_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/Username/AnimationPlayer" % card_name)
	if username_anim and username_anim.has_animation("usrreadyani"):
		username_anim.play_backwards("usrreadyani")

	var status_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/StatusLabel/AnimationPlayer" % card_name)
	if status_anim and status_anim.has_animation("usersearchingani"):
		status_anim.play_backwards("usersearchingani")

	var card_anim: AnimationPlayer = get_node_or_null("CardsContainer/%s/AnimationPlayer" % card_name)
	if card_anim and card_anim.has_animation("usercardani"):
		card_anim.play_backwards("usercardani")


func _sync_my_card_bg_to_lobby(bg_path: String) -> void:
	if _room_id == "" or _lobby_server_url == "":
		return
	if not Auth or Auth.current_local_id == "":
		return

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/cosmetics"
	var body := {
		"player_id": Auth.current_local_id,
		"card_bg": bg_path
	}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))


func _are_all_present_clients_ready(room_data: Dictionary) -> bool:
	var c1_val = room_data.get("client", null)
	if typeof(c1_val) == TYPE_DICTIONARY and not bool(c1_val.get("ready", false)):
		return false
	var c2_val = room_data.get("client2", null)
	if typeof(c2_val) == TYPE_DICTIONARY and not bool(c2_val.get("ready", false)):
		return false
	return true


func _get_my_slot() -> String:
	var my_uid: String = _player_id
	if my_uid == "":
		return ""
	if _is_host:
		return "host"
	if typeof(_latest_room_data) != TYPE_DICTIONARY:
		return ""
	var c1_val = _latest_room_data.get("client", null)
	if typeof(c1_val) == TYPE_DICTIONARY and str(c1_val.get("player_id", "")) == my_uid:
		return "client"
	var c2_val = _latest_room_data.get("client2", null)
	if typeof(c2_val) == TYPE_DICTIONARY and str(c2_val.get("player_id", "")) == my_uid:
		return "client2"
	return ""


func _on_start_pressed() -> void:
	if not _is_host or _room_id == "" or _lobby_server_url == "":
		return

	# Guard: require at least 2 players + all present clients ready
	var status := str(_latest_room_data.get("status", "waiting"))
	var current_players: int = int(_latest_room_data.get("current_players", 1))
	if status != "waiting" or current_players < 2 or not _are_all_present_clients_ready(_latest_room_data):
		_message_label.text = "Players not ready yet."
		_start_btn.disabled = false
		return

	_start_btn.disabled = true
	_message_label.text = "Starting..."

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/status"
	var http := HTTPRequest.new()
	add_child(http)

	# Schedule a synchronized start time (server timestamp) so all clients reach arena together.
	var body := {
		"status": "in_game",
		"game_start_in_ms": LOADING_DURATION_MS
	}
	var headers := ["Content-Type: application/json"]

	http.request_completed.connect(func(_r, code, _h, body_bytes):
		http.queue_free()
		if code != 200:
			_start_btn.disabled = false
			_message_label.text = "Failed to start. Try again."
			return
		# Best-effort: transition host immediately using latest snapshot.
		var latest := _latest_room_data if typeof(_latest_room_data) == TYPE_DICTIONARY else {}
		if not _transitioning:
			_transitioning = true
			# If server returned game_start_time_ms, merge it into snapshot for the loading scene.
			var resp = JSON.parse_string(body_bytes.get_string_from_utf8())
			if typeof(resp) == TYPE_DICTIONARY and resp.has("game_start_time_ms"):
				latest["game_start_time_ms"] = int(resp.get("game_start_time_ms", 0))
			_transition_to_loading(latest)
	)

	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_leave_pressed() -> void:
	if _room_id == "" or _lobby_server_url == "":
		_transition_back_to_landing()
		return

	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	var http := HTTPRequest.new()
	add_child(http)

	var pid: String = _player_id
	var body := {"player_id": pid}
	var headers := ["Content-Type: application/json"]

	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
		_transition_back_to_landing()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func _transition_to_loading(room_data: Dictionary) -> void:
	# Stop polling to avoid double-transition
	if _poll_timer and is_instance_valid(_poll_timer):
		_poll_timer.stop()

	# Preserve relay client across scene change
	if _relay_client and is_instance_valid(_relay_client) and _relay_client.get_parent():
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)

	var host_val = room_data.get("host", {})
	var c1_val = room_data.get("client", {})
	var c2_val = room_data.get("client2", {})
	var start_ms := int(room_data.get("game_start_time_ms", 0))

	get_tree().set_meta("defuse_trojan_loading_init", {
		"room_id": _room_id,
		"is_host": _is_host,
		"lobby_server_url": _lobby_server_url,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"host_data": host_val,
		"client_data": c1_val,
		"client2_data": c2_val,
		"game_start_time_ms": start_ms,
		"loading_duration_ms": LOADING_DURATION_MS
	})

	get_tree().change_scene_to_file("res://scene/defuse_trojan_loading.tscn")


func _transition_back_to_landing() -> void:
	if _relay_client and is_instance_valid(_relay_client) and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	get_tree().change_scene_to_file("res://scene/landing.tscn")
