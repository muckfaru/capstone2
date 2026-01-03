# InventoryHelper.gd
# Autoload singleton for managing inventory operations
# Add to Project > Project Settings > Autoload as "InventoryHelper"

extends Node

signal item_added(item_data: Dictionary)
signal item_removed(item_id: String)
signal inventory_loaded(items: Array)

var firestore_base_url := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents"

const EQUIP_SLOT_CARD_BACKGROUND := "card_background"
const STARTER_CHARIOT_ITEM_ID := "reward_bg_chariot_7"

const REWARD_BACKGROUND_CARDS := [
	{
		"id": "reward_bg_fool_0",
		"name": "The Fool",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "uncommon",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the fool 0 card.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_hermit_4",
		"name": "The Hermit",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "rare",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the hermit 4 card.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_magician_1",
		"name": "The Magician I",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "epic",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the magician card 1.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_magician_2",
		"name": "The Magician II",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "epic",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the magician card 2.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_priestess",
		"name": "The Priestess",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "rare",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the priestest card.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_lovers_6",
		"name": "The Lovers",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "rare",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the lovers 6 card.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_chariot_7",
		"name": "The Chariot",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "uncommon",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the chariot 7 card.jpeg",
		"amount": 1,
	},
	{
		"id": "reward_bg_strength_8",
		"name": "The Strength",
		"type": "card",
		"subtype": EQUIP_SLOT_CARD_BACKGROUND,
		"rarity": "epic",
		"description": "Equip to change your Host/Client card background.",
		"icon_path": "res://asset/reward_background_cards/the strength 8 card.jpeg",
		"amount": 1,
	},
]

func ensure_reward_background_cards_in_inventory() -> void:
	"""Best-effort: create deterministic inventory docs for the reward backgrounds."""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	for item in REWARD_BACKGROUND_CARDS:
		_upsert_inventory_item(str(item.get("id", "")), item)

