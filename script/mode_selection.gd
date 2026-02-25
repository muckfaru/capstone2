extends Control

# ── Buttons (direct children of CanvasLayer, no container parent) ─────────
@onready var beginner_btn: Button = $CanvasLayer/BeginnerButton
@onready var intermediate_btn: Button = $CanvasLayer/IntermediateButton
@onready var advanced_btn: Button = $CanvasLayer/AdvancedButton
@onready var back_btn: Button = $CanvasLayer/BackButton

# ── Multiplayer buttons ───────────────────────────────────────────────────
@onready var create_room_btn: Button = $CanvasLayer/CreateRoomButton
@onready var join_lobby_btn: Button = $CanvasLayer/JoinLobbyButton
@onready var join_lobby_popup: Control = null # instantiated at runtime
# ── XP / Rank display (now scene nodes) ──────────────────────────────────
@onready var xp_label: Label = $CanvasLayer/XPLabel
@onready var xp_progress_bar: ProgressBar = $CanvasLayer/XPProgressBar
@onready var rank_icon: TextureRect = $CanvasLayer/RankIcon
@onready var rank_label: Label = $CanvasLayer/RankLabel

# ── Unlock panel (now a scene node) ──────────────────────────────────────
@onready var unlock_panel: Panel = $CanvasLayer/UnlockProgressPanel
@onready var code_breaker_label: Label = $CanvasLayer/UnlockProgressPanel/UnlockVBox/CodeBreakerVBox/CodeBreakerLabel
@onready var code_breaker_progress: ProgressBar = $CanvasLayer/UnlockProgressPanel/UnlockVBox/CodeBreakerVBox/CodeBreakerProgress
@onready var code_breaker_progress_label: Label = $CanvasLayer/UnlockProgressPanel/UnlockVBox/CodeBreakerVBox/CodeBreakerProgressLabel
@onready var game3_label: Label = $CanvasLayer/UnlockProgressPanel/UnlockVBox/Game3Label

# ── Video fade overlay (created at runtime, small helper) ─────────────────
var fade_overlay: ColorRect = null

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

# Icon resources (24x24 or 32x32 recommended)
const ICON_TIME := preload("res://asset/icons/time_icon1.png")
const ICON_XP := preload("res://asset/icons/xp icon.png")
const ICON_STAR_FILLED := preload("res://asset/icons/star_filled2.png")
const ICON_STAR_EMPTY := preload("res://asset/icons/star_empty.png")
const ICON_DIFFICULTY := preload("res://asset/icons/difficulty.png")

# Tutorial category icons
const ICON_FUNDAMENTALS := preload("res://asset/icons/cyfunda.png")
const ICON_NETWORK := preload("res://asset/icons/NBfun.png")
const ICON_PASSWORD := preload("res://asset/icons/passwordfticon.png")
const ICON_MALWARE := preload("res://asset/icons/malwaretpicon.png")
const ICON_CIA_TRIAD := preload("res://asset/icons/cyfunda.png")
const ICON_PHISHING := preload("res://asset/icons/phishinglbicon.png")
const ICON_TROJAN := preload("res://asset/icons/Defuse the trojan 1.png")
const ICON_DEFENSE := preload("res://asset/icons/firewall shield icon.png")
const ICON_LAB := preload("res://asset/icons/code breaker.png")
const ICON_ENCRYPTION := preload("res://asset/icons/encryicon.png")
const ICON_ADVANCED := preload("res://asset/icons/hacker.png")

# Intermediate minigame icons
const ICON_DROP_ZONE := preload("res://asset/icons/drop_zone_icon.png")
const ICON_ASSET_THREAT := preload("res://asset/icons/asset_threat_icon.png")
const ICON_CRYPT_CONTRACT := preload("res://asset/icons/crypt_contract_icon.png")
const ICON_INCIDENT_COMMANDER := preload("res://asset/icons/incident_commander_icon.png")

# Advanced minigame icons
const ICON_SECURITY_GUARDIAN := preload("res://asset/icons/security_guardian_icon.png")
const ICON_MALWARE_DEFENSE := preload("res://asset/icons/malware_defense_icon.png")
const ICON_INCIDENT_RESPONSE := preload("res://asset/icons/incident_response_icon.png")

