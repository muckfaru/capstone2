extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")
const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")

# === UI References ===
@onready var news_panel = $VideoStreamPlayer/HomePanel/NewsPanel
@onready var mission_button: Button
@onready var welcome_ui := $PokemonStyleWelcomeUI
@onready var username_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/usernameInput
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
@onready var tutorial_btn: Button = $VideoStreamPlayer/ProfilePanel/UserPanel/TutorialButton
@onready var avatar_picker: PopupPanel = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker
@onready var avatar_grid: GridContainer = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker/GridContainer
@onready var menu_panel: Control = $MenuPanel

# === Avatars & User Data ===
var avatars: Dictionary = {}
var selected_avatar: String = ""
var last_avatar_change: int = 0
var avatar_cooldown: int = 2592000 # 30 days
var first_mission_active: bool = false

var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"
var http: HTTPRequest

# ✅ CRITICAL: Flag to prevent duplicate welcome bonus
var welcome_bonus_awarded: bool = false

# Resume retry guard (prevents infinite loops if server is down)
var _code_breaker_resume_retries: int = 0
var _tgc_resume_retries: int = 0
var _resume_routed: bool = false

# === Lifecycle ===
func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)

	_load_avatars()
	change_btn.pressed.connect(_on_change_avatar_pressed)
	save_btn.pressed.connect(_on_save_profile_pressed)
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	
	# ✅ OPTIMIZATION: Load user data first (includes welcome tutorial check)
	_load_user_data_and_check_tutorial()
	
	_instantiate_chat_panel()
	Auth.set_user_online()
	
	# ✅ Connect XP signals
	if not TutorialManager.xp_updated.is_connected(_on_xp_updated):
		TutorialManager.xp_updated.connect(_on_xp_updated)
	if not TutorialManager.rank_up.is_connected(_on_rank_up):
		TutorialManager.rank_up.connect(_on_rank_up)
	if not TutorialManager.data_loaded.is_connected(_update_xp_display):
		TutorialManager.data_loaded.connect(_update_xp_display)
	
	TutorialManager.load_user_data()
	call_deferred("_update_xp_display")

	_setup_navigation()
	_setup_mission_system()

	# If the app was restarted (shutdown/crash) while in a Code Breaker room/match,
	# attempt to resume by routing into the reconnect flow.
	call_deferred("_try_resume_code_breaker_session")
	call_deferred("_try_resume_akashic_tcg_session")

	# ===== POKEMON WELCOME UI SETUP =====
	if welcome_ui:
		print("[Landing] ✅ PokemonStyleWelcomeUI found in scene tree")
		welcome_ui.layer = 100
		welcome_ui.visible = false
		
		# ✅ Disconnect any existing connections first
		if welcome_ui.tutorial_completed.is_connected(_on_welcome_tutorial_completed):
			welcome_ui.tutorial_completed.disconnect(_on_welcome_tutorial_completed)
		
		# Connect with ONE_SHOT to prevent multiple calls
		welcome_ui.tutorial_completed.connect(_on_welcome_tutorial_completed, CONNECT_ONE_SHOT)
		print("[Landing] ✅ Connected tutorial_completed signal (ONE_SHOT)")
	else:
		push_error("[Landing] ❌ PokemonStyleWelcomeUI node not found!")
	

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
	mission_button.add_theme_color_override("font_hover_color", Color.WHITE)  # No color change on hover
	mission_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	mission_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mission_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	mission_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	
	# Add black divider line below
	var divider = ColorRect.new()
	divider.name = "MissionDivider"
	divider.size = Vector2(380, 2)
	divider.position = Vector2(10, 115)  # Below the text
	divider.color = Color(0, 0, 0, 1)  # Black color
	
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
	tween.set_loops(5)  # Pulse 5 times
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
	panel_style.bg_color = Color(0.05, 0.1, 0.15, 0.95)  # Dark blue-ish background
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0, 0.9, 1, 0.8)  # Cyan border
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
	mission_title.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
	mission_title.add_theme_font_size_override("font_size", 28)
	dialog_panel.add_child(mission_title)
	
	# Description
	var description = Label.new()
	description.text = "Your First Cyber Arena Mission is to learn the basics of cybersecurity and \nhow to protect yourself online against threats!"
	description.position = Vector2(40, 110)
	description.size = Vector2(620, 80)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
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
	mission_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
	mission_label.add_theme_font_size_override("font_size", 16)
	dialog_panel.add_child(mission_label)
	
	# Reward
	var reward_label = Label.new()
	reward_label.text = "REWARD: 50 XP"
	reward_label.position = Vector2(40, 310)
	reward_label.size = Vector2(620, 30)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
	reward_label.add_theme_font_size_override("font_size", 18)
	dialog_panel.add_child(reward_label)
	
	# Challenge text
	var challenge_label = Label.new()
	challenge_label.text = "This is your first real test, Agent. Can you handle it?"
	challenge_label.position = Vector2(40, 345)
	challenge_label.size = Vector2(620, 30)
	challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	challenge_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
	challenge_label.add_theme_font_size_override("font_size", 16)
	dialog_panel.add_child(challenge_label)
	
	# Accept Mission Button (centered)
	var accept_btn = Button.new()
	accept_btn.text = "Accept Mission"
	accept_btn.custom_minimum_size = Vector2(200, 40)
	accept_btn.position = Vector2(175, 395)  # Centered: (700 - 450) / 2 = 125, then 125 + 50 = 175
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
	later_btn.position = Vector2(395, 395)  # 175 + 200 (button width) + 20 (gap) = 395
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