func set_equipped_card_background(texture_path: String) -> void:
	"""Persist equipped background on the user doc (owner-only)."""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	if Auth:
		Auth.current_card_bg_path = texture_path

	var doc_url := "%s/users/%s?updateMask.fieldPaths=equipped_card_bg_path" % [firestore_base_url, user_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	var body := {
		"fields": {
			"equipped_card_bg_path": {"stringValue": texture_path}
		}
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code != 200:
			push_warning("[InventoryHelper] Failed to persist equipped_card_bg_path HTTP %d" % code)
	)
	http.request(doc_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func grant_reward_background_card(item_id: String, equipped: bool) -> void:
	"""Create/overwrite a reward background card inventory doc with a deterministic ID."""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	var template: Dictionary = {}
	for item in REWARD_BACKGROUND_CARDS:
		if str(item.get("id", "")) == item_id:
			template = item
			break

	if template.is_empty():
		push_warning("[InventoryHelper] Unknown reward background id: %s" % item_id)
		return

	var timestamp := int(Time.get_unix_time_from_system())
	var url = "%s/users/%s/inventory/%s" % [firestore_base_url, user_id, item_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var fields := {
		"name": {"stringValue": str(template.get("name", "Unknown"))},
		"type": {"stringValue": str(template.get("type", "card"))},
		"subtype": {"stringValue": str(template.get("subtype", EQUIP_SLOT_CARD_BACKGROUND))},
		"rarity": {"stringValue": str(template.get("rarity", "common"))},
		"description": {"stringValue": str(template.get("description", ""))},
		"icon_path": {"stringValue": str(template.get("icon_path", ""))},
		"amount": {"integerValue": str(int(template.get("amount", 1)))},
		"date_acquired": {"integerValue": str(timestamp)},
		"is_equipped": {"booleanValue": equipped},
		"is_used": {"booleanValue": false},
	}

	var body := {"fields": fields}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			var err = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_warning("[InventoryHelper] Failed to grant %s HTTP %d\n%s" % [item_id, code, err])
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

func grant_starter_chariot_equipped() -> void:
	grant_reward_background_card(STARTER_CHARIOT_ITEM_ID, true)

func _upsert_inventory_item(item_id: String, item_data: Dictionary) -> void:
	if item_id.strip_edges() == "":
		return
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	if user_id == "" or id_token == "":
		return

	var url = "%s/users/%s/inventory/%s" % [firestore_base_url, user_id, item_id]

	# Note: Do NOT include date_acquired/is_equipped here so re-running this won't overwrite user state.
	var fields := {
		"name": {"stringValue": str(item_data.get("name", "Unknown"))},
		"type": {"stringValue": str(item_data.get("type", "item"))},
		"subtype": {"stringValue": str(item_data.get("subtype", ""))},
		"rarity": {"stringValue": str(item_data.get("rarity", "common"))},
		"description": {"stringValue": str(item_data.get("description", ""))},
		"icon_path": {"stringValue": str(item_data.get("icon_path", ""))},
		"amount": {"integerValue": str(int(item_data.get("amount", 1)))},
		"is_used": {"booleanValue": false},
	}

	var body := {"fields": fields}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			var err = resp_body.get_string_from_utf8() if resp_body.size() > 0 else ""
			push_warning("[InventoryHelper] Reward card upsert failed (%s) HTTP %d\n%s" % [item_id, code, err])
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

# ✅ Save item to inventory
func add_item_to_inventory(item_data: Dictionary) -> void:
	"""
	Add an item to player's inventory
	
	item_data format:
	{
		"name": "Item Name",
		"type": "badge/card/avatar/powerup/item",
		"rarity": "common/rare/epic/legendary",
		"description": "Description text",
		"icon_path": "res://path/to/icon.png",
		"amount": 1
	}
	"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[InventoryHelper] User not logged in")
		return
	
	# Generate unique item ID
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	var item_type = item_data.get("type", "item")
	var item_id = "%d_%s_%d" % [timestamp, item_type, random_suffix]
	
	var url = "%s/users/%s/inventory/%s" % [firestore_base_url, user_id, item_id]
	
	# Build Firestore document
	var fields := {
		"name": {"stringValue": item_data.get("name", "Unknown")},
		"type": {"stringValue": item_type},
		"rarity": {"stringValue": item_data.get("rarity", "common")},
		"description": {"stringValue": item_data.get("description", "")},
		"icon_path": {"stringValue": item_data.get("icon_path", "")},
		"amount": {"integerValue": str(item_data.get("amount", 1))},
		"date_acquired": {"integerValue": str(timestamp)},
		"is_equipped": {"booleanValue": item_data.get("is_equipped", false)},
		"is_used": {"booleanValue": false}
	}
	if item_data.has("subtype"):
		fields["subtype"] = {"stringValue": str(item_data.get("subtype", ""))}
	var body := {"fields": fields}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, response_body):
		http.queue_free()
		if code == 200:
			print("[InventoryHelper] ✅ Item added: %s" % item_data.get("name"))
			item_added.emit(item_data)
		else:
			var error = response_body.get_string_from_utf8() if response_body.size() > 0 else "Unknown error"
			push_error("[InventoryHelper] ❌ Failed to add item: %s" % error)
	)
	
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

# ✅ Remove item from inventory
func remove_item_from_inventory(item_id: String) -> void:
	"""Delete an item from inventory"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[InventoryHelper] User not logged in")
		return
	
	var url = "%s/users/%s/inventory/%s" % [firestore_base_url, user_id, item_id]
	var headers = ["Authorization: Bearer %s" % id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[InventoryHelper] ✅ Item removed: %s" % item_id)
			item_removed.emit(item_id)
		else:
			push_error("[InventoryHelper] ❌ Failed to remove item")
	)
	
	http.request(url, headers, HTTPClient.METHOD_DELETE)

# ✅ Load all inventory items
func load_inventory(callback: Callable) -> void:
	"""Load all items from player's inventory"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[InventoryHelper] User not logged in")
		callback.call([])
		return
	
	var url = "%s/users/%s/inventory" % [firestore_base_url, user_id]
	var headers = ["Authorization: Bearer %s" % id_token]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			var items = _parse_inventory_response(body)
			print("[InventoryHelper] ✅ Loaded %d items" % items.size())
			inventory_loaded.emit(items)
			callback.call(items)
		else:
			push_error("[InventoryHelper] ❌ Failed to load inventory")
			callback.call([])
	)
	
	http.request(url, headers, HTTPClient.METHOD_GET)

# ✅ Get items by type
func get_items_by_type(item_type: String, callback: Callable) -> void:
	"""Get all items of a specific type (badge, card, etc.)"""
	load_inventory(func(items):
		var filtered = items.filter(func(item): return item.get("type") == item_type)
		callback.call(filtered)
	)

# ✅ Get items by rarity
func get_items_by_rarity(rarity: String, callback: Callable) -> void:
	"""Get all items of a specific rarity"""
	load_inventory(func(items):
		var filtered = items.filter(func(item): return item.get("rarity") == rarity)
		callback.call(filtered)
	)

# ✅ Check if player has item
func has_item(item_name: String, callback: Callable) -> void:
	"""Check if player has an item by name"""
	load_inventory(func(items):
		var found = items.any(func(item): return item.get("name") == item_name)
		callback.call(found)
	)

# ✅ Update item (e.g., mark as equipped/used)
func update_item(item_id: String, updates: Dictionary) -> void:
	"""
	Update item properties
	updates format: {"is_equipped": true, "is_used": false}
	"""
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[InventoryHelper] User not logged in")
		return
	
	var url = "%s/users/%s/inventory/%s" % [firestore_base_url, user_id, item_id]
	
	# Build update fields
	var fields = {}
	var field_paths = []
	
	for key in updates.keys():
		field_paths.append(key)
		var value = updates[key]
		
		if typeof(value) == TYPE_BOOL:
			fields[key] = {"booleanValue": value}
		elif typeof(value) == TYPE_INT:
			fields[key] = {"integerValue": str(value)}
		elif typeof(value) == TYPE_STRING:
			fields[key] = {"stringValue": value}
	
	# Build URL with updateMask
	var update_mask = "&".join(field_paths.map(func(fp): return "updateMask.fieldPaths=%s" % fp))
	url += "?" + update_mask
	
	var body = {"fields": fields}
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		http.queue_free()
		if code == 200:
			print("[InventoryHelper] ✅ Item updated: %s" % item_id)
		else:
			push_error("[InventoryHelper] ❌ Failed to update item")
	)
	
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))

# ✅ Helper: Parse Firestore response
func _parse_inventory_response(body: PackedByteArray) -> Array:
	"""Parse inventory data from Firestore"""
	var json_str = body.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	
	if not data or not data.has("documents"):
		return []
	
	var items: Array = []
	
	for doc in data["documents"]:
		if not doc.has("fields"):
			continue
		
		var fields = doc["fields"]
		var item = {
			"id": doc.get("name", "").split("/")[-1],
			"name": fields.get("name", {}).get("stringValue", "Unknown"),
			"type": fields.get("type", {}).get("stringValue", "item"),
			"rarity": fields.get("rarity", {}).get("stringValue", "common"),
			"description": fields.get("description", {}).get("stringValue", ""),
			"icon_path": fields.get("icon_path", {}).get("stringValue", ""),
			"amount": int(fields.get("amount", {}).get("integerValue", 1)),
			"date_acquired": int(fields.get("date_acquired", {}).get("integerValue", 0)),
			"is_equipped": fields.get("is_equipped", {}).get("booleanValue", false),
			"is_used": fields.get("is_used", {}).get("booleanValue", false)
		}
		items.append(item)
	
	return items


# ========== QUICK ADD FUNCTIONS (NON-STATIC) ==========
# ✅ FIX: Remove "static" keyword - these are now instance methods

func quick_add_badge(item_name: String, rarity: String = "common", description: String = "") -> void:
	add_item_to_inventory({
		"name": item_name,
		"type": "badge",
		"rarity": rarity,
		"description": description,
		"icon_path": "res://asset/icons/badge_icon.png"
	})

func quick_add_card(item_name: String, rarity: String = "common", description: String = "") -> void:
	add_item_to_inventory({
		"name": item_name,
		"type": "card",
		"rarity": rarity,
		"description": description,
		"icon_path": "res://asset/icons/card_icon.png"
	})

func quick_add_avatar(item_name: String, avatar_path: String, rarity: String = "rare") -> void:
	add_item_to_inventory({
		"name": item_name,
		"type": "avatar",
		"rarity": rarity,
		"description": "Unlocked avatar",
		"icon_path": avatar_path
	})

func quick_add_powerup(item_name: String, amount: int = 1, description: String = "") -> void:
	add_item_to_inventory({
		"name": item_name,
		"type": "powerup",
		"rarity": "uncommon",
		"description": description,
		"icon_path": "res://asset/icons/powerup_icon.png",
		"amount": amount
	})
