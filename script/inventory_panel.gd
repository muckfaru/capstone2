@tool
# inventory_panel.gd
extends Panel

const AvatarCatalog = preload("res://script/AvatarCatalog.gd")

# ── Scene-defined UI references ──────────────────────────────────────────────
@onready var close_button: Button               = $CloseButton
@onready var category_container: HBoxContainer  = $CategoryContainer
@onready var sort_container: HBoxContainer      = $SortContainer
@onready var items_grid: GridContainer          = $ScrollContainer/ItemsGrid
@onready var item_detail_panel: Panel           = $ItemDetailPanel

# Status labels (inside ItemsGrid, hidden by default)
@onready var loading_label: Label     = $ScrollContainer/ItemsGrid/LoadingLabel
@onready var empty_state_label: Label = $ScrollContainer/ItemsGrid/EmptyStateLabel
@onready var no_results_label: Label  = $ScrollContainer/ItemsGrid/NoResultsLabel
@onready var error_label: Label       = $ScrollContainer/ItemsGrid/ErrorLabel

# Item card template (hidden Panel, cloned at runtime)
@onready var card_tpl_badge:   Panel = $CardTemplateBadge
@onready var card_tpl_card:    Panel = $CardTemplateCard
@onready var card_tpl_avatar:  Panel = $CardTemplateAvatar
@onready var card_tpl_powerup: Panel = $CardTemplatePowerup
@onready var card_tpl_default: Panel = $CardTemplateDefault

# Detail panel children
@onready var detail_title: Label             = $ItemDetailPanel/DetailRoot/DetailVBox/DetailHeader/DetailTitle
@onready var detail_desc: Label              = $ItemDetailPanel/DetailRoot/DetailVBox/DetailDesc
@onready var detail_info_vbox: VBoxContainer = $ItemDetailPanel/DetailRoot/DetailVBox/DetailInfoVBox
@onready var detail_equip_btn: Button        = $ItemDetailPanel/DetailRoot/DetailVBox/DetailEquipButton
@onready var close_detail_btn: Button        = $ItemDetailPanel/DetailRoot/DetailVBox/DetailHeader/CloseDetailButton

# Category buttons (scene-defined)
@onready var btn_cat_all:     Button = $CategoryContainer/BtnCatAll
@onready var btn_cat_badge:   Button = $CategoryContainer/BtnCatBadge
@onready var btn_cat_card:    Button = $CategoryContainer/BtnCatCard
@onready var btn_cat_avatar:  Button = $CategoryContainer/BtnCatAvatar
@onready var btn_cat_powerup: Button = $CategoryContainer/BtnCatPowerup

# Sort buttons (scene-defined)
@onready var btn_sort_rarity: Button = $SortContainer/BtnSortRarity
@onready var btn_sort_date:   Button = $SortContainer/BtnSortDate
@onready var btn_sort_name:   Button = $SortContainer/BtnSortName

# ── State ─────────────────────────────────────────────────────────────────────
var category_buttons: Dictionary = {}
var sort_buttons: Dictionary = {}
var current_category: String = "all"
var current_sort: String = "rarity"
var player_items: Array = []
var _detail_item: Dictionary = {}
var is_loading: bool = false

signal inventory_closed
signal avatar_selected(avatar_file: String)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	visible = false

	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.pressed.connect(_on_close_pressed)
	if close_detail_btn:
		close_detail_btn.pressed.connect(_on_close_detail_pressed)
	if detail_equip_btn:
		detail_equip_btn.pressed.connect(_on_detail_equip_pressed)

	category_buttons = {
		"all":     btn_cat_all,
		"badge":   btn_cat_badge,
		"card":    btn_cat_card,
		"avatar":  btn_cat_avatar,
		"powerup": btn_cat_powerup,
	}
	btn_cat_all.pressed.connect(_on_cat_all_pressed)
	btn_cat_badge.pressed.connect(_on_cat_badge_pressed)
	btn_cat_card.pressed.connect(_on_cat_card_pressed)
	btn_cat_avatar.pressed.connect(_on_cat_avatar_pressed)
	btn_cat_powerup.pressed.connect(_on_cat_powerup_pressed)

	sort_buttons = {
		"rarity": btn_sort_rarity,
		"date":   btn_sort_date,
		"name":   btn_sort_name,
	}
	btn_sort_rarity.pressed.connect(_on_sort_rarity_pressed)
	btn_sort_date.pressed.connect(_on_sort_date_pressed)
	btn_sort_name.pressed.connect(_on_sort_name_pressed)

	if item_detail_panel:
		item_detail_panel.visible = false

	_on_category_selected("all")
	_on_sort_selected("rarity")

