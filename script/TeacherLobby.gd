extends Control

# ─────────────────────────────────────────────────────────────────────────────
# TeacherLobby.gd
# All 10 slot nodes are defined in TeacherRoomPanel.tscn.
# AvatarTexture and RankTexture are TextureRect nodes — assign textures via
# the player data dictionary: { "name": String, "avatar": Texture2D, "rank_icon": Texture2D }
# Supports both Teacher mode (can start) and Student mode (waiting only).
# ─────────────────────────────────────────────────────────────────────────────

signal quiz_started(room_code: String)
signal lobby_closed
signal game_started(data: Dictionary)  # For student mode when teacher starts

@export var max_player_count: int = 10

@onready var room_name_label: Label = $PanelBg/TopBar/RoomNameLabel
@onready var room_code_label: Label = $PanelBg/TopBar/RoomCodeLabel
@onready var player_count_lbl: Label = $PanelBg/TopBar/PlayerCountLabel
@onready var slot_grid: GridContainer = $PanelBg/SlotGrid
@onready var chat_input: LineEdit = $PanelBg/BottomBar/ChatInput
@onready var start_quiz_btn: Button = $PanelBg/BottomBar/StartQuizButton
@onready var back_button: Button = $PanelBg/TopBar/BackButton

var _room_code: String = ""
var _room_name: String = ""
var _minigame: String = ""
var _difficulty: String = ""
var _players: Array[Dictionary] = []
var _slot_nodes: Array[PanelContainer] = []
var _poll_timer: Timer = null
var _lobby_url: String = ""

# Student mode variables
var _is_student_mode: bool = false
var _game_name: String = ""
var _game_scene: String = ""
var _waiting_label: Label = null
var _dot_timer: Timer = null
var _dot_count: int = 0

# Add Student Number UI (teacher only)
var _add_student_btn: Button = null
var _add_student_popup: PanelContainer = null
var _add_student_input: LineEdit = null
var _add_student_status: Label = null

# Chat system
var _room_type: String = "quiz"  # "quiz" or "gamemode"
var _chat_container: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_poll_timer: Timer = null
var _chat_last_ts: int = 0

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_slot_nodes.clear()
	# Remove static slots baked in the .tscn — slots are rebuilt dynamically
	# in show_lobby() / show_lobby_student_mode() via _build_slots().
	for child in slot_grid.get_children():
		slot_grid.remove_child(child)
		child.queue_free()

	# Wrap SlotGrid in a ScrollContainer so large player counts don't overflow.
	var panel_bg: Control = slot_grid.get_parent()
	var sc := ScrollContainer.new()
	sc.name = "SlotScroll"
	sc.offset_left   = slot_grid.offset_left
	sc.offset_top    = slot_grid.offset_top
	sc.offset_right  = slot_grid.offset_right
	sc.offset_bottom = slot_grid.offset_bottom
	sc.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_bg.remove_child(slot_grid)
	panel_bg.add_child(sc)
	sc.add_child(slot_grid)
	# SlotGrid fills the scroll width and grows vertically.
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

	start_quiz_btn.pressed.connect(_on_start_quiz_pressed)
	back_button.pressed.connect(_on_back_pressed)
	if chat_input:
		chat_input.text_submitted.connect(_on_chat_text_submitted)
		chat_input.placeholder_text = "Type a message..."
	_refresh_player_count_label()
	_build_add_student_ui()
	_build_chat_display()

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────
func show_lobby(room_code: String, room_name: String,
		minigame: String, difficulty: String, player_count: int) -> void:
	_room_code = room_code
	_room_name = room_name
	_minigame = minigame
	_difficulty = difficulty
	_is_student_mode = false
	max_player_count = maxi(player_count, 1)
	_build_slots(max_player_count)

	room_name_label.text = room_name
	room_code_label.text = room_code

	# Reset UI for teacher mode
	if start_quiz_btn:
		start_quiz_btn.visible = true
		start_quiz_btn.text = "Start"
	if chat_input:
		chat_input.visible = true
	if _add_student_btn:
		_add_student_btn.visible = true
	_clear_waiting_label()
	_clear_chat()

	_players.clear()
	_refresh_all_slots()
	_refresh_player_count_label()

