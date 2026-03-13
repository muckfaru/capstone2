extends PopupPanel

var profile_pic: TextureRect
var username_label: Label
var level_label: Label
var wins_label: Label
var losses_label: Label
var winrate_label: Label
var match_played_label: Label
var rank_label: Label  # ✅ For displaying rank
var rank_icon_rect: TextureRect  # ✅ For rank icon
var close_btn: Button

var _match_history_vbox: VBoxContainer = null
var avatars: Dictionary = {}
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"
var http: HTTPRequest
var _pending_username: String = ""

const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"

# ✅ MATCH TutorialManager's EXACT rank thresholds
const RANK_THRESHOLDS := [
	{"name": "Iron", "min_xp": 0, "max_xp": 199, "color": Color(0.5, 0.5, 0.5), "icon": "res://asset/rankicon/IRON.png"},
	{"name": "Bronze", "min_xp": 200, "max_xp": 399, "color": Color(0.8, 0.5, 0.2), "icon": "res://asset/rankicon/BRONZE.png"},
	{"name": "Silver", "min_xp": 400, "max_xp": 699, "color": Color(0.75, 0.75, 0.75), "icon": "res://asset/rankicon/SILVER.png"},
	{"name": "Gold", "min_xp": 700, "max_xp": 1099, "color": Color(1, 0.843, 0), "icon": "res://asset/rankicon/GOLD.png"},
	{"name": "Platinum", "min_xp": 1100, "max_xp": 1599, "color": Color(0.4, 0.8, 0.7), "icon": "res://asset/rankicon/PLATINUM.png"},
	{"name": "Diamond", "min_xp": 1600, "max_xp": 2299, "color": Color(0.5, 0.7, 1), "icon": "res://asset/rankicon/DIAMOND.png"},
	{"name": "Master", "min_xp": 2300, "max_xp": 3199, "color": Color(0.8, 0.3, 0.8), "icon": "res://asset/rankicon/MASTER.png"},
	{"name": "Grandmaster", "min_xp": 3200, "max_xp": 4499, "color": Color(1, 0.2, 0.2), "icon": "res://asset/rankicon/GRANDMASTER.png"},
	{"name": "Challenger", "min_xp": 4500, "max_xp": 999999, "color": Color(0, 1, 1), "icon": "res://asset/rankicon/CHALLENGER.png"}
]

func _ready() -> void:
	# Get nodes dynamically instead of using @onready
	profile_pic = get_node_or_null("ProfilePanel/UserPanel/ProfilePic")
	username_label = get_node_or_null("ProfilePanel/UserPanel/usernameInput")
	level_label = get_node_or_null("ProfilePanel/UserPanel/levelInput")
	wins_label = get_node_or_null("ProfilePanel/UserPanel/winsInput")
	losses_label = get_node_or_null("ProfilePanel/UserPanel/losesInput")
	winrate_label = get_node_or_null("ProfilePanel/UserPanel/winrateInput")
	match_played_label = get_node_or_null("ProfilePanel/UserPanel/MatchPlayedInput")
	rank_label = get_node_or_null("ProfilePanel/UserPanel/rankLabel")
	rank_icon_rect = get_node_or_null("ProfilePanel/UserPanel/RankIconRect")
	close_btn = get_node_or_null("ProfilePanel/MatchHistoyPanel/MatchHistoyHeader/CloseViewPlayerProfile")

	_load_avatars()

	# Set up VBoxContainer inside the match history ScrollContainer
	var _scroll := get_node_or_null("ProfilePanel/MatchHistoyPanel/ScrollContainer")
	if _scroll:
		_match_history_vbox = VBoxContainer.new()
		_match_history_vbox.name = "HistoryVBox"
		_match_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_match_history_vbox.add_theme_constant_override("separation", 6)
		_scroll.add_child(_match_history_vbox)

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("[ViewPlayerProfile] Warning: close_btn not found")
	
	# Free self when dismissed by clicking outside or pressing Escape
	close_requested.connect(_on_close_pressed)
	
	print("[ViewPlayerProfile] Modal ready and initialized")

func _load_avatars() -> void:
	# DirAccess cannot list res:// in exported builds (.pck),
	# so use the hardcoded AvatarCatalog keys instead.
	avatars.clear()
	var avatar_files: Array = AvatarCatalog.DISPLAY_NAMES.keys()
	for file_name in avatar_files:
		var tex := load("res://asset/avatars/" + file_name)
		if tex:
			avatars[file_name] = tex

