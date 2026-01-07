# AkashicTCGTutorialArena.gd
# Tutorial version of the arena - EXACT COPY with AI opponent instead of real player
# Uses same cards, effects, animations, sounds as the real arena
extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")
const _CardView = preload("res://script/AkashicTCGCardView.gd")

# Tutorial guide reference
var tutorial_guide: CanvasLayer = null
var tutorial_completed := false
var match_started := false
var in_tutorial_phase := true

# AI opponent variables
var ai_timer: Timer = null
var ai_turn_delay := 2.0

# ===== SAME UI REFERENCES AS REAL ARENA =====
@onready var _status: Label = $HUD/StatusLabel
@onready var _opp_si_bar: ProgressBar = $HUD/OpponentBars/OppSIBar
@onready var _opp_fw_bar: ProgressBar = $HUD/OpponentBars/OppFWBar
@onready var _opp_resource_label: Label = $HUD/OpponentBars/OppResourceLabel
@onready var _opp_hand_hbox: HBoxContainer = $HUD/OppHandArea/OppHandHBox
@onready var _you_si_bar: ProgressBar = $HUD/PlayerBars/YouSIBar
@onready var _you_fw_bar: ProgressBar = $HUD/PlayerBars/YouFWBar
@onready var _resource_label: Label = $HUD/PlayerBars/ResourceLabel
@onready var _drop_timer_label: Label = $HUD/PlayerBars/YouSIBar/DropTimerLabel
@onready var _sidebar_opp_name: Label = $HUD/Sidebar/OppName
@onready var _sidebar_you_name: Label = $HUD/Sidebar/YouName
@onready var _timer_label: Label = $HUD/Sidebar/TimerLabel
@onready var _countdown_label: Label = $HUD/CountdownLabel
@onready var _round_label: Label = $HUD/RoundLabel
@onready var _end_turn_btn: Button = $HUD/PlayerBars/EndTurnButton
@onready var _play_zone: Panel = $HUD/Table/PlayZone
@onready var _hand_hbox: HBoxContainer = $HUD/HandArea/HandHBox
@onready var _menu_btn: Button = $MenuButton

@onready var _opp_dropped_cards: Array[TextureRect] = [
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/OppDroppedRow/OppDropped1,
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/OppDroppedRow/OppDropped2,
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/OppDroppedRow/OppDropped3,
]
@onready var _you_dropped_cards: Array[TextureRect] = [
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/YouDroppedRow/YouDropped1,
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/YouDroppedRow/YouDropped2,
	$HUD/Table/PlayZone/ZoneVBox/DroppedCards/YouDroppedRow/YouDropped3,
]

# ===== SAME CONSTANTS AS REAL ARENA =====
const STARTING_SI := 20
const MAX_FW := 12
const START_HAND := 3
const HAND_LIMIT := 7
const PLAYS_PER_TURN := 3
const MAX_BW := 10
const CARD_VIEW_SIZE := Vector2(110, 160)
const HAND_CARD_VIEW_SIZE := Vector2(140, 200)
const FLIP_HALF_SEC := 0.12

var _flip_tweens: Dictionary = {}

# ===== SAME CARD TEXTURES AS REAL ARENA =====
const _TEX := {
	"virus": preload("res://asset/cards for AkashicTGC/virus card 2.png"),
	"trojan": preload("res://asset/cards for AkashicTGC/Trojan horse card 2.png"),
	"phishing": preload("res://asset/cards for AkashicTGC/phising card 1.png"),
	"dos": preload("res://asset/cards for AkashicTGC/DOS card 1.png"),
	"ddos": preload("res://asset/cards for AkashicTGC/DDOS card 1.png"),
	"mfa": preload("res://asset/cards for AkashicTGC/Multi fartor auth card 2.png"),
	"ids": preload("res://asset/cards for AkashicTGC/intrusion detection card 2.png"),
	"encryption": preload("res://asset/cards for AkashicTGC/encryption key card 2.png"),
	"antivirus": preload("res://asset/cards for AkashicTGC/anti virus core card 2.png"),
	"firewall": preload("res://asset/cards for AkashicTGC/firewall shield 3.png"),
}
const _BACK_TEX: Texture2D = preload("res://asset/cards for AkashicTGC/back cards.png")

# ===== SAME SFX AS REAL ARENA =====
const _SFX_CARD_DROP: AudioStream = preload("res://asset/audio/akashic sfx/card drop sound effect.wav")
const _SFX_CARD_REVEAL: AudioStream = preload("res://asset/audio/akashic sfx/card reveal sound effect.wav")
const _SFX_VICTORY: AudioStream = preload("res://asset/audio/akashic sfx/player victory.wav")
const _SFX_DEFEAT: AudioStream = preload("res://asset/audio/akashic sfx/player defeat.wav")
const _SFX_ROUND_PATH := "res://asset/audio/akashic sfx/round_sound effect.mp3"

var _sfx_drop_player: AudioStreamPlayer = null
var _sfx_reveal_player: AudioStreamPlayer = null
var _sfx_result_player: AudioStreamPlayer = null
var _round_sfx_stream: AudioStream = null
var _sfx_round_player: AudioStreamPlayer = null

enum CardType {ATTACK, DEFENSE}