# Tutorial metadata
const TUTORIAL_METADATA := {
	"beginner_fundamentals": {"time": "10-15 min", "xp_range": "100-200 XP", "difficulty": 2},
	"beginner_cia_triad": {"time": "5-8 min", "xp_range": "100-200 XP", "difficulty": 1},
	"beginner_network": {"time": "12-18 min", "xp_range": "100-200 XP", "difficulty": 3},
	"beginner_password": {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3},
	"beginner_malware": {"time": "10-15 min", "xp_range": "100-200 XP", "difficulty": 2},
	"intermediate_phishing": {"time": "20-25 min", "xp_range": "50-100 XP", "difficulty": 4},
	"intermediate_trojan": {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3},
	"intermediate_defense": {"time": "18-25 min", "xp_range": "100-200 XP", "difficulty": 4},
	"intermediate_lab": {"time": "20-30 min", "xp_range": "100-200 XP", "difficulty": 4},
	"advanced_scenarios": {"time": "25-35 min", "xp_range": "100-200 XP", "difficulty": 5},
	"advanced_encryption": {"time": "20-25 min", "xp_range": "100-200 XP", "difficulty": 4},
	"advanced_lab": {"time": "25-40 min", "xp_range": "100-200 XP", "difficulty": 5}
}


func _ready() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ No auth state! Redirecting to login...")
		get_tree().change_scene_to_file.call_deferred("res://scene/login.tscn")
		return

	print("[ModeSelection] ========== MODE SELECTION READY ==========")
	print("[ModeSelection] ✅ Mode Selection Ready | UID:", Auth.current_local_id)

	_setup_smooth_video_loop()

	# Connect TutorialManager signal
	if not TutorialManager.data_loaded.is_connected(_update_xp_display):
		TutorialManager.data_loaded.connect(_update_xp_display)

	if not TutorialManager.data_has_loaded:
		print("[ModeSelection] TutorialManager data not loaded yet, loading now...")
		TutorialManager.load_user_data()
	else:
		print("[ModeSelection] TutorialManager already has data (XP: %d)" % TutorialManager.total_xp)
		call_deferred("_update_xp_display")

	_animate_entrance()

	var bgm = $BackgroundMusic
	if bgm:
		bgm.volume_db = -80
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -10, 2.0)

	call_deferred("_check_and_show_rank_up")


func _fade_out_music_and_transition(scene_path: String) -> void:
	var bgm = $BackgroundMusic
	if bgm:
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -80, 0.5)
		await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _setup_smooth_video_loop() -> void:
	var video_player = $VideoStreamPlayer
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.modulate.a = 0
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)
	move_child(fade_overlay, get_child_count() - 2)
	video_player.loop = false
	video_player.finished.connect(_on_video_finished)


func _on_video_finished() -> void:
	var video_player = $VideoStreamPlayer
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	await tween.finished
	video_player.play()
	await get_tree().create_timer(0.1).timeout
	var tween2 = create_tween()
	tween2.tween_property(fade_overlay, "modulate:a", 0.0, 0.6)


