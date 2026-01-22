extends Control

# This post-game screen intentionally reuses the Code Breaker postgame UI scene
# (via scene inheritance) to keep the same visual design.

@onready var _title_label: Label = $TitleLabel

@onready var _host_card: NinePatchRect = $HostCard
@onready var _client_card: NinePatchRect = $ClientCard
var _client2_card: NinePatchRect = null

@onready var _back_button: Button = $BackToLandingButton

# Host fields
@onready var _host_username: Label = $HostCard/HostUsername
@onready var _host_status: Label = $HostCard/HostStatus
@onready var _host_wave: Label = $HostCard/HostXP
@onready var _host_time: Label = $HostCard/HostTime
@onready var _host_score: Label = $HostCard/HostPowerups
@onready var _host_wpm: Label = $HostCard/HostWPM
@onready var _host_accuracy: Label = $HostCard/HostAccuracy
@onready var _host_streak: Label = $HostCard/HostWrongSubmissions

# Game init data
var _init: Dictionary = {}
var _relay_client: Node = null

func _ready() -> void:
	# Pull init payload
	if get_tree().has_meta("defuse_trojan_postgame_init"):
		_init = get_tree().get_meta("defuse_trojan_postgame_init")
		get_tree().set_meta("defuse_trojan_postgame_init", null)

	_title_label.text = "DEFUSE THE TROJAN"

	_relay_client = _init.get("relay_client", null)
	if _relay_client and _relay_client.get_parent() == get_tree().root:
		_relay_client.get_parent().remove_child(_relay_client)
		add_child(_relay_client)

	_back_button.pressed.connect(_on_back_pressed)

	# Create a 3rd card by duplicating ClientCard so styles match.
	_ensure_third_card()
	_layout_three_cards()
	_hide_unused_stat_rows()
	_apply_results()


func _ensure_third_card() -> void:
	if has_node("ClientCard2"):
		_client2_card = $ClientCard2
		return
	_client2_card = _client_card.duplicate()
	_client2_card.name = "ClientCard2"
	add_child(_client2_card)


func _layout_three_cards() -> void:
	# Host stays left; move ClientCard to center; ClientCard2 stays right.
	# HostCard already positioned in inherited scene.
	_client_card.anchors_preset = Control.PRESET_CENTER
	_client_card.anchor_left = 0.5
	_client_card.anchor_top = 0.5
	_client_card.anchor_right = 0.5
	_client_card.anchor_bottom = 0.5
	_client_card.offset_left = -200.0
	_client_card.offset_right = 200.0
	_client_card.offset_top = -190.0
	_client_card.offset_bottom = 17.0
	_client_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_client_card.grow_vertical = Control.GROW_DIRECTION_BOTH

	if _client2_card == null:
		return
	_client2_card.anchors_preset = Control.PRESET_CENTER_RIGHT
	_client2_card.anchor_left = 1.0
	_client2_card.anchor_top = 0.5
	_client2_card.anchor_right = 1.0
	_client2_card.anchor_bottom = 0.5
	_client2_card.offset_left = -500.0
	_client2_card.offset_right = -100.0
	_client2_card.offset_top = -190.0
	_client2_card.offset_bottom = 17.0
	_client2_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_client2_card.grow_vertical = Control.GROW_DIRECTION_BOTH


func _hide_unused_stat_rows() -> void:
	# We only show: MODE, WAVE, TIME, SCORE, WPM, ACCURACY, STREAK.
	for path in [
		"HostCard/HostAvgTime",
		"HostCard/HostFastestTime",
		"HostCard/HostDamageStats",
		"HostCard/HostComebackBadge",
		"ClientCard/ClientAvgTime",
		"ClientCard/ClientFastestTime",
		"ClientCard/ClientDamageStats",
		"ClientCard/ClientComebackBadge",
	]:
		var n = get_node_or_null(path)
		if n:
			n.visible = false
	if _client2_card:
		for node_name in ["ClientAvgTime", "ClientFastestTime", "ClientDamageStats", "ClientComebackBadge"]:
			var n2 = _client2_card.get_node_or_null(node_name)
			if n2:
				n2.visible = false


