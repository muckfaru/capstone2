extends Control

const _TGCSess = preload("res://script/AkashicTCGSessionStore.gd")

# Minimal Postgame screen for Akashic TCG (Milestone 1)

@onready var _title: Label = $TitleLabel
@onready var _result: Label = $ResultLabel
@onready var _details: Label = $DetailsLabel
@onready var _back_btn: Button = $BackButton

var _room_id: String = ""
var _player_id: String = ""
var _winner_id: String = ""
var _reason: String = ""
var _lobby_server_url: String = ""

func _ready() -> void:
	_title.text = "AKASHIC TCG"
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

	var is_winner := (_winner_id != "" and _winner_id == _player_id)
	_result.text = "✅ VICTORY" if is_winner else "❌ DEFEATED"
	_details.text = "Reason: %s\nRoom: %s" % [_reason, _room_id]

	_back_btn.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
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