# ===== SAME CARD DATABASE AS REAL ARENA =====
const _CARD_DB := {
	# Defense cards
	"mfa": {"name": "MULTI-FACTOR AUTH", "type": CardType.DEFENSE, "cost": 3, "desc": "Block next Phishing/Trojan"},
	"antivirus": {"name": "ANTIVIRUS CORE", "type": CardType.DEFENSE, "cost": 3, "desc": "Remove active virus effects"},
	"encryption": {"name": "ENCRYPTION KEY", "type": CardType.DEFENSE, "cost": 3, "desc": "Reduce next attack damage"},
	"firewall": {"name": "FIREWALL SHIELD", "type": CardType.DEFENSE, "cost": 2, "desc": "Restore 3 Firewall"},
	"ids": {"name": "INTRUSION DETECTION", "type": CardType.DEFENSE, "cost": 2, "desc": "Reduce damage, draw 2"},
	# Attack cards
	"phishing": {"name": "PHISHING", "type": CardType.ATTACK, "cost": 1, "base_damage": 2, "desc": "Deal 2 damage"},
	"dos": {"name": "DOS", "type": CardType.ATTACK, "cost": 2, "base_damage": 4, "desc": "Deal 4 damage"},
	"ddos": {"name": "DDOS", "type": CardType.ATTACK, "cost": 4, "base_damage": 8, "desc": "Deal 8 damage"},
	"virus": {"name": "VIRUS", "type": CardType.ATTACK, "cost": 2, "base_damage": 1, "desc": "Deal 1+ongoing damage"},
	"trojan": {"name": "TROJAN HORSE", "type": CardType.ATTACK, "cost": 3, "base_damage": 3, "desc": "Deal 3 damage, steal BW"},
}

# Game state
var player_si := STARTING_SI
var player_fw := MAX_FW
var ai_si := 15 # ⚠️ TUTORIAL: AI starts with only 15 SI (easier win)
var ai_fw := 2 # ⚠️ TUTORIAL: AI has weak firewall
var player_bw := 2
var player_max_bw := 10
var ai_bw := 2
var player_plays := 0
var ai_plays := 0
var current_round := 1
var is_player_turn := true

# Round done flags for simultaneous submission
var player_round_done := false
var ai_round_done := false
var resolve_in_progress := false

# Card data
var player_hand: Array = []
var ai_hand: Array = []
var player_dropped: Array = [null, null, null]
var ai_dropped: Array = [null, null, null]

var _match_start_msec: int = 0
var _match_timer: Timer = null
var _card_id_counter := 0

signal match_completed(player_won: bool)

func _ready() -> void:
	print("[TutorialArena] Tutorial Arena ready - using real arena assets")
	
	# Hide menu for tutorial
	if _menu_btn:
		_menu_btn.visible = false
	
	# Set names
	if _sidebar_opp_name:
		_sidebar_opp_name.text = "CYBER BOT"
	if _sidebar_you_name:
		var username = Auth.current_username if Auth and Auth.current_username != "" else "Player"
		_sidebar_you_name.text = username.to_upper()
	
	# Setup end turn button
	if _end_turn_btn:
		_end_turn_btn.pressed.connect(_on_end_turn_pressed)
		_end_turn_btn.disabled = true
	
	# Setup dropped card slots for click-to-play
	_setup_dropped_slots()
	
	# Setup play zone for drag & drop
	if _play_zone:
		_play_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Load round SFX
	var loaded: Variant = load(_SFX_ROUND_PATH)
	if loaded != null and loaded is AudioStream:
		_round_sfx_stream = loaded as AudioStream
	
	# Initialize SFX players
	_ensure_sfx_players()
	
	# Initialize game state
	_update_ui()
	
	# Load tutorial guide first
	_load_tutorial_guide()

func _setup_dropped_slots() -> void:
	for slot in _you_dropped_cards:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.custom_minimum_size = CARD_VIEW_SIZE
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for slot in _opp_dropped_cards:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.custom_minimum_size = CARD_VIEW_SIZE
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _ensure_sfx_players() -> void:
	if _sfx_drop_player == null:
		_sfx_drop_player = AudioStreamPlayer.new()
		_sfx_drop_player.volume_db = -4.0
		add_child(_sfx_drop_player)
	if _sfx_reveal_player == null:
		_sfx_reveal_player = AudioStreamPlayer.new()
		_sfx_reveal_player.volume_db = -9.0
		add_child(_sfx_reveal_player)
	if _sfx_result_player == null:
		_sfx_result_player = AudioStreamPlayer.new()
		_sfx_result_player.volume_db = -6.0
		add_child(_sfx_result_player)
	if _sfx_round_player == null:
		_sfx_round_player = AudioStreamPlayer.new()
		_sfx_round_player.volume_db = -8.0
		add_child(_sfx_round_player)

func _play_drop_sfx() -> void:
	if _sfx_drop_player:
		_sfx_drop_player.stream = _SFX_CARD_DROP
		_sfx_drop_player.play()

func _play_reveal_sfx() -> void:
	if _sfx_reveal_player:
		_sfx_reveal_player.stream = _SFX_CARD_REVEAL
		_sfx_reveal_player.play()

func _play_round_sfx() -> void:
	if _sfx_round_player and _round_sfx_stream:
		_sfx_round_player.stream = _round_sfx_stream
		_sfx_round_player.play()

