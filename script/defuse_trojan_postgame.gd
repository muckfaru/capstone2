@tool
extends Control

# This post-game screen intentionally reuses the Code Breaker postgame UI scene
# (via scene inheritance) to keep the same visual design.

@onready var _title_label: Label = $TitleLabel

# Cards are at root level in parent scene (code_breaker_postgame.tscn)
@onready var _host_card: NinePatchRect = $HostCard
@onready var _client_card: NinePatchRect = $ClientCard
var _client2_card: NinePatchRect = null  # Created at runtime by duplicating ClientCard

@onready var _cards_container: Control = get_node_or_null("NinePatchRect/pstpnl") as Control

@onready var _back_button: Button = $BackToLandingButton

# Host fields (access via card reference for clarity)
func _get_host_username() -> Label: return _host_card.get_node("HostUsername") as Label
func _get_host_status() -> Label: return _host_card.get_node("HostStatus") as Label
func _get_host_wave() -> Label: return _host_card.get_node("HostXP") as Label
func _get_host_time() -> Label: return _host_card.get_node("HostTime") as Label
func _get_host_score() -> Label: return _host_card.get_node("HostPowerups") as Label
func _get_host_wpm() -> Label: return _host_card.get_node("HostWPM") as Label
func _get_host_accuracy() -> Label: return _host_card.get_node("HostAccuracy") as Label
func _get_host_streak() -> Label: return _host_card.get_node("HostWrongSubmissions") as Label

# Game init data
var _init: Dictionary = {}
var _relay_client: Node = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_title_label.text = "DEFUSE THE TROJAN"
		_create_styled_client2_card()
		_hide_unused_stat_rows()
		return

	# Pull init payload
	if get_tree().has_meta("defuse_trojan_postgame_init"):
		_init = get_tree().get_meta("defuse_trojan_postgame_init")
		get_tree().set_meta("defuse_trojan_postgame_init", null)

	_title_label.text = "DEFUSE THE TROJAN"

	var relay_any = _init.get("relay_client", null)
	if relay_any != null and is_instance_valid(relay_any):
		_relay_client = relay_any
		if _relay_client.get_parent() == get_tree().root:
			_relay_client.get_parent().remove_child(_relay_client)
			add_child(_relay_client)
	else:
		_relay_client = null

	_back_button.pressed.connect(_on_back_pressed)

	_create_styled_client2_card()
	_hide_unused_stat_rows()
	_apply_results()


func _create_styled_client2_card() -> void:
	# Safety check - _client_card must exist
	if not is_instance_valid(_client_card):
		push_warning("[DefuseTrojanPostgame] _client_card is null, cannot create ClientCard2")
		return
	
	# Remove any existing ClientCard2
	if _client2_card and is_instance_valid(_client2_card):
		_client2_card.queue_free()
		_client2_card = null
	
	# Create a styled duplicate of ClientCard
	_client2_card = _client_card.duplicate() as NinePatchRect
	_client2_card.name = "ClientCard2"
	_client2_card.visible = true
	
	# Add to same parent as other cards
	var parent := _client_card.get_parent()
	if parent:
		parent.add_child(_client2_card)
	else:
		add_child(_client2_card)
	
	# Set proper layout properties
	_client2_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_client2_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_client2_card.custom_minimum_size = Vector2(280, 400)
	
	# Set placeholder text for Player 3
	var uname = _client2_card.get_node_or_null("ClientUsername") as Label
	if uname:
		uname.text = "Player 3"


func _get_cards_container() -> Control:
	if _cards_container != null:
		return _cards_container
	return self


func _layout_three_cards() -> void:
	# Layout is driven by the .tscn (`CenterContainer` + `HBoxContainer`).
	# Keep this as a no-op hook in case we want runtime adjustments later.
	pass


func _hide_unused_stat_rows() -> void:
	# We only show: MODE, WAVE, TIME, SCORE, WPM, ACCURACY, STREAK.
	# Hide unused rows on host card
	for node_name in ["HostAvgTime", "HostFastestTime", "HostDamageStats", "HostComebackBadge"]:
		var n = _host_card.get_node_or_null(node_name)
		if n:
			n.visible = false
	# Hide unused rows on client card
	for node_name in ["ClientAvgTime", "ClientFastestTime", "ClientDamageStats", "ClientComebackBadge"]:
		var n = _client_card.get_node_or_null(node_name)
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
		_get_host_username().text = "Player"
		_get_host_status().text = "MODE: %s" % mode.to_upper()
		_get_host_wave().text = "WAVE: %d" % wave_reached
		_get_host_time().text = "TIME: %s" % _format_duration(duration_ms)
		_get_host_score().text = "SCORE: 0"
		_get_host_wpm().text = "WPM: 0.0"
		_get_host_accuracy().text = "ACC: 0.0%"
		_get_host_streak().text = "STREAK: 0"

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