func _apply_results() -> void:
	var mode := str(_init.get("mode", "solo"))
	var duration_ms := int(_init.get("duration_ms", 0))
	var wave_reached := int(_init.get("wave_reached", 1))

	var players: Array = _init.get("players", [])
	var stats_by_pid: Dictionary = _init.get("stats_by_player_id", {})

	# Host card
	if players.size() >= 1:
		_apply_card(_host_card, true, players[0], mode, duration_ms, wave_reached, stats_by_pid)
	else:
		_host_username.text = "Player"
		_host_status.text = "MODE: %s" % mode.to_upper()
		_host_wave.text = "WAVE: %d" % wave_reached
		_host_time.text = "TIME: %s" % _format_duration(duration_ms)
		_host_score.text = "SCORE: 0"
		_host_wpm.text = "WPM: 0.0"
		_host_accuracy.text = "ACC: 0.0%"
		_host_streak.text = "STREAK: 0"

	# Client card 1
	if players.size() >= 2:
		_client_card.visible = true
		_apply_card(_client_card, false, players[1], mode, duration_ms, wave_reached, stats_by_pid)
	else:
		_client_card.visible = false

	# Client card 2
	if _client2_card:
		if players.size() >= 3:
			_client2_card.visible = true
			_apply_card(_client2_card, false, players[2], mode, duration_ms, wave_reached, stats_by_pid)
		else:
			_client2_card.visible = false


func _apply_card(card: NinePatchRect, is_host: bool, player: Dictionary, mode: String, duration_ms: int, wave_reached: int, stats_by_pid: Dictionary) -> void:
	var pid := str(player.get("player_id", ""))
	var uname := str(player.get("username", "Player"))
	var st: Dictionary = stats_by_pid.get(pid, {})

	var score := int(st.get("score", 0))
	var wpm := float(st.get("wpm", 0.0))
	var acc := float(st.get("accuracy_pct", 0.0))
	var streak := int(st.get("longest_streak", 0))

	if is_host:
		(card.get_node("HostUsername") as Label).text = uname
		(card.get_node("HostStatus") as Label).text = "MODE: %s" % mode.to_upper()
		(card.get_node("HostXP") as Label).text = "WAVE: %d" % wave_reached
		(card.get_node("HostTime") as Label).text = "TIME: %s" % _format_duration(duration_ms)
		(card.get_node("HostPowerups") as Label).text = "SCORE: %d" % score
		(card.get_node("HostWPM") as Label).text = "WPM: %.1f" % wpm
		(card.get_node("HostAccuracy") as Label).text = "ACC: %.1f%%" % acc
		(card.get_node("HostWrongSubmissions") as Label).text = "STREAK: %d" % streak
		var badge = card.get_node_or_null("WinnerBadge")
		if badge:
			badge.visible = false
	else:
		(card.get_node("ClientUsername") as Label).text = uname
		(card.get_node("ClientStatus") as Label).text = "MODE: %s" % mode.to_upper()
		(card.get_node("ClientXP") as Label).text = "WAVE: %d" % wave_reached
		(card.get_node("ClientTime") as Label).text = "TIME: %s" % _format_duration(duration_ms)
		(card.get_node("ClientPowerups") as Label).text = "SCORE: %d" % score
		(card.get_node("ClientWPM") as Label).text = "WPM: %.1f" % wpm
		(card.get_node("ClientAccuracy") as Label).text = "ACC: %.1f%%" % acc
		(card.get_node("ClientWrongSubmissions") as Label).text = "STREAK: %d" % streak
		var badge2 = card.get_node_or_null("WinnerBadge")
		if badge2:
			badge2.visible = false


func _format_duration(duration_ms: int) -> String:
	var total_seconds := int(round(duration_ms / 1000.0))
	if total_seconds < 0:
		total_seconds = 0
	var minutes: int = int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	return "%dm %02ds" % [minutes, seconds]


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/landing.tscn")
