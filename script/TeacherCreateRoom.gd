extends Control

@export var code_length: int = 12
@export var code_chars: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
@export var scene_on_back: String = "res://scene/mode_selection.tscn"
@export var is_admin: bool = false

const ICON_FUNDAMENTALS := preload("res://asset/icons/cyfunda.png")
const ICON_NETWORK := preload("res://asset/icons/NBfun.png")
const ICON_PASSWORD := preload("res://asset/icons/passwordfticon.png")
const ICON_MALWARE := preload("res://asset/icons/malwaretpicon.png")
const ICON_ENCRYPTION := preload("res://asset/icons/encryicon.png")
const ICON_DROP_ZONE := preload("res://asset/icons/drop_zone_icon.png")
const ICON_PHISHING := preload("res://asset/icons/phishinglbicon.png")
const ICON_ASSET_THREAT := preload("res://asset/icons/asset_threat_icon.png")
const ICON_CRYPT_CONTRACT := preload("res://asset/icons/crypt_contract_icon.png")
const ICON_INCIDENT_COMMANDER := preload("res://asset/icons/incident_commander_icon.png")
const ICON_SECURITY_GUARDIAN := preload("res://asset/icons/security_guardian_icon.png")
const ICON_CRYPTO_SORTER := preload("res://asset/icons/encryicon.png")
const ICON_RSA_KEY_LAB := preload("res://asset/icons/crypt_contract_icon.png")

const ALL_MINIGAMES := [
	# ── Lesson 1: Information Assurance & Networking ──
	{"name": "Cybersecurity Fundamentals", "scene": "res://scene/tutorial_cyber_fundamentals.tscn", "id": "beginner_fundamentals", "level": "Beginner", "icon": "FUNDAMENTALS", "lesson": "Lesson 1"},
	{"name": "Network Basics", "scene": "res://scene/tutorial_network_basics.tscn", "id": "beginner_network", "level": "Beginner", "icon": "NETWORK", "lesson": "Lesson 1"},
	{"name": "Drop Zone Defender", "scene": "res://scene/datavsnetwork.tscn", "id": "beginner_drop_zone", "level": "Beginner", "icon": "DROP_ZONE", "lesson": "Lesson 1"},
	# ── Lesson 2: Threats & Assets ──
	{"name": "Threat Identification Lab", "scene": "res://scene/tutorial_malware_types.tscn", "id": "beginner_malware", "level": "Beginner", "icon": "MALWARE", "lesson": "Lesson 2"},
	{"name": "Asset vs Threats", "scene": "res://scene/Assetandthreat.tscn", "id": "intermediate_assetandthreat", "level": "Beginner", "icon": "ASSET_THREAT", "lesson": "Lesson 2"},
	# ── Lesson 3: Symmetric Encryption ──
	{"name": "Encryption (Caesar Cipher)", "scene": "res://scene/tutorial_encryption_basics.tscn", "id": "advanced_encryption", "level": "Intermediate", "icon": "ENCRYPTION", "lesson": "Lesson 3"},
	{"name": "Crypt Contract", "scene": "res://scene/PhoneEncryption.tscn", "id": "intermediate_crypt_contract", "level": "Intermediate", "icon": "CRYPT_CONTRACT", "lesson": "Lesson 3"},
	# ── Lesson 4: DES, Triple DES & AES ──
	{"name": "Encryption Audit Lab", "scene": "res://scene/phishing_intro.tscn", "id": "intermediate_phishing", "level": "Intermediate", "icon": "PHISHING", "lesson": "Lesson 4"},
	{"name": "Cipher Defense Terminal", "scene": "res://scene/SOCMain.tscn", "id": "intermediate_incident_commander", "level": "Intermediate", "icon": "INCIDENT_COMMANDER", "lesson": "Lesson 4"},
	# ── Lesson 5: Public-Key Cryptography ──
	{"name": "Crypto Sorter", "scene": "res://scene/crypto_sorter.tscn", "id": "advanced_crypto_sorter", "level": "Advanced", "icon": "CRYPTO_SORTER", "lesson": "Lesson 5"},
	# ── Lesson 6: RSA, Diffie-Hellman & Practice ──
	{"name": "RSA Key Lab", "scene": "res://scene/rsa_key_lab.tscn", "id": "advanced_rsa_key_lab", "level": "Advanced", "icon": "RSA_KEY_LAB", "lesson": "Lesson 6"},
	# ── Lesson 7: Authentication ──
	{"name": "Password Fortress Defender", "scene": "res://scene/tutorial_password_basics.tscn", "id": "beginner_password", "level": "Advanced", "icon": "PASSWORD", "lesson": "Lesson 7"},
	{"name": "Security Guardian", "scene": "res://scene/authgmMain.tscn", "id": "advanced_security_guardian", "level": "Advanced", "icon": "SECURITY_GUARDIAN", "lesson": "Lesson 7"},
]

const LESSON_HEADERS := {
	"Lesson 1": "Lesson 1 — Information Assurance & Networking",
	"Lesson 2": "Lesson 2 — Threats & Assets",
	"Lesson 3": "Lesson 3 — Symmetric Encryption",
	"Lesson 4": "Lesson 4 — DES, Triple DES & AES",
	"Lesson 5": "Lesson 5 — Public-Key Cryptography",
	"Lesson 6": "Lesson 6 — RSA, Diffie-Hellman & Practice",
	"Lesson 7": "Lesson 7 — Authentication",
}

const LEVEL_COLORS := {
	"Beginner": Color(0.0, 0.85, 0.4, 1.0),
	"Intermediate": Color(1.0, 0.75, 0.0, 1.0),
	"Advanced": Color(1.0, 0.2, 0.2, 1.0),
}

const PLAYER_MIN: int = 1
const PLAYER_MAX: int = 999

@onready var main_panel: Panel = $CanvasLayer/MainPanel
@onready var create_form_panel: Panel = $CanvasLayer/CreateFormPanel
@onready var room_code_panel: Panel = $CanvasLayer/RoomCodePanel
@onready var statistics_panel: Panel = $CanvasLayer/StatisticsPanel
@onready var choose_game_popup: Control = $CanvasLayer/ChooseGamePopup
@onready var lobby_panel: Control = $CanvasLayer/LobbyPanel
@onready var quiz_creation_panel: Control = $CanvasLayer/QuizCreationPanel
@onready var quiz_preview_panel: Control = $CanvasLayer/QuizPreviewPanel

@onready var room_list_container: VBoxContainer = $CanvasLayer/MainPanel/RoomListContainer
@onready var empty_label: Label = $CanvasLayer/MainPanel/RoomListContainer/EmptyLabel

@onready var room_name_input: LineEdit = $CanvasLayer/CreateFormPanel/FormContent/RoomNameRow/RoomNameInput
@onready var game_mode_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/CategoryRow/CategoryButtons/GameModeButton
@onready var multiple_choice_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/CategoryRow/CategoryButtons/MultipleChoiceButton
@onready var choose_game_row: HBoxContainer = $CanvasLayer/CreateFormPanel/FormContent/ChooseGameRow
@onready var player_count_input: LineEdit = $CanvasLayer/CreateFormPanel/FormContent/PlayerRow/PlayerInputRow/PlayerCountInput
@onready var player_validation_label: Label = $CanvasLayer/CreateFormPanel/FormContent/PlayerRow/PlayerValidationLabel
@onready var choose_game_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/ChooseGameRow/ChooseGameButton
@onready var choose_game_hint: Label = $CanvasLayer/CreateFormPanel/FormContent/ChooseGameRow/ChooseGameHint
@onready var generate_button_row: HBoxContainer = $CanvasLayer/CreateFormPanel/FormContent/GenerateButtonRow
@onready var generate_button: Button = $CanvasLayer/CreateFormPanel/FormContent/GenerateButtonRow/GenerateButton
var save_draft_button: Button = null

@onready var mc_section: PanelContainer = $CanvasLayer/CreateFormPanel/FormContent/MCSection

@onready var mc_questions_input: LineEdit = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsRow/MCQuestionsInput
@onready var mc_questions_validation: Label = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsValidation
@onready var mc_create_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCQuestionsRow/MCCreateRow/MCCreateButton

@onready var mc_time_30s: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime30s
@onready var mc_time_60s: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime60s
@onready var mc_time_120s: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime120s
@onready var mc_time_240s: Button = $CanvasLayer/CreateFormPanel/FormContent/MCSection/MCSectionInner/MCTimeRow/MCTime240s


@onready var mc_view_btn: Button = $CanvasLayer/CreateFormPanel/FormContent/GenerateButtonRow/MCViewButton

@onready var popup_selected_label: Label = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/SelectedLabel
@onready var popup_confirm_btn: Button = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/ConfirmRow/ConfirmButton
@onready var minigame_grid: VBoxContainer = $CanvasLayer/ChooseGamePopup/PopupPanel/PopupVBox/ScrollContainer/MinigameGrid

@onready var code_room_name_label: Label = $CanvasLayer/RoomCodePanel/CodeTopBar/CodeRoomNameLabel
@onready var code_display_label: Label = $CanvasLayer/RoomCodePanel/CodeContent/CodeRow/CodeDisplayLabel
@onready var copy_button: Button = $CanvasLayer/RoomCodePanel/CodeContent/CodeRow/CopyButton
@onready var stats_room_name_label: Label = $CanvasLayer/StatisticsPanel/StatsTopBar/StatsRoomNameLabel

var current_room_code: String = ""
var current_room_name: String = ""
var selected_difficulty: String = ""
var selected_minigame: String = ""
var selected_minigame_scene: String = ""
var _selected_card: PanelContainer = null
var rooms: Dictionary = {}
var _selected_difficulty_button: Button = null

var mc_quiz_created: bool = false
var mc_quiz_data: Dictionary = {}
var mc_all_questions_completed: bool = false
var mc_selected_time: int = 0
var _mc_time_buttons: Array[Button] = []
var _quiz_heartbeat_timer: Timer = null
var _quiz_poll_timer: Timer = null
var _quiz_start_posted: bool = false
var _cached_leaderboard: Array = []  # Cached for See All popup
var _cached_results_by_room: Dictionary = {}  # { room_code: { leaderboard, question_stats, ... } }

# ── Student Number Whitelist ─────────────────────────────────────────────────
var _restrict_checkbox: CheckBox = null
var _student_numbers_section: VBoxContainer = null
var _student_numbers_edit: TextEdit = null
var _student_numbers_hint: Label = null
var _section_dropdown: OptionButton = null
var _section_mode_tabs: HBoxContainer = null
var _manual_tab: Button = null
var _section_tab: Button = null
var _selected_section_id: String = ""

# ── Room History (Firestore) ─────────────────────────────────────────────────
const FIRESTORE_BASE_URL: String = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents"

var room_history: Array[Dictionary] = []  # Loaded from Firestore
var _history_http: HTTPRequest = null
var _viewing_room_code: String = ""  # Currently viewing room's code
var _editing_draft_code: String = "" # Currently editing draft's code

