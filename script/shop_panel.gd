# shop_panel.gd
# Full-screen shop overlay — UI lives in scene/shop_panel.tscn.
# Displays ShopManager catalog in 3 tabs (Avatars, Backgrounds, Skins)
# with buy / equip / preview.
# ============================================================================
extends Control

signal shop_closed

# ── Scene node references ────────────────────────────────────────────────────
@onready var back_btn: Button = $RootMargin/MainVBox/TopBar/BackButton
@onready var title_label: Label = $RootMargin/MainVBox/TopBar/TitleLabel
@onready var _coin_label: Label = $RootMargin/MainVBox/TopBar/CoinLabel

@onready var _tab_avatar_btn: Button = $RootMargin/MainVBox/TabBar/TabAvatars
@onready var _tab_bg_btn: Button = $RootMargin/MainVBox/TabBar/TabBackgrounds
@onready var _tab_skin_btn: Button = $RootMargin/MainVBox/TabBar/TabSkins

@onready var grid_scroll: ScrollContainer = $RootMargin/MainVBox/ContentSplit/GridScroll
@onready var _grid: GridContainer = $RootMargin/MainVBox/ContentSplit/GridScroll/ItemGrid

@onready var detail_panel: PanelContainer = $RootMargin/MainVBox/ContentSplit/DetailPanel
@onready var _detail_icon: TextureRect = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/DetailIcon
@onready var _detail_name: Label = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/DetailName
@onready var _detail_rarity: Label = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/DetailRarity
@onready var _detail_desc: Label = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/DetailDesc
@onready var _detail_price: Label = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/DetailPrice
@onready var _detail_action_btn: Button = $RootMargin/MainVBox/ContentSplit/DetailPanel/DetailVBox/ActionButton

# ── State ────────────────────────────────────────────────────────────────────
var _selected_item_id: String = ""
var _current_category: String = "avatar"

# ── Rarity colours ───────────────────────────────────────────────────────────
const RARITY_COLORS := {
	"common":    Color(0.6, 0.6, 0.6),
	"uncommon":  Color(0.2, 0.8, 0.2),
	"rare":      Color(0.2, 0.5, 1.0),
	"epic":      Color(0.7, 0.2, 1.0),
	"legendary": Color(1.0, 0.8, 0.0),
}

# ── Tab StyleBoxes (cached from .tscn sub-resources) ────────────────────────
var _tab_style_active: StyleBoxFlat
var _tab_style_inactive: StyleBoxFlat

# ── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Cache tab styles from scene (TabAvatars starts active, TabBackgrounds starts inactive)
	_tab_style_active = _tab_avatar_btn.get_theme_stylebox("normal").duplicate()
	_tab_style_inactive = _tab_bg_btn.get_theme_stylebox("normal").duplicate()
	visible = false


func show_shop() -> void:
	visible = true
	_update_coin_display()
	_select_category(_current_category)


func hide_shop() -> void:
	visible = false
	shop_closed.emit()


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  T A B   C A L L B A C K S  (connected via .tscn signals)               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
func _on_tab_avatars() -> void:
	_select_category("avatar")

func _on_tab_backgrounds() -> void:
	_select_category("background")

func _on_tab_skins() -> void:
	_select_category("skin")


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  C A T E G O R Y   S W I T C H                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
func _select_category(cat: String) -> void:
	_current_category = cat
	_selected_item_id = ""

	# Highlight active tab
	for btn in [_tab_avatar_btn, _tab_bg_btn, _tab_skin_btn]:
		_set_tab_active(btn, false)
	match cat:
		"avatar":     _set_tab_active(_tab_avatar_btn, true)
		"background": _set_tab_active(_tab_bg_btn, true)
		"skin":       _set_tab_active(_tab_skin_btn, true)

	_populate_grid(cat)
	_clear_detail()


func _populate_grid(cat: String) -> void:
	for c in _grid.get_children():
		c.queue_free()

	var items: Array[Dictionary] = ShopManager.get_catalog(cat)

	# For grouped categories, use a VBox with header + HFlowContainer per group
	# to avoid headers stretching grid columns
	if cat == "background" or cat == "skin":
		_grid.columns = 1  # single column: each child is a section VBox
		var groups: Dictionary = {}  # slot -> items
		for item in items:
			var slot: String = item.get("slot", "")
			if not groups.has(slot):
				groups[slot] = []
			groups[slot].append(item)
		for slot_key in groups.keys():
			var section := VBoxContainer.new()
			section.add_theme_constant_override("separation", 8)
			section.size_flags_horizontal = SIZE_EXPAND_FILL
			_grid.add_child(section)

			# Sub-header
			var header := Label.new()
			header.text = _slot_display_name(slot_key)
			header.add_theme_color_override("font_color", Color(0, 1, 1, 0.8))
			header.add_theme_font_size_override("font_size", 14)
			section.add_child(header)

			# Items in a flow row
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 12)
			row.add_theme_constant_override("v_separation", 12)
			row.size_flags_horizontal = SIZE_EXPAND_FILL
			section.add_child(row)

			for item in groups[slot_key]:
				row.add_child(_make_item_card(item))
	else:
		_grid.columns = 3
		for item in items:
			_grid.add_child(_make_item_card(item))