func _load_tutorial_guide() -> void:
	var guide_scene = load("res://scene/akashic_tcg_tutorial_guide.tscn")
	if guide_scene:
		tutorial_guide = guide_scene.instantiate()
		add_child(tutorial_guide)
		
		# Connect signals
		tutorial_guide.tutorial_completed.connect(_on_tutorial_completed)
		tutorial_guide.tutorial_skipped.connect(_on_tutorial_skipped)
		tutorial_guide.start_friendly_match.connect(_on_start_friendly_match)
		
		# Start tutorial with arena reference
		var username = Auth.current_username if Auth and Auth.current_username != "" else "Player"
		tutorial_guide.start_tutorial(self, username)
	else:
		push_error("[TutorialArena] Could not load tutorial guide scene")
		_start_match()

func _on_tutorial_completed() -> void:
	print("[TutorialArena] Tutorial explanation completed!")
	tutorial_completed = true
	in_tutorial_phase = false

func _on_tutorial_skipped() -> void:
	print("[TutorialArena] Tutorial skipped!")
	tutorial_completed = true
	in_tutorial_phase = false
	_start_match()

func _on_start_friendly_match() -> void:
	print("[TutorialArena] Starting friendly match!")
	in_tutorial_phase = false
	_start_match()

func _start_match() -> void:
	match_started = true
	_match_start_msec = Time.get_ticks_msec()
	
	# Setup match timer
	_match_timer = Timer.new()
	_match_timer.wait_time = 0.25
	_match_timer.timeout.connect(_on_match_timer_tick)
	add_child(_match_timer)
	_match_timer.start()
	
	# Setup AI turn timer
	ai_timer = Timer.new()
	ai_timer.wait_time = ai_turn_delay
	ai_timer.one_shot = true
	add_child(ai_timer)
	ai_timer.timeout.connect(_on_ai_turn)
	
	# Run countdown
	_run_start_countdown()

func _run_start_countdown() -> void:
	if _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	
	if _countdown_label:
		_countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	
	if _countdown_label:
		_countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	
	if _countdown_label:
		_countdown_label.text = "START!"
	await get_tree().create_timer(0.7).timeout
	
	if _countdown_label:
		_countdown_label.visible = false
	
	# Generate initial hands
	_generate_player_hand()
	_generate_ai_hand()
	
	_end_turn_btn.disabled = false
	_status.text = "Your Turn - Play cards!"
	_play_round_sfx()
	_show_round_banner()
	_update_ui()

func _on_match_timer_tick() -> void:
	if not match_started:
		return
	var elapsed_msec: int = maxi(0, Time.get_ticks_msec() - _match_start_msec)
	var elapsed_sec: int = int(elapsed_msec / 1000.0)
	_set_timer_display(elapsed_sec)

func _set_timer_display(total_seconds: int) -> void:
	if _timer_label == null:
		return
	var s: int = maxi(0, total_seconds)
	var m: int = int(s / 60.0)
	var sec: int = s % 60
	_timer_label.text = "%02d\n..\n%02d" % [m, sec]

func _show_round_banner() -> void:
	if _round_label:
		_round_label.visible = true
		_round_label.text = "ROUND %d" % current_round
		_round_label.modulate = Color(1, 1, 1, 1)
		_round_label.scale = Vector2(0.8, 0.8)
		
		var tween = create_tween()
		tween.tween_property(_round_label, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(_round_label, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_interval(1.0)
		tween.tween_property(_round_label, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): _round_label.visible = false)

func _generate_player_hand() -> void:
	player_hand.clear()
	for child in _hand_hbox.get_children():
		child.queue_free()
	
	# Give player 3 starting cards (same as real game)
	var card_types = _CARD_DB.keys()
	for i in range(START_HAND):
		var card_id = card_types[randi() % card_types.size()]
		_add_card_to_player_hand(card_id)

func _generate_ai_hand() -> void:
	ai_hand.clear()
	var card_types = _CARD_DB.keys()
	for i in range(START_HAND):
		var card_id = card_types[randi() % card_types.size()]
		var card_data = _CARD_DB[card_id].duplicate()
		card_data["card_id"] = card_id
		card_data["unique_id"] = _get_unique_card_id()
		ai_hand.append(card_data)
	_render_ai_hand()

func _get_unique_card_id() -> int:
	_card_id_counter += 1
	return _card_id_counter

func _add_card_to_player_hand(card_id: String) -> void:
	var card_data = _CARD_DB[card_id].duplicate()
	card_data["card_id"] = card_id
	card_data["unique_id"] = _get_unique_card_id()
	card_data["hand_index"] = player_hand.size()
	player_hand.append(card_data)
	_create_hand_card_ui(card_data)

func _create_hand_card_ui(card_data: Dictionary) -> void:
	var card_id: String = card_data["card_id"]
	
	# Use the same CardView as real arena
	var card_view = _CardView.new()
	card_view.custom_minimum_size = HAND_CARD_VIEW_SIZE
	card_view.texture = _TEX.get(card_id, _BACK_TEX)
	card_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_view.stretch_mode = TextureRect.STRETCH_SCALE
	card_view.card_data = card_data
	card_view.drag_enabled = true
	card_view.click_enabled = true
	card_view.hover_sfx_enabled = true
	
	# Connect signals
	card_view.card_clicked.connect(_on_hand_card_clicked)
	
	# Connect hover signals for description
	card_view.mouse_entered.connect(func(): _show_card_info(card_data))
	card_view.mouse_exited.connect(_hide_card_info)
	
	_hand_hbox.add_child(card_view)

# Card Info Panel
var _card_info_panel: Panel = null
var _info_name_label: Label = null
var _info_cost_label: Label = null
var _info_type_label: Label = null
var _info_desc_label: Label = null

func _setup_card_info_panel() -> void:
	if _card_info_panel: return
	
	_card_info_panel = Panel.new()
	_card_info_panel.name = "CardInfoPanel"
	_card_info_panel.custom_minimum_size = Vector2(200, 150)
	_card_info_panel.visible = false
	_card_info_panel.z_index = 100 # High z-index to show on top
	_card_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0.8, 1, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_card_info_panel.add_theme_stylebox_override("panel", style)
	
	add_child(_card_info_panel)
	
	var vbox = VBoxContainer.new()
	_card_info_panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	
	# Header (Name + Cost)
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	_info_name_label = Label.new()
	_info_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name_label.add_theme_font_size_override("font_size", 16)
	_info_name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Gold
	hbox.add_child(_info_name_label)
	
	_info_cost_label = Label.new()
	_info_cost_label.add_theme_font_size_override("font_size", 16)
	_info_cost_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1)) # Cyan
	hbox.add_child(_info_cost_label)
	
	# Type
	_info_type_label = Label.new()
	_info_type_label.add_theme_font_size_override("font_size", 12)
	_info_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_info_type_label)
	
	vbox.add_child(HSeparator.new())
	
	# Description
	_info_desc_label = Label.new()
	_info_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_desc_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_info_desc_label)