func _reset_form() -> void:
	_editing_draft_code = ""
	room_name_input.text = ""
	_quiz_start_posted = false
	game_mode_btn.set_pressed_no_signal(false)
	multiple_choice_btn.set_pressed_no_signal(false)
	if choose_game_row:
		choose_game_row.visible = false
	if choose_game_hint:
		choose_game_hint.text = "Pick minigame for the room"
	if mc_section:
		mc_section.visible = false
	if generate_button:
		generate_button.visible = true
	if save_draft_button:
		save_draft_button.visible = true
	_reset_mc_state()
	selected_minigame = ""
	selected_minigame_scene = ""
	selected_difficulty = ""
	_selected_difficulty_button = null
	if player_count_input:
		player_count_input.text = "10"
	if player_validation_label:
		player_validation_label.visible = false
	if _restrict_checkbox:
		_restrict_checkbox.set_pressed_no_signal(false)
		if _student_numbers_section:
			_student_numbers_section.visible = false
	_update_generate_button()

func _ready() -> void:
	_show_screen("main")
	_wrap_room_list_in_scroll()  # Add scrollable room history
	_load_room_history()  # Load room history from Firestore
	_refresh_room_list()
	_build_minigame_cards()
	popup_confirm_btn.disabled = true

	# ── Build Save Draft Button ──
	_build_save_draft_button()

	# ── Build Refresh Button ──
	_build_refresh_button()

	game_mode_btn.set_pressed_no_signal(false)
	multiple_choice_btn.set_pressed_no_signal(false)
	if choose_game_hint:
		choose_game_hint.text = "Pick minigame for the room"
	if choose_game_row:
		choose_game_row.visible = false
	if mc_section:
		mc_section.visible = false

	player_count_input.text = "10"
	player_validation_label.visible = false
	player_count_input.text_changed.connect(_on_player_count_changed)
	player_count_input.focus_exited.connect(_on_player_count_focus_exited)
	
	# Fix for generate/save buttons not lighting up when typing the room name
	room_name_input.text_changed.connect(func(_new_text): _update_generate_button())

	# ── Build Student Number Whitelist UI (between ChooseGameRow and MCSection) ──
	_build_student_restriction_ui()

	_mc_time_buttons = [mc_time_30s, mc_time_60s, mc_time_120s, mc_time_240s]

	mc_questions_input.text_changed.connect(_on_mc_questions_changed)

	mc_time_30s.pressed.connect(func(): _on_mc_time_selected(30, mc_time_30s))
	mc_time_60s.pressed.connect(func(): _on_mc_time_selected(60, mc_time_60s))
	mc_time_120s.pressed.connect(func(): _on_mc_time_selected(120, mc_time_120s))
	mc_time_240s.pressed.connect(func(): _on_mc_time_selected(240, mc_time_240s))


	mc_view_btn.disabled = true
	mc_view_btn.visible = false
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

	# ── Check if we came from Section Manager with a section prefill ──
	if get_tree().has_meta("section_manager_return"):
		scene_on_back = get_tree().get_meta("section_manager_return")
		get_tree().remove_meta("section_manager_return")
	_check_section_prefill()

# ── Generate button ──────────────────────────────────────────────────────────

func _update_generate_button() -> void:
	var ok := true
	if room_name_input.text.strip_edges().is_empty(): ok = false
	if not _is_player_count_valid(): ok = false
	if not game_mode_btn.button_pressed and not multiple_choice_btn.button_pressed:
		ok = false
	if game_mode_btn.button_pressed:
		if selected_minigame.is_empty(): ok = false
		if selected_difficulty.is_empty(): ok = false
	if multiple_choice_btn.button_pressed:
		if not mc_all_questions_completed: ok = false
	print("[CreateRoom] Generate btn: ok=%s | name='%s' | player_ok=%s | gm=%s | mc=%s | game='%s' | diff='%s' | mc_done=%s" % [
		str(ok), room_name_input.text.strip_edges(), str(_is_player_count_valid()),
		str(game_mode_btn.button_pressed), str(multiple_choice_btn.button_pressed),
		selected_minigame, selected_difficulty, str(mc_all_questions_completed)])
	generate_button.disabled = not ok
	if save_draft_button:
		save_draft_button.disabled = not ok

# ── Section Prefill (from Section Manager) ───────────────────────────────────

func _check_section_prefill() -> void:
	if not get_tree().has_meta("prefill_section_id"):
		return
	
	var section_id: String = get_tree().get_meta("prefill_section_id")
	var section_name: String = get_tree().get_meta("prefill_section_name")
	var student_count: int = get_tree().get_meta("prefill_student_count")
	
	# Clean up meta
	get_tree().remove_meta("prefill_section_id")
	get_tree().remove_meta("prefill_section_name")
	get_tree().remove_meta("prefill_student_count")
	
	# Auto-fill the room name and player count
	room_name_input.text = "%s — Game Room" % section_name
	player_count_input.text = str(student_count)
	
	# Auto-enable Game Mode toggle
	game_mode_btn.set_pressed_no_signal(true)
	_on_game_mode_toggled(true)
	
	# Auto-enable student restriction with section pre-selected
	if _restrict_checkbox:
		_restrict_checkbox.set_pressed_no_signal(true)
		_on_restrict_checkbox_toggled(true)
	
	# Select the correct section in the dropdown
	_selected_section_id = section_id
	if _section_dropdown:
		for i in _section_dropdown.item_count:
			if _section_dropdown.get_item_metadata(i) == section_id:
				_section_dropdown.select(i)
				break
	
	_update_generate_button()
	
	# Jump directly to the form (skip the room history list)
	_show_screen("form")
	print("[CreateRoom] Section prefill: '%s' (%d students)" % [section_name, student_count])

# ── MC Create button ─────────────────────────────────────────────────────────

func _update_mc_create_button() -> void:
	var can_create := true
	if not _mc_questions_valid(): can_create = false
	if mc_selected_time == 0: can_create = false
	mc_create_btn.disabled = not can_create

# ── MC config handlers ───────────────────────────────────────────────────────

func _on_mc_questions_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9": digits += ch
	if digits != new_text:
		mc_questions_input.text = digits
		mc_questions_input.caret_column = digits.length()
	var valid := _mc_questions_valid()
	if mc_questions_input.text.strip_edges().is_empty():
		mc_questions_validation.text = "Number of questions cannot be empty."
		mc_questions_validation.visible = true
	elif not valid:
		mc_questions_validation.text = "Enter a positive number."
		mc_questions_validation.visible = true
	else:
		mc_questions_validation.visible = false
	mc_quiz_created = false
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


# ── Quiz creation flow ───────────────────────────────────────────────────────

func _on_mc_create_pressed() -> void:
	if not _mc_questions_valid():
		mc_questions_validation.text = "Please enter a valid question count first."
		mc_questions_validation.visible = true
		return
	if mc_selected_time == 0:
		push_warning("[CreateRoom] Select time before creating.")
		return
	var num_questions: int = mc_questions_input.text.strip_edges().to_int()
	if quiz_creation_panel and quiz_creation_panel.has_method("initialize"):
		quiz_creation_panel.initialize(num_questions, mc_selected_time)
		# Load drafted questions if we are editing an existing draft
		if not mc_quiz_data.is_empty() and mc_quiz_data.has("questions"):
			if quiz_creation_panel.has_method("load_existing_data"):
				quiz_creation_panel.load_existing_data(mc_quiz_data["questions"])
		_show_screen("quiz_creation")


func _on_quiz_creation_completed(quiz_data: Dictionary) -> void:
	mc_quiz_data = quiz_data
	mc_quiz_created = true
	mc_all_questions_completed = true
	mc_view_btn.disabled = false
	mc_create_btn.text = "Edit Quiz"
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
		if choose_game_row:
			choose_game_row.visible = true
		if mc_section:
			mc_section.visible = false
		if generate_button:
			generate_button.visible = true
		if save_draft_button:
			save_draft_button.visible = true
		if mc_view_btn:
			mc_view_btn.visible = false
		_reset_mc_state()
		# Show student restriction option for game mode
		if _restrict_checkbox:
			_restrict_checkbox.get_parent().visible = true
	else:
		if choose_game_row:
			choose_game_row.visible = false
		selected_minigame = ""
		selected_minigame_scene = ""
		# Hide student restriction when game mode deselected
		if _restrict_checkbox:
			_restrict_checkbox.get_parent().visible = false
			_restrict_checkbox.set_pressed_no_signal(false)
			if _student_numbers_section:
				_student_numbers_section.visible = false
	_update_generate_button()

func _on_multiple_choice_toggled(button_pressed: bool) -> void:
	if button_pressed:
		game_mode_btn.set_pressed_no_signal(false)
		if choose_game_hint:
			choose_game_hint.text = "Pick minigame for the room"
		if choose_game_row:
			choose_game_row.visible = false
		selected_minigame = ""
		selected_minigame_scene = ""
		if mc_section:
			mc_section.visible = true
		selected_difficulty = "MC"
		if mc_view_btn:
			mc_view_btn.visible = true
		_update_mc_create_button()
		# Show student restriction option for multiple choice
		if _restrict_checkbox:
			_restrict_checkbox.get_parent().visible = true
	else:
		if mc_section:
			mc_section.visible = false
		if generate_button:
			generate_button.visible = true
		if save_draft_button:
			save_draft_button.visible = true
		selected_difficulty = ""
		if mc_view_btn:
			mc_view_btn.visible = false
		_reset_mc_state()
		# Hide student restriction when multiple choice deselected
		if _restrict_checkbox:
			_restrict_checkbox.get_parent().visible = false
			_restrict_checkbox.set_pressed_no_signal(false)
			if _student_numbers_section:
				_student_numbers_section.visible = false
	_update_generate_button()

# ── Student Number Whitelist UI ──────────────────────────────────────────────

