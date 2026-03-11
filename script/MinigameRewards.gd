# MinigameRewards.gd
# Autoload singleton — add to Project > Project Settings > Autoload as "MinigameRewards"
#
# Manages per-minigame reward drops (badge + card + avatar, legendary powerup).
#
# Usage A (award_minigame_xp scripts):
#   var xp = TutorialManager.award_minigame_xp(id, xp, score)
#   if xp > 0: MinigameRewards.try_grant_rewards(id, score, xp, self)
#
# Usage B (save_tutorial_result scripts):
#   var first_time = MinigameRewards.is_first_completion(id)
#   tutorial_mgr.save_tutorial_result(id, score, max_score)
#   if first_time: MinigameRewards.try_grant_rewards(id, score, 100, self)
# ============================================================================
extends Node

# ============================================================================
# FOLDER STRUCTURE — place your .png files here
# ============================================================================
# All reward textures live under  res://asset/rewards/<folder_name>/
#
# Each folder needs these files (you provide the PNGs):
#   badge_common.png      — Common badge icon
#   card_rare.png         — Rare card artwork
#   avatar_epic.png       — Epic avatar unlock
#   powerup_legendary.png — Legendary powerup (only shown on high score)
#
# Example for beginner_fundamentals:
#   res://asset/rewards/beginner_fundamentals/badge_common.png
#   res://asset/rewards/beginner_fundamentals/card_rare.png
#   res://asset/rewards/beginner_fundamentals/avatar_epic.png
#   res://asset/rewards/beginner_fundamentals/powerup_legendary.png
# ============================================================================

const REWARD_BASE_PATH := "res://asset/rewards/"

# ── Map in-script game IDs → reward folder names ──────────────────────────
# Some scripts use different IDs than the mode_selection / folder names.
# Any ID not listed here is assumed to match the folder name directly.
const SCRIPT_ID_TO_FOLDER := {
	# Pattern A — award_minigame_xp IDs
	"malware_defense":     "beginner_malware",
	"asset_vs_threats":    "intermediate_assetandthreat",
	"incident_commander":  "intermediate_incident_commander",
	"crypt_contract":      "intermediate_crypt_contract",
	"cmd_defender":        "intermediate_incident_commander",
	"drop_zone_defender":  "beginner_drop_zone",
	"security_guardian":   "advanced_security_guardian",
	# Pattern B — save_tutorial_result IDs
	"beginner_encryption": "advanced_encryption",
	"network_defense":     "beginner_network",
}

# ── Legendary score thresholds per game (score >= threshold → legendary) ──
# Tweak these values to control how hard legendary is to earn.
const LEGENDARY_THRESHOLDS := {
	"beginner_fundamentals": 90,
	"beginner_network": 90,
	"advanced_encryption": 90,
	"beginner_password": 150,
	"beginner_malware": 80,
	"beginner_drop_zone": 400,
	"intermediate_phishing": 1000,
	"intermediate_assetandthreat": 400,
	"intermediate_crypt_contract": 400,
	"intermediate_incident_commander": 400,
	"advanced_crypto_sorter": 400,
	"advanced_rsa_key_lab": 400,
	"advanced_security_guardian": 400,
}

# ── Reward definitions for every game ─────────────────────────────────────
# Each game maps to an array of reward dicts:
#   type     : "badge" | "card" | "avatar" | "powerup"
#   rarity   : "common" | "rare" | "epic" | "legendary"
#   name     : display name shown in popup
#   file     : texture filename inside the game's reward folder
#   desc     : short flavour text
#   legendary: bool — only included when score meets the threshold
#
# The first 3 rewards are ALWAYS given (common badge, rare card, epic avatar).
# The 4th (legendary powerup) is conditional on score.