func _complete_first_mission() -> void:
	"""Mark first mission as completed"""
	first_mission_active = false
	
	if mission_button:
		mission_button.visible = false
	
	var divider = news_panel.get_node_or_null("MissionDivider")
	if divider:
		divider.visible = false
	
	# Save to Firestore
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		return
	
	var url = "%s/%s?updateMask.fieldPaths=first_mission_completed" % [firestore_base_url, user_id]
	var body = {
		"fields": {
			"first_mission_completed": { "booleanValue": true }
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
			print("[Landing] ✅ First mission marked complete")
	)
	http_mission.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))





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
		# Assume new user
		Auth.set_welcome_tutorial_status(false)
		_start_welcome_tutorial()
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data.has("fields"):
		Auth.set_welcome_tutorial_status(false)
		_start_welcome_tutorial()
		return

	var f = data["fields"]
	
	# ✅ Load user profile data
	if f.has("avatar"):
		selected_avatar = f["avatar"]["stringValue"]
		if avatars.has(selected_avatar):
			profile_pic.texture = avatars[selected_avatar]
			Auth.current_avatar = selected_avatar

	if f.has("last_avatar_change"):
		last_avatar_change = int(f["last_avatar_change"]["integerValue"])

	if f.has("username"):
		Auth.current_username = f["username"]["stringValue"]
		username_input.text = Auth.current_username

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
	
	# ✅ Check welcome tutorial status
	var welcome_completed := true  # Default for existing users
	if f.has("welcome_tutorial_completed"):
		welcome_completed = f["welcome_tutorial_completed"].get("booleanValue", true)
		print("[Landing] welcome_tutorial_completed:", welcome_completed)
	else:
		print("[Landing] welcome_tutorial_completed field NOT found - NEW USER!")
		welcome_completed = false
	
	# ✅ Cache the status
	Auth.set_welcome_tutorial_status(welcome_completed)
	
	# ✅ Show Pokemon UI if new user
	if not welcome_completed:
		print("[Landing] 🎉 NEW USER DETECTED - Starting Pokemon Welcome Tutorial")
		_start_welcome_tutorial()
	else:
		print("[Landing] ✅ Welcome tutorial already completed")


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
	call_deferred("_show_welcome_reward")
	call_deferred("_activate_first_mission")

func _show_welcome_reward() -> void:
	"""Show a reward dialog after completing the tutorial"""
	print("[Landing] ========== SHOW WELCOME REWARD ==========")
	print("[Landing] Current XP BEFORE reward: %d" % TutorialManager.total_xp)
	
	# ✅ Double-check we haven't awarded this already
	if TutorialManager.total_xp >= 50:
		print("[Landing] ⚠️ User already has XP, might be duplicate call. Current XP: %d" % TutorialManager.total_xp)
	
	# Award XP FIRST
	print("[Landing] Awarding welcome bonus XP (+50)...")
	TutorialManager.add_xp(50, "Tutorial Completion Bonus")
	
	# Wait a frame to ensure all XP processing is done
	await get_tree().process_frame
	
	print("[Landing] Current XP AFTER reward: %d" % TutorialManager.total_xp)
	
	var dialog := AcceptDialog.new()
	dialog.title = "🎉 Welcome Bonus!"
	dialog.dialog_text = "Congratulations on completing the tutorial!\n\nYou've earned:\n• 50 XP\n• Beginner Badge\n\nGood luck in Cyber Arena!"
	dialog.min_size = Vector2(400, 250)
	dialog.exclusive = false  # ✅ Allow other windows
	add_child(dialog)
	dialog.popup_centered()
	
	# Simple one-shot connection that only closes the dialog
	dialog.confirmed.connect(func(): 
		print("[Landing] Dialog closed")
		dialog.queue_free()
	, CONNECT_ONE_SHOT)


