extends Control

@export var code_length: int = 12
@export var code_chars: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
@export var scene_on_back: String = "res://scene/mode_selection.tscn"
@export var is_admin: bool = false

const ICON_FUNDAMENTALS       := preload("res://asset/icons/cyfunda.png")
const ICON_NETWORK             := preload("res://asset/icons/NBfun.png")
const ICON_PASSWORD            := preload("res://asset/icons/passwordfticon.png")
const ICON_MALWARE             := preload("res://asset/icons/malwaretpicon.png")
const ICON_ENCRYPTION          := preload("res://asset/icons/encryicon.png")
const ICON_DROP_ZONE           := preload("res://asset/icons/drop_zone_icon.png")
const ICON_PHISHING            := preload("res://asset/icons/phishinglbicon.png")
const ICON_ASSET_THREAT        := preload("res://asset/icons/asset_threat_icon.png")
const ICON_CRYPT_CONTRACT      := preload("res://asset/icons/crypt_contract_icon.png")
const ICON_INCIDENT_COMMANDER  := preload("res://asset/icons/incident_commander_icon.png")
const ICON_SECURITY_GUARDIAN   := preload("res://asset/icons/security_guardian_icon.png")
const ICON_MALWARE_DEFENSE     := preload("res://asset/icons/malware_defense_icon.png")
const ICON_INCIDENT_RESPONSE   := preload("res://asset/icons/incident_response_icon.png")

const ALL_MINIGAMES := [
	{"name": "Cybersecurity Fundamentals", "scene": "res://scene/tutorial_cyber_fundamentals.tscn", "id": "beginner_fundamentals",           "level": "Beginner",     "icon": "FUNDAMENTALS"},
	{"name": "Network Basics",             "scene": "res://scene/tutorial_network_basics.tscn",     "id": "beginner_network",                "level": "Beginner",     "icon": "NETWORK"},
	{"name": "Encryption",                 "scene": "res://scene/tutorial_encryption_basics.tscn",  "id": "advanced_encryption",             "level": "Beginner",     "icon": "ENCRYPTION"},
	{"name": "Password Fortress Defender", "scene": "res://scene/tutorial_password_basics.tscn",    "id": "beginner_password",               "level": "Beginner",     "icon": "PASSWORD"},
	{"name": "Malware Types Overview",     "scene": "res://scene/tutorial_malware_types.tscn",      "id": "beginner_malware",                "level": "Beginner",     "icon": "MALWARE"},
	{"name": "Drop Zone Defender",         "scene": "res://scene/datavsnetwork.tscn",               "id": "beginner_drop_zone",              "level": "Intermediate", "icon": "DROP_ZONE"},
	{"name": "Phishing Detection Lab",     "scene": "res://scene/phishing_intro.tscn",              "id": "intermediate_phishing",           "level": "Intermediate", "icon": "PHISHING"},
	{"name": "Asset vs Threats",           "scene": "res://scene/Assetandthreat.tscn",              "id": "intermediate_assetandthreat",     "level": "Intermediate", "icon": "ASSET_THREAT"},
	{"name": "Crypt Contract",             "scene": "res://scene/PhoneEncryption.tscn",             "id": "intermediate_crypt_contract",     "level": "Intermediate", "icon": "CRYPT_CONTRACT"},
	{"name": "Incident Commander",         "scene": "res://scene/SOCMain.tscn",                     "id": "intermediate_incident_commander", "level": "Intermediate", "icon": "INCIDENT_COMMANDER"},
	{"name": "Security Guardian",          "scene": "res://scene/authgmMain.tscn",                  "id": "advanced_security_guardian",      "level": "Advanced",     "icon": "SECURITY_GUARDIAN"},
	{"name": "Malware Defense & Removal",  "scene": "res://scene/DigitalForensicsScene.tscn",       "id": "advanced_malware_defense",        "level": "Advanced",     "icon": "MALWARE_DEFENSE"},
	{"name": "CMD Defender: Incident Response","scene":"res://scene/incedentmain.tscn",             "id": "advanced_incident_response",      "level": "Advanced",     "icon": "INCIDENT_RESPONSE"},
]