## Student mode: Show lobby without start button, waiting for teacher
func show_lobby_student_mode(room_code: String, game_name: String, game_scene: String,
		lobby_url: String, player_count: int = 10) -> void:
	_room_code = room_code
	_room_name = game_name
	_game_name = game_name
	_game_scene = game_scene
	_lobby_url = lobby_url
	_is_student_mode = true
	max_player_count = maxi(player_count, 1)
	_build_slots(max_player_count)

	room_name_label.text = game_name
	room_code_label.text = room_code

	# Hide start button, show waiting message
	if start_quiz_btn:
		start_quiz_btn.visible = false
	if chat_input:
		chat_input.visible = true
	if _add_student_btn:
		_add_student_btn.visible = false
	_create_waiting_label()
	_clear_chat()

	_players.clear()
	_refresh_all_slots()
	_refresh_player_count_label()

	# Start polling for player list and game status
	start_gamemode_polling_student(room_code, lobby_url)

func _create_waiting_label() -> void:
	_clear_waiting_label()
	var bottom_bar := $PanelBg/BottomBar as HBoxContainer
	if not bottom_bar:
		return

	_waiting_label = Label.new()
	_waiting_label.name = "WaitingLabel"
	_waiting_label.text = "⏳ Waiting for teacher to start the game..."
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_waiting_label.add_theme_font_size_override("font_size", 16)
	bottom_bar.add_child(_waiting_label)

	# Animate dots
	_dot_timer = Timer.new()
	_dot_timer.wait_time = 0.5
	_dot_timer.autostart = true
	add_child(_dot_timer)
	_dot_timer.timeout.connect(_animate_waiting_dots)

func _clear_waiting_label() -> void:
	if _waiting_label and is_instance_valid(_waiting_label):
		_waiting_label.queue_free()
		_waiting_label = null
	if _dot_timer and is_instance_valid(_dot_timer):
		_dot_timer.queue_free()
		_dot_timer = null

func _animate_waiting_dots() -> void:
	_dot_count = (_dot_count + 1) % 4
	if _waiting_label and is_instance_valid(_waiting_label):
		var dots := ".".repeat(_dot_count + 1)
		_waiting_label.text = "⏳ Waiting for teacher to start the game" + dots

## CyberQuiz: Start polling server for joined students
func start_server_polling(room_code: String, lobby_url: String) -> void:
	_lobby_url = lobby_url
	_room_type = "quiz"
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_server_players(room_code))
	# Do an immediate first poll
	_poll_server_players(room_code)
	_start_chat_polling(room_code)

## GameMode: Start polling server for joined students (gamemode endpoint)
func start_gamemode_polling(room_code: String, lobby_url: String) -> void:
	_lobby_url = lobby_url
	_room_type = "gamemode"
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_gamemode_players(room_code))
	# Do an immediate first poll
	_poll_gamemode_players(room_code)
	_start_chat_polling(room_code)

func stop_server_polling() -> void:
	if _poll_timer:
		_poll_timer.queue_free()
		_poll_timer = null
	_stop_chat_polling()

