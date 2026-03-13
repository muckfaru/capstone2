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
var hover_sfx: AudioStreamPlayer
var click_sfx: AudioStreamPlayer
var card_textures := {
	"DefuseTheTrojan": {
		"normal": preload("res://asset/icons/defuse the trojan 22.png"),
		"hover": preload("res://asset/icons/Defuse the trojan 33.png")  # Your hover texture
	},
	"AkashicTCG": {
		"normal": preload("res://asset/icons/akashic tgc 22.png"),
		"hover": preload("res://asset/icons/akashic tgc 4444.png")
	},
	"CodeBreaker": {
		"normal": preload("res://asset/icons/code breaker 3.png"),
		"hover": preload("res://asset/icons/code breaker 33.png")
	}
}

@onready var rank_icon_rect: TextureRect = $VideoStreamPlayer/ProfilePanel/UserPanel/RankIconRect
# Achievement slots (Profile) — names start with digits so we use get_node()
var _ach_slot_0: PanelContainer
var _ach_slot_1: PanelContainer
var _ach_slot_2: PanelContainer
var _ach_pic_0: TextureRect
var _ach_pic_1: TextureRect
var _ach_pic_2: TextureRect
var _equipped_achievements: Array = ["", "", ""]  # slot 0/1/2
# Match history (Profile)
@onready var match_history_panel: Panel = $VideoStreamPlayer/ProfilePanel/MatchHistoyPanel
@onready var winrate_input: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/winrateInput
var _match_history_scroll: ScrollContainer = null
var _match_history_vbox: VBoxContainer = null

# Leaderboard (Ranking Panel)
var _leaderboard_scroll: ScrollContainer = null
var _leaderboard_vbox: VBoxContainer = null
var _current_leaderboard_game: String = "code_breaker"

@onready var inventory_panel: Panel = null
var shop_panel_instance: Control = null
# Dynamic UI elements (created at runtime)
var file_dialog: FileDialog
@onready var xp_progress: TextureProgressBar = $VideoStreamPlayer/ProfilePanel/MatchHistoyPanel/XPProgressBar

# === Avatars & User Data ===
var original_username: String = ""
var original_avatar: String = ""
var edit_profile_popup: Control = null
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

# === CyberCoin UI ===
@onready var _cybercoin_label: Label = $VideoStreamPlayer/ProfilePanel/UserPanel/CyberCoinLabel

# ✅ CRITICAL: Flag to prevent duplicate welcome bonus
var welcome_bonus_awarded: bool = false

# Starter reward state (cached from Firestore)
var _starter_reward_claimed_cache: bool = false

# Cached stats computed from match history (more accurate than Firestore win/loss fields alone)
var _history_match_count: int = -1   # -1 = not yet loaded
var _history_win_count:   int = 0
var _history_loss_count:  int = 0

# Resume retry guard (prevents infinite loops if server is down)
var _code_breaker_resume_retries: int = 0
var _tgc_resume_retries: int = 0
var _resume_routed: bool = false

var current_video_index: int = 0
# Add this with the other @onready vars at the top
@onready var _shop_nav_btn: Button = $NavigationPanel/HBoxContainer/ShopNavigate
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
	if not ui_initialized:
		_initialize_profile_ui()
		ui_initialized = true

	_setup_video_and_music()
	_load_avatars()
	change_btn.pressed.connect(_on_change_avatar_pressed)
	_setup_game_sfx()
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
	_setup_shop_system() # ✅ Initialize shop system
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

	# Load CyberCoin balance and claim daily bonus
	CyberCoinManager.load_from_firestore()
	if not CyberCoinManager.balance_changed.is_connected(_on_cybercoin_balance_changed):
		CyberCoinManager.balance_changed.connect(_on_cybercoin_balance_changed)
	_setup_cybercoin_display()
	await get_tree().create_timer(1.0).timeout
	CyberCoinManager.claim_daily_bonus()

	# Load shop data from Firestore
	ShopManager.load_from_firestore()

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
	
	# Achievement slots
	_setup_achievement_slots()


# Replace these functions in your landing.gd script




func _ensure_match_history_ui() -> void:
	if not match_history_panel:
		return
	# ↑ NO extra indent after this — everything below runs normally

	# Setup tab buttons FIRST
	_setup_match_history_tabs()

	_match_history_scroll = match_history_panel.get_node_or_null("ScrollContainer")
	if not _match_history_scroll:
		_match_history_scroll = ScrollContainer.new()
		_match_history_scroll.name = "ScrollContainer"
		_match_history_scroll.anchor_left = 0.0
		_match_history_scroll.anchor_top = 0.0
		_match_history_scroll.anchor_right = 1.0
		_match_history_scroll.anchor_bottom = 1.0
		_match_history_scroll.offset_left = 8.0
		_match_history_scroll.offset_top = 75.0
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

	_clear_match_history_rows()
	

func _setup_match_history_tabs() -> void:
	var tab_bar = match_history_panel.get_node_or_null("TabBar")
	if not tab_bar:
		return

	var history_tab = tab_bar.get_node_or_null("MatchHistoryTab")
	var stats_tab = tab_bar.get_node_or_null("StatsTab")
	var inventory_tab = tab_bar.get_node_or_null("InventoryTab")

	if not history_tab or not stats_tab or not inventory_tab:
		return

	if history_tab.pressed.is_connected(_on_tab_match_history):
		return

	history_tab.pressed.connect(_on_tab_match_history)
	stats_tab.pressed.connect(_on_tab_stats)
	inventory_tab.pressed.connect(_on_tab_inventory_panel)

	if _match_history_scroll:
		_match_history_scroll.visible = false
	_on_tab_stats()


func _set_active_tab(_active: Button, _all_tabs: Array) -> void:
	pass # All styling is handled in the .tscn file

func _on_tab_match_history() -> void:
	var tab_bar = match_history_panel.get_node_or_null("TabBar")
	if tab_bar:
		_set_active_tab(tab_bar.get_node("MatchHistoryTab"),
			[tab_bar.get_node("MatchHistoryTab"),
			tab_bar.get_node("StatsTab"),
			tab_bar.get_node("InventoryTab")])

	if _match_history_scroll:
		_match_history_scroll.visible = true
	var stats_content = match_history_panel.get_node_or_null("StatsContent")
	if stats_content:
		stats_content.visible = false

	# ✅ Hide XP bar on match history tab
	if xp_progress:
		xp_progress.visible = false

	_load_match_history()


func _on_tab_stats() -> void:
	var tab_bar = match_history_panel.get_node_or_null("TabBar")
	if tab_bar:
		_set_active_tab(tab_bar.get_node("StatsTab"),
			[tab_bar.get_node("MatchHistoryTab"),
			tab_bar.get_node("StatsTab"),
			tab_bar.get_node("InventoryTab")])

	if _match_history_scroll:
		_match_history_scroll.visible = false

	if xp_progress:
		xp_progress.visible = true

	var stats_content = match_history_panel.get_node_or_null("StatsContent")
	if not stats_content:
		return
	stats_content.visible = true

	# Show cached data immediately (uses history counts if already loaded)
	_apply_stats_from_local()
	# Fetch real-time stats from Firestore (user doc for level/wins/losses)
	_fetch_stats_realtime()
	# If match history hasn't been loaded yet, load it now so match_played is accurate
	if _history_match_count < 0:
		_load_match_history()


