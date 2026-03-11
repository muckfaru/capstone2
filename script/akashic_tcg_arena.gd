extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")
const _CardView = preload("res://script/AkashicTCGCardView.gd")

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
@onready var _menu_panel: Control = $MenuPanel
@onready var _menu_button: Button = $MenuButton
@onready var _arena_chat: Panel = $HUD/ArenaChat
@onready var _arena_chat_header: Panel = $HUD/ArenaChat/VBoxContainer/Header
@onready var _arena_chat_scroll: ScrollContainer = $HUD/ArenaChat/VBoxContainer/ScrollContainer
@onready var _arena_chat_messages: VBoxContainer = $HUD/ArenaChat/VBoxContainer/ScrollContainer/VBoxContainer
@onready var _arena_chat_input: LineEdit = $HUD/ArenaChat/VBoxContainer/HBoxContainer/LineEdit
@onready var _arena_chat_send_btn: Button = $HUD/ArenaChat/VBoxContainer/HBoxContainer/SendButton
@onready var _arena_chat_min_btn: Button = $HUD/ArenaChat/VBoxContainer/Header/HeaderHBox/MinButton
@onready var _arena_chat_close_btn: Button = $HUD/ArenaChat/VBoxContainer/Header/HeaderHBox/CloseButton

const _ARENA_CHAT_MAX_LINES := 60

var _arena_chat_collapsed: bool = false
var _arena_chat_saved_size: Vector2 = Vector2.ZERO

var _arena_chat_dragging: bool = false
var _arena_chat_drag_offset: Vector2 = Vector2.ZERO

var _arena_chat_default_pos: Vector2 = Vector2.ZERO

var _start_countdown_started: bool = false
var _start_countdown_active: bool = false

var _match_timer: Timer = null
var _match_timer_started: bool = false
var _match_start_msec: int = 0

const DROP_TIME_LIMIT_SEC := 30

var _drop_timer: Timer = null
var _drop_timer_turn: int = -1
var _drop_deadline_msec: int = 0
var _drop_timer_running: bool = false
var _auto_pass_turn: int = -1

func _ensure_drop_timer() -> void:
	if _drop_timer != null and is_instance_valid(_drop_timer):
		return
	_drop_timer = Timer.new()
	_drop_timer.wait_time = 0.2
	_drop_timer.one_shot = false
	_drop_timer.autostart = true
	_drop_timer.timeout.connect(_on_drop_timer_tick)
	add_child(_drop_timer)

func _has_submitted_any_card_this_round() -> bool:
	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var my_cards_val: Variant = pending.get(_player_id, [])
	var my_cards: Array = my_cards_val if typeof(my_cards_val) == TYPE_ARRAY else []
	for c in my_cards:
		if str(c) != "":
			return true
	return false

func _is_my_round_done() -> bool:
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	return bool(round_done.get(_player_id, false))

func _set_drop_timer_label(show_label: bool, seconds_left: int = 0) -> void:
	if _drop_timer_label == null:
		return
	_drop_timer_label.visible = show_label
	if show_label:
		_drop_timer_label.text = "%ds" % maxi(0, seconds_left)
	if _buff_icons_hbox != null and is_instance_valid(_buff_icons_hbox) and _buff_icons_runtime_created:
		call_deferred("_position_buff_icons_ui")

func _on_drop_timer_tick() -> void:
	# Only run after the arena has started.
	if not _match_timer_started:
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return
	if _start_countdown_active:
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return
	if typeof(_state) != TYPE_DICTIONARY or _state.is_empty():
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return
	if str(_state.get("winner_id", "")) != "":
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return

	var turn_i: int = int(_state.get("turn", 0))

	# If you've already acted (dropped) or you've already passed/finished, hide timer.
	if _is_my_round_done() or _has_submitted_any_card_this_round():
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return

	# If we already auto-passed this turn (waiting for sync), don't re-arm.
	if _auto_pass_turn == turn_i:
		_drop_timer_running = false
		_set_drop_timer_label(false)
		return

	# (Re)arm on new turn.
	if turn_i != _drop_timer_turn:
		_drop_timer_turn = turn_i
		_drop_deadline_msec = Time.get_ticks_msec() + int(DROP_TIME_LIMIT_SEC * 1000)
		_drop_timer_running = true

	if not _drop_timer_running:
		_set_drop_timer_label(false)
		return

	var now_msec: int = Time.get_ticks_msec()
	var remaining_msec: int = maxi(0, _drop_deadline_msec - now_msec)
	var remaining_sec: int = int(ceil(remaining_msec / 1000.0))
	_set_drop_timer_label(true, remaining_sec)

	if remaining_msec <= 0:
		_drop_timer_running = false
		_set_drop_timer_label(false)
		_auto_pass_turn = turn_i
		_send_or_apply_action("pass", {})

func _ensure_match_timer() -> void:
	if _match_timer != null and is_instance_valid(_match_timer):
		return
	_match_timer = Timer.new()
	_match_timer.wait_time = 0.25
	_match_timer.one_shot = false
	_match_timer.autostart = false
	_match_timer.timeout.connect(_on_match_timer_tick)
	add_child(_match_timer)

func _start_match_timer() -> void:
	if _match_timer_started:
		return
	_match_timer_started = true
	_match_start_msec = Time.get_ticks_msec()
	_set_timer_display(0)
	_ensure_match_timer()
	if _match_timer != null:
		_match_timer.start()

func _on_match_timer_tick() -> void:
	if not _match_timer_started:
		return
	var elapsed_msec: int = maxi(0, Time.get_ticks_msec() - _match_start_msec)
	var elapsed_sec: int = int(elapsed_msec / 1000.0)
	_set_timer_display(elapsed_sec)

func _run_start_countdown() -> void:
	if _start_countdown_started:
		return
	_start_countdown_started = true
	_start_countdown_active = true

	if _end_turn_btn != null:
		_end_turn_btn.disabled = true

	if _countdown_label != null:
		_countdown_label.visible = true
		_countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	if _countdown_label != null:
		_countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	if _countdown_label != null:
		_countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	if _countdown_label != null:
		_countdown_label.text = "START"
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return

	if _countdown_label != null:
		_countdown_label.visible = false

	_start_countdown_active = false
	_start_match_timer()
	_render()

func _set_timer_display(total_seconds: int) -> void:
	if _timer_label == null:
		return
	var s: int = maxi(0, total_seconds)
	var m: int = int(s / 60.0)
	var sec: int = s % 60
	_timer_label.text = "%02d\n..\n%02d" % [m, sec]

@onready var _play_zone: Panel = $HUD/Table/PlayZone
@onready var _hand_hbox: HBoxContainer = $HUD/HandArea/HandHBox

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

const STARTING_SI := 20
const MAX_FW := 12
const START_HAND := 3
const HAND_LIMIT := 7
const PLAYS_PER_TURN := 3
const MAX_BW := 10
const MAX_LOG_LINES := 6

const CARD_VIEW_SIZE := Vector2(110, 160)
const HAND_CARD_VIEW_SIZE := Vector2(140, 200)

const REVEAL_DELAY_SEC := 0.7
const FLIP_HALF_SEC := 0.12

const _SFX_CARD_DROP: AudioStream = preload("res://asset/audio/akashic sfx/card drop sound effect.wav")
const _SFX_CARD_REVEAL: AudioStream = preload("res://asset/audio/akashic sfx/card reveal sound effect.wav")

const _SFX_ROUND_PATH := "res://asset/audio/akashic sfx/round_sound effect.mp3"
const _SFX_ROUND_VOLUME_DB := -8.0

const _BUFF_ICON_SIZE := Vector2(25, 25)
const _ICON_MFA: Texture2D = preload("res://asset/icons/Multi fartor auth card icon.png")
const _ICON_IDS: Texture2D = preload("res://asset/icons/intrusion detection card icon.png")
const _ICON_ENCRYPTED: Texture2D = preload("res://asset/icons/encryption key card icon.png")

const _BUFF_TOOLTIP := {
	"mfa": {
		"title": "MFA",
		"desc": "Blocks the next Phishing/Trojan.",
	},
	"ids": {
		"title": "IDS",
		"desc": "Next incoming attack -1 damage, then draw 2.",
	},
	"encrypted": {
		"title": "ENCRYPTION",
		"desc": "Next Phishing/Virus/Trojan -1 damage.",
	},
}

const _ROUND_LABEL_DELAY_SEC := 0.35
const _ROUND_LABEL_SHOW_SEC := 1.25

const _ROUND_LABEL_IN_SEC := 0.18
const _ROUND_LABEL_OUT_SEC := 0.14
const _ROUND_LABEL_POP_SCALE := 1.08
const _ROUND_LABEL_START_SCALE := 0.86

const _SFX_DROP_VOLUME_DB := -4.0
const _SFX_REVEAL_VOLUME_DB := -9.0

var _sfx_drop_player: AudioStreamPlayer = null
var _sfx_reveal_player: AudioStreamPlayer = null
var _sfx_initialized: bool = false
var _reveal_sfx_turn: int = -1

var _round_sfx_stream: AudioStream = null
var _sfx_round_player: AudioStreamPlayer = null
var _last_round_ui: int = -1
var _round_announce_inflight: bool = false
var _round_label_tween: Tween = null
var _round_input_blocker: Control = null

var _buff_icons_hbox: HBoxContainer = null
var _buff_icons_runtime_created: bool = false


func _ensure_round_input_blocker() -> void:
	if _round_input_blocker != null and is_instance_valid(_round_input_blocker):
		return
	var hud: Control = $HUD
	_round_input_blocker = Control.new()
	_round_input_blocker.name = "RoundInputBlocker"
	_round_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_round_input_blocker.focus_mode = Control.FOCUS_NONE
	_round_input_blocker.visible = false
	_round_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_round_input_blocker.offset_left = 0
	_round_input_blocker.offset_top = 0
	_round_input_blocker.offset_right = 0
	_round_input_blocker.offset_bottom = 0
	hud.add_child(_round_input_blocker)


func _set_round_input_blocker_active(active: bool) -> void:
	_ensure_round_input_blocker()
	if _round_input_blocker == null or not is_instance_valid(_round_input_blocker):
		return
	_round_input_blocker.visible = active


func _ensure_buff_icons_ui() -> void:
	if _buff_icons_hbox != null and is_instance_valid(_buff_icons_hbox):
		return
	# Option 2: if it's authored in the scene, use it.
	var existing := get_node_or_null("HUD/PlayerBars/YouSIBar/BuffIconsHBox")
	if existing != null and existing is HBoxContainer:
		_buff_icons_hbox = existing as HBoxContainer
		return
	if _drop_timer_label == null:
		return
	var parent: Node = _drop_timer_label.get_parent()
	if parent == null or not (parent is Control):
		return

	_buff_icons_hbox = HBoxContainer.new()
	_buff_icons_hbox.name = "BuffIconsHBox"
	_buff_icons_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_icons_hbox.visible = false
	(parent as Control).add_child(_buff_icons_hbox)
	_buff_icons_runtime_created = true
	call_deferred("_position_buff_icons_ui")