func _show_card_info(card_data: Dictionary) -> void:
	if not _card_info_panel: _setup_card_info_panel()
	
	var card_id = card_data["card_id"]
	var info = _CARD_DB[card_id]
	
	_info_name_label.text = info["name"]
	_info_cost_label.text = "Cost: %d" % info["cost"]
	_info_type_label.text = "Type: %s" % ("ATTACK" if info["type"] == CardType.ATTACK else "DEFENSE")
	_info_desc_label.text = info["desc"]
	
	# Position near mouse but offset
	var mouse_pos = get_global_mouse_position()
	_card_info_panel.global_position = mouse_pos + Vector2(20, -180)
	
	# Keep on screen
	var viewport_size = get_viewport_rect().size
	if _card_info_panel.global_position.x + _card_info_panel.size.x > viewport_size.x:
		_card_info_panel.global_position.x = mouse_pos.x - _card_info_panel.size.x - 20
	
	_card_info_panel.visible = true

func _hide_card_info() -> void:
	if _card_info_panel:
		_card_info_panel.visible = false

func _render_ai_hand() -> void:
	# Clear existing AI hand display
	for child in _opp_hand_hbox.get_children():
		child.queue_free()
	
	# Show card backs for AI hand
	for i in range(ai_hand.size()):
		var card_back = TextureRect.new()
		card_back.custom_minimum_size = CARD_VIEW_SIZE
		card_back.texture = _BACK_TEX
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_SCALE
		_opp_hand_hbox.add_child(card_back)

func _on_hand_card_clicked(card_data: Dictionary) -> void:
	if not match_started or not is_player_turn:
		return
	
	if in_tutorial_phase:
		return
	
	_play_card(card_data)

func _play_card(card_data: Dictionary) -> void:
	if player_round_done or resolve_in_progress:
		return
	
	var card_id: String = card_data["card_id"]
	var card_info = _CARD_DB[card_id]
	var cost: int = card_info["cost"]
	
	# Check cost
	if cost > player_bw:
		_status.text = "Not enough bandwidth!"
		return
	
	# Check plays limit
	if player_plays >= PLAYS_PER_TURN:
		_status.text = "No more plays this turn!"
		return
	
	# Find empty slot
	var slot_idx = -1
	for i in range(player_dropped.size()):
		if player_dropped[i] == null:
			slot_idx = i
			break
	
	if slot_idx == -1:
		_status.text = "Play zone full!"
		return
	
	# Pay cost and play
	player_bw -= cost
	player_plays += 1
	player_dropped[slot_idx] = card_data
	
	# Remove from hand
	_remove_card_from_hand(card_data)
	
	# Show card FACE DOWN (back of card) - no reveal yet!
	_show_card_face_down(slot_idx, true)
	_play_drop_sfx()
	
	_update_ui()
	
	# Check if player can still play more cards
	_check_player_auto_done()

func _remove_card_from_hand(card_data: Dictionary) -> void:
	var unique_id = card_data["unique_id"]
	for i in range(player_hand.size()):
		if player_hand[i]["unique_id"] == unique_id:
			player_hand.remove_at(i)
			break
	
	# Refresh hand UI
	for child in _hand_hbox.get_children():
		child.queue_free()
	for card in player_hand:
		_create_hand_card_ui(card)