func _slot_display_name(slot: String) -> String:
	match slot:
		"equipped_bg_defuse_trojan": return "-- Defuse the Trojan --"
		"equipped_bg_akashic_tcg":   return "-- Akashic TCG --"
		"equipped_bg_code_breaker":  return "-- Code Breaker --"
		"equipped_skin_defuse_trojan": return "-- Defuse the Trojan Ships --"
		"equipped_skin_akashic_tcg":   return "-- Akashic TCG Card Backs --"
		"equipped_skin_code_breaker":  return "-- Code Breaker Break Effects --"
		_: return slot.capitalize()


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  I T E M   C A R D   (built dynamically per catalog item)               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
func _make_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 200)

	var item_id: String = item.get("id", "")
	var owned: bool = ShopManager.is_owned(item_id)
	var equipped: bool = ShopManager.is_equipped(item_id)
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	# Card style
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.18, 0.9)
	sb.border_color = rarity_color if owned else Color(0.2, 0.2, 0.3, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	if equipped:
		sb.border_color = Color(0, 1, 1, 1)
		sb.shadow_color = Color(0, 1, 1, 0.3)
		sb.shadow_size = 6
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	var icon_path: String = item.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "???")
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.custom_minimum_size.x = 160
	vbox.add_child(name_lbl)

	# Status row
	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if equipped:
		status_lbl.text = "EQUIPPED"
		status_lbl.add_theme_color_override("font_color", Color(0, 1, 0.6))
	elif owned:
		status_lbl.text = "OWNED"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	else:
		var price: int = item.get("price", 0)
		status_lbl.text = "%d coins" % price
		status_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0))
	vbox.add_child(status_lbl)

	# Click handler
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(item_id)
	)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return card


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  D E T A I L   P A N E L                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
func _show_detail(item_id: String) -> void:
	_selected_item_id = item_id
	var item: Dictionary = ShopManager.get_item(item_id)
	if item.is_empty():
		return

	var icon_path: String = item.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_detail_icon.texture = load(icon_path)
	else:
		_detail_icon.texture = null

	_detail_name.text = item.get("name", "???")
	var rarity: String = item.get("rarity", "common")
	_detail_rarity.text = rarity.to_upper()
	_detail_rarity.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	_detail_desc.text = item.get("description", "")

	var owned: bool = ShopManager.is_owned(item_id)
	var equipped: bool = ShopManager.is_equipped(item_id)
	var price: int = item.get("price", 0)

	if equipped:
		_detail_price.text = "Currently equipped"
		_detail_action_btn.text = "Equipped"
		_detail_action_btn.disabled = true
		_detail_action_btn.visible = true
		_set_btn_color(_detail_action_btn, Color(0.15, 0.4, 0.15))
	elif owned:
		_detail_price.text = "Owned"
		_detail_action_btn.text = "Equip"
		_detail_action_btn.disabled = false
		_detail_action_btn.visible = true
		_set_btn_color(_detail_action_btn, Color(0, 0.45, 0.65))
	else:
		_detail_price.text = "%d CyberCoins" % price
		var can: bool = CyberCoinManager.can_afford(price)
		_detail_action_btn.text = "Buy  %d" % price
		_detail_action_btn.disabled = not can
		_detail_action_btn.visible = true
		_set_btn_color(_detail_action_btn, Color(0, 0.5, 0.2) if can else Color(0.3, 0.3, 0.3))


func _clear_detail() -> void:
	_detail_icon.texture = null
	_detail_name.text = "Select an item"
	_detail_rarity.text = ""
	_detail_desc.text = ""
	_detail_price.text = ""
	_detail_action_btn.visible = false


func _on_action_pressed() -> void:
	if _selected_item_id == "":
		return
	var owned: bool = ShopManager.is_owned(_selected_item_id)
	if owned:
		ShopManager.equip(_selected_item_id)
	else:
		if ShopManager.purchase(_selected_item_id):
			ShopManager.equip(_selected_item_id)
	# Refresh
	_update_coin_display()
	_populate_grid(_current_category)
	_show_detail(_selected_item_id)


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  H E L P E R S                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
func _update_coin_display() -> void:
	_coin_label.text = "%d CyberCoins" % CyberCoinManager.get_balance()


func _set_tab_active(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _tab_style_active.duplicate())
		btn.add_theme_color_override("font_color", Color(0, 1, 1))
	else:
		btn.add_theme_stylebox_override("normal", _tab_style_inactive.duplicate())
		btn.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))


func _set_btn_color(btn: Button, bg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bg.lightened(0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	var disabled_sb := sb.duplicate()
	disabled_sb.bg_color = bg
	disabled_sb.border_color = bg
	btn.add_theme_stylebox_override("disabled", disabled_sb)
