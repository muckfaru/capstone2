extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")
const _CardView = preload("res://script/AkashicTCGCardView.gd")

@onready var _status: Label = $HUD/StatusLabel

@onready var _opp_si_bar: ProgressBar = $HUD/OpponentBars/OppSIBar
@onready var _opp_fw_bar: ProgressBar = $HUD/OpponentBars/OppFWBar
@onready var _opp_resource_label: Label = $HUD/OpponentBars/OppResourceLabel
@onready var _you_si_bar: ProgressBar = $HUD/PlayerBars/YouSIBar
@onready var _you_fw_bar: ProgressBar = $HUD/PlayerBars/YouFWBar
@onready var _resource_label: Label = $HUD/PlayerBars/ResourceLabel

@onready var _sidebar_opp_name: Label = $HUD/Sidebar/OppName
@onready var _sidebar_you_name: Label = $HUD/Sidebar/YouName
@onready var _timer_label: Label = $HUD/Sidebar/TimerLabel
@onready var _end_turn_btn: Button = $HUD/PlayerBars/EndTurnButton
@onready var _menu_btn: Button = $HUD/Sidebar/MenuButton

@onready var _play_zone: Panel = $HUD/Table/PlayZone
@onready var _hand_hbox: HBoxContainer = $HUD/HandArea/HandHBox

@onready var _opp_recent1: TextureRect = $HUD/Table/PlayZone/ZoneVBox/OppRecent/OppRecent1
@onready var _opp_recent2: TextureRect = $HUD/Table/PlayZone/ZoneVBox/OppRecent/OppRecent2
@onready var _you_recent1: TextureRect = $HUD/Table/PlayZone/ZoneVBox/YouRecent/YouRecent1
@onready var _you_recent2: TextureRect = $HUD/Table/PlayZone/ZoneVBox/YouRecent/YouRecent2

const STARTING_SI := 20
const MAX_FW := 12
const START_HAND := 3
const HAND_LIMIT := 7
const PLAYS_PER_TURN := 2
const MAX_BW := 10
const MAX_LOG_LINES := 6

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

