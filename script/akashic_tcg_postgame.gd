extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")

# UI References (match Code Breaker postgame design)
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_xp: Label = $HostCard/HostXP
@onready var _host_time: Label = $HostCard/HostTime
@onready var _host_cards_used: OptionButton = $HostCard/HostPowerups
@onready var _host_winner_badge: Label = $HostCard/WinnerBadge

@onready var _client_username: Label = $ClientCard/ClientUsername
@onready var _client_status: Label = $ClientCard/ClientStatus
@onready var _client_xp: Label = $ClientCard/ClientXP
@onready var _client_time: Label = $ClientCard/ClientTime
@onready var _client_cards_used: OptionButton = $ClientCard/ClientPowerups
@onready var _client_winner_badge: Label = $ClientCard/WinnerBadge

@onready var _room_time_label: Label = $RoomTimeLabel

@onready var _back_button: Button = $BackToLandingButton

var _room_id: String = ""
var _player_id: String = ""
var _winner_id: String = ""
var _reason: String = ""
var _lobby_server_url: String = ""
var _host_data: Dictionary = {}
var _client_data: Dictionary = {}

var _ended_at_unix: int = 0
var _host_cards_used_ids: Array = []
var _client_cards_used_ids: Array = []

const XP_WIN := 200
const XP_LOSE := -50
const TOTAL_DECK_CARDS := 25

const _SFX_VICTORY: AudioStream = preload("res://asset/audio/akashic sfx/player victory.wav")
const _SFX_DEFEAT: AudioStream = preload("res://asset/audio/akashic sfx/player defeat.wav")

var _outcome_sfx_player: AudioStreamPlayer = null
var _outcome_sfx_played: bool = false

const COLOR_WINNER := Color(1, 0.84, 0, 1)
const COLOR_LOSER := Color(1, 0.36, 0.43, 1)
const COLOR_XP_WIN := Color(0, 1, 0.5, 1)
const COLOR_XP_LOSE := Color(0.8, 0.8, 0.8, 1)

func _ready() -> void:
	# Postgame means the session is over; don't attempt to auto-resume.
	_TGCSess.clear_session()

	var init: Dictionary = {}
	if get_tree().has_meta("tgc_postgame_init"):
		init = get_tree().get_meta("tgc_postgame_init")
		get_tree().set_meta("tgc_postgame_init", null)

	_room_id = str(init.get("room_id", ""))
	_player_id = str(init.get("player_id", ""))
	_winner_id = str(init.get("winner_id", ""))
	_reason = str(init.get("reason", ""))
	_lobby_server_url = str(init.get("lobby_server_url", ""))
	_host_data = init.get("host_data", {})
	_client_data = init.get("client_data", {})
	_ended_at_unix = int(init.get("ended_at_unix", 0))
	_host_cards_used_ids = init.get("host_cards_used", [])
	_client_cards_used_ids = init.get("client_cards_used", [])

	_setup_ui()
	_play_outcome_sfx()
	_back_button.pressed.connect(_on_back_to_landing_pressed)
	_animate_in()


func _play_outcome_sfx() -> void:
	if _outcome_sfx_played:
		return
	_outcome_sfx_played = true
	if _winner_id.strip_edges() == "" or _player_id.strip_edges() == "":
		return
	if _outcome_sfx_player == null or not is_instance_valid(_outcome_sfx_player):
		_outcome_sfx_player = AudioStreamPlayer.new()
		add_child(_outcome_sfx_player)
	var local_won: bool = (_winner_id == _player_id)
	_outcome_sfx_player.stream = _SFX_VICTORY if local_won else _SFX_DEFEAT
	_outcome_sfx_player.play()