const LEVEL_COLORS := {
	"Beginner":     Color(0.0, 0.85, 0.4,  1.0),
	"Intermediate": Color(1.0, 0.75, 0.0,  1.0),
	"Advanced":     Color(1.0, 0.2,  0.2,  1.0),
}

const PLAYER_MIN: int = 1
const PLAYER_MAX: int = 50

@onready var main_panel: Panel           = $CanvasLayer/MainPanel
@onready var create_form_panel: Panel    = $CanvasLayer/CreateFormPanel
@onready var room_code_panel: Panel      = $CanvasLayer/RoomCodePanel
@onready var statistics_panel: Panel     = $CanvasLayer/StatisticsPanel
@onready var choose_game_popup: Control  = $CanvasLayer/ChooseGamePopup
@onready var lobby_panel: Control        = $CanvasLayer/LobbyPanel
@onready var quiz_creation_panel: Control = $CanvasLayer/QuizCreationPanel
@onready var quiz_preview_panel: Control  = $CanvasLayer/QuizPreviewPanel

@onready var room_list_container: VBoxContainer = $CanvasLayer/MainPanel/RoomListContainer
@onready var empty_label: Label                 = $CanvasLayer/MainPanel/RoomListContainer/EmptyLabel

@onready var room_name_input: LineEdit      = $CanvasLayer/CreateFormPanel/FormContent/RoomNameRow/RoomNameInput
@onready var game_mode_btn: Button          = $CanvasLayer/CreateFormPanel/FormContent/CategoryRow/CategoryButtons/GameModeButton
@onready var multiple_choice_btn: Button    = $CanvasLayer/CreateFormPanel/FormContent/CategoryRow/CategoryButtons/MultipleChoiceButton
@onready var choose_game_row: HBoxContainer = $CanvasLayer/CreateFormPanel/FormContent/ChooseGameRow
@onready var difficulty_row: HBoxContainer  = $CanvasLayer/CreateFormPanel/FormContent/DifficultyRow
@onready var player_count_input: LineEdit   = $CanvasLayer/CreateFormPanel/FormContent/PlayerRow/PlayerInputRow/PlayerCountInput
@onready var player_validation_label: Label = $CanvasLayer/CreateFormPanel/FormContent/PlayerRow/PlayerValidationLabel
@onready var generate_button: Button        = $CanvasLayer/CreateFormPanel/FormContent/GenerateButtonRow/GenerateButton

@onready var mc_section: PanelContainer = $CanvasLayer/CreateFormPanel/FormContent/MCSection

@onready var mc_questions_input: LineEdit   = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsRow/MCQuestionsInput
@onready var mc_questions_validation: Label = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsValidation
@onready var mc_create_btn: Button          = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsRow/MCCreateRow/MCCreateButton

@onready var mc_time_30s: Button   = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime30s
@onready var mc_time_60s: Button   = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime60s
@onready var mc_time_120s: Button  = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime120s
@onready var mc_time_240s: Button  = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime240s

@onready var mc_qtimer_30m: Button   = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuizTimerRow/MCQTimer30m
@onready var mc_qtimer_1h: Button    = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuizTimerRow/MCQTimer1h
@onready var mc_qtimer_1h30m: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuizTimerRow/MCQTimer1h30m
@onready var mc_qtimer_2h: Button    = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuizTimerRow/MCQTimer2h

@onready var mc_view_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/GenerateButtonRow/MCViewButton

@onready var popup_selected_label: Label  = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/SelectedLabel
@onready var popup_confirm_btn: Button    = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/ConfirmRow/ConfirmButton
@onready var minigame_grid: GridContainer = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/ScrollContainer/MinigameGrid