const _CARD_DB := {
	# Defense
	"mfa": {"name": "MULTI-FACTOR AUTH", "type": CardType.DEFENSE, "cost": 1},
	"antivirus": {"name": "ANTIVIRUS CORE", "type": CardType.DEFENSE, "cost": 2},
	"encryption": {"name": "ENCRYPTION KEY", "type": CardType.DEFENSE, "cost": 2},
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

func _ready() -> void:
	var init: Dictionary = {}
	if get_tree().has_meta("tgc_arena_init"):
		init = get_tree().get_meta("tgc_arena_init")
		get_tree().set_meta("tgc_arena_init", null)

	_room_id = str(init.get("room_id", ""))
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
	_timer_label.text = "01:53"

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
	_menu_btn.pressed.connect(func():
		# Menu UX not specified yet; keep button inert for now.
		pass
	)

	_status.text = "Connecting…"
	if _is_host:
		_try_init_host_state_if_possible()
	else:
		_request_state()
	_render()

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

func _build_initial_state(host_id: String, client_id: String) -> Dictionary:
	var host_deck := _make_start_deck()
	var client_deck := _make_start_deck()
	host_deck.shuffle()
	client_deck.shuffle()

	var state := {
		"version": 1,
		"turn": 0,
		"active_player": host_id,
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

	_start_turn(state, host_id)
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
		"status": {},
		"recent_attack": [],
		"recent_defense": [],
		"backdoor_used_turn": -1,
	}

func _make_start_deck() -> Array:
	# Starter deck (16 cards): 2x of everything except DOS/DDOS
	var deck: Array = []
	var starter_ids := [
		"mfa", "antivirus", "encryption", "firewall", "ids",
		"phishing", "virus", "trojan",
	]
	for id in starter_ids:
		deck.append(id)
		deck.append(id)
	return deck

func _start_turn(state: Dictionary, pid: String) -> void:
	state["active_player"] = pid
	state["turn"] = int(state.get("turn", 0)) + 1

	var p: Dictionary = state["players"][pid]
	p["turns_taken"] = int(p.get("turns_taken", 0)) + 1
	p["plays_left"] = PLAYS_PER_TURN

	_apply_start_of_turn_effects(state, pid)
	_maybe_shuffle_packages(state, pid)

	var lag_penalty := 0
	var st: Dictionary = p.get("status", {})
	if st.has("lag"):
		lag_penalty = 1
		st.erase("lag")
		p["status"] = st

	p["bw_max"] = min(int(p.get("bw_max", 0)) + 1, MAX_BW)
	p["bw"] = max(int(p.get("bw_max", 0)) - lag_penalty, 0)

	_draw_card(state, pid)
	_append_log(state, "%s turn" % _name_for(pid))

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
	var card_id: String = str(deck.pop_back())
	p["deck"] = deck
	if hand.size() >= HAND_LIMIT:
		var discard: Array = p.get("discard", [])
		discard.append(card_id)
		p["discard"] = discard
		_append_log(state, "%s burned a card" % _name_for(pid))
		return
	hand.append(card_id)
	p["hand"] = hand

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
		_opp_resource_label.text = "BW 0/0  |  Plays 0/2"
		_resource_label.text = "BW 0/0  |  Plays 0/2"
		_clear_hand_ui()
		_set_recent_textures([], [], [], [])
		return

	var opp_id := _other_player(_player_id)
	var my_val: Variant = _state.get("players", {}).get(_player_id, null)
	var opp_val: Variant = _state.get("players", {}).get(opp_id, null)
	var my: Dictionary = my_val if typeof(my_val) == TYPE_DICTIONARY else {}
	var opp: Dictionary = opp_val if typeof(opp_val) == TYPE_DICTIONARY else {}

	var active := str(_state.get("active_player", ""))
	var is_my_turn := (active == _player_id)
	var winner := str(_state.get("winner_id", ""))
	var over := winner != ""

	_sidebar_opp_name.text = _name_for(opp_id)
	_sidebar_you_name.text = _name_for(_player_id)

	_status.text = "Turn %d | Active: %s" % [int(_state.get("turn", 0)), _name_for(active)]
	if over:
		_status.text = "Game Over | Winner: %s" % _name_for(winner)

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

	_end_turn_btn.disabled = over or (not is_my_turn)

	_render_hand(my, is_my_turn, over)
	_set_recent_textures(
		opp.get("recent_attack", []),
		my.get("recent_defense", []),
		my.get("recent_attack", []),
		opp.get("recent_defense", [])
	)

func _clear_hand_ui() -> void:
	for c in _hand_hbox.get_children():
		c.queue_free()

func _set_recent_textures(opp_attacks: Array, you_defs: Array, _you_attacks: Array, _opp_defs: Array) -> void:
	# Current UI only shows: Opponent recent attacks (red) and Your recent defenses (blue)
	var opp_a := _last_two_ids(opp_attacks)
	var you_d := _last_two_ids(you_defs)
	_opp_recent1.texture = _texture_for_id(opp_a[0])
	_opp_recent2.texture = _texture_for_id(opp_a[1])
	_you_recent1.texture = _texture_for_id(you_d[0])
	_you_recent2.texture = _texture_for_id(you_d[1])

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
		card.custom_minimum_size = Vector2(110, 160)
		card.card_data = {"card_id": card_id, "hand_index": i}
		card.drag_enabled = (not over) and is_my_turn and int(my.get("plays_left", 0)) > 0 and _can_afford_card(my, card_id)
		_hand_hbox.add_child(card)

func _can_afford_card(p: Dictionary, card_id: String) -> bool:
	var cost := _effective_cost(p, card_id)
	return int(p.get("bw", 0)) >= cost

func _on_play_zone_card_dropped(card_data: Dictionary) -> void:
	var card_id := str(card_data.get("card_id", ""))
	var idx := int(card_data.get("hand_index", -1))
	if card_id == "" or idx < 0:
		return
	_send_or_apply_action("play_card", {"hand_index": idx, "card_id": card_id})

func _on_end_turn_pressed() -> void:
	_send_or_apply_action("end_turn", {})


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
			_transition_to_postgame(str(data.get("winner_id", "")), str(data.get("reason", "ended")))
		"tgc_force_loading_sync":
			_transition_to_loading("forced_resync")
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
	var active := str(_state.get("active_player", ""))
	if action != "concede" and actor != active:
		_append_log(_state, "%s tried to act out-of-turn" % _name_for(actor))
		_bump_version(_state)
		return

	match action:
		"play_card":
			_host_play_card(actor, payload)
		"end_turn":
			_host_end_turn(actor)
		"concede":
			_host_concede(actor)
		_:
			_append_log(_state, "Unknown action: %s" % action)
	_bump_version(_state)
	_check_game_over()

func _bump_version(state: Dictionary) -> void:
	state["version"] = int(state.get("version", 0)) + 1
	_local_version = int(state["version"])

func _other_player(pid: String) -> String:
	return _client_id if pid == _host_id else _host_id

func _host_play_card(pid: String, payload: Dictionary) -> void:
	var p: Dictionary = _state["players"][pid]
	if int(p.get("plays_left", 0)) <= 0:
		_append_log(_state, "%s has no plays left" % _name_for(pid))
		return
	var hand: Array = p.get("hand", [])
	var idx := int(payload.get("hand_index", -1))
	var claimed_id := str(payload.get("card_id", ""))
	if idx < 0 or idx >= hand.size():
		_append_log(_state, "%s invalid hand index" % _name_for(pid))
		return
	var card_id := str(hand[idx])
	if claimed_id != "" and claimed_id != card_id:
		_append_log(_state, "%s hand mismatch" % _name_for(pid))
		return
	var def_val: Variant = _CARD_DB.get(card_id, null)
	if typeof(def_val) != TYPE_DICTIONARY:
		_append_log(_state, "Invalid card")
		return
	var def: Dictionary = def_val
	var cost := _effective_cost(p, card_id)
	if int(p.get("bw", 0)) < cost:
		_append_log(_state, "%s lacks BW" % _name_for(pid))
		return

	# If this play benefits from Backdoor discount, consume it for this turn.
	_maybe_consume_backdoor_discount(p, card_id, cost)

	p["bw"] = int(p.get("bw", 0)) - cost
	p["plays_left"] = int(p.get("plays_left", 0)) - 1

	hand.remove_at(idx)
	p["hand"] = hand
	_state["players"][pid] = p

	_apply_card_effect(pid, card_id, def)

func _host_end_turn(pid: String) -> void:
	var next := _other_player(pid)
	_start_turn(_state, next)

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
		call_deferred("_finish_match_host", winner, "hp_zero")

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
	if turns_taken == 4:
		_shuffle_in(state, pid, ["dos", "dos"], "Midgame package deployed")
	elif turns_taken == 6:
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
			st["ids"] = {"turns": 2}
			p["status"] = st
			_append_log(_state, "%s deployed IDS" % _name_for(actor_id))
			_push_recent(p, "recent_defense", card_id)
		"encryption":
			st = p.get("status", {})
			st["encrypted"] = {"turns": 3}
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

	# IDS reduces next Attack by 3 and draws 1
	if defender_status.has("ids"):
		dmg = max(0, dmg - 3)
		defender_status.erase("ids")
		defender["status"] = defender_status
		_state["players"][defender_id] = defender
		_draw_card(_state, defender_id)
		_append_log(_state, "%s IDS reduced damage" % _name_for(defender_id))
		defender = _state["players"][defender_id]

	# Encryption reduces PHISHING/VIRUS/TROJAN by 2
	if defender_status.has("encrypted") and (card_id == "phishing" or card_id == "virus" or card_id == "trojan"):
		dmg = max(0, dmg - 2)

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
	await _post_room_status("finished")
	_broadcast_match_end(winner_id, reason)
	_transition_to_postgame(winner_id, reason)

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

func _broadcast_match_end(winner_id: String, reason: String) -> void:
	if _relay_client == null:
		return
	_relay_client.send_message({
		"type": "tgc_match_end",
		"room_id": _room_id,
		"winner_id": winner_id,
		"reason": reason,
		"timestamp": int(Time.get_unix_time_from_system()),
	})

func _on_relay_disconnected() -> void:
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

func _transition_to_postgame(winner_id: String, reason: String) -> void:
	if get_tree().has_meta("tgc_postgame_init"):
		return
	if _relay_client and _relay_client.has_method("disconnect_from_relay"):
		_relay_client.disconnect_from_relay()
	get_tree().set_meta("tgc_postgame_init", {
		"room_id": _room_id,
		"player_id": _player_id,
		"winner_id": winner_id,
		"reason": reason,
		"lobby_server_url": _lobby_server_url,
		"host_data": _host_data,
		"client_data": _client_data,
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
