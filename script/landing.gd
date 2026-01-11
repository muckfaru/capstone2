extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")
const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")

# === UI References ===
@onready var news_panel = $VideoStreamPlayer/HomePanel/NewsPanel
@onready var mission_button: Button
@onready var welcome_ui := $PokemonStyleWelcomeUI
@onready var username_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/usernameInput # Keep as Label!
@onready var level_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/levelInput
@onready var wins_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/winsInput
@onready var losses_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/losesInput
@onready var xp_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/xpInput
@onready var rank_label: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/rankLabel
@onready var match_played_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/MatchPlayedInput
@onready var status_label: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/StatusLabel
@onready var profile_pic: TextureRect = $VideoStreamPlayer/ProfilePanel/UserPanel/ProfilePic
@onready var change_btn: Button = $VideoStreamPlayer/ProfilePanel/UserPanel/ChangeAvatarButton
@onready var save_btn: Button = $VideoStreamPlayer/ProfilePanel/UserPanel/SaveProfile
@onready var avatar_picker: PopupPanel = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker
@onready var avatar_grid: GridContainer = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker/AvatarScroll/GridContainer
@onready var menu_panel: Control = $MenuPanel

# Match history (Profile)
@onready var match_history_panel: Panel = $VideoStreamPlayer/ProfilePanel/MatchHistoyPanel

var _match_history_scroll: ScrollContainer = null
var _match_history_vbox: VBoxContainer = null

@onready var inventory_panel: Panel = null
# Dynamic UI elements (created at runtime)
var file_dialog: FileDialog
var xp_progress: ProgressBar
const RANK_ICON_POSITION := Vector2(90, 265)
const RANK_ICON_SIZE := Vector2(60, 60)
const RANK_LABEL_POSITION := Vector2(23, 330)
# === Avatars & User Data ===
var original_username: String = ""
var original_avatar: String = ""
var edit_profile_popup: Panel = null
var has_unsaved_changes: bool = false
var confirmation_popup: Panel = null
var avatars: Dictionary = {}
var selected_avatar: String = ""
var last_avatar_change: int = 0
var avatar_cooldown: int = 2592000 # 30 days
var first_mission_active: bool = false
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"
var match_history_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents:runQuery"
var http: HTTPRequest
var ui_initialized: bool = false

# ✅ CRITICAL: Flag to prevent duplicate welcome bonus
var welcome_bonus_awarded: bool = false

# Starter reward state (cached from Firestore)
var _starter_reward_claimed_cache: bool = false

# Resume retry guard (prevents infinite loops if server is down)
var _code_breaker_resume_retries: int = 0
var _tgc_resume_retries: int = 0
var _resume_routed: bool = false

var current_video_index: int = 0

@export var background_video: String = "res://asset/background/video_background_2.ogv"
@export var transition_video: String = "res://asset/background/video_background_1.ogv"
@export var background_music: String = "res://asset/background/LETHAL DOSE.mp3"
@export var video_fade_duration: float = 0.8 # Faster fade looks more natural
@export var music_fade_duration: float = 2.0
var video_player: VideoStreamPlayer = null
var audio_player: AudioStreamPlayer = null
var fade_overlay: ColorRect = null
# === Lifecycle ===
func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	_setup_inventory_system()
	# ✅ CRITICAL: Force UI positions IMMEDIATELY before anything else
	call_deferred("_force_initial_ui_layout")
	_setup_video_and_music()
	_load_avatars()
	change_btn.pressed.connect(_on_change_avatar_pressed)

	# File dialog setup
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPG Images", "*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	file_dialog.file_selected.connect(_on_custom_avatar_selected)
	add_child(file_dialog)
	
	# Load user data
	_load_user_data_and_check_tutorial()
	_ensure_match_history_ui()
	_instantiate_chat_panel()
	_setup_inventory_system() # ✅ Initialize inventory system
	Auth.set_user_online()
	
	# Connect XP signals
	if not TutorialManager.xp_updated.is_connected(_on_xp_updated):
		TutorialManager.xp_updated.connect(_on_xp_updated)
	if not TutorialManager.rank_up.is_connected(_on_rank_up):
		TutorialManager.rank_up.connect(_on_rank_up)
	if not TutorialManager.data_loaded.is_connected(_update_xp_display):
		TutorialManager.data_loaded.connect(_update_xp_display)
	
	# Load TutorialManager data and update display
	TutorialManager.load_user_data()
	await get_tree().create_timer(0.5).timeout
	_update_xp_display()

	_setup_navigation()
	_setup_mission_system()
	call_deferred("_try_resume_code_breaker_session")
	call_deferred("_try_resume_akashic_tcg_session")

	# Pokemon Welcome UI setup
	if welcome_ui:
		print("[Landing] ✅ PokemonStyleWelcomeUI found in scene tree")
		welcome_ui.layer = 100
		welcome_ui.visible = false
		
		if welcome_ui.tutorial_completed.is_connected(_on_welcome_tutorial_completed):
			welcome_ui.tutorial_completed.disconnect(_on_welcome_tutorial_completed)
		
		welcome_ui.tutorial_completed.connect(_on_welcome_tutorial_completed, CONNECT_ONE_SHOT)
		print("[Landing] ✅ Connected tutorial_completed signal (ONE_SHOT)")
	else:
		push_error("[Landing] ❌ PokemonStyleWelcomeUI node not found!")
	
	# Check if returning from tutorial with rewards to show
	call_deferred("_check_tutorial_rewards")
	
	# === DEFUSE THE TROJAN GAME CARD CLICK HANDLER ===
	var defuse_trojan_card = get_node_or_null("VideoStreamPlayer/GameSelectPanel/allgame/DefuseTheTrojan")
	if defuse_trojan_card:
		defuse_trojan_card.gui_input.connect(_on_defuse_trojan_card_input)
		print("[Landing] ✅ DefuseTheTrojan card click handler connected")


# Replace these functions in your landing.gd script

func _force_initial_ui_layout() -> void:
	"""Force UI layout IMMEDIATELY when scene loads"""
	var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
	
	if not user_panel:
		return
	
	print("[Landing] ========== FORCING INITIAL UI LAYOUT ==========")
	
	# ✅ Profile picture - TOP position (80x80, ends at y=105)
	if profile_pic:
		profile_pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		profile_pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		profile_pic.custom_minimum_size = Vector2(80, 80)
		profile_pic.size = Vector2(80, 80)
		profile_pic.position = Vector2(30, 25) # Ends at x=110, y=105
		profile_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		profile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ✅ Username - next to profile pic
	if username_input:
		username_input.position = Vector2(120, 35)
		username_input.size = Vector2(120, 30)
		username_input.clip_text = true
	
	# ✅ Level labels - below username
	var level_label = user_panel.get_node_or_null("levelLabel")
	if level_label:
		level_label.position = Vector2(120, 65)
		level_label.size = Vector2(50, 23)
	
	if level_input:
		level_input.position = Vector2(170, 65)
		level_input.size = Vector2(50, 23)
	
	# ✅✅✅ STATS ROW - MOVED DOWN to y=115 (below profile pic at y=105)
	var wins_label = user_panel.get_node_or_null("winsLabel")
	if wins_label:
		wins_label.position = Vector2(29, 115) # Changed from 95 to 115
		wins_label.size = Vector2(30, 23)
	
	if wins_input:
		wins_input.position = Vector2(56, 115) # Changed from 95 to 115
		wins_input.size = Vector2(30, 23)
	
	var losses_label = user_panel.get_node_or_null("losesLabel")
	if losses_label:
		losses_label.position = Vector2(91, 115) # Changed from 95 to 115
		losses_label.size = Vector2(25, 23)
	
	if losses_input:
		losses_input.position = Vector2(114, 115) # Changed from 95 to 115
		losses_input.size = Vector2(30, 23)
	
	var winrate_label = user_panel.get_node_or_null("WinrateLabel")
	if winrate_label:
		winrate_label.position = Vector2(146, 115) # Changed from 95 to 115
		winrate_label.size = Vector2(40, 23)
	
	var winrate_input = user_panel.get_node_or_null("winrateInput")
	if winrate_input:
		winrate_input.position = Vector2(187, 115) # Changed from 95 to 115
		winrate_input.size = Vector2(40, 23)
	
	# ✅ Match played - also moved down
	var match_played_label = user_panel.get_node_or_null("MatchPlayedLabel")
	if match_played_label:
		match_played_label.position = Vector2(29, 141) # Changed from 121 to 141
		match_played_label.size = Vector2(130, 23)
	
	if match_played_input:
		match_played_input.position = Vector2(165, 141) # Changed from 121 to 141
		match_played_input.size = Vector2(50, 23)
	# ✅ Hide old elements
	if save_btn:
		save_btn.visible = false
	if status_label:
		status_label.visible = false
	if change_btn:
		change_btn.visible = false
	
	var username_label = user_panel.get_node_or_null("usernameLabel")
	if username_label:
		username_label.visible = false
	
	if xp_input:
		xp_input.visible = false
	var old_xp_label = user_panel.get_node_or_null("xpLabel")
	if old_xp_label:
		old_xp_label.visible = false
	
	# ✅ NOW create dynamic elements BELOW the stats
	if not ui_initialized:
		_initialize_profile_ui()
		ui_initialized = true
	
	print("[Landing] ✅ Initial UI layout forced")


func _ensure_match_history_ui() -> void:
	if not match_history_panel:
		return

	# Create ScrollContainer/VBox only if missing (keeps scene unchanged)
	_match_history_scroll = match_history_panel.get_node_or_null("ScrollContainer")
	if not _match_history_scroll:
		_match_history_scroll = ScrollContainer.new()
		_match_history_scroll.name = "ScrollContainer"
		_match_history_scroll.anchor_left = 0.0
		_match_history_scroll.anchor_top = 0.0
		_match_history_scroll.anchor_right = 1.0
		_match_history_scroll.anchor_bottom = 1.0
		# Leave space for the header (approx 70px)
		_match_history_scroll.offset_left = 8.0
		_match_history_scroll.offset_top = 72.0
		_match_history_scroll.offset_right = -8.0
		_match_history_scroll.offset_bottom = -8.0
		match_history_panel.add_child(_match_history_scroll)

	_match_history_vbox = _match_history_scroll.get_node_or_null("VBoxContainer")
	if not _match_history_vbox:
		_match_history_vbox = VBoxContainer.new()
		_match_history_vbox.name = "VBoxContainer"
		_match_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_match_history_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_match_history_vbox.add_theme_constant_override("separation", 8)
		_match_history_scroll.add_child(_match_history_vbox)

	# Placeholder
	_clear_match_history_rows()
	_add_match_history_placeholder("Loading…")


func _clear_match_history_rows() -> void:
	if not _match_history_vbox:
		return
	for child in _match_history_vbox.get_children():
		child.queue_free()


func _add_match_history_placeholder(text: String) -> void:
	if not _match_history_vbox:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_history_vbox.add_child(lbl)


func _load_match_history() -> void:
	if not match_history_panel or not _match_history_vbox:
		return
	if Auth.current_id_token == "":
		_clear_match_history_rows()
		_add_match_history_placeholder("Not logged in")
		return
	if Auth.current_local_id == "" and Auth.current_username == "":
		_clear_match_history_rows()
		_add_match_history_placeholder("No user")
		return

	_clear_match_history_rows()
	_add_match_history_placeholder("Loading…")

	# Prefer UID-based query if available (new schema). Fallback to username OR query (legacy schema).
	_query_match_history_by_uid(Auth.current_local_id)


func _query_match_history_by_uid(uid: String) -> void:
	if uid == "":
		# No UID available; fall back to legacy username query.
		_query_match_history_by_username(Auth.current_username)
		return

	var token = Auth.current_id_token
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	var query_body := {
		"structuredQuery": {
			"from": [ {"collectionId": "match_history"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "participant_ids"},
					"op": "ARRAY_CONTAINS",
					"value": {"stringValue": uid}
				}
			},
			# Avoid composite-index requirements by sorting client-side.
			"limit": 50
		}
	}

	var http_hist := HTTPRequest.new()
	add_child(http_hist)
	http_hist.request_completed.connect(func(_r, code, _h, body):
		http_hist.queue_free()
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[Landing] ⚠️ Match history UID query failed: %d\n%s" % [code, err_text])
			if code == 403:
				print("[Landing] 🔒 match_history denied by rules; loading users/%s.recent_matches instead" % Auth.current_local_id)
				_load_match_history_from_user_doc()
				return
			_query_match_history_by_username(Auth.current_username)
			return
		if code == 200:
			var items = _parse_match_history_query(body)
			if items.size() > 0:
				_render_match_history(items)
				return
		# Fallback to legacy schema by username
		_query_match_history_by_username(Auth.current_username)
	)

	http_hist.request(match_history_base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


func _query_match_history_by_username(username: String) -> void:
	if username == "":
		_clear_match_history_rows()
		_add_match_history_placeholder("No matches yet")
		return

	var token = Auth.current_id_token
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]

	# Legacy documents store host/client as usernames.
	var query_body := {
		"structuredQuery": {
			"from": [ {"collectionId": "match_history"}],
			"where": {
				"compositeFilter": {
					"op": "OR",
					"filters": [
						{
							"fieldFilter": {
								"field": {"fieldPath": "host"},
								"op": "EQUAL",
								"value": {"stringValue": username}
							}
						},
						{
							"fieldFilter": {
								"field": {"fieldPath": "client"},
								"op": "EQUAL",
								"value": {"stringValue": username}
							}
						}
					]
				}
			},
			# Avoid composite-index requirements by sorting client-side.
			"limit": 50
		}
	}

	var http_hist := HTTPRequest.new()
	add_child(http_hist)
	http_hist.request_completed.connect(func(_r, code, _h, body):
		http_hist.queue_free()
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[Landing] ⚠️ Match history username query failed: %d\n%s" % [code, err_text])
			if code == 403:
				print("[Landing] 🔒 match_history denied by rules; loading users/%s.recent_matches instead" % Auth.current_local_id)
				_load_match_history_from_user_doc()
				return
			_clear_match_history_rows()
			_add_match_history_placeholder("Failed to load history")
			return
		var items = _parse_match_history_query(body)
		_render_match_history(items)
	)

	http_hist.request(match_history_base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(query_body))


func _parse_match_history_query(body: PackedByteArray) -> Array:
	var text := body.get_string_from_utf8() if body.size() > 0 else ""
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		# Firestore returns {"error": {...}} on failure; log it for debugging.
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			print("[Landing] ⚠️ Match history query error:\n%s" % text)
		return []

	var items: Array = []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("document"):
			continue
		var doc = entry["document"]
		if typeof(doc) != TYPE_DICTIONARY or not doc.has("fields"):
			continue
		items.append(doc)

	items.sort_custom(func(a, b):
		var ta := _doc_timestamp_ms(a)
		var tb := _doc_timestamp_ms(b)
		return ta > tb
	)

	return items


func _doc_timestamp_ms(doc: Dictionary) -> int:
	var fields: Dictionary = doc.get("fields", {})
	var ts := _fs_int(fields, "timestamp", 0)
	if ts != 0:
		return ts
	# Older docs might not have timestamp; try ended_at/created_at.
	var ended := _fs_int(fields, "ended_at", 0)
	if ended != 0:
		return ended
	return _fs_int(fields, "created_at", 0)