# ── Button signal handlers ────────────────────────────────────────────────────
func _on_close_pressed() -> void:
	visible = false
	inventory_closed.emit()

func _on_close_detail_pressed() -> void:
	item_detail_panel.visible = false

func _on_cat_all_pressed()     -> void: _on_category_selected("all")
func _on_cat_badge_pressed()   -> void: _on_category_selected("badge")
func _on_cat_card_pressed()    -> void: _on_category_selected("card")
func _on_cat_avatar_pressed()  -> void: _on_category_selected("avatar")
func _on_cat_powerup_pressed() -> void: _on_category_selected("powerup")

func _on_sort_rarity_pressed() -> void: _on_sort_selected("rarity")
func _on_sort_date_pressed()   -> void: _on_sort_selected("date")
func _on_sort_name_pressed()   -> void: _on_sort_selected("name")

# ─── Category / sort selection ────────────────────────────────────────────────
func _on_category_selected(category: String) -> void:
	current_category = category
	_refresh_display()
	for cat_id in category_buttons:
		var btn: Button = category_buttons[cat_id]
		if cat_id == category:
			btn.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))

func _on_sort_selected(sort_type: String) -> void:
	current_sort = sort_type
	_refresh_display()
	for sort_id in sort_buttons:
		var btn: Button = sort_buttons[sort_id]
		if sort_id == sort_type:
			btn.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))

# ─── Display ──────────────────────────────────────────────────────────────────
func _hide_all_status_labels() -> void:
	loading_label.visible     = false
	empty_state_label.visible = false
	no_results_label.visible  = false
	error_label.visible       = false

func _clear_item_cards() -> void:
	var keep: Array = ["LoadingLabel", "EmptyStateLabel", "NoResultsLabel", "ErrorLabel"]
	for child in items_grid.get_children():
		if not keep.has(child.name):
			child.queue_free()

func _refresh_display() -> void:
	_clear_item_cards()
	_hide_all_status_labels()

	if player_items.is_empty():
		empty_state_label.visible = true
		return

	var filtered: Array = _filter_items(player_items)
	if filtered.is_empty():
		no_results_label.visible = true
		return

	var sorted: Array = _sort_items(filtered)
	for item in sorted:
		_create_item_card(item)

# ─── Item card ────────────────────────────────────────────────────────────────
func _get_template_for_type(item_type: String) -> Panel:
	if item_type == "badge":   return card_tpl_badge
	if item_type == "card":    return card_tpl_card
	if item_type == "avatar":  return card_tpl_avatar
	if item_type == "powerup": return card_tpl_powerup
	return card_tpl_default