func _poll_server_players(room_code: String) -> void:
	if _lobby_url.is_empty(): return
	var url := _lobby_url + "/api/quiz/%s/info" % room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200: return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		var server_players: Array = data.get("players", [])
		_sync_players_from_server(server_players)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _sync_players_from_server(server_players: Array) -> void:
	# Build a list of player names already in _players
	var current_names: Array[String] = []
	for p in _players:
		current_names.append(p.get("name", ""))
	# Add new players with avatar + rank
	for sp in server_players:
		var uname: String = str(sp.get("username", ""))
		if uname.is_empty(): continue
		if uname not in current_names:
			var avatar_file: String = str(sp.get("avatar", "default.png"))
			var xp_val: int = int(sp.get("xp", 0))
			print("[Lobby] Adding player: %s | avatar='%s' | xp=%d" % [uname, avatar_file, xp_val])
			var avatar_tex := _load_avatar_texture(avatar_file)
			var rank_tex := _load_rank_texture_from_xp(xp_val)
			print("[Lobby]   avatar_tex=%s | rank_tex=%s" % [str(avatar_tex), str(rank_tex)])
			add_player(uname, avatar_tex, rank_tex)
	# Remove players that left
	var server_names: Array[String] = []
	for sp in server_players:
		server_names.append(str(sp.get("username", "")))
	for p in _players.duplicate():
		if p.get("name", "") not in server_names:
			remove_player(p.get("name", ""))

## Load avatar texture from filename (e.g., "avatar1.png")
func _load_avatar_texture(avatar_file: String) -> Texture2D:
	print("[Lobby] _load_avatar_texture called with: '%s'" % avatar_file)
	if avatar_file.is_empty():
		print("[Lobby]   → skipping (empty)")
		return null
	# Handle different avatar path formats
	var path: String
	if avatar_file.begins_with("res://"):
		path = avatar_file
	elif avatar_file.begins_with("user://"):
		# Custom avatar - load from user data
		if FileAccess.file_exists(avatar_file):
			var img := Image.load_from_file(avatar_file)
			if img:
				img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
				return ImageTexture.create_from_image(img)
		print("[Lobby]   → user:// file not found")
		return null
	else:
		# Just a filename like "avatar1.png"
		path = "res://asset/avatars/" + avatar_file
	print("[Lobby]   → trying path: '%s' | exists=%s" % [path, str(ResourceLoader.exists(path))])
	if ResourceLoader.exists(path):
		var tex = load(path)
		print("[Lobby]   → loaded tex: %s | is Texture2D: %s" % [str(tex), str(tex is Texture2D)])
		if tex is Texture2D:
			return tex as Texture2D
	return null

## Load rank icon texture from XP value (uses TutorialManager.RANK_THRESHOLDS)
func _load_rank_texture_from_xp(xp: int) -> Texture2D:
	# Use TutorialManager to get the correct rank based on XP
	if TutorialManager:
		var rank: Dictionary = TutorialManager.get_rank(xp)
		var rank_icon: String = rank.get("icon", "")
		if not rank_icon.is_empty() and ResourceLoader.exists(rank_icon):
			var tex = load(rank_icon)
			if tex is Texture2D:
				return tex as Texture2D
	# Fallback: Iron rank
	var fallback_path := "res://asset/rankicon/IRON.png"
	if ResourceLoader.exists(fallback_path):
		var tex = load(fallback_path)
		if tex is Texture2D:
			return tex as Texture2D
	return null

func _poll_gamemode_players(room_code: String) -> void:
	if _lobby_url.is_empty(): return
	var url := _lobby_url + "/api/gamemode/%s/info" % room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200: return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		var server_players: Array = data.get("players", [])
		_sync_players_from_server(server_players)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

## Student mode polling: Also checks if game started
func start_gamemode_polling_student(room_code: String, lobby_url: String) -> void:
	_lobby_url = lobby_url
	_room_type = "gamemode"
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_gamemode_student(room_code))
	# Immediate first poll
	_poll_gamemode_student(room_code)
	_start_chat_polling(room_code)

