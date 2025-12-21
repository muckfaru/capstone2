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

var avatars: Dictionary = {}
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"
var http: HTTPRequest

# ✅ MATCH TutorialManager's EXACT rank thresholds
const RANK_THRESHOLDS := [
	{"name": "Iron", "min_xp": 0, "max_xp": 199, "color": Color(0.5, 0.5, 0.5), "icon": "res://asset/icons/IRON.png"},
	{"name": "Bronze", "min_xp": 200, "max_xp": 399, "color": Color(0.8, 0.5, 0.2), "icon": "res://asset/icons/BRONZE.png"},
	{"name": "Silver", "min_xp": 400, "max_xp": 699, "color": Color(0.75, 0.75, 0.75), "icon": "res://asset/icons/SILVER.png"},
	{"name": "Gold", "min_xp": 700, "max_xp": 1099, "color": Color(1, 0.843, 0), "icon": "res://asset/icons/GOLD.png"},
	{"name": "Platinum", "min_xp": 1100, "max_xp": 1599, "color": Color(0.4, 0.8, 0.7), "icon": "res://asset/icons/PLATINUM.png"},
	{"name": "Diamond", "min_xp": 1600, "max_xp": 2299, "color": Color(0.5, 0.7, 1), "icon": "res://asset/icons/DIAMOND.png"},
	{"name": "Master", "min_xp": 2300, "max_xp": 3199, "color": Color(0.8, 0.3, 0.8), "icon": "res://asset/icons/MASTER.png"},
	{"name": "Grandmaster", "min_xp": 3200, "max_xp": 4499, "color": Color(1, 0.2, 0.2), "icon": "res://asset/icons/GRAND MASTER.png"},
	{"name": "Challenger", "min_xp": 4500, "max_xp": 999999, "color": Color(0, 1, 1), "icon": "res://asset/icons/CHALLENGER.png"}
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
	close_btn = get_node_or_null("ProfilePanel/MatchHistoyPanel/MatchHistoyHeader/CloseViewPlayerProfile")
	
	_load_avatars()
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("[ViewPlayerProfile] Warning: close_btn not found")
	
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
	var token = Auth.current_id_token
	if token == "":
		push_error("⚠️ Not authenticated")
		return

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
	http.request(query_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))

func _on_player_data_received(_result, response_code, _headers, body) -> void:
	if response_code != 200:
		push_error("⚠️ Failed to fetch player data")
		if http:
			http.queue_free()
		return

	var arr = JSON.parse_string(body.get_string_from_utf8())
	if typeof(arr) != TYPE_ARRAY or arr.size() == 0:
		push_error("⚠️ Player not found")
		if http:
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
		var avatar_path = player_data["avatar"]["stringValue"]
		
		# Check if it's a custom avatar (user:// path)
		if avatar_path.begins_with("user://"):
			if FileAccess.file_exists(avatar_path):
				var img = Image.load_from_file(avatar_path)
				if img:
					# Resize to match your ProfilePic size
					img.resize(100, 100, Image.INTERPOLATE_LANCZOS)
					
					var texture = ImageTexture.create_from_image(img)
					profile_pic.texture = texture
					
					# Ensure proper stretch mode
					profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					
					print("[ViewPlayerProfile] Custom avatar loaded: ", avatar_path)
				else:
					print("[ViewPlayerProfile] ⚠️ Failed to load custom avatar image")
			else:
				print("[ViewPlayerProfile] ⚠️ Custom avatar file not found: ", avatar_path)
		
		# Otherwise, it's a preset avatar
		elif avatars.has(avatar_path):
			profile_pic.texture = avatars[avatar_path]
			print("[ViewPlayerProfile] Preset avatar loaded: ", avatar_path)
		else:
			print("[ViewPlayerProfile] ⚠️ Avatar not found: ", avatar_path)
	
	# ✅ NEW: Load and display rank based on XP
	if rank_label and player_data.has("total_xp"):
		var total_xp = int(player_data["total_xp"]["integerValue"])
		var rank = _get_rank_from_xp(total_xp)
		
		_display_rank(rank)
		print("[ViewPlayerProfile] Rank displayed: %s (XP: %d)" % [rank["name"], total_xp])
	elif rank_label:
		# If no XP data, show default rank (Iron)
		var default_rank = _get_rank_from_xp(0)
		_display_rank(default_rank)
		print("[ViewPlayerProfile] No XP data, showing default rank: Iron")
	
	if http:
		http.queue_free()

# ✅ Calculate rank from XP (EXACT copy of TutorialManager logic)
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
	if not rank_label:
		print("[ViewPlayerProfile] ⚠️ rank_label is null!")
		return
	
	var user_panel = get_node_or_null("ProfilePanel/UserPanel")
	if not user_panel:
		print("[ViewPlayerProfile] ⚠️ UserPanel not found!")
		return
	
	var icon_path = rank.get("icon", "")
	var name = rank.get("name", "Iron")
	var color = rank.get("color", Color(0.5, 0.5, 0.5))
	
	print("[ViewPlayerProfile] Displaying rank: %s | Icon: %s" % [name, icon_path])
	
	# Load rank icon
	if icon_path != "" and FileAccess.file_exists(icon_path):
		var rank_texture = load(icon_path)
		if rank_texture:
			# Create or get rank icon rect
			rank_icon_rect = user_panel.get_node_or_null("RankIconRect")
			
			if not rank_icon_rect:
				rank_icon_rect = TextureRect.new()
				rank_icon_rect.name = "RankIconRect"
				rank_icon_rect.custom_minimum_size = Vector2(50, 50)
				rank_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				rank_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				user_panel.add_child(rank_icon_rect)
				print("[ViewPlayerProfile] ✅ Created RankIconRect")
			
			rank_icon_rect.texture = rank_texture
			
			# Add glow effect
			_add_glow_to_rank_icon(rank_icon_rect, color)
			
			# Position the icon (adjust these values to match your layout)
			var center_x = 33 + 90 - 25
			rank_icon_rect.position = Vector2(center_x, 235)
			
			# Position rank label below icon
			rank_label.text = name
			rank_label.position = Vector2(33, 290)
			rank_label.size = Vector2(180, 30)
			rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			print("[ViewPlayerProfile] ✅ Rank icon displayed")
		else:
			print("[ViewPlayerProfile] ⚠️ Failed to load rank texture: ", icon_path)
			# Fallback: text only
			rank_label.text = name
			rank_label.position = Vector2(33, 235)
			rank_label.size = Vector2(180, 30)
			rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		print("[ViewPlayerProfile] ⚠️ Rank icon not found: ", icon_path)
		# Text-only display
		rank_label.text = name
		rank_label.position = Vector2(33, 235)
		rank_label.size = Vector2(180, 60)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	rank_label.add_theme_color_override("font_color", color)
	print("[ViewPlayerProfile] ✅ Rank label updated: %s" % name)

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