# ─────────────────────────────────────────────────────────────────────────────
# REAL-TIME STATS HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _fetch_stats_realtime() -> void:
	"""Fetch level from Firestore, then redraw the Stats panel using history-derived counts."""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		print("[Stats] ⚠️ No auth — showing cached stats")
		_apply_stats_from_local()
		return

	_show_stats_loading(true)

	var url := "%s/%s" % [firestore_base_url, Auth.current_local_id]
	var headers := PackedStringArray(["Authorization: Bearer %s" % Auth.current_id_token])

	var http_stats := HTTPRequest.new()
	http_stats.timeout = 10.0
	add_child(http_stats)

	http_stats.request_completed.connect(func(_r, code, _h, body):
		if is_instance_valid(http_stats):
			http_stats.queue_free()

		_show_stats_loading(false)

		if code != 200:
			print("[Stats] ⚠️ Firestore returned %d — using cached data" % code)
			_apply_stats_from_local()
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("fields"):
			_apply_stats_from_local()
			return

		var f: Dictionary = data["fields"]

		# Only update level from Firestore — wins/losses are unreliable there.
		# Win/Loss counts are always derived from match history (more accurate).
		var lv := 0
		if f.has("level"):
			lv = int(str(f["level"].get("integerValue", 0)))
			if level_input:
				level_input.text = str(lv)

		# Use history-derived wins/losses; fall back to label cache if history not loaded yet.
		var w := _history_win_count  if _history_match_count >= 0 else \
				 (int(wins_input.text) if wins_input and wins_input.text.is_valid_int() else 0)
		var l := _history_loss_count if _history_match_count >= 0 else \
				 (int(losses_input.text) if losses_input and losses_input.text.is_valid_int() else 0)

		print("[Stats] ✅ Refreshed — W:%d L:%d Lv:%d (from history)" % [w, l, lv])
		_apply_stats_to_panel(w, l, lv)
	)

	http_stats.request(url, headers, HTTPClient.METHOD_GET)


func _apply_stats_from_local() -> void:
	"""Populate the Stats panel — always prefer history-derived counts."""
	# Wins/losses from history are the most accurate source (covers all game types).
	var w  := _history_win_count  if _history_match_count >= 0 else \
			  (int(wins_input.text) if wins_input and wins_input.text.is_valid_int() else 0)
	var l  := _history_loss_count if _history_match_count >= 0 else \
			  (int(losses_input.text) if losses_input and losses_input.text.is_valid_int() else 0)
	var lv := int(level_input.text) if level_input and level_input.text.is_valid_int() else 0
	_apply_stats_to_panel(w, l, lv)


func _apply_stats_to_panel(w: int, l: int, lv: int) -> void:
	"""Write computed stats into the StatsContent child nodes."""
	var stats_content = match_history_panel.get_node_or_null("StatsContent")
	if not stats_content or not stats_content.visible:
		return

	# WIN / LOSE come from history counts (passed in as w, l).
	# WIN RATE = wins / (wins + losses) for PvP matches only.
	var pvp_total := w + l
	var wr_pct    := (float(w) / float(pvp_total) * 100.0) if pvp_total > 0 else 0.0
	var wr_text   := ("%.1f%%" % wr_pct) if pvp_total > 0 else "0%"

	# MATCH PLAYED — total history count (PvP + PvE like Defuse the Trojan).
	var display_total := _history_match_count if _history_match_count >= 0 else pvp_total

	var wins_val = stats_content.get_node_or_null("WinsPanel/WinsValue")
	if wins_val: wins_val.text = str(w)

	var losses_val = stats_content.get_node_or_null("LossesPanel/LossesValue")
	if losses_val: losses_val.text = str(l)

	var wr_val = stats_content.get_node_or_null("WinRatePanel/WinRateValue")
	if wr_val: wr_val.text = wr_text

	var mp_val = stats_content.get_node_or_null("MatchPlayedPanel/MatchPlayedValue")
	if mp_val: mp_val.text = str(display_total)

	var lv_val = stats_content.get_node_or_null("LevelPanel/LevelValue")
	if lv_val: lv_val.text = str(lv) if lv > 0 else (level_input.text if level_input else "0")

	# ── Winrate progress bar (optional — if a ProgressBar node exists) ──
	var wr_bar = stats_content.get_node_or_null("WinRatePanel/WinRateBar")
	if wr_bar and wr_bar is ProgressBar:
		wr_bar.value = wr_pct


func _show_stats_loading(loading: bool) -> void:
	"""Show/hide a subtle 'Refreshing…' hint inside the StatsContent panel."""
	var stats_content = match_history_panel.get_node_or_null("StatsContent")
	if not stats_content:
		return

	var lbl = stats_content.get_node_or_null("StatsLoadingLabel")
	if loading:
		if not lbl:
			lbl = Label.new()
			lbl.name = "StatsLoadingLabel"
			lbl.text = "⟳ Refreshing…"
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl.add_theme_color_override("font_color", Color(0, 1, 1, 0.55))
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_content.add_child(lbl)
		lbl.visible = true
	else:
		if lbl:
			lbl.visible = false

