extends Control

const _SessionStore = preload("res://script/CodeBreakerSessionStore.gd")

# === UI References ===
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
@onready var reset_stats_btn: Button = $VideoStreamPlayer/ProfilePanel/UserPanel/ResetStatsButton
@onready var avatar_picker: PopupPanel = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker
@onready var avatar_grid: GridContainer = $VideoStreamPlayer/ProfilePanel/UserPanel/AvatarPicker/GridContainer
@onready var menu_panel: Control = $MenuPanel

# === Avatars & User Data ===
var avatars: Dictionary = {}
var selected_avatar: String = ""
var last_avatar_change: int = 0
var avatar_cooldown: int = 2592000 # 30 days

# Firestore base
var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"

# Reusable HTTP node for requests
var http: HTTPRequest

# Resume retry guard (prevents infinite loops if server is down)
var _code_breaker_resume_retries: int = 0

# === Lifecycle ===
func _ready() -> void:
	#print("Setting fullscreen...")
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Create reusable HTTPRequest node
	http = HTTPRequest.new()
	add_child(http)

	_load_avatars()
	change_btn.pressed.connect(_on_change_avatar_pressed)
	save_btn.pressed.connect(_on_save_profile_pressed)
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	reset_stats_btn.pressed.connect(_on_reset_stats_pressed)
	_load_user_data()

	# Load and instance ChatPanel
	_instantiate_chat_panel()

	# mark presence online when entering landing
	Auth.set_user_online()
	
	# Connect to XP update signals FIRST (before loading data)
	TutorialManager.xp_updated.connect(_on_xp_updated)
	TutorialManager.rank_up.connect(_on_rank_up)
	TutorialManager.data_loaded.connect(_update_xp_display)
	
	# Load tutorial/XP data for game unlocks (signal will fire after load completes)
	TutorialManager.load_user_data()
	
	# Also update display immediately if TutorialManager already has data
	# (in case of hot reload or scene re-entry)
	# Use call_deferred to ensure UI nodes are fully ready
	call_deferred("_update_xp_display")

	# === Navigation setup ===
	_setup_navigation()

	_check_tutorial_status()
	# If the app was restarted (shutdown/crash) while in a Code Breaker room/match,
	# attempt to resume by routing into the reconnect flow.
	call_deferred("_try_resume_code_breaker_session")
	

func _try_resume_code_breaker_session() -> void:
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
	


# === Update XP Display ===
func _update_xp_display() -> void:
	print("[Landing] ========== UPDATING XP DISPLAY ==========")
	print("[Landing] Total XP: %d" % TutorialManager.total_xp)
	print("[Landing] Completed Tutorials: %d" % TutorialManager.completed_tutorials.size())
	
	if xp_input:
		xp_input.text = "XP : %d" % TutorialManager.total_xp
		print("[Landing] ✅ XP Label updated to: %s" % xp_input.text)
	else:
		push_error("[Landing] xp_input label not found!")
	
	# Update rank display
	var rank: Dictionary = TutorialManager.get_rank()
	print("[Landing] Rank: %s %s" % [rank["icon"], rank["name"]])
	
	if rank_label:
		rank_label.text = "%s %s" % [rank["icon"], rank["name"]]
		rank_label.add_theme_color_override("font_color", rank["color"])
		rank_label.tooltip_text = "XP: %d/%d (%.0f%% to next rank)" % [rank["current_xp"], rank["max_xp"], rank["progress"]]
		print("[Landing] ✅ Rank Label updated to: %s" % rank_label.text)
	
	# Update match played display
	if match_played_input and wins_input and losses_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		var total_matches = wins + losses
		match_played_input.text = str(total_matches)
		print("[Landing] ✅ Match Played updated to: %d" % total_matches)

func _on_xp_updated(new_xp: int) -> void:
	if xp_input:
		xp_input.text = "XP %d" % new_xp
		print("🎉 XP Updated: ", new_xp)
	
	# Update rank
	var rank: Dictionary = TutorialManager.get_rank(new_xp)
	if rank_label:
		rank_label.text = "%s %s" % [rank["icon"], rank["name"]]
		rank_label.add_theme_color_override("font_color", rank["color"])