func _render_match_history(items: Array) -> void:
	_clear_match_history_rows()

	if items.is_empty():
		_add_match_history_placeholder("No matches yet")
		return

	# Render each match as a compact row.
	for doc in items:
		var fields: Dictionary = doc.get("fields", {})
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 46)

		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 2)

		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_theme_constant_override("separation", 2)

		var game_type := _fs_string(fields, "game_type", "code_breaker")
		var game_label := "CODE BREAKER" if game_type == "code_breaker" else "AKASHIC TCG"

		var my_username := Auth.current_username
		var host := _fs_string(fields, "host", "")
		var client := _fs_string(fields, "client", "")
		var opponent := ""
		if fields.has("opponent"):
			opponent = _fs_string(fields, "opponent", "")
		if host != "" and client != "":
			opponent = client if host == my_username else host
		else:
			# New schema could have players map; best-effort
			opponent = _fs_string(fields, "opponent", "")

		var winner := _fs_string(fields, "winner", "")
		var loser := _fs_string(fields, "loser", "")
		var result := "UNKNOWN"
		if fields.has("result"):
			result = _fs_string(fields, "result", "UNKNOWN").to_upper()
		if winner != "" and loser != "" and my_username != "":
			result = "WIN" if winner == my_username else ("LOSE" if loser == my_username else "UNKNOWN")
		else:
			var key_res = "%s_result" % my_username
			var res_raw = _fs_string(fields, key_res, "")
			if res_raw != "":
				result = res_raw.to_upper()

		var duration := _fs_string(fields, "time_ended", "")
		var my_score := _fs_int(fields, "my_score", -1)
		var opp_score := _fs_int(fields, "opp_score", -1)
		if my_score < 0:
			my_score = _fs_int(fields, my_username, -1)
		if opp_score < 0:
			opp_score = _fs_int(fields, opponent, -1)

		var title := Label.new()
		title.text = "%s — %s" % [game_label, result]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		title.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		title.add_theme_font_size_override("font_size", 14)
		left.add_child(title)

		var subtitle := Label.new()
		if opponent != "":
			subtitle.text = "vs %s" % opponent
		else:
			subtitle.text = "vs …"
		subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subtitle.clip_text = true
		subtitle.add_theme_color_override("font_color", Color(0, 0.75, 1, 0.9))
		subtitle.add_theme_font_size_override("font_size", 12)
		left.add_child(subtitle)

		var stats := Label.new()
		var stats_parts: Array[String] = []
		if my_score >= 0 and opp_score >= 0:
			stats_parts.append("%d–%d" % [my_score, opp_score])
		if duration != "":
			stats_parts.append(duration)
		stats.text = "  ".join(stats_parts)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 0.85))
		stats.add_theme_font_size_override("font_size", 12)
		right.add_child(stats)

		row.add_child(left)
		row.add_child(right)
		_match_history_vbox.add_child(row)


func _load_match_history_from_user_doc() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		_clear_match_history_rows()
		_add_match_history_placeholder("Not logged in")
		return
	print("[Landing] 📜 Loading recent_matches from users/%s" % Auth.current_local_id)

	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var url = "%s/%s" % [firestore_base_url, uid]
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])

	var http_user := HTTPRequest.new()
	http_user.timeout = 10.0
	add_child(http_user)
	http_user.request_completed.connect(func(_r, code, _h, body):
		http_user.queue_free()
		print("[Landing] 📜 recent_matches user doc GET code: %d" % code)
		if code != 200:
			var err_text: String = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[Landing] ⚠️ Failed to load user doc recent_matches: %d\n%s" % [code, err_text])
			_clear_match_history_rows()
			_add_match_history_placeholder("Failed to load history")
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("fields"):
			_clear_match_history_rows()
			_add_match_history_placeholder("No matches yet")
			return

		var fields: Dictionary = data.get("fields", {})
		if not fields.has("recent_matches"):
			print("[Landing] 📜 users/%s has no recent_matches field" % uid)
			_clear_match_history_rows()
			_add_match_history_placeholder("No matches yet")
			return

		var rm = fields["recent_matches"]
		var rm_items: Array = []
		if typeof(rm) == TYPE_DICTIONARY and rm.has("arrayValue"):
			var av = rm.get("arrayValue", {})
			var values = av.get("values", [])
			if typeof(values) == TYPE_ARRAY:
				for v in values:
					# v is a Firestore value; wrap as a pseudo-document (doc.fields)
					if typeof(v) == TYPE_DICTIONARY and v.has("mapValue"):
						var mv = v.get("mapValue", {})
						var f = mv.get("fields", {})
						if typeof(f) == TYPE_DICTIONARY:
							rm_items.append({"fields": f})

		print("[Landing] 📜 recent_matches loaded: %d" % rm_items.size())
		_render_match_history(rm_items)
	)

	print("[Landing] 📜 recent_matches GET starting: %s" % url)
	var req_err: int = http_user.request(url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		print("[Landing] ⚠️ recent_matches request() failed immediately: %d" % req_err)
		http_user.queue_free()
		_clear_match_history_rows()
		_add_match_history_placeholder("Failed to load history")


func _fs_string(fields: Dictionary, key: String, default_value: String) -> String:
	if not fields.has(key):
		return default_value
	var v = fields[key]
	if typeof(v) != TYPE_DICTIONARY:
		return default_value
	if v.has("stringValue"):
		return str(v["stringValue"])
	if v.has("integerValue"):
		return str(v["integerValue"])
	return default_value


func _fs_int(fields: Dictionary, key: String, default_value: int) -> int:
	if not fields.has(key):
		return default_value
	var v = fields[key]
	if typeof(v) != TYPE_DICTIONARY:
		return default_value
	if v.has("integerValue"):
		return int(str(v["integerValue"]))
	if v.has("doubleValue"):
		return int(float(v["doubleValue"]))
	return default_value


func _initialize_profile_ui() -> void:
	"""Initialize all profile UI elements ONCE with proper spacing"""
	var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
	
	if not user_panel:
		push_error("[Landing] UserPanel not found!")
		return
	
	print("[Landing] ========== INITIALIZING PROFILE UI ==========")
	
	var edit_btn = user_panel.get_node_or_null("EditProfileButton")
	if not edit_btn:
		edit_btn = Button.new()
		edit_btn.name = "EditProfileButton"
		edit_btn.text = "Edit Profile"
		edit_btn.custom_minimum_size = Vector2(200, 38)
		edit_btn.position = Vector2(23, 175)
		edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var edit_icon = load("res://asset/icons/edit_icon.png")
		if edit_icon:
			var img = edit_icon.get_image()
			if img:
				img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
				edit_icon = ImageTexture.create_from_image(img)
			
			edit_btn.icon = edit_icon
			edit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			edit_btn.expand_icon = false
		
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0, 0.4, 0.5, 0.8)
		btn_style_normal.border_width_left = 2
		btn_style_normal.border_width_top = 2
		btn_style_normal.border_width_right = 2
		btn_style_normal.border_width_bottom = 2
		btn_style_normal.border_color = Color(0, 0.9, 1, 0.8)
		btn_style_normal.corner_radius_top_left = 6
		btn_style_normal.corner_radius_top_right = 6
		btn_style_normal.corner_radius_bottom_left = 6
		btn_style_normal.corner_radius_bottom_right = 6
		
		# ✅ UNEVEN MARGINS: Less left, more right = shifts content left
		btn_style_normal.content_margin_left = 20 # Reduced from 10
		btn_style_normal.content_margin_right = 65 # Increased from 10
		btn_style_normal.content_margin_top = 8
		btn_style_normal.content_margin_bottom = 8
		
		var btn_style_hover = btn_style_normal.duplicate()
		btn_style_hover.bg_color = Color(0, 0.6, 0.7, 1)
		btn_style_hover.shadow_color = Color(0, 1, 1, 0.5)
		btn_style_hover.shadow_size = 10
		
		edit_btn.add_theme_stylebox_override("normal", btn_style_normal)
		edit_btn.add_theme_stylebox_override("hover", btn_style_hover)
		edit_btn.add_theme_stylebox_override("pressed", btn_style_hover)
		edit_btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		edit_btn.add_theme_font_size_override("font_size", 15)
		
		edit_btn.add_theme_constant_override("h_separation", 20) # Space between icon and text
		edit_btn.add_theme_constant_override("icon_max_width", 24)
		
		edit_btn.pressed.connect(_open_edit_profile_popup)
		user_panel.add_child(edit_btn)
		print("[Landing] ✅ Edit Profile button created")
	else:
		edit_btn.position = Vector2(23, 175)
	
	_create_xp_progress_bar()
	print("[Landing] ✅ Profile UI initialized")


func _create_xp_progress_bar() -> void:
	"""Create and style the XP progress bar at fixed position"""
	var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
	
	var existing_bar = user_panel.get_node_or_null("XPProgressBar")
	if existing_bar:
		xp_progress = existing_bar
		xp_progress.position = Vector2(23, 225) # ✅ Changed from 205 to 225
		xp_progress.size = Vector2(200, 28)
		return
	
	xp_progress = ProgressBar.new()
	xp_progress.name = "XPProgressBar"
	xp_progress.position = Vector2(23, 225) # ✅ Changed from 205 to 225
	xp_progress.size = Vector2(200, 28)
	xp_progress.min_value = 0
	xp_progress.max_value = 1000
	xp_progress.value = 0
	xp_progress.show_percentage = false
	xp_progress.z_index = 10
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.corner_radius_top_left = 5
	style_bg.corner_radius_top_right = 5
	style_bg.corner_radius_bottom_left = 5
	style_bg.corner_radius_bottom_right = 5
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0, 0.9, 1, 1)
	style_fg.corner_radius_top_left = 5
	style_fg.corner_radius_top_right = 5
	style_fg.corner_radius_bottom_left = 5
	style_fg.corner_radius_bottom_right = 5
	
	xp_progress.add_theme_stylebox_override("background", style_bg)
	xp_progress.add_theme_stylebox_override("fill", style_fg)
	
	user_panel.add_child(xp_progress)
	
	var xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.size = Vector2(200, 28)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.text = "0 / 1000 XP"
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_progress.add_child(xp_label)
	
	print("[Landing] ✅ XP Progress Bar created at (23, 225)")

func _refresh_profile_ui_positions() -> void:
	"""Ensure all profile UI elements are in their correct positions"""
	var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
	if not user_panel:
		return
	
	print("[Landing] ========== REFRESHING UI POSITIONS ==========")
	
	var edit_btn = user_panel.get_node_or_null("EditProfileButton")
	if edit_btn:
		edit_btn.position = Vector2(23, 175)
		edit_btn.size = Vector2(200, 38)
	
	if xp_progress and is_instance_valid(xp_progress):
		xp_progress.position = Vector2(23, 225)
		xp_progress.size = Vector2(200, 28)
	
	# ✅ Use constant
	var rank_icon_rect = user_panel.get_node_or_null("RankIconRect")
	if rank_icon_rect:
		rank_icon_rect.position = RANK_ICON_POSITION
		rank_icon_rect.size = RANK_ICON_SIZE
	
	# ✅ Use constant
	if rank_label:
		rank_label.position = RANK_LABEL_POSITION
		rank_label.size = Vector2(200, 30)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	print("[Landing] ✅ Profile UI positions refreshed")
	

func _update_xp_display() -> void:
	"""Update XP display with fixed positions"""
	print("[Landing] ========== UPDATING XP DISPLAY ==========")
	
	var rank: Dictionary = TutorialManager.get_rank()
	var current_xp = rank.get("current_xp", TutorialManager.total_xp)
	var max_xp = rank.get("max_xp", 1000)
	
	if xp_progress and is_instance_valid(xp_progress):
		xp_progress.max_value = max_xp
		xp_progress.value = current_xp
		
		var label = xp_progress.get_node_or_null("XPLabel")
		if label:
			label.text = "%d / %d XP" % [current_xp, max_xp]
	
	if rank_label:
		var icon_path = rank.get("icon", "")
		var rank_name = rank.get("name", "Iron")
		var color = rank.get("color", Color(0.5, 0.5, 0.5))
		
		var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
		
		if icon_path.begins_with("res://"):
			var rank_texture = load(icon_path)
			if rank_texture:
				var rank_icon_rect = user_panel.get_node_or_null("RankIconRect")
				
				if not rank_icon_rect:
					rank_icon_rect = TextureRect.new()
					rank_icon_rect.name = "RankIconRect"
					rank_icon_rect.custom_minimum_size = RANK_ICON_SIZE
					rank_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					rank_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					user_panel.add_child(rank_icon_rect)
				
				rank_icon_rect.texture = rank_texture
				# ✅ Use constant
				rank_icon_rect.position = RANK_ICON_POSITION
				rank_icon_rect.size = RANK_ICON_SIZE
				_add_glow_to_rank_icon(rank_icon_rect, color)
				
				# ✅ Use constant
				rank_label.text = rank_name
				rank_label.position = RANK_LABEL_POSITION
				rank_label.size = Vector2(200, 30)
				rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				rank_label.text = rank_name
				rank_label.position = RANK_LABEL_POSITION
		else:
			rank_label.text = "%s\n%s" % [icon_path, rank_name]
			rank_label.position = RANK_LABEL_POSITION
		
		rank_label.add_theme_color_override("font_color", color)
		
func _exit_tree() -> void:
	"""Cleanup when leaving the scene"""
	# Reset the initialization flag for next time
	ui_initialized = false
	
	# Clean up any popups
	if edit_profile_popup and is_instance_valid(edit_profile_popup):
		edit_profile_popup.queue_free()
	if confirmation_popup and is_instance_valid(confirmation_popup):
		confirmation_popup.queue_free()

func _create_edit_profile_button() -> void:
	"""Create a neon-styled Edit Profile button"""
	var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
	
	# Hide or remove the old save button and status label
	if save_btn:
		save_btn.visible = false
	if status_label:
		status_label.visible = false
	
	# ✅ REMOVE "Select image" button/label if it exists
	var select_image_label = user_panel.get_node_or_null("SelectImageLabel")
	if select_image_label:
		select_image_label.queue_free()
	
	var select_image_btn = user_panel.get_node_or_null("SelectImageButton")
	if select_image_btn:
		select_image_btn.queue_free()
	
	# ✅ Also hide the ChangeAvatarButton if visible
	if change_btn:
		change_btn.visible = false
	
	# Create new Edit Profile button
	var edit_btn = Button.new()
	edit_btn.name = "EditProfileButton"
	edit_btn.text = "Edit Profile"
	edit_btn.custom_minimum_size = Vector2(180, 35)
	edit_btn.position = Vector2(33, 160) # ✅ Moved up to where "Select image" was
	edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var edit_icon = load("res://asset/icons/edit_icon.png") # Change path to your icon
	if edit_icon:
		edit_btn.icon = edit_icon
		edit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT # Icon on left side
		edit_btn.expand_icon = true # Keep icon crisp
	# Neon cyan style
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0, 0.4, 0.5, 0.8)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(0, 0.9, 1, 0.8)
	btn_style_normal.corner_radius_top_left = 6
	btn_style_normal.corner_radius_top_right = 6
	btn_style_normal.corner_radius_bottom_left = 6
	btn_style_normal.corner_radius_bottom_right = 6
	
	var btn_style_hover = btn_style_normal.duplicate()
	btn_style_hover.bg_color = Color(0, 0.6, 0.7, 1)
	btn_style_hover.shadow_color = Color(0, 1, 1, 0.5)
	btn_style_hover.shadow_size = 10
	
	edit_btn.add_theme_stylebox_override("normal", btn_style_normal)
	edit_btn.add_theme_stylebox_override("hover", btn_style_hover)
	edit_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	edit_btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	edit_btn.add_theme_font_size_override("font_size", 16)
	
	edit_btn.pressed.connect(_open_edit_profile_popup)
	
	user_panel.add_child(edit_btn)
	print("[Landing] ✅ Edit Profile button created")