func display_player_profile(player_username: String) -> void:
	print("[ViewPlayerProfile] Fetching profile for: ", player_username)
	_pending_username = player_username
	var token = Auth.current_id_token
	if token == "":
		push_error("⚠️ Not authenticated")
		return

	# Free any leftover http node from a previous call
	if is_instance_valid(http):
		http.queue_free()
		http = null

	# Query for player by username
	var query_url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents:runQuery"
	var query_body = {
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "username"},
					"op": "EQUAL",
					"value": {"stringValue": player_username}
				}
			},
			"limit": 1
		}
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_player_data_received)
	var err := http.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))
	if err != OK:
		push_error("[ViewPlayerProfile] HTTP request error: %d" % err)
		http.queue_free()
		http = null

func _on_player_data_received(_result, response_code, _headers, body) -> void:
	var body_text: String = body.get_string_from_utf8()

	if response_code != 200:
		if response_code == 403:
			print("[ViewPlayerProfile] Firestore 403 — falling back to RTDB public profile")
			if is_instance_valid(http):
				http.queue_free()
				http = null
			_fetch_rtdb_profile()
			return
		push_error("⚠️ Failed to fetch player data — HTTP %d: %s" % [response_code, body_text])
		if is_instance_valid(http):
			http.queue_free()
		return

	var arr = JSON.parse_string(body_text)
	if typeof(arr) != TYPE_ARRAY or arr.size() == 0 or not arr[0].has("document"):
		push_error("⚠️ Player not found. Raw response: %s" % body_text)
		if is_instance_valid(http):
			http.queue_free()
		return

	var player_data = arr[0]["document"]["fields"]
	print("[ViewPlayerProfile] Player data received: ", player_data.keys())

	if username_label and player_data.has("username"):
		username_label.text = player_data["username"]["stringValue"]
		print("[ViewPlayerProfile] Set username: ", username_label.text)

	if level_label:
		if player_data.has("level"):
			level_label.text = str(int(_from_firestore_value(player_data["level"])))
		else:
			level_label.text = "1"

	var total_wins := 0
	var total_losses := 0

	if player_data.has("cb_wins"):    total_wins   += int(_from_firestore_value(player_data["cb_wins"]))
	if player_data.has("cb_losses"):  total_losses += int(_from_firestore_value(player_data["cb_losses"]))

	if player_data.has("akashic_wins"):   total_wins   += int(_from_firestore_value(player_data["akashic_wins"]))
	if player_data.has("akashic_losses"): total_losses += int(_from_firestore_value(player_data["akashic_losses"]))

	if player_data.has("dt_wins"):    total_wins   += int(_from_firestore_value(player_data["dt_wins"]))
	if player_data.has("dt_losses"):  total_losses += int(_from_firestore_value(player_data["dt_losses"]))

	# Legacy fallback if no per-game fields exist
	if total_wins == 0 and player_data.has("wins"):
		total_wins = int(_from_firestore_value(player_data["wins"]))
	if total_losses == 0 and player_data.has("losses"):
		total_losses = int(_from_firestore_value(player_data["losses"]))

	if wins_label:
		wins_label.text = str(total_wins)
	if losses_label:
		losses_label.text = str(total_losses)

	var total_matches := total_wins + total_losses
	if winrate_label:
		var wr := 0
		if total_matches > 0:
			wr = int((float(total_wins) / float(total_matches)) * 100.0)
		winrate_label.text = str(wr) + "%"

	if match_played_label:
		match_played_label.text = str(total_matches)

	# Avatar
	if profile_pic and player_data.has("avatar"):
		_apply_avatar(player_data["avatar"]["stringValue"])

	# ✅ FIX 2: use _from_firestore_value so doubleValue / string-encoded ints all work
	var xp_for_rank := 0
	if player_data.has("total_xp"):
		xp_for_rank = int(_from_firestore_value(player_data["total_xp"]))
	_display_rank(_get_rank_from_xp(xp_for_rank))

	# Free http node before any async work
	if is_instance_valid(http):
		http.queue_free()
		http = null

	# Match history — read from the Firestore fields we already have
	print("[ViewPlayerProfile] Firestore fields keys: ", player_data.keys())
	if player_data.has("recent_matches"):
		var decoded = _from_firestore_value(player_data["recent_matches"])
		if typeof(decoded) == TYPE_ARRAY and decoded.size() > 0:
			_render_friend_match_history(decoded, _pending_username)
		else:
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
	else:
		# Field absent — fall back to RTDB public_profiles
		_fetch_rtdb_match_history(_pending_username)