func _position_buff_icons_ui() -> void:
	if _buff_icons_hbox == null or not is_instance_valid(_buff_icons_hbox):
		return
	# If authored in the scene (Option 2), the editor controls placement.
	if not _buff_icons_runtime_created:
		return
	if _drop_timer_label == null:
		return
	var label_pos: Vector2 = _drop_timer_label.position
	var label_size: Vector2 = _drop_timer_label.size
	var max_w: float = (_BUFF_ICON_SIZE.x * 3.0) + 8.0
	_buff_icons_hbox.position = Vector2(label_pos.x - max_w - 6.0, label_pos.y - 2.0)
	_buff_icons_hbox.custom_minimum_size = Vector2(max_w, max(label_size.y, _BUFF_ICON_SIZE.y))
	_buff_icons_hbox.size = _buff_icons_hbox.custom_minimum_size
	_buff_icons_hbox.add_theme_constant_override("separation", 4)


func _status_active(status: Dictionary, key: String) -> bool:
	if not status.has(key):
		return false
	var v: Variant = status.get(key)
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	if typeof(v) == TYPE_INT:
		return int(v) > 0
	if typeof(v) == TYPE_FLOAT:
		return float(v) > 0.0
	if typeof(v) == TYPE_DICTIONARY:
		return int((v as Dictionary).get("turns", 1)) > 0
	return true


func _turns_left_from_status(status: Dictionary, key: String) -> int:
	if not status.has(key):
		return 0
	var v: Variant = status.get(key)
	if typeof(v) == TYPE_DICTIONARY:
		return int((v as Dictionary).get("turns", 1))
	if typeof(v) == TYPE_INT:
		return int(v)
	return 1


func _make_buff_icon(tex: Texture2D, key: String, status: Dictionary) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = _BUFF_ICON_SIZE

	var meta: Dictionary = _BUFF_TOOLTIP.get(key, {})
	var title: String = str(meta.get("title", key.to_upper()))
	var desc: String = str(meta.get("desc", ""))
	var turns_left: int = _turns_left_from_status(status, key)
	if desc != "":
		icon.tooltip_text = "%s\n%s\nTurns left: %d" % [title, desc, turns_left]
	else:
		icon.tooltip_text = "%s\nTurns left: %d" % [title, turns_left]
	return icon


func _render_my_buff_icons(my_player: Dictionary) -> void:
	_ensure_buff_icons_ui()
	if _buff_icons_hbox == null or not is_instance_valid(_buff_icons_hbox):
		return
	var st_val: Variant = my_player.get("status", {})
	var st: Dictionary = st_val if typeof(st_val) == TYPE_DICTIONARY else {}

	var show_mfa := _status_active(st, "mfa")
	var show_ids := _status_active(st, "ids")
	var show_enc := _status_active(st, "encrypted")

	for c in _buff_icons_hbox.get_children():
		c.queue_free()

	if show_mfa:
		_buff_icons_hbox.add_child(_make_buff_icon(_ICON_MFA, "mfa", st))
	if show_ids:
		_buff_icons_hbox.add_child(_make_buff_icon(_ICON_IDS, "ids", st))
	if show_enc:
		_buff_icons_hbox.add_child(_make_buff_icon(_ICON_ENCRYPTED, "encrypted", st))

	_buff_icons_hbox.visible = show_mfa or show_ids or show_enc

func _ensure_round_sfx_player() -> void:
	if _sfx_round_player != null and is_instance_valid(_sfx_round_player):
		return
	_sfx_round_player = AudioStreamPlayer.new()
	add_child(_sfx_round_player)


func _play_round_sfx() -> void:
	if _round_sfx_stream == null:
		return
	_ensure_round_sfx_player()
	if _sfx_round_player == null or not is_instance_valid(_sfx_round_player):
		return
	_sfx_round_player.stream = _round_sfx_stream
	_sfx_round_player.volume_db = _SFX_ROUND_VOLUME_DB
	_sfx_round_player.play()


func _hide_round_label() -> void:
	if _round_label == null:
		return
	_set_round_input_blocker_active(false)
	if _round_label_tween != null and is_instance_valid(_round_label_tween):
		_round_label_tween.kill()
		_round_label_tween = null
	_round_label.visible = false
	_round_label.text = ""
	_round_label.scale = Vector2.ONE
	_round_label.modulate = Color(1, 1, 1, 1)


func _refresh_round_label_pivot() -> void:
	if _round_label == null:
		return
	# Keep scaling centered.
	_round_label.pivot_offset = _round_label.size * 0.5


func _animate_round_label_in() -> void:
	if _round_label == null:
		return
	_set_round_input_blocker_active(true)
	if _round_label_tween != null and is_instance_valid(_round_label_tween):
		_round_label_tween.kill()
		_round_label_tween = null

	# Start hidden-ish, then pop in.
	_round_label.visible = true
	_round_label.scale = Vector2.ONE * _ROUND_LABEL_START_SCALE
	_round_label.modulate = Color(1, 1, 1, 0)
	call_deferred("_refresh_round_label_pivot")

	_round_label_tween = create_tween()
	_round_label_tween.set_trans(Tween.TRANS_BACK)
	_round_label_tween.set_ease(Tween.EASE_OUT)
	_round_label_tween.parallel().tween_property(
		_round_label,
		"scale",
		Vector2.ONE * _ROUND_LABEL_POP_SCALE,
		_ROUND_LABEL_IN_SEC
	)
	_round_label_tween.parallel().tween_property(
		_round_label,
		"modulate",
		Color(1, 1, 1, 1),
		_ROUND_LABEL_IN_SEC
	)
	_round_label_tween.tween_property(
		_round_label,
		"scale",
		Vector2.ONE,
		0.08
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_round_label_out() -> void:
	if _round_label == null:
		return
	if _round_label_tween != null and is_instance_valid(_round_label_tween):
		_round_label_tween.kill()
		_round_label_tween = null
	if not _round_label.visible:
		return

	_round_label_tween = create_tween()
	_round_label_tween.set_trans(Tween.TRANS_SINE)
	_round_label_tween.set_ease(Tween.EASE_IN)
	_round_label_tween.parallel().tween_property(
		_round_label,
		"scale",
		Vector2.ONE * 0.92,
		_ROUND_LABEL_OUT_SEC
	)
	_round_label_tween.parallel().tween_property(
		_round_label,
		"modulate",
		Color(1, 1, 1, 0),
		_ROUND_LABEL_OUT_SEC
	)
	_round_label_tween.tween_callback(func():
		if _round_label == null:
			return
		_round_label.visible = false
		_round_label.text = ""
		_round_label.scale = Vector2.ONE
		_round_label.modulate = Color(1, 1, 1, 1)
		_set_round_input_blocker_active(false)
	)


func _show_round_banner(round_i: int) -> void:
	if _round_label == null:
		_round_announce_inflight = false
		return
	if not is_inside_tree():
		_round_announce_inflight = false
		return
	if typeof(_state) != TYPE_DICTIONARY or _state.is_empty():
		_hide_round_label()
		_round_announce_inflight = false
		return
	if str(_state.get("winner_id", "")) != "":
		_hide_round_label()
		_round_announce_inflight = false
		return
	if int(_state.get("turn", 0)) != round_i:
		# State advanced; don't show stale banner.
		_hide_round_label()
		_round_announce_inflight = false
		return
	if _start_countdown_active:
		# Wait until countdown finishes, then try again.
		get_tree().create_timer(0.25).timeout.connect(func():
			_show_round_banner(round_i)
		)
		return

	_round_label.text = "ROUND %d" % round_i
	_animate_round_label_in()
	_play_round_sfx()
	_last_round_ui = round_i
	_round_announce_inflight = false

	# Auto-hide after a short time.
	get_tree().create_timer(_ROUND_LABEL_SHOW_SEC).timeout.connect(func():
		if not is_inside_tree():
			return
		if _round_label == null:
			return
		# Only hide if we're still on the same round.
		if typeof(_state) == TYPE_DICTIONARY and not _state.is_empty() and int(_state.get("turn", 0)) == round_i:
			_animate_round_label_out()
	)


func _maybe_announce_round_start() -> void:
	if _round_label == null:
		return
	if typeof(_state) != TYPE_DICTIONARY or _state.is_empty():
		_hide_round_label()
		_last_round_ui = -1
		_round_announce_inflight = false
		return
	if str(_state.get("winner_id", "")) != "":
		_hide_round_label()
		_last_round_ui = -1
		_round_announce_inflight = false
		return
	var round_i: int = int(_state.get("turn", 0))
	if round_i <= 0:
		_hide_round_label()
		_last_round_ui = -1
		_round_announce_inflight = false
		return

	# If a new round is detected, schedule a banner.
	if round_i != _last_round_ui and not _round_announce_inflight:
		_round_announce_inflight = true
		_hide_round_label()
		get_tree().create_timer(_ROUND_LABEL_DELAY_SEC).timeout.connect(func():
			_show_round_banner(round_i)
		)

func _ensure_sfx_players() -> void:
	if _sfx_drop_player == null or not is_instance_valid(_sfx_drop_player):
		_sfx_drop_player = AudioStreamPlayer.new()
		add_child(_sfx_drop_player)
	if _sfx_reveal_player == null or not is_instance_valid(_sfx_reveal_player):
		_sfx_reveal_player = AudioStreamPlayer.new()
		add_child(_sfx_reveal_player)

func _play_drop_sfx() -> void:
	if not _sfx_initialized:
		return
	_ensure_sfx_players()
	if _sfx_drop_player == null:
		return
	_sfx_drop_player.volume_db = _SFX_DROP_VOLUME_DB
	_sfx_drop_player.stream = _SFX_CARD_DROP
	_sfx_drop_player.play()

func _play_reveal_sfx() -> void:
	if not _sfx_initialized:
		return
	_ensure_sfx_players()
	if _sfx_reveal_player == null:
		return
	_sfx_reveal_player.volume_db = _SFX_REVEAL_VOLUME_DB
	_sfx_reveal_player.stream = _SFX_CARD_REVEAL
	_sfx_reveal_player.play()

enum CardType { ATTACK, DEFENSE }

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

var _BACK_TEX: Texture2D = preload("res://asset/cards for AkashicTGC/back cards.png")

const _CARD_DB := {
	# Defense
	"mfa": {"name": "MULTI-FACTOR AUTH", "type": CardType.DEFENSE, "cost": 3},
	"antivirus": {"name": "ANTIVIRUS CORE", "type": CardType.DEFENSE, "cost": 3},
	"encryption": {"name": "ENCRYPTION KEY", "type": CardType.DEFENSE, "cost": 3},
	"firewall": {"name": "FIREWALL SHIELD", "type": CardType.DEFENSE, "cost": 2},
	"ids": {"name": "INTRUSION DETECTION", "type": CardType.DEFENSE, "cost": 2},
	# Attack
	"phishing": {"name": "PHISHING", "type": CardType.ATTACK, "cost": 1, "base_damage": 2},
	"dos": {"name": "DOS", "type": CardType.ATTACK, "cost": 2, "base_damage": 4},
	"ddos": {"name": "DDOS", "type": CardType.ATTACK, "cost": 4, "base_damage": 8},
	"virus": {"name": "VIRUS", "type": CardType.ATTACK, "cost": 2, "base_damage": 1},
	"trojan": {"name": "TROJAN HORSE", "type": CardType.ATTACK, "cost": 3, "base_damage": 3},
}

var _room_id: String = ""
var _relay_client: Node = null
var _player_id: String = ""
var _is_host: bool = false
var _lobby_server_url: String = ""
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}