func _open_edit_profile_popup() -> void:
	"""Show the Edit Profile popup panel"""
	if edit_profile_popup and is_instance_valid(edit_profile_popup):
		return # Already open
	
	# Store original values
	original_username = username_input.text
	original_avatar = selected_avatar
	
	# Create popup panel
	edit_profile_popup = Panel.new()
	edit_profile_popup.custom_minimum_size = Vector2(500, 600)
	edit_profile_popup.position = Vector2(
		(get_viewport().size.x - 500) / 2,
		(get_viewport().size.y - 600) / 2
	)
	edit_profile_popup.z_index = 1000
	
	# Neon style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.08, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0, 1, 1, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0, 1, 1, 0.6)
	panel_style.shadow_size = 25
	edit_profile_popup.add_theme_stylebox_override("panel", panel_style)
	
	# === TITLE ===
	var title = Label.new()
	title.text = "EDIT PROFILE"
	title.position = Vector2(0, 15)
	title.size = Vector2(500, 35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	title.add_theme_font_size_override("font_size", 24)
	edit_profile_popup.add_child(title)
	
	# === DIVIDER ===
	var divider1 = ColorRect.new()
	divider1.color = Color(0, 1, 1, 0.3)
	divider1.size = Vector2(460, 2)
	divider1.position = Vector2(20, 55)
	edit_profile_popup.add_child(divider1)
	
	# === PROFILE PICTURE SECTION ===
	var avatar_label = Label.new()
	avatar_label.text = "Profile Picture"
	avatar_label.position = Vector2(30, 70)
	avatar_label.size = Vector2(440, 25)
	avatar_label.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
	avatar_label.add_theme_font_size_override("font_size", 16)
	edit_profile_popup.add_child(avatar_label)
	
	# Current avatar preview
	var avatar_preview = TextureRect.new()
	avatar_preview.name = "AvatarPreview"
	avatar_preview.texture = profile_pic.texture
	avatar_preview.custom_minimum_size = Vector2(100, 100)
	avatar_preview.position = Vector2(200, 100)
	avatar_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	edit_profile_popup.add_child(avatar_preview)
	
	# Change Avatar Button
	var change_avatar_btn = Button.new()
	change_avatar_btn.text = "Change Avatar"
	change_avatar_btn.custom_minimum_size = Vector2(200, 40)
	change_avatar_btn.position = Vector2(150, 215)
	change_avatar_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var folder_icon = load("res://asset/icons/folder_icon.png")
	if folder_icon:
		var img = folder_icon.get_image()
		if img:
			img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
			folder_icon = ImageTexture.create_from_image(img)
		
		change_avatar_btn.icon = folder_icon
		# ✅ CENTER alignment
		change_avatar_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		change_avatar_btn.expand_icon = false

	
	var avatar_btn_style = StyleBoxFlat.new()
	avatar_btn_style.bg_color = Color(0.1, 0.2, 0.3, 0.9)
	avatar_btn_style.border_width_left = 2
	avatar_btn_style.border_width_right = 2
	avatar_btn_style.border_width_top = 2
	avatar_btn_style.border_width_bottom = 2
	avatar_btn_style.border_color = Color(0, 0.9, 1, 0.6)
	avatar_btn_style.corner_radius_top_left = 5
	avatar_btn_style.corner_radius_top_right = 5
	avatar_btn_style.corner_radius_bottom_left = 5
	avatar_btn_style.corner_radius_bottom_right = 5
	avatar_btn_style.content_margin_left = 10
	avatar_btn_style.content_margin_right = 10
	avatar_btn_style.content_margin_top = 10
	avatar_btn_style.content_margin_bottom = 10

	var avatar_btn_hover = avatar_btn_style.duplicate()
	avatar_btn_hover.border_color = Color(0, 1, 1, 1)
	avatar_btn_hover.shadow_color = Color(0, 1, 1, 0.3)
	avatar_btn_hover.shadow_size = 5

	change_avatar_btn.add_theme_stylebox_override("normal", avatar_btn_style)
	change_avatar_btn.add_theme_stylebox_override("hover", avatar_btn_hover)
	change_avatar_btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	change_avatar_btn.add_theme_font_size_override("font_size", 14)
	# ✅ Minimal gap
	change_avatar_btn.add_theme_constant_override("h_separation", 4)
	change_avatar_btn.add_theme_constant_override("icon_max_width", 24)

	change_avatar_btn.pressed.connect(func():
		file_dialog.popup_centered(Vector2(700, 500))
	)
	edit_profile_popup.add_child(change_avatar_btn)
	
	# Preset avatars button
	var preset_btn = Button.new()
	preset_btn.text = "Preset Avatars"
	preset_btn.custom_minimum_size = Vector2(200, 40)
	preset_btn.position = Vector2(150, 265)
	preset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var preset_icon = load("res://asset/icons/palette_icon.png")
	if preset_icon:
		var img = preset_icon.get_image()
		if img:
			img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
			preset_icon = ImageTexture.create_from_image(img)
		
		preset_btn.icon = preset_icon
		# ✅ CENTER alignment
		preset_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		preset_btn.expand_icon = false

	preset_btn.add_theme_stylebox_override("normal", avatar_btn_style)
	preset_btn.add_theme_stylebox_override("hover", avatar_btn_hover)
	preset_btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	preset_btn.add_theme_font_size_override("font_size", 14)
	# ✅ Minimal gap
	preset_btn.add_theme_constant_override("h_separation", 4)
	preset_btn.add_theme_constant_override("icon_max_width", 24)

	preset_btn.pressed.connect(func():
		avatar_picker.popup_centered()
	)
	edit_profile_popup.add_child(preset_btn)
	
	# === DIVIDER ===
	var divider2 = ColorRect.new()
	divider2.color = Color(0, 1, 1, 0.3)
	divider2.size = Vector2(460, 2)
	divider2.position = Vector2(20, 325)
	edit_profile_popup.add_child(divider2)
	
	# === USERNAME SECTION ===
	var username_label = Label.new()
	username_label.text = "Username"
	username_label.position = Vector2(30, 345)
	username_label.size = Vector2(440, 25)
	username_label.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
	username_label.add_theme_font_size_override("font_size", 16)
	edit_profile_popup.add_child(username_label)
	
	# Username input field
	var username_edit = LineEdit.new()
	username_edit.name = "UsernameEdit"
	username_edit.text = username_input.text
	username_edit.placeholder_text = "Enter new username"
	username_edit.max_length = 20
	username_edit.position = Vector2(30, 375)
	username_edit.size = Vector2(440, 45)
	
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.05, 0.1, 0.15, 0.9)
	input_style.border_width_left = 2
	input_style.border_width_right = 2
	input_style.border_width_top = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0, 0.9, 1, 0.6)
	input_style.corner_radius_top_left = 5
	input_style.corner_radius_top_right = 5
	input_style.corner_radius_bottom_left = 5
	input_style.corner_radius_bottom_right = 5
	
	var input_focus = input_style.duplicate()
	input_focus.border_color = Color(0, 1, 1, 1)
	input_focus.shadow_color = Color(0, 1, 1, 0.4)
	input_focus.shadow_size = 8
	
	username_edit.add_theme_stylebox_override("normal", input_style)
	username_edit.add_theme_stylebox_override("focus", input_focus)
	username_edit.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	username_edit.add_theme_color_override("font_placeholder_color", Color(0, 0.5, 0.6, 0.5))
	username_edit.add_theme_font_size_override("font_size", 18)
	
	edit_profile_popup.add_child(username_edit)
	
	# Character count
	var char_count = Label.new()
	char_count.name = "CharCount"
	char_count.text = "%d / 20" % username_edit.text.length()
	char_count.position = Vector2(30, 425)
	char_count.size = Vector2(440, 20)
	char_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	char_count.add_theme_color_override("font_color", Color(0, 0.7, 0.8, 0.8))
	char_count.add_theme_font_size_override("font_size", 12)
	edit_profile_popup.add_child(char_count)
	
	username_edit.text_changed.connect(func(new_text: String):
		char_count.text = "%d / 20" % new_text.length()
		# Change color if too long
		if new_text.length() >= 18:
			char_count.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
		else:
			char_count.add_theme_color_override("font_color", Color(0, 0.7, 0.8, 0.8))
	)
	
	# Validation hint
	var hint_label = Label.new()
	hint_label.text = "Username must be 3-20 characters"
	hint_label.position = Vector2(30, 450)
	hint_label.size = Vector2(440, 25)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.7))
	hint_label.add_theme_font_size_override("font_size", 12)
	edit_profile_popup.add_child(hint_label)
	
	# === DIVIDER ===
	var divider3 = ColorRect.new()
	divider3.color = Color(0, 1, 1, 0.3)
	divider3.size = Vector2(460, 2)
	divider3.position = Vector2(20, 490)
	edit_profile_popup.add_child(divider3)
	
	# === BUTTONS ===
	# SAVE Button
	var save_button = Button.new()
	save_button.text = "✓ SAVE CHANGES"
	save_button.custom_minimum_size = Vector2(210, 45)
	save_button.position = Vector2(35, 520)
	save_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var save_style_normal = StyleBoxFlat.new()
	save_style_normal.bg_color = Color(0, 0.5, 0.6, 0.9)
	save_style_normal.border_width_left = 2
	save_style_normal.border_width_top = 2
	save_style_normal.border_width_right = 2
	save_style_normal.border_width_bottom = 2
	save_style_normal.border_color = Color(0, 1, 1, 0.9)
	save_style_normal.corner_radius_top_left = 8
	save_style_normal.corner_radius_top_right = 8
	save_style_normal.corner_radius_bottom_left = 8
	save_style_normal.corner_radius_bottom_right = 8
	
	var save_style_hover = save_style_normal.duplicate()
	save_style_hover.bg_color = Color(0, 0.7, 0.8, 1)
	save_style_hover.shadow_color = Color(0, 1, 1, 0.6)
	save_style_hover.shadow_size = 12
	
	save_button.add_theme_stylebox_override("normal", save_style_normal)
	save_button.add_theme_stylebox_override("hover", save_style_hover)
	save_button.add_theme_stylebox_override("pressed", save_style_hover)
	save_button.add_theme_color_override("font_color", Color.WHITE)
	save_button.add_theme_font_size_override("font_size", 16)
	
	save_button.pressed.connect(func():
		var new_username = username_edit.text.strip_edges()
		
		# Validate username
		if new_username.length() < 3:
			_show_error_message("Username must be at least 3 characters!")
			return
		if new_username.length() > 20:
			_show_error_message("Username must be 20 characters or less!")
			return
		
		# Update values
		username_input.text = new_username
		Auth.current_username = new_username
		
		# Save to Firestore
		_save_profile_changes()
		_close_edit_profile_popup()
	)
	edit_profile_popup.add_child(save_button)
	
	# CANCEL Button
	var cancel_button = Button.new()
	cancel_button.text = "✕ CANCEL"
	cancel_button.custom_minimum_size = Vector2(210, 45)
	cancel_button.position = Vector2(255, 520)
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var cancel_style_normal = StyleBoxFlat.new()
	cancel_style_normal.bg_color = Color(0.4, 0, 0, 0.9)
	cancel_style_normal.border_width_left = 2
	cancel_style_normal.border_width_top = 2
	cancel_style_normal.border_width_right = 2
	cancel_style_normal.border_width_bottom = 2
	cancel_style_normal.border_color = Color(1, 0, 0, 0.8)
	cancel_style_normal.corner_radius_top_left = 8
	cancel_style_normal.corner_radius_top_right = 8
	cancel_style_normal.corner_radius_bottom_left = 8
	cancel_style_normal.corner_radius_bottom_right = 8
	
	var cancel_style_hover = cancel_style_normal.duplicate()
	cancel_style_hover.bg_color = Color(0.6, 0, 0, 1)
	cancel_style_hover.shadow_color = Color(1, 0, 0, 0.5)
	cancel_style_hover.shadow_size = 12
	
	cancel_button.add_theme_stylebox_override("normal", cancel_style_normal)
	cancel_button.add_theme_stylebox_override("hover", cancel_style_hover)
	cancel_button.add_theme_stylebox_override("pressed", cancel_style_hover)
	cancel_button.add_theme_color_override("font_color", Color.WHITE)
	cancel_button.add_theme_font_size_override("font_size", 16)
	
	cancel_button.pressed.connect(func():
		# Restore original values
		username_input.text = original_username
		selected_avatar = original_avatar
		
		# Restore avatar
		if selected_avatar.begins_with("user://") and FileAccess.file_exists(selected_avatar):
			var img = Image.load_from_file(selected_avatar)
			if img:
				img.resize(100, 100, Image.INTERPOLATE_LANCZOS)
				profile_pic.texture = ImageTexture.create_from_image(img)
		elif avatars.has(selected_avatar):
			profile_pic.texture = avatars[selected_avatar]
		
		_close_edit_profile_popup()
	)
	edit_profile_popup.add_child(cancel_button)
	
	add_child(edit_profile_popup)
	
	# Animate entrance
	edit_profile_popup.modulate.a = 0
	edit_profile_popup.scale = Vector2(0.85, 0.85)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(edit_profile_popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(edit_profile_popup, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Focus on username input
	await get_tree().create_timer(0.1).timeout
	username_edit.grab_focus()

func _close_edit_profile_popup() -> void:
	"""Close the edit profile popup with animation"""
	if not edit_profile_popup or not is_instance_valid(edit_profile_popup):
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(edit_profile_popup, "modulate:a", 0.0, 0.2)
	tween.tween_property(edit_profile_popup, "scale", Vector2(0.85, 0.85), 0.2)
	await tween.finished
	edit_profile_popup.queue_free()
	edit_profile_popup = null

func _show_error_message(message: String) -> void:
	"""Show temporary error message in the popup"""
	if not edit_profile_popup:
		return
	
	var error_label = edit_profile_popup.get_node_or_null("ErrorMessage")
	if not error_label:
		error_label = Label.new()
		error_label.name = "ErrorMessage"
		error_label.position = Vector2(30, 475)
		error_label.size = Vector2(440, 25)
		error_label.add_theme_font_size_override("font_size", 13)
		edit_profile_popup.add_child(error_label)
	
	error_label.text = "⚠ " + message
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	error_label.visible = true
	
	# Fade out after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if error_label and is_instance_valid(error_label):
		var fade = create_tween()
		fade.tween_property(error_label, "modulate:a", 0.0, 0.5)
		await fade.finished
		error_label.visible = false

func _save_profile_changes() -> void:
	"""Save profile changes to Firestore"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in")
		return
	
	last_avatar_change = int(Time.get_unix_time_from_system())
	
	var url = "%s/%s?updateMask.fieldPaths=username&updateMask.fieldPaths=avatar&updateMask.fieldPaths=last_avatar_change" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"username": {"stringValue": username_input.text},
			"avatar": {"stringValue": selected_avatar},
			"last_avatar_change": {"integerValue": str(last_avatar_change)}
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http_save := HTTPRequest.new()
	add_child(http_save)
	
	http_save.request_completed.connect(func(_r, code, _h, response_body):
		http_save.queue_free()
		if code == 200:
			print("[Landing] ✅ Profile saved successfully!")
			# Update originals
			original_username = username_input.text
			original_avatar = selected_avatar
			# Show success notification
			_show_success_notification()
		else:
			var msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "Unknown error"
			push_error("[Landing] Failed to save profile: %s" % msg)
			_show_error_message("Failed to save profile. Please try again.")
	)
	
	http_save.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _show_success_notification() -> void:
	"""Show a quick success notification"""
	var notif_panel = Panel.new()
	notif_panel.custom_minimum_size = Vector2(300, 60)
	notif_panel.position = Vector2(
		(get_viewport().size.x - 300) / 2,
		50
	)
	notif_panel.z_index = 2000
	
	var notif_style = StyleBoxFlat.new()
	notif_style.bg_color = Color(0, 0.6, 0.7, 0.95)
	notif_style.border_width_left = 2
	notif_style.border_width_top = 2
	notif_style.border_width_right = 2
	notif_style.border_width_bottom = 2
	notif_style.border_color = Color(0, 1, 1, 1)
	notif_style.corner_radius_top_left = 8
	notif_style.corner_radius_top_right = 8
	notif_style.corner_radius_bottom_left = 8
	notif_style.corner_radius_bottom_right = 8
	notif_style.shadow_color = Color(0, 1, 1, 0.6)
	notif_style.shadow_size = 15
	notif_panel.add_theme_stylebox_override("panel", notif_style)
	
	var notif_label = Label.new()
	notif_label.text = "✓ Profile Updated Successfully!"
	notif_label.size = Vector2(300, 60)
	notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notif_label.add_theme_color_override("font_color", Color.WHITE)
	notif_label.add_theme_font_size_override("font_size", 16)
	notif_panel.add_child(notif_label)
	
	add_child(notif_panel)
	
	# Animate in
	notif_panel.modulate.a = 0
	notif_panel.position.y -= 20
	var tween_in = create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(notif_panel, "modulate:a", 1.0, 0.3)
	tween_in.tween_property(notif_panel, "position:y", 50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait and fade out
	await get_tree().create_timer(2.0).timeout
	var tween_out = create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(notif_panel, "modulate:a", 0.0, 0.5)
	tween_out.tween_property(notif_panel, "position:y", 30, 0.5)
	await tween_out.finished
	notif_panel.queue_free()


func _setup_username_editing() -> void:
	"""Convert username label to editable LineEdit"""
	if not username_input:
		return
	
	# Get parent and position
	var parent = username_input.get_parent()
	var pos = username_input.position
	var username_size = username_input.size
	
	# Create LineEdit replacement
	var username_edit = LineEdit.new()
	username_edit.name = "usernameInput"
	username_edit.text = username_input.text
	username_edit.position = pos
	username_edit.size = username_size
	username_edit.max_length = 20
	username_edit.placeholder_text = "Enter username"
	
	# Style the LineEdit with neon theme
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.05, 0.1, 0.15, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0, 0.9, 1, 0.6)
	style_normal.corner_radius_top_left = 5
	style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_left = 5
	style_normal.corner_radius_bottom_right = 5
	
	var style_focus = style_normal.duplicate()
	style_focus.border_color = Color(0, 1, 1, 1)
	style_focus.shadow_color = Color(0, 1, 1, 0.3)
	style_focus.shadow_size = 5
	
	username_edit.add_theme_stylebox_override("normal", style_normal)
	username_edit.add_theme_stylebox_override("focus", style_focus)
	username_edit.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	username_edit.add_theme_color_override("font_placeholder_color", Color(0, 0.5, 0.6, 0.5))
	
	# Connect signal to detect changes
	username_edit.text_changed.connect(_on_username_changed)
	
	# Replace the old label
	parent.remove_child(username_input)
	username_input.queue_free()
	parent.add_child(username_edit)
	username_input = username_edit

func _on_username_changed(_new_text: String) -> void:
	"""Called when username is edited"""
	_check_for_changes()


func _on_custom_avatar_selected(path: String) -> void:
	"""Load custom avatar with fixed size"""
	var img = Image.load_from_file(path)
	if img:
		# ✅ IMPORTANT: Resize to fixed size
		img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
		var texture = ImageTexture.create_from_image(img)
		
		profile_pic.texture = texture
		
		# ✅ Re-enforce size constraints
		profile_pic.custom_minimum_size = Vector2(80, 80)
		profile_pic.size = Vector2(80, 80)
		profile_pic.position = Vector2(30, 25)
		profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var user_avatar_path = "user://custom_avatar_%s.png" % Auth.current_local_id
		img.save_png(user_avatar_path)
		selected_avatar = user_avatar_path
		
		# Update preview in edit popup if open
		if edit_profile_popup and is_instance_valid(edit_profile_popup):
			var preview = edit_profile_popup.get_node_or_null("AvatarPreview")
			if preview:
				preview.texture = texture
		
		print("[Landing] ✅ Custom avatar loaded with fixed size 80x80")
	else:
		_show_error_message("Failed to load image")

func _on_avatar_selected(file_name: String) -> void:
	"""Load preset avatar with fixed size"""
	if avatars.has(file_name):
		profile_pic.texture = avatars[file_name]
		selected_avatar = file_name
		avatar_picker.hide()
		
		# ✅ Re-enforce size constraints
		profile_pic.custom_minimum_size = Vector2(80, 80)
		profile_pic.size = Vector2(80, 80)
		profile_pic.position = Vector2(30, 25)
		profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Update preview in edit popup if open
		if edit_profile_popup and is_instance_valid(edit_profile_popup):
			var preview = edit_profile_popup.get_node_or_null("AvatarPreview")
			if preview:
				preview.texture = avatars[file_name]
		
		print("[Landing] ✅ Preset avatar loaded with fixed size 80x80")

func _check_for_changes() -> void:
	"""Check if profile has unsaved changes"""
	var username_changed = (username_input.text != original_username)
	var avatar_changed = (selected_avatar != original_avatar)
	
	has_unsaved_changes = username_changed or avatar_changed
	
	if has_unsaved_changes:
		_show_save_confirmation_popup()
func _show_save_confirmation_popup() -> void:
	"""Show neon-styled confirmation popup"""
	if confirmation_popup and is_instance_valid(confirmation_popup):
		return # Popup already showing
	
	# Create popup panel
	confirmation_popup = Panel.new()
	confirmation_popup.custom_minimum_size = Vector2(400, 200)
	confirmation_popup.position = Vector2(
		(get_viewport().size.x - 400) / 2,
		(get_viewport().size.y - 200) / 2
	)
	confirmation_popup.z_index = 1000
	
	# Neon style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.08, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0, 1, 1, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0, 1, 1, 0.5)
	panel_style.shadow_size = 20
	confirmation_popup.add_theme_stylebox_override("panel", panel_style)
	
	# Title
	var title = Label.new()
	title.text = "⚠ UNSAVED CHANGES"
	title.position = Vector2(0, 15)
	title.size = Vector2(400, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	title.add_theme_font_size_override("font_size", 20)
	confirmation_popup.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "Do you want to save your profile changes?"
	message.position = Vector2(20, 60)
	message.size = Vector2(360, 40)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	message.add_theme_font_size_override("font_size", 14)
	confirmation_popup.add_child(message)
	
	# Changes list
	var changes_text = ""
	if username_input.text != original_username:
		changes_text += "• Username: %s → %s\n" % [original_username, username_input.text]
	if selected_avatar != original_avatar:
		changes_text += "• Avatar changed\n"
	
	var changes_label = Label.new()
	changes_label.text = changes_text
	changes_label.position = Vector2(30, 100)
	changes_label.size = Vector2(340, 50)
	changes_label.add_theme_color_override("font_color", Color(0, 0.8, 1, 0.8))
	changes_label.add_theme_font_size_override("font_size", 12)
	confirmation_popup.add_child(changes_label)
	
	# YES Button
	var yes_btn = Button.new()
	yes_btn.text = "YES - SAVE"
	yes_btn.custom_minimum_size = Vector2(160, 40)
	yes_btn.position = Vector2(30, 145)
	yes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0, 0.5, 0.6, 0.8)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(0, 1, 1, 0.9)
	btn_style_normal.corner_radius_top_left = 8
	btn_style_normal.corner_radius_top_right = 8
	btn_style_normal.corner_radius_bottom_left = 8
	btn_style_normal.corner_radius_bottom_right = 8
	
	var btn_style_hover = btn_style_normal.duplicate()
	btn_style_hover.bg_color = Color(0, 0.7, 0.8, 1)
	btn_style_hover.shadow_color = Color(0, 1, 1, 0.4)
	btn_style_hover.shadow_size = 8
	
	yes_btn.add_theme_stylebox_override("normal", btn_style_normal)
	yes_btn.add_theme_stylebox_override("hover", btn_style_hover)
	yes_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	yes_btn.add_theme_color_override("font_color", Color.WHITE)
	yes_btn.add_theme_font_size_override("font_size", 14)
	
	yes_btn.pressed.connect(func():
		_confirm_save_profile()
		_close_confirmation_popup()
	)
	confirmation_popup.add_child(yes_btn)
	
	# NO Button
	var no_btn = Button.new()
	no_btn.text = "NO - DISCARD"
	no_btn.custom_minimum_size = Vector2(160, 40)
	no_btn.position = Vector2(210, 145)
	no_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var no_style_normal = StyleBoxFlat.new()
	no_style_normal.bg_color = Color(0.5, 0, 0, 0.8)
	no_style_normal.border_width_left = 2
	no_style_normal.border_width_top = 2
	no_style_normal.border_width_right = 2
	no_style_normal.border_width_bottom = 2
	no_style_normal.border_color = Color(1, 0, 0, 0.9)
	no_style_normal.corner_radius_top_left = 8
	no_style_normal.corner_radius_top_right = 8
	no_style_normal.corner_radius_bottom_left = 8
	no_style_normal.corner_radius_bottom_right = 8
	
	var no_style_hover = no_style_normal.duplicate()
	no_style_hover.bg_color = Color(0.7, 0, 0, 1)
	no_style_hover.shadow_color = Color(1, 0, 0, 0.4)
	no_style_hover.shadow_size = 8
	
	no_btn.add_theme_stylebox_override("normal", no_style_normal)
	no_btn.add_theme_stylebox_override("hover", no_style_hover)
	no_btn.add_theme_stylebox_override("pressed", no_style_hover)
	no_btn.add_theme_color_override("font_color", Color.WHITE)
	no_btn.add_theme_font_size_override("font_size", 14)
	
	no_btn.pressed.connect(func():
		_discard_changes()
		_close_confirmation_popup()
	)
	confirmation_popup.add_child(no_btn)
	
	add_child(confirmation_popup)
	
	# Animate popup entrance
	confirmation_popup.modulate.a = 0
	confirmation_popup.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(confirmation_popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(confirmation_popup, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_confirmation_popup() -> void:
	"""Close the confirmation popup with animation"""
	if not confirmation_popup or not is_instance_valid(confirmation_popup):
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(confirmation_popup, "modulate:a", 0.0, 0.2)
	tween.tween_property(confirmation_popup, "scale", Vector2(0.8, 0.8), 0.2)
	await tween.finished
	confirmation_popup.queue_free()
	confirmation_popup = null

func _confirm_save_profile() -> void:
	"""Save profile changes"""
	has_unsaved_changes = false
	_on_save_profile_pressed() # Call your existing save function

func _discard_changes() -> void:
	"""Discard changes and restore original values"""
	has_unsaved_changes = false
	username_input.text = original_username
	selected_avatar = original_avatar
	
	# Restore avatar texture
	if selected_avatar.begins_with("user://"):
		if FileAccess.file_exists(selected_avatar):
			var img = Image.load_from_file(selected_avatar)
			if img:
				img.resize(100, 100, Image.INTERPOLATE_LANCZOS)
				var texture = ImageTexture.create_from_image(img)
				profile_pic.texture = texture
	elif avatars.has(selected_avatar):
		profile_pic.texture = avatars[selected_avatar]
		

func _add_glow_to_rank_icon(icon: TextureRect, glow_color: Color) -> void:
	"""Add glowing effect to rank icon using improved shader"""
	
	var shader_code = """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;
uniform float glow_size : hint_range(0.0, 0.1) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Only add glow if the original pixel has transparency
	if (tex.a > 0.5) {
		// Just render the original texture
		COLOR = tex;
	} else {
		// Sample neighboring pixels for glow effect
		float glow = 0.0;
		int samples = 16;
		
		for(int i = 0; i < samples; i++) {
			float angle = float(i) * 6.28318 / float(samples);
			vec2 offset = vec2(cos(angle), sin(angle)) * glow_size;
			
			// Sample texture at offset position
			vec4 sample_tex = texture(TEXTURE, UV + offset);
			
			// Only accumulate glow from opaque parts of the texture
			if (sample_tex.a > 0.5) {
				glow += 1.0;
			}
		}
		
		// Normalize glow
		glow = glow / float(samples);
		
		// Apply glow only if there's something nearby
		if (glow > 0.1) {
			COLOR = vec4(glow_color.rgb, glow * glow_strength * glow_color.a);
		} else {
			// Fully transparent
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
}
"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("glow_color", glow_color)
	shader_material.set_shader_parameter("glow_strength", 1.5) # Reduced for subtlety
	shader_material.set_shader_parameter("glow_size", 0.05) # Reduced for tighter glow
	
	icon.material = shader_material
	
	print("[Landing] ✅ Glow effect applied to rank icon with color:", glow_color)


func _try_resume_code_breaker_session() -> void:
	if _resume_routed:
		return
	# Only resume for logged-in users (Auth can be set a frame later)
	for _i in range(10):
		if Auth and Auth.current_local_id != "":
			break
		await get_tree().create_timer(0.25).timeout
	if not Auth or Auth.current_local_id == "":
		return

	var session := _SessionStore.load_session()
	if session.is_empty():
		return

	# Ignore stale sessions from other accounts
	var session_player_id := str(session.get("player_id", ""))
	if session_player_id != "" and session_player_id != "unknown" and session_player_id != Auth.current_local_id:
		_SessionStore.clear_session()
		return

	var room_id := str(session.get("room_id", ""))
	if room_id.strip_edges() == "":
		_SessionStore.clear_session()
		return

	var saved_lobby_url := str(session.get("lobby_server_url", ""))
	var current_lobby_url := MultiplayerConfig.get_lobby_url() if MultiplayerConfig else ""
	var lobby_candidates: Array[String] = []
	if saved_lobby_url.strip_edges() != "":
		lobby_candidates.append(saved_lobby_url)
	if current_lobby_url.strip_edges() != "" and (current_lobby_url not in lobby_candidates):
		lobby_candidates.append(current_lobby_url)
	if lobby_candidates.is_empty():
		return

	print("[Landing] 🔄 Found Code Breaker session. Room: %s | Candidates: %s" % [room_id, str(lobby_candidates)])

	var chosen_lobby_url := ""
	var parsed: Variant = null
	var saw_404 := false
	for candidate_url in lobby_candidates:
		var url := candidate_url + "/api/rooms/" + room_id
		var res := await _http_get_json(url)
		var code := int(res.get("code", 0))
		if code == 404:
			saw_404 = true
			continue
		if code != 200:
			print("[Landing] ⚠️ Resume check failed against ", candidate_url, " HTTP ", code)
			continue
		var data: Variant = res.get("data", null)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if data.has("error"):
			continue
		chosen_lobby_url = candidate_url
		parsed = data
		break

	if parsed == null:
		# If the room is definitely gone, clear. If it was just a transient network/server issue, keep session and retry.
		if saw_404:
			print("[Landing] ℹ️ Room not found (404). Clearing session.")
			_SessionStore.clear_session()
			_code_breaker_resume_retries = 0
			return
		if _code_breaker_resume_retries < 5:
			_code_breaker_resume_retries += 1
			print("[Landing] ⏳ Resume check failed (transient). Retrying in 2s… (", _code_breaker_resume_retries, "/5)")
			await get_tree().create_timer(2.0).timeout
			call_deferred("_try_resume_code_breaker_session")
		return

	_code_breaker_resume_retries = 0

	var status := str(parsed.get("status", "waiting"))
	var host_dict = parsed.get("host", {})
	var is_host := false
	if typeof(host_dict) == TYPE_DICTIONARY:
		is_host = (str(host_dict.get("player_id", "")) == Auth.current_local_id)

	if status == "in_game":
		print("[Landing] ✅ Match in progress, routing to reconnect")
		_resume_routed = true
		var init := {
			"room_id": room_id,
			"lobby_server_url": chosen_lobby_url,
			"player_id": Auth.current_local_id,
			"username": Auth.current_username,
			"is_host": is_host,
			"relay_client": null,
			"host_data": host_dict,
			"client_data": parsed.get("client", {}) if parsed.get("client", null) != null else {},
			"game_start_time": int(parsed.get("game_start_time", 0)),
			"reason": "Resume after relogin"
		}
		get_tree().set_meta("code_breaker_reconnect_init", init)
		var reconnect_scene := load("res://scene/code_breaker_reconnect.tscn")
		if reconnect_scene:
			get_tree().change_scene_to_packed(reconnect_scene)
		return

	if status == "waiting":
		print("[Landing] ✅ Room still waiting, routing back to room")
		_resume_routed = true
		var room_init := {
			"room_id": room_id,
			"host_name": str(host_dict.get("username", "Host")),
			"is_host": is_host,
			"lobby_server_url": chosen_lobby_url
		}
		get_tree().set_meta("code_breaker_room_init", room_init)
		var room_scene := load("res://scene/code_breaker_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		return

	if status == "finished":
		print("[Landing] ✅ Match finished, routing to postgame")
		_resume_routed = true
		var postgame_init := {
			"room_id": room_id,
			"relay_client": null,
			"player_id": Auth.current_local_id,
			"is_host": is_host,
			"host_data": host_dict,
			"client_data": parsed.get("client", {}) if parsed.get("client", null) != null else {},
			"lobby_server_url": chosen_lobby_url,
			"winner_id": "",
			"host_score": 0,
			"client_score": 0,
			"host_health": 0,
			"client_health": 0,
			"game_duration": 0.0,
			"host_powerups_used": 0,
			"client_powerups_used": 0,
			"result_unknown": true
		}
		get_tree().set_meta("code_breaker_postgame_init", postgame_init)
		var post_scene := load("res://scene/code_breaker_postgame.tscn")
		if post_scene:
			get_tree().change_scene_to_packed(post_scene)
		return

	# Unknown status -> clear and stay on landing
	_SessionStore.clear_session()


func _try_resume_akashic_tcg_session() -> void:
	if _resume_routed:
		return
	# Only resume for logged-in users (Auth can be set a frame later)
	for _i in range(10):
		if Auth and Auth.current_local_id != "":
			break
		await get_tree().create_timer(0.25).timeout
	if not Auth or Auth.current_local_id == "":
		return

	var session := _TGCSess.load_session()
	if session.is_empty():
		return

	var session_player_id := str(session.get("player_id", ""))
	if session_player_id != "" and session_player_id != "unknown" and session_player_id != Auth.current_local_id:
		_TGCSess.clear_session()
		return

	var room_id := str(session.get("room_id", "")).strip_edges()
	if room_id == "":
		_TGCSess.clear_session()
		return

	var saved_lobby_url := str(session.get("lobby_server_url", "")).strip_edges()
	var current_lobby_url := MultiplayerConfig.get_lobby_url() if MultiplayerConfig else ""
	var lobby_candidates: Array[String] = []
	if saved_lobby_url != "":
		lobby_candidates.append(saved_lobby_url)
	if current_lobby_url.strip_edges() != "" and (current_lobby_url not in lobby_candidates):
		lobby_candidates.append(current_lobby_url)
	if lobby_candidates.is_empty():
		return

	print("[Landing] 🔄 Found Akashic TCG session. Room: %s | Candidates: %s" % [room_id, str(lobby_candidates)])

	var chosen_lobby_url := ""
	var parsed: Variant = null
	var saw_404 := false
	for candidate_url in lobby_candidates:
		var url := candidate_url + "/api/rooms/" + room_id
		var res := await _http_get_json(url)
		var code := int(res.get("code", 0))
		if code == 404:
			saw_404 = true
			continue
		if code != 200:
			print("[Landing] ⚠️ TGC resume check failed against ", candidate_url, " HTTP ", code)
			continue
		var data: Variant = res.get("data", null)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if data.has("error"):
			continue
		chosen_lobby_url = candidate_url
		parsed = data
		break

	if parsed == null:
		if saw_404:
			print("[Landing] ℹ️ TGC room not found (404). Clearing session.")
			_TGCSess.clear_session()
			_tgc_resume_retries = 0
			return
		if _tgc_resume_retries < 5:
			_tgc_resume_retries += 1
			print("[Landing] ⏳ TGC resume check failed (transient). Retrying in 2s… (", _tgc_resume_retries, "/5)")
			await get_tree().create_timer(2.0).timeout
			call_deferred("_try_resume_akashic_tcg_session")
		return

	_tgc_resume_retries = 0

	var status := str(parsed.get("status", "waiting"))
	var host_dict = parsed.get("host", {})
	var is_host := false
	if typeof(host_dict) == TYPE_DICTIONARY:
		is_host = (str(host_dict.get("player_id", "")) == Auth.current_local_id)

	var phase := str(session.get("phase", ""))

	if status == "in_game":
		print("[Landing] ✅ TGC match in progress, routing to reconnect")
		_resume_routed = true
		get_tree().set_meta("tgc_reconnect_init", {
			"room_id": room_id,
			"lobby_server_url": chosen_lobby_url,
			"player_id": Auth.current_local_id,
			"username": Auth.current_username,
			"is_host": is_host,
			"relay_client": null,
			"host_data": host_dict,
			"client_data": parsed.get("client", {}) if parsed.get("client", null) != null else {},
			"game_start_time": int(parsed.get("game_start_time", 0)),
			"reason": "Resume after relogin",
			"phase": phase,
		})
		var reconnect_scene := load("res://scene/akashic_tcg_reconnect.tscn")
		if reconnect_scene:
			get_tree().change_scene_to_packed(reconnect_scene)
		return

	if status == "waiting":
		print("[Landing] ✅ TGC room still waiting, routing to room")
		_resume_routed = true
		get_tree().set_meta("tgc_room_init", {
			"room_id": room_id,
			"host_name": str(host_dict.get("username", "Host")),
			"is_host": is_host,
			"lobby_server_url": chosen_lobby_url,
		})
		var room_scene := load("res://scene/akashic_tcg_room.tscn")
		if room_scene:
			get_tree().change_scene_to_packed(room_scene)
		return

	if status == "finished":
		print("[Landing] ✅ TGC match finished, routing to postgame")
		_resume_routed = true
		get_tree().set_meta("tgc_postgame_init", {
			"room_id": room_id,
			"player_id": Auth.current_local_id,
			"winner_id": "",
			"reason": "resume_finished",
			"lobby_server_url": chosen_lobby_url,
			"host_data": host_dict,
			"client_data": parsed.get("client", {}) if parsed.get("client", null) != null else {},
			"result_unknown": true,
		})
		var post_scene := load("res://scene/akashic_tcg_postgame.tscn")
		if post_scene:
			get_tree().change_scene_to_packed(post_scene)
		return

	_TGCSess.clear_session()


func _http_get_json(url: String) -> Dictionary:
	var http_req := HTTPRequest.new()
	add_child(http_req)
	var err := http_req.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		http_req.queue_free()
		return {"code": 0, "data": null}
	var result: Array = await http_req.request_completed
	http_req.queue_free()
	var code := int(result[1])
	var body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return {"code": code, "data": parsed}

func _setup_mission_system() -> void:
	"""Setup the first mission as clickable label in NewsPanel"""
	if not news_panel:
		push_error("[Landing] NewsPanel not found!")
		return
	
	# Create clickable mission label (simple text style)
	mission_button = Button.new()
	mission_button.name = "FirstMissionButton"
	mission_button.text = "URGENT: Task Awaits!"
	mission_button.custom_minimum_size = Vector2(380, 80)
	mission_button.position = Vector2(10, 65)
	mission_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Make button completely transparent (plain text style)
	var btn_style = StyleBoxEmpty.new()
	
	mission_button.add_theme_stylebox_override("normal", btn_style)
	mission_button.add_theme_stylebox_override("hover", btn_style)
	mission_button.add_theme_stylebox_override("pressed", btn_style)
	mission_button.add_theme_stylebox_override("focus", btn_style)
	mission_button.add_theme_font_size_override("font_size", 16)
	mission_button.add_theme_color_override("font_color", Color.WHITE)
	mission_button.add_theme_color_override("font_hover_color", Color.WHITE) # No color change on hover
	mission_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	mission_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mission_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	mission_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	
	# Add black divider line below
	var divider = ColorRect.new()
	divider.name = "MissionDivider"
	divider.size = Vector2(380, 2)
	divider.position = Vector2(10, 115) # Below the text
	divider.color = Color(0, 0, 0, 1) # Black color
	
	# Connect button click
	mission_button.pressed.connect(_on_mission_button_pressed)
	
	# Add to NewsPanel
	news_panel.add_child(mission_button)
	news_panel.add_child(divider)
	
	# Initially hidden
	mission_button.visible = false
	divider.visible = false
	
	print("[Landing] ✅ Mission system initialized")


# === Call this after welcome tutorial completes ===
func _activate_first_mission() -> void:
	"""Activate the first mission for new players"""
	if not mission_button:
		push_error("[Landing] Mission button not initialized!")
		return
	
	print("[Landing] 🎯 Activating first mission!")
	first_mission_active = true
	mission_button.visible = true
	
	# Show divider
	var divider = news_panel.get_node_or_null("MissionDivider")
	if divider:
		divider.visible = true
	
	# Animate button to draw attention
	_animate_mission_button()


func _animate_mission_button() -> void:
	"""Pulse animation for mission button"""
	if not mission_button:
		return
	
	var tween = create_tween()
	tween.set_loops(5) # Pulse 5 times
	tween.tween_property(mission_button, "modulate:a", 0.6, 0.5)
	tween.tween_property(mission_button, "modulate:a", 1.0, 0.5)


func _on_mission_button_pressed() -> void:
	"""Show mission details popup"""
	print("[Landing] 🎯 Mission button clicked!")
	
	# Create custom dialog panel
	var dialog_panel = Panel.new()
	dialog_panel.custom_minimum_size = Vector2(700, 450)
	dialog_panel.position = Vector2(
		(get_viewport().size.x - 700) / 2,
		(get_viewport().size.y - 450) / 2
	)
	
	# Style the panel (matching mode_selection style)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.1, 0.15, 0.95) # Dark blue-ish background
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0, 0.9, 1, 0.8) # Cyan border
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0, 1, 1, 0.3)
	panel_style.shadow_size = 15
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Task Awaits"
	title_label.position = Vector2(0, 10)
	title_label.size = Vector2(700, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	title_label.add_theme_font_size_override("font_size", 18)
	dialog_panel.add_child(title_label)
	
	# Mission Title
	var mission_title = Label.new()
	mission_title.text = "Task 00: Learn"
	mission_title.position = Vector2(0, 50)
	mission_title.size = Vector2(700, 40)
	mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_title.add_theme_color_override("font_color", Color(0, 1, 1, 1)) # Cyan
	mission_title.add_theme_font_size_override("font_size", 28)
	dialog_panel.add_child(mission_title)
	
	# Description
	var description = Label.new()
	description.text = "Your First Cyber Arena Mission is to learn the basics of cybersecurity and \nhow to protect yourself online against threats!"
	description.position = Vector2(40, 110)
	description.size = Vector2(620, 80)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.add_theme_color_override("font_color", Color(0, 1, 1, 1)) # Cyan
	description.add_theme_font_size_override("font_size", 16)
	dialog_panel.add_child(description)
	
	# Mission objectives
	var mission_label = Label.new()
	mission_label.text = """Your Objectives:
• Navigate to MODULE section
• Complete security training tutorials
• Learn how to defend against cyber threats
• Earn XP to unlock advanced security tools"""
	mission_label.position = Vector2(40, 190)
	mission_label.size = Vector2(620, 120)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mission_label.add_theme_color_override("font_color", Color(0, 1, 1, 1)) # Cyan
	mission_label.add_theme_font_size_override("font_size", 16)
	dialog_panel.add_child(mission_label)
	
	# Reward
	var reward_label = Label.new()
	reward_label.text = "REWARD: 50 XP"
	reward_label.position = Vector2(40, 310)
	reward_label.size = Vector2(620, 30)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_label.add_theme_color_override("font_color", Color(0, 1, 1, 1)) # Cyan
	reward_label.add_theme_font_size_override("font_size", 18)
	dialog_panel.add_child(reward_label)
	
	# Challenge text
	var challenge_label = Label.new()
	challenge_label.text = "This is your first real test, Agent. Can you handle it?"
	challenge_label.position = Vector2(40, 345)
	challenge_label.size = Vector2(620, 30)
	challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	challenge_label.add_theme_color_override("font_color", Color(0, 1, 1, 1)) # Cyan
	challenge_label.add_theme_font_size_override("font_size", 16)
	dialog_panel.add_child(challenge_label)
	
	# Accept Mission Button (centered)
	var accept_btn = Button.new()
	accept_btn.text = "Accept Mission"
	accept_btn.custom_minimum_size = Vector2(200, 40)
	accept_btn.position = Vector2(175, 395) # Centered: (700 - 450) / 2 = 125, then 125 + 50 = 175
	accept_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0, 0, 0, 0.8)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(0, 0.9, 1, 0.8)
	btn_style_normal.corner_radius_top_left = 5
	btn_style_normal.corner_radius_top_right = 5
	btn_style_normal.corner_radius_bottom_left = 5
	btn_style_normal.corner_radius_bottom_right = 5
	
	var btn_style_hover = btn_style_normal.duplicate()
	btn_style_hover.bg_color = Color(0, 0.6, 0.7, 0.9)
	
	accept_btn.add_theme_stylebox_override("normal", btn_style_normal)
	accept_btn.add_theme_stylebox_override("hover", btn_style_hover)
	accept_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	accept_btn.add_theme_color_override("font_color", Color.WHITE)
	accept_btn.add_theme_font_size_override("font_size", 16)
	
	accept_btn.pressed.connect(func():
		print("[Landing] Mission accepted! Going to Module...")
		dialog_panel.queue_free()
		_complete_first_mission()
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	)
	dialog_panel.add_child(accept_btn)
	
	# Later Button (centered next to Accept)
	var later_btn = Button.new()
	later_btn.text = "Later"
	later_btn.custom_minimum_size = Vector2(200, 40)
	later_btn.position = Vector2(395, 395) # 175 + 200 (button width) + 20 (gap) = 395
	later_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	later_btn.add_theme_stylebox_override("normal", btn_style_normal)
	later_btn.add_theme_stylebox_override("hover", btn_style_hover)
	later_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	later_btn.add_theme_color_override("font_color", Color.WHITE)
	later_btn.add_theme_font_size_override("font_size", 16)
	
	later_btn.pressed.connect(func():
		print("[Landing] Mission postponed")
		dialog_panel.queue_free()
	)
	dialog_panel.add_child(later_btn)
	
	# Close button (X)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.position = Vector2(660, 10)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.5, 1))
	close_btn.add_theme_font_size_override("font_size", 24)
	
	close_btn.pressed.connect(func():
		dialog_panel.queue_free()
	)
	dialog_panel.add_child(close_btn)
	
	add_child(dialog_panel)

# ===== COMBINED: LOAD USER DATA + CHECK WELCOME TUTORIAL =====
func _load_user_data_and_check_tutorial() -> void:
	"""Load user data and check welcome tutorial in ONE request"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		print("[Landing] No auth info")
		return
	
	# ✅ INSTANT CHECK: Use cached status if already loaded
	if Auth.welcome_tutorial_loaded:
		print("[Landing] === USING CACHED WELCOME TUTORIAL STATUS ===")
		# Still need to load user profile data
		_load_user_data()
		# Check tutorial from cache
		if not Auth.welcome_tutorial_completed:
			print("[Landing] 🎉 NEW USER (cached) - Starting Pokemon Welcome Tutorial")
			_start_welcome_tutorial()
		else:
			print("[Landing] ✅ Welcome tutorial already completed (cached)")
		return

	# ✅ ONE REQUEST: Load everything at once
	print("[Landing] === LOADING USER DATA + WELCOME STATUS ===")
	var url = "%s/%s" % [firestore_base_url, user_id]
	var headers = ["Authorization: Bearer %s" % id_token]

	if http.request_completed.is_connected(_on_combined_data_response):
		http.request_completed.disconnect(_on_combined_data_response)
	http.request_completed.connect(_on_combined_data_response)

	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_combined_data_response(_result, response_code, _headers, body) -> void:
	"""Handle combined user data + welcome tutorial check"""
	if response_code != 200:
		print("[Landing] Failed to load data:", response_code)
		Auth.set_welcome_tutorial_status(false)
		_start_welcome_tutorial()
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data.has("fields"):
		Auth.set_welcome_tutorial_status(false)
		_start_welcome_tutorial()
		return

	var f = data["fields"]
	
	# ✅ Load avatar with size enforcement
	if f.has("avatar"):
		selected_avatar = f["avatar"]["stringValue"]
		
		if selected_avatar.begins_with("user://"):
			if FileAccess.file_exists(selected_avatar):
				var img = Image.load_from_file(selected_avatar)
				if img:
					# ✅ CRITICAL: Resize to fixed 80x80
					img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
					var texture = ImageTexture.create_from_image(img)
					profile_pic.texture = texture
					Auth.current_avatar = selected_avatar
		elif avatars.has(selected_avatar):
			profile_pic.texture = avatars[selected_avatar]
			Auth.current_avatar = selected_avatar
		
		# ✅ Always enforce size after loading
		_setup_profile_picture_constraints()
	
	if f.has("last_avatar_change"):
		last_avatar_change = int(f["last_avatar_change"]["integerValue"])

	if f.has("username"):
		Auth.current_username = f["username"]["stringValue"]
		username_input.text = Auth.current_username

	# Equipped card background (for Host/Client cards)
	if Auth:
		if f.has("equipped_card_bg_path"):
			Auth.current_card_bg_path = str(f["equipped_card_bg_path"].get("stringValue", ""))
		else:
			Auth.current_card_bg_path = ""

	if f.has("level"):
		var lvl := int(f["level"]["integerValue"])
		level_input.text = str(lvl)
		if Auth:
			Auth.current_level = lvl

	if f.has("wins"):
		wins_input.text = str(f["wins"]["integerValue"])

	if f.has("losses"):
		losses_input.text = str(f["losses"]["integerValue"])
	
	if match_played_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)
	
	# Check welcome tutorial
	var welcome_completed := true
	if f.has("welcome_tutorial_completed"):
		welcome_completed = f["welcome_tutorial_completed"].get("booleanValue", true)
	else:
		welcome_completed = false
	
	Auth.set_welcome_tutorial_status(welcome_completed)

	# One-time starter reward (first time the player starts the game)
	var starter_claimed := false
	if f.has("starter_chariot_reward_claimed"):
		starter_claimed = bool(f["starter_chariot_reward_claimed"].get("booleanValue", false))
	_starter_reward_claimed_cache = starter_claimed

	# IMPORTANT: new users should finish the Pokemon welcome UI first
	if not starter_claimed:
		if not welcome_completed:
			print("[Landing] 🎉 NEW USER DETECTED - Starting Pokemon Welcome Tutorial")
			_start_welcome_tutorial()
			return
		print("[Landing] 🎁 Starter reward not claimed - showing popup")
		call_deferred("_show_starter_reward_popup", true)
		return

	if not welcome_completed:
		print("[Landing] 🎉 NEW USER DETECTED - Starting Pokemon Welcome Tutorial")
		_start_welcome_tutorial()
	else:
		print("[Landing] ✅ Welcome tutorial already completed")


func _show_starter_reward_popup(welcome_completed: bool) -> void:
	# Show the same RewardPopup design/concept as other rewards.
	await get_tree().process_frame

	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	add_child(popup)
	popup.save_to_inventory = false # we'll save the custom items ourselves (needs subtype for cosmetics)

	var custom_font = load("res://asset/fonts/NicoMoji-Regular.ttf")
	_apply_font_to_children(popup, custom_font, 20)

	var guide_icon: Texture2D = null
	if ResourceLoader.exists("res://asset/icons/hologram_guide.png"):
		guide_icon = load("res://asset/icons/hologram_guide.png")

	var chariot_path := "res://asset/reward_background_cards/the chariot 7 card.jpeg"
	var chariot_icon: Texture2D = null
	if ResourceLoader.exists(chariot_path):
		chariot_icon = load(chariot_path)

	var rewards = [
		RewardItem.new("xp", 50, "Experience Points", null, "Welcome bonus"),
		RewardItem.new("badge", 1, "Beginner Guide", guide_icon, "Your quick-start guide."),
		RewardItem.new("card", 1, "The Chariot", chariot_icon, "Equip to change your Host/Client card background."),
	]
	popup.show_rewards(rewards, "🎁 Starter Rewards")

	popup.rewards_claimed.connect(func():
		_show_starter_reward_claimed_async(welcome_completed)
	)


func _show_starter_reward_claimed_async(welcome_completed: bool) -> void:
	# Grant the custom rewards to Firestore, then continue onboarding.
	if has_node("/root/InventoryHelper"):
		# Beginner guide as a badge item
		InventoryHelper.add_item_to_inventory({
			"name": "Beginner Guide",
			"type": "badge",
			"rarity": "common",
			"description": "Your quick-start guide.",
			"icon_path": "res://asset/icons/hologram_guide.png",
			"amount": 1,
		})

		# The Chariot card background (equippable) - deterministic ID + default equipped
		InventoryHelper.grant_starter_chariot_equipped()
		InventoryHelper.set_equipped_card_background("res://asset/reward_background_cards/the chariot 7 card.jpeg")

	_mark_starter_reward_claimed()

	if not welcome_completed:
		print("[Landing] ▶ Continuing into welcome tutorial")
		_start_welcome_tutorial()
	else:
		print("[Landing] ▶ Starter rewards claimed")


func _mark_starter_reward_claimed() -> void:
	_starter_reward_claimed_cache = true
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	var url = "%s/%s?updateMask.fieldPaths=starter_chariot_reward_claimed" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"starter_chariot_reward_claimed": {"booleanValue": true}
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var starter_http := HTTPRequest.new()
	add_child(starter_http)
	starter_http.request_completed.connect(func(_r, code, _h, _b):
		starter_http.queue_free()
		if code != 200:
			push_warning("[Landing] Failed to mark starter reward claimed HTTP %d" % code)
	)
	starter_http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

# ===== REMOVE OLD FUNCTIONS - REPLACED BY COMBINED VERSION =====
# _check_and_start_welcome_tutorial() is now replaced by _load_user_data_and_check_tutorial()
# _load_user_data() is now only called if cache exists


func _start_welcome_tutorial() -> void:
	"""Start the Pokemon-style welcome tutorial overlay"""
	if not welcome_ui:
		push_error("[Landing] Cannot start tutorial - welcome_ui is null!")
		return
	
	print("[Landing] ========== STARTING POKEMON WELCOME TUTORIAL ==========")
	
	# Ensure the welcome UI is on top of everything
	welcome_ui.layer = 100
	welcome_ui.visible = true
	welcome_ui.show()
	
	print("[Landing] Welcome UI visible:", welcome_ui.visible)
	print("[Landing] Welcome UI layer:", welcome_ui.layer)
	
	# Start the tutorial sequence
	welcome_ui.start_tutorial()
	print("[Landing] ✅ Pokemon Tutorial started!")


func _on_welcome_tutorial_completed() -> void:
	"""Called when the Pokemon-style welcome tutorial is completed"""
	print("[Landing] ========== TUTORIAL COMPLETED SIGNAL RECEIVED ==========")
	
	# ✅ CRITICAL: Check if we already awarded the bonus
	if welcome_bonus_awarded:
		print("[Landing] ⚠️ Welcome bonus already awarded! Ignoring duplicate call.")
		return
	
	welcome_bonus_awarded = true
	print("[Landing] ✅ Pokemon Welcome tutorial completed! (First time)")
	
	# ✅ Mark as completed in Auth cache
	Auth.mark_welcome_tutorial_complete()
	
	# ✅ Use call_deferred to avoid any conflicts
	if not _starter_reward_claimed_cache:
		call_deferred("_show_starter_reward_popup", true)
	call_deferred("_activate_first_mission")

func _show_welcome_reward() -> void:
	"""Show animated reward popup after completing the tutorial"""
	print("[Landing] ========== SHOW WELCOME REWARD ==========")
	
	# Award XP FIRST

	await get_tree().process_frame
	
	# ✅ SIMPLE: Just use RewardItem directly now!
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	add_child(popup)
	
	var custom_font = load("res://asset/fonts/NicoMoji-Regular.ttf") # or .otf
	
	_apply_font_to_children(popup, custom_font, 20)


	var rewards = [
		RewardItem.new("xp", 50, "Experience Points", null, "Completed the Welcome Tutorial"),
		RewardItem.new("badge", 1, "Beginner Badge", null, "Your first achievement!")
	]
	popup.show_rewards(rewards, " Welcome Aboard, Agent!")


func _apply_font_to_children(node: Node, font: Font, font_size: int) -> void:
		if node is Label or node is Button or node is RichTextLabel:
			node.add_theme_font_override("font", font)
			node.add_theme_font_size_override("font_size", font_size)
		
		for child in node.get_children():
			_apply_font_to_children(child, font, font_size)

func _complete_first_mission() -> void:
	"""Mark first mission as completed with animated rewards"""
	first_mission_active = false
	
	if mission_button:
		mission_button.visible = false
	
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	add_child(popup)
	
	var rewards = [
		RewardItem.new("xp", 50, "Mission XP", null, "Task 00: Learn completed!"),
		RewardItem.new("badge", 1, "First Mission", null, "Complete your first mission")
	]
	
	popup.show_rewards(rewards, "🎯 Mission Complete!")
	
	popup.rewards_claimed.connect(func():
		_save_mission_completion_to_firestore()
	)

# ✅ NEW: Helper function for saving mission completion
func _save_mission_completion_to_firestore() -> void:
	"""Save mission completion to Firestore"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		return
	
	var url = "%s/%s?updateMask.fieldPaths=first_mission_completed" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"first_mission_completed": {"booleanValue": true}
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http_mission = HTTPRequest.new()
	add_child(http_mission)
	http_mission.request_completed.connect(func(_r, code, _h, _b):
		http_mission.queue_free()
		if code == 200:
			print("[Landing] ✅ First mission marked complete in Firestore")
		else:
			push_error("[Landing] ❌ Failed to save mission completion")
	)
	http_mission.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _on_xp_updated(new_xp: int) -> void:
	print("[Landing] 🎉 XP Updated: %d" % new_xp)
	
	var rank: Dictionary = TutorialManager.get_rank(new_xp)
	var current_xp = rank.get("current_xp", new_xp)
	var max_xp = rank.get("max_xp", 1000)
	
	if xp_progress:
		xp_progress.max_value = max_xp
		xp_progress.value = current_xp
		
		var label = xp_progress.get_node_or_null("XPLabel")
		if label:
			label.text = "%d / %d XP" % [current_xp, max_xp]
	
	if rank_label:
		var icon_path = rank.get("icon", "")
		var rank_name = rank.get("name", "Iron")
		var color = rank.get("color", Color(0.5, 0.5, 0.5))
		
		var user_panel = $VideoStreamPlayer/ProfilePanel/UserPanel
		var rank_icon_rect = user_panel.get_node_or_null("RankIconRect")
		
		if icon_path.begins_with("res://") and rank_icon_rect:
			var rank_texture = load(icon_path)
			if rank_texture:
				rank_icon_rect.texture = rank_texture
				_add_glow_to_rank_icon(rank_icon_rect, color)
				
				# ✅ Use constant
				rank_icon_rect.position = RANK_ICON_POSITION
				rank_icon_rect.size = RANK_ICON_SIZE
				
				rank_label.text = rank_name
				rank_label.position = RANK_LABEL_POSITION
				rank_label.size = Vector2(200, 30)
				rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				rank_label.text = rank_name
				rank_label.position = RANK_LABEL_POSITION
		else:
			rank_label.text = "%s\n%s" % [icon_path, rank_name]
			rank_label.position = RANK_LABEL_POSITION
		
		rank_label.add_theme_color_override("font_color", color)
		
func _on_rank_up(new_rank: Dictionary) -> void:
	print("🏆 RANK UP! %s %s" % [new_rank["icon"], new_rank["name"]])
	
	# Find old rank
	var old_rank: Dictionary = TutorialManager.RANK_THRESHOLDS[0]
	for i in range(TutorialManager.RANK_THRESHOLDS.size()):
		if TutorialManager.RANK_THRESHOLDS[i]["name"] == new_rank["name"] and i > 0:
			old_rank = TutorialManager.RANK_THRESHOLDS[i - 1]
			break
	
	await get_tree().process_frame
	
	var notification_scene = load("res://scene/rank_up_notification.tscn")
	if notification_scene:
		var rank_up_notification = notification_scene.instantiate()
		add_child(rank_up_notification)
		rank_up_notification.show_rank_up(old_rank, new_rank)
		await rank_up_notification.notification_closed
		print("[Landing] ✅ Rank-up notification closed")
	else:
		push_error("[Landing] ❌ Failed to load rank_up_notification.tscn")


# === Load avatars from folder ===
func _load_avatars() -> void:
	var dir := DirAccess.open("res://asset/avatars")
	if dir == null:
		push_error("⚠️ Avatar folder not found")
		return

	avatars.clear()
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["png", "jpg", "jpeg", "webp"]:
			var tex := load("res://asset/avatars/" + file_name)
			if tex:
				avatars[file_name] = tex
				var btn := TextureButton.new()
				btn.texture_normal = tex
				# Force thumbnails to 80x80 regardless of source texture size.
				btn.ignore_texture_size = true
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				btn.custom_minimum_size = Vector2(80, 80)
				var captured_name: String = file_name
				btn.pressed.connect(func(): _on_avatar_selected(captured_name))
				avatar_grid.add_child(btn)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_change_avatar_pressed() -> void:
	# Open file dialog to select custom image
	file_dialog.popup_centered(Vector2(700, 500))


func _on_save_profile_pressed() -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in")
		return

	last_avatar_change = int(Time.get_unix_time_from_system())

	var url = "%s/%s?updateMask.fieldPaths=username&updateMask.fieldPaths=level&updateMask.fieldPaths=wins&updateMask.fieldPaths=losses&updateMask.fieldPaths=avatar&updateMask.fieldPaths=last_avatar_change" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"username": {"stringValue": username_input.text},
			"level": {"integerValue": level_input.text},
			"wins": {"integerValue": wins_input.text},
			"losses": {"integerValue": losses_input.text},
			"avatar": {"stringValue": selected_avatar},
			"last_avatar_change": {"integerValue": str(last_avatar_change)}
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	if http.request_completed.is_connected(_on_save_profile_response):
		http.request_completed.disconnect(_on_save_profile_response)
	http.request_completed.connect(_on_save_profile_response)

	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _on_save_profile_response(_result, response_code, _headers, body) -> void:
	if response_code == 200:
		# ✅ Update originals after successful save
		original_username = username_input.text
		original_avatar = selected_avatar
		
		# Show temporary success message
		if status_label:
			status_label.visible = true
			status_label.text = "✅ Profile saved!"
			status_label.modulate = Color(0, 1, 0.5, 1)
			
			# Hide after 2 seconds
			await get_tree().create_timer(2.0).timeout
			if status_label:
				status_label.visible = false
		
		Auth.current_avatar = selected_avatar
		Auth.current_username = username_input.text
		_load_user_data()
	else:
		var msg = body.get_string_from_utf8() if body.size() > 0 else "Unknown error"
		if status_label:
			status_label.visible = true
			status_label.text = "❌ Failed to save profile"
			status_label.modulate = Color(1, 0, 0, 1)
		push_error("Firestore error: %s" % msg)

func _load_user_data() -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	var url = "%s/%s" % [firestore_base_url, user_id]
	var headers = ["Authorization: Bearer %s" % id_token]

	if http.request_completed.is_connected(_on_user_data_response):
		http.request_completed.disconnect(_on_user_data_response)
	http.request_completed.connect(_on_user_data_response)

	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_user_data_response(_result, response_code, _headers, body) -> void:
	if response_code != 200:
		push_error("⚠️ Failed to load user data:", response_code)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data.has("fields"):
		return

	var f = data["fields"]

	if f.has("avatar"):
		selected_avatar = f["avatar"]["stringValue"]
		
		if selected_avatar.begins_with("user://"):
			if FileAccess.file_exists(selected_avatar):
				var img = Image.load_from_file(selected_avatar)
				if img:
					# ✅ CRITICAL: Always resize to 80x80
					img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
					var texture = ImageTexture.create_from_image(img)
					profile_pic.texture = texture
					Auth.current_avatar = selected_avatar
		elif avatars.has(selected_avatar):
			# ✅ NEW: Also resize preset avatars to ensure consistency
			var original_texture = avatars[selected_avatar]
			var img = original_texture.get_image()
			if img:
				img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
				profile_pic.texture = ImageTexture.create_from_image(img)
			else:
				profile_pic.texture = original_texture
			Auth.current_avatar = selected_avatar
		
		# ✅ IMPORTANT: Call this AFTER setting the texture
		await get_tree().process_frame # Wait one frame for texture to apply
		_setup_profile_picture_constraints()
		
	if f.has("last_avatar_change"):
		last_avatar_change = int(f["last_avatar_change"]["integerValue"])

	if f.has("username"):
		Auth.current_username = f["username"]["stringValue"]
		username_input.text = Auth.current_username
		original_username = Auth.current_username

	if f.has("level"):
		var lvl := int(f["level"]["integerValue"])
		level_input.text = str(lvl)
		if Auth:
			Auth.current_level = lvl

	if f.has("wins"):
		wins_input.text = str(f["wins"]["integerValue"])

	if f.has("losses"):
		losses_input.text = str(f["losses"]["integerValue"])
	
	if match_played_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)
	
	original_avatar = selected_avatar

	# Load match history after we have username/uid
	_ensure_match_history_ui()
	_load_match_history()

# ============================================
# STEP 7: Update _refresh_profile_ui_positions
# ============================================
# ============================================
# STEP 8: Update _update_xp_display for new positions
# ============================================

func _show_panel(panel_paths: Dictionary, panel_name: String) -> void:
	"""Show panel and ensure UI elements maintain their positions"""
	for key in panel_paths.keys():
		var node = $VideoStreamPlayer.get_node_or_null(panel_paths[key])
		if node:
			node.visible = false

	var code_breaker_lobby = $VideoStreamPlayer.get_node_or_null("CodeBreakerLobby")
	if code_breaker_lobby:
		code_breaker_lobby.visible = false

	var akashic_lobby = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
	if akashic_lobby:
		akashic_lobby.visible = false

	var node_to_show = $VideoStreamPlayer.get_node_or_null(panel_paths.get(panel_name, ""))
	if node_to_show:
		node_to_show.visible = true
		
		# ✅ If showing profile panel, ensure UI is properly positioned
		if panel_name == "profile":
			_refresh_profile_ui_positions()
			# Refresh match history when opening profile
			_ensure_match_history_ui()
			_load_match_history()

	var friend_list = $VideoStreamPlayer.get_node_or_null("FriendListPanel")
	if friend_list:
		friend_list.visible = (panel_name != "game")

func _setup_navigation() -> void:
	var panel_paths := {
		"home": "HomePanel",
		"game": "GameSelectPanel",
		"ranking": "RankingPanel",
		"profile": "ProfilePanel",
	}

	$NavigationPanel/HBoxContainer/HomeNavigate.pressed.connect(func(): _show_panel(panel_paths, "home"))
	$NavigationPanel/HBoxContainer/GameNavigate.pressed.connect(func(): _show_panel(panel_paths, "game"))
	$NavigationPanel/HBoxContainer/RankingNavigate.pressed.connect(func(): _show_panel(panel_paths, "ranking"))
	$NavigationPanel/HBoxContainer/ProfileNavigate.pressed.connect(func(): _show_panel(panel_paths, "profile"))
	$NavigationPanel/HBoxContainer/LogoButton.pressed.connect(func(): _show_panel(panel_paths, "home"))
	$NavigationPanel/HBoxContainer/BagNavigate.pressed.connect(open_inventory)
	$NavigationPanel/HBoxContainer/MenuButton.pressed.connect(_on_menu_button_pressed)
	
	# ✅ Module button navigation
	$NavigationPanel/HBoxContainer/ModuleNavigate.pressed.connect(_on_module_navigate_pressed)

	var defuse_trojan = $VideoStreamPlayer/GameSelectPanel/allgame/DefuseTheTrojan
	if defuse_trojan:
		defuse_trojan.gui_input.connect(_on_defuse_trojan_gui_input)
		defuse_trojan.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var akashic_tcg = $VideoStreamPlayer/GameSelectPanel/allgame/AkashicTCG
	if akashic_tcg:
		akashic_tcg.gui_input.connect(_on_akashic_tcg_gui_input)
		akashic_tcg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var code_breaker_icon = $VideoStreamPlayer/GameSelectPanel/allgame/CodeBreaker
	if code_breaker_icon:
		code_breaker_icon.gui_input.connect(_on_code_breaker_gui_input)
		code_breaker_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_show_panel(panel_paths, "home")


func _on_module_button_pressed() -> void:
	# Check if user has seen cybersecurity intro
	_check_intro_completion()

func _check_intro_completion() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[Landing] Auth not ready!")
		return
	
	var url = firestore_base_url + "/%s" % Auth.current_local_id
	var headers = ["Authorization: Bearer " + Auth.current_id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("fields"):
				var fields = json["fields"]
				var intro_completed = fields.get("cybersecurity_intro_completed", {}).get("booleanValue", false)
				
				if intro_completed:
					# Go directly to mode selection
					get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
				else:
					# Show intro first
					get_tree().change_scene_to_file("res://scene/intro_cybersecurity.tscn")
			else:
				# First time, show intro
				get_tree().change_scene_to_file("res://scene/intro_cybersecurity.tscn")
		else:
			# On error, show intro anyway
			get_tree().change_scene_to_file("res://scene/intro_cybersecurity.tscn")
	)
	
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_menu_button_pressed() -> void:
	if menu_panel:
		menu_panel.visible = true
		menu_panel.move_to_front()


# ✅ Module navigation function
func _on_module_navigate_pressed() -> void:
	print("[Landing] Checking intro completion before navigating to tutorials...")
	_check_intro_completion()


func _on_reset_stats_pressed() -> void:
	print("[Landing] Resetting match statistics...")
	
	wins_input.text = "0"
	losses_input.text = "0"
	match_played_input.text = "0"
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in")
		return
	
	var url = "%s/%s?updateMask.fieldPaths=wins&updateMask.fieldPaths=losses" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"wins": {"integerValue": 0},
			"losses": {"integerValue": 0}
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http_reset := HTTPRequest.new()
	add_child(http_reset)
	
	http_reset.request_completed.connect(func(_r, code, _h, response_body):
		http_reset.queue_free()
		if code == 200:
			status_label.text = "✅ Match stats reset!"
		else:
			var msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "Unknown error"
			status_label.text = "❌ Failed to reset stats"
			push_error("Firestore error: %s" % msg)
	)
	
	http_reset.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _on_logout_pressed() -> void:
	print("Logging out...")
	Auth.set_user_offline()
	TutorialManager.reset_data()
	get_tree().change_scene_to_file("res://scene/login.tscn")


func _instantiate_chat_panel() -> void:
	var chat_scene = load("res://scene/chat.tscn")
	if chat_scene:
		var chat_panel = chat_scene.instantiate()
		add_child(chat_panel)
		print("[Landing] ChatPanel instantiated")
	else:
		push_error("[Landing] Failed to load chat.tscn")


func _on_defuse_trojan_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Defuse The Trojan clicked")


func _on_akashic_tcg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Akashic TCG clicked")
		# Check if first-time player before showing lobby
		_check_akashic_tutorial_status()


func _check_akashic_tutorial_status() -> void:
	"""Check Firestore for akashic_tcg_tutorial_completed before going to lobby"""
	print("[Landing] Checking AkashicTCG tutorial status...")
	
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[Landing] No auth, skipping tutorial check")
		_go_to_akashic_lobby()
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % user_id
	
	var tutorial_http = HTTPRequest.new()
	add_child(tutorial_http)
	
	tutorial_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		tutorial_http.queue_free()
		
		if code != 200:
			print("[Landing] Could not fetch user data, assuming first time")
			_show_akashic_tutorial_prompt()
			return
		
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("fields"):
			print("[Landing] Invalid response, assuming first time")
			_show_akashic_tutorial_prompt()
			return
		
		var fields = json["fields"]
		if fields.has("akashic_tcg_tutorial_completed"):
			var val = fields["akashic_tcg_tutorial_completed"]
			if val.has("booleanValue") and val["booleanValue"] == true:
				print("[Landing] ✅ Tutorial already completed, going to lobby")
				_go_to_akashic_lobby()
				return
		
		print("[Landing] 🆕 First time player! Showing tutorial prompt")
		_show_akashic_tutorial_prompt()
	)
	
	var headers = ["Authorization: Bearer %s" % id_token]
	var err = tutorial_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[Landing] Failed to check tutorial status")
		tutorial_http.queue_free()
		_go_to_akashic_lobby()