func _on_tab_inventory_panel() -> void:
	var tab_bar = match_history_panel.get_node_or_null("TabBar")
	if tab_bar:
		_set_active_tab(tab_bar.get_node("InventoryTab"),
			[tab_bar.get_node("MatchHistoryTab"),
			tab_bar.get_node("StatsTab"),
			tab_bar.get_node("InventoryTab")])

	if _match_history_scroll:
		_match_history_scroll.visible = false
	var stats_content = match_history_panel.get_node_or_null("StatsContent")
	if stats_content:
		stats_content.visible = false

	# ✅ Hide XP bar on inventory tab
	if xp_progress:
		xp_progress.visible = false

	open_inventory()

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

	# ── Compute stats from history items (covers PvE games Firestore fields miss) ──
	var h_wins   := 0
	var h_losses := 0
	var my_uname := Auth.current_username
	for _doc in items:
		var _f: Dictionary = _doc.get("fields", {})
		var _gt := _fs_string(_f, "game_type", "")
		if _gt == "defuse_trojan" or _gt == "cyber_quiz":
			# PvE / Solo quiz — counts as a match played, not a win or loss
			pass
		else:
			var _winner := _fs_string(_f, "winner", "")
			var _loser  := _fs_string(_f, "loser",  "")
			var _result := _fs_string(_f, "result", "")
			if _winner == my_uname or _result.to_upper() == "WIN":
				h_wins += 1
			elif _loser == my_uname or _result.to_upper() == "LOSE":
				h_losses += 1
	_history_match_count = items.size()
	_history_win_count   = h_wins
	_history_loss_count  = h_losses
	# Sync the hidden profile labels so _apply_stats_from_local stays accurate
	if wins_input   and h_wins   > 0: wins_input.text   = str(h_wins)
	if losses_input and h_losses > 0: losses_input.text = str(h_losses)
	if match_played_input: match_played_input.text = str(items.size())
	# If the Stats tab is already open, refresh it with the newly computed counts
	var _sc = match_history_panel.get_node_or_null("StatsContent") if match_history_panel else null
	if _sc and _sc.visible:
		# Use Firestore wins/losses (authoritative) + history total for match played
		var _w  := int(wins_input.text)   if wins_input   and wins_input.text.is_valid_int()   else h_wins
		var _l  := int(losses_input.text) if losses_input and losses_input.text.is_valid_int() else h_losses
		var _lv := int(level_input.text)  if level_input  and level_input.text.is_valid_int()  else 0
		_apply_stats_to_panel(_w, _l, _lv)

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
		var game_label := "CODE BREAKER"
		match game_type:
			"code_breaker":
				game_label = "CODE BREAKER"
			"akashic", "akashic_tcg":
				game_label = "AKASHIC TCG"
			"defuse_trojan":
				game_label = "DEFUSE TROJAN"
			"cyber_quiz":
				game_label = "CYBER QUIZ"
			_:
				game_label = game_type.to_upper().replace("_", " ")

		var my_username := Auth.current_username
		var title_suffix := ""
		var subtitle_text := ""

		# Handle CyberQuiz entries (solo quiz)
		if game_type == "cyber_quiz":
			var quiz_title := _fs_string(fields, "quiz_title", "Quiz")
			var q_score := _fs_int(fields, "score", 0)
			var q_total := _fs_int(fields, "total_questions", 0)
			var q_pct := 0.0
			if fields.has("percentage"):
				var pct_raw = fields["percentage"]
				if typeof(pct_raw) == TYPE_DICTIONARY:
					if pct_raw.has("doubleValue"):
						q_pct = float(pct_raw["doubleValue"])
					elif pct_raw.has("integerValue"):
						q_pct = float(pct_raw["integerValue"])
			title_suffix = "%d/%d (%.0f%%)" % [q_score, q_total, q_pct]
			subtitle_text = quiz_title

		# Handle Defuse the Trojan differently (PvE game)
		elif game_type == "defuse_trojan":
			var wave_reached := _fs_int(fields, "wave_reached", 0)
			var mode := _fs_string(fields, "mode", "solo")
			var top_score := _fs_int(fields, "top_score", 0)
			
			title_suffix = "Wave %d" % wave_reached if wave_reached > 0 else "Completed"
			
			if mode == "solo":
				subtitle_text = "Solo — Score: %d" % top_score
			else:
				# Multiplayer: show team members
				var usernames: Array = []
				if fields.has("participant_usernames"):
					var pu = fields["participant_usernames"]
					if typeof(pu) == TYPE_DICTIONARY and pu.has("arrayValue"):
						var av = pu.get("arrayValue", {})
						var values = av.get("values", [])
						if typeof(values) == TYPE_ARRAY:
							for v in values:
								if typeof(v) == TYPE_DICTIONARY and v.has("stringValue"):
									var uname = str(v["stringValue"])
									if uname != my_username:
										usernames.append(uname)
				if usernames.size() > 0:
					subtitle_text = "Team: %s — Score: %d" % [", ".join(usernames), top_score]
				else:
					subtitle_text = "Multiplayer — Score: %d" % top_score
		else:
			# PvP games (Code Breaker, Akashic)
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
			
			title_suffix = result
			subtitle_text = "vs %s" % opponent if opponent != "" else "vs …"

		var duration := _fs_string(fields, "time_ended", "")
		var my_score := _fs_int(fields, "my_score", -1)
		var opp_score := _fs_int(fields, "opp_score", -1)
		if my_score < 0:
			my_score = _fs_int(fields, my_username, -1)
		if game_type != "defuse_trojan" and game_type != "cyber_quiz":
			var host := _fs_string(fields, "host", "")
			var client := _fs_string(fields, "client", "")
			var opponent := client if host == my_username else host
			if opp_score < 0:
				opp_score = _fs_int(fields, opponent, -1)

		var title := Label.new()
		title.text = "%s — %s" % [game_label, title_suffix]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		title.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		title.add_theme_font_size_override("font_size", 14)
		left.add_child(title)

		var subtitle := Label.new()
		subtitle.text = subtitle_text
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

	# Publish simplified history to RTDB so friends can view it on the profile modal
	_publish_match_history_to_rtdb(items)


func _publish_match_history_to_rtdb(items: Array) -> void:
	var username := Auth.current_username
	var token := Auth.current_id_token
	if username == "" or token == "":
		return
	const _RTDB := "https://capstone-823dc-default-rtdb.firebaseio.com"
	var history_data := []
	var count := mini(items.size(), 20)
	for i in range(count):
		var doc = items[i]
		var f: Dictionary = doc.get("fields", {})
		history_data.append({
			"game_type": _fs_string(f, "game_type", ""),
			"result":    _fs_string(f, "result",    ""),
			"winner":    _fs_string(f, "winner",    ""),
			"loser":     _fs_string(f, "loser",     ""),
			"opponent":  _fs_string(f, "opponent",  ""),
			"host":      _fs_string(f, "host",      ""),
			"client":    _fs_string(f, "client",    ""),
			"timestamp":    _fs_int(f, "timestamp",    0),
			"wave_reached": _fs_int(f, "wave_reached", 0),
			"top_score":    _fs_int(f, "top_score",    0),
			"mode":      _fs_string(f, "mode",      "")
		})
	var url := "%s/public_profiles/%s/recent_matches.json?auth=%s" % [_RTDB, username.uri_encode(), token]
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
	req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify(history_data))

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
	
	# EditProfileButton now lives in .tscn - just connect the signal
	var edit_btn = user_panel.get_node_or_null("EditProfileButton")
	if edit_btn:
		if not edit_btn.pressed.is_connected(_open_edit_profile_popup):
			edit_btn.pressed.connect(_open_edit_profile_popup)
	else:
		push_error("[Landing] EditProfileButton node not found in scene!")
	
	_create_xp_progress_bar()
	print("[Landing] ✅ Profile UI initialized")


func _create_xp_progress_bar() -> void:
	# Node now lives in .tscn - nothing to create
	if not xp_progress:
		push_error("[Landing] XPProgressBar node not found in scene!")
		return
	var xp_label = xp_progress.get_node_or_null("XPLabel")
	if not xp_label:
		xp_label = Label.new()
		xp_label.name = "XPLabel"
		xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		xp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		xp_label.add_theme_font_size_override("font_size", 13)
		xp_label.text = "0 / 1000 XP"
		xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_progress.add_child(xp_label)
	print("[Landing] ✅ XP Progress Bar ready")

func _refresh_profile_ui_positions() -> void:
	"""Ensure all profile UI elements are in their correct positions"""
	if rank_label:
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
		
		if icon_path.begins_with("res://"):
			var rank_texture = load(icon_path)
			if rank_texture:
				rank_icon_rect.texture = rank_texture
				rank_label.text = rank_name
				rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				rank_label.text = rank_name
		else:
			rank_label.text = "%s\n%s" % [icon_path, rank_name]
		
		rank_label.add_theme_color_override("font_color", color)

# ─────────────────────────────────────────────────────────────────────────────
# CYBERCOIN DISPLAY
# ─────────────────────────────────────────────────────────────────────────────
func _setup_cybercoin_display() -> void:
	if _cybercoin_label and is_instance_valid(_cybercoin_label):
		_cybercoin_label.text = "%d CyberCoins" % CyberCoinManager.get_balance()