func _build_student_restriction_ui() -> void:
	var form_content = create_form_panel.get_node_or_null("FormContent")
	if not form_content:
		push_error("[Whitelist] FormContent not found")
		return

	# Find ChooseGameRow index to insert after it
	var insert_idx := -1
	for i in form_content.get_child_count():
		if form_content.get_child(i).name == "ChooseGameRow":
			insert_idx = i + 1
			break
	if insert_idx < 0:
		insert_idx = form_content.get_child_count() - 1  # fallback: before last

	# ── Checkbox Row ──
	var checkbox_row := HBoxContainer.new()
	checkbox_row.name = "StudentRestrictRow"
	checkbox_row.visible = false  # Hidden until Game Mode is selected
	checkbox_row.add_theme_constant_override("separation", 10)

	_restrict_checkbox = CheckBox.new()
	_restrict_checkbox.text = "Restrict by Student Number"
	_restrict_checkbox.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0, 0.9))
	_restrict_checkbox.add_theme_font_size_override("font_size", 13)
	_restrict_checkbox.toggled.connect(_on_restrict_checkbox_toggled)
	checkbox_row.add_child(_restrict_checkbox)

	form_content.add_child(checkbox_row)
	form_content.move_child(checkbox_row, insert_idx)

	# ── Student Numbers Section (hidden until checkbox checked) ──
	_student_numbers_section = VBoxContainer.new()
	_student_numbers_section.name = "StudentNumbersSection"
	_student_numbers_section.visible = false
	_student_numbers_section.add_theme_constant_override("separation", 8)

	# ── Mode Tabs (Select Section / Enter Manually) ──
	_section_mode_tabs = HBoxContainer.new()
	_section_mode_tabs.add_theme_constant_override("separation", 0)
	
	_section_tab = Button.new()
	_section_tab.text = "📁 Select Section"
	_section_tab.toggle_mode = true
	_section_tab.button_pressed = true
	_section_tab.add_theme_font_size_override("font_size", 12)
	_section_tab.custom_minimum_size = Vector2(140, 32)
	_section_tab.pressed.connect(_on_section_tab_pressed)
	_section_mode_tabs.add_child(_section_tab)
	
	_manual_tab = Button.new()
	_manual_tab.text = "✏️ Enter Manually"
	_manual_tab.toggle_mode = true
	_manual_tab.button_pressed = false
	_manual_tab.add_theme_font_size_override("font_size", 12)
	_manual_tab.custom_minimum_size = Vector2(140, 32)
	_manual_tab.pressed.connect(_on_manual_tab_pressed)
	_section_mode_tabs.add_child(_manual_tab)
	
	# Manage Sections link
	var manage_link := Button.new()
	manage_link.text = "⚙ Manage Sections"
	manage_link.flat = true
	manage_link.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	manage_link.add_theme_font_size_override("font_size", 11)
	manage_link.pressed.connect(_on_manage_sections_pressed)
	_section_mode_tabs.add_child(manage_link)
	
	# Manage Bindings link (Anti-Cheat admin)
	var bindings_link := Button.new()
	bindings_link.text = "🔐 Manage Bindings"
	bindings_link.flat = true
	bindings_link.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	bindings_link.add_theme_font_size_override("font_size", 11)
	bindings_link.pressed.connect(_on_manage_bindings_pressed)
	_section_mode_tabs.add_child(bindings_link)
	
	_student_numbers_section.add_child(_section_mode_tabs)

	# ── Section Dropdown ──
	_section_dropdown = OptionButton.new()
	_section_dropdown.custom_minimum_size = Vector2(0, 36)
	_section_dropdown.add_theme_font_size_override("font_size", 13)
	_section_dropdown.item_selected.connect(_on_section_selected)
	_student_numbers_section.add_child(_section_dropdown)
	
	# Populate dropdown with sections
	_refresh_section_dropdown()

	# ── Manual Entry Hint ──
	_student_numbers_hint = Label.new()
	_student_numbers_hint.text = "Enter student numbers (comma or newline separated):"
	_student_numbers_hint.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0, 0.6))
	_student_numbers_hint.add_theme_font_size_override("font_size", 11)
	_student_numbers_hint.visible = false
	_student_numbers_section.add_child(_student_numbers_hint)

	# ── Manual Entry TextEdit ──
	_student_numbers_edit = TextEdit.new()
	_student_numbers_edit.custom_minimum_size = Vector2(0, 80)
	_student_numbers_edit.placeholder_text = "21-2169, 21-2170, 21-2171..."
	_student_numbers_edit.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
	_student_numbers_edit.add_theme_color_override("caret_color", Color(0.145, 0.878, 0.992, 1.0))
	_student_numbers_edit.add_theme_font_size_override("font_size", 13)
	_student_numbers_edit.visible = false
	# Style the TextEdit background
	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = Color(0.02, 0.05, 0.14, 1.0)
	edit_style.border_color = Color(0.145, 0.878, 0.992, 0.4)
	edit_style.set_border_width_all(2)
	edit_style.set_corner_radius_all(8)
	edit_style.set_content_margin_all(10)
	_student_numbers_edit.add_theme_stylebox_override("normal", edit_style)
	_student_numbers_edit.add_theme_stylebox_override("focus", edit_style)
	_student_numbers_section.add_child(_student_numbers_edit)

	form_content.add_child(_student_numbers_section)
	form_content.move_child(_student_numbers_section, insert_idx + 1)

func _refresh_section_dropdown() -> void:
	if not _section_dropdown:
		return
	
	_section_dropdown.clear()
	_section_dropdown.add_item("— Select a section —", 0)
	_section_dropdown.set_item_metadata(0, "")
	
	var sections := StudentDatabase.get_all_sections()
	for section in sections:
		var count: int = section.get("students", []).size()
		var display := "%s (%s) — %d students" % [
			section.get("name", ""),
			section.get("school_year", ""),
			count
		]
		_section_dropdown.add_item(display)
		_section_dropdown.set_item_metadata(_section_dropdown.item_count - 1, section["id"])
	
	# Add import option
	_section_dropdown.add_separator()
	_section_dropdown.add_item("📥 Import new section from Excel/CSV...")
	_section_dropdown.set_item_metadata(_section_dropdown.item_count - 1, "__import__")

func _on_section_tab_pressed() -> void:
	_section_tab.button_pressed = true
	_manual_tab.button_pressed = false
	_section_dropdown.visible = true
	_student_numbers_hint.visible = false
	_student_numbers_edit.visible = false

func _on_manual_tab_pressed() -> void:
	_section_tab.button_pressed = false
	_manual_tab.button_pressed = true
	_section_dropdown.visible = false
	_student_numbers_hint.visible = true
	_student_numbers_edit.visible = true

func _on_section_selected(index: int) -> void:
	var section_id: String = _section_dropdown.get_item_metadata(index)
	
	if section_id == "__import__":
		# Open section manager for import
		_section_dropdown.select(0)
		_on_manage_sections_pressed()
		return
	
	_selected_section_id = section_id

func _on_manage_sections_pressed() -> void:
	# Set return path so Section Manager knows where to go back
	get_tree().set_meta("section_manager_return", "res://scene/TeacherCreateRoom.tscn")
	get_tree().change_scene_to_file("res://scene/section_manager.tscn")

func _on_manage_bindings_pressed() -> void:
	# Set return path and lobby URL for Binding Manager
	get_tree().set_meta("binding_manager_return", "res://scene/TeacherCreateRoom.tscn")
	get_tree().set_meta("binding_manager_lobby_url", "https://codebreaker-lobby.onrender.com")
	get_tree().change_scene_to_file("res://scene/binding_manager.tscn")

func _collect_allowed_students() -> Array:
	var allowed_list: Array = []
	
	if not _restrict_checkbox or not _restrict_checkbox.button_pressed:
		return allowed_list
	
	# Check if using section mode (dropdown visible + section selected)
	if _section_tab and _section_tab.button_pressed and not _selected_section_id.is_empty():
		# Get student numbers from selected section
		allowed_list = StudentDatabase.get_student_numbers_for_section(_selected_section_id)
	elif _student_numbers_edit and _student_numbers_edit.visible:
		# Manual entry mode
		var raw := _student_numbers_edit.text
		var parts := raw.replace("\n", ",").replace("\r", ",").split(",")
		for p in parts:
			var trimmed := p.strip_edges().to_upper()
			if not trimmed.is_empty():
				allowed_list.append(trimmed)
	
	return allowed_list

func _on_restrict_checkbox_toggled(pressed: bool) -> void:
	if _student_numbers_section:
		_student_numbers_section.visible = pressed
		# Refresh dropdown when shown
		if pressed:
			_refresh_section_dropdown()
	if not pressed:
		if _student_numbers_edit:
			_student_numbers_edit.text = ""
		_selected_section_id = ""
		if _section_dropdown:
			_section_dropdown.select(0)
	_update_generate_button()

func _build_save_draft_button() -> void:
	if not generate_button_row: return
	
	save_draft_button = Button.new()
	save_draft_button.text = "Save as Draft"
	save_draft_button.custom_minimum_size = Vector2(160, 40)
	save_draft_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.1, 0.15, 0.25, 0.9)
	sb_normal.border_color = Color(0.145, 0.878, 0.992, 0.6)
	sb_normal.set_border_width_all(2)
	sb_normal.set_corner_radius_all(6)
	save_draft_button.add_theme_stylebox_override("normal", sb_normal)
	
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.15, 0.25, 0.35, 1.0)
	sb_hover.border_color = Color(0.145, 0.878, 0.992, 1.0)
	sb_hover.set_border_width_all(2)
	sb_hover.set_corner_radius_all(6)
	save_draft_button.add_theme_stylebox_override("hover", sb_hover)
	
	save_draft_button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	save_draft_button.add_theme_font_size_override("font_size", 14)
	
	save_draft_button.pressed.connect(_on_save_draft_pressed)
	
	# Insert it to the left of the generate button (assuming generate is at index 0 or 1)
	generate_button_row.add_child(save_draft_button)
	generate_button_row.move_child(save_draft_button, generate_button.get_index())

func _build_refresh_button() -> void:
	var top_bar: HBoxContainer = main_panel.get_node_or_null("TopBar")
	if not top_bar: return
	
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(90, 36)
	refresh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.145, 0.878, 0.992, 0.2)
	sb.border_color = Color(0.145, 0.878, 0.992, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	refresh_btn.add_theme_stylebox_override("normal", sb)
	
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.145, 0.878, 0.992, 0.4)
	refresh_btn.add_theme_stylebox_override("hover", sb_hover)
	refresh_btn.add_theme_stylebox_override("pressed", sb)
	
	refresh_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	refresh_btn.pressed.connect(_load_room_history)
	
	top_bar.add_child(refresh_btn)
	
	# Try to insert it right before the Create button
	var create_btn = top_bar.get_node_or_null("CreateButton")
	if create_btn:
		top_bar.move_child(refresh_btn, create_btn.get_index())
		
	# Add a small spacer between Refresh and Create just in case
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	top_bar.add_child(spacer)
	top_bar.move_child(spacer, refresh_btn.get_index() + 1)
	
func _on_save_draft_pressed() -> void:
	var room_name := room_name_input.text.strip_edges()
	if room_name.is_empty():
		_flash_error(room_name_input); return
	if not _is_player_count_valid():
		_flash_error(player_count_input)
		player_validation_label.visible = true
		player_validation_label.text = "Enter a valid player count (%d-%d)." % [PLAYER_MIN, PLAYER_MAX]
		return
	if not game_mode_btn.button_pressed and not multiple_choice_btn.button_pressed:
		return
	if game_mode_btn.button_pressed:
		if selected_minigame.is_empty() or selected_difficulty.is_empty(): return
	if multiple_choice_btn.button_pressed:
		if not mc_all_questions_completed: return
	current_room_name = room_name
	_finalise_draft_room()

func _finalise_draft_room() -> void:
	var draft_code := _editing_draft_code if not _editing_draft_code.is_empty() else _generate_code()
	var cats: Array[String] = []
	if game_mode_btn.button_pressed: cats.append("Game Mode")
	if multiple_choice_btn.button_pressed: cats.append("Multiple Choice")
	var room_data: Dictionary = {
		"name": current_room_name, "difficulty": selected_difficulty,
		"categories": ", ".join(cats), "minigame": selected_minigame,
		"minigame_scene": selected_minigame_scene, "player_count": _get_player_count(),
		"status": "draft"
	}
	if multiple_choice_btn.button_pressed and not mc_quiz_data.is_empty():
		room_data["mc_quiz_data"] = mc_quiz_data.duplicate(true)
		room_data["mc_time_per_q"] = mc_selected_time

	# We don't put it in `rooms` dict (active rooms), we only save it to Firestore history
	# Collect student whitelist if enabled
	var allowed_list: Array = _collect_allowed_students()
	room_data["allowed_students"] = allowed_list

	_save_room_to_history(draft_code, room_data)
	
	# Skip opening the Code display screen -> return to Main History List directly
	_reset_form()
	_show_screen("main")
	# Refreshing will happen naturally when saving to Firestore, but we can call it now too
	_load_room_history()