@onready var code_room_name_label: Label  = $CanvasLayer/RoomCodePanel/CodeTopBar/CodeRoomNameLabel
@onready var code_display_label: Label    = $CanvasLayer/RoomCodePanel/CodeContent/CodeRow/CodeDisplayLabel
@onready var copy_button: Button          = $CanvasLayer/RoomCodePanel/CodeContent/CodeRow/CopyButton
@onready var stats_room_name_label: Label = $CanvasLayer/StatisticsPanel/StatsTopBar/StatsRoomNameLabel

var current_room_code: String       = ""
var current_room_name: String       = ""
var selected_difficulty: String     = ""
var selected_minigame: String       = ""
var selected_minigame_scene: String = ""
var _selected_card: PanelContainer  = null
var rooms: Dictionary               = {}
var _selected_difficulty_button: Button = null

var mc_quiz_created: bool            = false
var mc_quiz_data: Dictionary         = {}
var mc_all_questions_completed: bool = false
var mc_selected_time: int            = 0
var mc_selected_qtimer: int          = 0
var _mc_time_buttons: Array[Button]   = []
var _mc_qtimer_buttons: Array[Button] = []

func _ready() -> void:
	_show_screen("main")
	_refresh_room_list()
	_build_minigame_cards()
	popup_confirm_btn.disabled = true

	game_mode_btn.set_pressed_no_signal(false)
	multiple_choice_btn.set_pressed_no_signal(false)
	choose_game_row.visible  = false
	difficulty_row.visible   = true
	mc_section.visible       = false

	player_count_input.text         = "10"
	player_validation_label.visible = false
	player_count_input.text_changed.connect(_on_player_count_changed)
	player_count_input.focus_exited.connect(_on_player_count_focus_exited)

	_mc_time_buttons   = [mc_time_30s, mc_time_60s, mc_time_120s, mc_time_240s]
	_mc_qtimer_buttons = [mc_qtimer_30m, mc_qtimer_1h, mc_qtimer_1h30m, mc_qtimer_2h]

	mc_questions_input.text_changed.connect(_on_mc_questions_changed)

	mc_time_30s.pressed.connect(func():   _on_mc_time_selected(30,   mc_time_30s))
	mc_time_60s.pressed.connect(func():   _on_mc_time_selected(60,   mc_time_60s))
	mc_time_120s.pressed.connect(func():  _on_mc_time_selected(120,  mc_time_120s))
	mc_time_240s.pressed.connect(func():  _on_mc_time_selected(240,  mc_time_240s))

	mc_qtimer_30m.pressed.connect(func():   _on_mc_qtimer_selected(1800, mc_qtimer_30m))
	mc_qtimer_1h.pressed.connect(func():    _on_mc_qtimer_selected(3600, mc_qtimer_1h))
	mc_qtimer_1h30m.pressed.connect(func(): _on_mc_qtimer_selected(5400, mc_qtimer_1h30m))
	mc_qtimer_2h.pressed.connect(func():    _on_mc_qtimer_selected(7200, mc_qtimer_2h))

	mc_view_btn.disabled = true
	mc_view_btn.visible  = false
	mc_create_btn.disabled = true

	_update_generate_button()

	# Quiz creation panel signals
	if quiz_creation_panel:
		quiz_creation_panel.visible = false
		if quiz_creation_panel.has_signal("quiz_creation_completed"):
			quiz_creation_panel.quiz_creation_completed.connect(_on_quiz_creation_completed)
		if quiz_creation_panel.has_signal("quiz_creation_cancelled"):
			quiz_creation_panel.quiz_creation_cancelled.connect(_on_quiz_creation_cancelled)

	# Quiz preview panel signals
	if quiz_preview_panel:
		quiz_preview_panel.visible = false
		if quiz_preview_panel.has_signal("preview_closed"):
			quiz_preview_panel.preview_closed.connect(_on_preview_closed)

	if lobby_panel:
		lobby_panel.visible = false
		if lobby_panel.has_signal("lobby_closed"):
			lobby_panel.lobby_closed.connect(_on_lobby_closed)
		if lobby_panel.has_signal("quiz_started"):
			lobby_panel.quiz_started.connect(_on_quiz_started)