## Recursively decode a Firestore-encoded value into a plain GDScript value.
func _from_firestore_value(val: Dictionary):
	if val.has("stringValue"):   return str(val["stringValue"])
	if val.has("integerValue"):  return int(str(val["integerValue"]))
	if val.has("doubleValue"):   return float(val["doubleValue"])
	if val.has("booleanValue"):  return bool(val["booleanValue"])
	if val.has("nullValue"):     return null
	if val.has("arrayValue"):
		var out: Array = []
		var values = val["arrayValue"].get("values", [])
		for v in values:
			out.append(_from_firestore_value(v))
		return out
	if val.has("mapValue"):
		var out: Dictionary = {}
		var mfields = val["mapValue"].get("fields", {})
		for k in mfields:
			out[k] = _from_firestore_value(mfields[k])
		return out
	return null

func _fetch_rtdb_match_history(username: String) -> void:
	"""Fetch only the recent_matches sub-node from RTDB for the given username."""
	var token := Auth.current_id_token
	if token == "" or username == "":
		_add_history_placeholder("No match history available")
		return
	var url := "%s/public_profiles/%s/recent_matches.json?auth=%s" % [RTDB_BASE, username.uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		var body_text := body.get_string_from_utf8()
		if code != 200 or body_text == "null" or body_text == "":
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		var parsed = JSON.parse_string(body_text)
		var items: Array = []
		if typeof(parsed) == TYPE_ARRAY:
			items = parsed
		elif typeof(parsed) == TYPE_DICTIONARY:
			# RTDB may return array as {"0":{...},"1":{...}}
			var keys = parsed.keys()
			keys.sort()
			for k in keys:
				if typeof(parsed[k]) == TYPE_DICTIONARY:
					items.append(parsed[k])
		_render_friend_match_history(items, username)
	)
	req.request(url, [], HTTPClient.METHOD_GET)


func _fetch_rtdb_match_history_with_fallback(username: String, uid: String) -> void:
	"""Try RTDB public_profiles/{username}/recent_matches first; if absent, fall through to Firestore."""
	var token := Auth.current_id_token
	if token == "" or username == "":
		_add_history_placeholder("No match history available")
		return
	var url := "%s/public_profiles/%s/recent_matches.json?auth=%s" % [RTDB_BASE, username.uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		var body_text := body.get_string_from_utf8()
		if code == 200 and body_text != "null" and body_text != "":
			var parsed = JSON.parse_string(body_text)
			var items: Array = []
			if typeof(parsed) == TYPE_ARRAY:
				items = parsed
			elif typeof(parsed) == TYPE_DICTIONARY:
				var keys = parsed.keys()
				keys.sort()
				for k in keys:
					if typeof(parsed[k]) == TYPE_DICTIONARY:
						items.append(parsed[k])
			if items.size() > 0:
				print("[ViewPlayerProfile] Got %d recent_matches from RTDB sub-path for '%s'" % [items.size(), username])
				_render_friend_match_history(items, username)
				return
		# RTDB sub-path empty — fall back to Firestore user doc (works for own profile, 403 for others)
		print("[ViewPlayerProfile] RTDB sub-path empty for '%s' — trying Firestore uid lookup" % username)
		if uid != "":
			_fetch_history_from_firestore_user_doc(uid, username)
		else:
			_fetch_history_via_uid_lookup(username)
	)
	req.request(url, [], HTTPClient.METHOD_GET)

# ─── RTDB public profile fallback ─────────────────────────────────────────
func _fetch_rtdb_profile() -> void:
	var token := Auth.current_id_token
	if token == "" or _pending_username == "":
		push_error("[ViewPlayerProfile] Cannot fetch RTDB profile — missing auth or username")
		return
	var url := "%s/public_profiles/%s.json?auth=%s" % [RTDB_BASE, _pending_username.uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		var body_text: String = body.get_string_from_utf8()
		if code != 200:
			push_error("[ViewPlayerProfile] RTDB fallback failed HTTP %d: %s" % [code, body_text])
			return
		# "null" means the friend hasn't logged in since public profile was enabled
		# Show what we know (username) with zeroed defaults so the popup still opens
		if body_text == "null" or body_text == "":
			print("[ViewPlayerProfile] No RTDB profile yet for '%s' — showing defaults" % _pending_username)
			_populate_from_rtdb_data({"username": _pending_username})
			return
		var data = JSON.parse_string(body_text)
		if typeof(data) != TYPE_DICTIONARY:
			push_error("[ViewPlayerProfile] RTDB profile parse failed: %s" % body_text)
			return
		print("[ViewPlayerProfile] RTDB profile loaded for: ", _pending_username)
		_populate_from_rtdb_data(data)
	)
	req.request(url, [], HTTPClient.METHOD_GET)

