# inventory_panel.gd
extends Panel

# UI References
@onready var close_button: Button = $CloseButton
@onready var category_container: HBoxContainer = $CategoryContainer
@onready var sort_container: HBoxContainer = $SortContainer
@onready var items_grid: GridContainer = $ScrollContainer/ItemsGrid
@onready var item_detail_panel: Panel = $ItemDetailPanel

# Category buttons
var category_buttons: Dictionary = {}
var sort_buttons: Dictionary = {}

# Current filters
var current_category: String = "all"
var current_sort: String = "rarity"

# Item data (will be loaded from Firestore)
var player_items: Array = []

signal inventory_closed

# ✅ FIX 1: Add loading state
var is_loading: bool = false
var loading_label: Label = null

func _ready() -> void:
	visible = false
	
	# Setup close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Setup categories
	_create_category_buttons()
	_create_sort_buttons()
	
	# Hide item detail panel initially
	if item_detail_panel:
		item_detail_panel.visible = false
	
	# ✅ FIX 2: Create loading indicator
	_create_loading_indicator()

func _create_loading_indicator() -> void:
	loading_label = Label.new()
	loading_label.name = "LoadingLabel"
	loading_label.text = "Loading inventory..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.custom_minimum_size = Vector2(600, 300)
	loading_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	loading_label.add_theme_font_size_override("font_size", 18)
	loading_label.add_theme_font_override("font", load("res://asset/fonts/ABeeZee-Regular.ttf"))
	loading_label.visible = false
	items_grid.add_child(loading_label)


func show_inventory() -> void:
	"""Open the inventory panel"""
	visible = true
	_load_player_items()

func _create_category_buttons() -> void:
	"""Create filter buttons for item categories"""
	var categories = [
		{"id": "all", "label": "All Items"},
		{"id": "badge", "label": "Badges"},
		{"id": "card", "label": "Cards"},
		{"id": "avatar", "label": "Avatars"},
		{"id": "powerup", "label": "Power-ups"}
	]
	
	for cat in categories:
		var btn = Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Style button
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0.1, 0.2, 0.3, 0.9)
		btn_style_normal.border_width_left = 2
		btn_style_normal.border_width_right = 2
		btn_style_normal.border_width_top = 2
		btn_style_normal.border_width_bottom = 2
		btn_style_normal.border_color = Color(0, 0.9, 1, 0.6)
		btn_style_normal.corner_radius_top_left = 5
		btn_style_normal.corner_radius_top_right = 5
		btn_style_normal.corner_radius_bottom_left = 5
		btn_style_normal.corner_radius_bottom_right = 5
		
		var btn_style_hover = btn_style_normal.duplicate()
		btn_style_hover.bg_color = Color(0, 0.6, 0.7, 1)
		btn_style_hover.border_color = Color(0, 1, 1, 1)
		
		btn.add_theme_stylebox_override("normal", btn_style_normal)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("pressed", btn_style_hover)
		btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		
		# 🔧 ADD CUSTOM FONT TO BUTTONS
		btn.add_theme_font_override("font", load("res://asset/fonts/NicoMoji-Regular.ttf"))
		btn.add_theme_font_size_override("font_size", 16)
		
		var cat_id = cat["id"]
		btn.pressed.connect(func(): _on_category_selected(cat_id))
		
		category_container.add_child(btn)
		category_buttons[cat_id] = btn
	
	_on_category_selected("all")