func _create_item_card(item: Dictionary) -> void:
	var item_type: String  = str(item.get("type", ""))
	var template: Panel    = _get_template_for_type(item_type)
	var card: Panel        = template.duplicate()
	card.visible = true


	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if card.custom_minimum_size == Vector2.ZERO:
		card.custom_minimum_size = Vector2(150, 185)
	# Rarity border colour
	var rarity_color: Color      = _get_rarity_color(item.get("rarity", "common"))
	var card_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	card_style.border_color = rarity_color
	card.add_theme_stylebox_override("panel", card_style)

	# Equipped badge (only relevant for card_backgrounds)
	var badge: Label = card.get_node("EquippedBadge")
	var is_bg: bool  = str(item.get("subtype", "")) == "card_background"
	var is_eq: bool  = bool(item.get("is_equipped", false))
	badge.visible = is_bg and is_eq

	# Icon / fallback
	var icon: TextureRect = card.get_node("CardVBox/IconContainer/ItemIcon")
	var fallback: Label   = card.get_node("CardVBox/IconContainer/FallbackLabel")
	var icon_path: String = item.get("icon_path", "")

	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture     = load(icon_path)
		icon.visible     = true
		fallback.visible = false
	else:
		icon.visible     = false
		fallback.visible = true
		if item_type == "badge":
			fallback.text = "🏆"
		elif item_type == "card":
			fallback.text = "🎴"
		elif item_type == "avatar":
			fallback.text = "👤"
		elif item_type == "powerup":
			fallback.text = "⚡"
		else:
			fallback.text = "🎁"

	# Powerup amount badge (only exists on CardTemplatePowerup)
	if item_type == "powerup":
		var amount_lbl: Label = card.get_node_or_null("CardVBox/IconContainer/AmountLabel")
		if amount_lbl:
			var amt: int = int(item.get("amount", 1))
			amount_lbl.text = "x%d" % amt
			amount_lbl.visible = amt > 1

	# Name
	var name_lbl: Label      = card.get_node("CardVBox/ItemName")
	var display_name: String = str(item.get("name", "Unknown"))
	if str(item.get("subtype", "")) == "card_background":
		display_name = _normalize_card_bg_name(display_name)
	name_lbl.text = display_name

	# Rarity
	var rarity_lbl: Label = card.get_node("CardVBox/RarityLabel")
	rarity_lbl.text = item.get("rarity", "common").capitalize()
	rarity_lbl.add_theme_color_override("font_color", rarity_color)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("item_data", item)
	card.gui_input.connect(_on_item_card_input.bind(card))
	card.size_flags_horizontal = Control.SIZE_FILL
	card.size_flags_vertical   = Control.SIZE_FILL
	items_grid.add_child(card)

func _on_item_card_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var item: Dictionary = card.get_meta("item_data")
			_show_item_details(item)

# ─── Detail panel ─────────────────────────────────────────────────────────────
func _show_item_details(item: Dictionary) -> void:
	if not item_detail_panel:
		return

	_detail_item = item.duplicate(true)
	item_detail_panel.visible = true

	var display_title: String = str(item.get("name", "Unknown"))
	if str(item.get("subtype", "")) == "card_background":
		display_title = _normalize_card_bg_name(display_title)
	detail_title.text = display_title
	detail_title.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
	detail_desc.text = item.get("description", "No description available.")

	for child in detail_info_vbox.get_children():
		child.queue_free()

	var lines: Array = [
		"Type: "     + item.get("type",   "unknown").capitalize(),
		"Rarity: "   + item.get("rarity", "common").capitalize(),
		"Acquired: " + _format_date(item.get("date_acquired", 0))
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		lbl.add_theme_font_size_override("font_size", 13)
		detail_info_vbox.add_child(lbl)

	if str(item.get("subtype", "")) == "card_background":
		var equipped_now: bool = bool(item.get("is_equipped", false))
		var status := Label.new()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.add_theme_font_size_override("font_size", 13)
		if equipped_now:
			status.text = "Status: Equipped"
			status.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		else:
			status.text = "Status: Not equipped"
			status.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		detail_info_vbox.add_child(status)

		detail_equip_btn.visible  = true
		detail_equip_btn.disabled = equipped_now
		if equipped_now:
			detail_equip_btn.text = "EQUIPPED"
		else:
			detail_equip_btn.text = "EQUIP BACKGROUND"

	elif str(item.get("type", "")) == "avatar":
		detail_equip_btn.visible  = true
		detail_equip_btn.text     = "SET AVATAR"
		detail_equip_btn.disabled = false
	else:
		detail_equip_btn.visible  = false
		detail_equip_btn.disabled = true

func _on_detail_equip_pressed() -> void:
	if _detail_item.is_empty():
		return
	if str(_detail_item.get("subtype", "")) == "card_background":
		_equip_card_background(_detail_item)
	elif str(_detail_item.get("type", "")) == "avatar":
		_equip_avatar(_detail_item)

# ─── Inventory loading ────────────────────────────────────────────────────────
func show_inventory() -> void:
	visible = true
	_load_player_items()

func _load_player_items() -> void:
	if is_loading:
		return
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[Inventory] User not logged in")
		_show_error_message("Please log in to view your inventory")
		return

	is_loading = true
	_hide_all_status_labels()
	_clear_item_cards()
	loading_label.visible = true

	var user_id:  String = Auth.current_local_id
	var id_token: String = Auth.current_id_token
	var url:      String = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s/inventory" % user_id
	var headers:  Array  = ["Authorization: Bearer %s" % id_token]

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_inventory_loaded.bind(http))

	var err: int = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		is_loading = false
		loading_label.visible = false
		push_error("[Inventory] HTTP request failed: %d" % err)
		_show_error_message("Connection error. Please check your internet.")

