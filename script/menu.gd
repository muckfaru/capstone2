extends Control

# Simple draggable menu: full-screen overlay blocks input; drag the header of the window; close with X.

signal exit_match_requested

@onready var window_panel: Panel = $Window
@onready var header_panel: Panel = $Window/Panel
@onready var close_button: Button = $Window/Panel/CloseMenuButton
@onready var overlay: ColorRect = $Overlay
@onready var menu_logout_button: Button = $Window/Body/LogoutButton
@onready var settings_button: Button = $Window/Body/SettingsButton
@onready var exit_match_button: Button = $Window/Body/ExitMatchButton

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _confirm_popup: Control = null  # Custom styled popup

# Set this to true from the arena scene to show the exit button
var show_exit_button: bool = true:
	set(value):
		show_exit_button = value
		_apply_exit_button_visibility()

func _ready() -> void:
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.focus_mode = Control.FOCUS_NONE
	if header_panel and not header_panel.gui_input.is_connected(_on_header_gui_input):
		header_panel.gui_input.connect(_on_header_gui_input)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if menu_logout_button and not menu_logout_button.pressed.is_connected(_on_menu_logout_pressed):
		menu_logout_button.pressed.connect(_on_menu_logout_pressed)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if exit_match_button and not exit_match_button.pressed.is_connected(_on_exit_match_pressed):
		exit_match_button.pressed.connect(_on_exit_match_pressed)

	# Auto-detect if we're on a landing/lobby scene (no active match)
	# Hide the exit button by default; arena scenes will call show_exit_button = true
	_auto_detect_scene()

func _auto_detect_scene() -> void:
	var current_scene := get_tree().get_current_scene()
	if current_scene == null:
		_apply_exit_button_visibility()
		return

	var scene_path := current_scene.scene_file_path.to_lower()
	var is_arena := (
		scene_path.contains("arena") or
		scene_path.contains("_arena") or
		scene_path.contains("code_breaker_arena") or
		scene_path.contains("akashic_tcg_arena") or
		scene_path.contains("defuse_trojan") and not scene_path.contains("postgame")
	)
	show_exit_button = is_arena

func _apply_exit_button_visibility() -> void:
	if exit_match_button:
		exit_match_button.visible = show_exit_button

func _on_close_pressed() -> void:
	visible = false


func _on_menu_logout_pressed() -> void:
	Auth.set_user_offline()
	TutorialManager.reset_data()
	get_tree().change_scene_to_file("res://scene/login.tscn")


func _on_settings_pressed() -> void:
	var settings_scene = preload("res://scene/SettingsPanel.tscn")
	var inst = settings_scene.instantiate()
	var cs = get_tree().get_current_scene()
	if cs:
		cs.add_child(inst)
		var music_target: Node = null
		if cs.has_node("BackgroundMusicPlayer"):
			music_target = cs.get_node("BackgroundMusicPlayer")
		elif cs.has_node("BackgroundMusic"):
			music_target = cs.get_node("BackgroundMusic")
		elif cs.has_node("BattleMusic"):
			music_target = cs.get_node("BattleMusic")
		if music_target and inst.has_method("set_target_music"):
			inst.set_target_music(music_target)
	visible = false


func _on_exit_match_pressed() -> void:
	# Prevent duplicate popups
	if _confirm_popup and is_instance_valid(_confirm_popup):
		return

	var popup_scene = load("res://scene/exit_confirm_popup.tscn")
	if popup_scene == null:
		push_error("[Menu] exit_confirm_popup.tscn not found — place it in res://scene/")
		return

	_confirm_popup = popup_scene.instantiate()
	get_tree().root.add_child(_confirm_popup)
	_confirm_popup.visible = true

	# Wire buttons — paths match exit_confirm_popup.tscn BottomBar layout
	var forfeit_btn: Button = _confirm_popup.get_node_or_null("CenterContainer/PopupPanel/BottomBar/ButtonRow/ForfeitButton")
	var cancel_btn: Button  = _confirm_popup.get_node_or_null("CenterContainer/PopupPanel/BottomBar/ButtonRow/CancelButton")
	var close_btn: Button   = _confirm_popup.get_node_or_null("CenterContainer/PopupPanel/Header/CloseButton")
	var overlay_node        = _confirm_popup.get_node_or_null("Overlay")

	# Debug: warn if any node wasn't found so path mismatches are obvious
	if not forfeit_btn: push_warning("[Menu] ForfeitButton not found in popup — check node path")
	if not cancel_btn:  push_warning("[Menu] CancelButton not found in popup — check node path")
	if not close_btn:   push_warning("[Menu] CloseButton not found in popup — check node path")

	if forfeit_btn:
		forfeit_btn.pressed.connect(_on_exit_confirmed, CONNECT_ONE_SHOT)
	if cancel_btn:
		cancel_btn.pressed.connect(_close_confirm_popup, CONNECT_ONE_SHOT)
	if close_btn:
		close_btn.pressed.connect(_close_confirm_popup, CONNECT_ONE_SHOT)
	if overlay_node:
		overlay_node.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_close_confirm_popup()
		)

	# Entrance animation
	_confirm_popup.modulate.a = 0.0
	var popup_panel = _confirm_popup.get_node_or_null("CenterContainer/PopupPanel")
	if popup_panel:
		popup_panel.scale = Vector2(0.85, 0.85)
		popup_panel.pivot_offset = popup_panel.custom_minimum_size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_confirm_popup, "modulate:a", 1.0, 0.22)
	if popup_panel:
		tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_confirm_popup() -> void:
	if not _confirm_popup or not is_instance_valid(_confirm_popup):
		_confirm_popup = null
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_confirm_popup, "modulate:a", 0.0, 0.18)
	var popup_panel = _confirm_popup.get_node_or_null("CenterContainer/PopupPanel")
	if popup_panel:
		tween.tween_property(popup_panel, "scale", Vector2(0.85, 0.85), 0.18)
	await tween.finished
	if is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	_confirm_popup = null


func _on_exit_confirmed() -> void:
	if _confirm_popup and is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	_confirm_popup = null
	visible = false
	print("[Menu] ⚔️ Exit match confirmed — emitting exit_match_requested")
	exit_match_requested.emit()


func _input(event: InputEvent) -> void:
	# ESC closes the confirm popup if it's open, otherwise closes the menu
	if event.is_action_pressed("ui_cancel"):
		if _confirm_popup and is_instance_valid(_confirm_popup):
			_close_confirm_popup()
			get_viewport().set_input_as_handled()
		elif visible:
			visible = false
			get_viewport().set_input_as_handled()


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - window_panel.global_position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var new_pos := motion.position - _drag_offset
		var vp := get_viewport().get_visible_rect()
		new_pos.x = clamp(new_pos.x, 0.0, max(0.0, vp.size.x - window_panel.size.x))
		new_pos.y = clamp(new_pos.y, 0.0, max(0.0, vp.size.y - window_panel.size.y))
		window_panel.global_position = new_pos
		accept_event()


func _clamp_to_viewport() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var pos := window_panel.global_position
	var sz := window_panel.size
	pos.x = clamp(pos.x, 0.0, max(0.0, vp_rect.size.x - sz.x))
	pos.y = clamp(pos.y, 0.0, max(0.0, vp_rect.size.y - sz.y))
	window_panel.global_position = pos
