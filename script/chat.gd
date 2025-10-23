extends Panel

var _dragging := false
var _drag_offset := Vector2.ZERO
var _handle: Control
var _other_user_id: String = ""
var _messages_container: VBoxContainer
var _message_input: LineEdit
var _send_button: Button
var _username_label: Label
var _scroll_container: ScrollContainer
var _displayed_messages: Dictionary = {}

func _ready() -> void:
	print("[Chat] _ready() called")
	
	# Allow free positioning independent of parent layout
	top_level = true
	
	# Initially hidden
	visible = false
	print("[Chat] Chat panel initialized, visible=false")

	# Use child 'Panel' as handle if exists; else drag from this node
	if has_node("VBoxContainer/Panel"):
		_handle = $VBoxContainer/Panel
		print("[Chat] Handle (Panel) found for dragging")
	if _handle:
		_handle.gui_input.connect(_on_gui_input)
		_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		gui_input.connect(_on_gui_input)
		mouse_default_cursor_shape = Control.CURSOR_MOVE

	# Get references to chat UI elements
	if has_node("VBoxContainer/ScrollContainer/VBoxContainer"):
		_messages_container = $VBoxContainer/ScrollContainer/VBoxContainer
		print("[Chat] Messages container found")
	if has_node("VBoxContainer/HBoxContainer/LineEdit"):
		_message_input = $VBoxContainer/HBoxContainer/LineEdit
		print("[Chat] Message input found")
	if has_node("VBoxContainer/HBoxContainer/Button"):
		_send_button = $VBoxContainer/HBoxContainer/Button
		print("[Chat] Send button found")
	
	# Get username label - CORRECT PATH
	if has_node("VBoxContainer/Panel/UsernameLabel"):
		_username_label = $VBoxContainer/Panel/UsernameLabel
		print("[Chat] Username label found at VBoxContainer/Panel/UsernameLabel")
	else:
		print("[Chat] WARNING: UsernameLabel not found at VBoxContainer/Panel/UsernameLabel")
	
	# Get scroll container reference
	if has_node("VBoxContainer/ScrollContainer"):
		_scroll_container = $VBoxContainer/ScrollContainer
		print("[Chat] Scroll container found")
	
	# Connect signals
	if _send_button:
		_send_button.pressed.connect(_on_send_pressed)
	if _message_input:
		_message_input.text_submitted.connect(_on_message_submitted)
	
	# Connect to ChatManager signals
	if is_instance_valid(ChatManager):
		ChatManager.chat_loaded.connect(_on_chat_loaded)
		ChatManager.message_received.connect(_on_message_received)
		print("[Chat] Connected to ChatManager signals")
	else:
		push_error("ChatManager autoload not found!")

func _process(_delta: float) -> void:
	if not _dragging:
		return

	var target := get_global_mouse_position() - _drag_offset
	var vp := get_viewport_rect()
	var max_pos := vp.size - size
	target.x = clamp(target.x, 0.0, max_pos.x)
	target.y = clamp(target.y, 0.0, max_pos.y)
	global_position = target

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position - global_position
			accept_event()
		else:
			_dragging = false
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false

func open_chat_with(user_id: String, user_name: String = "") -> void:
	print("[Chat] open_chat_with called: user_id=%s, user_name=%s" % [user_id, user_name])
	
	_other_user_id = user_id
	
	# Show the chat panel
	visible = true
	print("[Chat] Chat panel made visible")
	
	# Clear previous messages
	if _messages_container:
		for child in _messages_container.get_children():
			child.queue_free()
		_displayed_messages.clear()
	
	# Update username label
	if _username_label:
		_username_label.text = user_name if user_name else "Chat"
		print("[Chat] Username label updated to: ", _username_label.text)
	else:
		print("[Chat] WARNING: Username label is null!")
	
	# Load chat history
	if is_instance_valid(ChatManager):
		print("[Chat] Loading chat history for: ", user_id)
		ChatManager.load_chat_history(user_id)
	else:
		push_error("[Chat] ChatManager not available")

func _on_chat_loaded(messages: Array) -> void:
	print("[Chat] Chat loaded with %d messages" % messages.size())
	for msg in messages:
		_display_message(msg)

func _on_message_received(message: Dictionary) -> void:
	# Avoid duplicate messages
	var msg_key = message.get("key", "")
	if msg_key != "" and _displayed_messages.has(msg_key):
		return
	
	print("[Chat] Message received from: ", message.get("sender", "Unknown"))
	_display_message(message)
	
	# Auto-scroll to bottom
	if _scroll_container:
		await get_tree().process_frame
		_scroll_container.scroll_vertical = int(1e9)

func _display_message(msg: Dictionary) -> void:
	if not _messages_container:
		print("[Chat] WARNING: Messages container is null!")
		return
	
	var msg_key = msg.get("key", "")
	if msg_key != "":
		_displayed_messages[msg_key] = true
	
	var is_own_message = msg.get("sender") == ChatManager.current_user_id
	var msg_label = Label.new()
	msg_label.text = "%s: %s" % [msg.get("sender", "Unknown"), msg.get("text", "")]
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	if is_own_message:
		msg_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		msg_label.add_theme_color_override("font_color", Color.WHITE)
	
	_messages_container.add_child(msg_label)
	print("[Chat] Message displayed: ", msg_label.text)

func _on_send_pressed() -> void:
	if _message_input:
		_on_message_submitted(_message_input.text)

func _on_message_submitted(text: String) -> void:
	if text.is_empty():
		return
	
	print("[Chat] Sending message: ", text)
	ChatManager.send_message(text)
	if _message_input:
		_message_input.clear()
