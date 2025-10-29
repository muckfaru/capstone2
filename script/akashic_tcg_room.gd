extends Control

@onready var _room_id_label: Label = $RoomHeader/RoomIDLabel
@onready var _room_state_label: Label = $RoomHeader/RoomStateLabel
@onready var _host_username: Label = $CardsContainer/HostCard/Username
@onready var _host_level: Label = $CardsContainer/HostCard/Level
@onready var _host_status: Label = $CardsContainer/HostCard/StatusLabel
@onready var _client_username: Label = $CardsContainer/ClientCard/Username
@onready var _client_level: Label = $CardsContainer/ClientCard/Level
@onready var _client_status: Label = $CardsContainer/ClientCard/StatusLabel
@onready var _message_label: Label = $MessageLabel
@onready var _start_btn: Button = $ButtonPanel/StartButton
@onready var _leave_btn: Button = $ButtonPanel/LeaveButton

const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const POLL_INTERVAL := 2.0
const ROOMS_PATH := "/tgc_rooms"

# Theme colors (Cyber Neon)
const COLOR_ACCENT := Color(0, 0.819608, 1, 1) # cyan
const COLOR_DANGER := Color(1, 0.356863, 0.431373, 1) # pink-red
const COLOR_MUTED := Color(0.560784, 0.639216, 0.678431, 1) # muted gray-blue

var _room_id: String = ""
var _is_host: bool = false
var _last_client_present: bool = false
var _poll_timer: Timer

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_room_init"):
		init = get_tree().get_meta("tgc_room_init")
		# Clear so stale data isn't reused
		get_tree().set_meta("tgc_room_init", null)

	var room_id: String = str(init.get("room_id", "local"))
	var host_name: String = str(init.get("host_name", "Host"))
	var is_host: bool = bool(init.get("is_host", false))

	_room_id = room_id
	_is_host = is_host

	# Initially hide the randomized room id; will set actual room name after first fetch
	_room_id_label.text = ""
	_room_state_label.text = "WAITING"

	# Populate host card
	_host_username.text = host_name
	_host_level.text = ""
	_host_status.text = "READY"

	# Set client placeholder
	_client_username.text = "."
	_client_level.text = "."
	_client_status.text = "Searching.."

	_message_label.text = "Waiting for player to join..."

	# Buttons
	_start_btn.pressed.connect(func():
		print("[TGC Room] Start Match pressed")
	)
	_leave_btn.pressed.connect(_leave_room)

	# Start polling room state
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timeout)
	_fetch_room()

	# Configure action button based on role
	_configure_buttons()

	# Initialize embedded room chat with this room context
	var chat := get_node_or_null("RoomChat")
	if chat and chat.has_method("initialize"):
		chat.initialize(RTDB_BASE, ROOMS_PATH, _room_id)

func _on_poll_timeout() -> void:
	_fetch_room()

func _fetch_room() -> void:
	if _room_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Poll failed HTTP " + str(code))
			return
		var node = JSON.parse_string(body.get_string_from_utf8())
		if node == null or typeof(node) != TYPE_DICTIONARY:
			_message_label.text = "Room has been closed."
			_go_to_landing()
			return
		_apply_room_snapshot(node)
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)

func _apply_room_snapshot(node: Dictionary) -> void:
	var host_val = node.get("host", null)
	var client_val = node.get("client", null)
	var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY and host_val.size() > 0
	var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0

	# Update header with room name (fallback to host username)
	var host_name_for_room := "Host"
	if host_present:
		host_name_for_room = str(host_val.get("username", "Host"))
	var room_name := str(node.get("room_name", host_name_for_room))
	if room_name.strip_edges() == "":
		room_name = host_name_for_room
	# Show only the actual room name provided by the host, with prefix
	_room_id_label.text = "ROOM: " + room_name

	var current_uid := Auth.current_local_id if Auth else ""

	# If host is absent but client exists and it's us, promote self to host
	if not host_present and client_present and not _is_host:
		var client_uid := str(client_val.get("uid", ""))
		if client_uid == current_uid and current_uid != "":
			_message_label.text = "Host left. Promoting you to host..."
			var id_token := Auth.current_id_token if Auth else ""
			if id_token != "":
				_promote_self_to_host(client_val, id_token)
				return
			# If no token, just update local UI; lobby will reflect on next poll
			_is_host = true

	# Host UI
	if host_present:
		_host_username.text = str(host_val.get("username", "Host"))
		var host_lvl_val = host_val.get("level", 0)
		_host_level.text = "Level: " + str(int(host_lvl_val))
		var h_status := str(host_val.get("status", "ready"))
		_host_status.text = ("READY" if h_status == "ready" else "NOT READY")
		_host_status.add_theme_color_override("font_color", (COLOR_ACCENT if h_status == "ready" else COLOR_DANGER))
	else:
		_host_username.text = "."
		_host_level.text = ""
		_host_status.text = "LEFT"
		_host_status.add_theme_color_override("font_color", COLOR_DANGER)

	# Client UI
	if client_present:
		_client_username.text = str(client_val.get("username", "."))
		var client_lvl_val = client_val.get("level", 0)
		_client_level.text = "Level: " + str(int(client_lvl_val))
		var c_status := str(client_val.get("status", "not_ready"))
		_client_status.text = ("READY" if c_status == "ready" else "NOT READY")
		_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if c_status == "ready" else COLOR_DANGER))
		if not _last_client_present:
			_message_label.text = "Player joined!"

		# If we are the client, mirror ready state into toggle button
		if not _is_host:
			var client_uid2 := str(client_val.get("uid", ""))
			var my_uid := Auth.current_local_id if Auth else ""
			if client_uid2 == my_uid and _start_btn.toggle_mode:
				var is_ready := str(client_val.get("status", "not_ready")) == "ready"
				if _start_btn.button_pressed != is_ready:
					_start_btn.button_pressed = is_ready
				# Button shows the ACTION (opposite of current state)
				_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
	else:
		_client_username.text = "."
		_client_level.text = "."
		_client_status.text = "Searching.."
		_client_status.add_theme_color_override("font_color", COLOR_MUTED)
		if _last_client_present:
			_message_label.text = "Player left."
	_last_client_present = client_present

	# State + Start/Ready button enablement
	var players := (1 if host_present else 0) + (1 if client_present else 0)
	_room_state_label.text = ("READY" if players == 2 else "WAITING")
	_room_state_label.add_theme_color_override("font_color", (COLOR_ACCENT if players == 2 else COLOR_MUTED))
	# If we see host now equals our uid, flip _is_host
	if host_present:
		var host_uid := str(host_val.get("uid", ""))
		if host_uid == current_uid and not _is_host:
			_is_host = true
			_message_label.text = "You are the host now."
			_configure_buttons()
	# Enable/disable based on role
	if _is_host:
		var client_ready := client_present and (str(client_val.get("status", "not_ready")) == "ready")
		_start_btn.disabled = not (client_present and client_ready)
	else:
		_start_btn.disabled = false