# ── Generate button ──────────────────────────────────────────────────────────

func _update_generate_button() -> void:
	var ok := true
	if room_name_input.text.strip_edges().is_empty(): ok = false
	if not _is_player_count_valid():                  ok = false
	if not game_mode_btn.button_pressed and not multiple_choice_btn.button_pressed:
		ok = false
	if game_mode_btn.button_pressed:
		if selected_minigame.is_empty():   ok = false
		if selected_difficulty.is_empty(): ok = false
	if multiple_choice_btn.button_pressed:
		if not mc_all_questions_completed: ok = false
	generate_button.disabled = not ok

# ── MC Create button ─────────────────────────────────────────────────────────

func _update_mc_create_button() -> void:
	var can_create := true
	if not _mc_questions_valid(): can_create = false
	if mc_selected_time == 0:     can_create = false
	if mc_selected_qtimer == 0:   can_create = false
	mc_create_btn.disabled = not can_create

# ── MC config handlers ───────────────────────────────────────────────────────

func _on_mc_questions_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9": digits += ch
	if digits != new_text:
		mc_questions_input.text         = digits
		mc_questions_input.caret_column = digits.length()
	var valid := _mc_questions_valid()
	if mc_questions_input.text.strip_edges().is_empty():
		mc_questions_validation.text    = "Number of questions cannot be empty."
		mc_questions_validation.visible = true
	elif not valid:
		mc_questions_validation.text    = "Enter a positive number."
		mc_questions_validation.visible = true
	else:
		mc_questions_validation.visible = false
	mc_quiz_created            = false
	mc_all_questions_completed = false
	mc_quiz_data.clear()
	mc_view_btn.disabled = true
	_update_mc_create_button()
	_update_generate_button()

func _mc_questions_valid() -> bool:
	var raw := mc_questions_input.text.strip_edges()
	if raw.is_empty() or not raw.is_valid_int(): return false
	return raw.to_int() > 0

func _on_mc_time_selected(seconds: int, btn: Button) -> void:
	mc_selected_time = seconds
	_highlight_preset(_mc_time_buttons, btn)
	_update_mc_create_button()
	_update_generate_button()

func _on_mc_qtimer_selected(seconds: int, btn: Button) -> void:
	mc_selected_qtimer = seconds
	_highlight_preset(_mc_qtimer_buttons, btn)
	_update_mc_create_button()
	_update_generate_button()

# ── Quiz creation flow ───────────────────────────────────────────────────────

func _on_mc_create_pressed() -> void:
	if not _mc_questions_valid():
		mc_questions_validation.text    = "Please enter a valid question count first."
		mc_questions_validation.visible = true
		return
	if mc_selected_time == 0 or mc_selected_qtimer == 0:
		push_warning("[CreateRoom] Select time and quiz timer before creating.")
		return
	var num_questions: int = mc_questions_input.text.strip_edges().to_int()
	if quiz_creation_panel and quiz_creation_panel.has_method("initialize"):
		quiz_creation_panel.initialize(num_questions, mc_selected_time, mc_selected_qtimer)
		_show_screen("quiz_creation")


func _on_quiz_creation_completed(quiz_data: Dictionary) -> void:
	mc_quiz_data               = quiz_data
	mc_quiz_created            = true
	mc_all_questions_completed = true
	mc_view_btn.disabled       = false
	mc_create_btn.text         = "Edit Quiz"
	_update_generate_button()
	_show_screen("form")

func _on_quiz_creation_cancelled() -> void:
	_show_screen("form")

# ── View / Preview ───────────────────────────────────────────────────────────

func _on_mc_view_pressed() -> void:
	if not mc_quiz_created or mc_quiz_data.is_empty(): return
	if quiz_preview_panel and quiz_preview_panel.has_method("show_preview"):
		quiz_preview_panel.show_preview(mc_quiz_data)
		_show_screen("quiz_preview")

