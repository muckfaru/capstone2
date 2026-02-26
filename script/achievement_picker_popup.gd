extends Control
class_name AchievementPickerPopup
# =============================================================================
# ACHIEVEMENT PICKER POPUP
# Shown when a player clicks an achievement display slot on their profile.
# Displays all earned achievement badges; player picks one to equip.
#
# Requires scene: res://scene/achievement_picker_popup.tscn
# Signals:
#   achievement_picked(achievement_id)  — player confirmed a selection
#   slot_cleared()                      — player chose to clear the slot
#   popup_closed()                      — popup dismissed without action
# =============================================================================

signal achievement_picked(achievement_id: String)
signal slot_cleared()
signal popup_closed()

# ─────────────────────────────────────────────────────────────────────────────
# Scene node references (wired via .tscn)
# ─────────────────────────────────────────────────────────────────────────────
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _title_label: Label         = $MainPanel/PanelMargin/OuterVBox/HeaderMargin/TitleBar/TitleLabel
@onready var _close_btn: Button          = $MainPanel/PanelMargin/OuterVBox/HeaderMargin/TitleBar/CloseButton
@onready var _badge_grid: GridContainer  = $MainPanel/PanelMargin/OuterVBox/BadgeScroll/GridMargin/BadgeGrid
@onready var _desc_label: Label          = $MainPanel/PanelMargin/OuterVBox/FooterMargin/Footer/DescLabel
@onready var _clear_btn: Button          = $MainPanel/PanelMargin/OuterVBox/FooterMargin/Footer/ButtonRow/ClearButton
@onready var _equip_btn: Button          = $MainPanel/PanelMargin/OuterVBox/FooterMargin/Footer/ButtonRow/EquipButton

# ─────────────────────────────────────────────────────────────────────────────
# Achievement definitions: id → { name, desc, badge }
# Badge paths reuse the same icons already loaded by mode_selection.gd
# ─────────────────────────────────────────────────────────────────────────────
const ACHIEVEMENT_DEFS: Dictionary = {
	"beginner_fundamentals": {
		"name": "Cyber Fundamentalist",
		"desc": "Completed Cybersecurity Fundamentals",
		"badge": "res://asset/icons/cyfunda.png"
	},
	"beginner_network": {
		"name": "Network Navigator",
		"desc": "Completed Network Basics",
		"badge": "res://asset/icons/NBfun.png"
	},
	"advanced_encryption": {
		"name": "Encryption Expert",
		"desc": "Completed Encryption Basics",
		"badge": "res://asset/icons/encryicon.png"
	},
	"beginner_password": {
		"name": "Password Guardian",
		"desc": "Completed Password Fortress Defender",
		"badge": "res://asset/icons/passwordfticon.png"
	},
	"beginner_malware": {
		"name": "Malware Analyst",
		"desc": "Completed Malware Types Overview",
		"badge": "res://asset/icons/malwaretpicon.png"
	},
	"beginner_drop_zone": {
		"name": "Drop Zone Defender",
		"desc": "Completed Drop Zone Defender",
		"badge": "res://asset/icons/drop_zone_icon.png"
	},
	"intermediate_phishing": {
		"name": "Phishing Detective",
		"desc": "Completed Phishing Detection Lab",
		"badge": "res://asset/icons/phishinglbicon.png"
	},
	"intermediate_assetandthreat": {
		"name": "Asset Guardian",
		"desc": "Completed Asset vs Threats",
		"badge": "res://asset/icons/asset_threat_icon.png"
	},
	"intermediate_crypt_contract": {
		"name": "Crypt Contractor",
		"desc": "Completed Crypt Contract",
		"badge": "res://asset/icons/crypt_contract_icon.png"
	},
	"intermediate_incident_commander": {
		"name": "Incident Commander",
		"desc": "Completed Incident Commander",
		"badge": "res://asset/icons/incident_commander_icon.png"
	},
	"advanced_security_guardian": {
		"name": "Security Guardian",
		"desc": "Completed Security Guardian",
		"badge": "res://asset/icons/security_guardian_icon.png"
	},
	"advanced_malware_defense": {
		"name": "Malware Defender",
		"desc": "Completed Malware Defense & Removal",
		"badge": "res://asset/icons/malware_defense_icon.png"
	},
	"advanced_incident_response": {
		"name": "Incident Responder",
		"desc": "Completed CMD Defender",
		"badge": "res://asset/icons/incident_response_icon.png"
	},
}

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _selected_id: String = ""
var _slot_index: int = 0  # which slot (0/1/2) is being edited
var _currently_equipped: String = ""  # id already in this slot
var _card_buttons: Dictionary = {}  # id -> Button (for selection styling)