# ─────────────────────────────────────────────────────────────────────────────
# XP / RANK DISPLAY  (reads from scene nodes, no node creation)
# ─────────────────────────────────────────────────────────────────────────────
func _update_xp_display() -> void:
	print("[ModeSelection] ========== UPDATING XP DISPLAY ==========")
	var rank: Dictionary = TutorialManager.get_rank()
	var current_xp = TutorialManager.total_xp

	if xp_label:
		xp_label.text = ": %d" % current_xp

	if rank_icon:
		var icon_texture = load(rank["icon"])
		if icon_texture:
			rank_icon.texture = icon_texture

	if rank_label:
		rank_label.text = rank["name"]
		rank_label.add_theme_color_override("font_color", rank["color"])
		rank_label.tooltip_text = "Progress: %.0f%% | XP to next rank: %d" % [rank["progress"], rank["xp_to_next"]]

	if xp_progress_bar:
		var next_rank_xp = rank["max_xp"] if rank["max_xp"] != 999999 else rank["min_xp"] + 1000
		xp_progress_bar.max_value = next_rank_xp
		var tween = create_tween()
		tween.tween_property(xp_progress_bar, "value", current_xp, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_update_unlock_panel()


# ─────────────────────────────────────────────────────────────────────────────
# UNLOCK PANEL  (updates text on scene nodes, no node creation)
# ─────────────────────────────────────────────────────────────────────────────
func _update_unlock_panel() -> void:
	var current_xp = TutorialManager.total_xp
	var required_xp = TutorialManager.XP_THRESHOLDS["code_breaker"]
	var cb_unlocked = TutorialManager.is_game_unlocked("code_breaker")
	var game3_unlocked = TutorialManager.is_game_unlocked("game_3")

	# Code Breaker label
	if code_breaker_label:
		if cb_unlocked:
			code_breaker_label.text = "✅ Code Breaker (Unlocked!)"
			code_breaker_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			code_breaker_label.text = "🔒 Code Breaker (Unlock at 500 XP)"
			code_breaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Code Breaker progress bar + label
	if code_breaker_progress:
		code_breaker_progress.visible = not cb_unlocked
		code_breaker_progress.max_value = required_xp
		code_breaker_progress.value = current_xp

	if code_breaker_progress_label:
		code_breaker_progress_label.visible = not cb_unlocked
		code_breaker_progress_label.text = "Progress: %d/%d XP (%.0f%%)" % [current_xp, required_xp, (float(current_xp) / required_xp) * 100.0]

	# Game 3 label
	if game3_label:
		if game3_unlocked:
			game3_label.text = "✅ Mystery Game (Unlocked!)"
			game3_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			game3_label.text = "🔒 Mystery Game (Unlock at 1500 XP)"
			game3_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


# ─────────────────────────────────────────────────────────────────────────────
# ENTRANCE ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
func _animate_entrance() -> void:
	for btn in [beginner_btn, intermediate_btn, advanced_btn]:
		if btn:
			btn.modulate.a = 0
			btn.position.x -= 50

	if beginner_btn:
		var tween = create_tween()
		tween.tween_property(beginner_btn, "modulate:a", 1.0, 0.5).set_delay(0.1)
		tween.parallel().tween_property(beginner_btn, "position:x", beginner_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if intermediate_btn:
		var tween = create_tween()
		tween.tween_property(intermediate_btn, "modulate:a", 1.0, 0.5).set_delay(0.2)
		tween.parallel().tween_property(intermediate_btn, "position:x", intermediate_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if advanced_btn:
		var tween = create_tween()
		tween.tween_property(advanced_btn, "modulate:a", 1.0, 0.5).set_delay(0.3)
		tween.parallel().tween_property(advanced_btn, "position:x", advanced_btn.position.x + 50, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Animate multiplayer buttons sliding in from the right
	for btn in [create_room_btn, join_lobby_btn]:
		if btn:
			btn.modulate.a = 0
			btn.position.x += 30

	if create_room_btn:
		var tween = create_tween()
		tween.tween_property(create_room_btn, "modulate:a", 1.0, 0.5).set_delay(0.4)
		tween.parallel().tween_property(create_room_btn, "position:x", create_room_btn.position.x - 30, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if join_lobby_btn:
		var tween = create_tween()
		tween.tween_property(join_lobby_btn, "modulate:a", 1.0, 0.5).set_delay(0.5)
		tween.parallel().tween_property(join_lobby_btn, "position:x", join_lobby_btn.position.x - 30, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# BUTTON HOVER
# ─────────────────────────────────────────────────────────────────────────────
func _on_button_hover(level: String) -> void:
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return

	var hover_sfx = $HoverSound
	if hover_sfx and not hover_sfx.playing:
		hover_sfx.play()
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.3)


# ─────────────────────────────────────────────────────────────────────────────
# LEVEL SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _on_level_selected(level: String) -> void:
	print("🎯 Level selected:", level)
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	await tween.finished

	_show_tutorial_menu(level)


# ─────────────────────────────────────────────────────────────────────────────
# TUTORIAL MENU  (instantiates tutorial_menu_overlay.tscn)
# ─────────────────────────────────────────────────────────────────────────────
func _show_tutorial_menu(level: String) -> void:
	var tutorials: Array = []
	var level_int: int = 1

	match level:
		"beginner":
			level_int = 1
			tutorials = [
				{"name": "Cybersecurity Fundamentals (Start Here!)", "scene": "res://scene/tutorial_cyber_fundamentals.tscn", "id": "beginner_fundamentals"},
				{"name": "Network Basics", "scene": "res://scene/tutorial_network_basics.tscn", "id": "beginner_network"},
				{"name": "Encryption", "scene": "res://scene/tutorial_encryption_basics.tscn", "id": "advanced_encryption"},
				{"name": "Password Fortress Defender", "scene": "res://scene/tutorial_password_basics.tscn", "id": "beginner_password"},
				{"name": "Malware Types Overview", "scene": "res://scene/tutorial_malware_types.tscn", "id": "beginner_malware"},
			]
		"intermediate":
			level_int = 2
			tutorials = [
				{"name": "Drop Zone Defender", "scene": "res://scene/datavsnetwork.tscn", "id": "beginner_drop_zone"},
				{"name": "Phishing Detection Lab", "scene": "res://scene/phishing_intro.tscn", "id": "intermediate_phishing"},
				{"name": "Asset vs Threats", "scene": "res://scene/Assetandthreat.tscn", "id": "intermediate_assetandthreat"},
				{"name": "Crypt Contract", "scene": "res://scene/PhoneEncryption.tscn", "id": "intermediate_crypt_contract"},
				{"name": "Incident Commander", "scene": "res://scene/SOCMain.tscn", "id": "intermediate_incident_commander"},
			]
		"advanced":
			level_int = 3
			tutorials = [
				{"name": "Security Guardian", "scene": "res://scene/authgmMain.tscn", "id": "advanced_security_guardian"},
				{"name": "Malware Defense & Removal", "scene": "res://scene/DigitalForensicsScene.tscn", "id": "advanced_malware_defense"},
				{"name": "CMD Defender: Incident Response Training", "scene": "res://scene/incedentmain.tscn", "id": "advanced_incident_response"},
			]

	Auth.current_level = level_int

	if not TutorialManager.data_has_loaded:
		print("[Dialog] Waiting for TutorialManager data...")
		await TutorialManager.data_loaded

	# Load the overlay scene
	var overlay_scene = load("res://scene/tutorial_menu_overlay.tscn")
	if not overlay_scene:
		push_error("❌ Could not load tutorial_menu_overlay.tscn")
		return

	var overlay = overlay_scene.instantiate()

	# Set title
	var title_lbl = overlay.get_node("DialogPanel/ContentMargin/MainVBox/TitleLabel")
	if title_lbl:
		title_lbl.text = "Choose Tutorial - Level %d Assessment" % level_int

	# Connect close button (signal is already wired in .tscn)
	var close_btn = overlay.get_node("DialogPanel/CloseButton")
	if close_btn and not close_btn.pressed.is_connected(overlay.queue_free):
		close_btn.pressed.connect(overlay.queue_free)

	# Populate tutorial cards
	var tutorials_vbox = overlay.get_node("DialogPanel/ContentMargin/MainVBox/ScrollContainer/ScrollContentMargin/TutorialsVBox")
	if tutorials_vbox:
		for tutorial in tutorials:
			var card = _create_tutorial_card(tutorial, level_int, overlay)
			tutorials_vbox.add_child(card)

	$CanvasLayer.add_child(overlay)

	# Entrance animation on the panel
	var dialog_panel = overlay.get_node("DialogPanel")
	dialog_panel.modulate.a = 0
	dialog_panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(dialog_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# TUTORIAL CARD  (instantiates tutorial_card.tscn, fills in data)
# ─────────────────────────────────────────────────────────────────────────────
func _create_tutorial_card(tutorial: Dictionary, level_int: int, overlay: Control) -> PanelContainer:
	var tutorial_id: String = tutorial["id"]

	var minigame_ids = [
		"beginner_drop_zone",
		"intermediate_assetandthreat",
		"intermediate_crypt_contract",
		"intermediate_incident_commander",
		"advanced_security_guardian",
		"advanced_malware_defense",
		"advanced_incident_response"
	]
	var is_minigame: bool = tutorial_id in minigame_ids

	var is_completed: bool = false
	var completion_data: Dictionary = {}
	if is_minigame:
		is_completed = TutorialManager.completed_minigames.has(tutorial_id)
		if is_completed:
			completion_data = TutorialManager.completed_minigames[tutorial_id]
	else:
		is_completed = TutorialManager.completed_tutorials.has(tutorial_id)
		if is_completed:
			completion_data = TutorialManager.completed_tutorials[tutorial_id]

	var metadata = TUTORIAL_METADATA.get(tutorial_id, {"time": "15-20 min", "xp_range": "100-200 XP", "difficulty": 3})

	# Load card scene
	var card_scene = load("res://scene/tutorial_card.tscn")
	if not card_scene:
		push_error("❌ Could not load tutorial_card.tscn — falling back to inline card")
		return _create_tutorial_card_inline(tutorial, level_int, overlay)

	var card = card_scene.instantiate()

	# ── Colour the card panel based on completion ──────────────────────────
	var card_style = StyleBoxFlat.new()
	if is_completed:
		card_style.bg_color = Color(0.05, 0.2, 0.1, 0.9)
		card_style.border_color = Color(0, 1, 0.5, 1.0)
		card_style.shadow_color = Color(0, 1, 0.5, 0.4)
		card_style.shadow_size = 8
	else:
		card_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
		card_style.border_color = Color(0, 1, 1, 0.6)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)

	# ── Category icon ─────────────────────────────────────────────────────
	var icon_map = {
		# Beginner tutorials
		"beginner_fundamentals": ICON_FUNDAMENTALS,
		"beginner_cia_triad": ICON_CIA_TRIAD,
		"beginner_network": ICON_NETWORK,
		"beginner_password": ICON_PASSWORD,
		"beginner_malware": ICON_MALWARE,
		# Intermediate minigames
		"beginner_drop_zone": ICON_DROP_ZONE,
		"intermediate_phishing": ICON_PHISHING,
		"intermediate_assetandthreat": ICON_ASSET_THREAT,
		"intermediate_crypt_contract": ICON_CRYPT_CONTRACT,
		"intermediate_incident_commander": ICON_INCIDENT_COMMANDER,
		# Advanced minigames
		"advanced_security_guardian": ICON_SECURITY_GUARDIAN,
		"advanced_malware_defense": ICON_MALWARE_DEFENSE,
		"advanced_incident_response": ICON_INCIDENT_RESPONSE,
		# Old tutorial IDs (kept for safety)
		"intermediate_trojan": ICON_TROJAN,
		"intermediate_defense": ICON_DEFENSE,
		"intermediate_lab": ICON_LAB,
		"advanced_scenarios": ICON_ADVANCED,
		"advanced_encryption": ICON_ENCRYPTION,
		"advanced_lab": ICON_LAB
	}
	var category_icon = card.get_node("CardMargin/MainHBox/CategoryIcon")
	if category_icon:
		category_icon.texture = icon_map.get(tutorial_id, ICON_FUNDAMENTALS)

	# ── Title ─────────────────────────────────────────────────────────────
	var title_lbl = card.get_node("CardMargin/MainHBox/CardVBox/TitleLabel")
	if title_lbl:
		title_lbl.text = tutorial["name"]

	# ── Time / XP labels ──────────────────────────────────────────────────
	var time_lbl = card.get_node("CardMargin/MainHBox/CardVBox/InfoHBox/TimeContainer/TimeLabel")
	if time_lbl:
		time_lbl.text = metadata["time"]

	var xp_lbl = card.get_node("CardMargin/MainHBox/CardVBox/InfoHBox/XPContainer/XPLabel")
	if xp_lbl:
		xp_lbl.text = metadata["xp_range"]

	# ── Star difficulty ───────────────────────────────────────────────────
	var diff = metadata["difficulty"]
	var diff_container = card.get_node("CardMargin/MainHBox/CardVBox/InfoHBox/DifficultyContainer")
	if diff_container:
		for i in range(1, 6):
			var star = diff_container.get_node("Star%d" % i)
			if star:
				if i <= diff:
					star.texture = ICON_STAR_FILLED
					star.modulate = Color(1, 0.8, 0.2)
				else:
					star.texture = ICON_STAR_EMPTY
					star.modulate = Color(0.4, 0.4, 0.4)

	# ── Status row ────────────────────────────────────────────────────────
	var status_lbl = card.get_node("CardMargin/MainHBox/CardVBox/StatusRow/StatusLabel")
	var action_btn = card.get_node("CardMargin/MainHBox/CardVBox/StatusRow/ActionButton")
	var no_xp_lbl = card.get_node("CardMargin/MainHBox/CardVBox/StatusRow/NoXPLabel")

	if is_completed:
		if status_lbl:
			if is_minigame:
				status_lbl.text = "✅ COMPLETED | Best Score: %d | 🏆 XP earned: %d" % [completion_data.get("score", 0), completion_data.get("xp_earned", 0)]
			else:
				status_lbl.text = "✅ COMPLETED - %.0f%% | 🏆 XP earned: %d" % [completion_data.get("percentage", 0.0), completion_data.get("xp_earned", 0)]
			status_lbl.visible = true

		# Style action button as replay
		if action_btn:
			action_btn.text = "PLAY AGAIN 🔄"
			action_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
			var replay_style = StyleBoxFlat.new()
			replay_style.bg_color = Color(0.3, 0.15, 0.4, 0.6)
			replay_style.border_width_left = 2; replay_style.border_width_top = 2
			replay_style.border_width_right = 2; replay_style.border_width_bottom = 2
			replay_style.border_color = Color(0.8, 0.4, 1, 0.7)
			replay_style.corner_radius_top_left = 5; replay_style.corner_radius_top_right = 5
			replay_style.corner_radius_bottom_left = 5; replay_style.corner_radius_bottom_right = 5
			action_btn.add_theme_stylebox_override("normal", replay_style)
			var replay_hover = replay_style.duplicate()
			replay_hover.bg_color = Color(0.5, 0.25, 0.6, 0.8)
			replay_hover.border_color = Color(1, 0.6, 1, 1)
			action_btn.add_theme_stylebox_override("hover", replay_hover)

		if no_xp_lbl:
			no_xp_lbl.visible = true
	else:
		if status_lbl:
			status_lbl.visible = false
		if no_xp_lbl:
			no_xp_lbl.visible = false
		# Style action button as start
		if action_btn:
			action_btn.text = "START TUTORIAL →"
			action_btn.add_theme_color_override("font_color", Color(0, 1, 1))
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0, 0.3, 0.4, 0.5)
			btn_style.border_width_left = 2; btn_style.border_width_top = 2
			btn_style.border_width_right = 2; btn_style.border_width_bottom = 2
			btn_style.border_color = Color(0, 1, 1, 0.8)
			btn_style.corner_radius_top_left = 5; btn_style.corner_radius_top_right = 5
			btn_style.corner_radius_bottom_left = 5; btn_style.corner_radius_bottom_right = 5
			action_btn.add_theme_stylebox_override("normal", btn_style)
			var btn_hover = btn_style.duplicate()
			btn_hover.bg_color = Color(0, 0.5, 0.6, 0.7)
			action_btn.add_theme_stylebox_override("hover", btn_hover)

	# ── Wire up the button ────────────────────────────────────────────────
	if action_btn:
		action_btn.pressed.connect(func():
			overlay.queue_free()
			get_tree().set_meta("tutorial_id", tutorial_id)
			get_tree().set_meta("tutorial_level", level_int)
			_save_level_and_navigate(level_int, tutorial["scene"])
		)

	return card


# Fallback: build card inline if the scene file is missing
func _create_tutorial_card_inline(tutorial: Dictionary, level_int: int, overlay: Control) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(600, 95)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl = Label.new()
	lbl.text = tutorial["name"]
	card.add_child(lbl)
	var btn = Button.new()
	btn.text = "START →"
	btn.pressed.connect(func():
		overlay.queue_free()
		get_tree().set_meta("tutorial_id", tutorial["id"])
		get_tree().set_meta("tutorial_level", level_int)
		_save_level_and_navigate(level_int, tutorial["scene"])
	)
	card.add_child(btn)
	return card


# ─────────────────────────────────────────────────────────────────────────────
# SAVE LEVEL TO FIRESTORE + NAVIGATE
# ─────────────────────────────────────────────────────────────────────────────
func _save_level_and_navigate(level_int: int, tutorial_scene: String) -> void:
	print("💾 Saving level to Firestore...")
	var url: String = "%s/users/%s?updateMask.fieldPaths=level" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	var body := {"fields": {"level": {"integerValue": level_int}}}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		if code == 200:
			print("✅ Level saved successfully:", level_int)
		else:
			push_error("❌ Failed to save level (%s): %s" % [code, body_response.get_string_from_utf8()])
		_transition_to_tutorial(tutorial_scene)
	)
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()
		_transition_to_tutorial(tutorial_scene)


# ─────────────────────────────────────────────────────────────────────────────
# TRANSITION ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
func _transition_to_tutorial(scene_path: String) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	var bgm = $BackgroundMusic
	if bgm:
		tween.tween_property(bgm, "volume_db", -80, 0.3)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


# ─────────────────────────────────────────────────────────────────────────────
# MULTIPLAYER — CREATE ROOM
# ─────────────────────────────────────────────────────────────────────────────
func _on_create_room_pressed() -> void:
	if create_room_btn:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(create_room_btn, "scale", Vector2(0.92, 0.92), 0.08)
		tween.tween_property(create_room_btn, "scale", Vector2(1.0, 1.0), 0.15)
		await tween.finished
	_fade_out_music_and_transition("res://scene/TeacherCreateRoom.tscn")


# ─────────────────────────────────────────────────────────────────────────────
# MULTIPLAYER — JOIN LOBBY
# ─────────────────────────────────────────────────────────────────────────────
func _on_join_lobby_pressed() -> void:
	if join_lobby_btn:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(join_lobby_btn, "scale", Vector2(0.92, 0.92), 0.08)
		tween.tween_property(join_lobby_btn, "scale", Vector2(1.0, 1.0), 0.15)

	var popup_scene = load("res://scene/JoinRoomPopup.tscn")
	if not popup_scene:
		push_error("❌ Could not load JoinRoomPopup.tscn")
		return
	join_lobby_popup = popup_scene.instantiate()
	$CanvasLayer.add_child(join_lobby_popup)
	join_lobby_popup.join_requested.connect(_on_join_code_submitted)
	join_lobby_popup.popup_closed.connect(_on_join_popup_closed)
	join_lobby_popup.show_popup()

func _on_join_popup_closed() -> void:
	if join_lobby_popup:
		join_lobby_popup.queue_free()
		join_lobby_popup = null

func _on_join_code_submitted(room_code: String) -> void:
	print("[Join] Student attempting to join room: %s" % room_code)
	# Validate the code against the CyberQuiz server
	var lobby_url := _get_lobby_url()
	var url := lobby_url + "/api/quiz/%s/join" % room_code
	var body := {
		"player_id": Auth.current_local_id,
		"username": Auth.current_username,
	}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[Join] ✅ Successfully joined quiz room: %s" % room_code)
			if join_lobby_popup:
				join_lobby_popup.queue_free()
				join_lobby_popup = null
			# Store room code and lobby URL for StudentQuizScene
			get_tree().set_meta("cyber_quiz_room_code", room_code)
			get_tree().set_meta("cyber_quiz_lobby_url", lobby_url)
			get_tree().change_scene_to_file("res://scene/StudentQuizScene.tscn")
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			var err_data = JSON.parse_string(err_text)
			var msg := "Failed to join room."
			if typeof(err_data) == TYPE_DICTIONARY:
				msg = err_data.get("error", msg)
			print("[Join] ❌ Join failed: %d %s" % [code, msg])
			if join_lobby_popup and join_lobby_popup.has_method("show_error"):
				join_lobby_popup.show_error(msg)
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("[Join] HTTP request failed: %d" % err)
		http.queue_free()
		if join_lobby_popup and join_lobby_popup.has_method("show_error"):
			join_lobby_popup.show_error("Connection error. Try again.")

func _get_lobby_url() -> String:
	if has_node("/root/MultiplayerConfig"):
		return get_node("/root/MultiplayerConfig").get_lobby_url()
	var cfg_script = load("res://script/MultiplayerConfig.gd")
	if cfg_script:
		var cfg = cfg_script.new()
		return cfg.get_lobby_url()
	return "https://codebreaker-lobby.onrender.com"


# ─────────────────────────────────────────────────────────────────────────────
# MENU / SETTINGS BUTTON
# ─────────────────────────────────────────────────────────────────────────────
func _on_menu_pressed() -> void:
	print("🍔 Menu button pressed - Opening settings...")
	var settings_scene = load("res://scene/SettingsPanel.tscn")
	if not settings_scene:
		push_error("❌ Failed to load settings_panel.tscn")
		return
	var settings_panel = settings_scene.instantiate()
	var bgm = $BackgroundMusic
	if bgm and settings_panel.has_method("set_target_music"):
		settings_panel.set_target_music(bgm)
	$CanvasLayer.add_child(settings_panel)
	if settings_panel.has_node("Window"):
		var window = settings_panel.get_node("Window")
		var viewport_size = get_viewport_rect().size
		window.position = (viewport_size - window.size) / 2


# ─────────────────────────────────────────────────────────────────────────────
# PROFILE / BACK
# ─────────────────────────────────────────────────────────────────────────────
func _on_profile_pressed() -> void:
	_fade_out_music_and_transition("res://scene/landing.tscn")

func _on_back_pressed() -> void:
	_fade_out_music_and_transition("res://scene/landing.tscn")


# ─────────────────────────────────────────────────────────────────────────────
# RANK-UP NOTIFICATION
# ─────────────────────────────────────────────────────────────────────────────
func _on_rank_up(new_rank: Dictionary) -> void:
	print("[ModeSelection] 🏆 RANK UP SIGNAL RECEIVED! %s %s" % [new_rank["icon"], new_rank["name"]])
	var old_rank: Dictionary = TutorialManager.RANK_THRESHOLDS[0]
	for i in range(TutorialManager.RANK_THRESHOLDS.size()):
		if TutorialManager.RANK_THRESHOLDS[i]["name"] == new_rank["name"] and i > 0:
			old_rank = TutorialManager.RANK_THRESHOLDS[i - 1]
			break
	await get_tree().process_frame
	var notification_scene = load("res://scene/rank_up_notification.tscn")
	if not notification_scene:
		push_error("[ModeSelection] ❌ Failed to load rank_up_notification.tscn")
		return
	var notification = notification_scene.instantiate()
	add_child(notification)
	notification.show_rank_up(old_rank, new_rank)
	await notification.notification_closed
	print("[ModeSelection] ✅ Rank-up notification closed")


func _check_and_show_rank_up() -> void:
	var rank_up_data = TutorialManager.check_pending_rank_up()
	if rank_up_data.is_empty():
		return
	var old_rank: Dictionary = rank_up_data["old_rank"]
	var new_rank: Dictionary = rank_up_data["new_rank"]
	print("[ModeSelection] 🎉 SHOWING RANK-UP: %s → %s" % [old_rank["name"], new_rank["name"]])
	await get_tree().create_timer(0.5).timeout
	var notification_scene = load("res://scene/rank_up_notification.tscn")
	if not notification_scene:
		push_error("[ModeSelection] ❌ Failed to load rank_up_notification.tscn")
		return
	var notification = notification_scene.instantiate()
	add_child(notification)
	notification.show_rank_up(old_rank, new_rank)
	await notification.notification_closed
	print("[ModeSelection] ✅ Rank-up notification closed")


# F9 test shortcut
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		print("[TEST] Manually triggering rank-up notification...")
		_on_rank_up(TutorialManager.RANK_THRESHOLDS[1])
