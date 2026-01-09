extends RefCounted
class_name AvatarCatalog

# Friendly display names for preset avatars.
# Keeps Firestore/avatar ids stable (e.g., "default.png"), only changes UI labels.
const DISPLAY_NAMES := {
	"default.png": "Cyber Wolf",
	"avatar1.png": "Neon Ronin",
	"avatar2.png": "Synth Assassin",
	"avatar3.png": "Chrome Queen",
	"avatar4.png": "Night Hacker",
	"avatar5.png": "Void Operative",
	"avatar6.png": "Glitch Warden",
	"avatar7.png": "Circuit Reaper",
	"avatar8.png": "Data Phantom",
	"avatar9.png": "Arc Enforcer",
	"avatar10.png": "Hex Vanguard",
	"avatar11.png": "Pulse Raider",
	"avatar12.png": "Shadow Protocol",
	"avatar14.png": "Quantum Rogue",
	"avatar15.png": "Specter Agent",
	"avatar16.png": "Neon Revenant",
	"avatar17.png": "Codebreaker",
	"avatar18.png": "Apex Cipher",
}

static func normalize_avatar_id(avatar_id: String) -> String:
	# Accept values like "default.png" or "res://asset/avatars/default.png".
	if avatar_id.begins_with("res://") or avatar_id.begins_with("user://"):
		return avatar_id.get_file()
	return avatar_id

static func get_display_name(avatar_id: String) -> String:
	var key := normalize_avatar_id(avatar_id)
	if DISPLAY_NAMES.has(key):
		return str(DISPLAY_NAMES[key])
	# Fallback: derive from filename.
	var base := key.get_basename()
	var pretty := base.replace("_", " ").replace("-", " ")
	return pretty.capitalize()