var _host_id: String = ""
var _client_id: String = ""

var _state: Dictionary = {}
var _local_version: int = 0
var _pending_action_id: int = 1

var _flip_tweens: Dictionary = {}
var _last_opp_revealed_ids: Array[String] = ["", "", ""]

var _slide_tweens: Dictionary = {}
var _last_you_slot_keys: Array[String] = ["", "", ""]
var _last_opp_slot_keys: Array[String] = ["", "", ""]

const SLIDE_IN_SEC := 0.14
const SLIDE_IN_SCALE_FROM := 0.78
const SLIDE_IN_SCALE_OVERSHOOT := 1.08

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_arena_init"):
		init = get_tree().get_meta("tgc_arena_init")
		get_tree().set_meta("tgc_arena_init", null)

	_room_id = str(init.get("room_id", ""))
	if _room_id.strip_edges() == "":
		var sess := _TGCSess.load_session()
		_room_id = str(sess.get("room_id", ""))
	_relay_client = init.get("relay_client", null)
	_player_id = str(init.get("player_id", ""))
	_is_host = bool(init.get("is_host", false))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})

	_host_id = str(_host_data.get("player_id", ""))
	_client_id = str(_client_data.get("player_id", ""))

	_sidebar_opp_name.text = _name_for(_other_player(_player_id))
	_sidebar_you_name.text = _name_for(_player_id)
	_init_arena_chat()
	_set_timer_display(0)

	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, "arena")

	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	if _relay_client:
		if not _relay_client.message_received.is_connected(_on_relay_message):
			_relay_client.message_received.connect(_on_relay_message)
		if _relay_client.has_signal("disconnected_from_relay") and not _relay_client.disconnected_from_relay.is_connected(_on_relay_disconnected):
			_relay_client.disconnected_from_relay.connect(_on_relay_disconnected)

	if _play_zone.has_signal("card_dropped"):
		if not _play_zone.card_dropped.is_connected(_on_play_zone_card_dropped):
			_play_zone.card_dropped.connect(_on_play_zone_card_dropped)

	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	# Load round SFX (runtime load so missing files won't break parsing).
	var loaded: Variant = load(_SFX_ROUND_PATH)
	if loaded != null and loaded is AudioStream:
		_round_sfx_stream = loaded as AudioStream
	else:
		_round_sfx_stream = null
		push_warning("[TGC Arena] Round SFX not found at: " + _SFX_ROUND_PATH)
	if _menu_button != null and not _menu_button.pressed.is_connected(_on_menu_button_pressed):
		_menu_button.pressed.connect(_on_menu_button_pressed)
	_ensure_round_input_blocker()
	_ensure_buff_icons_ui()
	_ensure_drop_timer()
	if _menu_panel != null:
		_menu_panel.visible = false
		if _menu_panel.has_signal("exit_match_requested") and not _menu_panel.exit_match_requested.is_connected(_on_exit_match_forfeit):
			_menu_panel.exit_match_requested.connect(_on_exit_match_forfeit)

	# Click-to-cancel on your dropped slots.
	for i in range(_you_dropped_cards.size()):
		var slot := _you_dropped_cards[i]
		if slot == null:
			continue
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if not slot.gui_input.is_connected(_on_you_dropped_gui_input):
			slot.gui_input.connect(_on_you_dropped_gui_input.bind(i))

	for slot in _opp_dropped_cards:
		_setup_card_slot(slot)
	for slot in _you_dropped_cards:
		_setup_card_slot(slot)


	_status.text = "Connecting…"
	_apply_shop_cosmetics()
	if _is_host:
		_try_init_host_state_if_possible()
	else:
		_request_state()
	_render()
	_run_start_countdown()


func _on_menu_button_pressed() -> void:
	if _menu_panel == null:
		return
	_menu_panel.visible = not _menu_panel.visible
	if _menu_panel.visible:
		_menu_panel.move_to_front()


func _apply_shop_cosmetics() -> void:
	# Background swap
	var bg_val: String = ShopManager.get_equipped_value(ShopManager.SLOT_BG_AKASHIC_TCG)
	if bg_val != "" and ResourceLoader.exists(bg_val):
		var bg_node = $NinePatchRect
		if bg_node and bg_node is NinePatchRect:
			bg_node.texture = load(bg_val)
			print("[ATCG Arena] 🎨 Shop background applied: ", bg_val)

	# Card back skin swap
	var skin_val: String = ShopManager.get_equipped_value(ShopManager.SLOT_SKIN_AKASHIC_TCG)
	if skin_val != "" and ResourceLoader.exists(skin_val):
		var tex = load(skin_val) as Texture2D
		if tex:
			_BACK_TEX = tex
			print("[ATCG Arena] 🎨 Shop card back applied: ", skin_val)


func _init_arena_chat() -> void:
	if _arena_chat == null:
		return
	# Capture the default position once (for snap-back behavior).
	if _arena_chat_default_pos == Vector2.ZERO:
		_arena_chat_default_pos = _arena_chat.global_position
	# Keep it on top like the old ChatPanel.
	_arena_chat.visible = true
	_arena_chat.top_level = true
	_arena_chat.z_index = 1000
	# Draggable header.
	if _arena_chat_header and not _arena_chat_header.gui_input.is_connected(_on_arena_chat_header_gui_input):
		_arena_chat_header.gui_input.connect(_on_arena_chat_header_gui_input)
	# Wire input events.
	if _arena_chat_send_btn and not _arena_chat_send_btn.pressed.is_connected(_on_arena_chat_send_pressed):
		_arena_chat_send_btn.pressed.connect(_on_arena_chat_send_pressed)
	if _arena_chat_input and not _arena_chat_input.text_submitted.is_connected(_on_arena_chat_text_submitted):
		_arena_chat_input.text_submitted.connect(_on_arena_chat_text_submitted)
	if _arena_chat_min_btn and not _arena_chat_min_btn.pressed.is_connected(_on_arena_chat_min_pressed):
		_arena_chat_min_btn.pressed.connect(_on_arena_chat_min_pressed)
	if _arena_chat_close_btn and not _arena_chat_close_btn.pressed.is_connected(_on_arena_chat_close_pressed):
		_arena_chat_close_btn.pressed.connect(_on_arena_chat_close_pressed)
	# Small hint so you can see it's alive.
	_append_arena_chat_line("SYSTEM", "Chat ready")


func _on_arena_chat_header_gui_input(event: InputEvent) -> void:
	if _arena_chat == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			# Don't start dragging if clicking the control buttons.
			var mouse_pos := get_viewport().get_mouse_position()
			if _arena_chat_min_btn and _arena_chat_min_btn.get_global_rect().has_point(mouse_pos):
				return
			if _arena_chat_close_btn and _arena_chat_close_btn.get_global_rect().has_point(mouse_pos):
				return
			_arena_chat_dragging = true
			_arena_chat_drag_offset = mouse_pos - _arena_chat.global_position
			accept_event()
		else:
			_arena_chat_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _arena_chat_dragging:
		var motion := event as InputEventMouseMotion
		var new_pos := motion.position - _arena_chat_drag_offset
		# Clamp to viewport bounds.
		var vp := get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, max(0.0, vp.x - _arena_chat.size.x))
		new_pos.y = clamp(new_pos.y, 0.0, max(0.0, vp.y - _arena_chat.size.y))
		_arena_chat.global_position = new_pos
		accept_event()


func _on_arena_chat_close_pressed() -> void:
	if _arena_chat == null:
		return
	# Snap back to default position for next open.
	_reset_arena_chat_position()
	_arena_chat.visible = false


func _reset_arena_chat_position() -> void:
	if _arena_chat == null:
		return
	if _arena_chat_default_pos != Vector2.ZERO:
		_arena_chat.global_position = _arena_chat_default_pos
	# Reset collapse so next open is fully usable.
	_arena_chat_collapsed = false
	_apply_arena_chat_collapsed_state()


func _on_arena_chat_min_pressed() -> void:
	_arena_chat_collapsed = not _arena_chat_collapsed
	_apply_arena_chat_collapsed_state()


func _apply_arena_chat_collapsed_state() -> void:
	if _arena_chat == null:
		return
	if _arena_chat_scroll == null or _arena_chat_input == null or _arena_chat_send_btn == null:
		return
	var input_row := _arena_chat_input.get_parent()
	if _arena_chat_collapsed:
		if _arena_chat_saved_size == Vector2.ZERO:
			_arena_chat_saved_size = _arena_chat.size
		_arena_chat_scroll.visible = false
		if input_row and "visible" in input_row:
			input_row.visible = false
		var header_h: float = 34.0
		if _arena_chat_header != null:
			header_h = max(header_h, _arena_chat_header.size.y)
		_arena_chat.size = Vector2(_arena_chat.size.x, header_h)
		if _arena_chat_min_btn != null:
			_arena_chat_min_btn.text = "+"
	else:
		_arena_chat_scroll.visible = true
		if input_row and "visible" in input_row:
			input_row.visible = true
		if _arena_chat_saved_size != Vector2.ZERO:
			_arena_chat.size = _arena_chat_saved_size
		if _arena_chat_min_btn != null:
			_arena_chat_min_btn.text = "_"


func _on_arena_chat_send_pressed() -> void:
	if _arena_chat_input == null:
		return
	_send_arena_chat(_arena_chat_input.text)


func _on_arena_chat_text_submitted(text: String) -> void:
	_send_arena_chat(text)


