# CyberCoinManager.gd
# Autoload singleton — manages CyberCoin currency (separate from XP).
# CyberCoins are earned through gameplay and spent in the shop.
# Stored in Firestore users/{uid} document under "cybercoins" field.
# ============================================================================
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal balance_changed(new_balance: int)
signal coins_earned(amount: int, reason: String)
signal coins_spent(amount: int, item_name: String)
signal daily_bonus_claimed(amount: int)

# ── Constants ────────────────────────────────────────────────────────────────
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents"

# XP-to-CyberCoin conversion rate: 1 CyberCoin per this many XP earned
const XP_TO_COIN_RATE := 10

# Daily login bonus
const DAILY_BONUS_AMOUNT := 10

# Earning rates by source
const EARN_RATES := {
	# Quiz: coins per correct answer
	"quiz_per_correct": 10,
	# PvP win reward
	"pvp_win": 50,
	# Tutorial/minigame completion (first time)
	"tutorial_complete": 30,
	# Minigame completion (first time)
	"minigame_complete": 25,
}

# ── State ────────────────────────────────────────────────────────────────────
var balance: int = 0
var _last_daily_claim_date: String = ""  # "YYYY-MM-DD" format
var _data_loaded: bool = false


# ─────────────────────────────────────────────────────────────────────────────
# CORE API
# ─────────────────────────────────────────────────────────────────────────────

## Add coins and save. Returns the new balance.
func add_coins(amount: int, reason: String = "Bonus") -> int:
	if amount <= 0:
		push_warning("[CyberCoin] Cannot add %d coins (must be positive)" % amount)
		return balance
	balance += amount
	print("[CyberCoin] +%d coins (%s) → Balance: %d" % [amount, reason, balance])
	coins_earned.emit(amount, reason)
	balance_changed.emit(balance)
	_save_to_firestore()
	return balance


## Spend coins. Returns true if successful, false if insufficient funds.
func spend_coins(amount: int, item_name: String = "") -> bool:
	if amount <= 0:
		push_warning("[CyberCoin] Cannot spend %d coins (must be positive)" % amount)
		return false
	if balance < amount:
		print("[CyberCoin] ❌ Insufficient funds: need %d, have %d" % [amount, balance])
		return false
	balance -= amount
	print("[CyberCoin] -%d coins (%s) → Balance: %d" % [amount, item_name, balance])
	coins_spent.emit(amount, item_name)
	balance_changed.emit(balance)
	_save_to_firestore()
	return true


## Check if player can afford an amount.
func can_afford(amount: int) -> bool:
	return balance >= amount


## Get current balance.
func get_balance() -> int:
	return balance


# ─────────────────────────────────────────────────────────────────────────────
# EARNING SOURCES
# ─────────────────────────────────────────────────────────────────────────────

## Award coins for quiz completion (score-based: coins per correct answer).
func award_quiz_coins(correct_count: int, quiz_title: String = "Quiz") -> int:
	var coins := correct_count * EARN_RATES["quiz_per_correct"]
	if coins > 0:
		add_coins(coins, "Quiz: %s (%d correct)" % [quiz_title, correct_count])
	return coins


## Award coins for PvP match win.
func award_pvp_win(game_type: String = "PvP") -> int:
	var coins := EARN_RATES["pvp_win"]
	add_coins(coins, "PvP Win: %s" % game_type)
	return coins


## Award coins for tutorial completion (first time only, checked externally).
func award_tutorial_coins(tutorial_id: String) -> int:
	var coins := EARN_RATES["tutorial_complete"]
	add_coins(coins, "Tutorial: %s" % tutorial_id)
	return coins


## Award coins for minigame completion (first time only, checked externally).
func award_minigame_coins(minigame_id: String) -> int:
	var coins := EARN_RATES["minigame_complete"]
	add_coins(coins, "Minigame: %s" % minigame_id)
	return coins


## Convert XP earned into CyberCoins. Call when XP is awarded.
## Returns coins earned from conversion.
func award_xp_conversion(xp_amount: int, reason: String = "XP") -> int:
	@warning_ignore("integer_division")
	var coins := xp_amount / XP_TO_COIN_RATE  # Integer division (intentional)
	if coins > 0:
		add_coins(coins, "XP Conversion: +%d XP (%s)" % [xp_amount, reason])
	return coins


## Claim daily login bonus. Returns coins earned (0 if already claimed today).
func claim_daily_bonus() -> int:
	var today := _get_today_str()
	if _last_daily_claim_date == today:
		print("[CyberCoin] Daily bonus already claimed today (%s)" % today)
		return 0
	_last_daily_claim_date = today
	var coins := DAILY_BONUS_AMOUNT
	add_coins(coins, "Daily Login Bonus")
	daily_bonus_claimed.emit(coins)
	return coins


## Check if daily bonus is available.
func is_daily_bonus_available() -> bool:
	return _last_daily_claim_date != _get_today_str()


# ─────────────────────────────────────────────────────────────────────────────
# FIRESTORE PERSISTENCE
# ─────────────────────────────────────────────────────────────────────────────

## Load CyberCoin balance from Firestore user document.
## Call after Auth is ready (e.g., after TutorialManager.load_user_data).
func load_from_firestore() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[CyberCoin] Cannot load: no auth state")
		return

	var url := "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := ["Authorization: Bearer %s" % Auth.current_id_token]
	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code != 200:
			print("[CyberCoin] ⚠️ Could not load user doc (code %d), defaulting to 0" % code)
			_data_loaded = true
			balance_changed.emit(balance)
			return

		var json = JSON.parse_string(body.get_string_from_utf8())
		if typeof(json) != TYPE_DICTIONARY or not json.has("fields"):
			_data_loaded = true
			balance_changed.emit(balance)
			return

		var fields: Dictionary = json["fields"]

		# Load balance
		if fields.has("cybercoins") and fields["cybercoins"].has("integerValue"):
			balance = int(fields["cybercoins"]["integerValue"])
		else:
			balance = 0

		# Load last daily claim date
		if fields.has("cybercoin_daily_claim") and fields["cybercoin_daily_claim"].has("stringValue"):
			_last_daily_claim_date = fields["cybercoin_daily_claim"]["stringValue"]

		_data_loaded = true
		print("[CyberCoin] ✅ Loaded balance: %d | Last daily: %s" % [balance, _last_daily_claim_date])
		balance_changed.emit(balance)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


## Save balance to Firestore (uses PATCH with updateMask to avoid overwriting other fields).
func _save_to_firestore() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[CyberCoin] Cannot save: no auth state")
		return

	var url := "%s/users/%s?updateMask.fieldPaths=cybercoins&updateMask.fieldPaths=cybercoin_daily_claim" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	var body := {
		"fields": {
			"cybercoins": {"integerValue": str(balance)},
			"cybercoin_daily_claim": {"stringValue": _last_daily_claim_date},
		}
	}

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body):
		http.queue_free()
		if code == 200:
			print("[CyberCoin] 💾 Saved balance: %d" % balance)
		else:
			var resp: String = _body.get_string_from_utf8() if _body.size() > 0 else ""
			push_error("[CyberCoin] ❌ Save failed (%d): %s" % [code, resp])
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))


## Reset data on logout.
func reset_data() -> void:
	balance = 0
	_last_daily_claim_date = ""
	_data_loaded = false
	balance_changed.emit(balance)
	print("[CyberCoin] 🔄 Data reset")


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _get_today_str() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