func _poll_gamemode_student(room_code: String) -> void:
	if _lobby_url.is_empty(): return
	var url := _lobby_url + "/api/gamemode/%s/info" % room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200: return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return

		# Update player list
		var server_players: Array = data.get("players", [])
		_sync_players_from_server(server_players)

		# Check if game started
		var status: String = data.get("status", "waiting")
		if status == "active":
			_on_game_started_student(data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _on_game_started_student(data: Dictionary) -> void:
	# Stop polling
	stop_server_polling()
	_clear_waiting_label()

	# Update waiting label to show starting
	if _waiting_label == null:
		var bottom_bar := $PanelBg/BottomBar as HBoxContainer
		if bottom_bar:
			_waiting_label = Label.new()
			_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_waiting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_waiting_label.add_theme_font_size_override("font_size", 16)
			bottom_bar.add_child(_waiting_label)
	if _waiting_label:
		_waiting_label.text = "🚀 Game starting..."
		_waiting_label.add_theme_color_override("font_color", Color(0.3, 1, 0.5))

	# Emit signal for parent to handle
	emit_signal("game_started", data)

# player dict: { "name": String, "avatar": Texture2D (optional), "rank_icon": Texture2D (optional) }
func add_player(player_name: String, avatar: Texture2D = null, rank_icon: Texture2D = null) -> void:
	if _players.size() >= max_player_count:
		return
	_players.append({"name": player_name, "avatar": avatar, "rank_icon": rank_icon})
	_refresh_all_slots()
	_refresh_player_count_label()

func remove_player(player_name: String) -> void:
	for i in _players.size():
		if _players[i]["name"] == player_name:
			_players.remove_at(i)
			break
	_refresh_all_slots()
	_refresh_player_count_label()

# ─────────────────────────────────────────────────────────────────────────────
# SLOT REFRESH
# ─────────────────────────────────────────────────────────────────────────────

## Dynamically create `count` slot nodes, replacing any existing ones.
## This allows the lobby to support any player count at runtime.
func _build_slots(count: int) -> void:
	for child in slot_grid.get_children():
		slot_grid.remove_child(child)
		child.queue_free()
	_slot_nodes.clear()

	for i in count:
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % (i + 1)
		slot.custom_minimum_size = Vector2(150, 220)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", _slot_style(false))

		# Use a proper VBoxContainer for vertical alignment
		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)
		slot.add_child(vbox)

		# Spacer top
		var spacer_top := Control.new()
		spacer_top.custom_minimum_size = Vector2(0, 8)
		vbox.add_child(spacer_top)

		# Avatar centered
		var avatar_center := CenterContainer.new()
		avatar_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(avatar_center)

		var avatar_pan := PanelContainer.new()
		avatar_pan.name = "AvatarPanel"
		avatar_pan.custom_minimum_size = Vector2(72, 72)
		avatar_pan.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		avatar_pan.add_theme_stylebox_override("panel", _avatar_style(false))
		avatar_center.add_child(avatar_pan)

		var avatar_tex := TextureRect.new()
		avatar_tex.name = "AvatarTexture"
		avatar_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avatar_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		avatar_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_tex.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		avatar_pan.add_child(avatar_tex)

		# Border overlay panel (child of AvatarPanel, after AvatarTexture)
		var border_style := StyleBoxFlat.new()
		border_style.draw_center = false
		border_style.border_width_left = 2
		border_style.border_width_top = 2
		border_style.border_width_right = 2
		border_style.border_width_bottom = 2
		border_style.border_color = Color("#25e0fd")
		border_style.corner_radius_top_left = 40
		border_style.corner_radius_top_right = 40
		border_style.corner_radius_bottom_left = 40
		border_style.corner_radius_bottom_right = 40

		var border_pan := Panel.new()
		border_pan.name = "border"
		border_pan.layout_mode = 1  # Anchors mode
		border_pan.anchor_left = 0.0
		border_pan.anchor_top = 0.0
		border_pan.anchor_right = 1.0
		border_pan.anchor_bottom = 1.0
		border_pan.offset_left = 0
		border_pan.offset_top = 0
		border_pan.offset_right = 0
		border_pan.offset_bottom = 0
		border_pan.add_theme_stylebox_override("panel", border_style)
		avatar_pan.add_child(border_pan)

		# NameLabel centered
		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1, 0.45))
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.text = "Name"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		vbox.add_child(name_lbl)

		# RankPanel centered
		var rank_center := CenterContainer.new()
		rank_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(rank_center)

		var rank_pan := PanelContainer.new()
		rank_pan.name = "RankPanel"
		rank_pan.custom_minimum_size = Vector2(70, 50)
		rank_pan.add_theme_stylebox_override("panel", _rank_style())
		rank_center.add_child(rank_pan)

		var rank_tex := TextureRect.new()
		rank_tex.name = "RankTexture"
		rank_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rank_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rank_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rank_pan.add_child(rank_tex)

		slot_grid.add_child(slot)
		_slot_nodes.append(slot)
		