const GAME_REWARDS := {
	# ────────────────────── BEGINNER ──────────────────────────────────────
	"beginner_fundamentals": [
		{"type": "badge", "rarity": "common", "name": "Cyber Recruit Badge", "file": "badge_common.png", "desc": "Awarded for completing Cybersecurity Fundamentals."},
		{"type": "card", "rarity": "rare", "name": "Firewall Sentinel Card", "file": "card_rare.png", "desc": "A rare card depicting the first line of defense."},
		{"type": "avatar", "rarity": "epic", "name": "Agent Zero Avatar", "file": "avatar_epic.png", "desc": "An epic avatar for budding cyber agents."},
		{"type": "powerup", "rarity": "legendary", "name": "Cyber Shield Boost", "file": "powerup_legendary.png", "desc": "A legendary powerup — double XP on your next game!", "legendary": true},
	],
	"beginner_network": [
		{"type": "badge", "rarity": "common", "name": "Network Explorer Badge", "file": "badge_common.png", "desc": "Awarded for mastering Network Basics."},
		{"type": "card", "rarity": "rare", "name": "Packet Tracer Card", "file": "card_rare.png", "desc": "A rare card showing data packets in flight."},
		{"type": "avatar", "rarity": "epic", "name": "Router Guardian Avatar", "file": "avatar_epic.png", "desc": "An epic avatar of the network protector."},
		{"type": "powerup", "rarity": "legendary", "name": "Bandwidth Surge", "file": "powerup_legendary.png", "desc": "Legendary powerup — bonus combo multiplier!", "legendary": true},
	],
	"advanced_encryption": [
		{"type": "badge", "rarity": "common", "name": "Cipher Initiate Badge", "file": "badge_common.png", "desc": "Awarded for unlocking the secrets of encryption."},
		{"type": "card", "rarity": "rare", "name": "Caesar Wheel Card", "file": "card_rare.png", "desc": "A rare card featuring the classic Caesar cipher."},
		{"type": "avatar", "rarity": "epic", "name": "Cryptkeeper Avatar", "file": "avatar_epic.png", "desc": "An epic avatar shrouded in encrypted mystery."},
		{"type": "powerup", "rarity": "legendary", "name": "Decryption Key", "file": "powerup_legendary.png", "desc": "Legendary powerup — instant hint in crypto games!", "legendary": true},
	],
	"beginner_password": [
		{"type": "badge", "rarity": "common", "name": "Fortress Builder Badge", "file": "badge_common.png", "desc": "Awarded for defending the Password Fortress."},
		{"type": "card", "rarity": "rare", "name": "Iron Gate Card", "file": "card_rare.png", "desc": "A rare card depicting an impenetrable gate."},
		{"type": "avatar", "rarity": "epic", "name": "Vault Keeper Avatar", "file": "avatar_epic.png", "desc": "An epic avatar of the vault's guardian."},
		{"type": "powerup", "rarity": "legendary", "name": "Unbreakable Wall", "file": "powerup_legendary.png", "desc": "Legendary powerup — extra life in battle games!", "legendary": true},
	],
	"beginner_malware": [
		{"type": "badge", "rarity": "common", "name": "Malware Hunter Badge", "file": "badge_common.png", "desc": "Awarded for identifying all malware types."},
		{"type": "card", "rarity": "rare", "name": "Trojan Horse Card", "file": "card_rare.png", "desc": "A rare card revealing the hidden threat."},
		{"type": "avatar", "rarity": "epic", "name": "Virus Slayer Avatar", "file": "avatar_epic.png", "desc": "An epic avatar of the malware destroyer."},
		{"type": "powerup", "rarity": "legendary", "name": "Antivirus Overcharge", "file": "powerup_legendary.png", "desc": "Legendary powerup — area-of-effect damage boost!", "legendary": true},
	],
	# ────────────────────── INTERMEDIATE ──────────────────────────────────
	"beginner_drop_zone": [
		{"type": "badge", "rarity": "common", "name": "Drop Zone Ace Badge", "file": "badge_common.png", "desc": "Awarded for mastering data vs network classification."},
		{"type": "card", "rarity": "rare", "name": "Firewall Matrix Card", "file": "card_rare.png", "desc": "A rare card showing layered firewall rules."},
		{"type": "avatar", "rarity": "epic", "name": "Data Warden Avatar", "file": "avatar_epic.png", "desc": "An epic avatar who guards the data streams."},
		{"type": "powerup", "rarity": "legendary", "name": "Sorting Surge", "file": "powerup_legendary.png", "desc": "Legendary powerup — auto-sort one wave!", "legendary": true},
	],
	"intermediate_phishing": [
		{"type": "badge", "rarity": "common", "name": "Phishing Detective Badge", "file": "badge_common.png", "desc": "Awarded for spotting phishing attempts."},
		{"type": "card", "rarity": "rare", "name": "Bait & Hook Card", "file": "card_rare.png", "desc": "A rare card illustrating social engineering."},
		{"type": "avatar", "rarity": "epic", "name": "Inbox Guardian Avatar", "file": "avatar_epic.png", "desc": "An epic avatar protecting the inbox."},
		{"type": "powerup", "rarity": "legendary", "name": "Spam Shield", "file": "powerup_legendary.png", "desc": "Legendary powerup — block one wrong answer!", "legendary": true},
	],
	"intermediate_assetandthreat": [
		{"type": "badge", "rarity": "common", "name": "Threat Analyst Badge", "file": "badge_common.png", "desc": "Awarded for defending assets from threats."},
		{"type": "card", "rarity": "rare", "name": "Risk Matrix Card", "file": "card_rare.png", "desc": "A rare card mapping assets to vulnerabilities."},
		{"type": "avatar", "rarity": "epic", "name": "Shield Operator Avatar", "file": "avatar_epic.png", "desc": "An epic avatar wielding a digital shield."},
		{"type": "powerup", "rarity": "legendary", "name": "Threat Neutralizer", "file": "powerup_legendary.png", "desc": "Legendary powerup — freeze all threats for 5s!", "legendary": true},
	],
	"intermediate_crypt_contract": [
		{"type": "badge", "rarity": "common", "name": "Crypto Engineer Badge", "file": "badge_common.png", "desc": "Awarded for completing the Crypt Contract."},
		{"type": "card", "rarity": "rare", "name": "Encryption Seal Card", "file": "card_rare.png", "desc": "A rare card sealed with cryptographic proof."},
		{"type": "avatar", "rarity": "epic", "name": "Key Master Avatar", "file": "avatar_epic.png", "desc": "An epic avatar who forges encryption keys."},
		{"type": "powerup", "rarity": "legendary", "name": "Master Key", "file": "powerup_legendary.png", "desc": "Legendary powerup — skip one encryption puzzle!", "legendary": true},
	],
	"intermediate_incident_commander": [
		{"type": "badge", "rarity": "common", "name": "Incident Commander Badge", "file": "badge_common.png", "desc": "Awarded for commanding the SOC center."},
		{"type": "card", "rarity": "rare", "name": "Alert Console Card", "file": "card_rare.png", "desc": "A rare card showing the SOC command console."},
		{"type": "avatar", "rarity": "epic", "name": "SOC Director Avatar", "file": "avatar_epic.png", "desc": "An epic avatar leading the security team."},
		{"type": "powerup", "rarity": "legendary", "name": "Command Override", "file": "powerup_legendary.png", "desc": "Legendary powerup — auto-resolve one incident!", "legendary": true},
	],
	# ────────────────────── ADVANCED ──────────────────────────────────────
	"advanced_crypto_sorter": [
		{"type": "badge", "rarity": "common", "name": "Crypto Sorter Badge", "file": "badge_common.png", "desc": "Awarded for sorting symmetric vs asymmetric crypto."},
		{"type": "card", "rarity": "rare", "name": "Algorithm Atlas Card", "file": "card_rare.png", "desc": "A rare card cataloging every major algorithm."},
		{"type": "avatar", "rarity": "epic", "name": "Algorithm Sage Avatar", "file": "avatar_epic.png", "desc": "An epic avatar who knows every cipher."},
		{"type": "powerup", "rarity": "legendary", "name": "Cipher Mastery", "file": "powerup_legendary.png", "desc": "Legendary powerup — reveal answer hints!", "legendary": true},
	],
	"advanced_rsa_key_lab": [
		{"type": "badge", "rarity": "common", "name": "RSA Scholar Badge", "file": "badge_common.png", "desc": "Awarded for completing the RSA Key Lab."},
		{"type": "card", "rarity": "rare", "name": "Prime Factor Card", "file": "card_rare.png", "desc": "A rare card showing the beauty of prime numbers."},
		{"type": "avatar", "rarity": "epic", "name": "Cryptographer Avatar", "file": "avatar_epic.png", "desc": "An epic avatar of a master cryptographer."},
		{"type": "powerup", "rarity": "legendary", "name": "Prime Catalyst", "file": "powerup_legendary.png", "desc": "Legendary powerup — double score on next game!", "legendary": true},
	],
	"advanced_security_guardian": [
		{"type": "badge", "rarity": "common", "name": "Guardian Elite Badge", "file": "badge_common.png", "desc": "Awarded for mastering authentication security."},
		{"type": "card", "rarity": "rare", "name": "Auth Protocol Card", "file": "card_rare.png", "desc": "A rare card detailing multi-factor auth."},
		{"type": "avatar", "rarity": "epic", "name": "Sentinel Prime Avatar", "file": "avatar_epic.png", "desc": "An epic avatar — the ultimate security sentinel."},
		{"type": "powerup", "rarity": "legendary", "name": "Guardian's Blessing", "file": "powerup_legendary.png", "desc": "Legendary powerup — invincibility for one round!", "legendary": true},
	],
}