func _send_arena_chat(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	if _arena_chat_input != null:
		_arena_chat_input.text = ""
	var username: String = Auth.current_username if Auth else "Player"
	_append_arena_chat_line(username, clean)
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "tgc_chat",
		"sender": _player_id,
		"username": username,
		"text": clean,
		"timestamp": Time.get_ticks_msec(),
	})


func _append_arena_chat_line(user: String, text: String) -> void:
	if _arena_chat_messages == null:
		return
	# Cap the list to avoid growing forever.
	while _arena_chat_messages.get_child_count() >= _ARENA_CHAT_MAX_LINES:
		var first := _arena_chat_messages.get_child(0)
		if first:
			first.queue_free()
		else:
			break
	var label := Label.new()
	label.text = "%s: %s" % [user, text]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.add_theme_font_size_override("font_size", 12)
	_arena_chat_messages.add_child(label)
	_scroll_arena_chat_to_bottom()


func _scroll_arena_chat_to_bottom() -> void:
	if _arena_chat_scroll == null:
		return
	await get_tree().process_frame
	_arena_chat_scroll.scroll_vertical = int(_arena_chat_scroll.get_v_scroll_bar().max_value)

func _setup_card_slot(slot: TextureRect) -> void:
	if slot == null:
		return
	slot.custom_minimum_size = CARD_VIEW_SIZE
	# Match AkashicTCGCardView sizing behavior so the texture's pixel size does not
	# force a larger minimum size and so containers don't stretch the slot.
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_SCALE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _try_init_host_state_if_possible() -> void:
	if _host_id == "" or _client_id == "":
		_status.text = "Waiting for opponent…"
		return
	if not _state.is_empty():
		return
	_state = _build_initial_state(_host_id, _client_id)
	_local_version = int(_state.get("version", 0))
	_status.text = "Match started"
	_broadcast_state_sync({"type": "init"})
	_render()
	# Edge case: if both players have no affordable moves on round start,
	# auto-finish can mark both as done. Ensure we don't deadlock.
	_resolve_round_if_ready()

func _build_initial_state(host_id: String, client_id: String) -> Dictionary:
	var host_deck := _make_start_deck()
	var client_deck := _make_start_deck()
	host_deck.shuffle()
	client_deck.shuffle()

	var state := {
		"version": 1,
		"turn": 0,
		"priority": host_id,
		"pending": {}, # {player_id: Array[String]}
		"pending_costs": {}, # {player_id: Array[int]}
		"round_done": {}, # {player_id: bool}
		"winner_id": "",
		"players": {
			host_id: _make_player_state(host_deck),
			client_id: _make_player_state(client_deck),
		},
		"log": [],
	}

	for _i in range(START_HAND):
		_draw_card(state, host_id)
		_draw_card(state, client_id)

	_start_round(state)
	return state

func _make_player_state(deck: Array) -> Dictionary:
	return {
		"si": STARTING_SI,
		"fw": 0,
		"bw": 0,
		"bw_max": 0,
		"plays_left": 0,
		"turns_taken": 0,
		"deck": deck,
		"hand": [],
		"discard": [],
		"cards_used": [],
		"status": {},
		"recent_attack": [],
		"recent_defense": [],
		"backdoor_used_turn": -1,
	}

func _track_card_used_in_state(actor_id: String, card_id: String) -> void:
	if not _is_host:
		return
	if _state.is_empty():
		return
	if card_id.strip_edges() == "":
		return
	var p_val: Variant = _state.get("players", {}).get(actor_id, {})
	if typeof(p_val) != TYPE_DICTIONARY:
		return
	var p: Dictionary = p_val
	var used_val: Variant = p.get("cards_used", [])
	var used: Array = used_val if typeof(used_val) == TYPE_ARRAY else []
	used.append(card_id)
	p["cards_used"] = used
	_state["players"][actor_id] = p

func _cards_used_from_state(pid: String) -> Array:
	var p_val: Variant = _state.get("players", {}).get(pid, {})
	if typeof(p_val) != TYPE_DICTIONARY:
		return []
	var p: Dictionary = p_val
	var used_val: Variant = p.get("cards_used", [])
	return used_val if typeof(used_val) == TYPE_ARRAY else []

func _make_start_deck() -> Array:
	# Starter deck (25 cards)
	# Defense (2 each): MFA, Antivirus, Encryption, Firewall Shield, IDS
	# Attack (3 each): Phishing, DOS, DDOS, Virus, Trojan Horse
	var deck: Array = []
	var defensive_ids := ["mfa", "antivirus", "encryption", "firewall", "ids"]
	var attacking_ids := ["phishing", "dos", "ddos", "virus", "trojan"]
	for id in defensive_ids:
		deck.append(id)
		deck.append(id)
	for id in attacking_ids:
		deck.append(id)
		deck.append(id)
		deck.append(id)
	return deck

func _start_round(state: Dictionary) -> void:
	# Simultaneous round: both players refresh and can submit up to 3 cards (or pass).
	state["turn"] = int(state.get("turn", 0)) + 1
	state["pending"] = {}
	state["pending_costs"] = {}
	state["round_done"] = {}

	var priority := str(state.get("priority", _host_id))
	if priority != _host_id and priority != _client_id:
		priority = _host_id
	var order := [priority, _other_player(priority)]

	for pid in order:
		var p: Dictionary = state["players"][pid]
		p["turns_taken"] = int(p.get("turns_taken", 0)) + 1
		p["plays_left"] = PLAYS_PER_TURN

		_apply_start_of_turn_effects(state, pid)
		_maybe_shuffle_packages(state, pid)

		# Bandwidth (BW): fixed max (10) and per-round gain with carryover.
		# Round 1-2: +2, 3-6: +3, 7-10: +4, 11+: +5. Cap at MAX_BW.
		# Lag reduces this round's BW gain by 1.
		var st: Dictionary = p.get("status", {})
		var gain := _bw_gain_for_round(int(state.get("turn", 0)))
		if st.has("lag"):
			gain = max(0, gain - 1)
			st.erase("lag")
			p["status"] = st
		p["bw_max"] = MAX_BW
		p["bw"] = min(MAX_BW, int(p.get("bw", 0)) + gain)

		state["players"][pid] = p
		_draw_card(state, pid)
		_auto_finish_player_if_no_moves(state, pid)

	_append_log(state, "Round %d | Priority: %s" % [int(state.get("turn", 0)), _name_for(priority)])
	# If both players are immediately finished (e.g., no affordable cards),
	# schedule an auto-resolve so the match can progress.
	_resolve_round_if_ready()

func _bw_gain_for_round(round_number: int) -> int:
	if round_number <= 2:
		return 2
	if round_number <= 6:
		return 3
	if round_number <= 10:
		return 4
	return 5

func _name_for(pid: String) -> String:
	if pid == _host_id:
		return str(_host_data.get("username", "Host"))
	if pid == _client_id:
		return str(_client_data.get("username", "Client"))
	return "Player"

func _draw_card(state: Dictionary, pid: String) -> void:
	var p: Dictionary = state["players"][pid]
	var deck: Array = p.get("deck", [])
	if deck.is_empty():
		return
	var hand: Array = p.get("hand", [])
	var turns_taken: int = int(p.get("turns_taken", 0))

	# Gate mid/late-game cards so they don't appear too early.
	# DOS unlocks at turn 4, DDOS unlocks at turn 6 (host-authoritative).
	var card_id: String = ""
	var drew: bool = false
	var attempts: int = mini(deck.size(), 32)
	for _i in range(attempts):
		if deck.is_empty():
			break
		var candidate: String = str(deck.pop_back())
		var locked := (candidate == "dos" and turns_taken < 4) or (candidate == "ddos" and turns_taken < 6)
		if locked:
			# Put it back somewhere random so we can draw something else.
			var insert_at: int = randi_range(0, deck.size())
			deck.insert(insert_at, candidate)
			continue
		card_id = candidate
		drew = true
		break

	# If everything left is locked, skip drawing this time.
	if not drew:
		p["deck"] = deck
		state["players"][pid] = p
		return

	p["deck"] = deck
	if hand.size() >= HAND_LIMIT:
		var discard: Array = p.get("discard", [])
		discard.append(card_id)
		p["discard"] = discard
		_append_log(state, "%s burned a card" % _name_for(pid))
		return
	hand.append(card_id)
	p["hand"] = hand
	state["players"][pid] = p

func _append_log(state: Dictionary, text: String) -> void:
	var arr: Array = state.get("log", [])
	arr.append(text)
	while arr.size() > MAX_LOG_LINES:
		arr.pop_front()
	state["log"] = arr

func _render() -> void:
	if _state.is_empty():
		_status.text = "Waiting for state…"
		_end_turn_btn.disabled = true
		_opp_resource_label.text = "BW 0/0  |  Plays 0/%d" % PLAYS_PER_TURN
		_resource_label.text = "BW 0/0  |  Plays 0/%d" % PLAYS_PER_TURN
		_render_opp_hand_count(0)
		_clear_hand_ui()
		_render_dropped_cards({})
		_maybe_announce_round_start()
		return

	var opp_id := _other_player(_player_id)
	var my_val: Variant = _state.get("players", {}).get(_player_id, null)
	var opp_val: Variant = _state.get("players", {}).get(opp_id, null)
	var my: Dictionary = my_val if typeof(my_val) == TYPE_DICTIONARY else {}
	var opp: Dictionary = opp_val if typeof(opp_val) == TYPE_DICTIONARY else {}

	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	var my_done := bool(round_done.get(_player_id, false))
	var opp_done := bool(round_done.get(opp_id, false))
	var my_cards_val: Variant = pending.get(_player_id, [])
	var opp_cards_val: Variant = pending.get(opp_id, [])
	var my_cards: Array = my_cards_val if typeof(my_cards_val) == TYPE_ARRAY else []
	var opp_cards: Array = opp_cards_val if typeof(opp_cards_val) == TYPE_ARRAY else []
	var _my_submitted := my_cards.size() > 0
	var _opp_submitted := opp_cards.size() > 0
	var winner := str(_state.get("winner_id", ""))
	var over := winner != ""

	_sidebar_opp_name.text = _name_for(opp_id)
	_sidebar_you_name.text = _name_for(_player_id)

	if over:
		_status.text = "Game Over | Winner: %s" % _name_for(winner)
	else:
		if my_done and not opp_done:
			_status.text = "Waiting for opponent…"
		elif (not my_done) and opp_done:
			_status.text = "Opponent finished. Your move."
		else:
			_status.text = "Round %d" % int(_state.get("turn", 0))

	_maybe_announce_round_start()

	_opp_si_bar.max_value = STARTING_SI
	_opp_fw_bar.max_value = MAX_FW
	_you_si_bar.max_value = STARTING_SI
	_you_fw_bar.max_value = MAX_FW
	_opp_si_bar.value = clamp(float(opp.get("si", STARTING_SI)), 0.0, float(STARTING_SI))
	_opp_fw_bar.value = clamp(float(opp.get("fw", 0)), 0.0, float(MAX_FW))
	_you_si_bar.value = clamp(float(my.get("si", STARTING_SI)), 0.0, float(STARTING_SI))
	_you_fw_bar.value = clamp(float(my.get("fw", 0)), 0.0, float(MAX_FW))

	_resource_label.text = "BW %d/%d  |  Plays %d/%d" % [
		int(my.get("bw", 0)),
		int(my.get("bw_max", 0)),
		int(my.get("plays_left", 0)),
		PLAYS_PER_TURN,
	]

	_opp_resource_label.text = "BW %d/%d  |  Plays %d/%d" % [
		int(opp.get("bw", 0)),
		int(opp.get("bw_max", 0)),
		int(opp.get("plays_left", 0)),
		PLAYS_PER_TURN,
	]
	var opp_hand_val: Variant = opp.get("hand", [])
	var opp_hand: Array = opp_hand_val if typeof(opp_hand_val) == TYPE_ARRAY else []
	_render_opp_hand_count(opp_hand.size())

	_end_turn_btn.text = "PASS"
	_end_turn_btn.disabled = over or my_done

	_render_hand(my, (not my_done), over)
	_render_my_buff_icons(my)

	# Show the cards currently dropped/submitted this round.
	_render_dropped_cards(pending)
	if not _sfx_initialized:
		_sfx_initialized = true