# ─────────────────────────────────────────────────────────────────────────────
# Show the popup
# slot_index  : 0 / 1 / 2
# current_id  : achievement already equipped in this slot (or "")
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.pressed.connect(_on_close)
	_equip_btn.pressed.connect(_on_equip)
	_clear_btn.pressed.connect(_on_clear)
	hide()


# ─────────────────────────────────────────────────────────────────────────────
# Public API — call this after adding the scene as a child
# slot_index  : 0 / 1 / 2
# current_id  : achievement already equipped in this slot (or "")
# ─────────────────────────────────────────────────────────────────────────────
func show_picker(slot_index: int, current_id: String) -> void:
	_slot_index = slot_index
	_currently_equipped = current_id
	_selected_id = current_id
	_title_label.text = "🏅  Select Achievement Badge — Slot %d" % (_slot_index + 1)
	_desc_label.text = "Select an earned badge to display on your profile."
	_populate_badge_grid()
	show()
	_animate_in()


# ─────────────────────────────────────────────────────────────────────────────
# Populate the badge grid from ACHIEVEMENT_DEFS
# ─────────────────────────────────────────────────────────────────────────────
func _populate_badge_grid() -> void:
	for child in _badge_grid.get_children():
		child.queue_free()
	_card_buttons.clear()

	# Merge completion defs (this script) with stat defs (AchievementManager)
	var all_defs := _get_all_defs()
	var earned_ids := _get_earned_achievement_ids(all_defs)
	for ach_id in all_defs.keys():
		var def: Dictionary = all_defs[ach_id]
		var is_earned: bool = ach_id in earned_ids
		var card := _build_badge_card(ach_id, def, is_earned)
		_badge_grid.add_child(card)
		_card_buttons[ach_id] = card

	if _selected_id != "":
		_highlight_selected(_selected_id)


## Returns merged dict of all achievement defs (completion + stat).
func _get_all_defs() -> Dictionary:
	var all_defs := ACHIEVEMENT_DEFS.duplicate()
	var am := get_node_or_null("/root/AchievementManager")
	if am:
		for id in am.ACHIEVEMENT_DEFS.keys():
			if not all_defs.has(id):
				all_defs[id] = am.ACHIEVEMENT_DEFS[id]
	return all_defs


# ─────────────────────────────────────────────────────────────────────────────
# Build a single badge card button
# ─────────────────────────────────────────────────────────────────────────────
func _build_badge_card(ach_id: String, def: Dictionary, is_earned: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(128, 128)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_earned else Control.CURSOR_ARROW
	btn.disabled = not is_earned
	btn.tooltip_text = def["name"] + "\n" + def["desc"] if is_earned else "🔒 " + def["name"] + " (Not yet earned)"

	# Card background style
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.08, 0.15, 0.9) if is_earned else Color(0.05, 0.05, 0.08, 0.6)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0, 0.7, 1, 0.5) if is_earned else Color(0.3, 0.3, 0.3, 0.3)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("focus", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.1, 0.18, 0.28, 0.95)
	hover_style.border_color = Color(0, 1, 1, 0.9)
	hover_style.shadow_color = Color(0, 1, 1, 0.3)
	hover_style.shadow_size = 6
	btn.add_theme_stylebox_override("hover", hover_style)

	# Inner VBox: icon + name
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	btn.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(def["badge"]):
		icon_rect.texture = load(def["badge"])
	if not is_earned:
		icon_rect.modulate = Color(0.35, 0.35, 0.35, 0.7)
	vbox.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = def["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color",
		Color(0.85, 0.95, 1.0) if is_earned else Color(0.45, 0.45, 0.45))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	if not is_earned:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 20)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.set_anchors_preset(Control.PRESET_CENTER)
		lock_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lock_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_lbl)

	# Connect click
	btn.pressed.connect(func(): _on_badge_selected(ach_id, def))
	return btn