func _on_preview_closed() -> void:
	_show_screen("form")

# ── Category toggles ─────────────────────────────────────────────────────────

func _on_game_mode_toggled(button_pressed: bool) -> void:
	if button_pressed:
		multiple_choice_btn.set_pressed_no_signal(false)
		choose_game_row.visible = true
		mc_section.visible      = false
		difficulty_row.visible  = true
		generate_button.visible = true
		mc_view_btn.visible     = false
		_reset_mc_state()
	else:
		choose_game_row.visible = false
		selected_minigame       = ""
		selected_minigame_scene = ""
	_update_generate_button()

func _on_multiple_choice_toggled(button_pressed: bool) -> void:
	if button_pressed:
		game_mode_btn.set_pressed_no_signal(false)
		choose_game_row.visible = false
		selected_minigame       = ""
		selected_minigame_scene = ""
		mc_section.visible      = true
		difficulty_row.visible  = false
		selected_difficulty     = "MC"
		mc_view_btn.visible     = true
		_update_mc_create_button()
	else:
		mc_section.visible      = false
		difficulty_row.visible  = true
		generate_button.visible = true
		selected_difficulty     = ""
		mc_view_btn.visible     = false
		_reset_mc_state()
	_update_generate_button()

# ── Reset ────────────────────────────────────────────────────────────────────

func _reset_mc_state() -> void:
	mc_quiz_created            = false
	mc_all_questions_completed = false
	mc_quiz_data.clear()
	mc_selected_time           = 0
	mc_selected_qtimer         = 0
	mc_questions_input.text             = ""
	mc_questions_validation.visible     = false
	mc_create_btn.text                  = "Create"
	mc_create_btn.disabled              = true
	mc_view_btn.disabled                = true
	mc_view_btn.visible                 = false
	for b in _mc_time_buttons:
		b.add_theme_stylebox_override("normal", _preset_idle_style())
		b.add_theme_stylebox_override("hover",  _preset_idle_style())
		b.remove_theme_color_override("font_color")
	for b in _mc_qtimer_buttons:
		b.add_theme_stylebox_override("normal", _preset_idle_style())
		b.add_theme_stylebox_override("hover",  _preset_idle_style())
		b.remove_theme_color_override("font_color")

func _reset_form() -> void:
	game_mode_btn.set_pressed_no_signal(false)
	multiple_choice_btn.set_pressed_no_signal(false)
	choose_game_row.visible     = false
	mc_section.visible          = false
	difficulty_row.visible      = true
	generate_button.visible     = true
	selected_minigame           = ""
	selected_minigame_scene     = ""
	selected_difficulty         = ""
	_selected_difficulty_button = null
	player_count_input.text         = "10"
	player_validation_label.visible = false
	_reset_mc_state()
	_update_generate_button()

# ── Screen management ────────────────────────────────────────────────────────