func _animate_card_to_slot(card_id: String, slot_idx: int, is_player: bool) -> void:
	var slots = _you_dropped_cards if is_player else _opp_dropped_cards
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	
	var slot = slots[slot_idx]
	if slot == null:
		return
	
	if is_player:
		# Player cards show immediately with animation
		slot.texture = _TEX.get(card_id, _BACK_TEX)
		slot.modulate = Color(1, 1, 1, 0)
		slot.scale = Vector2(0.7, 0.7)
		slot.pivot_offset = slot.size * 0.5
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(slot, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.08)
	else:
		# AI cards show back first, then flip reveal
		slot.texture = _BACK_TEX
		slot.modulate = Color(1, 1, 1, 0)
		slot.scale = Vector2(0.7, 0.7)
		slot.pivot_offset = slot.size * 0.5
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(slot, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.08)
		# Flip to reveal after a delay
		tween.tween_callback(func(): _flip_reveal(slot, _TEX.get(card_id, _BACK_TEX), _CARD_DB.get(card_id, {}).get("name", "")))

# Flip card reveal animation (same as real arena)
func _flip_reveal(node: TextureRect, new_texture: Texture2D, new_tooltip: String) -> void:
	if node == null:
		return
	if _flip_tweens.has(node):
		var old_tw: Variant = _flip_tweens.get(node)
		if old_tw is Tween and is_instance_valid(old_tw):
			(old_tw as Tween).kill()
		_flip_tweens.erase(node)
	
	# Ensure we have a "back" visible before flipping
	if node.texture == null:
		node.texture = _BACK_TEX
	
	# Flip around center
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1, 1)
	
	var tw := create_tween()
	_flip_tweens[node] = tw
	tw.tween_property(node, "scale:x", 0.0, FLIP_HALF_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		node.texture = new_texture
		node.tooltip_text = new_tooltip
	)
	tw.tween_property(node, "scale:x", 1.0, FLIP_HALF_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		if _flip_tweens.get(node) == tw:
			_flip_tweens.erase(node)
	)
	_play_reveal_sfx()

# Show card face down (back of card visible)
func _show_card_face_down(slot_idx: int, is_player: bool) -> void:
	var slots = _you_dropped_cards if is_player else _opp_dropped_cards
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	
	var slot = slots[slot_idx]
	if slot == null:
		return
	
	slot.texture = _BACK_TEX
	slot.modulate = Color(1, 1, 1, 0)
	slot.scale = Vector2(0.7, 0.7)
	slot.pivot_offset = slot.size * 0.5
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(slot, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.08)

# Check if player can afford to play more cards
func _check_player_auto_done() -> void:
	if player_round_done:
		return
	
	# Auto-done if: max plays reached, or no affordable cards, or hand empty
	if player_plays >= PLAYS_PER_TURN:
		_mark_player_done()
		return
	
	# Check if any card in hand is affordable
	var can_play_any := false
	for card in player_hand:
		var card_id = card["card_id"]
		var cost = _CARD_DB[card_id]["cost"]
		if cost <= player_bw:
			can_play_any = true
			break
	
	if not can_play_any:
		_mark_player_done()

func _mark_player_done() -> void:
	if player_round_done:
		return
	player_round_done = true
	_end_turn_btn.disabled = true
	_status.text = "Waiting for AI..."
	
	# AI also submits their cards now
	_ai_submit_cards()

func _ai_submit_cards() -> void:
	if ai_round_done:
		_try_resolve_round()
		return
	
	# AI plays 1-2 cards face-down
	var cards_to_play = mini(2, ai_hand.size())
	
	for _i in range(cards_to_play):
		if ai_hand.is_empty() or ai_bw <= 0 or ai_plays >= PLAYS_PER_TURN:
			break
		
		# Find a card AI can afford
		var playable_idx = -1
		for j in range(ai_hand.size()):
			var check_card = ai_hand[j]
			var check_cost = _CARD_DB[check_card["card_id"]]["cost"]
			if check_cost <= ai_bw:
				playable_idx = j
				break
		
		if playable_idx == -1:
			break
		
		var played_card = ai_hand[playable_idx]
		var card_id = played_card["card_id"]
		var card_cost = _CARD_DB[card_id]["cost"]
		
		# Find slot
		var slot_idx = -1
		for k in range(ai_dropped.size()):
			if ai_dropped[k] == null:
				slot_idx = k
				break
		
		if slot_idx == -1:
			break
		
		# Pay and play (face down)
		ai_bw -= card_cost
		ai_plays += 1
		ai_dropped[slot_idx] = played_card
		ai_hand.remove_at(playable_idx)
		
		# Show face down
		_show_card_face_down(slot_idx, false)
		_play_drop_sfx()
		
		await get_tree().create_timer(0.3).timeout
	
	ai_round_done = true
	_render_ai_hand()
	_update_ui()
	
	# Both done - resolve!
	_try_resolve_round()

func _try_resolve_round() -> void:
	if not player_round_done or not ai_round_done:
		return
	if resolve_in_progress:
		return
	
	resolve_in_progress = true
	_status.text = "Revealing cards..."
	
	await get_tree().create_timer(0.5).timeout
	
	# Reveal all cards with flip animation
	await _resolve_all_cards()

