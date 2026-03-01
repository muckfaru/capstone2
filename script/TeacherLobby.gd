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
	sc.layout_mode = 0
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
	# Switch SlotGrid to container-based layout so it fills the scroll width
	# and grows vertically with its content.
	slot_grid.layout_mode          = 2
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

	start_quiz_btn.pressed.connect(_on_start_quiz_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_player_count_label()

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
	max_player_count = clampi(player_count, 1, 50)
	_build_slots(max_player_count)

	room_name_label.text = room_name
	room_code_label.text = room_code

	# Reset UI for teacher mode
	if start_quiz_btn:
		start_quiz_btn.visible = true
		start_quiz_btn.text = "Start"
	if chat_input:
		chat_input.visible = true
	_clear_waiting_label()

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
	max_player_count = clampi(player_count, 1, 50)
	_build_slots(max_player_count)

	room_name_label.text = game_name
	room_code_label.text = room_code

	# Hide start button, show waiting message
	if start_quiz_btn:
		start_quiz_btn.visible = false
	if chat_input:
		chat_input.visible = false
	_create_waiting_label()

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
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_server_players(room_code))
	# Do an immediate first poll
	_poll_server_players(room_code)

## GameMode: Start polling server for joined students (gamemode endpoint)
func start_gamemode_polling(room_code: String, lobby_url: String) -> void:
	_lobby_url = lobby_url
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_gamemode_players(room_code))
	# Do an immediate first poll
	_poll_gamemode_players(room_code)

func stop_server_polling() -> void:
	if _poll_timer:
		_poll_timer.queue_free()
		_poll_timer = null

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
	if avatar_file.is_empty() or avatar_file == "default.png":
		print("[Lobby]   → skipping (empty or default)")
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
	stop_server_polling()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(func(): _poll_gamemode_student(room_code))
	# Immediate first poll
	_poll_gamemode_student(room_code)

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
## This allows the lobby to support any player count (1–50) at runtime.
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
		avatar_pan.add_theme_stylebox_override("panel", _avatar_style(false))
		avatar_center.add_child(avatar_pan)

		var avatar_tex := TextureRect.new()
		avatar_tex.name = "AvatarTexture"
		avatar_tex.layout_mode = 2
		avatar_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avatar_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		avatar_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_pan.add_child(avatar_tex)

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
		rank_tex.layout_mode = 2
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