func _on_cybercoin_balance_changed(new_balance: int) -> void:
	if _cybercoin_label and is_instance_valid(_cybercoin_label):
		_cybercoin_label.text = "%d CyberCoins" % new_balance
		
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
	"""Show the Edit Profile popup (scene-based, responsive to any resolution)."""
	if edit_profile_popup and is_instance_valid(edit_profile_popup):
		return  # Already open

	# Store original values for cancel/restore
	original_username = username_input.text
	original_avatar = selected_avatar

	# Instantiate the scene-based popup
	var popup_scene := preload("res://scene/edit_profile_popup.tscn")
	edit_profile_popup = popup_scene.instantiate()
	edit_profile_popup.z_index = 1000
	add_child(edit_profile_popup)

	# --- Grab references inside the popup ---
	var avatar_preview: TextureRect = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/AvatarSection/AvatarVBox/AvatarCenter/AvatarPreview")
	var change_avatar_btn: Button = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/AvatarSection/AvatarVBox/ButtonCenter/ButtonVBox/ChangeAvatarBtn")
	var preset_btn: Button = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/AvatarSection/AvatarVBox/ButtonCenter/ButtonVBox/PresetAvatarsBtn")
	var username_edit: LineEdit = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/UsernameSection/UsernameVBox/UsernameEdit")
	var char_count: Label = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/UsernameSection/UsernameVBox/CharCount")
	var save_button: Button = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/ButtonSection/ButtonHBox/SaveButton")
	var cancel_button: Button = edit_profile_popup.get_node("CenterContainer/PopupPanel/VBoxContent/ButtonSection/ButtonHBox/CancelButton")
	var dimmer: Panel = edit_profile_popup.get_node("Dimmer")

	# --- Populate with current data ---
	if profile_pic and profile_pic.texture:
		avatar_preview.texture = profile_pic.texture
	username_edit.text = username_input.text
	char_count.text = "%d / 20" % username_edit.text.length()

	# --- Load button icons ---
	var folder_icon = load("res://asset/icons/folder_icon.png")
	if folder_icon:
		var img = folder_icon.get_image()
		if img:
			img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
			folder_icon = ImageTexture.create_from_image(img)
		change_avatar_btn.icon = folder_icon

	var palette_icon = load("res://asset/icons/palette_icon.png")
	if palette_icon:
		var img = palette_icon.get_image()
		if img:
			img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
			palette_icon = ImageTexture.create_from_image(img)
		preset_btn.icon = palette_icon

	# --- Wire signals ---
	change_avatar_btn.pressed.connect(func():
		file_dialog.popup_centered(Vector2(700, 500))
	)
	preset_btn.pressed.connect(func():
		avatar_picker.popup_centered()
	)
	dimmer.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_edit_profile_popup()
	)

	username_edit.text_changed.connect(func(new_text: String):
		char_count.text = "%d / 20" % new_text.length()
		if new_text.length() >= 18:
			char_count.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
		else:
			char_count.add_theme_color_override("font_color", Color(0, 0.7, 0.8, 0.8))
	)

	save_button.pressed.connect(func():
		var new_username = username_edit.text.strip_edges()
		if new_username.length() < 3:
			_show_error_message("Username must be at least 3 characters!")
			return
		if new_username.length() > 20:
			_show_error_message("Username must be 20 characters or less!")
			return
		username_input.text = new_username
		Auth.current_username = new_username
		_save_profile_changes()
		_close_edit_profile_popup()
	)

	cancel_button.pressed.connect(func():
		username_input.text = original_username
		selected_avatar = original_avatar
		if selected_avatar.begins_with("user://") and FileAccess.file_exists(selected_avatar):
			var img = Image.load_from_file(selected_avatar)
			if img:
				img.resize(100, 100, Image.INTERPOLATE_LANCZOS)
				profile_pic.texture = ImageTexture.create_from_image(img)
		elif avatars.has(selected_avatar):
			profile_pic.texture = avatars[selected_avatar]
		_close_edit_profile_popup()
	)

	# Animate entrance
	edit_profile_popup.modulate.a = 0
	var popup_panel = edit_profile_popup.get_node("CenterContainer/PopupPanel")
	popup_panel.scale = Vector2(0.85, 0.85)
	popup_panel.pivot_offset = popup_panel.size / 2.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(edit_profile_popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(popup_panel, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Focus on username input
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(username_edit):
		username_edit.grab_focus()


func _close_edit_profile_popup() -> void:
	"""Close the edit profile popup with animation"""
	if not edit_profile_popup or not is_instance_valid(edit_profile_popup):
		return

	var popup_panel = edit_profile_popup.get_node_or_null("CenterContainer/PopupPanel")
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(edit_profile_popup, "modulate:a", 0.0, 0.2)
	if popup_panel:
		tween.tween_property(popup_panel, "scale", Vector2(0.85, 0.85), 0.2)
	await tween.finished
	if is_instance_valid(edit_profile_popup):
		edit_profile_popup.queue_free()
	edit_profile_popup = null

func _show_error_message(message: String) -> void:
	"""Show temporary error message in the popup"""
	if not edit_profile_popup or not is_instance_valid(edit_profile_popup):
		return

	var error_panel = edit_profile_popup.get_node_or_null("CenterContainer/PopupPanel/VBoxContent/UsernameSection/UsernameVBox/ErrorMessage")
	if not error_panel:
		return
	var error_label = error_panel.get_node_or_null("ErrorLabel")
	if not error_label:
		return

	error_label.text = "⚠ " + message
	error_panel.visible = true
	error_panel.modulate.a = 1.0

	# Fade out after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(error_panel):
		var fade = create_tween()
		fade.tween_property(error_panel, "modulate:a", 0.0, 0.5)
		await fade.finished
		if is_instance_valid(error_panel):
			error_panel.visible = false

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
	var img = Image.load_from_file(path)
	if img:
		img.resize(80, 80, Image.INTERPOLATE_LANCZOS)
		var texture = ImageTexture.create_from_image(img)
		profile_pic.texture = texture
		
		var user_avatar_path = "user://custom_avatar_%s.png" % Auth.current_local_id
		img.save_png(user_avatar_path)
		selected_avatar = user_avatar_path
		
		if edit_profile_popup and is_instance_valid(edit_profile_popup):
			var preview = edit_profile_popup.get_node_or_null("AvatarPreview")
			if preview:
				preview.texture = texture
		
		print("[Landing] ✅ Custom avatar loaded")
	else:
		_show_error_message("Failed to load image")

func _on_avatar_selected(file_name: String) -> void:
	if avatars.has(file_name):
		profile_pic.texture = avatars[file_name]
		selected_avatar = file_name
		avatar_picker.hide()
		
		if edit_profile_popup and is_instance_valid(edit_profile_popup):
			var preview = edit_profile_popup.get_node_or_null("AvatarPreview")
			if preview:
				preview.texture = avatars[file_name]
		
		print("[Landing] ✅ Preset avatar loaded")

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

	# Load equipped badge / card from inventory
	if Auth:
		if f.has("equipped_badge"):
			Auth.current_equipped_badge = str(f["equipped_badge"].get("stringValue", ""))
		else:
			Auth.current_equipped_badge = ""
		if f.has("equipped_card"):
			Auth.current_equipped_card = str(f["equipped_card"].get("stringValue", ""))
		else:
			Auth.current_equipped_card = ""

	# Load equipped achievement badges
	if f.has("equipped_achievements"):
		var arr = f["equipped_achievements"].get("arrayValue", {}).get("values", [])
		for i in range(min(arr.size(), 3)):
			_equipped_achievements[i] = arr[i].get("stringValue", "")
	for i in range(3):
		_refresh_achievement_slot(i)

	if f.has("level"):
		var lvl := int(f["level"]["integerValue"])
		level_input.text = str(lvl)
		if Auth:
			Auth.current_level = lvl

	var total_w := 0
	var total_l := 0

	if f.has("cb_wins"): total_w += int(f["cb_wins"]["integerValue"])
	if f.has("cb_losses"): total_l += int(f["cb_losses"]["integerValue"])

	if f.has("akashic_wins"): total_w += int(f["akashic_wins"]["integerValue"])
	if f.has("akashic_losses"): total_l += int(f["akashic_losses"]["integerValue"])

	if f.has("dt_wins"): total_w += int(f["dt_wins"]["integerValue"])
	if f.has("dt_losses"): total_l += int(f["dt_losses"]["integerValue"])

	if total_w == 0 and f.has("wins"): total_w += int(f["wins"]["integerValue"])
	if total_l == 0 and f.has("losses"): total_l += int(f["losses"]["integerValue"])

	wins_input.text = str(total_w)
	losses_input.text = str(total_l)
	
	if match_played_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)

	# Publish public profile to RTDB so friends can view it (bypasses Firestore 403)
	var _pub_w := int(wins_input.text) if wins_input and wins_input.text.is_valid_int() else 0
	var _pub_l := int(losses_input.text) if losses_input and losses_input.text.is_valid_int() else 0
	Auth.publish_public_profile({
		"wins": _pub_w,
		"losses": _pub_l,
		"total_xp": int(str(f["total_xp"].get("integerValue", f["total_xp"].get("doubleValue", 0)))) if f.has("total_xp") else 0,
		"level": int(level_input.text) if level_input and level_input.text.is_valid_int() else 0,
		"avatar": selected_avatar,
		"cb_wins":        int(str(f["cb_wins"].get("integerValue", 0)))        if f.has("cb_wins")        else 0,
		"cb_losses":      int(str(f["cb_losses"].get("integerValue", 0)))      if f.has("cb_losses")      else 0,
		"akashic_wins":   int(str(f["akashic_wins"].get("integerValue", 0)))   if f.has("akashic_wins")   else 0,
		"akashic_losses": int(str(f["akashic_losses"].get("integerValue", 0))) if f.has("akashic_losses") else 0,
		"dt_wins":        int(str(f["dt_wins"].get("integerValue", 0)))        if f.has("dt_wins")        else 0,
		"dt_losses":      int(str(f["dt_losses"].get("integerValue", 0)))      if f.has("dt_losses")      else 0,
	})
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
	if ResourceLoader.exists("res://asset/newUIlandingupdate/beginnerbadgdes.png"):
		guide_icon = load("res://asset/newUIlandingupdate/beginnerbadgdes.png")

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
			"icon_path": "res://asset/newUIlandingupdate/beginnerbadgdes.png",
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
		
		if icon_path.begins_with("res://") and rank_icon_rect:
			var rank_texture = load(icon_path)
			if rank_texture:
				rank_icon_rect.texture = rank_texture
				rank_label.text = rank_name
				rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				rank_label.text = rank_name
		else:
			rank_label.text = "%s\n%s" % [icon_path, rank_name]
		
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


# === Load avatars from catalog (works in exported builds) ===
func _load_avatars() -> void:
	avatars.clear()
	# DirAccess cannot list res:// in exported builds (.pck),
	# so use the hardcoded AvatarCatalog keys instead.
	var avatar_files: Array = AvatarCatalog.DISPLAY_NAMES.keys()
	avatar_files.sort()
	for file_name in avatar_files:
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

	var total_w := 0
	var total_l := 0

	if f.has("cb_wins"): total_w += int(f["cb_wins"]["integerValue"])
	if f.has("cb_losses"): total_l += int(f["cb_losses"]["integerValue"])

	if f.has("akashic_wins"): total_w += int(f["akashic_wins"]["integerValue"])
	if f.has("akashic_losses"): total_l += int(f["akashic_losses"]["integerValue"])

	if f.has("dt_wins"): total_w += int(f["dt_wins"]["integerValue"])
	if f.has("dt_losses"): total_l += int(f["dt_losses"]["integerValue"])

	if total_w == 0 and f.has("wins"): total_w += int(f["wins"]["integerValue"])
	if total_l == 0 and f.has("losses"): total_l += int(f["losses"]["integerValue"])

	wins_input.text = str(total_w)
	losses_input.text = str(total_l)

	if match_played_input:
		var wins = int(wins_input.text) if wins_input.text.is_valid_int() else 0
		var losses = int(losses_input.text) if losses_input.text.is_valid_int() else 0
		match_played_input.text = str(wins + losses)

	# ── Load equipped achievement badges (cached-path fix) ──
	if f.has("equipped_achievements"):
		var arr = f["equipped_achievements"].get("arrayValue", {}).get("values", [])
		for i in range(min(arr.size(), 3)):
			_equipped_achievements[i] = arr[i].get("stringValue", "")
	for i in range(3):
		_refresh_achievement_slot(i)

	original_avatar = selected_avatar

	# Load match history after we have username/uid (also populates _history_match_count)
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
# ✅ If showing profile panel, ensure UI is properly positioned
		if panel_name == "profile":
			_refresh_profile_ui_positions()
			# Re-initialise the UI structure only (no data load yet).
			# Data is loaded on demand when the user clicks a tab.
			_ensure_match_history_ui()
			# Default to Stats tab so match history scroll stays hidden.
			if _match_history_scroll:
				_match_history_scroll.visible = false
			_on_tab_stats()

	var friend_list = $VideoStreamPlayer.get_node_or_null("FriendListPanel")
	if friend_list:
		friend_list.visible = (panel_name != "game")

func _setup_navigation() -> void:

	_setup_game_card_hovers()
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
	_add_shop_nav_button()
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
	
	# Setup leaderboard
	_setup_leaderboard()


func _on_module_button_pressed() -> void:
	# Check if user has seen cybersecurity intro
	_check_intro_completion()

func _check_intro_completion() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[Landing] Auth not ready!")
		return
	
	var url = firestore_base_url + "/%s" % Auth.current_local_id
	var headers = ["Authorization: Bearer " + Auth.current_id_token]
	
	var intro_http = HTTPRequest.new()
	add_child(intro_http)
	intro_http.request_completed.connect(func(_r, code, _h, body):
		intro_http.queue_free()
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
	
	intro_http.request(url, headers, HTTPClient.METHOD_GET)

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
	CyberCoinManager.reset_data()
	ShopManager.reset_data()
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
		
		# ✅ Play click sound
		if click_sfx and click_sfx.stream:
			click_sfx.play()
		
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
		
		# ✅ Play click sound
		if click_sfx and click_sfx.stream:
			click_sfx.play()
		
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


func _go_to_defuse_trojan_lobby() -> void:
	"""Show Defuse The Trojan lobby panel (single/multiplayer selection)"""
	var game_select_panel = $VideoStreamPlayer/GameSelectPanel
	if game_select_panel:
		game_select_panel.visible = false

	var code_breaker_lobby = $VideoStreamPlayer.get_node_or_null("CodeBreakerLobby")
	if code_breaker_lobby:
		code_breaker_lobby.visible = false

	var akashic_lobby = $VideoStreamPlayer.get_node_or_null("AkashicLobby")
	if akashic_lobby:
		akashic_lobby.visible = false

	var defuse_lobby = $VideoStreamPlayer.get_node_or_null("DefuseTrojanLobby")
	if defuse_lobby:
		defuse_lobby.visible = true
	else:
		push_error("[Landing] DefuseTrojanLobby not found")


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
	if not profile_pic:
		return
	# ONLY set how the texture renders, NOT position or size
	profile_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		if inventory_panel.has_signal("badge_equipped"):
			inventory_panel.badge_equipped.connect(_on_inventory_badge_equipped)
		
		print("[Landing] ✅ Inventory system initialized")
	else:
		push_error("[Landing] ❌ Failed to load inventory_panel.tscn")

func _on_inventory_badge_equipped(badge_data: Dictionary) -> void:
	var icon_path: String = str(badge_data.get("icon_path", ""))
	if icon_path.strip_edges() == "":
		return
	# Check if already in a slot
	for i in range(3):
		if _equipped_achievements[i] == icon_path:
			return
	# Find first empty slot
	var target_slot: int = -1
	for i in range(3):
		if _equipped_achievements[i] == "":
			target_slot = i
			break
	if target_slot == -1:
		_show_badge_slots_full_notification()
		return
	_equipped_achievements[target_slot] = icon_path
	_refresh_achievement_slot(target_slot)
	_save_equipped_achievements()

func _show_badge_slots_full_notification() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Badge Slots Full"
	dialog.dialog_text = "All 3 badge slots are full!\nRemove a badge from your profile first."
	dialog.ok_button_text = "OK"
	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 120))
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _on_inventory_avatar_selected(file_name: String) -> void:
	# Load texture (try preloaded dict first, then load from disk)
	var tex = avatars.get(file_name, null)
	if tex == null and ResourceLoader.exists("res://asset/avatars/" + file_name):
		tex = load("res://asset/avatars/" + file_name)
	if tex == null:
		push_error("[Landing] Could not load avatar: %s" % file_name)
		return

	# Update local UI
	profile_pic.texture = tex
	selected_avatar = file_name
	original_avatar = file_name
	Auth.current_avatar = file_name

	# Persist to Firestore immediately
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id != "" and id_token != "":
		last_avatar_change = int(Time.get_unix_time_from_system())
		var url = "%s/%s?updateMask.fieldPaths=avatar&updateMask.fieldPaths=last_avatar_change" % [firestore_base_url, user_id]
		var body = {
			"fields": {
				"avatar": {"stringValue": file_name},
				"last_avatar_change": {"integerValue": str(last_avatar_change)}
			}
		}
		var headers = [
			"Content-Type: application/json",
			"Authorization: Bearer %s" % id_token
		]
		var http_req := HTTPRequest.new()
		add_child(http_req)
		http_req.request_completed.connect(func(_r, code, _h, _b):
			http_req.queue_free()
			if code == 200:
				print("[Landing] ✅ Avatar set from inventory: %s" % file_name)
			else:
				push_error("[Landing] Failed to save avatar from inventory: HTTP %d" % code)
		)
		http_req.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	print("[Landing] ✅ Inventory avatar applied: %s" % file_name)