func _resolve_all_cards() -> void:
	# First reveal player cards
	for i in range(player_dropped.size()):
		var card_data = player_dropped[i]
		if card_data != null:
			var card_id = card_data["card_id"]
			var card_name = _CARD_DB.get(card_id, {}).get("name", "")
			_flip_reveal(_you_dropped_cards[i], _TEX.get(card_id, _BACK_TEX), card_name)
			await get_tree().create_timer(0.3).timeout
	
	# Then reveal AI cards
	for i in range(ai_dropped.size()):
		var card_data = ai_dropped[i]
		if card_data != null:
			var card_id = card_data["card_id"]
			var card_name = _CARD_DB.get(card_id, {}).get("name", "")
			_flip_reveal(_opp_dropped_cards[i], _TEX.get(card_id, _BACK_TEX), card_name)
			await get_tree().create_timer(0.3).timeout
	
	await get_tree().create_timer(0.5).timeout
	
	# Apply all effects (player first, then AI)
	for i in range(player_dropped.size()):
		var card_data = player_dropped[i]
		if card_data != null:
			_apply_card_effect(card_data["card_id"], true)
			_update_ui()
			await get_tree().create_timer(0.4).timeout
	
	for i in range(ai_dropped.size()):
		var card_data = ai_dropped[i]
		if card_data != null:
			_apply_card_effect(card_data["card_id"], false)
			_update_ui()
			await get_tree().create_timer(0.4).timeout
	
	_check_win_condition()
	
	if match_started:
		await get_tree().create_timer(0.5).timeout
		_start_new_round()

func _start_new_round() -> void:
	current_round += 1
	
	# BW gain per round (matching real arena)
	var gain: int = 2
	if current_round >= 11:
		gain = 5
	elif current_round >= 7:
		gain = 4
	elif current_round >= 3:
		gain = 3
	
	player_bw = mini(player_bw + gain, MAX_BW)
	ai_bw = mini(ai_bw + gain, MAX_BW)
	
	# Reset round state
	player_plays = 0
	ai_plays = 0
	player_round_done = false
	ai_round_done = false
	resolve_in_progress = false
	
	# Clear dropped zones
	_clear_dropped_zones()
	
	# Draw cards
	if player_hand.size() < HAND_LIMIT:
		var card_types = _CARD_DB.keys()
		var card_id = card_types[randi() % card_types.size()]
		_add_card_to_player_hand(card_id)
	
	if ai_hand.size() < HAND_LIMIT:
		var card_types = _CARD_DB.keys()
		var card_id = card_types[randi() % card_types.size()]
		var card_data = _CARD_DB[card_id].duplicate()
		card_data["card_id"] = card_id
		card_data["unique_id"] = _get_unique_card_id()
		ai_hand.append(card_data)
	
	_render_ai_hand()
	_end_turn_btn.disabled = false
	_status.text = "Round %d - Your Turn!" % current_round
	_play_round_sfx()
	_show_round_banner()
	_update_ui()

func _apply_card_effect(card_id: String, is_player: bool) -> void:
	var card_info = _CARD_DB[card_id]
	var card_type = card_info["type"]
	
	if card_type == CardType.ATTACK:
		var damage: int = card_info.get("base_damage", 0)
		if is_player:
			# Player attacks AI - BONUS DAMAGE for tutorial!
			damage = damage * 2 # Double player damage!
			if ai_fw > 0:
				var fw_dmg = mini(damage, ai_fw)
				ai_fw -= fw_dmg
				damage -= fw_dmg
			if damage > 0:
				ai_si = maxi(0, ai_si - damage)
			_status.text = "%s dealt %d damage!" % [card_info["name"], card_info["base_damage"] * 2]
		else:
			# AI attacks player - REDUCED DAMAGE for tutorial!
			damage = maxi(1, int(float(damage) / 2.0)) # Halve AI damage (minimum 1)
			if player_fw > 0:
				var fw_dmg = mini(damage, player_fw)
				player_fw -= fw_dmg
				damage -= fw_dmg
			if damage > 0:
				player_si = maxi(0, player_si - damage)
			_status.text = "AI used %s!" % card_info["name"]
	
	elif card_type == CardType.DEFENSE:
		if card_id == "firewall":
			if is_player:
				player_fw = mini(MAX_FW, player_fw + 3)
				_status.text = "Firewall restored!"
			else:
				ai_fw = mini(MAX_FW, ai_fw + 3)
				_status.text = "AI restored firewall!"
		else:
			_status.text = "%s activated!" % card_info["name"]

func _on_end_turn_pressed() -> void:
	if not match_started:
		return
	
	if in_tutorial_phase:
		return
	
	if player_round_done or resolve_in_progress:
		return
	
	# Player manually ends their turn - mark as done
	_mark_player_done()

func _clear_dropped_zones() -> void:
	for i in range(player_dropped.size()):
		player_dropped[i] = null
		if i < _you_dropped_cards.size() and _you_dropped_cards[i]:
			_you_dropped_cards[i].texture = null
	for i in range(ai_dropped.size()):
		ai_dropped[i] = null
		if i < _opp_dropped_cards.size() and _opp_dropped_cards[i]:
			_opp_dropped_cards[i].texture = null