func _refresh_all_slots() -> void:
	for idx in _slot_nodes.size():
		var slot: PanelContainer = _slot_nodes[idx]
		var vbox = slot.get_child(0)
		# Navigate the VBox layout: SpacerTop, AvatarCenter > AvatarPanel > AvatarTexture, NameLabel, RankCenter > RankPanel > RankTexture
		var avatar_pan: PanelContainer = vbox.get_child(1).get_child(0)  # AvatarCenter > AvatarPanel
		var avatar_tex: TextureRect = avatar_pan.get_node("AvatarTexture")
		var name_lbl: Label = vbox.get_child(2)  # NameLabel
		var rank_pan: PanelContainer = vbox.get_child(3).get_child(0)  # RankCenter > RankPanel
		var rank_tex: TextureRect = rank_pan.get_node("RankTexture")

		if idx < _players.size():
			var p: Dictionary = _players[idx]
			# Avatar
			avatar_tex.texture = p.get("avatar", null)
			print("[Lobby] Slot %d → name=%s avatar_tex=%s" % [idx, p["name"], str(avatar_tex.texture)])
			avatar_pan.add_theme_stylebox_override("panel", _avatar_style(true))
			# Name
			name_lbl.text = p["name"]
			name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			# Rank icon
			rank_tex.texture = p.get("rank_icon", null)
			rank_pan.modulate = Color(1, 1, 1, 1)
			# Slot glow
			slot.add_theme_stylebox_override("panel", _slot_style(true))
			slot.visible = true
		elif idx < max_player_count:
			avatar_tex.texture = null
			avatar_pan.add_theme_stylebox_override("panel", _avatar_style(false))
			name_lbl.text = "Name"
			name_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1, 0.45))
			rank_tex.texture = null
			rank_pan.modulate = Color(1, 1, 1, 0.45)
			slot.add_theme_stylebox_override("panel", _slot_style(false))
			slot.visible = true
		else:
			slot.visible = false

func _refresh_player_count_label() -> void:
	if player_count_lbl:
		player_count_lbl.text = "%d / %d" % [_players.size(), max_player_count]

# ─────────────────────────────────────────────────────────────────────────────
# STYLE HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _slot_style(filled: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.border_width_left = 0
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.bg_color = Color("#00367D")
	if filled:
		s.shadow_color = Color(0.0, 1.0, 1.0, 0.35)
		s.shadow_size = 6
	else:
		s.shadow_size = 0
	return s

func _avatar_style(filled: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 40
	s.corner_radius_top_right = 40
	s.corner_radius_bottom_left = 40
	s.corner_radius_bottom_right = 40
	s.bg_color = Color(0.04, 0.1, 0.24, 0.85)
	s.border_color = Color(0.0, 0.85, 1.0, 0.85) if filled else Color(0.14, 0.58, 0.75, 0.5)
	s.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
	s.shadow_size = 4 if filled else 0
	return s

func _rank_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.12, 0.28, 0.9)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.14, 0.58, 0.75, 0.6)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s
# ─────────────────────────────────────────────────────────────────────────────
# BUTTON HANDLERS
# ─────────────────────────────────────────────────────────────────────────────
func _on_start_quiz_pressed() -> void:
	print("[Lobby] Starting quiz | Room: %s | Game: %s | Players: %d" % [
		_room_code, _minigame, _players.size()])
	stop_server_polling()
	# Immediately emit quiz_started so the server POST happens NOW
	emit_signal("quiz_started", _room_code)
	start_quiz_btn.text = "Statistics"
	start_quiz_btn.pressed.disconnect(_on_start_quiz_pressed)
	start_quiz_btn.pressed.connect(_on_statistics_pressed)