# ── Reset ────────────────────────────────────────────────────────────────────

func _reset_mc_state() -> void:
	mc_quiz_created = false
	mc_all_questions_completed = false
	mc_quiz_data.clear()
	mc_selected_time = 0
	mc_questions_input.text = ""
	mc_questions_validation.visible = false
	mc_create_btn.text = "Create"
	mc_create_btn.disabled = true
	mc_view_btn.disabled = true
	mc_view_btn.visible = false
	for b in _mc_time_buttons:
		b.add_theme_stylebox_override("normal", _preset_idle_style())
		b.add_theme_stylebox_override("hover", _preset_idle_style())
		b.remove_theme_color_override("font_color")




# ── Screen management ────────────────────────────────────────────────────────

func _show_screen(which: String) -> void:
	main_panel.visible = (which == "main")
	create_form_panel.visible = (which == "form")
	room_code_panel.visible = (which == "code")
	statistics_panel.visible = (which == "stats")
	if quiz_creation_panel:
		quiz_creation_panel.visible = (which == "quiz_creation")
	if quiz_preview_panel:
		quiz_preview_panel.visible = (which == "quiz_preview")
	if lobby_panel:
		lobby_panel.visible = (which == "lobby")

	var target: Control
	match which:
		"main": target = main_panel
		"form": target = create_form_panel
		"code": target = room_code_panel
		"stats": target = statistics_panel
		"quiz_creation": target = quiz_creation_panel
		"quiz_preview": target = quiz_preview_panel
		"lobby": target = lobby_panel

	if target:
		target.modulate.a = 0.0
		target.scale = Vector2(0.92, 0.92)
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
		player_validation_label.text = "Enter a valid player count (%d-%d)." % [PLAYER_MIN, PLAYER_MAX]
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
	current_room_code = _editing_draft_code if not _editing_draft_code.is_empty() else _generate_code()
	var cats: Array[String] = []
	if game_mode_btn.button_pressed: cats.append("Game Mode")
	if multiple_choice_btn.button_pressed: cats.append("Multiple Choice")
	var room_data: Dictionary = {
		"name": current_room_name, "difficulty": selected_difficulty,
		"categories": ", ".join(cats), "minigame": selected_minigame,
		"minigame_scene": selected_minigame_scene, "player_count": _get_player_count(),
	}
	if multiple_choice_btn.button_pressed and not mc_quiz_data.is_empty():
		room_data["mc_quiz_data"] = mc_quiz_data.duplicate(true)
		room_data["mc_time_per_q"] = mc_selected_time

	rooms[current_room_code] = room_data
	code_room_name_label.text = current_room_name
	code_display_label.text = current_room_code
	
	# Save to Firestore room history
	_save_room_to_history(current_room_code, room_data)
	
	_show_screen("code")
	_refresh_room_list()

	# Collect student whitelist if enabled (shared for both quiz and game mode)
	var allowed_list: Array = _collect_allowed_students()
	room_data["allowed_students"] = allowed_list
	room_data["has_student_restriction"] = _restrict_checkbox != null and _restrict_checkbox.button_pressed

	# ── CyberQuiz: POST quiz data to server ─────────────────────────────
	if multiple_choice_btn.button_pressed and not mc_quiz_data.is_empty():
		_post_quiz_to_server(current_room_code, room_data)

	# ── GameMode: POST game room to server ──────────────────────────────
	if game_mode_btn.button_pressed and not selected_minigame.is_empty():
		_post_gamemode_to_server(current_room_code, room_data)

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
	tw.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.3)

func _highlight_preset(group: Array[Button], active: Button) -> void:
	for b in group:
		if b == active:
			b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1, 1))
			b.add_theme_stylebox_override("normal", _preset_active_style())
			b.add_theme_stylebox_override("hover", _preset_active_style())
		else:
			b.remove_theme_color_override("font_color")
			b.add_theme_stylebox_override("normal", _preset_idle_style())
			b.add_theme_stylebox_override("hover", _preset_idle_style())

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
		s.bg_color = Color(0, 0, 0, 0)
		s.border_width_left = 0
		s.border_width_top = 0
		s.border_width_right = 0
		s.border_width_bottom = 0
		s.corner_radius_top_left = 6
		s.corner_radius_top_right = 6
		s.corner_radius_bottom_left = 6
		s.corner_radius_bottom_right = 6
		return s
func _on_player_count_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9": digits += ch
	if digits != new_text:
		player_count_input.text = digits
		player_count_input.caret_column = digits.length()
	if digits.is_empty():
		player_validation_label.visible = true
		player_validation_label.text = "Player count cannot be empty."
	else:
		var val := digits.to_int()
		if val < PLAYER_MIN or val > PLAYER_MAX:
			player_validation_label.visible = true
			player_validation_label.text = "Enter a value between %d and %d." % [PLAYER_MIN, PLAYER_MAX]
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
	popup_selected_label.text = "No game selected yet — click a card below."
	popup_confirm_btn.disabled = true
	choose_game_popup.visible = true
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

func _on_popup_close_pressed() -> void: _close_popup()
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _on_popup_confirm_pressed() -> void:
	if selected_minigame.is_empty(): return
	_close_popup(); _update_generate_button()
	await get_tree().create_timer(0.18).timeout

func _build_minigame_cards() -> void:
	for c in minigame_grid.get_children(): c.queue_free()
	var current_lesson := ""
	for game in ALL_MINIGAMES:
		var lesson: String = game.get("lesson", "")
		if lesson != current_lesson:
			current_lesson = lesson
			minigame_grid.add_child(_make_lesson_header(lesson))
		minigame_grid.add_child(_make_card(game))

func _make_lesson_header(lesson_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.55, 0.75, 0.25)
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 6; s.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = LESSON_HEADERS.get(lesson_key, lesson_key)
	lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	lbl.add_theme_font_size_override("font_size", 15)
	panel.add_child(lbl)
	return panel

func _make_card(game: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(238, 82)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.name = "Card_" + game["id"]
	card.add_theme_stylebox_override("panel", _card_style(false))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	var icon_tex := TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(48, 48)
	icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.texture = _get_icon(game["icon"])
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
	_selected_card = card
	selected_minigame = game["name"]
	selected_minigame_scene = game["scene"]
	selected_difficulty = game.get("level", "Beginner")
	_update_generate_button()
	
	if choose_game_hint:
		choose_game_hint.text = game["name"]
		
	popup_selected_label.text = "Selected: %s  [%s]" % [game["name"], game["level"]]
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
		s.shadow_size = 8
	else:
		s.bg_color = Color(0.05, 0.06, 0.15, 0.92)
		s.border_color = Color(0.0, 0.85, 1.0, 0.45)
	return s

func _get_icon(key: String) -> Texture2D:
	match key:
		"FUNDAMENTALS": return ICON_FUNDAMENTALS
		"NETWORK": return ICON_NETWORK
		"PASSWORD": return ICON_PASSWORD
		"MALWARE": return ICON_MALWARE
		"ENCRYPTION": return ICON_ENCRYPTION
		"DROP_ZONE": return ICON_DROP_ZONE
		"PHISHING": return ICON_PHISHING
		"ASSET_THREAT": return ICON_ASSET_THREAT
		"CRYPT_CONTRACT": return ICON_CRYPT_CONTRACT
		"INCIDENT_COMMANDER": return ICON_INCIDENT_COMMANDER
		"SECURITY_GUARDIAN": return ICON_SECURITY_GUARDIAN
		"CRYPTO_SORTER": return ICON_CRYPTO_SORTER
		"RSA_KEY_LAB": return ICON_RSA_KEY_LAB
		_: return ICON_FUNDAMENTALS

func _on_copy_code_pressed() -> void:
	if current_room_code.is_empty(): return
	DisplayServer.clipboard_set(current_room_code)
	copy_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	copy_button.text = "Copy"

## Wrap room_list_container in a ScrollContainer with hidden scrollbar
func _wrap_room_list_in_scroll() -> void:
	var parent := room_list_container.get_parent()
	if not parent: return

	var scroll := ScrollContainer.new()
	scroll.name = "RoomListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Copy position from the VBox
	scroll.offset_left = room_list_container.offset_left
	scroll.offset_top = room_list_container.offset_top
	scroll.offset_right = room_list_container.offset_right
	scroll.offset_bottom = room_list_container.offset_bottom

	# Insert scroll at same index as room_list_container
	var idx := room_list_container.get_index()
	parent.remove_child(room_list_container)
	parent.add_child(scroll)
	parent.move_child(scroll, idx)

	# Reset VBox positioning inside scroll
	room_list_container.offset_left = 0
	room_list_container.offset_top = 0
	room_list_container.offset_right = scroll.offset_right - scroll.offset_left
	room_list_container.offset_bottom = 0
	room_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(room_list_container)

	# Hide scrollbar for cleaner UI
	var v_bar := scroll.get_v_scroll_bar()
	if v_bar:
		v_bar.modulate = Color(1, 1, 1, 0)

func _refresh_room_list() -> void:
	for child in room_list_container.get_children():
		if child != empty_label: child.queue_free()
	
	# Combine active rooms and history
	var all_shown: bool = not rooms.is_empty() or not room_history.is_empty()
	empty_label.visible = not all_shown
	
	# Show room history (from Firestore)
	for history_item in room_history:
		var status: String = history_item.get("status", "active")
		room_list_container.add_child(_create_room_item(
			history_item.get("room_name", "Untitled"),
			history_item.get("room_code", ""),
			history_item.get("difficulty", ""),
			history_item.get("game_name", ""),
			history_item.get("player_count", 10),
			status,
			history_item.get("category", "game_mode")))
	
	# Show active session rooms (not yet saved to history or still in active stats)
	for code in rooms:
		var data: Dictionary = rooms[code]
		# Only show if not already in history
		var already_shown := false
		for h in room_history:
			if h.get("room_code") == code:
				already_shown = true
				break
		if not already_shown:
			var category := "game_mode" if game_mode_btn.button_pressed else "multiple_choice"
			room_list_container.add_child(_create_room_item(
				data["name"], code, data["difficulty"],
				data.get("minigame", ""), data.get("player_count", 0), "active", category))

func _create_room_item(rname: String, code: String, diff: String, game: String, _player_count: int, _status: String = "active", category: String = "game_mode") -> PanelContainer:
	var item := PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 46)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# White/light panel style matching Figma
	var item_style := StyleBoxFlat.new()
	item_style.bg_color = Color(0.85, 0.9, 0.95, 0.15)
	item_style.border_color = Color(0.6, 0.75, 0.85, 0.3)
	item_style.set_border_width_all(1)
	item_style.set_corner_radius_all(6)
	item_style.content_margin_left = 16
	item_style.content_margin_right = 12
	item_style.content_margin_top = 8
	item_style.content_margin_bottom = 8
	item.add_theme_stylebox_override("panel", item_style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_child(hbox)
	
	# Room name label (left-aligned, fixed width)
	var name_lbl := Label.new()
	name_lbl.text = rname
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_lbl)
	
	# Room code label (expanded, takes remaining space)
	var code_lbl := Label.new()
	code_lbl.text = code
	code_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.9))
	code_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(code_lbl)
	
	# Difficulty / category label (right side, before button)
	var info_text := diff if diff != "" and diff != "MC" else ""
	if game != "":
		info_text = game
	if category == "multiple_choice" and info_text == "":
		info_text = "Quiz"
	if info_text != "":
		var info_lbl := Label.new()
		info_lbl.text = info_text
		info_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.7))
		info_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(info_lbl)
	
	# View / Resume button (matching Figma style)
	var view_btn := Button.new()
	if _status == "draft":
		view_btn.text = "Resume"
	else:
		view_btn.text = "View"
	view_btn.custom_minimum_size = Vector2(75, 30)
	view_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style := StyleBoxFlat.new()
	if _status == "draft":
		btn_style.bg_color = Color(0.145, 0.90, 0.60, 0.9) # Green-ish for resume
	else:
		btn_style.bg_color = Color(0.145, 0.878, 0.992, 0.9)
	btn_style.set_corner_radius_all(5)
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	view_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := StyleBoxFlat.new()
	if _status == "draft":
		btn_hover.bg_color = Color(0.18, 0.95, 0.65, 1.0)
	else:
		btn_hover.bg_color = Color(0.2, 0.92, 1.0, 1.0)
	btn_hover.set_corner_radius_all(5)
	btn_hover.content_margin_left = 12
	btn_hover.content_margin_right = 12
	btn_hover.content_margin_top = 4
	btn_hover.content_margin_bottom = 4
	view_btn.add_theme_stylebox_override("hover", btn_hover)
	
	view_btn.add_theme_color_override("font_color", Color(0.03, 0.05, 0.12, 1))
	view_btn.add_theme_font_size_override("font_size", 13)
	
	var cap_code := code
	var cap_category := category
	if _status == "draft":
		view_btn.pressed.connect(func(): _load_draft_into_form(cap_code, cap_category))
	else:
		view_btn.pressed.connect(func(): _view_room_history(cap_code, cap_category))
	hbox.add_child(view_btn)
	
	return item