func _create_sort_buttons() -> void:
	"""Create sorting buttons"""
	var sorts = [
		{"id": "rarity", "label": "By Rarity"},
		{"id": "date", "label": "By Date"},
		{"id": "name", "label": "By Name"}
	]
	
	for sort in sorts:
		var btn = Button.new()
		btn.text = sort["label"]
		btn.custom_minimum_size = Vector2(100, 35)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Style button (smaller than category buttons)
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0.05, 0.1, 0.15, 0.9)
		btn_style_normal.border_width_left = 2
		btn_style_normal.border_width_right = 2
		btn_style_normal.border_width_top = 2
		btn_style_normal.border_width_bottom = 2
		btn_style_normal.border_color = Color(0, 0.7, 0.8, 0.6)
		btn_style_normal.corner_radius_top_left = 4
		btn_style_normal.corner_radius_top_right = 4
		btn_style_normal.corner_radius_bottom_left = 4
		btn_style_normal.corner_radius_bottom_right = 4
		
		var btn_style_hover = btn_style_normal.duplicate()
		btn_style_hover.bg_color = Color(0, 0.5, 0.6, 1)
		
		btn.add_theme_stylebox_override("normal", btn_style_normal)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("pressed", btn_style_hover)
		btn.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		btn.add_theme_font_size_override("font_size", 14)
		
		# 🔧 ADD CUSTOM FONT TO SORT BUTTONS
		btn.add_theme_font_override("font", load("res://asset/fonts/NicoMoji-Regular.ttf"))
		
		var sort_id = sort["id"]
		btn.pressed.connect(func(): _on_sort_selected(sort_id))
		
		sort_container.add_child(btn)
		sort_buttons[sort_id] = btn
	
	_on_sort_selected("rarity")
	
func _on_category_selected(category: String) -> void:
	"""Filter items by category"""
	current_category = category
	_refresh_display()
	
	# Update button states (highlight selected)
	for cat_id in category_buttons.keys():
		var btn = category_buttons[cat_id]
		if cat_id == category:
			btn.add_theme_color_override("font_color", Color(1, 1, 0, 1))  # Yellow for selected
		else:
			btn.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan for normal

func _on_sort_selected(sort_type: String) -> void:
	"""Sort items"""
	current_sort = sort_type
	_refresh_display()
	
	# Update button states
	for sort_id in sort_buttons.keys():
		var btn = sort_buttons[sort_id]
		if sort_id == sort_type:
			btn.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))

func _refresh_display() -> void:
	"""Refresh the items grid based on current filters"""
	# Clear existing items
	for child in items_grid.get_children():
		child.queue_free()
	
	# ✅ FIX 4: Show empty state if no items
	if player_items.is_empty():
		_show_empty_state()
		return
	
	# Filter items
	var filtered_items = _filter_items(player_items)
	
	# ✅ Show "no results" if filter returns nothing
	if filtered_items.is_empty():
		_show_no_results_state()
		return
	
	# Sort items
	var sorted_items = _sort_items(filtered_items)
	
	# Display items
	for item in sorted_items:
		_create_item_card(item)

# ✅ FIX 5: Add empty state UI
func _show_empty_state() -> void:
	var empty_label = Label.new()
	empty_label.text = "Your inventory is empty.\nComplete missions to earn rewards!"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 1))
	empty_label.add_theme_font_size_override("font_size", 18)
	# 🔧 ADD CUSTOM FONT
	empty_label.add_theme_font_override("font", load("res://asset/fonts/ABeeZee-Regular.ttf"))
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	empty_label.custom_minimum_size = Vector2(600, 200)
	items_grid.add_child(empty_label)

# ✅ FIX 6: Add no results state
func _show_no_results_state() -> void:
	var no_results_label = Label.new()
	no_results_label.text = "No items match this filter.\nTry selecting a different category!"
	no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_results_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 1))
	no_results_label.add_theme_font_size_override("font_size", 16)
	# 🔧 ADD CUSTOM FONT
	no_results_label.add_theme_font_override("font", load("res://asset/fonts/ABeeZee-Regular.ttf"))
	no_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	no_results_label.custom_minimum_size = Vector2(800, 200)
	items_grid.add_child(no_results_label)

func _filter_items(items: Array) -> Array:
	"""Filter items based on current category"""
	if current_category == "all":
		return items
	
	var filtered: Array = []
	for item in items:
		if item.get("type", "") == current_category:
			filtered.append(item)
	return filtered

func _sort_items(items: Array) -> Array:
	"""Sort items based on current sort type"""
	var sorted = items.duplicate()
	
	match current_sort:
		"rarity":
			sorted.sort_custom(func(a, b): return _get_rarity_value(a.get("rarity", "common")) > _get_rarity_value(b.get("rarity", "common")))
		"date":
			sorted.sort_custom(func(a, b): return a.get("date_acquired", 0) > b.get("date_acquired", 0))
		"name":
			sorted.sort_custom(func(a, b): return a.get("name", "").naturalnocasecmp_to(b.get("name", "")) < 0)
	
	return sorted