func _on_ai_turn() -> void:
	if ai_hand.is_empty():
		_end_ai_turn()
		return
	
	# AI plays 1-2 cards
	var cards_to_play = mini(2, ai_hand.size())
	
	for _i in range(cards_to_play):
		if ai_hand.is_empty() or ai_bw <= 0:
			break
		
		# Find a card AI can afford
		var playable_idx = -1
		for j in range(ai_hand.size()):
			var check_card = ai_hand[j]
			var check_cost = _CARD_DB[check_card["card_id"]]["cost"]
			if check_cost <= ai_bw:
				playable_idx = j
				break
		
		if playable_idx == -1:
			break
		
		var played_card = ai_hand[playable_idx]
		var card_id = played_card["card_id"]
		var card_cost = _CARD_DB[card_id]["cost"]
		
		# Find slot
		var slot_idx = -1
		for k in range(ai_dropped.size()):
			if ai_dropped[k] == null:
				slot_idx = k
				break
		
		if slot_idx == -1:
			break
		
		# Pay and play
		ai_bw -= card_cost
		ai_dropped[slot_idx] = played_card
		ai_hand.remove_at(playable_idx)
		
		# Animate and apply
		_animate_card_to_slot(card_id, slot_idx, false)
		_play_reveal_sfx()
		await get_tree().create_timer(0.5).timeout
		_apply_card_effect(card_id, false)
		_update_ui()
		
		await get_tree().create_timer(0.8).timeout
	
	_check_win_condition()
	
	if match_started:
		await get_tree().create_timer(0.5).timeout
		_end_ai_turn()

func _end_ai_turn() -> void:
	current_round += 1
	
	# BW gain per round (matching real arena)
	# Round 1-2: +2, 3-6: +3, 7-10: +4, 11+: +5. Cap at MAX_BW.
	var gain: int = 2
	if current_round >= 11:
		gain = 5
	elif current_round >= 7:
		gain = 4
	elif current_round >= 3:
		gain = 3
	
	player_bw = mini(player_bw + gain, MAX_BW)
	ai_bw = mini(ai_bw + gain, MAX_BW)
	player_plays = 0
	
	# Draw cards
	if player_hand.size() < HAND_LIMIT:
		var card_types = _CARD_DB.keys()
		var card_id = card_types[randi() % card_types.size()]
		_add_card_to_player_hand(card_id)
	
	if ai_hand.size() < HAND_LIMIT:
		var card_types = _CARD_DB.keys()
		var card_id = card_types[randi() % card_types.size()]
		var card_data = _CARD_DB[card_id].duplicate()
		card_data["card_id"] = card_id
		card_data["unique_id"] = _get_unique_card_id()
		ai_hand.append(card_data)
	
	_render_ai_hand()
	_clear_dropped_zones()
	
	is_player_turn = true
	_end_turn_btn.disabled = false
	_status.text = "Round %d - Your Turn!" % current_round
	_play_round_sfx()
	_show_round_banner()
	_update_ui()

func _update_ui() -> void:
	if _you_si_bar:
		_you_si_bar.value = player_si
	if _you_fw_bar:
		_you_fw_bar.value = player_fw
	if _opp_si_bar:
		_opp_si_bar.value = ai_si
	if _opp_fw_bar:
		_opp_fw_bar.value = ai_fw
	if _resource_label:
		_resource_label.text = "BW %d/%d  |  Plays %d/%d" % [player_bw, player_max_bw, player_plays, PLAYS_PER_TURN]
	if _opp_resource_label:
		_opp_resource_label.text = "AI: %d cards" % ai_hand.size()
	if _drop_timer_label:
		_drop_timer_label.visible = false

func _check_win_condition() -> void:
	if ai_si <= 0:
		_on_match_end(true)
	elif player_si <= 0:
		_on_match_end(false)

func _on_match_end(player_won: bool) -> void:
	match_started = false
	_end_turn_btn.disabled = true
	
	if _match_timer:
		_match_timer.stop()
	
	if player_won:
		_status.text = "🎉 VICTORY! You defeated the Cyber Bot!"
		if _sfx_result_player:
			_sfx_result_player.stream = _SFX_VICTORY
			_sfx_result_player.play()
	else:
		_status.text = "DEFEAT... The Cyber Bot won this time."
		if _sfx_result_player:
			_sfx_result_player.stream = _SFX_DEFEAT
			_sfx_result_player.play()
	
	# Mark tutorial as complete
	_mark_tutorial_complete()
	
	match_completed.emit(player_won)
	
	# Show post-game results panel
	await _show_postgame_results(player_won)
	
	# Set meta flag for landing to show rewards
	get_tree().set_meta("show_akashic_tcg_reward", true)
	_return_to_lobby()