func _load_draft_into_form(code: String, category: String) -> void:
	var draft_data: Dictionary = {}
	for h in room_history:
		if h.get("room_code") == code:
			draft_data = h
			break
			
	if draft_data.is_empty(): return
	
	# Reconstruct room_data format
	var room_data := {
		"name": draft_data.get("room_name", "Untitled Draft"),
		"difficulty": draft_data.get("difficulty", ""),
		"categories": "Multiple Choice" if category == "multiple_choice" else "Game Mode",
		"minigame": draft_data.get("game_name", ""),
		"minigame_scene": "",
		"player_count": int(draft_data.get("player_count", 10)),
		"allowed_students": [] 
	}
	
	# Find scene from game name
	for g in ALL_MINIGAMES:
		if g["name"] == room_data["minigame"]:
			room_data["minigame_scene"] = g["scene"]
			room_data["difficulty"] = g.get("level", "Beginner")
			break
			
	# We need to load full document to get mc_quiz_data for multiple choice
	if category == "multiple_choice":
		_fetch_full_draft_and_edit(code, room_data)
	else:
		_complete_draft_edit(code, room_data)
		
func _fetch_full_draft_and_edit(code: String, base_room_data: Dictionary) -> void:
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var url := "%s/users/%s" % [FIRESTORE_BASE_URL, uid]
	var headers := ["Content-Type: application/json", "Authorization: Bearer %s" % token]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, call_code, _h, body):
		http.queue_free()
		if call_code == 200:
			var doc = JSON.parse_string(body.get_string_from_utf8())
			if typeof(doc) == TYPE_DICTIONARY:
				var fields = doc.get("fields", {})
				if fields.has("room_history"):
					var arr = fields["room_history"].get("arrayValue", {}).get("values", [])
					for item in arr:
						var rfields = item.get("mapValue", {}).get("fields", {})
						if rfields.has("room_code") and rfields["room_code"].get("stringValue") == code:
							if rfields.has("mc_quiz_data_json"):
								var qdata_str = rfields["mc_quiz_data_json"].get("stringValue", "{}")
								base_room_data["mc_quiz_data"] = JSON.parse_string(qdata_str)
							if rfields.has("mc_time_per_q"):
								base_room_data["mc_time_per_q"] = int(rfields["mc_time_per_q"].get("integerValue", "30"))
							break
		_complete_draft_edit(code, base_room_data)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _complete_draft_edit(code: String, room_data: Dictionary) -> void:
	_reset_form()
	_editing_draft_code = code
	room_name_input.text = room_data.get("name", "")
	player_count_input.text = str(room_data.get("player_count", 10))
	
	# ✅ FIX: Check category from room_data string, not button state
	var cats_str: String = str(room_data.get("categories", ""))
	var is_mc := cats_str.contains("Multiple Choice")
	
	if is_mc:
		multiple_choice_btn.button_pressed = true
		_on_multiple_choice_toggled(true)
		if room_data.has("mc_quiz_data"):
			mc_quiz_data.clear()
			mc_quiz_data = room_data["mc_quiz_data"]
			mc_all_questions_completed = true
			mc_quiz_created = true
			var num_q = int(mc_quiz_data.get("total_questions", 0))
			if num_q == 0 and mc_quiz_data.has("questions"):
				num_q = mc_quiz_data["questions"].size()
			mc_questions_input.text = str(num_q)
			mc_view_btn.disabled = false
			mc_create_btn.text = "Edit Quiz"
			mc_create_btn.disabled = false
			
			var target_time = int(room_data.get("mc_time_per_q", 30))
			for btn in _mc_time_buttons:
				if btn.text == str(target_time) + "s":
					_on_mc_time_selected(target_time, btn)
	else:
		game_mode_btn.button_pressed = true
		_on_game_mode_toggled(true)
		selected_minigame = room_data.get("minigame", "")
		selected_minigame_scene = room_data.get("minigame_scene", "")
		selected_difficulty = room_data.get("difficulty", "Beginner")
		
		# ✅ FIX: Show correct hint text — fallback if minigame is empty
		if choose_game_hint:
			if not selected_minigame.is_empty():
				choose_game_hint.text = selected_minigame
			else:
				choose_game_hint.text = "Pick minigame for the room"
		
		# ✅ FIX: Visually highlight the selected card in the popup grid
		if not selected_minigame.is_empty():
			for card in minigame_grid.get_children():
				if card is PanelContainer and card.name.begins_with("Card_"):
					var lbl = card.get_node_or_null("HBoxContainer/VBoxContainer/Label")
					if lbl and lbl.text == selected_minigame:
						_clear_card_highlight()
						card.add_theme_stylebox_override("panel", _card_style(true))
						_selected_card = card
						popup_selected_label.text = "Selected: %s  [%s]" % [selected_minigame, selected_difficulty]
						popup_confirm_btn.disabled = false
						break
		
	_update_generate_button()
	_show_screen("form")


## View room history — fetch and display statistics for a completed/active room
func _view_room_history(code: String, category: String) -> void:
	_viewing_room_code = code
	
	# Find room in history or active rooms
	var room_name := ""
	for h in room_history:
		if h.get("room_code") == code:
			room_name = h.get("room_name", "Untitled Room")
			break
	
	if room_name.is_empty() and rooms.has(code):
		room_name = rooms[code].get("name", "Untitled Room")
	
	current_room_code = code
	current_room_name = room_name
	stats_room_name_label.text = room_name
	
	# Clear stale stats from previous room view
	_clear_stats_panels()
	_show_screen("stats")
	
	# Show cached results immediately if we have them
	if _cached_results_by_room.has(code):
		var cached: Dictionary = _cached_results_by_room[code]
		if category == "multiple_choice":
			_update_stats_leaderboard(cached)
		elif category == "game_mode":
			_update_gamemode_leaderboard(cached)
	
	# Fetch fresh statistics from server
	if category == "multiple_choice":
		_start_results_polling(code)
	elif category == "game_mode":
		_start_gamemode_results_polling(code)
	else:
		push_warning("[RoomHistory] Unknown category: %s" % category)

## Clear all stats sub-panels to empty/loading state
func _clear_stats_panels() -> void:
	var graph_panel = statistics_panel.get_node_or_null("StatsGrid/GraphPanel")
	if graph_panel:
		for child in graph_panel.get_children():
			child.queue_free()
	var high_score_panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/HighScorePanel")
	if high_score_panel:
		for child in high_score_panel.get_children():
			child.queue_free()
	var rankings_panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/RankingsPanel")
	if rankings_panel:
		for child in rankings_panel.get_children():
			child.queue_free()
	_cached_leaderboard = []

func _view_room(code: String) -> void:
	if not rooms.has(code): return
	current_room_code = code
	current_room_name = rooms[code]["name"]
	code_room_name_label.text = current_room_name
	code_display_label.text = current_room_code
	_show_screen("code")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(scene_on_back)

func _on_create_button_pressed() -> void:
	_reset_form()
	room_name_input.text = "Quiz-%d" % (rooms.size() + 1)
	_update_generate_button()
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
	# CyberQuiz: start lobby polling + heartbeat for MC quiz rooms
	if room_data.get("minigame", "").is_empty() and lobby_panel and lobby_panel.has_method("start_server_polling"):
		lobby_panel.start_server_polling(current_room_code, _get_lobby_url())
		_start_quiz_heartbeat(current_room_code)
	# GameMode: start lobby polling + heartbeat for game mode rooms
	elif not room_data.get("minigame", "").is_empty() and lobby_panel and lobby_panel.has_method("start_gamemode_polling"):
		lobby_panel.start_gamemode_polling(current_room_code, _get_lobby_url())
		_start_gamemode_heartbeat(current_room_code)

func _on_lobby_closed() -> void: _show_screen("code")

func _on_quiz_started(room_code: String) -> void:
	if not rooms.has(room_code): return
	var room_data: Dictionary = rooms[room_code]

	# Multiple Choice → POST start to server, then show StatisticsPanel
	if room_data.get("minigame", "") == "":
		if not _quiz_start_posted:
			_post_quiz_start(room_code)
			_quiz_start_posted = true
		stats_room_name_label.text = room_data.get("name", "")
		_show_screen("stats")
		_start_results_polling(room_code)
		return

	# Game Mode → POST start to server, then show StatisticsPanel with leaderboard
	if not _quiz_start_posted:
		_post_gamemode_start(room_code)
		_quiz_start_posted = true
	stats_room_name_label.text = room_data.get("name", "")
	_show_screen("stats")
	_start_gamemode_results_polling(room_code)

