extends Panel

@onready var friend_container: VBoxContainer = $FriendListVBox
@onready var http_node: HTTPRequest = $HTTPRequest

# Firebase
var api_key: String = "AIzaSyAZvW_4HWndG-Spu5eUrxSf_yRKbpswm3Q"
var project_id: String = "capstone-823dc"
var base_url: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % project_id

var user_uid: String = ""
var user_data: Dictionary = {}

func _ready() -> void:
	if friend_container == null:
		push_error("FriendListVBox not found")
	if http_node == null:
		push_error("HTTPRequest node not found; creating one")
		http_node = HTTPRequest.new()
		add_child(http_node)

	# get uid from your Auth singleton if available
	if Engine.has_singleton("Auth"):
		user_uid = Engine.get_singleton("Auth").current_local_id if Engine.get_singleton("Auth").has("current_local_id") else ""
	else:
		# fallback: try global
		if Engine.has_singleton("Global") and Engine.get_singleton("Global").has("user_uid"):
			user_uid = Engine.get_singleton("Global").user_uid

	# initial load
	if user_uid != "":
		load_friend_list()


# Fetch user's document and display friends[] (if exists)
func load_friend_list() -> void:
	if user_uid == "":
		push_warning("No logged in user uid; cannot load friend list")
		return

	var url := "%s/users/%s" % [base_url, user_uid]
	var headers := [
		"Authorization: Bearer %s" % (Engine.get_singleton("Auth").current_id_token if Engine.has_singleton("Auth") else "")
	]
	# use a temporary HTTPRequest to avoid signal collision
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, response_code, headers_r, body_r):
		_clear_vbox(friend_container)
		if response_code == 200:
			var parsed = JSON.parse_string(body_r.get_string_from_utf8())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("fields") and parsed["fields"].has("friends"):
				var arr = parsed["fields"]["friends"]["arrayValue"]["values"]
				display_friends(arr)
			else:
				var lbl := Label.new()
				lbl.text = "No friends found."
				friend_container.add_child(lbl)
		else:
			push_error("Failed to load friends: %s" % response_code)
		req.queue_free()
	)
	req.request(url, headers, HTTPClient.METHOD_GET)


func display_friends(friends_array: Array) -> void:
	_clear_vbox(friend_container)
	for v in friends_array:
		if typeof(v) == TYPE_DICTIONARY and v.has("stringValue"):
			var uid: String = v["stringValue"] # explicit type avoids inference error
			var h := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = uid 
			h.add_child(lbl)
			friend_container.add_child(h)

# send friend request: adds to sender.outgoing and target.incoming (best-effort)
func send_friend_request(target_uid: String) -> void:
	if target_uid == "" or target_uid == user_uid:
		push_warning("Invalid target uid")
		return

	var user_doc := "%s/users/%s" % [base_url, user_uid]
	var target_doc := "%s/users/%s" % [base_url, target_uid]

	_patch_append_array(user_doc, "friend_requests.outgoing", target_uid)
	_patch_append_array(target_doc, "friend_requests.incoming", user_uid)


# accept friend request: adds each other to friends[] and removes pending keys
func accept_friend_request(request_uid: String) -> void:
	if request_uid == "":
		return
	var user_doc := "%s/users/%s" % [base_url, user_uid]
	var other_doc := "%s/users/%s" % [base_url, request_uid]

	_patch_append_array(user_doc, "friends", request_uid)
	_patch_append_array(other_doc, "friends", user_uid)

	_patch_remove_array(user_doc, "friend_requests.incoming", request_uid)
	_patch_remove_array(other_doc, "friend_requests.outgoing", user_uid)


# decline friend request
func decline_friend_request(request_uid: String) -> void:
	if request_uid == "":
		return
	var user_doc := "%s/users/%s" % [base_url, user_uid]
	var other_doc := "%s/users/%s" % [base_url, request_uid]

	_patch_remove_array(user_doc, "friend_requests.incoming", request_uid)
	_patch_remove_array(other_doc, "friend_requests.outgoing", user_uid)


# Helpers: Do a simple PATCH that writes the array field to the doc (Firestore REST expects a fields map)
func _patch_append_array(doc_url: String, field_path: String, new_value: String) -> void:
	var components := field_path.split(".")
	var body := {
		"fields": {
			components[0]: {
				"mapValue": {
					"fields": {
						components[1]: {
							"arrayValue": {"values": [{"stringValue": new_value}]}
						}
					}
				}
			}
		}
	}
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % (Engine.get_singleton("Auth").current_id_token if Engine.has_singleton("Auth") else "")
	]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, response_code, headers_r, body_r):
		if response_code != 200:
			push_warning("_patch_append_array failed: %s" % response_code)
		req.queue_free()
	)
	req.request(doc_url + "?key=" + api_key, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _patch_remove_array(doc_url: String, field_path: String, remove_value: String) -> void:
	var headers := [
		"Authorization: Bearer %s" % (Engine.get_singleton("Auth").current_id_token if Engine.has_singleton("Auth") else "")
	]
	var read_req := HTTPRequest.new()
	add_child(read_req)
	read_req.request_completed.connect(func(result, response_code, headers_r, body_r):
		if response_code == 200:
			var parsed = JSON.parse_string(body_r.get_string_from_utf8())
			if parsed.has("fields") and parsed["fields"].has(field_path.split(".")[0]):
				var arr = []
				var map = parsed["fields"].get(field_path.split(".")[0]).get("mapValue", {}).get("fields", {})
				if map.has(field_path.split(".")[1]):
					var vals = map[field_path.split(".")[1]].get("arrayValue", {}).get("values", [])
					for v in vals:
						if v.has("stringValue") and v["stringValue"] != remove_value:
							arr.append({"stringValue": v["stringValue"]})
				var body := {
					"fields": {
						field_path.split(".")[0]: {
							"mapValue": {
								"fields": {
									field_path.split(".")[1]: {
										"arrayValue": {"values": arr}
									}
								}
							}
						}
					}
				}
				var write_req := HTTPRequest.new()
				add_child(write_req)
				write_req.request_completed.connect(func(r2, c2, h2, b2):
					write_req.queue_free()
					if c2 != 200:
						push_warning("_patch_remove_array write failed: %s" % c2)
				)
				write_req.request(doc_url + "?key=" + api_key, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(body))
		else:
			push_warning("_patch_remove_array read failed: %s" % response_code)
		read_req.queue_free()
	)
	read_req.request(doc_url, headers, HTTPClient.METHOD_GET)


# Utility: clear VBox children
func _clear_vbox(vbox: VBoxContainer) -> void:
	for c in vbox.get_children():
		c.queue_free()