func _render_opp_hand_count(count: int) -> void:
	if _opp_hand_hbox == null:
		return
	for c in _opp_hand_hbox.get_children():
		c.queue_free()
	var n: int = int(clamp(count, 0, HAND_LIMIT))
	for i in range(n):
		var card := TextureRect.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.texture = _BACK_TEX
		card.custom_minimum_size = Vector2(110, 160)
		# Match AkashicTCGCardView sizing behavior so the texture's pixel size
		# does not force a larger minimum size inside containers.
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.z_as_relative = true
		card.z_index = i
		_opp_hand_hbox.add_child(card)

func _clear_hand_ui() -> void:
	for c in _hand_hbox.get_children():
		c.queue_free()

func _render_dropped_cards(pending: Dictionary) -> void:
	if _opp_dropped_cards.size() < 3 or _you_dropped_cards.size() < 3:
		return
	var opp_id := _other_player(_player_id)
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	var reveal_now := bool(round_done.get(_player_id, false)) and bool(round_done.get(opp_id, false))
	var opp_cards_val: Variant = pending.get(opp_id, [])
	var you_cards_val: Variant = pending.get(_player_id, [])
	var opp_cards: Array = opp_cards_val if typeof(opp_cards_val) == TYPE_ARRAY else []
	var you_cards: Array = you_cards_val if typeof(you_cards_val) == TYPE_ARRAY else []
	var turn_i: int = int(_state.get("turn", 0))
	var reveal_sfx_played_this_tick := false
	if reveal_now and _reveal_sfx_turn != turn_i and opp_cards.size() > 0:
		_reveal_sfx_turn = turn_i
		_play_reveal_sfx()
		reveal_sfx_played_this_tick = true

	# Note: Your cards are always visible to you; opponent cards reveal all-at-once
	# only when BOTH players are finished (PASS or auto-finish).

	for i in range(3):
		# Your row (always face-up).
		if i < you_cards.size() and str(you_cards[i]) != "":
			var you_id := str(you_cards[i])
			var you_key := you_id
			var you_prev := _last_you_slot_keys[i]
			_you_dropped_cards[i].texture = _texture_for_id(you_id)
			_you_dropped_cards[i].tooltip_text = _tooltip_for_card(you_id)
			# Cursor: allow cancel before resolution is scheduled.
			_you_dropped_cards[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_cancel_now() else Control.CURSOR_ARROW
			if you_prev == "" and you_key != "":
				_slide_in(_you_dropped_cards[i])
				if not reveal_sfx_played_this_tick:
					_play_drop_sfx()
			_last_you_slot_keys[i] = you_key
		else:
			_you_dropped_cards[i].texture = null
			_you_dropped_cards[i].tooltip_text = ""
			_you_dropped_cards[i].mouse_default_cursor_shape = Control.CURSOR_ARROW
			_last_you_slot_keys[i] = ""

		# Opponent row: stay hidden until both players are finished, then reveal all.
		if i < opp_cards.size() and str(opp_cards[i]) != "":
			var opp_card_id := str(opp_cards[i])
			var opp_key := (opp_card_id if reveal_now else "__back__" + opp_card_id)
			var opp_prev := _last_opp_slot_keys[i]
			if reveal_now:
				var next_tex := _texture_for_id(opp_card_id)
				var next_tip := _tooltip_for_card(opp_card_id)
				if _opp_dropped_cards[i].texture == _BACK_TEX and _last_opp_revealed_ids[i] != opp_card_id:
					_flip_reveal(_opp_dropped_cards[i], next_tex, next_tip)
					_last_opp_revealed_ids[i] = opp_card_id
				else:
					_opp_dropped_cards[i].texture = next_tex
					_opp_dropped_cards[i].tooltip_text = next_tip
			else:
				_opp_dropped_cards[i].texture = _BACK_TEX
				_opp_dropped_cards[i].tooltip_text = ""

			# Slide-in only when a new opponent slot becomes occupied (empty -> back).
			# Do NOT slide-in again when we switch back->faceup on reveal.
			if opp_prev == "" and opp_key != "":
				_slide_in(_opp_dropped_cards[i])
				# If the first time we learn opponent cards is at reveal, prefer reveal SFX.
				if not reveal_sfx_played_this_tick and not reveal_now:
					_play_drop_sfx()
			_last_opp_slot_keys[i] = opp_key
		else:
			_opp_dropped_cards[i].texture = null
			_opp_dropped_cards[i].tooltip_text = ""
			_last_opp_revealed_ids[i] = ""
			_last_opp_slot_keys[i] = ""

func _flip_reveal(node: TextureRect, new_texture: Texture2D, new_tooltip: String) -> void:
	if node == null:
		return
	if _flip_tweens.has(node):
		var old_tw: Variant = _flip_tweens.get(node)
		if old_tw is Tween and is_instance_valid(old_tw):
			(old_tw as Tween).kill()
		_flip_tweens.erase(node)

	# Ensure we have a "back" visible before flipping.
	if node.texture == null:
		node.texture = _BACK_TEX

	# Flip around center.
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


func _slide_in(node: TextureRect) -> void:
	if node == null:
		return
	if _slide_tweens.has(node):
		var old_tw: Variant = _slide_tweens.get(node)
		if old_tw is Tween and is_instance_valid(old_tw):
			(old_tw as Tween).kill()
		_slide_tweens.erase(node)

	var base_scale := node.scale
	var base_mod := node.modulate

	node.pivot_offset = node.size * 0.5
	# Container-safe animation: position is often managed by the Container,
	# so we use a visible pop (fade + scale overshoot).
	node.scale = base_scale * SLIDE_IN_SCALE_FROM
	node.modulate = Color(base_mod.r, base_mod.g, base_mod.b, 0.0)

	var tw := create_tween()
	_slide_tweens[node] = tw
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var half := SLIDE_IN_SEC * 0.5
	tw.tween_property(node, "scale", base_scale * SLIDE_IN_SCALE_OVERSHOOT, half)
	tw.parallel().tween_property(node, "modulate:a", base_mod.a, half)
	tw.tween_property(node, "scale", base_scale, half)
	tw.finished.connect(func():
		if _slide_tweens.get(node) == tw:
			_slide_tweens.erase(node)
	)

func _tooltip_for_card(card_id: String) -> String:
	if card_id == "":
		return ""
	var def_val: Variant = _CARD_DB.get(card_id, null)
	if typeof(def_val) != TYPE_DICTIONARY:
		return card_id
	var def: Dictionary = def_val
	var card_name := str(def.get("name", card_id)).strip_edges()
	var cost := int(def.get("cost", 0))
	var desc := _card_description(card_id)
	if desc == "":
		return "%s\nCost %d" % [card_name, cost]
	return "%s\nCost %d\n\n%s" % [card_name, cost, desc]

func _card_description(card_id: String) -> String:
	match card_id:
		"virus":
			return "Deal 1 damage (FW → SI).\nApply Infected (3 turns): at start of infected player's round, take 1 SI damage (bypasses FW)."
		"phishing":
			return "Deal 2 damage (FW → SI).\nIf SI damage > 0, apply Credential Compromised (2 turns)."
		"trojan":
			return "Deal 3 damage that bypasses FW (hits SI).\nIf SI damage > 0, gain Backdoor (3 turns): next Attack costs −1 once per round."
		"dos":
			return "Deal 4 damage (FW → SI).\nIf defender had 0 FW before hit and SI damage > 0, apply Lag (1 turn): next BW refresh −1."
		"ddos":
			return "Deal 8 damage (FW → SI).\nMinimum final damage is 3 unless fully blocked by effects."
		"mfa":
			return "For 2 turns: blocks the next Phishing or Trojan."
		"ids":
			return "Arms IDS (1 turn): next incoming Attack −1 damage, then draw 2."
		"encryption":
			return "For 2 turns: reduces incoming Phishing/Virus/Trojan by 1."
		"firewall":
			return "Increase your FW by 6 (max 12)."
		"antivirus":
			return "Remove Infected and Backdoor.\nHeal +2 SI (max 20)."
		_:
			return ""

func _last_two_ids(arr: Array) -> Array[String]:
	var a: Array[String] = ["", ""]
	if arr.size() >= 1:
		a[0] = str(arr[max(0, arr.size() - 2)])
	if arr.size() >= 2:
		a[1] = str(arr[max(0, arr.size() - 1)])
	return a

func _texture_for_id(card_id: String) -> Texture2D:
	if card_id == "":
		return null
	return _TEX.get(card_id, null)

func _render_hand(my: Dictionary, is_my_turn: bool, over: bool) -> void:
	_clear_hand_ui()
	var hand: Array = my.get("hand", [])
	for i in range(hand.size()):
		var card_id := str(hand[i])
		var card := TextureRect.new()
		card.set_script(_CardView)
		card.texture = _texture_for_id(card_id)
		_setup_card_slot(card)
		# Hover flip SFX for your hand cards.
		card.hover_sfx_enabled = true
		# Hand cards are intentionally larger than the center dropped slots.
		card.custom_minimum_size = HAND_CARD_VIEW_SIZE
		card.z_as_relative = true
		card.z_index = i
		card.tooltip_text = _tooltip_for_card(card_id)
		card.card_data = {"card_id": card_id, "hand_index": i}
		var can_play_turn := (not over) and is_my_turn and int(my.get("plays_left", 0)) > 0
		var can_afford := _can_afford_card(my, card_id)
		var playable := can_play_turn and can_afford
		card.drag_enabled = playable
		card.click_enabled = playable
		if card.has_signal("card_clicked") and not card.card_clicked.is_connected(_on_hand_card_clicked):
			card.card_clicked.connect(_on_hand_card_clicked)
		# Cursor indication:
		# - Enough BW (and playable now) -> pointing hand
		# - Not enough BW (while it's your turn) -> forbidden
		# - Otherwise -> default arrow
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		if can_play_turn and not can_afford:
			card.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		elif playable:
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_hand_hbox.add_child(card)


func _on_hand_card_clicked(card_data: Dictionary) -> void:
	if _start_countdown_active:
		return
	# Click-to-play: behaves like dropping the card into the play zone.
	_on_play_zone_card_dropped(card_data)

func _can_afford_card(p: Dictionary, card_id: String) -> bool:
	var cost := _effective_cost(p, card_id)
	return int(p.get("bw", 0)) >= cost

func _can_afford_any_card(p: Dictionary) -> bool:
	var bw := int(p.get("bw", 0))
	var hand_val: Variant = p.get("hand", [])
	var hand: Array = hand_val if typeof(hand_val) == TYPE_ARRAY else []
	for v in hand:
		var card_id := str(v)
		if card_id == "":
			continue
		if bw >= _effective_cost(p, card_id):
			return true
	return false

func _on_play_zone_card_dropped(card_data: Dictionary) -> void:
	if _start_countdown_active:
		return
	var card_id := str(card_data.get("card_id", ""))
	var idx := int(card_data.get("hand_index", -1))
	if card_id == "" or idx < 0:
		return
	_send_or_apply_action("submit_card", {"hand_index": idx, "card_id": card_id})


func _on_you_dropped_gui_input(event: InputEvent, slot_index: int) -> void:
	if _start_countdown_active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_attempt_cancel_dropped_slot(slot_index)


func _can_cancel_now() -> bool:
	if _state.is_empty():
		return false
	if str(_state.get("winner_id", "")) != "":
		return false
	# Once resolution is scheduled (both done), we lock the round.
	if bool(_state.get("resolve_scheduled", false)):
		return false
	return true


func _attempt_cancel_dropped_slot(slot_index: int) -> void:
	if not _can_cancel_now():
		return
	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var my_cards_val: Variant = pending.get(_player_id, [])
	var my_cards: Array = my_cards_val if typeof(my_cards_val) == TYPE_ARRAY else []
	if slot_index < 0 or slot_index >= my_cards.size():
		return
	_send_or_apply_action("cancel_card", {"slot_index": slot_index})

func _on_end_turn_pressed() -> void:
	if _start_countdown_active:
		return
	_send_or_apply_action("pass", {})


func _send_or_apply_action(action: String, payload: Dictionary) -> void:
	if _state.is_empty() or str(_state.get("winner_id", "")) != "":
		return
	if _is_host:
		_apply_action_host(_player_id, action, payload)
		_broadcast_state_sync({"type": "action", "action": action, "actor": _player_id})
		_render()
		return
	if _relay_client == null:
		return
	var msg := {
		"type": "tgc_action_request",
		"room_id": _room_id,
		"actor": _player_id,
		"action": action,
		"payload": payload,
		"client_action_id": _pending_action_id,
		"known_version": int(_state.get("version", 0)),
		"timestamp": Time.get_ticks_msec(),
	}
	_pending_action_id += 1
	_relay_client.send_message(msg)

func _on_relay_message(data: Dictionary) -> void:
	var t := str(data.get("type", ""))
	match t:
		"player_connected":
			if _is_host and _state.is_empty():
				# Try again now that both may be present
				_try_init_host_state_if_possible()
		"tgc_chat":
			var sender := str(data.get("sender", ""))
			# The relay server does not echo to sender, but keep this guard anyway.
			if sender == _player_id:
				return
			var user := str(data.get("username", "Opponent"))
			var text := str(data.get("text", ""))
			if text.strip_edges() == "":
				return
			_append_arena_chat_line(user, text)
		"tgc_request_state":
			if _is_host:
				_broadcast_state_sync({"type": "state_response", "to": str(data.get("player_id", ""))})
		"tgc_state_sync":
			var state_val = data.get("state", null)
			if typeof(state_val) != TYPE_DICTIONARY:
				return
			var v := int(state_val.get("version", 0))
			if v < _local_version:
				return
			_state = state_val
			_local_version = v
			_render()
		"tgc_action_request":
			if _is_host:
				_handle_action_request_host(data)
		"tgc_action_reject":
			_status.text = "Rejected: %s" % str(data.get("reason", "invalid"))
		"tgc_match_end":
			_transition_to_postgame(str(data.get("winner_id", "")), str(data.get("reason", "ended")), int(data.get("timestamp", 0)))
		"tgc_force_loading_sync":
			_transition_to_loading("forced_resync")
		"player_forfeit":
			# Opponent forfeited — auto-win
			var opp_id := _other_player(_player_id)
			print("[TGC Arena] ⚔️ Opponent forfeited! Auto-win!")
			_status.text = "⚔️ Opponent forfeited! You win!"
			if _is_host and str(_state.get("winner_id", "")) == "":
				_state["winner_id"] = _player_id
				_bump_version(_state)
				_broadcast_state_sync({"type": "forfeit"})
				call_deferred("_finish_match_host", _player_id, "opponent_forfeit")
			elif not _is_host:
				_state["winner_id"] = _player_id
				_render()
				await get_tree().create_timer(3.0).timeout
				_transition_to_postgame(_player_id, "opponent_forfeit")
		"player_disconnected":
			# Opponent disconnected — auto-win
			print("[TGC Arena] ⚠️ Opponent disconnected! Auto-win!")
			_status.text = "⚠️ Opponent disconnected! You win!"
			if _is_host and str(_state.get("winner_id", "")) == "":
				_state["winner_id"] = _player_id
				_bump_version(_state)
				call_deferred("_finish_match_host", _player_id, "opponent_disconnected")
			elif not _is_host:
				_state["winner_id"] = _player_id
				_render()
				await get_tree().create_timer(3.0).timeout
				_transition_to_postgame(_player_id, "opponent_disconnected")
		_:
			pass

func _request_state() -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "tgc_request_state",
		"player_id": _player_id,
		"timestamp": Time.get_ticks_msec(),
	})