func _on_inventory_closed() -> void:
	"""Called when inventory panel is closed"""
	print("[Landing] Inventory panel closed")

func open_inventory() -> void:
	"""Open the inventory/bag panel"""
	if inventory_panel:
		inventory_panel.show_inventory()
	else:
		push_error("[Landing] Inventory panel not initialized!")


func _setup_shop_system() -> void:
	"""Load and setup the shop panel as overlay"""
	if shop_panel_instance and is_instance_valid(shop_panel_instance):
		return
	var shop_scene = load("res://scene/shop_panel.tscn")
	if shop_scene:
		shop_panel_instance = shop_scene.instantiate()
		add_child(shop_panel_instance)
		shop_panel_instance.z_index = 999
		if shop_panel_instance.has_signal("shop_closed"):
			shop_panel_instance.shop_closed.connect(func(): print("[Landing] Shop panel closed"))
		print("[Landing] ✅ Shop system initialized")
	else:
		push_error("[Landing] ❌ Failed to load shop_panel.tscn")


func open_shop() -> void:
	"""Open the shop panel"""
	if shop_panel_instance and is_instance_valid(shop_panel_instance):
		shop_panel_instance.show_shop()
	else:
		push_error("[Landing] Shop panel not initialized!")


func _add_shop_nav_button() -> void:
		if _shop_nav_btn:
			_shop_nav_btn.pressed.connect(open_shop)


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
	audio_player.volume_db = 0.0  # Full volume - SettingsManager controls Master bus
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
	tween_in.tween_property(audio_player, "volume_db", 0.0, music_fade_duration)  # Full volume
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
		print("[Landing] 🎮 DefuseTheTrojan card clicked - opening lobby!")
		
		# ✅ Play click sound
		if click_sfx and click_sfx.stream:
			click_sfx.play()
			await click_sfx.finished  # Wait for sound to finish (optional)
		
		_go_to_defuse_trojan_lobby()