func _get_rarity_value(rarity: String) -> int:
	"""Convert rarity to numeric value for sorting"""
	match rarity.to_lower():
		"legendary": return 5
		"epic": return 4
		"rare": return 3
		"uncommon": return 2
		"common": return 1
		_: return 0

func _create_item_card(item: Dictionary) -> void:
	"""Create a visual card for an item"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(150, 180)
	
	# Style based on rarity
	var rarity_color = _get_rarity_color(item.get("rarity", "common"))
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = rarity_color
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	
	# Item icon
	var icon = TextureRect.new()
	icon.position = Vector2(25, 15)
	icon.size = Vector2(100, 100)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# ✅ FIX 7: Better icon loading with fallback
	var icon_path = item.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Use emoji as fallback if icon doesn't exist
		var fallback_label = Label.new()
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_label.add_theme_font_size_override("font_size", 64)
		fallback_label.size = Vector2(100, 100)
		fallback_label.position = Vector2(25, 15)
		
		match item.get("type", ""):
			"badge":
				fallback_label.text = "🏆"
			"card":
				fallback_label.text = "🎴"
			"avatar":
				fallback_label.text = "👤"
			"powerup":
				fallback_label.text = "⚡"
			_:
				fallback_label.text = "🎁"
		
		card.add_child(fallback_label)
	
	if icon.texture:
		card.add_child(icon)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.position = Vector2(10, 120)
	name_label.size = Vector2(130, 25)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 14)
	card.add_child(name_label)
	
	# Rarity label
	var rarity_label = Label.new()
	rarity_label.text = item.get("rarity", "common").capitalize()
	rarity_label.position = Vector2(10, 145)
	rarity_label.size = Vector2(130, 20)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.add_theme_font_size_override("font_size", 12)
	card.add_child(rarity_label)
	
	# Make card clickable
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event): _on_item_card_clicked(event, item))
	
	items_grid.add_child(card)

func _get_rarity_color(rarity: String) -> Color:
	"""Get color based on rarity"""
	match rarity.to_lower():
		"legendary": return Color(1, 0.5, 0, 1)  # Orange
		"epic": return Color(0.7, 0, 1, 1)  # Purple
		"rare": return Color(0, 0.5, 1, 1)  # Blue
		"uncommon": return Color(0, 1, 0, 1)  # Green
		"common": return Color(0.7, 0.7, 0.7, 1)  # Gray
		_: return Color(0.5, 0.5, 0.5, 1)

func _on_item_card_clicked(event: InputEvent, item: Dictionary) -> void:
	"""Show item details when clicked"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_item_details(item)