func _handle_action_request_host(msg: Dictionary) -> void:
	var actor := str(msg.get("actor", ""))
	var action := str(msg.get("action", ""))
	# Only accept from known players
	if actor != _host_id and actor != _client_id:
		_send_reject("unknown_actor")
		return
	if _state.is_empty():
		_send_reject("no_state")
		return
	if str(_state.get("winner_id", "")) != "":
		_send_reject("game_over")
		return
	_apply_action_host(actor, action, msg.get("payload", {}))
	_broadcast_state_sync({"type": "action", "action": action, "actor": actor})
	_render()

func _send_reject(reason: String) -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "tgc_action_reject",
		"reason": reason,
		"timestamp": Time.get_ticks_msec(),
	})


func _apply_action_host(actor: String, action: String, payload: Dictionary) -> void:
	match action:
		"submit_card":
			_host_submit_card(actor, payload)
		"cancel_card":
			_host_cancel_card(actor, payload)
		"pass":
			_host_pass(actor)
		"concede":
			_host_concede(actor)
		_:
			_append_log(_state, "Unknown action: %s" % action)
	_bump_version(_state)
	_check_game_over()
	if str(_state.get("winner_id", "")) == "":
		_resolve_round_if_ready()

func _bump_version(state: Dictionary) -> void:
	state["version"] = int(state.get("version", 0)) + 1
	_local_version = int(state["version"])

func _other_player(pid: String) -> String:
	return _client_id if pid == _host_id else _host_id


func _host_submit_card(pid: String, payload: Dictionary) -> void:
	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var costs_val: Variant = _state.get("pending_costs", {})
	var pending_costs: Dictionary = costs_val if typeof(costs_val) == TYPE_DICTIONARY else {}
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if bool(round_done.get(pid, false)):
		_append_log(_state, "%s already finished" % _name_for(pid))
		return

	var p: Dictionary = _state["players"][pid]
	if int(p.get("plays_left", 0)) <= 0:
		round_done[pid] = true
		_state["round_done"] = round_done
		_append_log(_state, "%s has no plays left" % _name_for(pid))
		return
	var hand: Array = p.get("hand", [])
	var idx := int(payload.get("hand_index", -1))
	var claimed_id := str(payload.get("card_id", ""))
	var resolved_idx := idx
	if claimed_id != "":
		resolved_idx = hand.find(claimed_id)
	if resolved_idx < 0:
		resolved_idx = idx
	if resolved_idx < 0 or resolved_idx >= hand.size():
		_append_log(_state, "%s invalid hand index" % _name_for(pid))
		return
	var card_id := str(hand[resolved_idx])
	var def_val: Variant = _CARD_DB.get(card_id, null)
	if typeof(def_val) != TYPE_DICTIONARY:
		_append_log(_state, "Invalid card")
		return
	var cost := _effective_cost(p, card_id)
	if int(p.get("bw", 0)) < cost:
		_append_log(_state, "%s lacks BW" % _name_for(pid))
		_auto_finish_player_if_no_moves(_state, pid)
		return

	# If this play benefits from Backdoor discount, consume it for this turn.
	_maybe_consume_backdoor_discount(p, card_id, cost)

	p["bw"] = int(p.get("bw", 0)) - cost
	p["plays_left"] = max(0, int(p.get("plays_left", 0)) - 1)

	hand.remove_at(resolved_idx)
	p["hand"] = hand
	_state["players"][pid] = p

	var arr_val: Variant = pending.get(pid, [])
	var arr: Array = arr_val if typeof(arr_val) == TYPE_ARRAY else []
	arr.append(card_id)
	if arr.size() > PLAYS_PER_TURN:
		arr.resize(PLAYS_PER_TURN)
	pending[pid] = arr
	_state["pending"] = pending
	var cost_arr_val: Variant = pending_costs.get(pid, [])
	var cost_arr: Array = cost_arr_val if typeof(cost_arr_val) == TYPE_ARRAY else []
	cost_arr.append(cost)
	if cost_arr.size() > PLAYS_PER_TURN:
		cost_arr.resize(PLAYS_PER_TURN)
	pending_costs[pid] = cost_arr
	_state["pending_costs"] = pending_costs
	_append_log(_state, "%s submitted a card (%d/%d)" % [_name_for(pid), arr.size(), PLAYS_PER_TURN])
	_auto_finish_player_if_no_moves(_state, pid)
	_resolve_round_if_ready()