func _on_stats_back_pressed() -> void:
	_quiz_start_posted = false
	# Mark room as completed and return to room history
	if not current_room_code.is_empty():
		_mark_room_completed(current_room_code)
	
	# Stop any polling timers
	if _quiz_poll_timer:
		_quiz_poll_timer.queue_free()
		_quiz_poll_timer = null
	if _quiz_heartbeat_timer:
		_quiz_heartbeat_timer.queue_free()
		_quiz_heartbeat_timer = null
	
	# Reload room history and show main panel
	_load_room_history()
	_show_screen("main")

func _on_see_all_pressed() -> void:
	_show_see_all_popup(_cached_leaderboard)

# ── CyberQuiz server helpers ─────────────────────────────────────────────────

func _get_lobby_url() -> String:
	if has_node("/root/MultiplayerConfig"):
		return get_node("/root/MultiplayerConfig").get_lobby_url()
	var cfg_script = load("res://script/MultiplayerConfig.gd")
	if cfg_script:
		var cfg = cfg_script.new()
		return cfg.get_lobby_url()
	return "https://codebreaker-lobby.onrender.com"

func _post_quiz_to_server(room_code: String, room_data: Dictionary) -> void:
	var url := _get_lobby_url() + "/api/quiz/create"
	var quiz_d = room_data.get("mc_quiz_data", {})
	var body := {
		"room_code": room_code,
		"room_name": room_data.get("name", "CyberQuiz Room"),
		"host_id": Auth.current_local_id,
		"host_username": Auth.current_username,
		"quiz_data": quiz_d,
		"time_per_question": room_data.get("mc_time_per_q", 30),
		"max_players": room_data.get("player_count", 10),
		"allowed_students": room_data.get("allowed_students", []),
		"has_student_restriction": room_data.get("has_student_restriction", false),
	}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[CyberQuiz] ✅ Quiz room created on server: %s" % room_code)
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_error("[CyberQuiz] ❌ Failed to create quiz on server: %d %s" % [code, err_text])
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("[CyberQuiz] ❌ HTTP request failed: %d" % err)
		http.queue_free()

func _post_quiz_start(room_code: String) -> void:
	var url := _get_lobby_url() + "/api/quiz/%s/start" % room_code
	var body := {"host_id": Auth.current_local_id}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[CyberQuiz] ✅ Quiz started: %s" % room_code)
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_error("[CyberQuiz] ❌ Failed to start quiz: %d %s" % [code, err_text])
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _start_results_polling(room_code: String) -> void:
	if _quiz_poll_timer:
		_quiz_poll_timer.queue_free()
	_quiz_poll_timer = Timer.new()
	_quiz_poll_timer.wait_time = 5.0
	_quiz_poll_timer.autostart = true
	add_child(_quiz_poll_timer)
	_quiz_poll_timer.timeout.connect(func(): _poll_quiz_results(room_code))
	# Immediate first poll
	_poll_quiz_results(room_code)

func _poll_quiz_results(room_code: String) -> void:
	var url := _get_lobby_url() + "/api/quiz/%s/results" % room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			# Server doesn't have this room (expired/restarted) — try Firestore cache
			if not _cached_results_by_room.has(room_code):
				_load_results_from_firestore(room_code, "multiple_choice")
			return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		_cached_results_by_room[room_code] = data
		_update_stats_leaderboard(data)
		# Save to Firestore for persistence
		_save_results_to_firestore(room_code, data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _update_stats_leaderboard(data: Dictionary) -> void:
	var leaderboard: Array = data.get("leaderboard", [])
	var total_q: int = data.get("total_questions", 0)
	var question_stats: Array = data.get("question_stats", [])
	_cached_leaderboard = leaderboard

	# --- Ensure StatsGrid is visible and clean up any old StatsContent ---
	var stats_grid = statistics_panel.get_node_or_null("StatsGrid")
	if stats_grid:
		stats_grid.visible = true
	var old_content = statistics_panel.get_node_or_null("StatsContent")
	if old_content:
		old_content.queue_free()

	# --- GRAPH PANEL: per-question correct/wrong bar chart ---
	var graph_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/GraphPanel")
	if graph_panel:
		_populate_graph_panel(graph_panel, question_stats, total_q)

	# --- HIGH SCORE PANEL: top 1 player ---
	var high_score_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/HighScorePanel")
	if high_score_panel:
		_populate_high_score_panel(high_score_panel, leaderboard)

	# --- RANKINGS PANEL: top 3 players ---
	var rankings_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/RankingsPanel")
	if rankings_panel:
		_populate_rankings_panel(rankings_panel, leaderboard)

## Build bar chart inside GraphPanel showing correct/wrong per question
func _populate_graph_panel(panel: Panel, question_stats: Array, _total_q: int) -> void:
	# Remove old children except keep panel style
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Questions Overview"
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if question_stats.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No data yet..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(empty_lbl)
		return

	# Scrollable chart area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var chart_hbox := HBoxContainer.new()
	chart_hbox.add_theme_constant_override("separation", 6)
	chart_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(chart_hbox)

	# Find max count to scale bars
	var max_count := 1
	for qs in question_stats:
		var c: int = int(qs.get("correct", 0))
		var w: int = int(qs.get("wrong", 0))
		if c + w > max_count:
			max_count = c + w

	for qs in question_stats:
		var q_idx: int = int(qs.get("question_index", 0))
		var correct: int = int(qs.get("correct", 0))
		var wrong: int = int(qs.get("wrong", 0))

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(28, 0)

		# Bar area (grows to fill)
		var bar_container := VBoxContainer.new()
		bar_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar_container.alignment = BoxContainer.ALIGNMENT_END

		# Correct bar (green)
		if correct > 0:
			var correct_bar := ColorRect.new()
			var bar_ratio: float = float(correct) / float(max_count)
			correct_bar.custom_minimum_size = Vector2(22, max(bar_ratio * 120.0, 6.0))
			correct_bar.color = Color(0.2, 0.85, 0.4, 0.9)
			correct_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			# Tooltip
			correct_bar.tooltip_text = "Q%d: %d correct" % [q_idx, correct]
			bar_container.add_child(correct_bar)

		# Wrong bar (red)
		if wrong > 0:
			var wrong_bar := ColorRect.new()
			var bar_ratio_w: float = float(wrong) / float(max_count)
			wrong_bar.custom_minimum_size = Vector2(22, max(bar_ratio_w * 120.0, 6.0))
			wrong_bar.color = Color(1.0, 0.3, 0.3, 0.9)
			wrong_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			wrong_bar.tooltip_text = "Q%d: %d wrong" % [q_idx, wrong]
			bar_container.add_child(wrong_bar)

		col.add_child(bar_container)

		# Question label
		var q_lbl := Label.new()
		q_lbl.text = "Q%d" % q_idx
		q_lbl.add_theme_font_size_override("font_size", 10)
		q_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(q_lbl)

		chart_hbox.add_child(col)

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	# Green = correct
	var lg := HBoxContainer.new()
	lg.add_theme_constant_override("separation", 4)
	var green_box := ColorRect.new()
	green_box.custom_minimum_size = Vector2(12, 12)
	green_box.color = Color(0.2, 0.85, 0.4, 0.9)
	lg.add_child(green_box)
	var green_lbl := Label.new()
	green_lbl.text = "Correct"
	green_lbl.add_theme_font_size_override("font_size", 10)
	green_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	lg.add_child(green_lbl)
	legend.add_child(lg)
	# Red = wrong
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 4)
	var red_box := ColorRect.new()
	red_box.custom_minimum_size = Vector2(12, 12)
	red_box.color = Color(1.0, 0.3, 0.3, 0.9)
	lr.add_child(red_box)
	var red_lbl := Label.new()
	red_lbl.text = "Wrong"
	red_lbl.add_theme_font_size_override("font_size", 10)
	red_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	lr.add_child(red_lbl)
	legend.add_child(lr)
	vbox.add_child(legend)

## High-score panel: show #1 player
func _populate_high_score_panel(panel: Panel, leaderboard: Array) -> void:
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "High Score"
	title.add_theme_color_override("font_color", Color(1, 0.85, 0))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if leaderboard.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Waiting for students..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)
		return

	var top: Dictionary = leaderboard[0]
	var finished: bool = top.get("finished", false)

	# Trophy + Name
	var name_lbl := Label.new()
	name_lbl.text = "🏆 %s" % str(top.get("username", "???"))
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Score
	var score_lbl := Label.new()
	if finished:
		score_lbl.text = "%d pts" % int(top.get("score", 0))
		score_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5))
	else:
		score_lbl.text = "answering..."
		score_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)

## Rankings panel: show top 3 players
func _populate_rankings_panel(panel: Panel, leaderboard: Array) -> void:
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Top Rankings"
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	title.add_theme_font_size_override("font_size", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if leaderboard.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No players yet..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)
		return

	var rank_emojis := ["🥇", "🥈", "🥉"]
	var rank_colors := [Color(1, 0.85, 0), Color(0.78, 0.78, 0.82), Color(0.82, 0.55, 0.2)]
	var top_count: int = min(leaderboard.size(), 3)

	for i in range(top_count):
		var entry: Dictionary = leaderboard[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var rank_lbl := Label.new()
		rank_lbl.text = rank_emojis[i]
		rank_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("username", "???"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", rank_colors[i])
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		var finished: bool = entry.get("finished", false)
		if finished:
			score_lbl.text = "%d" % int(entry.get("score", 0))
			score_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			score_lbl.text = "..."
			score_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		score_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(score_lbl)

		vbox.add_child(row)

## See All popup — full leaderboard overlay
func _show_see_all_popup(leaderboard: Array) -> void:
	# Remove old popup if any
	var old = statistics_panel.get_node_or_null("SeeAllPopup")
	if old:
		old.queue_free()

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "SeeAllPopup"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	statistics_panel.add_child(backdrop)

	# Popup panel
	var popup_panel := PanelContainer.new()
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.offset_left = -250
	popup_panel.offset_top = -180
	popup_panel.offset_right = 250
	popup_panel.offset_bottom = 180
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.08, 0.1, 0.16, 0.97)
	popup_sb.border_color = Color(0, 1, 1, 0.6)
	popup_sb.set_border_width_all(2)
	popup_sb.set_corner_radius_all(12)
	popup_sb.set_content_margin_all(16)
	popup_panel.add_theme_stylebox_override("panel", popup_sb)
	backdrop.add_child(popup_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popup_panel.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	var header_lbl := Label.new()
	header_lbl.text = "🏆 Full Rankings — %s" % current_room_name
	header_lbl.add_theme_color_override("font_color", Color(0, 1, 1))
	header_lbl.add_theme_font_size_override("font_size", 16)
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	close_btn.pressed.connect(func(): backdrop.queue_free())
	header_row.add_child(close_btn)
	vbox.add_child(header_row)

	# Divider
	var div := HSeparator.new()
	var div_sb := StyleBoxLine.new()
	div_sb.color = Color(0.3, 0.4, 0.5, 0.5)
	div.add_theme_stylebox_override("separator", div_sb)
	vbox.add_child(div)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	if leaderboard.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No players yet."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		list.add_child(empty_lbl)
	else:
		var rank_emojis := ["🥇", "🥈", "🥉"]
		for entry in leaderboard:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var rank_num: int = int(entry.get("rank", 0))
			var rank_lbl := Label.new()
			if rank_num >= 1 and rank_num <= 3:
				rank_lbl.text = rank_emojis[rank_num - 1]
			else:
				rank_lbl.text = "#%d" % rank_num
			rank_lbl.custom_minimum_size = Vector2(30, 0)
			rank_lbl.add_theme_font_size_override("font_size", 14)
			row.add_child(rank_lbl)

			var name_lbl := Label.new()
			name_lbl.text = str(entry.get("username", "???"))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(name_lbl)

			var score_lbl := Label.new()
			var finished: bool = entry.get("finished", false)
			if finished:
				score_lbl.text = "%d pts" % int(entry.get("score", 0))
				score_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5))
			else:
				score_lbl.text = "answering..."
				score_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			score_lbl.add_theme_font_size_override("font_size", 14)
			row.add_child(score_lbl)

			list.add_child(row)

	# Close button at bottom
	var close_btn2 := Button.new()
	close_btn2.text = "Close"
	close_btn2.custom_minimum_size = Vector2(120, 36)
	close_btn2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	btn_sb.border_color = Color(0, 1, 1, 0.5)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(8)
	close_btn2.add_theme_stylebox_override("normal", btn_sb)
	close_btn2.add_theme_color_override("font_color", Color(1, 1, 1))
	close_btn2.add_theme_font_size_override("font_size", 13)
	close_btn2.pressed.connect(func(): backdrop.queue_free())
	vbox.add_child(close_btn2)

	# Also close on backdrop click
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			var local := backdrop.get_local_mouse_position()
			var panel_rect := Rect2(popup_panel.position, popup_panel.size)
			if not panel_rect.has_point(local):
				backdrop.queue_free()
	)

