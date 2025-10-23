extends Node

signal message_received(message: Dictionary)
signal chat_loaded(messages: Array)
signal unread_count_changed(user_id: String, count: int)

var current_user_id: String = ""
var current_chat_user_id: String = ""
var _initialized := true
var _listening := false
var _listen_timer: Timer
var _last_received_keys: Dictionary = {}
var _unread_counts: Dictionary = {} # user_id -> unread count
var _all_chats_monitor_timer: Timer  # NEW: Monitor all chats for unread messages

const RTDB_BASE: String = "https://capstone-823dc-default-rtdb.firebaseio.com"

func _ready() -> void:
	print("[ChatManager] Initialized (using direct RTDB access)")
	
	# Create timer for polling new messages in current chat
	_listen_timer = Timer.new()
	_listen_timer.wait_time = 2.0
	_listen_timer.timeout.connect(_poll_new_messages)
	add_child(_listen_timer)
	
	# NEW: Create timer for monitoring all chats
	_all_chats_monitor_timer = Timer.new()
	_all_chats_monitor_timer.wait_time = 5.0  # Check every 5 seconds
	_all_chats_monitor_timer.autostart = true
	_all_chats_monitor_timer.timeout.connect(_monitor_all_chats)
	add_child(_all_chats_monitor_timer)

func set_current_user(user_id: String) -> void:
	current_user_id = user_id
	print("[ChatManager] Current user set to: ", user_id)
	# Start monitoring all chats
	_all_chats_monitor_timer.start()

func get_unread_count(user_id: String) -> int:
	var count = _unread_counts.get(user_id, 0)
	print("[ChatManager] get_unread_count for %s: %d" % [user_id, count])
	return count

# NEW: Monitor all chats for unread messages
func _monitor_all_chats() -> void:
	if current_user_id.is_empty():
		return
	
	# This would require knowing all friends - you'll need to integrate with FriendList
	# For now, we'll just check the chats we already know about
	for friend_id in _unread_counts.keys():
		_check_unread_for_user(friend_id)

# NEW: Check unread messages for a specific user
func _check_unread_for_user(other_user_id: String) -> void:
	# Skip if this is the currently open chat
	if other_user_id == current_chat_user_id:
		return
	
	var chat_path = _get_chat_path(current_user_id, other_user_id)
	var token = Auth.current_id_token
	if token == "":
		return
	
	var url = "%s/%s/messages.json?auth=%s" % [RTDB_BASE, chat_path, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return
		
		var txt = body.get_string_from_utf8()
		if txt == "null" or txt == "":
			return
		
		var data = JSON.parse_string(txt)
		if data and typeof(data) == TYPE_DICTIONARY:
			var unread = 0
			for msg_key in data.keys():
				var msg = data[msg_key]
				# Count messages from other user that are not seen
				if msg.get("sender") == other_user_id and not msg.get("seen", false):
					unread += 1
			
			# Update unread count if changed
			if _unread_counts.get(other_user_id, 0) != unread:
				_unread_counts[other_user_id] = unread
				print("[ChatManager] Updated unread count for %s: %d" % [other_user_id, unread])
				unread_count_changed.emit(other_user_id, unread)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

# NEW: Initialize unread count for a friend
func initialize_unread_for_friend(friend_id: String) -> void:
	if not _unread_counts.has(friend_id):
		_unread_counts[friend_id] = 0
	_check_unread_for_user(friend_id)

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
		
		# Mark all messages as read when opening chat
		mark_chat_as_read(other_user_id)
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
					
					# Don't increment unread for currently open chat
					# (it will be marked as read immediately)
					msg_count += 1
			if msg_count > 0:
				print("[ChatManager] Emitted %d new messages" % msg_count)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _increment_unread_count(sender_id: String) -> void:
	if sender_id.is_empty():
		return
	
	# Don't increment if we're currently viewing this chat
	if sender_id == current_chat_user_id:
		return
	
	var current = _unread_counts.get(sender_id, 0)
	_unread_counts[sender_id] = current + 1
	print("[ChatManager] Unread count for %s: %d" % [sender_id, _unread_counts[sender_id]])
	unread_count_changed.emit(sender_id, _unread_counts[sender_id])

func mark_chat_as_read(user_id: String) -> void:
	print("[ChatManager] Marking chat with %s as read" % user_id)
	if _unread_counts.has(user_id):
		_unread_counts[user_id] = 0
		print("[ChatManager] Marked chat with %s as read" % user_id)
		unread_count_changed.emit(user_id, 0)
	
	# Mark messages as seen in database
	_mark_messages_as_seen(user_id)

func _mark_messages_as_seen(other_user_id: String) -> void:
	var chat_path = _get_chat_path(current_user_id, other_user_id)
	var token = Auth.current_id_token
	if token == "":
		return
	
	# Get all messages first
	var url = "%s/%s/messages.json?auth=%s" % [RTDB_BASE, chat_path, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			return
		
		var txt = body.get_string_from_utf8()
		if txt == "null" or txt == "":
			return
		
		var data = JSON.parse_string(txt)
		if data and typeof(data) == TYPE_DICTIONARY:
			# Mark each message from other user as seen
			for msg_key in data.keys():
				var msg = data[msg_key]
				if msg.get("sender") == other_user_id and not msg.get("seen", false):
					_update_message_seen_status(chat_path, msg_key)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _update_message_seen_status(chat_path: String, msg_key: String) -> void:
	var token = Auth.current_id_token
	if token == "":
		return
	
	var url = "%s/%s/messages/%s/seen.json?auth=%s" % [RTDB_BASE, chat_path, msg_key, token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body):
		http.queue_free()
		if code == 200:
			print("[ChatManager] Marked message %s as seen" % msg_key)
	)
	http.request(url, [], HTTPClient.METHOD_PUT, "true")

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
		"timestamp": Time.get_ticks_msec(),
		"seen": false
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