# === LEADERBOARD SYSTEM (RTDB) ===
const RTDB_LEADERBOARD_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"

func _setup_leaderboard() -> void:
	var ranking_panel = $VideoStreamPlayer/RankingPanel
	if not ranking_panel:
		print("[Landing] ⚠️ RankingPanel not found")
		return
	
	var list_panel = ranking_panel.get_node_or_null("list")
	if not list_panel:
		print("[Landing] ⚠️ RankingPanel/list not found")
		return
	
	# Create ScrollContainer inside list panel if not exists
	_leaderboard_scroll = list_panel.get_node_or_null("ScrollContainer")
	if not _leaderboard_scroll:
		_leaderboard_scroll = ScrollContainer.new()
		_leaderboard_scroll.name = "ScrollContainer"
		_leaderboard_scroll.anchor_left = 0.0
		_leaderboard_scroll.anchor_top = 0.0
		_leaderboard_scroll.anchor_right = 1.0
		_leaderboard_scroll.anchor_bottom = 1.0
		_leaderboard_scroll.offset_left = 8.0
		_leaderboard_scroll.offset_top = 8.0
		_leaderboard_scroll.offset_right = -8.0
		_leaderboard_scroll.offset_bottom = -8.0
		list_panel.add_child(_leaderboard_scroll)
	
	# Create VBox inside scroll
	_leaderboard_vbox = _leaderboard_scroll.get_node_or_null("VBoxContainer")
	if not _leaderboard_vbox:
		_leaderboard_vbox = VBoxContainer.new()
		_leaderboard_vbox.name = "VBoxContainer"
		_leaderboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_leaderboard_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_leaderboard_vbox.add_theme_constant_override("separation", 6)
		_leaderboard_scroll.add_child(_leaderboard_vbox)
	
	# Connect tab buttons
	var akashic_btn = ranking_panel.get_node_or_null("AkashicTgcRank")
	var cb_btn = ranking_panel.get_node_or_null("CodeBreakerRank")
	var dt_btn = ranking_panel.get_node_or_null("DefuseTrojanRank")
	
	if akashic_btn:
		akashic_btn.pressed.connect(func(): _load_leaderboard("akashic_tcg"))
	if cb_btn:
		cb_btn.pressed.connect(func(): _load_leaderboard("code_breaker"))
	if dt_btn:
		dt_btn.pressed.connect(func(): _load_leaderboard("defuse_trojan"))
	
	# Load Code Breaker by default
	_load_leaderboard("code_breaker")


func _load_leaderboard(game_type: String) -> void:
	_current_leaderboard_game = game_type
	_clear_leaderboard()
	_add_leaderboard_placeholder("Loading...")
	
	print("[Landing] 📊 Loading leaderboard for: %s" % game_type)
	
	if Auth.current_id_token == "":
		_clear_leaderboard()
		_add_leaderboard_placeholder("Not logged in")
		return
	
	# Use RTDB instead of Firestore - simple read, sort client-side
	var url := "%s/leaderboards/%s.json?auth=%s" % [
		RTDB_LEADERBOARD_BASE, game_type, Auth.current_id_token
	]
	print("[Landing] 📊 Leaderboard URL: %s" % url.substr(0, 100))
	
	var http_lb := HTTPRequest.new()
	add_child(http_lb)
	
	http_lb.request_completed.connect(func(_r, code, _h, body):
		http_lb.queue_free()
		
		var body_text: String = ""
		if body.size() > 0:
			body_text = body.get_string_from_utf8()
		print("[Landing] 📊 Leaderboard HTTP code: %d, body size: %d" % [code, body.size()])
		
		if code != 200:
			print("[Landing] ⚠️ Leaderboard query failed: %d" % code)
			print("[Landing] ⚠️ Error response: %s" % body_text.substr(0, 500))
			_clear_leaderboard()
			_add_leaderboard_placeholder("Failed to load leaderboard (HTTP %d)" % code)
			return
		
		var users := _parse_rtdb_leaderboard(body_text, game_type)
		print("[Landing] 📊 Parsed %d users for leaderboard" % users.size())
		_render_leaderboard(users, game_type)
	)
	
	http_lb.request(url)