func _host_cancel_card(pid: String, payload: Dictionary) -> void:
	if bool(_state.get("resolve_scheduled", false)):
		_append_log(_state, "%s cannot cancel now" % _name_for(pid))
		return
	var slot_index := int(payload.get("slot_index", -1))
	if slot_index < 0 or slot_index >= PLAYS_PER_TURN:
		return

	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var costs_val: Variant = _state.get("pending_costs", {})
	var pending_costs: Dictionary = costs_val if typeof(costs_val) == TYPE_DICTIONARY else {}

	var arr_val: Variant = pending.get(pid, [])
	var arr: Array = arr_val if typeof(arr_val) == TYPE_ARRAY else []
	if slot_index >= arr.size():
		return
	var card_id := str(arr[slot_index])
	arr.remove_at(slot_index)
	pending[pid] = arr
	_state["pending"] = pending

	var cost_arr_val: Variant = pending_costs.get(pid, [])
	var cost_arr: Array = cost_arr_val if typeof(cost_arr_val) == TYPE_ARRAY else []
	var refund := 0
	if slot_index < cost_arr.size():
		refund = int(cost_arr[slot_index])
		cost_arr.remove_at(slot_index)
	pending_costs[pid] = cost_arr
	_state["pending_costs"] = pending_costs

	var p: Dictionary = _state.get("players", {}).get(pid, {})
	if typeof(p) != TYPE_DICTIONARY:
		return
	# Return card to hand, refund BW, restore a play.
	var hand_val: Variant = p.get("hand", [])
	var hand: Array = hand_val if typeof(hand_val) == TYPE_ARRAY else []
	hand.append(card_id)
	p["hand"] = hand
	p["bw"] = min(MAX_BW, int(p.get("bw", 0)) + refund)
	p["plays_left"] = min(PLAYS_PER_TURN, int(p.get("plays_left", 0)) + 1)
	_state["players"][pid] = p

	# If the player was marked done (PASS/auto-finish), reopen their turn.
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if bool(round_done.get(pid, false)):
		round_done[pid] = false
		_state["round_done"] = round_done

	_append_log(_state, "%s cancelled a card" % _name_for(pid))
	_auto_finish_player_if_no_moves(_state, pid)


func _host_pass(pid: String) -> void:
	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if bool(round_done.get(pid, false)):
		return
	round_done[pid] = true
	_state["round_done"] = round_done
	_state["pending"] = pending
	_append_log(_state, "%s passed" % _name_for(pid))
	_resolve_round_if_ready()

func _auto_finish_player_if_no_moves(state: Dictionary, pid: String) -> void:
	var done_val: Variant = state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if bool(round_done.get(pid, false)):
		return
	var p_val: Variant = state.get("players", {}).get(pid, {})
	if typeof(p_val) != TYPE_DICTIONARY:
		return
	var p: Dictionary = p_val
	if int(p.get("plays_left", 0)) <= 0:
		round_done[pid] = true
		state["round_done"] = round_done
		return
	if not _can_afford_any_card(p):
		round_done[pid] = true
		state["round_done"] = round_done

func _resolve_round_if_ready() -> void:
	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if not bool(round_done.get(_host_id, false)) or not bool(round_done.get(_client_id, false)):
		return
	if str(_state.get("winner_id", "")) != "":
		return
	if not _is_host:
		return
	if bool(_state.get("resolve_scheduled", false)):
		return

	# Leave pending in place briefly so both players can see the reveal.
	_state["resolve_scheduled"] = true
	call_deferred("_resolve_round_after_reveal_delay")

func _resolve_round_after_reveal_delay() -> void:
	await get_tree().create_timer(REVEAL_DELAY_SEC).timeout
	if _state.is_empty():
		return
	_state["resolve_scheduled"] = false

	var done_val: Variant = _state.get("round_done", {})
	var round_done: Dictionary = done_val if typeof(done_val) == TYPE_DICTIONARY else {}
	if not bool(round_done.get(_host_id, false)) or not bool(round_done.get(_client_id, false)):
		return
	if str(_state.get("winner_id", "")) != "":
		return

	var pending_val: Variant = _state.get("pending", {})
	var pending: Dictionary = pending_val if typeof(pending_val) == TYPE_DICTIONARY else {}

	# Resolve using current priority order.
	var priority := str(_state.get("priority", _host_id))
	if priority != _host_id and priority != _client_id:
		priority = _host_id
	var other := _other_player(priority)

	for pid in [priority, other]:
		var cards_val: Variant = pending.get(pid, [])
		var cards: Array = cards_val if typeof(cards_val) == TYPE_ARRAY else []
		for c in cards:
			var card_id := str(c)
			if card_id == "":
				continue
			var def_val: Variant = _CARD_DB.get(card_id, null)
			if typeof(def_val) != TYPE_DICTIONARY:
				continue
			_apply_card_effect(pid, card_id, def_val)

	# Alternate priority each round.
	_state["priority"] = other
	_state["pending"] = {}
	_state["pending_costs"] = {}
	_state["round_done"] = {}
	_check_game_over()
	if str(_state.get("winner_id", "")) == "":
		_start_round(_state)

	# Broadcast the post-resolution state.
	_bump_version(_state)
	_broadcast_state_sync({"type": "resolve"})
	_render()

func _host_concede(pid: String) -> void:
	var winner := _other_player(pid)
	_state["winner_id"] = winner
	_append_log(_state, "%s conceded" % _name_for(pid))
	if _is_host:
		call_deferred("_finish_match_host", winner, "concede")

func _check_game_over() -> void:
	var p_host_val: Variant = _state.get("players", {}).get(_host_id, {})
	var p_client_val: Variant = _state.get("players", {}).get(_client_id, {})
	var p_host: Dictionary = p_host_val if typeof(p_host_val) == TYPE_DICTIONARY else {}
	var p_client: Dictionary = p_client_val if typeof(p_client_val) == TYPE_DICTIONARY else {}
	if int(p_host.get("si", 1)) <= 0:
		_state["winner_id"] = _client_id
	if int(p_client.get("si", 1)) <= 0:
		_state["winner_id"] = _host_id
	var winner := str(_state.get("winner_id", ""))
	if winner != "" and _is_host:
		call_deferred("_finish_match_host", winner, "si_zero")

func _effective_cost(p: Dictionary, card_id: String) -> int:
	var def_val: Variant = _CARD_DB.get(card_id, null)
	var def: Dictionary = def_val if typeof(def_val) == TYPE_DICTIONARY else {}
	var base := int(def.get("cost", 0))
	var st: Dictionary = p.get("status", {})
	var t := int(def.get("type", CardType.ATTACK))
	var cost := base
	# Credential compromised: next Defense costs +1
	if t == CardType.DEFENSE and st.has("cred"):
		cost += 1
	# Backdoor: next Attack costs -1 (min 1), once per turn
	if t == CardType.ATTACK and st.has("backdoor"):
		var turn_i := int(_state.get("turn", 0))
		if int(p.get("backdoor_used_turn", -1)) != turn_i:
			cost = max(1, cost - 1)
	return cost

func _maybe_consume_backdoor_discount(p: Dictionary, card_id: String, effective_cost: int) -> void:
	var def_val: Variant = _CARD_DB.get(card_id, null)
	if typeof(def_val) != TYPE_DICTIONARY:
		return
	var def: Dictionary = def_val
	if int(def.get("type", CardType.ATTACK)) != CardType.ATTACK:
		return
	var base_cost := int(def.get("cost", 0))
	var st: Dictionary = p.get("status", {})
	if not st.has("backdoor"):
		return
	var turn_i := int(_state.get("turn", 0))
	if int(p.get("backdoor_used_turn", -1)) == turn_i:
		return
	if effective_cost < base_cost:
		p["backdoor_used_turn"] = turn_i

func _consume_status_charge(p: Dictionary, key: String) -> void:
	var st: Dictionary = p.get("status", {})
	if not st.has(key):
		return
	st.erase(key)
	p["status"] = st

func _apply_start_of_turn_effects(state: Dictionary, pid: String) -> void:
	var p: Dictionary = state["players"][pid]
	var st: Dictionary = p.get("status", {})

	# Virus tick: 1 SI damage bypass FW
	if st.has("infected"):
		p["si"] = int(p.get("si", 0)) - 1
		var inf: Dictionary = st["infected"]
		inf["turns"] = int(inf.get("turns", 1)) - 1
		if int(inf.get("turns", 0)) <= 0:
			st.erase("infected")
		else:
			st["infected"] = inf
		_append_log(state, "%s took 1 infected damage" % _name_for(pid))

	# Decrement duration-based statuses
	for key in ["mfa", "ids", "encrypted", "backdoor", "cred"]:
		if st.has(key):
			var sd: Dictionary = st[key]
			sd["turns"] = int(sd.get("turns", 1)) - 1
			if int(sd.get("turns", 0)) <= 0:
				st.erase(key)
			else:
				st[key] = sd

	p["status"] = st
	state["players"][pid] = p

func _maybe_shuffle_packages(state: Dictionary, pid: String) -> void:
	var p: Dictionary = state["players"][pid]
	var turns_taken := int(p.get("turns_taken", 0))
	var deck: Array = p.get("deck", [])
	if turns_taken == 4:
		# Legacy balancing: only add if DOS isn't already in the deck.
		if deck.count("dos") == 0:
			_shuffle_in(state, pid, ["dos", "dos"], "Midgame package deployed")
	elif turns_taken == 6:
		# Legacy balancing: only add if DDOS isn't already in the deck.
		if deck.count("ddos") == 0:
			_shuffle_in(state, pid, ["ddos", "ddos"], "Lategame package deployed")

func _shuffle_in(state: Dictionary, pid: String, cards: Array, msg: String) -> void:
	var p: Dictionary = state["players"][pid]
	var deck: Array = p.get("deck", [])
	for c in cards:
		deck.append(str(c))
	deck.shuffle()
	p["deck"] = deck
	state["players"][pid] = p
	_append_log(state, "%s: %s" % [_name_for(pid), msg])

func _push_recent(p: Dictionary, key: String, card_id: String) -> void:
	var arr: Array = p.get(key, [])
	arr.append(card_id)
	while arr.size() > 2:
		arr.pop_front()
	p[key] = arr

func _apply_card_effect(actor_id: String, card_id: String, def: Dictionary) -> void:
	var t := int(def.get("type", CardType.ATTACK))
	if t == CardType.DEFENSE:
		_apply_defense(actor_id, card_id)
	else:
		_apply_attack(actor_id, card_id)
	_track_card_used_in_state(actor_id, card_id)