func _populate_from_rtdb_data(data: Dictionary) -> void:
	print("[ViewPlayerProfile] RTDB data keys: ", data.keys())
	print("[ViewPlayerProfile] RTDB data: ", data)

	if username_label:
		username_label.text = str(data.get("username", _pending_username))

	if level_label:
		level_label.text = str(int(float(str(data.get("level", 1)))))

	var total_wins := 0
	var total_losses := 0

	if data.has("cb_wins"):      total_wins   += int(float(str(data["cb_wins"])))
	if data.has("cb_losses"):    total_losses += int(float(str(data["cb_losses"])))
	if data.has("akashic_wins"): total_wins   += int(float(str(data["akashic_wins"])))
	if data.has("akashic_losses"): total_losses += int(float(str(data["akashic_losses"])))
	if data.has("dt_wins"):      total_wins   += int(float(str(data["dt_wins"])))
	if data.has("dt_losses"):    total_losses += int(float(str(data["dt_losses"])))

	# Legacy wins/losses: use whichever is larger (handles stale nodes missing per-game fields)
	if data.has("wins"):
		var legacy_w := int(float(str(data["wins"])))
		if legacy_w > total_wins:
			total_wins = legacy_w
	if data.has("losses"):
		var legacy_l := int(float(str(data["losses"])))
		if legacy_l > total_losses:
			total_losses = legacy_l

	var total_matches := total_wins + total_losses

	if wins_label:        wins_label.text        = str(total_wins)
	if losses_label:      losses_label.text      = str(total_losses)
	if match_played_label: match_played_label.text = str(total_matches)
	if winrate_label:
		var wr := 0
		if total_matches > 0:
			wr = int((float(total_wins) / float(total_matches)) * 100.0)
		winrate_label.text = str(wr) + "%"

	var avatar_path: String = str(data.get("avatar", ""))
	if profile_pic and avatar_path != "":
		_apply_avatar(avatar_path)

	var total_xp := int(float(str(data.get("total_xp", 0))))
	_display_rank(_get_rank_from_xp(total_xp))

	var history_raw = data.get("recent_matches", null)
	if history_raw != null:
		var history_items: Array = []
		if typeof(history_raw) == TYPE_ARRAY:
			history_items = history_raw
		elif typeof(history_raw) == TYPE_DICTIONARY:
			var keys = history_raw.keys()
			keys.sort()
			for k in keys:
				if typeof(history_raw[k]) == TYPE_DICTIONARY:
					history_items.append(history_raw[k])
		print("[ViewPlayerProfile] recent_matches found in RTDB profile node (%d items)" % history_items.size())
		_render_friend_match_history(history_items, str(data.get("username", _pending_username)))
	else:
		print("[ViewPlayerProfile] recent_matches absent from profile node — trying sub-path and Firestore")
		_fetch_rtdb_match_history_with_fallback(_pending_username, str(data.get("uid", "")))


func _fetch_history_via_uid_lookup(username: String) -> void:
	"""Look up UID from presence_by_name (live) or usernames index, then fetch Firestore user doc."""
	var token := Auth.current_id_token
	if token == "" or username == "":
		_clear_history_rows()
		_add_history_placeholder("No match history yet")
		return

	# Try presence_by_name first — updated every time the user comes online (contains uid)
	var presence_url := "%s/presence_by_name/%s.json?auth=%s" % [RTDB_BASE, username.uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		var body_text := body.get_string_from_utf8()
		if code == 200 and body_text != "null" and body_text != "":
			var presence_data = JSON.parse_string(body_text)
			if typeof(presence_data) == TYPE_DICTIONARY and presence_data.has("uid"):
				var uid: String = str(presence_data["uid"])
				if uid != "":
					print("[ViewPlayerProfile] Got UID from presence_by_name for '%s': %s" % [username, uid])
					_fetch_history_from_firestore_user_doc(uid, username)
					return
		# Fall back to usernames index
		_fetch_history_via_usernames_index(username)
	)
	req.request(presence_url, [], HTTPClient.METHOD_GET)