func _on_statistics_pressed() -> void:
	# Quiz already started — just re-enter the stats view
	emit_signal("quiz_started", _room_code)

func _on_back_pressed() -> void:
	stop_server_polling()
	emit_signal("lobby_closed")
	visible = false

# ─────────────────────────────────────────────────────────────────────────────
# ADD STUDENT NUMBER (teacher in-lobby)
# ─────────────────────────────────────────────────────────────────────────────
func _build_add_student_ui() -> void:
	var bottom_bar = get_node_or_null("PanelBg/BottomBar")
	if not bottom_bar:
		return

	# ── Button in BottomBar ──
	_add_student_btn = Button.new()
	_add_student_btn.name = "AddStudentBtn"
	_add_student_btn.text = "+ Student"
	_add_student_btn.custom_minimum_size = Vector2(110, 36)
	_add_student_btn.visible = false  # shown when show_lobby() is called in teacher mode
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.0, 0.25, 0.35, 0.9)
	btn_sb.border_color = Color(0.145, 0.878, 0.992, 0.6)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(6)
	btn_sb.set_content_margin_all(4)
	_add_student_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hov := btn_sb.duplicate()
	btn_hov.bg_color = Color(0.0, 0.35, 0.5, 0.9)
	_add_student_btn.add_theme_stylebox_override("hover", btn_hov)
	_add_student_btn.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	_add_student_btn.add_theme_font_size_override("font_size", 13)
	_add_student_btn.pressed.connect(_on_add_student_btn_pressed)
	bottom_bar.add_child(_add_student_btn)
	# Move before StartQuizButton so layout is: ChatInput | +Student | Start
	var start_idx := start_quiz_btn.get_index()
	bottom_bar.move_child(_add_student_btn, start_idx)

	# ── Floating popup ──
	_add_student_popup = PanelContainer.new()
	_add_student_popup.name = "AddStudentPopup"
	_add_student_popup.visible = false
	_add_student_popup.z_index = 10
	_add_student_popup.custom_minimum_size = Vector2(340, 0)
	var pop_sb := StyleBoxFlat.new()
	pop_sb.bg_color = Color(0.02, 0.06, 0.16, 0.97)
	pop_sb.border_color = Color(0.145, 0.878, 0.992, 0.7)
	pop_sb.set_border_width_all(2)
	pop_sb.set_corner_radius_all(10)
	pop_sb.set_content_margin_all(14)
	_add_student_popup.add_theme_stylebox_override("panel", pop_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_add_student_popup.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Add Student Number"
	title_lbl.add_theme_color_override("font_color", Color(0.145, 0.878, 0.992))
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "Comma-separated (e.g. 21-2169, 21-2170)"
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0, 0.5))
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)

	_add_student_input = LineEdit.new()
	_add_student_input.placeholder_text = "21-2169, 21-2170..."
	_add_student_input.custom_minimum_size = Vector2(0, 36)
	_add_student_input.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	_add_student_input.add_theme_color_override("caret_color", Color(0.145, 0.878, 0.992))
	_add_student_input.add_theme_font_size_override("font_size", 13)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color(0.02, 0.05, 0.14, 1.0)
	input_sb.border_color = Color(0.145, 0.878, 0.992, 0.4)
	input_sb.set_border_width_all(2)
	input_sb.set_corner_radius_all(6)
	input_sb.set_content_margin_all(8)
	_add_student_input.add_theme_stylebox_override("normal", input_sb)
	_add_student_input.text_submitted.connect(func(_t): _on_add_student_submit())
	vbox.add_child(_add_student_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(90, 32)
	var cancel_sb := StyleBoxFlat.new()
	cancel_sb.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	cancel_sb.border_color = Color(0.5, 0.5, 0.6, 0.4)
	cancel_sb.set_border_width_all(1)
	cancel_sb.set_corner_radius_all(6)
	cancel_btn.add_theme_stylebox_override("normal", cancel_sb)
	cancel_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.pressed.connect(_on_add_student_cancel)
	btn_row.add_child(cancel_btn)

	var submit_btn := Button.new()
	submit_btn.text = "Add"
	submit_btn.custom_minimum_size = Vector2(90, 32)
	var sub_sb := StyleBoxFlat.new()
	sub_sb.bg_color = Color(0.0, 0.35, 0.5, 0.9)
	sub_sb.border_color = Color(0.145, 0.878, 0.992, 0.7)
	sub_sb.set_border_width_all(1)
	sub_sb.set_corner_radius_all(6)
	submit_btn.add_theme_stylebox_override("normal", sub_sb)
	submit_btn.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	submit_btn.add_theme_font_size_override("font_size", 12)
	submit_btn.pressed.connect(_on_add_student_submit)
	btn_row.add_child(submit_btn)

	_add_student_status = Label.new()
	_add_student_status.text = ""
	_add_student_status.add_theme_font_size_override("font_size", 11)
	_add_student_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_student_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_add_student_status)

	# Add popup to PanelBg so it floats above content
	var panel_bg = get_node_or_null("PanelBg")
	if panel_bg:
		panel_bg.add_child(_add_student_popup)
	# Position will be set when shown

