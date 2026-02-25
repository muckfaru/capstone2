extends Control

# ─────────────────────────────────────────────────────────────────────────────
# TeacherLobby.gd
# All 10 slot nodes are defined in TeacherRoomPanel.tscn.
# AvatarTexture and RankTexture are TextureRect nodes — assign textures via
# the player data dictionary: { "name": String, "avatar": Texture2D, "rank_icon": Texture2D }
# ─────────────────────────────────────────────────────────────────────────────

signal quiz_started(room_code: String)
signal lobby_closed

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

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_slot_nodes.clear()
	for child in slot_grid.get_children():
		if child is PanelContainer:
			_slot_nodes.append(child as PanelContainer)

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
	max_player_count = mini(player_count, _slot_nodes.size())

	room_name_label.text = room_name
	room_code_label.text = room_code

	_players.clear()
	_refresh_all_slots()
	_refresh_player_count_label()

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
	# Add new players
	for sp in server_players:
		var uname: String = sp.get("username", "")
		if uname.is_empty(): continue
		if uname not in current_names:
			add_player(uname)
	# Remove players that left
	var server_names: Array[String] = []
	for sp in server_players:
		server_names.append(sp.get("username", ""))
	for p in _players.duplicate():
		if p.get("name", "") not in server_names:
			remove_player(p.get("name", ""))

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
func _refresh_all_slots() -> void:
	for idx in _slot_nodes.size():
		var slot: PanelContainer = _slot_nodes[idx]
		var vbox: VBoxContainer = slot.get_child(0)
		var avatar_pan: PanelContainer = vbox.get_node("AvatarPanel")
		var avatar_tex: TextureRect = avatar_pan.get_node("AvatarTexture")
		var name_lbl: Label = vbox.get_node("NameLabel")
		var rank_pan: PanelContainer = vbox.get_node("RankPanel")
		var rank_tex: TextureRect = rank_pan.get_node("RankTexture")

		if idx < _players.size():
			var p: Dictionary = _players[idx]
			# Avatar
			avatar_tex.texture = p.get("avatar", null)
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
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	if filled:
		s.bg_color = Color(0.0, 0.18, 0.28, 0.95)
		s.border_color = Color(0.0, 0.85, 1.0, 0.85)
		s.shadow_color = Color(0.0, 1.0, 1.0, 0.35)
		s.shadow_size = 6
	else:
		s.bg_color = Color(0.04, 0.07, 0.18, 0.92)
		s.border_color = Color(0.14, 0.58, 0.75, 0.5)
		s.shadow_size = 0
	return s

func _avatar_style(filled: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 28
	s.corner_radius_top_right = 28
	s.corner_radius_bottom_left = 28
	s.corner_radius_bottom_right = 28
	s.bg_color = Color(0.04, 0.1, 0.24, 0.85)
	s.border_color = Color(0.0, 0.85, 1.0, 0.85) if filled else Color(0.14, 0.58, 0.75, 0.5)
	s.shadow_color = Color(0.0, 1.0, 1.0, 0.3)
	s.shadow_size = 4 if filled else 0
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