func _on_rank_up(new_rank: Dictionary) -> void:
	print("🏆 RANK UP! %s %s" % [new_rank["icon"], new_rank["name"]])
	
	# Show rank up dialog
	var dialog := AcceptDialog.new()
	dialog.title = "RANK UP!"
	dialog.dialog_text = "Congratulations!\n\nYou've been promoted to:\n%s %s\n\nKeep completing tutorials to climb higher!" % [new_rank["icon"], new_rank["name"]]
	dialog.min_size = Vector2(300, 200)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# === Load avatars from folder ===
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
				var btn := TextureButton.new()
				btn.texture_normal = tex
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				btn.custom_minimum_size = Vector2(64, 64)
				# capture file_name at connection time
				var captured_name: String = file_name
				btn.pressed.connect(func(): _on_avatar_selected(captured_name))
				avatar_grid.add_child(btn)
		file_name = dir.get_next()
	dir.list_dir_end()


# === Change avatar button ===
func _on_change_avatar_pressed() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_avatar_change < avatar_cooldown:
		var remaining = int((avatar_cooldown - (current_time - last_avatar_change)) / 86400)
		status_label.text = "⏳ You can change avatar again in %d days." % remaining
		return
	avatar_picker.popup_centered()


# === User selects avatar ===
func _on_avatar_selected(file_name: String) -> void:
	if avatars.has(file_name):
		profile_pic.texture = avatars[file_name]
		selected_avatar = file_name
		status_label.text = "✅ Avatar selected (click SaveProfile to apply)"
		avatar_picker.hide()


# === SaveProfile button pressed ===
func _on_save_profile_pressed() -> void:
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in, cannot save profile")
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


# === Load user data from Firestore ===
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
		push_error("⚠️ Failed to load user data: %s" % response_code)
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
	
	# Update match played count
	if match_played_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)


# === Navigation Logic ===
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

	# Connect game icons (NinePatchRect - need gui_input)
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
		# Ensure it appears above other controls if overlapped
		menu_panel.move_to_front()


func _show_panel(panel_paths: Dictionary, panel_name: String) -> void:
	# Hide all panels
	for key in panel_paths.keys():
		var node = $VideoStreamPlayer.get_node_or_null(panel_paths[key])
		if node:
			node.visible = false
		else:
			push_warning("Panel node missing (hide): %s" % panel_paths[key])

	# Also hide CodeBreakerLobby when navigating with buttons
	var code_breaker_lobby = $VideoStreamPlayer.get_node_or_null("CodeBreakerLobby")
	if code_breaker_lobby:
		code_breaker_lobby.visible = false

	# Hide AkashicLobby as well when navigating
	var akashic_lobby = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
	if akashic_lobby:
		akashic_lobby.visible = false

	# Show target panel
	var node_to_show = $VideoStreamPlayer.get_node_or_null(panel_paths.get(panel_name, ""))
	if node_to_show:
		node_to_show.visible = true
	else:
		push_warning("Panel node not found to show: %s" % panel_name)

	# Friend list visibility
	var friend_list = $VideoStreamPlayer.get_node_or_null("FriendListPanel")
	if friend_list:
		friend_list.visible = (panel_name != "game")


# === Reset Match Stats ===
func _on_reset_stats_pressed() -> void:
	print("[Landing] Resetting match statistics...")
	
	# Reset UI
	wins_input.text = "0"
	losses_input.text = "0"
	match_played_input.text = "0"
	
	# Save to Firestore
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		push_error("⚠️ User not logged in, cannot reset stats")
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
			print("[Landing] ✅ Match stats reset successfully")
		else:
			var msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "Unknown error"
			status_label.text = "❌ Failed to reset stats"
			push_error("Firestore error: %s" % msg)
	)
	
	http_reset.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