func _start_quiz_heartbeat(room_code: String) -> void:
	if _quiz_heartbeat_timer:
		_quiz_heartbeat_timer.queue_free()
	_quiz_heartbeat_timer = Timer.new()
	_quiz_heartbeat_timer.wait_time = 30.0
	_quiz_heartbeat_timer.autostart = true
	add_child(_quiz_heartbeat_timer)
	_quiz_heartbeat_timer.timeout.connect(func():
		var url := _get_lobby_url() + "/api/quiz/%s/heartbeat" % room_code
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
		http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	)

# ── GameMode server helpers ──────────────────────────────────────────────────

func _post_gamemode_to_server(room_code: String, room_data: Dictionary) -> void:
	var url := _get_lobby_url() + "/api/gamemode/create"
	var body := {
		"room_code": room_code,
		"room_name": room_data.get("name", "Game Room"),
		"host_id": Auth.current_local_id,
		"host_username": Auth.current_username,
		"game_name": room_data.get("minigame", ""),
		# Provide fallback scene to prevent server crashing if missing
		"game_scene": room_data.get("minigame_scene", "res://scene/tutorial_cyber_fundamentals.tscn"),
		"difficulty": room_data.get("difficulty", "Beginner"),
		"max_players": int(room_data.get("player_count", 10)),
		"allowed_students": room_data.get("allowed_students", []),
		"has_student_restriction": room_data.get("has_student_restriction", false),
	}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[GameMode] ✅ Game room created on server: %s" % room_code)
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_error("[GameMode] ❌ Failed to create game room: %d %s" % [code, err_text])
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("[GameMode] ❌ HTTP request failed: %d" % err)
		http.queue_free()

func _post_gamemode_start(room_code: String) -> void:
	var url := _get_lobby_url() + "/api/gamemode/%s/start" % room_code
	var body := {"host_id": Auth.current_local_id}
	var headers := ["Content-Type: application/json"]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			print("[GameMode] ✅ Game started: %s" % room_code)
		else:
			var err_text: String = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_error("[GameMode] ❌ Failed to start game: %d %s" % [code, err_text])
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _start_gamemode_results_polling(room_code: String) -> void:
	if _quiz_poll_timer:
		_quiz_poll_timer.queue_free()
	_quiz_poll_timer = Timer.new()
	_quiz_poll_timer.wait_time = 5.0
	_quiz_poll_timer.autostart = true
	add_child(_quiz_poll_timer)
	_quiz_poll_timer.timeout.connect(func(): _poll_gamemode_results(room_code))
	# Immediate first poll
	_poll_gamemode_results(room_code)

func _poll_gamemode_results(room_code: String) -> void:
	var url := _get_lobby_url() + "/api/gamemode/%s/results" % room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			if not _cached_results_by_room.has(room_code):
				_load_results_from_firestore(room_code, "game_mode")
			return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		_cached_results_by_room[room_code] = data
		_update_gamemode_leaderboard(data)
		_save_results_to_firestore(room_code, data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _start_gamemode_heartbeat(room_code: String) -> void:
	if _quiz_heartbeat_timer:
		_quiz_heartbeat_timer.queue_free()
	_quiz_heartbeat_timer = Timer.new()
	_quiz_heartbeat_timer.wait_time = 30.0
	_quiz_heartbeat_timer.autostart = true
	add_child(_quiz_heartbeat_timer)
	_quiz_heartbeat_timer.timeout.connect(func():
		var url := _get_lobby_url() + "/api/gamemode/%s/heartbeat" % room_code
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
		http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	)

func _update_gamemode_leaderboard(data: Dictionary) -> void:
	var leaderboard: Array = data.get("leaderboard", [])
	var game_name: String = data.get("game_name", "Game Mode")
	_cached_leaderboard = leaderboard

	# --- Ensure StatsGrid is visible and clean up any old StatsContent ---
	var stats_grid = statistics_panel.get_node_or_null("StatsGrid")
	if stats_grid:
		stats_grid.visible = true
	var old_content = statistics_panel.get_node_or_null("StatsContent")
	if old_content:
		old_content.queue_free()

	# Determine if this is a time-only game (Encryption has no score)
	var is_time_only: bool = game_name.to_lower().find("encryption") >= 0

	# --- GRAPH PANEL: show score distribution or time leaderboard for GameMode ---
	var graph_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/GraphPanel")
	if graph_panel:
		_populate_gamemode_graph(graph_panel, leaderboard, game_name, is_time_only)

	# --- HIGH SCORE PANEL: top 1 player ---
	var high_score_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/HighScorePanel")
	if high_score_panel:
		_populate_gamemode_high_score(high_score_panel, leaderboard, is_time_only)

	# --- RANKINGS PANEL: top 3 players ---
	var rankings_panel: Panel = statistics_panel.get_node_or_null("StatsGrid/RightColumn/RankingsPanel")
	if rankings_panel:
		_populate_gamemode_rankings(rankings_panel, leaderboard, is_time_only)

## GameMode graph: score bar chart for each player
func _populate_gamemode_graph(panel: Panel, leaderboard: Array, _game_name: String, is_time_only: bool) -> void:
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Player Scores" if not is_time_only else "Player Times"
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var finished_players: Array = []
	for entry in leaderboard:
		if entry.get("finished", false):
			finished_players.append(entry)

	if finished_players.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Waiting for players..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(empty_lbl)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var chart_hbox := HBoxContainer.new()
	chart_hbox.add_theme_constant_override("separation", 8)
	chart_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(chart_hbox)

	var max_val := 1.0
	for entry in finished_players:
		if is_time_only:
			var t: float = float(entry.get("time_taken_ms", 0)) / 1000.0
			if t > max_val: max_val = t
		else:
			var s: float = float(entry.get("score", 0))
			if s > max_val: max_val = s

	for entry in finished_players:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(32, 0)

		var bar_container := VBoxContainer.new()
		bar_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar_container.alignment = BoxContainer.ALIGNMENT_END

		var val: float
		var val_text: String
		if is_time_only:
			val = float(entry.get("time_taken_ms", 0)) / 1000.0
			@warning_ignore("integer_division")
			var secs: int = int(entry.get("time_taken_ms", 0)) / 1000
			@warning_ignore("integer_division")
			var mins: int = secs / 60
			secs = secs % 60
			val_text = "%d:%02d" % [mins, secs]
		else:
			val = float(entry.get("score", 0))
			val_text = "%d" % int(val)

		var bar := ColorRect.new()
		var ratio: float = val / max_val if max_val > 0.0 else 0.0
		bar.custom_minimum_size = Vector2(24, max(ratio * 120.0, 6.0))
		bar.color = Color(0.3, 0.7, 1.0, 0.9)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.tooltip_text = "%s: %s" % [str(entry.get("username", "?")), val_text]
		bar_container.add_child(bar)

		col.add_child(bar_container)

		var name_lbl := Label.new()
		var uname: String = str(entry.get("username", "?"))
		name_lbl.text = uname.substr(0, 4) if uname.length() > 4 else uname
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_lbl)

		chart_hbox.add_child(col)

## GameMode high score panel
func _populate_gamemode_high_score(panel: Panel, leaderboard: Array, is_time_only: bool) -> void:
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Best Time" if is_time_only else "High Score"
	title.add_theme_color_override("font_color", Color(1, 0.85, 0))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if leaderboard.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Waiting for players..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)
		return

	var top: Dictionary = leaderboard[0]
	var finished: bool = top.get("finished", false)

	var name_lbl := Label.new()
	name_lbl.text = "🏆 %s" % str(top.get("username", "???"))
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var val_lbl := Label.new()
	if finished:
		if is_time_only:
			var time_ms: int = int(top.get("time_taken_ms", 0))
			@warning_ignore("integer_division")
			var secs: int = time_ms / 1000
			@warning_ignore("integer_division")
			var mins: int = secs / 60
			secs = secs % 60
			val_lbl.text = "%d:%02d" % [mins, secs]
		else:
			val_lbl.text = "%d pts" % int(top.get("score", 0))
		val_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5))
	else:
		val_lbl.text = "playing..."
		val_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(val_lbl)