# === Update XP Display ===
func _update_xp_display() -> void:
	print("[Landing] ========== UPDATING XP DISPLAY ==========")
	print("[Landing] Total XP: %d" % TutorialManager.total_xp)
	
	if xp_input:
		xp_input.text = " %d" % TutorialManager.total_xp
		print("[Landing] ✅ XP Label updated")
	
	var rank: Dictionary = TutorialManager.get_rank()
	if rank_label:
		rank_label.text = "%s %s" % [rank["icon"], rank["name"]]
		rank_label.add_theme_color_override("font_color", rank["color"])
		rank_label.tooltip_text = " %d/%d (%.0f%% to next rank)" % [rank["current_xp"], rank["max_xp"], rank["progress"]]
	
	if match_played_input and wins_input and losses_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)


func _on_xp_updated(new_xp: int) -> void:
	print("[Landing] 🎉 XP Updated: %d" % new_xp)
	
	if xp_input:
		xp_input.text = " %d" % new_xp
	
	var rank: Dictionary = TutorialManager.get_rank(new_xp)
	if rank_label:
		rank_label.text = "%s %s" % [rank["icon"], rank["name"]]
		rank_label.add_theme_color_override("font_color", rank["color"])


func _on_rank_up(new_rank: Dictionary) -> void:
	print("🏆 RANK UP! %s %s" % [new_rank["icon"], new_rank["name"]])
	
	# ✅ Wait a frame to avoid dialog conflicts
	await get_tree().process_frame
	
	var dialog := AcceptDialog.new()
	dialog.title = "RANK UP!"
	dialog.dialog_text = "Congratulations!\n\nYou've been promoted to:\n%s %s\n\nKeep completing tutorials to climb higher!" % [new_rank["icon"], new_rank["name"]]
	dialog.min_size = Vector2(300, 200)
	dialog.exclusive = false  # ✅ Allow other windows
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free(), CONNECT_ONE_SHOT)


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
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				btn.custom_minimum_size = Vector2(64, 64)
				var captured_name: String = file_name
				btn.pressed.connect(func(): _on_avatar_selected(captured_name))
				avatar_grid.add_child(btn)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_change_avatar_pressed() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_avatar_change < avatar_cooldown:
		var remaining = int((avatar_cooldown - (current_time - last_avatar_change)) / 86400)
		status_label.text = "⏳ You can change avatar again in %d days." % remaining
		return
	avatar_picker.popup_centered()


func _on_avatar_selected(file_name: String) -> void:
	if avatars.has(file_name):
		profile_pic.texture = avatars[file_name]
		selected_avatar = file_name
		status_label.text = "✅ Avatar selected (click SaveProfile to apply)"
		avatar_picker.hide()


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
			"username": { "stringValue": username_input.text },
			"level": { "integerValue": level_input.text },
			"wins": { "integerValue": wins_input.text },
			"losses": { "integerValue": losses_input.text },
			"avatar": { "stringValue": selected_avatar },
			"last_avatar_change": { "integerValue": str(last_avatar_change) }
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
		status_label.text = "✅ Profile saved!"
		Auth.current_avatar = selected_avatar
		Auth.current_username = username_input.text
		_load_user_data()
	else:
		var msg = body.get_string_from_utf8() if body.size() > 0 else "Unknown error"
		status_label.text = "❌ Failed to save profile"
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
		if avatars.has(selected_avatar):
			profile_pic.texture = avatars[selected_avatar]
			Auth.current_avatar = selected_avatar

	if f.has("last_avatar_change"):
		last_avatar_change = int(f["last_avatar_change"]["integerValue"])

	if f.has("username"):
		Auth.current_username = f["username"]["stringValue"]
		username_input.text = Auth.current_username

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


func _on_menu_button_pressed() -> void:
	if menu_panel:
		menu_panel.visible = true
		menu_panel.move_to_front()


# ✅ Module navigation function
func _on_module_navigate_pressed() -> void:
	print("[Landing] Navigating to Mode Selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


func _show_panel(panel_paths: Dictionary, panel_name: String) -> void:
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

	var friend_list = $VideoStreamPlayer.get_node_or_null("FriendListPanel")
	if friend_list:
		friend_list.visible = (panel_name != "game")


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
			"wins": { "integerValue": 0 },
			"losses": { "integerValue": 0 }
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


func _on_tutorial_pressed() -> void:
	print("[Landing] Opening module selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


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
	dialog.exclusive = false  # ✅ Allow other windows
	dialog.canceled.connect(func(): dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	, CONNECT_ONE_SHOT)
	add_child(dialog)
	dialog.popup_centered()