func _promote_self_to_host(client_val: Dictionary, id_token: String) -> void:
	# Move client payload to host and clear client
	var patch_obj := {
		"host": client_val,
		"client": null,
		"state": "waiting"
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Promote to host failed HTTP " + str(code))
			return
		_is_host = true
		_message_label.text = "You are the host now."
		_fetch_room()
		_configure_buttons()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))

func _configure_buttons() -> void:
	if _is_host:
		_start_btn.toggle_mode = false
		_start_btn.text = "START MATCH"
		_start_btn.disabled = true  # until client present and ready
	else:
		_start_btn.toggle_mode = true
		# Maintain current pressed state; update label accordingly
		# Button shows the ACTION (opposite of current state)
		_start_btn.text = ("NOT READY" if _start_btn.button_pressed else "READY")
		_start_btn.disabled = false
		if not _start_btn.toggled.is_connected(_on_ready_toggled):
			_start_btn.toggled.connect(_on_ready_toggled)

func _on_ready_toggled(pressed: bool) -> void:
	# Update UI text immediately
	# Status displays the current state; button shows the action to switch
	_client_status.text = ("READY" if pressed else "NOT READY")
	_start_btn.text = ("NOT READY" if pressed else "READY")
	_client_status.add_theme_color_override("font_color", (COLOR_ACCENT if pressed else COLOR_DANGER))
	# Patch RTDB at client node
	if _room_id == "":
		return
	var id_token := Auth.current_id_token if Auth else ""
	if id_token == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _code, _h, _b):
		http.queue_free()
	)
	var patch := {"status": ("ready" if pressed else "not_ready")}
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + "/client.json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch))

func _leave_room() -> void:
	print("[TGC Room] Leave Room pressed")
	var id_token := Auth.current_id_token if Auth else ""
	if _room_id == "":
		_go_to_landing()
		return
	if id_token == "":
		push_warning("[TGC Room] No id_token; leaving without RTDB cleanup")
		_go_to_landing()
		return

	# Read room to decide whether to delete or just clear our slot
	var get_http := HTTPRequest.new()
	add_child(get_http)
	get_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		get_http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Could not read room before leave: HTTP " + str(code))
			_go_to_landing()
			return
		var node = JSON.parse_string(body.get_string_from_utf8())
		if typeof(node) != TYPE_DICTIONARY:
			_go_to_landing()
			return

		var host_val = node.get("host", null)
		var client_val = node.get("client", null)
		var host_present: bool = host_val != null and typeof(host_val) == TYPE_DICTIONARY and host_val.size() > 0
		var client_present: bool = client_val != null and typeof(client_val) == TYPE_DICTIONARY and client_val.size() > 0

		# Decide on operation
		if _is_host:
			if not client_present:
				_delete_room(id_token)
			else:
				_patch_room({"host": null, "state": "waiting"}, id_token)
		else:
			if not host_present:
				_delete_room(id_token)
			else:
				_patch_room({"client": null, "state": "waiting"}, id_token)
	)
	var get_url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json"
	get_http.request(get_url, [], HTTPClient.METHOD_GET)

func _patch_room(patch_obj: Dictionary, id_token: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Leave PATCH failed HTTP " + str(code))
		_go_to_landing()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(patch_obj))

func _delete_room(id_token: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[TGC Room] Leave DELETE failed HTTP " + str(code))
		_go_to_landing()
	)
	var url := RTDB_BASE + ROOMS_PATH + "/" + _room_id + ".json?auth=" + id_token
	http.request(url, [], HTTPClient.METHOD_DELETE)

func _go_to_landing() -> void:
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)