## GameMode rankings panel: top 3
func _populate_gamemode_rankings(panel: Panel, leaderboard: Array, is_time_only: bool) -> void:
	for child in panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Top Rankings"
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	title.add_theme_font_size_override("font_size", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if leaderboard.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No players yet..."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)
		return

	var rank_emojis := ["🥇", "🥈", "🥉"]
	var rank_colors := [Color(1, 0.85, 0), Color(0.78, 0.78, 0.82), Color(0.82, 0.55, 0.2)]
	var top_count: int = min(leaderboard.size(), 3)

	for i in range(top_count):
		var entry: Dictionary = leaderboard[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var rank_lbl := Label.new()
		rank_lbl.text = rank_emojis[i]
		rank_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("username", "???"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", rank_colors[i])
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		var finished: bool = entry.get("finished", false)
		if finished:
			if is_time_only:
				var time_ms: int = int(entry.get("time_taken_ms", 0))
				@warning_ignore("integer_division")
				var secs: int = time_ms / 1000
				@warning_ignore("integer_division")
				var mins: int = secs / 60
				secs = secs % 60
				val_lbl.text = "%d:%02d" % [mins, secs]
			else:
				val_lbl.text = "%d" % int(entry.get("score", 0))
			val_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			val_lbl.text = "..."
			val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		val_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(val_lbl)

		vbox.add_child(row)

# ════════════════════════════════════════════════════════════════════════════
# ROOM HISTORY — FIRESTORE PERSISTENCE
# ════════════════════════════════════════════════════════════════════════════

## Save room to user's Firestore document (called when room is created)
func _save_room_to_history(room_code: String, room_data: Dictionary) -> void:
	if not Auth or not Auth.current_local_id or not Auth.current_id_token:
		push_warning("[RoomHistory] No Auth — cannot save room history")
		return
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	
	var get_url := "%s/users/%s" % [FIRESTORE_BASE_URL, uid]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	
	var http_get := HTTPRequest.new()
	add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		
		if code != 200:
			push_warning("[RoomHistory] Failed to fetch user doc: HTTP %d" % code)
			return
		
		var doc = JSON.parse_string(body.get_string_from_utf8())
		var existing_rooms: Array = []
		
		if typeof(doc) == TYPE_DICTIONARY:
			var fields = doc.get("fields", {})
			if fields.has("room_history") and fields["room_history"].has("arrayValue"):
				var array_val = fields["room_history"]["arrayValue"].get("values", [])
				for item in array_val:
					if item.has("mapValue"):
						var t_code = item["mapValue"].get("fields", {}).get("room_code", {}).get("stringValue", "")
						if t_code != room_code:
							existing_rooms.append(item)
		
		# ✅ FIX: Derive category from room_data, NOT from live button state
		var cats_str: String = str(room_data.get("categories", ""))
		var category := "multiple_choice" if cats_str.contains("Multiple Choice") else "game_mode"
		
		var game_name: String = str(room_data.get("minigame", ""))
		var difficulty: String = str(room_data.get("difficulty", ""))
		var player_count := int(room_data.get("player_count", 10))
		
		var now := Time.get_datetime_dict_from_system(true)
		var timestamp := "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			now.year, now.month, now.day, now.hour, now.minute, now.second
		]
		
		var new_room := {
			"mapValue": {
				"fields": {
					"room_code": {"stringValue": room_code},
					"room_name": {"stringValue": str(room_data.get("name", "Untitled Room"))},
					"category": {"stringValue": category},
					"game_name": {"stringValue": game_name},
					"difficulty": {"stringValue": difficulty},
					"player_count": {"integerValue": str(player_count)},
					"created_at": {"timestampValue": timestamp},
					"status": {"stringValue": room_data.get("status", "active")}
				}
			}
		}
		
		# Save full quiz data string if it's a multiple choice draft
		if category == "multiple_choice" and room_data.has("mc_quiz_data"):
			new_room["mapValue"]["fields"]["mc_quiz_data_json"] = {"stringValue": JSON.stringify(room_data["mc_quiz_data"])}
			if room_data.has("mc_time_per_q"):
				new_room["mapValue"]["fields"]["mc_time_per_q"] = {"integerValue": str(room_data["mc_time_per_q"])}
		
		existing_rooms.insert(0, new_room)
		
		if existing_rooms.size() > 50:
			existing_rooms = existing_rooms.slice(0, 50)
		
		var update_doc := {
			"fields": {
				"room_history": {
					"arrayValue": {
						"values": existing_rooms
					}
				}
			}
		}
		
		var http_patch := HTTPRequest.new()
		add_child(http_patch)
		http_patch.request_completed.connect(func(_r2, code2, _h2, body2):
			http_patch.queue_free()
			if code2 == 200:
				print("[RoomHistory] ✅ Saved room %s to user doc" % room_code)
			else:
				push_warning("[RoomHistory] Failed to save: HTTP %d | %s" % [code2, body2.get_string_from_utf8()])
		)
		
		var patch_url := "%s?updateMask.fieldPaths=room_history" % get_url
		var json_body := JSON.stringify(update_doc)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, json_body)
	)
	
	http_get.request(get_url, headers, HTTPClient.METHOD_GET)

## Mark room as completed in user's Firestore document
func _mark_room_completed(room_code: String) -> void:
	if not Auth or not Auth.current_local_id or not Auth.current_id_token:
		return
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var url := "%s/users/%s" % [FIRESTORE_BASE_URL, uid]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	
	# Fetch current room_history array
	var http_get := HTTPRequest.new()
	add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, body):
		http_get.queue_free()
		
		if code != 200:
			return
		
		var doc = JSON.parse_string(body.get_string_from_utf8())
		if typeof(doc) != TYPE_DICTIONARY:
			return
		
		var fields = doc.get("fields", {})
		if not fields.has("room_history"):
			return
		
		var array_val = fields["room_history"].get("arrayValue", {}).get("values", [])
		var updated := false
		
		# Get proper UTC timestamp
		var now := Time.get_datetime_dict_from_system(true)
		var timestamp := "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			now.year, now.month, now.day, now.hour, now.minute, now.second
		]
		
		# Find and update the room
		for item in array_val:
			if item.has("mapValue"):
				var room_fields = item["mapValue"].get("fields", {})
				if room_fields.has("room_code") and room_fields["room_code"].get("stringValue") == room_code:
					room_fields["status"] = {"stringValue": "completed"}
					room_fields["completed_at"] = {"timestampValue": timestamp}
					updated = true
					break
		
		if not updated:
			return
		
		# Write back updated array
		var update_doc := {
			"fields": {
				"room_history": {
					"arrayValue": {"values": array_val}
				}
			}
		}
		
		var http_patch := HTTPRequest.new()
		add_child(http_patch)
		http_patch.request_completed.connect(func(_r2, code2, _h2, _b2):
			http_patch.queue_free()
			if code2 == 200:
				print("[RoomHistory] ✅ Marked room %s as completed" % room_code)
		)
		
		var patch_url := "%s?updateMask.fieldPaths=room_history" % url
		var json_body := JSON.stringify(update_doc)
		http_patch.request(patch_url, headers, HTTPClient.METHOD_PATCH, json_body)
	)
	
	http_get.request(url, headers, HTTPClient.METHOD_GET)

## Load all rooms from user's Firestore document
func _load_room_history() -> void:
	if not Auth or not Auth.current_local_id or not Auth.current_id_token:
		push_warning("[RoomHistory] No Auth — cannot load room history")
		return
	
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var url := "%s/users/%s" % [FIRESTORE_BASE_URL, uid]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	
	if not _history_http:
		_history_http = HTTPRequest.new()
		add_child(_history_http)
	
	if _history_http.request_completed.is_connected(_on_room_history_loaded):
		_history_http.request_completed.disconnect(_on_room_history_loaded)
	_history_http.request_completed.connect(_on_room_history_loaded)
	
	_history_http.request(url, headers, HTTPClient.METHOD_GET)
	
	print("[RoomHistory] 🔄 Loading room history from user doc: %s" % uid)

func _on_room_history_loaded(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _history_http and _history_http.request_completed.is_connected(_on_room_history_loaded):
		_history_http.request_completed.disconnect(_on_room_history_loaded)
	
	if code != 200:
		push_warning("[RoomHistory] Failed to load history: HTTP %d" % code)
		return
	
	var text := body.get_string_from_utf8()
	var doc = JSON.parse_string(text)
	
	if typeof(doc) != TYPE_DICTIONARY:
		push_warning("[RoomHistory] Unexpected response format")
		return
	
	room_history.clear()
	
	# Extract room_history array from user document
	var fields: Dictionary = doc.get("fields", {})
	if not fields.has("room_history"):
		print("[RoomHistory] No room_history field in user doc")
		_refresh_room_list()
		return
	
	var array_val = fields["room_history"].get("arrayValue", {}).get("values", [])
	
	for item in array_val:
		if not item.has("mapValue"):
			continue
		
		var room_fields: Dictionary = item["mapValue"].get("fields", {})
		
		var history_item := {
			"room_code": str(room_fields.get("room_code", {}).get("stringValue", "")),
			"room_name": str(room_fields.get("room_name", {}).get("stringValue", "Untitled")),
			"category": str(room_fields.get("category", {}).get("stringValue", "game_mode")),
			"game_name": str(room_fields.get("game_name", {}).get("stringValue", "")),
			"difficulty": str(room_fields.get("difficulty", {}).get("stringValue", "")),
			"player_count": int(room_fields.get("player_count", {}).get("integerValue", "10")),
			"status": str(room_fields.get("status", {}).get("stringValue", "active")),
			"created_at": str(room_fields.get("created_at", {}).get("timestampValue", ""))
		}
		
		room_history.append(history_item)
	
	print("[RoomHistory] ✅ Loaded %d rooms from user doc" % room_history.size())
	_refresh_room_list()

# ════════════════════════════════════════════════════════════════════════════
# QUIZ RESULTS — FIRESTORE CACHE (stored in user doc field "room_results")
# ════════════════════════════════════════════════════════════════════════════

## Save quiz/gamemode results to the user doc's "room_results" map field.
## Path: users/{uid}.room_results.{safe_code} = JSON string
func _save_results_to_firestore(room_code: String, data: Dictionary) -> void:
	if not Auth or not Auth.current_local_id or not Auth.current_id_token:
		return
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var safe_code := room_code.replace("/", "_")
	var field_path := "room_results.`%s`" % safe_code
	var url := "%s/users/%s?updateMask.fieldPaths=%s" % [FIRESTORE_BASE_URL, uid, field_path]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	# Serialize the entire results dict as a JSON string value
	var json_str := JSON.stringify(data)
	var doc := {
		"fields": {
			"room_results": {
				"mapValue": {
					"fields": {
						safe_code: {"stringValue": json_str}
					}
				}
			}
		}
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[ResultsCache] ✅ Saved results for %s" % room_code)
		else:
			push_warning("[ResultsCache] Failed to save results for %s: HTTP %d" % [room_code, code])
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(doc))

## Load quiz/gamemode results from user doc's "room_results" map field
func _load_results_from_firestore(room_code: String, category: String) -> void:
	if not Auth or not Auth.current_local_id or not Auth.current_id_token:
		return
	var uid := Auth.current_local_id
	var token := Auth.current_id_token
	var url := "%s/users/%s" % [FIRESTORE_BASE_URL, uid]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			print("[ResultsCache] Failed to read user doc: HTTP %d" % code)
			return
		var text: String = resp_body.get_string_from_utf8()
		var doc = JSON.parse_string(text)
		if typeof(doc) != TYPE_DICTIONARY: return
		var fields: Dictionary = doc.get("fields", {})
		if not fields.has("room_results"): return
		var results_map: Dictionary = fields["room_results"].get("mapValue", {}).get("fields", {})
		var safe_code := room_code.replace("/", "_")
		if not results_map.has(safe_code): return
		var json_str: String = results_map[safe_code].get("stringValue", "")
		if json_str.is_empty(): return
		var data = JSON.parse_string(json_str)
		if typeof(data) != TYPE_DICTIONARY: return
		print("[ResultsCache] ✅ Loaded cached results for %s" % room_code)
		_cached_results_by_room[room_code] = data
		# Only update if still viewing this room
		if _viewing_room_code == room_code:
			if category == "multiple_choice":
				_update_stats_leaderboard(data)
			elif category == "game_mode":
				_update_gamemode_leaderboard(data)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _utc_now() -> String:
	var now := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second
	]
