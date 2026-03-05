# ShopManager.gd
# Autoload singleton — Shop catalog, purchases, equip state.
# Uses CyberCoinManager for currency, InventoryHelper for inventory persistence.
# Equipped cosmetics are stored on the Firestore user doc so arenas can read them.
# ============================================================================
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal item_purchased(item_id: String, category: String)
signal item_equipped(item_id: String, category: String)
signal owned_items_loaded

# ── Firestore ────────────────────────────────────────────────────────────────
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents"

# ── Equip Slot Keys (stored on users/{uid}) ──────────────────────────────────
const SLOT_AVATAR           := "equipped_avatar"
const SLOT_BG_DEFUSE_TROJAN := "equipped_bg_defuse_trojan"
const SLOT_BG_AKASHIC_TCG   := "equipped_bg_akashic_tcg"
const SLOT_BG_CODE_BREAKER  := "equipped_bg_code_breaker"
const SLOT_SKIN_DEFUSE_TROJAN := "equipped_skin_defuse_trojan"
const SLOT_SKIN_AKASHIC_TCG   := "equipped_skin_akashic_tcg"
const SLOT_SKIN_CODE_BREAKER  := "equipped_skin_code_breaker"

# ── Category IDs (tab keys) ─────────────────────────────────────────────────
const CAT_AVATAR   := "avatar"
const CAT_BG       := "background"
const CAT_SKIN     := "skin"

# ── State ────────────────────────────────────────────────────────────────────
# { item_id: true } — set of all owned item IDs
var _owned: Dictionary = {}
# { slot_key: item_id } — currently equipped per slot
var _equipped: Dictionary = {}
var _data_loaded: bool = false

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  S H O P   C A T A L O G                                                ║
# ║  Add / remove items here. Everything else derives from this list.        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Each item dict:
#   id         : unique string
#   name       : display name
#   category   : CAT_AVATAR | CAT_BG | CAT_SKIN
#   price      : int (CyberCoins)
#   icon_path  : preview texture path (res://)
#   slot       : equip slot key (SLOT_*)
#   apply_value: the resource path/value the arena reads at runtime
#   rarity     : "common" | "uncommon" | "rare" | "epic" | "legendary"
#   description: flavour text
#   default    : bool — true = every player owns it from the start