func _apply_defense(actor_id: String, card_id: String) -> void:
	var p: Dictionary = _state["players"][actor_id]
	# Consume credential compromised (one-time) when you successfully play a Defense card
	var st: Dictionary = p.get("status", {})
	if st.has("cred"):
		st.erase("cred")
		p["status"] = st

	match card_id:
		"mfa":
			st = p.get("status", {})
			st["mfa"] = {"turns": 2}
			p["status"] = st
			_append_log(_state, "%s activated MFA" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		"ids":
			st = p.get("status", {})
			st["ids"] = {"turns": 1}
			p["status"] = st
			_append_log(_state, "%s deployed IDS" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		"encryption":
			st = p.get("status", {})
			st["encrypted"] = {"turns": 2}
			p["status"] = st
			_append_log(_state, "%s enabled Encryption" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		"firewall":
			p["fw"] = min(int(p.get("fw", 0)) + 6, MAX_FW)
			_append_log(_state, "%s raised Firewall" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		"antivirus":
			st = p.get("status", {})
			st.erase("infected")
			st.erase("backdoor")
			p["status"] = st
			p["si"] = min(int(p.get("si", 0)) + 2, STARTING_SI)
			_append_log(_state, "%s ran Antivirus" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		_:
			_append_log(_state, "Unknown defense")

	_state["players"][actor_id] = p

func _apply_attack(actor_id: String, card_id: String) -> void:
	var attacker: Dictionary = _state["players"][actor_id]
	var defender_id := _other_player(actor_id)
	var defender: Dictionary = _state["players"][defender_id]

	var attacker_status: Dictionary = attacker.get("status", {})
	var defender_status: Dictionary = defender.get("status", {})

	var base := int(_CARD_DB.get(card_id, {}).get("base_damage", 0))
	var dmg := base
	var bypass_fw := (card_id == "trojan")

	# MFA blocks first PHISHING/TROJAN for 2 turns
	if defender_status.has("mfa") and (card_id == "phishing" or card_id == "trojan"):
		defender_status.erase("mfa")
		defender["status"] = defender_status
		_append_log(_state, "%s blocked %s (MFA)" % [_name_for(defender_id), _CARD_DB[card_id]["name"]])
		_push_recent(attacker, "recent_attack", card_id)
		_state["players"][actor_id] = attacker
		_state["players"][defender_id] = defender
		return

	# IDS reduces next Attack by 1 and draws 2
	if defender_status.has("ids"):
		dmg = max(0, dmg - 1)
		defender_status.erase("ids")
		defender["status"] = defender_status
		_state["players"][defender_id] = defender
		_draw_card(_state, defender_id)
		_draw_card(_state, defender_id)
		_append_log(_state, "%s IDS reduced damage" % _name_for(defender_id))
		defender = _state["players"][defender_id]

	# Encryption reduces PHISHING/VIRUS/TROJAN by 1
	if defender_status.has("encrypted") and (card_id == "phishing" or card_id == "virus" or card_id == "trojan"):
		dmg = max(0, dmg - 1)

	# DDOS minimum final damage is 3 (unless fully blocked by MFA)
	if card_id == "ddos" and dmg < 3:
		dmg = 3

	var si_damage := 0
	var fw_before := int(defender.get("fw", 0))
	if dmg > 0:
		if bypass_fw:
			si_damage = dmg
		else:
			var fw_absorb: int = int(min(int(defender.get("fw", 0)), dmg))
			defender["fw"] = int(defender.get("fw", 0)) - fw_absorb
			si_damage = dmg - fw_absorb
			if fw_absorb > 0:
				_append_log(_state, "%s FW absorbed %d" % [_name_for(defender_id), fw_absorb])
		if si_damage > 0:
			defender["si"] = int(defender.get("si", 0)) - si_damage

	# Apply secondary effects
	match card_id:
		"phishing":
			if si_damage > 0:
				defender_status = defender.get("status", {})
				defender_status["cred"] = {"turns": 2}
				defender["status"] = defender_status
		"dos":
			if fw_before == 0 and si_damage > 0:
				defender_status = defender.get("status", {})
				defender_status["lag"] = {"turns": 1}
				defender["status"] = defender_status
		"virus":
			defender_status = defender.get("status", {})
			defender_status["infected"] = {"turns": 3}
			defender["status"] = defender_status
		"trojan":
			if si_damage > 0:
				attacker_status = attacker.get("status", {})
				attacker_status["backdoor"] = {"turns": 3}
				attacker["status"] = attacker_status
		_:
			pass

	_push_recent(attacker, "recent_attack", card_id)
	_append_log(_state, "%s played %s" % [_name_for(actor_id), _CARD_DB[card_id]["name"]])
	_state["players"][actor_id] = attacker
	_state["players"][defender_id] = defender


func _finish_match_host(winner_id: String, reason: String) -> void:
	var ended_at_unix: int = int(Time.get_unix_time_from_system())
	await _post_room_status("finished")
	_broadcast_match_end(winner_id, reason, ended_at_unix)
	_transition_to_postgame(winner_id, reason, ended_at_unix)

func _broadcast_state_sync(meta: Dictionary) -> void:
	if _relay_client == null:
		return
	var payload := {
		"type": "tgc_state_sync",
		"room_id": _room_id,
		"state": _state,
		"meta": meta,
		"timestamp": Time.get_ticks_msec(),
	}
	_relay_client.send_message(payload)

func _broadcast_match_end(winner_id: String, reason: String, ended_at_unix: int) -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "tgc_match_end",
		"room_id": _room_id,
		"winner_id": winner_id,
		"reason": reason,
		"timestamp": ended_at_unix,
	})

func _on_relay_disconnected() -> void:
	# If game is still active with no winner, opponent left = we win
	if not _state.is_empty() and str(_state.get("winner_id", "")) == "":
		print("[TGC Arena] ⚠️ Relay disconnected during active game — claiming victory")
		_status.text = "⚠️ Opponent disconnected! You win!"
		_state["winner_id"] = _player_id
		_render()
		await get_tree().create_timer(3.0).timeout
		_transition_to_postgame(_player_id, "opponent_disconnected")
		return
	_go_to_reconnect("Relay disconnected", "arena")

func _go_to_reconnect(reason: String, phase: String) -> void:
	var username: String = Auth.current_username if Auth else "Player"
	_TGCSess.save_session(_room_id, _lobby_server_url, _player_id, username, phase)
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	get_tree().set_meta("tgc_reconnect_init", {
		"room_id": _room_id,
		"lobby_server_url": _lobby_server_url,
		"player_id": _player_id,
		"username": username,
		"is_host": _is_host,
		"relay_client": null,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": 0,
		"reason": reason,
		"phase": phase,
	})
	var scene := load("res://scene/akashic_tcg_reconnect.tscn")
	if scene:
		get_tree().change_scene_to_packed(scene)

func _transition_to_postgame(winner_id: String, reason: String, ended_at_unix: int = 0) -> void:
	if get_tree().has_meta("tgc_postgame_init"):
		return
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()

	# Snapshot stats for postgame/history.
	var players_val: Variant = _state.get("players", {})
	var players: Dictionary = players_val if typeof(players_val) == TYPE_DICTIONARY else {}
	var host_p_val: Variant = players.get(_host_id, {})
	var client_p_val: Variant = players.get(_client_id, {})
	var host_p: Dictionary = host_p_val if typeof(host_p_val) == TYPE_DICTIONARY else {}
	var client_p: Dictionary = client_p_val if typeof(client_p_val) == TYPE_DICTIONARY else {}
	var host_si: int = int(host_p.get("si", STARTING_SI))
	var client_si: int = int(client_p.get("si", STARTING_SI))
	var duration_s: int = 0
	if _match_timer_started and _match_start_msec > 0:
		duration_s = int(maxi(0, Time.get_ticks_msec() - _match_start_msec) / 1000.0)
	var ended: int = ended_at_unix
	if ended <= 0:
		ended = int(Time.get_unix_time_from_system())
	get_tree().set_meta("tgc_postgame_init", {
		"room_id": _room_id,
		"player_id": _player_id,
		"winner_id": winner_id,
		"reason": reason,
		"ended_at_unix": ended,
		"lobby_server_url": _lobby_server_url,
		"host_data": _host_data,
		"client_data": _client_data,
		"host_cards_used": _cards_used_from_state(_host_id),
		"client_cards_used": _cards_used_from_state(_client_id),
		"host_si": host_si,
		"client_si": client_si,
		"duration_s": duration_s,
	})
	var scene := load("res://scene/akashic_tcg_postgame.tscn")
	if scene:
		get_tree().change_scene_to_packed(scene)

func _transition_to_loading(reason: String) -> void:
	if _relay_client and _relay_client.get_parent() != get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		get_tree().root.add_child(_relay_client)
	get_tree().set_meta("tgc_loading_init", {
		"room_id": _room_id,
		"relay_client": _relay_client,
		"player_id": _player_id,
		"is_host": _is_host,
		"host_data": _host_data,
		"client_data": _client_data,
		"game_start_time": 0,
		"lobby_server_url": _lobby_server_url,
		"resume": true,
		"reason": reason,
	})
	var loading_scene := load("res://scene/akashic_tcg_loading.tscn")
	if loading_scene:
		get_tree().change_scene_to_packed(loading_scene)

func _post_room_status(status: String) -> void:
	if _lobby_server_url == "" or _room_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	var done := {"ok": false}
	http.request_completed.connect(func(_r, _code, _h, _b):
		done["ok"] = true
		http.queue_free()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/status"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"status": status}))
	while not done["ok"]:
		await get_tree().create_timer(0.1).timeout
func _on_exit_match_forfeit() -> void:
	print("[TGC Arena] ⚔️ Player forfeiting match via menu!")

	# Hide the menu so it doesn't linger on screen
	if _menu_panel != null:
		_menu_panel.visible = false

	# If game is already over (e.g. postgame transition in progress), ignore.
	if str(_state.get("winner_id", "")) != "":
		return

	# Notify opponent via relay so they see the forfeit message
	if _relay_client != null:
		_relay_client.send_message({
			"type": "player_forfeit",
			"player_id": _player_id
		})

	# Host: mark the other player as winner and broadcast; then go to postgame.
	# Client: update local state and go straight to postgame.
	var winner_id := _other_player(_player_id)

	if _is_host:
		if not _state.is_empty():
			_state["winner_id"] = winner_id
			_bump_version(_state)
			_broadcast_state_sync({"type": "forfeit"})
		call_deferred("_finish_match_host", winner_id, "forfeit")
	else:
		if not _state.is_empty():
			_state["winner_id"] = winner_id
		# Small delay so the relay message reaches the host before we leave.
		await get_tree().create_timer(0.5).timeout
		_transition_to_postgame(winner_id, "forfeit")