func _on_add_student_btn_pressed() -> void:
	if not _add_student_popup:
		return
	_add_student_popup.visible = not _add_student_popup.visible
	if _add_student_popup.visible:
		_add_student_input.text = ""
		_add_student_status.text = ""
		# Position above the bottom bar
		await get_tree().process_frame
		var panel_bg = get_node_or_null("PanelBg")
		if panel_bg:
			var pb_size: Vector2 = panel_bg.size
			var pop_size: Vector2 = _add_student_popup.size
			_add_student_popup.position = Vector2(
				(pb_size.x - pop_size.x) / 2.0,
				pb_size.y - pop_size.y - 60
			)
		_add_student_input.grab_focus()

func _on_add_student_cancel() -> void:
	if _add_student_popup:
		_add_student_popup.visible = false

func _on_add_student_submit() -> void:
	if not _add_student_input:
		return
	var raw := _add_student_input.text.strip_edges()
	if raw.is_empty():
		_add_student_status.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		_add_student_status.text = "Please enter at least one student number."
		return

	# Parse comma-separated
	var parts := raw.split(",")
	var student_numbers: Array = []
	for p in parts:
		var trimmed := p.strip_edges()
		if not trimmed.is_empty():
			student_numbers.append(trimmed)

	if student_numbers.is_empty():
		_add_student_status.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		_add_student_status.text = "Please enter at least one student number."
		return

	_add_student_status.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_add_student_status.text = "Adding..."

	# Determine which endpoint to use (quiz or gamemode)
	var endpoint_type := "quiz"
	if not _minigame.is_empty() and _minigame != "Multiple Choice":
		endpoint_type = "gamemode"

	var url := _lobby_url + "/api/%s/%s/add-students" % [endpoint_type, _room_code]
	var body := {
		"host_id": Auth.current_local_id,
		"student_numbers": student_numbers,
	}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			var text: String = resp_body.get_string_from_utf8()
			var data = JSON.parse_string(text)
			var added_count := 0
			var total_count := 0
			if typeof(data) == TYPE_DICTIONARY:
				added_count = int(data.get("added", 0))
				total_count = int(data.get("total", 0))
			_add_student_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			_add_student_status.text = "Added %d student(s). Total whitelist: %d" % [added_count, total_count]
			_add_student_input.text = ""
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			var err_data = JSON.parse_string(err_text)
			var msg := "Failed to add students."
			if typeof(err_data) == TYPE_DICTIONARY:
				msg = err_data.get("error", msg)
			_add_student_status.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			_add_student_status.text = msg
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		_add_student_status.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		_add_student_status.text = "Network error."