func _setup_ui() -> void:
	var host_pid: String = str(_host_data.get("player_id", ""))
	var client_pid: String = str(_client_data.get("player_id", ""))
	var host_won: bool = (_winner_id != "" and _winner_id == host_pid)
	var client_won: bool = (_winner_id != "" and _winner_id == client_pid)

	_host_winner_badge.visible = false
	_client_winner_badge.visible = false

	_host_username.text = str(_host_data.get("username", "Host"))
	_client_username.text = str(_client_data.get("username", "Client"))

	_host_status.text = ("✅ VICTORY" if host_won else "❌ DEFEATED")
	_client_status.text = ("✅ VICTORY" if client_won else "❌ DEFEATED")
	_host_status.add_theme_color_override("font_color", COLOR_WINNER if host_won else COLOR_LOSER)
	_client_status.add_theme_color_override("font_color", COLOR_WINNER if client_won else COLOR_LOSER)

	# EXP rules (per your spec): winner +200, loser -50
	var host_xp_delta: int = XP_WIN if host_won else XP_LOSE
	var client_xp_delta: int = XP_WIN if client_won else XP_LOSE
	_host_xp.text = "EXP: %s%d" % ["+" if host_xp_delta >= 0 else "", host_xp_delta]
	_client_xp.text = "EXP: %s%d" % ["+" if client_xp_delta >= 0 else "", client_xp_delta]
	_host_xp.add_theme_color_override("font_color", COLOR_XP_WIN if host_won else COLOR_XP_LOSE)
	_client_xp.add_theme_color_override("font_color", COLOR_XP_WIN if client_won else COLOR_XP_LOSE)

	# Room + finish time
	_update_room_time_label()

	# Total cards (deck size) + dropdown list (cards used)
	_host_time.text = "Total Cards: %d" % TOTAL_DECK_CARDS
	_client_time.text = "Total Cards: %d" % TOTAL_DECK_CARDS
	_populate_cards_used_dropdown(_host_cards_used, _host_cards_used_ids)
	_populate_cards_used_dropdown(_client_cards_used, _client_cards_used_ids)

	if host_won:
		_host_winner_badge.visible = true
	if client_won:
		_client_winner_badge.visible = true


func _update_room_time_label() -> void:
	if _room_time_label == null:
		return
	var room_txt := (_room_id if _room_id != "" else "-")
	var time_txt := "-"
	var ended := _ended_at_unix
	if ended <= 0:
		ended = int(Time.get_unix_time_from_system())
	var dt := Time.get_datetime_dict_from_unix_time(ended)
	if typeof(dt) == TYPE_DICTIONARY and dt.has("hour"):
		time_txt = "%02d:%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0)), int(dt.get("second", 0))]
	_room_time_label.text = "Room: %s   |   Time: %s" % [room_txt, time_txt]


func _card_display_name(card_id: String) -> String:
	var id := card_id.strip_edges()
	match id:
		"mfa":
			return "MFA"
		"ids":
			return "IDS"
		"encryption":
			return "Encryption Key"
		"firewall":
			return "Firewall Shield"
		"antivirus":
			return "Antivirus Core"
		"phishing":
			return "Phishing"
		"virus":
			return "Virus"
		"trojan":
			return "Trojan Horse"
		"dos":
			return "DOS"
		"ddos":
			return "DDOS"
		_:
			return id.to_upper()


func _populate_cards_used_dropdown(dropdown: OptionButton, cards_used_ids: Array) -> void:
	if dropdown == null:
		return
	dropdown.clear()
	var total: int = cards_used_ids.size()
	dropdown.add_item("Cards Used (%d)" % total)
	if total <= 0:
		return
	# Aggregate counts so the dropdown stays readable.
	var counts: Dictionary = {}
	for v in cards_used_ids:
		var cid := str(v)
		if cid.strip_edges() == "":
			continue
		counts[cid] = int(counts.get(cid, 0)) + 1
	# Stable-ish order: display in the order they first appeared.
	var seen: Dictionary = {}
	for v in cards_used_ids:
		var cid := str(v)
		if cid.strip_edges() == "" or seen.has(cid):
			continue
		seen[cid] = true
		var n: int = int(counts.get(cid, 0))
		dropdown.add_item("%s x%d" % [_card_display_name(cid), n])


func _animate_in() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	var host_card := $HostCard
	host_card.modulate.a = 0.0
	tween.tween_property(host_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(host_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))

	var client_card := $ClientCard
	client_card.modulate.a = 0.0
	tween.tween_property(client_card, "modulate:a", 1.0, 0.5)
	tween.tween_property(client_card, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.8, 0.8))

	_back_button.modulate.a = 0.0
	await tween.finished

	tween = create_tween()
	tween.tween_property(_back_button, "modulate:a", 1.0, 0.3)


func _on_back_to_landing_pressed() -> void:
	await _leave_room_best_effort()
	var landing := load("res://scene/landing.tscn")
	if landing:
		get_tree().change_scene_to_packed(landing)


func _leave_room_best_effort() -> void:
	if _lobby_server_url == "" or _room_id == "" or _player_id == "":
		return
	var http := HTTPRequest.new()
	add_child(http)
	var done := {"ok": false}
	http.request_completed.connect(func(_r, _code, _h, _b):
		done["ok"] = true
		http.queue_free()
	)
	var url := _lobby_server_url + "/api/rooms/" + _room_id + "/leave"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"player_id": _player_id}))
	while not done["ok"]:
		await get_tree().create_timer(0.1).timeout