const CATALOG: Array[Dictionary] = [
	# ──────── AVATARS ──────────────────────────────────────────────────────
	# Default avatars (1-12) are free / already available in AvatarPicker.
	# Shop-exclusive premium avatars:
	{
		"id": "avatar_cyber_knight",
		"name": "Cyber Knight",
		"category": "avatar",
		"price": 100,
		"icon_path": "res://asset/avatars/avatar14.png",
		"slot": "equipped_avatar",
		"apply_value": "avatar14.png",
		"rarity": "rare",
		"description": "A cybernetic warrior avatar.",
		"default": false,
	},
	{
		"id": "avatar_neon_hacker",
		"name": "Neon Hacker",
		"category": "avatar",
		"price": 100,
		"icon_path": "res://asset/avatars/avatar15.png",
		"slot": "equipped_avatar",
		"apply_value": "avatar15.png",
		"rarity": "rare",
		"description": "A neon-lit hacker avatar.",
		"default": false,
	},
	{
		"id": "avatar_shadow_agent",
		"name": "Shadow Agent",
		"category": "avatar",
		"price": 150,
		"icon_path": "res://asset/avatars/avatar16.png",
		"slot": "equipped_avatar",
		"apply_value": "avatar16.png",
		"rarity": "epic",
		"description": "An elite shadow operative.",
		"default": false,
	},
	{
		"id": "avatar_quantum_sentinel",
		"name": "Quantum Sentinel",
		"category": "avatar",
		"price": 200,
		"icon_path": "res://asset/avatars/avatar17.png",
		"slot": "equipped_avatar",
		"apply_value": "avatar17.png",
		"rarity": "epic",
		"description": "Guardian of the quantum realm.",
		"default": false,
	},
	{
		"id": "avatar_digital_phoenix",
		"name": "Digital Phoenix",
		"category": "avatar",
		"price": 300,
		"icon_path": "res://asset/avatars/avatar18.png",
		"slot": "equipped_avatar",
		"apply_value": "avatar18.png",
		"rarity": "legendary",
		"description": "Reborn from digital ashes.",
		"default": false,
	},

	# ──────── GAME BACKGROUNDS ─────────────────────────────────────────────
	# Defuse the Trojan
	{
		"id": "bg_dt_default",
		"name": "Deep Space (Default)",
		"category": "background",
		"price": 0,
		"icon_path": "res://asset/defuse_trojan/space_background.jpg",
		"slot": "equipped_bg_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/space_background.jpg",
		"rarity": "common",
		"description": "The classic deep space background.",
		"default": true,
	},
	{
		"id": "bg_dt_nebula",
		"name": "Nebula Storm",
		"category": "background",
		"price": 120,
		"icon_path": "res://asset/background/Gemini_Generated_Image_2an8k72an8k72an8.png",
		"slot": "equipped_bg_defuse_trojan",
		"apply_value": "res://asset/background/Gemini_Generated_Image_2an8k72an8k72an8.png",
		"rarity": "rare",
		"description": "A swirling nebula backdrop for your battles.",
		"default": false,
	},
	{
		"id": "bg_dt_cyber_grid",
		"name": "Cyber Grid",
		"category": "background",
		"price": 200,
		"icon_path": "res://asset/background/Gemini_Generated_Image_mw5j4wmw5j4wmw5j.png",
		"slot": "equipped_bg_defuse_trojan",
		"apply_value": "res://asset/background/Gemini_Generated_Image_mw5j4wmw5j4wmw5j.png",
		"rarity": "epic",
		"description": "A futuristic cyber grid arena.",
		"default": false,
	},
	# Akashic TCG
	{
		"id": "bg_atcg_default",
		"name": "Akashic Chamber (Default)",
		"category": "background",
		"price": 0,
		"icon_path": "res://asset/background/Akashic room background.png",
		"slot": "equipped_bg_akashic_tcg",
		"apply_value": "res://asset/background/Akashic room background.png",
		"rarity": "common",
		"description": "The original Akashic Chamber.",
		"default": true,
	},
	{
		"id": "bg_atcg_dark_throne",
		"name": "Dark Throne",
		"category": "background",
		"price": 150,
		"icon_path": "res://asset/background/Gemini_Generated_Image_tyhhtqtyhhtqtyhh.png",
		"slot": "equipped_bg_akashic_tcg",
		"apply_value": "res://asset/background/Gemini_Generated_Image_tyhhtqtyhhtqtyhh.png",
		"rarity": "rare",
		"description": "An ominous throne room arena.",
		"default": false,
	},
	# Code Breaker
	{
		"id": "bg_cb_default",
		"name": "Scanlines (Default)",
		"category": "background",
		"price": 0,
		"icon_path": "res://asset/background/code_breaker_background_scanlines 1.png",
		"slot": "equipped_bg_code_breaker",
		"apply_value": "res://asset/background/code_breaker_background_scanlines 1.png",
		"rarity": "common",
		"description": "The classic Code Breaker scanlines.",
		"default": true,
	},
	{
		"id": "bg_cb_neon_city",
		"name": "Neon City",
		"category": "background",
		"price": 150,
		"icon_path": "res://asset/background/Code Breaker Arena Background.png",
		"slot": "equipped_bg_code_breaker",
		"apply_value": "res://asset/background/Code Breaker Arena Background.png",
		"rarity": "rare",
		"description": "A vibrant neon cityscape arena.",
		"default": false,
	},
	{
		"id": "bg_cb_dark_terminal",
		"name": "Dark Terminal",
		"category": "background",
		"price": 200,
		"icon_path": "res://asset/background/windows-10-dark-blue-5k-8k-3840x2160-733.jpg",
		"slot": "equipped_bg_code_breaker",
		"apply_value": "res://asset/background/windows-10-dark-blue-5k-8k-3840x2160-733.jpg",
		"rarity": "epic",
		"description": "A dark hacker terminal environment.",
		"default": false,
	},

	# ──────── GAME SKINS ───────────────────────────────────────────────────
	# Defuse the Trojan — player ship skins (SpriteFrames swap)
	{
		"id": "skin_dt_default",
		"name": "Standard Ship (Default)",
		"category": "skin",
		"price": 0,
		"icon_path": "res://asset/defuse_trojan/player_idle_spritesheet.jpg",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/player_frames.tres",
		"rarity": "common",
		"description": "The standard combat ship.",
		"default": true,
	},
	{
		"id": "skin_dt_stealth",
		"name": "Stealth Interceptor",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/defuse_trojan/stealth_ship_spritesheetA.png",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/stealth_ship_frames.tres",
		"rarity": "epic",
		"description": "A cloaked interceptor craft.",
		"default": false,
	},
	{
		"id": "skin_dt_neon_phoenix",
		"name": "Neon Phoenix",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/defuse_trojan/Neon PhoenixA.png",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/Neon Phoenix.tres",
		"rarity": "epic",
		"description": "A blazing phoenix-shaped fighter reborn from digital fire.",
		"default": false,
	},
	{
		"id": "skin_dt_quantum_cruiser",
		"name": "Quantum Cruiser",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/defuse_trojan/Quantum CruiserBC.png",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/Quantum Cruiser.tres",
		"rarity": "rare",
		"description": "A crystalline cruiser phasing through dimensions.",
		"default": false,
	},
	{
		"id": "skin_dt_void_reaper",
		"name": "Void Reaper",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/defuse_trojan/Void ReaperB-Photoroom.png",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/Void Reaper.tres",
		"rarity": "legendary",
		"description": "A menacing warship forged in the cosmic void.",
		"default": false,
	},
	{
		"id": "skin_dt_solar_falcon",
		"name": "Solar Falcon",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/defuse_trojan/Solar Falconicon.png",
		"slot": "equipped_skin_defuse_trojan",
		"apply_value": "res://asset/defuse_trojan/Solar Falcon.tres",
		"rarity": "rare",
		"description": "A sleek golden fighter powered by solar energy.",
		"default": false,
	},

	# Akashic TCG — card back skins
	{
		"id": "skin_atcg_default",
		"name": "Classic Card Back (Default)",
		"category": "skin",
		"price": 0,
		"icon_path": "res://asset/cards for AkashicTGC/back cards.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/cards for AkashicTGC/back cards.png",
		"rarity": "common",
		"description": "The classic Akashic card back.",
		"default": true,
	},
	{
		"id": "skin_atcg_chariot",
		"name": "The Celestial Oracle Back",
		"category": "skin",
		"price": 5,
		"icon_path": "res://asset/reward_background_cards/Celestial Oracle.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/reward_background_cards/Celestial Oracle.png",
		"rarity": "rare",
		"description": "An elegant chariot-themed card back.",
		"default": false,
	},
	{
		"id": "skin_atcg_hermit",
		"name": "The Void Serpent Back",
		"category": "skin",
		"price": 180,
		"icon_path": "res://asset/reward_background_cards/Void SerpentA.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/reward_background_cards/Void SerpentA.png",
		"rarity": "rare",
		"description": "A mysterious hermit-themed card back.",
		"default": false,
	},
		{
		"id": "skin_atcg_dragons_eye",
		"name": "The Dragon's Eye Back",
		"category": "skin",
		"price": 180,
		"icon_path": "res://asset/reward_background_cards/Dragons Eye.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/reward_background_cards/Dragons Eye.png",
		"rarity": "epic",
		"description": "A fiery dragon eye burns on the card back.",
		"default": false,
	},
		{
		"id": "skin_atcg_frost_sigil",
		"name": "The Frost Sigil Back",
		"category": "skin",
		"price": 180,
		"icon_path": "res://asset/reward_background_cards/Frost Sigil.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/reward_background_cards/Frost Sigil.png",
		"rarity": "rare",
		"description": "Ancient frost runes seal the card.",
		"default": false,
	},
		{
		"id": "skin_atcg_shadow_throne",
		"name": "The Shadow Throne Back",
		"category": "skin",
		"price": 180,
		"icon_path": "res://asset/reward_background_cards/Shadow Throne.png",
		"slot": "equipped_skin_akashic_tcg",
		"apply_value": "res://asset/reward_background_cards/Shadow Throne.png",
		"rarity": "epic",
		"description": "A dark throne shrouded in shadow.",
		"default": false,
	},
	# Code Breaker — break effect skins (shader parameter presets)
	{
		"id": "skin_cb_default",
		"name": "Cyan Shatter (Default)",
		"category": "skin",
		"price": 0,
		"icon_path": "res://asset/code breaker/panels/normal.png",
		"slot": "equipped_skin_code_breaker",
		"apply_value": "default",
		"rarity": "common",
		"description": "The classic cyan break effect.",
		"default": true,
	},
	{
		"id": "skin_cb_crimson",
		"name": "Crimson Fracture",
		"category": "skin",
		"price": 150,
		"icon_path": "res://asset/code breaker/panels/normal.png",
		"slot": "equipped_skin_code_breaker",
		"apply_value": "crimson",
		"rarity": "rare",
		"description": "Fiery red cracks with explosive shards.",
		"default": false,
	},
]


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  R U N T I M E   A P I                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