func _show_screen(which: String) -> void:
	main_panel.visible        = (which == "main")
	create_form_panel.visible = (which == "form")
	room_code_panel.visible   = (which == "code")
	statistics_panel.visible  = (which == "stats")
	if quiz_creation_panel:
		quiz_creation_panel.visible = (which == "quiz_creation")
	if quiz_preview_panel:
		quiz_preview_panel.visible = (which == "quiz_preview")
	if lobby_panel:
		lobby_panel.visible = (which == "lobby")

	var target: Control
	match which:
		"main":         target = main_panel
		"form":         target = create_form_panel
		"code":         target = room_code_panel
		"stats":        target = statistics_panel
		"quiz_creation":target = quiz_creation_panel
		"quiz_preview": target = quiz_preview_panel
		"lobby":        target = lobby_panel

	if target:
		target.modulate.a = 0.0
		target.scale      = Vector2(0.92, 0.92)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(target, "modulate:a", 1.0, 0.25)
		tw.tween_property(target, "scale", Vector2(1.0, 1.0), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Generate room ────────────────────────────────────────────────────────────

func _on_generate_pressed() -> void:
	var room_name := room_name_input.text.strip_edges()
	if room_name.is_empty():
		_flash_error(room_name_input); return
	if not _is_player_count_valid():
		_flash_error(player_count_input)
		player_validation_label.visible = true
		player_validation_label.text    = "Enter a valid player count (1-50)."
		return
	if not game_mode_btn.button_pressed and not multiple_choice_btn.button_pressed:
		return
	if game_mode_btn.button_pressed:
		if selected_minigame.is_empty() or selected_difficulty.is_empty(): return
	if multiple_choice_btn.button_pressed:
		if not mc_all_questions_completed: return
	current_room_name = room_name
	_finalise_room()

func _finalise_room() -> void:
	current_room_code = _generate_code()
	var cats: Array[String] = []
	if game_mode_btn.button_pressed:       cats.append("Game Mode")
	if multiple_choice_btn.button_pressed: cats.append("Multiple Choice")
	var room_data: Dictionary = {
		"name": current_room_name, "difficulty": selected_difficulty,
		"categories": ", ".join(cats), "minigame": selected_minigame,
		"minigame_scene": selected_minigame_scene, "player_count": _get_player_count(),
	}
	if multiple_choice_btn.button_pressed and not mc_quiz_data.is_empty():
		room_data["mc_quiz_data"]  = mc_quiz_data.duplicate(true)
		room_data["mc_time_per_q"] = mc_selected_time
		room_data["mc_quiz_timer"] = mc_selected_qtimer
	rooms[current_room_code]      = room_data
	code_room_name_label.text     = current_room_name
	code_display_label.text       = current_room_code
	_show_screen("code")
	_refresh_room_list()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _generate_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := ""
	for i in range(code_length):
		result += code_chars[rng.randi() % code_chars.length()]
	return result

func _flash_error(node: Control) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 0.3, 0.3), 0.1)
	tw.tween_property(node, "modulate", Color(1, 1, 1, 1),  0.3)

func _highlight_preset(group: Array[Button], active: Button) -> void:
	for b in group:
		if b == active:
			b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1, 1))
			b.add_theme_stylebox_override("normal", _preset_active_style())
			b.add_theme_stylebox_override("hover",  _preset_active_style())
		else:
			b.remove_theme_color_override("font_color")
			b.add_theme_stylebox_override("normal", _preset_idle_style())
			b.add_theme_stylebox_override("hover",  _preset_idle_style())

func _preset_active_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.145098, 0.878431, 0.992157, 1.0)
	s.border_color = Color(0.145098, 0.878431, 0.992157, 1.0)
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	return s

func _preset_idle_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.10, 0.22, 0.85)
	s.border_color = Color(0.145098, 0.878431, 0.992157, 0.5)
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	return s

func _on_player_count_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9": digits += ch
	if digits != new_text:
		player_count_input.text         = digits
		player_count_input.caret_column = digits.length()
	if digits.is_empty():
		player_validation_label.visible = true
		player_validation_label.text    = "Player count cannot be empty."
	else:
		var val := digits.to_int()
		if val < PLAYER_MIN or val > PLAYER_MAX:
			player_validation_label.visible = true
			player_validation_label.text    = "Enter a value between %d and %d." % [PLAYER_MIN, PLAYER_MAX]
		else:
			player_validation_label.visible = false
	_update_generate_button()

func _on_player_count_focus_exited() -> void:
	var raw := player_count_input.text.strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		player_count_input.text = str(PLAYER_MIN)
		player_validation_label.visible = false
		_update_generate_button()
		return
	var val := raw.to_int()
	if val < PLAYER_MIN: player_count_input.text = str(PLAYER_MIN)
	elif val > PLAYER_MAX: player_count_input.text = str(PLAYER_MAX)
	player_validation_label.visible = false
	_update_generate_button()