func _show_akashic_tutorial_prompt() -> void:
	"""Show Pokemon-style tutorial prompt when clicking AkashicTCG for first time"""
	print("[Landing] Showing AkashicTCG tutorial prompt...")
	
	var popup_scene = load("res://scene/akashic_tcg_tutorial_prompt.tscn")
	if not popup_scene:
		push_error("[Landing] Tutorial prompt scene not found!")
		_go_to_akashic_lobby()
		return
	
	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()
	
	# Get button references
	var yes_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/YesButton")
	var no_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/NoButton")
	
	if yes_btn:
		yes_btn.pressed.connect(func():
			popup.queue_free()
			_go_to_akashic_tutorial()
		)
	
	if no_btn:
		no_btn.pressed.connect(func():
			popup.queue_free()
			_skip_akashic_tutorial()
		)


func _go_to_akashic_tutorial() -> void:
	"""Navigate directly to tutorial arena"""
	print("[Landing] 🎮 Going to AkashicTCG Tutorial Arena...")
	get_tree().change_scene_to_file("res://scene/akashic_tcg_tutorial_arena.tscn")


func _skip_akashic_tutorial() -> void:
	"""Player skipped tutorial, mark complete and go to lobby"""
	print("[Landing] Player skipped tutorial, going to lobby")
	_mark_akashic_tutorial_complete()
	_go_to_akashic_lobby()


