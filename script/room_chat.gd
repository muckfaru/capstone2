extends Panel

@onready var _title_label: Label = $VBoxContainer/Panel/UsernameLabel
@onready var _drag_header: Panel = $VBoxContainer/Panel
@onready var _scroll: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var _messages_box: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var _input: LineEdit = $VBoxContainer/HBoxContainer/LineEdit
@onready var _send_btn: Button = $VBoxContainer/HBoxContainer/Button

const DEFAULT_POLL := 2.0

var _rtdb_base: String = ""
var _rooms_path: String = ""
var _room_id: String = ""
var _chat_url: String = ""
var _poll_timer: Timer
var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	_title_label.text = "CHAT"
	if _send_btn and not _send_btn.pressed.is_connected(_on_send_pressed):
		_send_btn.pressed.connect(_on_send_pressed)
	if _input and not _input.text_submitted.is_connected(_on_text_submitted):
		_input.text_submitted.connect(_on_text_submitted)
	if _drag_header and not _drag_header.gui_input.is_connected(_on_header_gui_input):
		_drag_header.gui_input.connect(_on_header_gui_input)
	# Setup polling timer (started after initialize)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = DEFAULT_POLL
	_poll_timer.one_shot = false
	_poll_timer.autostart = false
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_fetch_messages)

# Initialize the chat with the current room context
func initialize(rtdb_base: String, rooms_path: String, room_id: String) -> void:
	_rtdb_base = rtdb_base
	_rooms_path = rooms_path
	_room_id = room_id
	_chat_url = _rtdb_base + _rooms_path + "/" + _room_id + "/chat"
	# Start polling
	_fetch_messages()
	_poll_timer.start()
func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = get_viewport().get_mouse_position() - global_position
				accept_event()
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var new_pos := motion.position + _drag_header.global_position - _drag_header.position - _drag_offset
		# Clamp to viewport bounds
		var vp := get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, max(0.0, vp.x - size.x))
		new_pos.y = clamp(new_pos.y, 0.0, max(0.0, vp.y - size.y))
		global_position = new_pos
		accept_event()

func _on_send_pressed() -> void:
	_send_text(_input.text)

func _on_text_submitted(text: String) -> void:
	_send_text(text)

func _send_text(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	_input.text = ""
	_send_message(clean)

func _send_message(text: String) -> void:
	if _chat_url == "":
		return
	var id_token := Auth.current_id_token if Auth else ""
	var uid := Auth.current_local_id if Auth else ""
	var username := (Auth.current_username if Auth else "Player")
	var payload := {
		"uid": uid,
		"username": username,
		"text": text,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[RoomChat] Send failed HTTP " + str(code))
			return
		# Refresh view quickly after sending
		_fetch_messages()
	)
	var url := _chat_url + ".json" + ("?auth=" + id_token if id_token != "" else "")
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))

func _fetch_messages() -> void:
	if _chat_url == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		http.queue_free()
		if code != 200:
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		_render_messages(data)
	)
	var url := _chat_url + ".json"
	http.request(url, [], HTTPClient.METHOD_GET)

func _render_messages(data) -> void:
	# Rebuild the message list simply
	for c in _messages_box.get_children():
		c.queue_free()
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return
	# Sort by timestamp ascending using values, then append labels
	var msgs: Array = []
	for k in data.keys():
		var v = data[k]
		if typeof(v) == TYPE_DICTIONARY:
			msgs.append(v)
	msgs.sort_custom(func(a, b): return int(a.get("timestamp", 0)) < int(b.get("timestamp", 0)))
	for m in msgs:
		var user := str(m.get("username", "?"))
		var text := str(m.get("text", ""))
		var label := Label.new()
		label.text = user + ": " + text
		_messages_box.add_child(label)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