func _get_player_count() -> int:
	var raw := player_count_input.text.strip_edges()
	if raw.is_empty() or not raw.is_valid_int(): return PLAYER_MIN
	return clampi(raw.to_int(), PLAYER_MIN, PLAYER_MAX)

func _is_player_count_valid() -> bool:
	var raw := player_count_input.text.strip_edges()
	if raw.is_empty() or not raw.is_valid_int(): return false
	var val := raw.to_int()
	return val >= PLAYER_MIN and val <= PLAYER_MAX

func _on_choose_game_btn_pressed() -> void: _open_popup()

func _open_popup() -> void:
	selected_minigame = ""; selected_minigame_scene = ""
	_clear_card_highlight(); _selected_card = null
	popup_selected_label.text  = "No game selected yet — click a card below."
	popup_confirm_btn.disabled = true
	choose_game_popup.visible    = true
	choose_game_popup.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(choose_game_popup, "modulate:a", 1.0, 0.20)

func _close_popup() -> void:
	var tw := create_tween()
	tw.tween_property(choose_game_popup, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): choose_game_popup.visible = false)

func _on_difficulty_pressed(diff: String) -> void:
	selected_difficulty = diff
	_update_generate_button()

func _on_popup_close_pressed() -> void:   _close_popup()
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _on_popup_confirm_pressed() -> void:
	if selected_minigame.is_empty(): return
	_close_popup(); _update_generate_button()
	await get_tree().create_timer(0.18).timeout

func _build_minigame_cards() -> void:
	for c in minigame_grid.get_children(): c.queue_free()
	for game in ALL_MINIGAMES: minigame_grid.add_child(_make_card(game))

func _make_card(game: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size        = Vector2(238, 82)
	card.size_flags_horizontal      = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.name = "Card_" + game["id"]
	card.add_theme_stylebox_override("panel", _card_style(false))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	var icon_tex := TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(48, 48)
	icon_tex.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_tex.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.texture             = _get_icon(game["icon"])
	hbox.add_child(icon_tex)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.text = game["name"]
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)
	var level_lbl := Label.new()
	level_lbl.text = game["level"]
	level_lbl.add_theme_color_override("font_color", LEVEL_COLORS.get(game["level"], Color.WHITE))
	level_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(level_lbl)
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_card(card, game))
	return card

func _select_card(card: PanelContainer, game: Dictionary) -> void:
	_clear_card_highlight()
	card.add_theme_stylebox_override("panel", _card_style(true))
	_selected_card          = card
	selected_minigame       = game["name"]
	selected_minigame_scene = game["scene"]
	popup_selected_label.text  = "Selected: %s  [%s]" % [game["name"], game["level"]]
	popup_confirm_btn.disabled = false

func _clear_card_highlight() -> void:
	if _selected_card:
		_selected_card.add_theme_stylebox_override("panel", _card_style(false))

func _card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	if selected:
		s.bg_color = Color(0.0, 0.25, 0.30, 0.95)
		s.border_color = Color(0.0, 1.0, 1.0, 1.0)
		s.shadow_color = Color(0.0, 1.0, 1.0, 0.55)
		s.shadow_size  = 8
	else:
		s.bg_color = Color(0.05, 0.06, 0.15, 0.92)
		s.border_color = Color(0.0, 0.85, 1.0, 0.45)
	return s

func _get_icon(key: String) -> Texture2D:
	match key:
		"FUNDAMENTALS":       return ICON_FUNDAMENTALS
		"NETWORK":            return ICON_NETWORK
		"PASSWORD":           return ICON_PASSWORD
		"MALWARE":            return ICON_MALWARE
		"ENCRYPTION":         return ICON_ENCRYPTION
		"DROP_ZONE":          return ICON_DROP_ZONE
		"PHISHING":           return ICON_PHISHING
		"ASSET_THREAT":       return ICON_ASSET_THREAT
		"CRYPT_CONTRACT":     return ICON_CRYPT_CONTRACT
		"INCIDENT_COMMANDER": return ICON_INCIDENT_COMMANDER
		"SECURITY_GUARDIAN":  return ICON_SECURITY_GUARDIAN
		"MALWARE_DEFENSE":    return ICON_MALWARE_DEFENSE
		"INCIDENT_RESPONSE":  return ICON_INCIDENT_RESPONSE
		_:                    return ICON_FUNDAMENTALS