func _mark_akashic_tutorial_complete() -> void:
	"""Mark tutorial as completed in Firestore"""
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=akashic_tcg_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"akashic_tcg_tutorial_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var mark_http = HTTPRequest.new()
	add_child(mark_http)
	
	mark_http.request_completed.connect(func(_r, code, _h, _b):
		mark_http.queue_free()
		if code == 200:
			print("[Landing] ✅ Tutorial skip saved")
	)
	
	mark_http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _go_to_akashic_lobby() -> void:
	"""Show AkashicTCG lobby panel (normal flow)"""
	var game_select_panel = $VideoStreamPlayer/GameSelectPanel
	if game_select_panel:
		game_select_panel.visible = false

	var code_breaker_lobby = $VideoStreamPlayer.get_node_or_null("CodeBreakerLobby")
	if code_breaker_lobby:
		code_breaker_lobby.visible = false

	var akashic_lobby = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
	if akashic_lobby:
		akashic_lobby.visible = true


func _on_code_breaker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Code Breaker clicked")
		
		if not TutorialManager.is_game_unlocked("code_breaker"):
			_show_locked_game_dialog("Code Breaker", 500)
			return
		
		# Check if first-time player before showing lobby
		_check_code_breaker_tutorial_status()


func _check_code_breaker_tutorial_status() -> void:
	"""Check Firestore for code_breaker_tutorial_completed before going to lobby"""
	print("[Landing] Checking Code Breaker tutorial status...")
	
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[Landing] No auth, skipping tutorial check")
		_go_to_code_breaker_lobby()
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s" % user_id
	
	var cb_tutorial_http = HTTPRequest.new()
	add_child(cb_tutorial_http)
	
	cb_tutorial_http.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		cb_tutorial_http.queue_free()
		
		if code != 200:
			print("[Landing] Could not fetch user data, assuming first time")
			_show_code_breaker_tutorial_prompt()
			return
		
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("fields"):
			print("[Landing] Invalid response, assuming first time")
			_show_code_breaker_tutorial_prompt()
			return
		
		var fields = json["fields"]
		if fields.has("code_breaker_tutorial_completed"):
			var val = fields["code_breaker_tutorial_completed"]
			if val.has("booleanValue") and val["booleanValue"] == true:
				print("[Landing] ✅ Code Breaker tutorial already completed, going to lobby")
				_go_to_code_breaker_lobby()
				return
		
		print("[Landing] 🆕 First time Code Breaker player! Showing tutorial prompt")
		_show_code_breaker_tutorial_prompt()
	)
	
	var headers = ["Authorization: Bearer %s" % id_token]
	var err = cb_tutorial_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[Landing] Failed to check Code Breaker tutorial status")
		cb_tutorial_http.queue_free()
		_go_to_code_breaker_lobby()