func _on_inventory_loaded(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	is_loading = false
	loading_label.visible = false

	if code == 200:
		_parse_inventory_data(body)
	else:
		var err_msg: String = body.get_string_from_utf8() if body.size() > 0 else "Unknown error"
		push_error("[Inventory] Failed to load items: %d - %s" % [code, err_msg])
		_show_error_message("Failed to load inventory. Please try again.")

func _parse_inventory_data(body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data or not data.has("documents"):
		player_items = []
		_append_builtin_avatars()
		_refresh_display()
		return

	player_items.clear()
	for doc in data["documents"]:
		if not doc.has("fields"):
			continue
		var f: Dictionary = doc["fields"]
		var entry: Dictionary = {
			"id":            doc.get("name", "").split("/")[-1],
			"name":          f.get("name",          {}).get("stringValue",  "Unknown"),
			"type":          f.get("type",           {}).get("stringValue",  "unknown"),
			"subtype":       f.get("subtype",        {}).get("stringValue",  ""),
			"rarity":        f.get("rarity",         {}).get("stringValue",  "common"),
			"description":   f.get("description",    {}).get("stringValue",  ""),
			"icon_path":     f.get("icon_path",      {}).get("stringValue",  ""),
			"amount":        int(f.get("amount",     {}).get("integerValue", 1)),
			"is_equipped":   f.get("is_equipped",    {}).get("booleanValue", false),
			"date_acquired": int(f.get("date_acquired", {}).get("integerValue", 0))
		}
		player_items.append(entry)

	_append_builtin_avatars()
	print("[Inventory] Loaded %d items" % player_items.size())
	_refresh_display()

# ─── Helpers ──────────────────────────────────────────────────────────────────
func _show_error_message(message: String) -> void:
	_clear_item_cards()
	_hide_all_status_labels()
	error_label.text    = "⚠️ " + message
	error_label.visible = true

func _filter_items(items: Array) -> Array:
	if current_category == "all":
		return items
	var out: Array = []
	for item in items:
		if item.get("type", "") == current_category:
			out.append(item)
	return out

func _sort_items(items: Array) -> Array:
	var sorted: Array = items.duplicate()
	if current_sort == "rarity":
		sorted.sort_custom(_sort_by_rarity)
	elif current_sort == "date":
		sorted.sort_custom(_sort_by_date)
	elif current_sort == "name":
		sorted.sort_custom(_sort_by_name)
	return sorted

func _sort_by_rarity(a: Dictionary, b: Dictionary) -> bool:
	return _get_rarity_value(a.get("rarity", "common")) > _get_rarity_value(b.get("rarity", "common"))

func _sort_by_date(a: Dictionary, b: Dictionary) -> bool:
	return a.get("date_acquired", 0) > b.get("date_acquired", 0)

func _sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a.get("name", "").naturalnocasecmp_to(b.get("name", "")) < 0

func _get_rarity_value(rarity: String) -> int:
	if rarity == "legendary": return 5
	if rarity == "epic":      return 4
	if rarity == "rare":      return 3
	if rarity == "uncommon":  return 2
	if rarity == "common":    return 1
	return 0

func _get_rarity_color(rarity: String) -> Color:
	if rarity == "legendary": return Color(1, 0.5, 0, 1)
	if rarity == "epic":      return Color(0.7, 0, 1, 1)
	if rarity == "rare":      return Color(0, 0.5, 1, 1)
	if rarity == "uncommon":  return Color(0, 1, 0, 1)
	if rarity == "common":    return Color(0.7, 0.7, 0.7, 1)
	return Color(0.5, 0.5, 0.5, 1)

func _format_date(timestamp: int) -> String:
	if timestamp == 0:
		return "Unknown"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%d" % [dt.month, dt.day, dt.year]

func _normalize_card_bg_name(raw_name: String) -> String:
	var s: String = raw_name.strip_edges()
	if s == "":
		return "Unknown"
	if s.to_lower().begins_with("reward background"):
		s = s.substr("Reward Background".length()).strip_edges()
		if s.begins_with(":"):
			s = s.substr(1).strip_edges()
	var parts: Array = s.split(" ", false)
	if parts.size() <= 2:
		return s
	return parts[0] + " " + parts[1]

func _append_builtin_avatars() -> void:
	var dir := DirAccess.open("res://asset/avatars")
	if dir == null:
		return
	var existing_files: Dictionary = {}
	for it in player_items:
		var af: String = str(it.get("avatar_file", ""))
		if af != "":
			existing_files[af] = true
		var ip: String = str(it.get("icon_path", ""))
		if ip.begins_with("res://asset/avatars/"):
			existing_files[ip.get_file()] = true

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				if not existing_files.has(file_name):
					var base: String = file_name.get_basename()
					var entry: Dictionary = {
						"id":            "builtin_avatar_" + base,
						"name":          AvatarCatalog.get_display_name(file_name),
						"type":          "avatar",
						"subtype":       "preset",
						"rarity":        "common",
						"description":   "Preset avatar",
						"icon_path":     "res://asset/avatars/" + file_name,
						"avatar_file":   file_name,
						"amount":        1,
						"is_equipped":   false,
						"date_acquired": 0,
					}
					player_items.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()

func _equip_avatar(item: Dictionary) -> void:
	var file_name: String = str(item.get("avatar_file", ""))
	if file_name.strip_edges() == "":
		var icon_path: String = str(item.get("icon_path", ""))
		if icon_path.begins_with("res://asset/avatars/"):
			file_name = icon_path.get_file()
	if file_name.strip_edges() == "":
		_show_error_message("Invalid avatar")
		return
	avatar_selected.emit(file_name)
	item_detail_panel.visible = false

func _equip_card_background(item: Dictionary) -> void:
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		_show_error_message("Please log in to equip items")
		return
	if not has_node("/root/InventoryHelper"):
		_show_error_message("InventoryHelper missing")
		return

	var item_id:   String = str(item.get("id", ""))
	var icon_path: String = str(item.get("icon_path", ""))
	if item_id.strip_edges() == "" or icon_path.strip_edges() == "":
		_show_error_message("Invalid item")
		return

	for it in player_items:
		if str(it.get("subtype", "")) != "card_background":
			continue
		var other_id: String = str(it.get("id", ""))
		if other_id != "" and other_id != item_id and bool(it.get("is_equipped", false)):
			InventoryHelper.update_item(other_id, {"is_equipped": false})
			it["is_equipped"] = false

	InventoryHelper.update_item(item_id, {"is_equipped": true})
	InventoryHelper.set_equipped_card_background(icon_path)
	item["is_equipped"] = true

	for it2 in player_items:
		if str(it2.get("id", "")) == item_id:
			it2["is_equipped"] = true
	if Auth:
		Auth.current_card_bg_path = icon_path

	_refresh_display()
	_show_item_details(item)