func _parse_rtdb_leaderboard(body_text: String, game_type: String) -> Array:
	"""Parse RTDB leaderboard response"""
	var parsed = JSON.parse_string(body_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		print("[Landing] ⚠️ Leaderboard data is null or not a dictionary")
		return []
	
	var users: Array = []
	
	for uid in parsed.keys():
		var entry = parsed[uid]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		
		var user_data := {
			"username": str(entry.get("username", "Unknown")),
			"avatar": str(entry.get("avatar", "")),
			"uid": uid
		}
		
		match game_type:
			"code_breaker":
				user_data["wins"] = int(entry.get("wins", 0))
				user_data["losses"] = int(entry.get("losses", 0))
				user_data["games"] = int(entry.get("games", 0))
				user_data["sort_key"] = user_data["wins"]
			"akashic_tcg":
				user_data["wins"] = int(entry.get("wins", 0))
				user_data["losses"] = int(entry.get("losses", 0))
				user_data["games"] = int(entry.get("games", 0))
				user_data["sort_key"] = user_data["wins"]
			"defuse_trojan":
				user_data["best_wave"] = int(entry.get("best_wave", 0))
				user_data["high_score"] = int(entry.get("high_score", 0))
				user_data["games"] = int(entry.get("games", 0))
				user_data["sort_key"] = user_data["best_wave"] * 100000 + user_data["high_score"]
		
		# Only include users who have played
		if user_data.get("games", 0) > 0 or user_data.get("sort_key", 0) > 0:
			users.append(user_data)
	
	# Sort by sort_key descending
	users.sort_custom(func(a, b):
		return int(a.get("sort_key", 0)) > int(b.get("sort_key", 0))
	)
	
	return users


func _render_leaderboard(users: Array, game_type: String) -> void:
	_clear_leaderboard()
	
	if users.is_empty():
		_add_leaderboard_placeholder("No players yet")
		return
	
	# Add header
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	header.custom_minimum_size = Vector2(0, 32)
	
	var rank_header := Label.new()
	rank_header.text = "#"
	rank_header.custom_minimum_size = Vector2(40, 0)
	rank_header.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	rank_header.add_theme_font_size_override("font_size", 14)
	header.add_child(rank_header)
	
	var name_header := Label.new()
	name_header.text = "Player"
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_header.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	name_header.add_theme_font_size_override("font_size", 14)
	header.add_child(name_header)
	
	var stat_header := Label.new()
	match game_type:
		"code_breaker", "akashic_tcg":
			stat_header.text = "W / L"
		"defuse_trojan":
			stat_header.text = "Best Wave / Score"
	stat_header.custom_minimum_size = Vector2(120, 0)
	stat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stat_header.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	stat_header.add_theme_font_size_override("font_size", 14)
	header.add_child(stat_header)
	
	_leaderboard_vbox.add_child(header)
	
	# Add separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0, 0.8, 1, 0.5))
	_leaderboard_vbox.add_child(sep)
	
	# Render top 20 users
	var rank := 1
	for user in users.slice(0, 20):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 36)
		
		# Rank number with medal colors for top 3
		var lb_rank_label := Label.new()
		lb_rank_label.text = str(rank)
		lb_rank_label.custom_minimum_size = Vector2(40, 0)
		match rank:
			1:
				lb_rank_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))  # Gold
			2:
				lb_rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))  # Silver
			3:
				lb_rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2, 1))  # Bronze
			_:
				lb_rank_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 0.9))
		lb_rank_label.add_theme_font_size_override("font_size", 16)
		row.add_child(lb_rank_label)
		
		# Username
		var name_label := Label.new()
		name_label.text = str(user.get("username", "Unknown"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)
		
		# Stats
		var stat_label := Label.new()
		match game_type:
			"code_breaker", "akashic_tcg":
				var wins := int(user.get("wins", 0))
				var losses := int(user.get("losses", 0))
				stat_label.text = "%d / %d" % [wins, losses]
			"defuse_trojan":
				var best_wave := int(user.get("best_wave", 0))
				var high_score := int(user.get("high_score", 0))
				stat_label.text = "Wave %d / %d pts" % [best_wave, high_score]
		stat_label.custom_minimum_size = Vector2(120, 0)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
		stat_label.add_theme_font_size_override("font_size", 14)
		row.add_child(stat_label)
		
		_leaderboard_vbox.add_child(row)
		rank += 1


func _clear_leaderboard() -> void:
	if not _leaderboard_vbox:
		return
	for child in _leaderboard_vbox.get_children():
		child.queue_free()


func _add_leaderboard_placeholder(text: String) -> void:
	if not _leaderboard_vbox:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 0.8))
	_leaderboard_vbox.add_child(lbl)


# === LEADERBOARD UPDATE HELPERS (Call from postgame scripts) ===
static func update_leaderboard_rtdb(game_type: String, uid: String, username: String, stats: Dictionary) -> void:
	"""
	Update leaderboard entry in RTDB. Call this from postgame scripts.
	
	Example usage for Code Breaker:
		Landing.update_leaderboard_rtdb("code_breaker", Auth.current_user_id, username, {
			"wins": new_wins,
			"losses": new_losses,
			"games": total_games
		})
	
	Example usage for Defuse Trojan:
		Landing.update_leaderboard_rtdb("defuse_trojan", Auth.current_user_id, username, {
			"best_wave": best_wave,
			"high_score": high_score,
			"games": total_games
		})
	"""
	if uid == "" or game_type == "":
		print("[Landing] ⚠️ Cannot update leaderboard - missing uid or game_type")
		return
	
	var token := Auth.current_id_token
	if token == "":
		print("[Landing] ⚠️ Cannot update leaderboard - not logged in")
		return
	
	# Calculate sort_key based on game type
	var sort_key: int = 0
	match game_type:
		"code_breaker", "akashic_tcg":
			sort_key = int(stats.get("wins", 0))
		"defuse_trojan":
			sort_key = int(stats.get("best_wave", 0)) * 100000 + int(stats.get("high_score", 0))
	
	var entry := {
		"username": username,
		"sort_key": sort_key
	}
	# Merge stats into entry
	for key in stats.keys():
		entry[key] = stats[key]
	
	var url := "%s/leaderboards/%s/%s.json?auth=%s" % [
		"https://capstone-823dc-default-rtdb.firebaseio.com", game_type, uid, token
	]
	
	var lb_http := HTTPRequest.new()
	Engine.get_main_loop().root.add_child(lb_http)
	
	lb_http.request_completed.connect(func(_r, code, _h, _b):
		lb_http.queue_free()
		if code == 200:
			print("[Landing] ✅ Leaderboard updated for %s (%s)" % [username, game_type])
		else:
			print("[Landing] ⚠️ Failed to update leaderboard: HTTP %d" % code)
	)
	
	var headers := PackedStringArray(["Content-Type: application/json"])
	lb_http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(entry))