# === Tutorial Button ===
func _on_tutorial_pressed() -> void:
	print("[Landing] Opening tutorials...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# === Logout Logic ===
func _on_logout_pressed() -> void:
	print("Logging out...")
	Auth.set_user_offline()  # 🔴 mark offline before exit
	
	# Clear TutorialManager data on logout
	TutorialManager.reset_data()
	
	get_tree().change_scene_to_file("res://scene/login.tscn")


func _instantiate_chat_panel() -> void:
	var chat_scene = load("res://scene/chat.tscn")
	if chat_scene:
		var chat_panel = chat_scene.instantiate()
		add_child(chat_panel)
		print("[Landing] ChatPanel instantiated and added to scene")
	else:
		push_error("[Landing] Failed to load chat.tscn")


# === Defuse The Trojan Handler ===
func _on_defuse_trojan_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Defuse The Trojan clicked")
		# TODO: Add logic to show Defuse The Trojan game/lobby


# === Akashic TCG Handler ===
func _on_akashic_tcg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Akashic TCG clicked - showing lobby")
		# Hide GameSelectPanel
		var game_select_panel = $VideoStreamPlayer/GameSelectPanel
		if game_select_panel:
			game_select_panel.visible = false

		# Hide CodeBreakerLobby if visible
		var code_breaker_lobby = $VideoStreamPlayer.get_node_or_null("CodeBreakerLobby")
		if code_breaker_lobby:
			code_breaker_lobby.visible = false

		# Show AkashicLobby
		var akashic_lobby = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
		if akashic_lobby:
			akashic_lobby.visible = true
			print("[Landing] AkashicLobby is now visible")
		else:
			push_error("[Landing] Akashic Lobby node not found")


# === Code Breaker NinePatchRect Handler ===
func _on_code_breaker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Landing] Code Breaker clicked")
		
		# Check if game is unlocked
		if not TutorialManager.is_game_unlocked("code_breaker"):
			_show_locked_game_dialog("Code Breaker", 500)
			return
		
		print("[Landing] Code Breaker unlocked - showing lobby")
		
		# Hide GameSelectPanel
		var game_select_panel = $VideoStreamPlayer/GameSelectPanel
		if game_select_panel:
			game_select_panel.visible = false
		
		# Hide AkashicLobby if visible
		var akashic_lobby2 = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
		if akashic_lobby2:
			akashic_lobby2.visible = false
		
		# Show CodeBreakerLobby
		var code_breaker_lobby = $VideoStreamPlayer/CodeBreakerLobby
		if code_breaker_lobby:
			code_breaker_lobby.visible = true
			print("[Landing] CodeBreakerLobby is now visible")
		else:
			push_error("[Landing] Code Breaker Lobby node not found")


# === Show Locked Game Dialog ===
func _show_locked_game_dialog(game_name: String, required_xp: int) -> void:
	var current_xp: int = TutorialManager.total_xp
	var xp_needed: int = required_xp - current_xp
	
	var dialog := AcceptDialog.new()
	dialog.title = "🔒 Game Locked"
	dialog.dialog_text = "%s is locked!\n\nYour XP: %d\nRequired XP: %d\nNeeded: %d more XP\n\nComplete tutorials in Mode Selection to earn XP and unlock games." % [game_name, current_xp, required_xp, xp_needed]
	dialog.ok_button_text = "Go to Mode Selection"
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
	)
	add_child(dialog)
	dialog.popup_centered()
func _check_tutorial_status() -> void:
	"""
	Checks if user has completed tutorial.
	If tutorial_completed is false, redirect to landing_tutorial.tscn
	This handles cases where users closed the app during tutorial.
	"""
	var user_id := Auth.current_local_id
	var id_token := Auth.current_id_token
	
	if user_id == "" or id_token == "":
		print("[Landing] No auth info, skipping tutorial check")
		return
	
	var url := "%s/%s" % [firestore_base_url, user_id]
	var headers := ["Authorization: Bearer %s" % id_token]
	
	var http_tutorial := HTTPRequest.new()
	add_child(http_tutorial)
	
	http_tutorial.request_completed.connect(func(_r, code, _h, body):
		http_tutorial.queue_free()
		
		if code != 200:
			print("[Landing] Failed to check tutorial status: %s" % code)
			return
		
		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data or not data.has("fields"):
			print("[Landing] No user data found")
			return
		
		var fields = data["fields"]
		
		# Check if tutorial was completed
		if fields.has("tutorial_completed"):
			var completed: bool = fields["tutorial_completed"].get("booleanValue", true)
			
			if not completed:
				print("[Landing] 🎓 Tutorial not completed, redirecting to tutorial...")
				# Small delay to ensure landing scene is fully loaded
				await get_tree().create_timer(0.5).timeout
				get_tree().change_scene_to_file("res://scene/landing_tutorial.tscn")
			else:
				print("[Landing] ✅ Tutorial already completed")
		else:
			# If field doesn't exist, assume old user (no tutorial needed)
			print("[Landing] Tutorial field not found, assuming existing user")
	)
	
	var err := http_tutorial.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[Landing] Failed to start tutorial check request: %s" % err)
		http_tutorial.queue_free()