func _show_item_details(item: Dictionary) -> void:
	"""Display detailed information about an item"""
	if not item_detail_panel:
		return
	
	item_detail_panel.visible = true
	
	# Clear previous content
	for child in item_detail_panel.get_children():
		if child.name != "CloseDetailButton":
			child.queue_free()
	
	# Item name
	var title = Label.new()
	title.text = item.get("name", "Unknown")
	title.position = Vector2(20, 20)
	title.size = Vector2(260, 35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
	title.add_theme_font_size_override("font_size", 22)
	item_detail_panel.add_child(title)
	
	# Description
	var desc = Label.new()
	desc.text = item.get("description", "No description available.")
	desc.position = Vector2(20, 65)
	desc.size = Vector2(260, 80)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.add_theme_font_size_override("font_size", 14)
	item_detail_panel.add_child(desc)
	
	# Stats/Info
	var info_y = 155
	var info_items = [
		"Type: %s" % item.get("type", "unknown").capitalize(),
		"Rarity: %s" % item.get("rarity", "common").capitalize(),
		"Acquired: %s" % _format_date(item.get("date_acquired", 0))
	]
	
	for info in info_items:
		var info_label = Label.new()
		info_label.text = info
		info_label.position = Vector2(20, info_y)
		info_label.size = Vector2(260, 20)
		info_label.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		info_label.add_theme_font_size_override("font_size", 13)
		item_detail_panel.add_child(info_label)
		info_y += 25
	
	# Close button for detail panel
	var close_detail = item_detail_panel.get_node_or_null("CloseDetailButton")
	if not close_detail:
		close_detail = Button.new()
		close_detail.name = "CloseDetailButton"
		close_detail.text = "✕"
		close_detail.position = Vector2(260, 10)
		close_detail.custom_minimum_size = Vector2(30, 30)
		close_detail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var close_style = StyleBoxFlat.new()
		close_style.bg_color = Color(0, 0, 0, 0)
		close_detail.add_theme_stylebox_override("normal", close_style)
		close_detail.add_theme_color_override("font_color", Color(1, 0, 0, 1))
		close_detail.add_theme_font_size_override("font_size", 20)
		
		close_detail.pressed.connect(func(): item_detail_panel.visible = false)
		item_detail_panel.add_child(close_detail)

func _format_date(timestamp: int) -> String:
	"""Format Unix timestamp to readable date"""
	if timestamp == 0:
		return "Unknown"
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%d" % [datetime.month, datetime.day, datetime.year]

# ✅ FIX 8: Better error handling for Firestore loading
func _load_player_items() -> void:
	"""Load player's items from Firestore"""
	# ✅ Check if already loading
	if is_loading:
		print("[Inventory] Already loading items")
		return
	
	# ✅ Check authentication
	if not Auth or Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[Inventory] User not logged in")
		_show_error_message("Please log in to view your inventory")
		return
	
	is_loading = true
	
	# Show loading indicator
	if loading_label:
		loading_label.visible = true
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s/inventory" % user_id
	var headers = ["Authorization: Bearer %s" % id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		is_loading = false
		
		if loading_label:
			loading_label.visible = false
		
		if code == 200:
			_parse_inventory_data(body)
		else:
			var error_msg = body.get_string_from_utf8() if body.size() > 0 else "Unknown error"
			push_error("[Inventory] Failed to load items: %d - %s" % [code, error_msg])
			_show_error_message("Failed to load inventory. Please try again.")
			_refresh_display()  # Show empty state
	)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		is_loading = false
		if loading_label:
			loading_label.visible = false
		push_error("[Inventory] HTTP request failed: %d" % err)
		_show_error_message("Connection error. Please check your internet.")

# ✅ FIX 9: Add error message display
func _show_error_message(message: String) -> void:
	"""Show error message in inventory panel"""
	for child in items_grid.get_children():
		child.queue_free()
	
	var error_label = Label.new()
	error_label.text = "⚠️ " + message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	error_label.add_theme_font_size_override("font_size", 16)
	# 🔧 ADD CUSTOM FONT
	error_label.add_theme_font_override("font", load("res://asset/fonts/ABeeZee-Regular.ttf"))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	error_label.custom_minimum_size = Vector2(600, 200)
	items_grid.add_child(error_label)

func _parse_inventory_data(body: PackedByteArray) -> void:
	"""Parse inventory data from Firestore response"""
	var json_str = body.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	
	if not data or not data.has("documents"):
		player_items = []
		_refresh_display()
		return
	
	player_items.clear()
	
	for doc in data["documents"]:
		if not doc.has("fields"):
			continue
		
		var fields = doc["fields"]
		var item = {
			"id": doc.get("name", "").split("/")[-1],
			"name": fields.get("name", {}).get("stringValue", "Unknown"),
			"type": fields.get("type", {}).get("stringValue", "unknown"),
			"rarity": fields.get("rarity", {}).get("stringValue", "common"),
			"description": fields.get("description", {}).get("stringValue", ""),
			"icon_path": fields.get("icon_path", {}).get("stringValue", ""),
			"date_acquired": int(fields.get("date_acquired", {}).get("integerValue", 0))
		}
		player_items.append(item)
	
	print("[Inventory] Loaded %d items" % player_items.size())
	_refresh_display()

func _on_close_pressed() -> void:
	"""Close the inventory panel"""
	visible = false
	inventory_closed.emit()
