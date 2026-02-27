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
	var dir := DirAccess.open("res://asset/avatars")
	if dir == null:
		push_error("⚠️ Avatar folder not found: res://asset/avatars")
		return

	avatars.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["png", "jpg", "jpeg", "webp"]:
			var tex := load("res://asset/avatars/" + file_name)
			if tex:
				avatars[file_name] = tex
		file_name = dir.get_next()
	dir.list_dir_end()

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
			# Firestore rules block reads of other users — fall back to public RTDB profile
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
	# runQuery returns an array; if the first element has no "document" key the user wasn't found
	if typeof(arr) != TYPE_ARRAY or arr.size() == 0 or not arr[0].has("document"):
		push_error("⚠️ Player not found. Raw response: %s" % body_text)
		if is_instance_valid(http):
			http.queue_free()
		return

	var player_data = arr[0]["document"]["fields"]
	print("[ViewPlayerProfile] Player data received: ", player_data.keys())
	
	# Update UI with player data
	if username_label and player_data.has("username"):
		username_label.text = player_data["username"]["stringValue"]
		print("[ViewPlayerProfile] Set username: ", username_label.text)
	
	if level_label and player_data.has("level"):
		level_label.text = str(player_data["level"]["integerValue"])
	
	if wins_label and player_data.has("wins"):
		wins_label.text = str(player_data["wins"]["integerValue"])
	
	if losses_label and player_data.has("losses"):
		losses_label.text = str(player_data["losses"]["integerValue"])
	
	if winrate_label and player_data.has("wins") and player_data.has("losses"):
		var wins = int(player_data["wins"]["integerValue"])
		var losses = int(player_data["losses"]["integerValue"])
		var total = wins + losses
		var wr = 0
		if total > 0:
			wr = int((float(wins) / float(total)) * 100)
		winrate_label.text = str(wr)
	
	if match_played_label and player_data.has("wins") and player_data.has("losses"):
		var total = int(player_data["wins"]["integerValue"]) + int(player_data["losses"]["integerValue"])
		match_played_label.text = str(total)
	
	# ✅ FIXED: Load and display avatar (handles both preset and custom avatars)
	if profile_pic and player_data.has("avatar"):
		_apply_avatar(player_data["avatar"]["stringValue"])
	
	# ✅ NEW: Load and display rank based on XP
	var xp_for_rank := 0
	if player_data.has("total_xp"):
		xp_for_rank = int(player_data["total_xp"]["integerValue"])
	_display_rank(_get_rank_from_xp(xp_for_rank))
	
	if http:
		http.queue_free()

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
	# RTDB stores flat values (not Firestore fields format)
	if username_label:
		username_label.text = str(data.get("username", _pending_username))

	if level_label:
		level_label.text = str(int(float(str(data.get("level", 1)))))

	var wins := int(data.get("wins", 0))
	var losses := int(data.get("losses", 0))
	var total := wins + losses

	if wins_label:
		wins_label.text = str(wins)
	if losses_label:
		losses_label.text = str(losses)
	if match_played_label:
		match_played_label.text = str(total)
	if winrate_label:
		var wr := 0
		if total > 0:
			wr = int((float(wins) / float(total)) * 100.0)
		winrate_label.text = str(wr)

	# Avatar
	var avatar_path: String = str(data.get("avatar", ""))
	if profile_pic and avatar_path != "":
		_apply_avatar(avatar_path)

	# Rank from XP
	var total_xp := int(float(str(data.get("total_xp", 0))))
	_display_rank(_get_rank_from_xp(total_xp))

	# Match history
	var history_raw = data.get("recent_matches", null)
	if history_raw != null:
		var history_items: Array = []
		if typeof(history_raw) == TYPE_ARRAY:
			history_items = history_raw
		elif typeof(history_raw) == TYPE_DICTIONARY:
			# Firebase RTDB returns arrays as {"0":{...},"1":{...}} objects
			var keys = history_raw.keys()
			keys.sort()
			for k in keys:
				if typeof(history_raw[k]) == TYPE_DICTIONARY:
					history_items.append(history_raw[k])
		_render_friend_match_history(history_items, str(data.get("username", _pending_username)))
	else:
		_clear_history_rows()
		_add_history_placeholder("No match history yet")


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
				_add_glow_to_rank_icon(rank_icon_rect, color)
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