func _fetch_history_via_usernames_index(username: String) -> void:
	var token := Auth.current_id_token
	var rtdb_url := "%s/usernames/%s.json?auth=%s" % [RTDB_BASE, username.to_lower().uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		var body_text := body.get_string_from_utf8()
		if code != 200 or body_text == "null" or body_text == "":
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		var uid = JSON.parse_string(body_text)
		if typeof(uid) != TYPE_STRING or uid == "":
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		print("[ViewPlayerProfile] Got UID from usernames index for '%s': %s" % [username, uid])
		_fetch_history_from_firestore_user_doc(uid, username)
	)
	req.request(rtdb_url, [], HTTPClient.METHOD_GET)


func _fetch_history_from_firestore_user_doc(uid: String, username: String) -> void:
	"""Step 2: Directly fetch users/{uid} from Firestore and read recent_matches."""
	var token := Auth.current_id_token
	var url := "%s/%s" % [firestore_base_url, uid]
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		if code != 200:
			print("[ViewPlayerProfile] Firestore user doc fetch failed HTTP %d" % code)
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("fields"):
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		var fields: Dictionary = parsed["fields"]
		if not fields.has("recent_matches"):
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
			return
		var decoded = _from_firestore_value(fields["recent_matches"])
		if typeof(decoded) == TYPE_ARRAY and decoded.size() > 0:
			_render_friend_match_history(decoded, username)
		else:
			_clear_history_rows()
			_add_history_placeholder("No match history yet")
	)
	req.request(url, headers, HTTPClient.METHOD_GET)


func _clear_history_rows() -> void:
	if not is_instance_valid(_match_history_vbox):
		return
	for child in _match_history_vbox.get_children():
		child.queue_free()


func _add_history_placeholder(text: String) -> void:
	if not is_instance_valid(_match_history_vbox):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1, 0.7))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_history_vbox.add_child(lbl)