func _show_code_breaker_tutorial_prompt() -> void:
	"""Show Pokemon-style tutorial prompt when clicking Code Breaker for first time"""
	print("[Landing] Showing Code Breaker tutorial prompt...")
	
	var popup_scene = load("res://scene/code_breaker_tutorial_prompt.tscn")
	if not popup_scene:
		push_error("[Landing] Code Breaker tutorial prompt scene not found!")
		_go_to_code_breaker_lobby()
		return
	
	var popup: Window = popup_scene.instantiate()
	add_child(popup)
	popup.popup()
	
	# Get button references
	var yes_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/YesButton")
	var no_btn = popup.get_node_or_null("Panel/VBoxContainer/ButtonContainer/NoButton")
	
	if yes_btn:
		yes_btn.pressed.connect(func():
			popup.queue_free()
			_go_to_code_breaker_tutorial()
		)
	
	if no_btn:
		no_btn.pressed.connect(func():
			popup.queue_free()
			_skip_code_breaker_tutorial()
		)


func _go_to_code_breaker_tutorial() -> void:
	"""Navigate directly to Code Breaker tutorial arena"""
	print("[Landing] 🎮 Going to Code Breaker Tutorial Arena...")
	get_tree().change_scene_to_file("res://scene/code_breaker_tutorial_arena.tscn")