func _setup_game_card_hovers() -> void:
		var defuse = $VideoStreamPlayer/GameSelectPanel/allgame/DefuseTheTrojan
		var akashic = $VideoStreamPlayer/GameSelectPanel/allgame/AkashicTCG
		var code_breaker = $VideoStreamPlayer/GameSelectPanel/allgame/CodeBreaker
		
		if defuse:
			defuse.mouse_filter = Control.MOUSE_FILTER_STOP
			defuse.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			defuse.mouse_entered.connect(_on_card_hover.bind(defuse, "DefuseTheTrojan"))
			defuse.mouse_exited.connect(_on_card_hover_exit.bind(defuse, "DefuseTheTrojan"))
		
		if akashic:
			akashic.mouse_filter = Control.MOUSE_FILTER_STOP
			akashic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			akashic.mouse_entered.connect(_on_card_hover.bind(akashic, "AkashicTCG"))
			akashic.mouse_exited.connect(_on_card_hover_exit.bind(akashic, "AkashicTCG"))
		
		if code_breaker:
			code_breaker.mouse_filter = Control.MOUSE_FILTER_STOP
			code_breaker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			code_breaker.mouse_entered.connect(_on_card_hover.bind(code_breaker, "CodeBreaker"))
			code_breaker.mouse_exited.connect(_on_card_hover_exit.bind(code_breaker, "CodeBreaker"))

func _on_card_hover(card: NinePatchRect, card_name: String) -> void:
	if card_textures.has(card_name):
		card.texture = card_textures[card_name]["hover"]
		print("[Landing] 🎨 Hover: %s" % card_name)
		
		# ✅ Play hover sound with debugging
		if hover_sfx:
			if hover_sfx.stream:
				print("[Landing] 🔊 Playing hover sound - Volume: %f dB" % hover_sfx.volume_db)
				hover_sfx.play()
				print("[Landing] 🔊 Is playing: ", hover_sfx.playing)
			else:
				push_error("[Landing] ❌ Hover sound stream is null!")
		else:
			push_error("[Landing] ❌ hover_sfx is null!")

func _on_card_hover_exit(card: NinePatchRect, card_name: String) -> void:
		if card_textures.has(card_name):
			card.texture = card_textures[card_name]["normal"]
			print("[Landing] 🎨 Unhover: %s" % card_name)

func _setup_game_sfx() -> void:
	"""Setup sound effects for game selection cards"""
	
	# Create hover sound player
	hover_sfx = AudioStreamPlayer.new()
	hover_sfx.name = "GameCardHoverSFX"
	hover_sfx.volume_db = -2.0
	hover_sfx.bus = "Master"  # ✅ Explicitly set the bus
	add_child(hover_sfx)
	
	# Load hover sound
	var hover_sound = load("res://asset/audio/GameSelectPanelhover.mp3")
	if hover_sound:
		hover_sfx.stream = hover_sound
		print("[Landing] ✅ Hover sound loaded: ", hover_sound.resource_path)
	else:
		push_error("[Landing] ❌ Failed to load hover sound!")
	
	# Create click sound player
	click_sfx = AudioStreamPlayer.new()
	click_sfx.name = "GameCardClickSFX"
	click_sfx.volume_db = -8.0
	click_sfx.bus = "Master"  # ✅ Explicitly set the bus
	add_child(click_sfx)
	
	# Load click sound
	var click_sound = load("res://asset/audio/GameSelectPanelclick.mp3")
	if click_sound:
		click_sfx.stream = click_sound
		print("[Landing] ✅ Click sound loaded: ", click_sound.resource_path)
	else:
		push_error("[Landing] ❌ Failed to load click sound!")


# =============================================================================
# ACHIEVEMENT PICKER — slot click setup, picker popup, Firestore save
# =============================================================================
func _setup_achievement_slots() -> void:
	var base := "VideoStreamPlayer/ProfilePanel/UserPanel/RankIconRect/"
	_ach_slot_0 = get_node_or_null(base + "1stachievmentslot")
	_ach_slot_1 = get_node_or_null(base + "2ndachievementslot")
	_ach_slot_2 = get_node_or_null(base + "3rdachievementslot")
	_ach_pic_0  = get_node_or_null(base + "1stachievmentslot/1stachievementpicture")
	_ach_pic_1  = get_node_or_null(base + "2ndachievementslot/2ndachievementpicture")
	_ach_pic_2  = get_node_or_null(base + "3rdachievementslot/3rdachievementpicture")

	var raw_slots: Array = [_ach_slot_0, _ach_slot_1, _ach_slot_2]
	for i in range(raw_slots.size()):
		var slot: PanelContainer = raw_slots[i] as PanelContainer
		if not is_instance_valid(slot):
			continue
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i  # capture for lambda
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_open_achievement_picker(idx)
		)


func _open_achievement_picker(slot_index: int) -> void:
	var picker: AchievementPickerPopup = preload("res://scene/achievement_picker_popup.tscn").instantiate()
	add_child(picker)
	picker.achievement_picked.connect(func(ach_id: String):
		_on_achievement_pick_confirmed(ach_id, slot_index)
	)
	picker.slot_cleared.connect(func():
		_on_achievement_slot_cleared(slot_index)
	)
	picker.show_picker(slot_index, _equipped_achievements[slot_index])


func _on_achievement_pick_confirmed(ach_id: String, slot_index: int) -> void:
	_equipped_achievements[slot_index] = ach_id
	_refresh_achievement_slot(slot_index)
	_save_equipped_achievements()


func _on_achievement_slot_cleared(slot_index: int) -> void:
	_equipped_achievements[slot_index] = ""
	_refresh_achievement_slot(slot_index)
	_save_equipped_achievements()


func _refresh_achievement_slot(slot_index: int) -> void:
	var pics := [_ach_pic_0, _ach_pic_1, _ach_pic_2]
	if slot_index < 0 or slot_index >= pics.size():
		return
	var pic: TextureRect = pics[slot_index]
	if not is_instance_valid(pic):
		return
	var ach_id: String = _equipped_achievements[slot_index]
	if ach_id == "":
		pic.texture = null
		pic.modulate = Color(1, 1, 1, 1)
		return
	# Support direct icon paths (from inventory badges) or achievement IDs
	var badge_path: String = ""
	if ach_id.begins_with("res://"):
		badge_path = ach_id
	elif AchievementPickerPopup.ACHIEVEMENT_DEFS.has(ach_id):
		badge_path = AchievementPickerPopup.ACHIEVEMENT_DEFS[ach_id]["badge"]
	if badge_path != "" and ResourceLoader.exists(badge_path):
		pic.texture = load(badge_path)
		pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.modulate = Color(1, 1, 1, 1)
	else:
		pic.texture = null
		pic.modulate = Color(1, 1, 1, 1)


func _save_equipped_achievements() -> void:
	var user_id := Auth.current_local_id
	var id_token := Auth.current_id_token
	if user_id == "" or id_token == "":
		return
	var url := "%s/%s?updateMask.fieldPaths=equipped_achievements" % [firestore_base_url, user_id]
	var values := []
	for id in _equipped_achievements:
		values.append({"stringValue": id})
	var body := {
		"fields": {
			"equipped_achievements": {"arrayValue": {"values": values}}
		}
	}
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	var save_http := HTTPRequest.new()
	add_child(save_http)
	save_http.request_completed.connect(func(_r, code, _h, _b):
		save_http.queue_free()
		if code == 200:
			print("[Landing] ✅ Achievement badges saved.")
		else:
			push_error("[Landing] ❌ Failed to save achievement badges: %d" % code)
	)
	save_http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