# ============================================================================
# PUBLIC API
# ============================================================================

## Resolve a script-level game ID to the canonical reward folder name.
func _resolve_folder(game_id: String) -> String:
	return SCRIPT_ID_TO_FOLDER.get(game_id, game_id)

## Check if this is the player's first time completing this game.
## Works for BOTH completion patterns (minigames + tutorials).
func is_first_completion(game_id: String) -> bool:
	var folder := _resolve_folder(game_id)
	# Check both tracking dicts in TutorialManager
	if TutorialManager.completed_minigames.has(game_id):
		return false
	if TutorialManager.completed_tutorials.has(game_id):
		return false
	# Also check by folder name in case IDs differ
	if game_id != folder:
		if TutorialManager.completed_minigames.has(folder):
			return false
		if TutorialManager.completed_tutorials.has(folder):
			return false
	return true

## Call after first-time completion.
## Shows the RewardPopup with 3 guaranteed rewards + optional legendary.
## Returns true if rewards were shown, false if skipped.
##
## @param game_id      The in-script game/tutorial ID
## @param score        The player's score
## @param xp_awarded   XP that was just awarded (> 0 means first-time)
## @param parent       Node to attach the popup to (usually `self`)
func try_grant_rewards(game_id: String, score: int, xp_awarded: int, parent: Node) -> bool:
	if xp_awarded <= 0:
		print("[MinigameRewards] Replay detected — no rewards for '%s'" % game_id)
		return false

	var folder := _resolve_folder(game_id)
	var defs: Array = GAME_REWARDS.get(folder, [])
	if defs.is_empty():
		push_warning("[MinigameRewards] No reward definitions for '%s' (folder: '%s')" % [game_id, folder])
		return false

	# Determine whether legendary is earned
	var legendary_threshold: int = LEGENDARY_THRESHOLDS.get(folder, 999999)
	var earned_legendary: bool = score >= legendary_threshold

	# Build RewardItem list
	var reward_list: Array = []
	for def in defs:
		var is_legendary: bool = def.get("legendary", false)
		if is_legendary and not earned_legendary:
			continue  # skip legendary if score too low

		var icon_path: String = REWARD_BASE_PATH + folder + "/" + str(def["file"])
		var icon_tex: Texture2D = null
		if ResourceLoader.exists(icon_path):
			icon_tex = load(icon_path)

		var ri = RewardItem.new(
			str(def["type"]),
			1,
			str(def["name"]),
			icon_tex,
			str(def["desc"]),
			str(def["rarity"])
		)
		reward_list.append(ri)

	if reward_list.is_empty():
		return false

	# Also add XP as a visible reward
	reward_list.push_front(RewardItem.new("xp", xp_awarded, "Experience Points", null, "+%d XP earned!" % xp_awarded))

	# Show popup
	var popup_scene = preload("res://scene/reward_popup.tscn")
	var popup = popup_scene.instantiate()
	parent.add_child(popup)

	var title := "🎉 REWARDS UNLOCKED!"
	if earned_legendary:
		title = "🌟 LEGENDARY REWARDS!"

	popup.show_rewards(reward_list, title)

	# NOTE: Inventory save is handled by RewardPopup._apply_rewards() when user clicks "Claim".
	# Do NOT save here — it would create duplicate items in Firestore.

	print("[MinigameRewards] Granted %d rewards for '%s' (folder: '%s', legendary=%s)" % [reward_list.size(), game_id, folder, earned_legendary])
	return true
