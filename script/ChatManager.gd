extends Node

signal message_received(message: Dictionary)
signal chat_loaded(messages: Array)

var current_user_id: String = ""
var current_chat_user_id: String = ""
var _initialized := true
var _listening := false
var _listen_timer: Timer
var _last_received_keys: Dictionary = {}

const RTDB_BASE: String = "https://capstone-823dc-default-rtdb.firebaseio.com"

func _ready() -> void:
	print("[ChatManager] Initialized (using direct RTDB access)")
	
	# Create timer for polling new messages
	_listen_timer = Timer.new()
	_listen_timer.wait_time = 2.0
	_listen_timer.timeout.connect(_poll_new_messages)
	add_child(_listen_timer)

func set_current_user(user_id: String) -> void:
	current_user_id = user_id
	print("[ChatManager] Current user set to: ", user_id)

func load_chat_history(other_user_id: String) -> void:
	current_chat_user_id = other_user_id
	var chat_path = _get_chat_path(current_user_id, other_user_id)
	print("[ChatManager] Loading chat history from: ", chat_path)
	
	# Clear previous keys
	_last_received_keys.clear()
	
	# Start listening for new messages
	_start_listening()
	
	var token = Auth.current_id_token
	if token == "":
		push_error("[ChatManager] No auth token available")
		return
	
	var url = "%s/%s.json?auth=%s" % [RTDB_BASE, chat_path, token]
	print("[ChatManager] Fetching from URL: ", url)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			print("[ChatManager] Failed to load chat history, code: ", code)
			print("[ChatManager] Response: ", body.get_string_from_utf8())
			return
		
		var txt = body.get_string_from_utf8()
		print("[ChatManager] Raw response: ", txt)
		if txt == "null" or txt == "":
			print("[ChatManager] No chat history found (empty response)")
			chat_loaded.emit([])
			return
		
		var data = JSON.parse_string(txt)
		var messages = []
		if data and data.has("messages"):
			for msg_key in data["messages"]:
				var msg = data["messages"][msg_key]
				msg["key"] = msg_key
				_last_received_keys[msg_key] = true
				messages.append(msg)
			print("[ChatManager] Parsed %d messages from history" % messages.size())
		else:
			print("[ChatManager] No messages found in data structure")
		
		print("[ChatManager] Emitting chat_loaded with %d messages" % messages.size())
		chat_loaded.emit(messages)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _start_listening() -> void:
	if _listening:
		return
	_listening = true
	_listen_timer.start()
	print("[ChatManager] Started listening for new messages (polling every 2 seconds)")

func _poll_new_messages() -> void:
	if current_chat_user_id.is_empty() or current_user_id.is_empty():
		return
	
	var chat_path = _get_chat_path(current_user_id, current_chat_user_id)
	var token = Auth.current_id_token
	if token == "":
		return
	
	var url = "%s/%s/messages.json?auth=%s" % [RTDB_BASE, chat_path, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			print("[ChatManager] Poll failed with code: ", code)
			return
		
		var txt = body.get_string_from_utf8()
		if txt == "null" or txt == "":
			return
		
		var data = JSON.parse_string(txt)
		if data and typeof(data) == TYPE_DICTIONARY:
			var msg_count = 0
			for msg_key in data.keys():
				# Only emit if we haven't seen this key before
				if not _last_received_keys.has(msg_key):
					var msg = data[msg_key]
					msg["key"] = msg_key
					_last_received_keys[msg_key] = true
					print("[ChatManager] New message received: ", msg.get("text", ""))
					message_received.emit(msg)
					msg_count += 1
			if msg_count > 0:
				print("[ChatManager] Emitted %d new messages" % msg_count)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func send_message(text: String) -> void:
	if text.is_empty() or current_chat_user_id.is_empty():
		push_error("[ChatManager] Cannot send empty message or no chat user selected")
		return
	
	var chat_path = _get_chat_path(current_user_id, current_chat_user_id)
	var token = Auth.current_id_token
	if token == "":
		push_error("[ChatManager] No auth token available")
		return
	
	var url = "%s/%s/messages.json?auth=%s" % [RTDB_BASE, chat_path, token]
	var msg_data = {
		"sender": current_user_id,
		"text": text,
		"timestamp": Time.get_ticks_msec()
	}
	
	print("[ChatManager] Sending message to: ", chat_path)
	print("[ChatManager] Message data: ", msg_data)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			print("[ChatManager] Message sent successfully")
		else:
			print("[ChatManager] Failed to send message, code: ", code)
			print("[ChatManager] Response: ", body.get_string_from_utf8())
	)
	http.request(url, [], HTTPClient.METHOD_POST, JSON.stringify(msg_data))

func stop_listening() -> void:
	if _listen_timer:
		_listen_timer.stop()
	_listening = false
	print("[ChatManager] Stopped listening for messages")

func _get_chat_path(user1: String, user2: String) -> String:
	var sorted = [user1, user2]
	sorted.sort()
	return "chats/%s_%s" % [sorted[0], sorted[1]]