func _skip_code_breaker_tutorial() -> void:
	"""Player skipped tutorial, mark complete and go to lobby"""
	print("[Landing] Player skipped Code Breaker tutorial, going to lobby")
	_mark_code_breaker_tutorial_complete()
	_go_to_code_breaker_lobby()


func _mark_code_breaker_tutorial_complete() -> void:
	"""Mark Code Breaker tutorial as completed in Firestore"""
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=code_breaker_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"code_breaker_tutorial_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var mark_cb_http = HTTPRequest.new()
	add_child(mark_cb_http)
	
	mark_cb_http.request_completed.connect(func(_r, code_resp, _h, _b):
		mark_cb_http.queue_free()
		if code_resp == 200:
			print("[Landing] ✅ Code Breaker tutorial skip saved")
	)
	
	mark_cb_http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _go_to_code_breaker_lobby() -> void:
	"""Show Code Breaker lobby panel (normal flow)"""
	var game_select_panel = $VideoStreamPlayer/GameSelectPanel
	if game_select_panel:
		game_select_panel.visible = false
	
	var akashic_lobby2 = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
	if akashic_lobby2:
		akashic_lobby2.visible = false
	
	var code_breaker_lobby = $VideoStreamPlayer/CodeBreakerLobby
	if code_breaker_lobby:
		code_breaker_lobby.visible = true