func _on_copy_code_pressed() -> void:
	if current_room_code.is_empty(): return
	DisplayServer.clipboard_set(current_room_code)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	copy_button.text = "Copy"

func _refresh_room_list() -> void:
	for child in room_list_container.get_children():
		if child != empty_label: child.queue_free()
	empty_label.visible = rooms.is_empty()
	for code in rooms:
		var data: Dictionary = rooms[code]
		room_list_container.add_child(_create_room_item(
			data["name"], code, data["difficulty"],
			data.get("minigame", ""), data.get("player_count", 0)))

func _create_room_item(rname: String, code: String, diff: String, game: String, player_count: int) -> PanelContainer:
	var item := PanelContainer.new()
	item.custom_minimum_size   = Vector2(0, 52)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	item.add_child(hbox)
	for pair in [[rname, 130, Color(1,1,1,1)],[code, 0, Color(0.7,0.9,1,1)],[diff, 70, Color(0.8,0.8,0.8,1)]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		if pair[1] > 0: lbl.custom_minimum_size = Vector2(pair[1], 0)
		else: lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", pair[2])
		hbox.add_child(lbl)
	if player_count > 0:
		var plbl := Label.new()
		plbl.text = "👥 %d" % player_count
		plbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1, 1))
		plbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(plbl)
	if game != "":
		var glbl := Label.new()
		glbl.text = game
		glbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		glbl.add_theme_color_override("font_color", Color(0.5, 1, 0.8, 1))
		glbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(glbl)
	var view_btn := Button.new()
	view_btn.text = "View"
	view_btn.custom_minimum_size        = Vector2(70, 32)
	view_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cap := code
	view_btn.pressed.connect(func(): _view_room(cap))
	hbox.add_child(view_btn)
	return item

func _view_room(code: String) -> void:
	if not rooms.has(code): return
	current_room_code         = code
	current_room_name         = rooms[code]["name"]
	code_room_name_label.text = current_room_name
	code_display_label.text   = current_room_code
	_show_screen("code")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(scene_on_back)

func _on_create_button_pressed() -> void:
	room_name_input.text = "Quiz-%d" % (rooms.size() + 1)
	_reset_form()
	_show_screen("form")

func _on_form_back_pressed() -> void:
	_reset_form(); _show_screen("main")

func _on_code_back_pressed() -> void:
	_show_screen("form")

func _on_lobby_button_pressed() -> void:
	if not rooms.has(current_room_code): return
	var room_data: Dictionary = rooms[current_room_code]
	var minigame_label: String = room_data.get("minigame", "")
	if minigame_label.is_empty():
		minigame_label = "Multiple Choice"
	if lobby_panel and lobby_panel.has_method("show_lobby"):
		lobby_panel.show_lobby(current_room_code, current_room_name,
			minigame_label, room_data.get("difficulty", ""),
			int(room_data.get("player_count", 10)))
	_show_screen("lobby")

func _on_lobby_closed() -> void:   _show_screen("code")

func _on_quiz_started(room_code: String) -> void:
	if not rooms.has(room_code): return
	var room_data: Dictionary = rooms[room_code]

	# Multiple Choice → go to StatisticsPanel
	if room_data.get("minigame", "") == "":
		stats_room_name_label.text = room_data.get("name", "")
		_show_screen("stats")
		return

	# Game Mode → launch the actual minigame scene
	var scene_path: String = room_data.get("minigame_scene", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)

func _on_stats_back_pressed() -> void: _show_screen("code")
func _on_see_all_pressed() -> void:    print("See all rankings:", current_room_name)