func _render_friend_match_history(items: Array, viewed_username: String) -> void:
	_clear_history_rows()
	if items.is_empty():
		_add_history_placeholder("No matches yet")
		return
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var game_type: String = str(entry.get("game_type", ""))
		var game_label := "CODE BREAKER"
		match game_type:
			"code_breaker":
				game_label = "CODE BREAKER"
			"akashic", "akashic_tcg":
				game_label = "AKASHIC TCG"
			"defuse_trojan":
				game_label = "DEFUSE TROJAN"
			_:
				if game_type != "":
					game_label = game_type.to_upper().replace("_", " ")

		var title_suffix := ""
		var subtitle_text := ""
		var result_color := Color(0, 1, 1, 1)

		if game_type == "defuse_trojan":
			var wave: int = int(str(entry.get("wave_reached", 0)))
			var top_score: int = int(str(entry.get("top_score", 0)))
			var match_mode: String = str(entry.get("mode", "solo"))
			title_suffix = "Wave %d" % wave if wave > 0 else "Completed"
			subtitle_text = "%s — Score: %d" % [match_mode.capitalize(), top_score]
			result_color = Color(1, 0.8, 0, 1)
		else:
			var winner := str(entry.get("winner", ""))
			var loser  := str(entry.get("loser", ""))
			var result := str(entry.get("result", "")).to_upper()
			if winner != "" and loser != "":
				result = "WIN" if winner == viewed_username else ("LOSE" if loser == viewed_username else result)
			if result == "":
				result = "UNKNOWN"
			title_suffix = result
			result_color = Color(0.4, 1, 0.4, 1) if result == "WIN" else (Color(1, 0.4, 0.4, 1) if result == "LOSE" else Color(0, 1, 1, 1))
			var host     := str(entry.get("host", ""))
			var client   := str(entry.get("client", ""))
			var opponent := str(entry.get("opponent", ""))
			if opponent == "" and host != "" and client != "":
				opponent = client if host == viewed_username else host
			subtitle_text = "vs %s" % opponent if opponent != "" else "vs …"

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 42)

		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 2)

		var title_lbl := Label.new()
		title_lbl.text = "%s — %s" % [game_label, title_suffix]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.clip_text = true
		title_lbl.add_theme_color_override("font_color", result_color)
		title_lbl.add_theme_font_size_override("font_size", 13)
		left.add_child(title_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = subtitle_text
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_lbl.clip_text = true
		sub_lbl.add_theme_color_override("font_color", Color(0, 0.75, 1, 0.85))
		sub_lbl.add_theme_font_size_override("font_size", 11)
		left.add_child(sub_lbl)

		row.add_child(left)
		_match_history_vbox.add_child(row)


func _apply_avatar(avatar_path: String) -> void:
	if not is_instance_valid(profile_pic):
		return
	profile_pic.visible = true
	if avatar_path.begins_with("user://"):
		if FileAccess.file_exists(avatar_path):
			var img := Image.load_from_file(avatar_path)
			if img:
				img.resize(100, 100, Image.INTERPOLATE_LANCZOS)
				profile_pic.texture = ImageTexture.create_from_image(img)
	elif avatars.has(avatar_path):
		profile_pic.texture = avatars[avatar_path]
	else:
		var path := "res://asset/avatars/%s" % avatar_path
		if ResourceLoader.exists(path):
			profile_pic.texture = load(path) as Texture2D
func _get_rank_from_xp(xp: int) -> Dictionary:
	for rank in RANK_THRESHOLDS:
		if xp >= rank["min_xp"] and xp <= rank["max_xp"]:
			var progress: float = 0.0
			if rank["max_xp"] != 999999:
				var xp_in_rank: int = xp - int(rank["min_xp"])
				var xp_needed: int = int(rank["max_xp"]) - int(rank["min_xp"]) + 1
				progress = (float(xp_in_rank) / float(xp_needed)) * 100.0
			else:
				progress = 100.0  # Max rank
			
			return {
				"name": rank["name"],
				"icon": rank["icon"],
				"color": rank["color"],
				"min_xp": rank["min_xp"],
				"max_xp": rank["max_xp"],
				"current_xp": xp,
				"progress": progress,
				"xp_to_next": rank["max_xp"] - xp + 1 if rank["max_xp"] != 999999 else 0
			}
	
	# Fallback (should never happen)
	return RANK_THRESHOLDS[0]

# ✅ Display rank with icon and glow
func _display_rank(rank: Dictionary) -> void:
	var user_panel = get_node_or_null("ProfilePanel/UserPanel")
	if not user_panel:
		print("[ViewPlayerProfile] ⚠️ UserPanel not found!")
		return
	
	var icon_path = rank.get("icon", "")
	var rank_name = rank.get("name", "Iron")
	var color = rank.get("color", Color(0.5, 0.5, 0.5))
	
	print("[ViewPlayerProfile] Displaying rank: %s | Icon: %s" % [rank_name, icon_path])
	
	# Load rank icon
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var rank_texture = load(icon_path)
		if rank_texture:
			# Get from scene (created in _ready) or create as fallback
			if not is_instance_valid(rank_icon_rect):
				var user_panel2 = get_node_or_null("ProfilePanel/UserPanel")
				if user_panel2:
					rank_icon_rect = TextureRect.new()
					rank_icon_rect.name = "RankIconRect"
					rank_icon_rect.custom_minimum_size = Vector2(50, 50)
					rank_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					rank_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					user_panel2.add_child(rank_icon_rect)
			if is_instance_valid(rank_icon_rect):
				rank_icon_rect.texture = rank_texture
				print("[ViewPlayerProfile] ✅ Rank icon displayed")
	if rank_label:
		rank_label.text = rank_name
		rank_label.add_theme_color_override("font_color", color)
		print("[ViewPlayerProfile] ✅ Rank label updated: %s" % rank_name)

# ✅ Add glow effect to rank icon (same shader as landing.gd)
func _add_glow_to_rank_icon(icon: TextureRect, glow_color: Color) -> void:
	var shader_code = """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;
uniform float glow_size : hint_range(0.0, 0.1) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	if (tex.a > 0.5) {
		COLOR = tex;
	} else {
		float glow = 0.0;
		int samples = 16;
		
		for(int i = 0; i < samples; i++) {
			float angle = float(i) * 6.28318 / float(samples);
			vec2 offset = vec2(cos(angle), sin(angle)) * glow_size;
			vec4 sample_tex = texture(TEXTURE, UV + offset);
			
			if (sample_tex.a > 0.5) {
				glow += 1.0;
			}
		}
		
		glow = glow / float(samples);
		
		if (glow > 0.1) {
			COLOR = vec4(glow_color.rgb, glow * glow_strength * glow_color.a);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
}
"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("glow_strength", 1.5)
	material.set_shader_parameter("glow_size", 0.05)
	
	icon.material = material
	
	print("[ViewPlayerProfile] ✅ Glow effect applied to rank icon")

func _on_close_pressed() -> void:
	hide()
	queue_free()