func _show_postgame_results(player_won: bool) -> void:
	"""Show post-game results panel with detailed stats"""
	print("[TutorialArena] Showing post-game results...")
	
	# Create overlay
	var overlay = ColorRect.new()
	overlay.name = "PostgameOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)
	
	# Create results panel
	var panel = Panel.new()
	panel.name = "PostgamePanel"
	panel.custom_minimum_size = Vector2(400, 320)
	panel.z_index = 51
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -160
	panel.offset_bottom = 160
	
	# Style panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.08, 0.98)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0, 1, 1, 0.9) if player_won else Color(1, 0.3, 0.3, 0.9)
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.shadow_color = panel_style.border_color
	panel_style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	# Result title
	var title = Label.new()
	title.text = "🏆 VICTORY!" if player_won else "💀 DEFEAT"
	title.position = Vector2(0, 12)
	title.size = Vector2(400, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.84, 0, 1) if player_won else Color(1, 0.3, 0.3, 1))
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Akashic TCG Tutorial Complete!"
	subtitle.position = Vector2(0, 52)
	subtitle.size = Vector2(400, 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	subtitle.add_theme_font_size_override("font_size", 16)
	panel.add_child(subtitle)
	
	# Stats container
	var stats_y = 85
	var line_height = 26
	
	# Your SI
	var si_color = Color(0.3, 1, 0.3, 1) if player_si > 10 else Color(1, 0.5, 0, 1)
	_add_tcg_stat_row(panel, "💚 YOUR SI:", "%d / %d" % [player_si, STARTING_SI], stats_y, si_color)
	stats_y += line_height
	
	# Your FW
	_add_tcg_stat_row(panel, "🛡️ YOUR FW:", "%d / %d" % [player_fw, MAX_FW], stats_y)
	stats_y += line_height
	
	# AI SI
	_add_tcg_stat_row(panel, "🤖 BOT SI:", "%d" % ai_si, stats_y)
	stats_y += line_height
	
	# Round number
	_add_tcg_stat_row(panel, "📊 ROUND:", "%d" % current_round, stats_y)
	stats_y += line_height + 10
	
	# Divider
	var divider = ColorRect.new()
	divider.color = Color(0, 1, 1, 0.4)
	divider.position = Vector2(40, stats_y)
	divider.size = Vector2(320, 2)
	panel.add_child(divider)
	stats_y += 10
	
	# Hint text
	var hint = Label.new()
	hint.text = "Claim your reward on the next screen!"
	hint.position = Vector2(0, stats_y)
	hint.size = Vector2(400, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 0.9))
	hint.add_theme_font_size_override("font_size", 12)
	panel.add_child(hint)
	
	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE →"
	continue_btn.custom_minimum_size = Vector2(200, 45)
	continue_btn.position = Vector2(100, 265)
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.5, 0.6, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0, 1, 1, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0, 0.7, 0.8, 1)
	btn_hover.shadow_color = Color(0, 1, 1, 0.5)
	btn_hover.shadow_size = 10
	
	continue_btn.add_theme_stylebox_override("normal", btn_style)
	continue_btn.add_theme_stylebox_override("hover", btn_hover)
	continue_btn.add_theme_stylebox_override("pressed", btn_hover)
	continue_btn.add_theme_color_override("font_color", Color.WHITE)
	continue_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(continue_btn)
	
	# Wait for button press
	var button_pressed = [false] # Use array to allow modification in lambda
	continue_btn.pressed.connect(func():
		button_pressed[0] = true
	)
	
	# Animate panel entrance
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait for user to click continue
	while not button_pressed[0]:
		await get_tree().process_frame
	
	# Clean up
	overlay.queue_free()
	panel.queue_free()
	print("[TutorialArena] Post-game closed, continuing to landing...")

func _add_tcg_stat_row(parent: Node, label_text: String, value_text: String, y_pos: float, value_color: Color = Color(1, 1, 1, 1)) -> void:
	"""Add a stat row to the postgame panel"""
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(45, y_pos)
	label.size = Vector2(170, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.position = Vector2(220, y_pos)
	value.size = Vector2(135, 24)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 16)
	parent.add_child(value)

func _show_rewards_popup() -> void:
	"""Show tutorial rewards with card and XP"""
	print("[TutorialArena] Showing rewards popup...")
	
	var popup_scene = load("res://scene/tutorial_rewards_popup.tscn")
	if not popup_scene:
		push_error("[TutorialArena] Could not load rewards popup!")
		_return_to_lobby()
		return
	
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	# Set card image - The Magician 2 for Akashic TCG
	var card_image = popup.get_node_or_null("Panel/VBox/CardPanel/CardImage")
	if card_image:
		var card_tex = load("res://asset/reward_background_cards/the magician card 2.jpeg")
		if card_tex:
			card_image.texture = card_tex
	
	# Set card name
	var card_name_label = popup.get_node_or_null("Panel/VBox/CardNameLabel")
	if card_name_label:
		card_name_label.text = "✨ THE MAGICIAN 2 ✨"
	
	# Set XP
	var xp_label = popup.get_node_or_null("Panel/VBox/XPLabel")
	if xp_label:
		xp_label.text = "+100 XP"
	
	# Set Agent01 dialog text - Pokemon style!
	var dialog_text = popup.get_node_or_null("Panel/VBox/DialogBox/HBox/DialogText")
	if dialog_text:
		dialog_text.text = "Outstanding strategy, Agent! You've mastered the Akashic arts! This Magician card is yours - may it bring you power in future battles!"
	
	# Add XP to player
	if TutorialManager:
		TutorialManager.add_xp(100, "AkashicTCG Tutorial")
		print("[TutorialArena] Added 100 XP!")
	
	# Connect claim button
	var claim_btn = popup.get_node_or_null("Panel/VBox/ClaimButton")
	if claim_btn:
		claim_btn.pressed.connect(func():
			popup.queue_free()
			_return_to_lobby()
		)

func _mark_tutorial_complete() -> void:
	var user_id = Auth.current_local_id if Auth else ""
	var id_token = Auth.current_id_token if Auth else ""
	
	if user_id == "" or id_token == "":
		push_warning("[TutorialArena] Cannot save - user not logged in")
		return
	
	var firestore_url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s?updateMask.fieldPaths=akashic_tcg_tutorial_completed" % user_id
	
	var body = {
		"fields": {
			"akashic_tcg_tutorial_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[TutorialArena] ✅ Tutorial completion saved!")
	)
	
	http.request(firestore_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _return_to_lobby() -> void:
	print("[TutorialArena] Returning to landing...")
	get_tree().change_scene_to_file("res://scene/landing.tscn")