func get_catalog(category: String = "") -> Array[Dictionary]:
	"""Return catalog items, optionally filtered by category."""
	if category == "":
		return CATALOG
	var result: Array[Dictionary] = []
	for item in CATALOG:
		if item["category"] == category:
			result.append(item)
	return result


func get_item(item_id: String) -> Dictionary:
	for item in CATALOG:
		if item["id"] == item_id:
			return item
	return {}


func is_owned(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.get("default", false):
		return true
	return _owned.has(item_id)


func is_equipped(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty():
		return false
	var slot: String = item.get("slot", "")
	return _equipped.get(slot, "") == item_id


func get_equipped_value(slot: String) -> String:
	"""Return the apply_value for the currently equipped item in a slot, or empty."""
	var item_id: String = _equipped.get(slot, "")
	if item_id == "":
		return ""
	var item := get_item(item_id)
	return item.get("apply_value", "")


func purchase(item_id: String) -> bool:
	"""Buy an item. Returns true on success."""
	if is_owned(item_id):
		print("[Shop] Already owned: %s" % item_id)
		return false
	var item := get_item(item_id)
	if item.is_empty():
		push_error("[Shop] Unknown item: %s" % item_id)
		return false
	var price: int = item.get("price", 0)
	if not CyberCoinManager.can_afford(price):
		print("[Shop] Cannot afford %s (need %d, have %d)" % [item_id, price, CyberCoinManager.get_balance()])
		return false

	# Deduct coins
	if price > 0:
		CyberCoinManager.spend_coins(price, "Shop: %s" % item.get("name", item_id))

	# Mark owned
	_owned[item_id] = true
	_save_owned_to_firestore()

	# Add to InventoryHelper for the Bag panel
	InventoryHelper.add_item_to_inventory({
		"name": item.get("name", ""),
		"type": item.get("category", ""),
		"subtype": item.get("slot", ""),
		"rarity": item.get("rarity", "common"),
		"description": item.get("description", ""),
		"icon_path": item.get("icon_path", ""),
		"amount": 1,
	})

	item_purchased.emit(item_id, item.get("category", ""))
	print("[Shop] ✅ Purchased: %s for %d coins" % [item_id, price])
	return true


func equip(item_id: String) -> bool:
	"""Equip an owned item. Returns true on success."""
	if not is_owned(item_id):
		print("[Shop] Not owned: %s" % item_id)
		return false
	var item := get_item(item_id)
	if item.is_empty():
		return false
	var slot: String = item.get("slot", "")
	_equipped[slot] = item_id
	_save_equipped_to_firestore()
	item_equipped.emit(item_id, item.get("category", ""))
	print("[Shop] 🎨 Equipped: %s → slot %s" % [item_id, slot])
	return true


# ──────────────────────────────────────────────────────────────────────────
# FIRESTORE PERSISTENCE
# ──────────────────────────────────────────────────────────────────────────

func load_from_firestore() -> void:
	"""Load owned items and equipped slots from users/{uid}."""
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	var url := "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := ["Authorization: Bearer %s" % Auth.current_id_token]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			_data_loaded = true
			owned_items_loaded.emit()
			return
		var json = JSON.parse_string(body.get_string_from_utf8())
		if typeof(json) != TYPE_DICTIONARY or not json.has("fields"):
			_data_loaded = true
			owned_items_loaded.emit()
			return
		var fields: Dictionary = json["fields"]

		# Parse owned set
		_owned.clear()
		if fields.has("shop_owned") and fields["shop_owned"].has("mapValue"):
			var mv = fields["shop_owned"]["mapValue"].get("fields", {})
			for k in mv.keys():
				_owned[k] = true

		# Parse equipped dict
		_equipped.clear()
		if fields.has("shop_equipped") and fields["shop_equipped"].has("mapValue"):
			var mv = fields["shop_equipped"]["mapValue"].get("fields", {})
			for k in mv.keys():
				if mv[k].has("stringValue"):
					_equipped[k] = mv[k]["stringValue"]

		# Fill defaults for any slot that has no equip (use catalog defaults)
		for item in CATALOG:
			if item.get("default", false):
				var slot: String = item.get("slot", "")
				if not _equipped.has(slot):
					_equipped[slot] = item["id"]

		_data_loaded = true
		print("[Shop] ✅ Loaded %d owned, %d equipped" % [_owned.size(), _equipped.size()])
		owned_items_loaded.emit()
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _save_owned_to_firestore() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	var map_fields := {}
	for k in _owned.keys():
		map_fields[k] = {"booleanValue": true}

	var url := "%s/users/%s?updateMask.fieldPaths=shop_owned" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token,
	]
	var body := {"fields": {"shop_owned": {"mapValue": {"fields": map_fields}}}}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func _save_equipped_to_firestore() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		return
	var map_fields := {}
	for k in _equipped.keys():
		map_fields[k] = {"stringValue": _equipped[k]}

	var url := "%s/users/%s?updateMask.fieldPaths=shop_equipped" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token,
	]
	var body := {"fields": {"shop_equipped": {"mapValue": {"fields": map_fields}}}}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


func reset_data() -> void:
	_owned.clear()
	_equipped.clear()
	_data_loaded = false