# ─────────────────────────────────────────────────────────────────────────────
# Highlight the selected card
# ─────────────────────────────────────────────────────────────────────────────
func _highlight_selected(ach_id: String) -> void:
	for id in _card_buttons.keys():
		var btn: Button = _card_buttons[id]
		if not is_instance_valid(btn):
			continue
		var earned: bool = not btn.disabled
		if id == ach_id and earned:
			var sel_style := StyleBoxFlat.new()
			sel_style.bg_color = Color(0.05, 0.2, 0.08, 0.95)
			sel_style.border_width_left = 3
			sel_style.border_width_top = 3
			sel_style.border_width_right = 3
			sel_style.border_width_bottom = 3
			sel_style.border_color = Color(0, 1, 0.5, 1.0)
			sel_style.corner_radius_top_left = 8
			sel_style.corner_radius_top_right = 8
			sel_style.corner_radius_bottom_left = 8
			sel_style.corner_radius_bottom_right = 8
			sel_style.shadow_color = Color(0, 1, 0.5, 0.5)
			sel_style.shadow_size = 8
			btn.add_theme_stylebox_override("normal", sel_style)
			btn.add_theme_stylebox_override("hover", sel_style)
			btn.add_theme_stylebox_override("focus", sel_style)
		else:
			# Restore unselected style
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0.08, 0.08, 0.15, 0.9) if earned else Color(0.05, 0.05, 0.08, 0.6)
			normal_style.border_width_left = 2
			normal_style.border_width_top = 2
			normal_style.border_width_right = 2
			normal_style.border_width_bottom = 2
			normal_style.border_color = Color(0, 0.7, 1, 0.5) if earned else Color(0.3, 0.3, 0.3, 0.3)
			normal_style.corner_radius_top_left = 8
			normal_style.corner_radius_top_right = 8
			normal_style.corner_radius_bottom_left = 8
			normal_style.corner_radius_bottom_right = 8
			btn.add_theme_stylebox_override("normal", normal_style)
			var hover_style := normal_style.duplicate()
			hover_style.bg_color = Color(0.1, 0.18, 0.28, 0.95)
			hover_style.border_color = Color(0, 1, 1, 0.9)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("focus", normal_style)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _get_earned_achievement_ids(all_defs: Dictionary = {}) -> Array:
	if all_defs.is_empty():
		all_defs = _get_all_defs()
	var earned: Array = []
	var am := get_node_or_null("/root/AchievementManager")
	for ach_id in all_defs.keys():
		var unlocked := false
		if TutorialManager and (
			TutorialManager.completed_tutorials.has(ach_id)
			or TutorialManager.completed_minigames.has(ach_id)
		):
			unlocked = true
		if not unlocked and am and am.is_unlocked(ach_id):
			unlocked = true
		if unlocked:
			earned.append(ach_id)
	return earned


func _animate_in() -> void:
	modulate.a = 0.0
	_main_panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_main_panel, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────────────────────────────────────
# Callbacks
# ─────────────────────────────────────────────────────────────────────────────
func _on_badge_selected(ach_id: String, def: Dictionary) -> void:
	_selected_id = ach_id
	_highlight_selected(ach_id)
	_desc_label.text = "Selected: %s — %s" % [def["name"], def["desc"]]


func _on_equip() -> void:
	if _selected_id == "":
		return
	achievement_picked.emit(_selected_id)
	_close_animated()


func _on_clear() -> void:
	slot_cleared.emit()

	_close_animated()


func _on_close() -> void:
	popup_closed.emit()
	_close_animated()


func _close_animated() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	await tween.finished
	queue_free()