# ─────────────────────────────────────────────────────────────────────────────
# CHAT SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

## Build the chat display area between SlotGrid and BottomBar
func _build_chat_display() -> void:
	var panel_bg: Control = $PanelBg
	if not panel_bg:
		return

	# Create a ScrollContainer for chat messages
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.name = "ChatScroll"
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Position it just above the BottomBar
	_chat_scroll.offset_left = 15
	_chat_scroll.offset_top = 460
	_chat_scroll.offset_right = 508
	_chat_scroll.offset_bottom = 508
	panel_bg.add_child(_chat_scroll)

	_chat_container = VBoxContainer.new()
	_chat_container.name = "ChatMessages"
	_chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_container.add_theme_constant_override("separation", 2)
	_chat_scroll.add_child(_chat_container)

func _clear_chat() -> void:
	_chat_last_ts = 0
	if _chat_container:
		for child in _chat_container.get_children():
			child.queue_free()

func _on_chat_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	chat_input.text = ""
	_send_chat_message(text.strip_edges())

func _send_chat_message(msg: String) -> void:
	if _lobby_url.is_empty() or _room_code.is_empty():
		return

	var username: String = ""
	if Auth and Auth.current_username:
		username = Auth.current_username
	else:
		username = "Teacher"

	var api_path: String = "quiz" if _room_type == "quiz" else "gamemode"
	var url := _lobby_url + "/api/%s/%s/chat" % [api_path, _room_code]
	var body := {"username": username, "message": msg}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			# Add own message immediately to display
			_add_chat_message_to_display(username, msg)
		else:
			print("[Chat] ❌ Failed to send message: HTTP %d" % code)
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		print("[Chat] ❌ HTTP request failed: %d" % err)

func _start_chat_polling(room_code: String) -> void:
	_stop_chat_polling()
	_chat_poll_timer = Timer.new()
	_chat_poll_timer.wait_time = 3.0
	_chat_poll_timer.autostart = true
	add_child(_chat_poll_timer)
	_chat_poll_timer.timeout.connect(func(): _poll_chat_messages(room_code))
	# Immediate first poll
	_poll_chat_messages(room_code)

func _stop_chat_polling() -> void:
	if _chat_poll_timer:
		_chat_poll_timer.queue_free()
		_chat_poll_timer = null

func _poll_chat_messages(room_code: String) -> void:
	if _lobby_url.is_empty():
		return

	var api_path: String = "quiz" if _room_type == "quiz" else "gamemode"
	var url := _lobby_url + "/api/%s/%s/chat?since=%d" % [api_path, room_code, _chat_last_ts]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			return
		var messages: Array = data.get("messages", [])
		var my_username := ""
		if Auth and Auth.current_username:
			my_username = Auth.current_username
		for msg_data in messages:
			var uname: String = str(msg_data.get("username", ""))
			var msg_text: String = str(msg_data.get("message", ""))
			var ts: int = int(msg_data.get("timestamp", 0))
			# Skip own messages (already displayed on send)
			if uname == my_username:
				if ts > _chat_last_ts:
					_chat_last_ts = ts
				continue
			_add_chat_message_to_display(uname, msg_text)
			if ts > _chat_last_ts:
				_chat_last_ts = ts
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _add_chat_message_to_display(username: String, msg: String) -> void:
	if not _chat_container:
		return
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Color the username differently
	var color_hex := "00d4ff"
	if Auth and Auth.current_username and username == Auth.current_username:
		color_hex = "4dff8d"  # Green for own messages
	lbl.text = "[color=#%s]%s:[/color] %s" % [color_hex, username, msg]
	lbl.add_theme_font_size_override("normal_font_size", 12)
	_chat_container.add_child(lbl)

	# Keep max 50 messages displayed
	while _chat_container.get_child_count() > 50:
		var oldest = _chat_container.get_child(0)
		_chat_container.remove_child(oldest)
		oldest.queue_free()

	# Auto-scroll to bottom
	if _chat_scroll:
		await get_tree().process_frame
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)