func _show_locked_game_dialog(game_name: String, required_xp: int) -> void:
	var current_xp: int = TutorialManager.total_xp
	var xp_needed: int = required_xp - current_xp
	
	var dialog := AcceptDialog.new()
	dialog.title = "🔒 Game Locked"
	dialog.dialog_text = "%s is locked!\n\nYour XP: %d\nRequired XP: %d\nNeeded: %d more XP\n\nComplete tutorials in Mode Selection to earn XP." % [game_name, current_xp, required_xp, xp_needed]
	dialog.ok_button_text = "Go to Mode Selection"
	dialog.exclusive = false # ✅ Allow other windows
	dialog.canceled.connect(func(): dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	, CONNECT_ONE_SHOT)
	add_child(dialog)
	dialog.popup_centered()


func _setup_profile_picture_constraints() -> void:
	"""Lock profile picture to specific size and position - FINAL VERSION"""
	if not profile_pic:
		return
	
	# ✅ CRITICAL: Set size_flags to NONE to prevent auto-resizing
	profile_pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	profile_pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# ✅ Lock to fixed size
	profile_pic.custom_minimum_size = Vector2(80, 80)
	profile_pic.size = Vector2(80, 80)
	profile_pic.position = Vector2(30, 25)
	
	# ✅ Prevent texture from scaling beyond container
	profile_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Changed from EXPAND_FIT_WIDTH_PROPORTIONAL
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("[Landing] ✅ Profile picture locked: 80x80 at (30, 25)")

func _setup_inventory_system() -> void:
	"""Load and setup the inventory panel"""
	var inventory_scene = load("res://scene/inventory_panel.tscn")
	if inventory_scene:
		inventory_panel = inventory_scene.instantiate()
		add_child(inventory_panel)
		inventory_panel.z_index = 999
		
		if inventory_panel.has_signal("inventory_closed"):
			inventory_panel.inventory_closed.connect(_on_inventory_closed)
		if inventory_panel.has_signal("avatar_selected") and not inventory_panel.avatar_selected.is_connected(_on_inventory_avatar_selected):
			inventory_panel.avatar_selected.connect(_on_inventory_avatar_selected)
		
		print("[Landing] ✅ Inventory system initialized")
	else:
		push_error("[Landing] ❌ Failed to load inventory_panel.tscn")


func _on_inventory_avatar_selected(file_name: String) -> void:
	# Reuse the existing preset-avatar selection behavior.
	_on_avatar_selected(file_name)

func _on_inventory_closed() -> void:
	"""Called when inventory panel is closed"""
	print("[Landing] Inventory panel closed")

func open_inventory() -> void:
	"""Open the inventory/bag panel"""
	if inventory_panel:
		inventory_panel.show_inventory()
	else:
		push_error("[Landing] Inventory panel not initialized!")


func _setup_video_and_music() -> void:
	"""Setup video with fade overlay system and transition support"""
	
	# Setup video player
	video_player = $VideoStreamPlayer
	video_player.loop = false # ✅ Disable auto-loop, we'll control it manually
	video_player.autoplay = false
	video_player.z_index = -90
	video_player.modulate = Color(1, 1, 1, 1)
	video_player.finished.connect(_on_video_finished)
	
	# ✅ Create BLACK OVERLAY (starts invisible)
	fade_overlay = ColorRect.new()
	fade_overlay.name = "VideoFadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = -80
	fade_overlay.modulate.a = 0.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)
	
	# Load and play first video
	_load_and_play_video(0)
	
	# Setup background music
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "BackgroundMusicPlayer"
	audio_player.volume_db = -15.0
	audio_player.finished.connect(_on_music_finished)
	add_child(audio_player)
	
	var music = load(background_music)
	if music:
		audio_player.stream = music
		audio_player.play()
		print("[Landing] ✅ Music playing")
	
	print("[Landing] ✅ Video transition system initialized")

func _load_and_play_video(video_index: int) -> void:
	"""Load and play a specific video by index"""
	var video_path: String
	
	if video_index == 0:
		video_path = background_video
	else:
		video_path = transition_video
	
	var video = load(video_path)
	if video:
		video_player.stream = video
		video_player.play()
		current_video_index = video_index
		print("[Landing] ✅ Playing video %d: %s" % [video_index, video_path])
	else:
		push_error("[Landing] ❌ Failed to load video: %s" % video_path)

func _on_video_finished() -> void:
	"""Handle video completion based on current state"""
	
	if current_video_index == 0:
		# Video 1 finished → transition to Video 2 (with fade)
		print("[Landing] 🎬 Video 1 finished, transitioning to Video 2...")
		_transition_to_video2()
	
	elif current_video_index == 1:
		# Video 2 finished → just loop it (no fade)
		print("[Landing] 🔁 Video 2 looping...")
		video_player.play() # Simple restart, no fade


func _transition_to_video2() -> void:
	"""Transition from Video 1 to Video 2 with fade"""
	# Fade to black
	var tween_out = create_tween()
	tween_out.set_ease(Tween.EASE_IN_OUT)
	tween_out.set_trans(Tween.TRANS_SINE)
	tween_out.tween_property(fade_overlay, "modulate:a", 1.0, video_fade_duration)
	await tween_out.finished
	
	# Load and play Video 2
	_load_and_play_video(1)
	
	# Wait for video to start
	await get_tree().create_timer(0.1).timeout
	
	# Fade from black
	var tween_in = create_tween()
	tween_in.set_ease(Tween.EASE_IN_OUT)
	tween_in.set_trans(Tween.TRANS_SINE)
	tween_in.tween_property(fade_overlay, "modulate:a", 0.0, video_fade_duration)
	await tween_in.finished

func _on_music_finished() -> void:
	"""Music finished - restart with fade"""
	print("[Landing] 🎵 Music finished, restarting with fade...")
	_fade_loop_music()


func _fade_loop_music() -> void:
	"""Fade out music, restart, fade in"""
	
	# Fade out
	var tween_out = create_tween()
	tween_out.set_ease(Tween.EASE_IN_OUT)
	tween_out.set_trans(Tween.TRANS_SINE)
	tween_out.tween_property(audio_player, "volume_db", -80.0, music_fade_duration)
	await tween_out.finished
	
	# Restart
	audio_player.play()
	
	# Fade in
	var tween_in = create_tween()
	tween_in.set_ease(Tween.EASE_IN_OUT)
	tween_in.set_trans(Tween.TRANS_SINE)
	tween_in.tween_property(audio_player, "volume_db", -15.0, music_fade_duration)
	await tween_in.finished
	
	print("[Landing] ✅ Music loop complete")

# =============================================================================
# TUTORIAL REWARDS SYSTEM (Shows on Landing after completing tutorials)
# =============================================================================

func _check_tutorial_rewards() -> void:
	"""Check if returning from a tutorial with rewards to claim"""
	await get_tree().create_timer(1.0).timeout # Wait for landing to fully load
	
	# Check Code Breaker tutorial reward
	if get_tree().has_meta("show_code_breaker_reward"):
		print("[Landing] 🎁 Code Breaker tutorial reward pending!")
		get_tree().remove_meta("show_code_breaker_reward")
		_show_tutorial_reward("code_breaker")
		return
	
	# Check Akashic TCG tutorial reward
	if get_tree().has_meta("show_akashic_tcg_reward"):
		print("[Landing] 🎁 Akashic TCG tutorial reward pending!")
		get_tree().remove_meta("show_akashic_tcg_reward")
		_show_tutorial_reward("akashic_tcg")
		return

func _show_tutorial_reward(tutorial_type: String) -> void:
	"""Show Agent01 dialog first, then Mystery Reward popup separately"""
	print("[Landing] Starting tutorial reward sequence for: %s" % tutorial_type)
	
	# Configure based on tutorial type
	var card_path := ""
	var card_name := ""
	var dialog_text := ""
	
	if tutorial_type == "code_breaker":
		card_path = "res://asset/reward_background_cards/the magician card 1.jpeg"
		card_name = "✨ THE MAGICIAN 1 ✨"
		dialog_text = "Excellent work, Agent! You've proven yourself as a Code Breaker! Your skills are truly impressive. I have a special reward waiting for you..."
	else: # akashic_tcg
		card_path = "res://asset/reward_background_cards/the magician card 2.jpeg"
		card_name = "✨ THE MAGICIAN 2 ✨"
		dialog_text = "Outstanding strategy, Agent! You've mastered the Akashic arts! Your tactical mind is ready for greater challenges. I have a special reward for you..."
	
	# STEP 1: Show Agent01 congratulations dialog FIRST (no card yet)
	await _show_agent_dialog(dialog_text)
	
	# STEP 2: Show Mystery Reward popup with card AFTER dialog is closed
	await _show_mystery_reward_popup(tutorial_type, card_path, card_name)
	
	print("[Landing] ✅ Tutorial reward sequence complete!")

func _show_agent_dialog(dialog_text: String) -> void:
	"""Show Agent01 Pokemon-style congratulations dialog"""
	print("[Landing] Showing Agent01 dialog...")
	var root := get_tree().root
	var viewport_rect := get_viewport().get_visible_rect()
	var vp_pos: Vector2 = viewport_rect.position
	var vp_size: Vector2 = viewport_rect.size
	
	# Create overlay (but don't block mouse events on children)
	var overlay = ColorRect.new()
	overlay.name = "AgentDialogOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.top_level = true
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 98
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # ✅ Don't block clicks
	root.add_child(overlay)
	
	# Create dialog panel (Pokemon style - bottom of screen)
	var dialog_panel = Panel.new()
	dialog_panel.name = "AgentDialogPanel"
	dialog_panel.z_index = 99
	dialog_panel.top_level = true
	# Responsive clamp (prevents overflow on small resolutions)
	var side_margin: float = clampf(vp_size.x * 0.04, 12.0, 50.0)
	var bottom_margin: float = clampf(vp_size.y * 0.04, 12.0, 30.0)
	var panel_height: float = clampf(vp_size.y * 0.22, 130.0, 180.0)
	var panel_width: float = max(240.0, vp_size.x - (side_margin * 2.0))
	dialog_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	dialog_panel.size = Vector2(panel_width, panel_height)
	dialog_panel.global_position = Vector2(vp_pos.x + side_margin, vp_pos.y + vp_size.y - bottom_margin - panel_height)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.1, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0, 0.8, 1, 1)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.shadow_color = Color(0, 1, 1, 0.3)
	panel_style.shadow_size = 15
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(dialog_panel)
	
	# Main VBox container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_top = 15
	vbox.offset_right = -15
	vbox.offset_bottom = -15
	vbox.add_theme_constant_override("separation", 10)
	dialog_panel.add_child(vbox)
	
	# HBox for portrait + text
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	# Agent01 portrait
	var portrait_panel = Panel.new()
	portrait_panel.custom_minimum_size = Vector2(90, 90)
	var portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.1, 0.15, 0.2, 1)
	portrait_style.border_width_left = 2
	portrait_style.border_width_top = 2
	portrait_style.border_width_right = 2
	portrait_style.border_width_bottom = 2
	portrait_style.border_color = Color(0, 0.8, 1, 1)
	portrait_style.corner_radius_top_left = 8
	portrait_style.corner_radius_top_right = 8
	portrait_style.corner_radius_bottom_left = 8
	portrait_style.corner_radius_bottom_right = 8
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	hbox.add_child(portrait_panel)
	
	var portrait = TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 5
	portrait.offset_top = 5
	portrait.offset_right = -5
	portrait.offset_bottom = -5
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var agent_tex = load("res://asset/icons/AGENT01.png")
	if agent_tex:
		portrait.texture = agent_tex
	portrait_panel.add_child(portrait)
	
	# Dialog text
	var text_label = Label.new()
	text_label.text = dialog_text
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	text_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(text_label)
	
	# Button container (right-aligned)
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_container)
	
	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "Continue ▶"
	continue_btn.custom_minimum_size = Vector2(150, 40)
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.5, 0.6, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0, 1, 1, 1)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0, 0.7, 0.8, 1)
	
	continue_btn.add_theme_stylebox_override("normal", btn_style)
	continue_btn.add_theme_stylebox_override("hover", btn_hover)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_font_size_override("font_size", 16)
	btn_container.add_child(continue_btn)
	
	# Wait for button press
	var dialog_closed = [false]
	continue_btn.pressed.connect(func():
		dialog_closed[0] = true
	)
	
	# Animate entrance
	dialog_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)
	
	# Wait for user to continue
	while not dialog_closed[0]:
		await get_tree().process_frame
	
	# Clean up dialog
	overlay.queue_free()
	dialog_panel.queue_free()
	print("[Landing] Agent01 dialog closed")

func _show_mystery_reward_popup(tutorial_type: String, card_path: String, card_name: String) -> void:
	"""Show Mystery Reward popup with card and XP"""
	print("[Landing] Showing Mystery Reward popup...")
	
	var popup_scene = load("res://scene/tutorial_rewards_popup.tscn")
	if not popup_scene:
		push_error("[Landing] Could not load tutorial rewards popup!")
		return
	
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	# Set "MYSTERY REWARD" banner
	var banner = popup.get_node_or_null("Panel/VBox/CongratsBanner")
	if banner:
		banner.text = "🎁 MYSTERY REWARD 🎁"
	
	# Hide the dialog box (we already showed it separately)
	var dialog_box = popup.get_node_or_null("Panel/VBox/DialogBox")
	if dialog_box:
		dialog_box.visible = false
	
	# Set card image
	var card_image = popup.get_node_or_null("Panel/VBox/CardPanel/CardImage")
	if card_image:
		var card_tex = load(card_path)
		if card_tex:
			card_image.texture = card_tex
	
	# Set card name
	var name_label = popup.get_node_or_null("Panel/VBox/CardNameLabel")
	if name_label:
		name_label.text = card_name
	
	# Set XP
	var xp_label = popup.get_node_or_null("Panel/VBox/XPLabel")
	if xp_label:
		xp_label.text = "+100 XP"
	
	# Add XP to player
	if TutorialManager:
		var source = "Code Breaker Tutorial" if tutorial_type == "code_breaker" else "AkashicTCG Tutorial"
		TutorialManager.add_xp(100, source)
		print("[Landing] Added 100 XP from %s!" % source)
	
	# Wait for claim button
	var reward_claimed = [false]
	var claim_btn = popup.get_node_or_null("Panel/VBox/ClaimButton")
	if claim_btn:
		claim_btn.text = "CLAIM REWARD"
		claim_btn.pressed.connect(func():
			reward_claimed[0] = true
		)
	
	# Wait for claim
	while not reward_claimed[0]:
		await get_tree().process_frame
	
	# Clean up
	popup.queue_free()
	print("[Landing] Mystery Reward claimed!")

# === DEFUSE THE TROJAN GAME ===
func _on_defuse_trojan_card_input(event: InputEvent) -> void:
	"""Handle click on DefuseTheTrojan game card to launch the typing game"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] 🎮 DefuseTheTrojan card clicked - launching game!")
		get_tree().change_scene_to_file("res://scene/defuse_trojan_arena.tscn")
