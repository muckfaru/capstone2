extends Node
class_name CodeBreakerSessionStore

const _PATH := "user://code_breaker_session.cfg"
const _SECTION := "code_breaker"

static func save_session(room_id: String, lobby_server_url: String, player_id: String, username: String, phase: String) -> void:
	if room_id.strip_edges() == "":
		return
	var safe_player_id := player_id
	if safe_player_id == "unknown":
		safe_player_id = ""
	var cfg := ConfigFile.new()
	cfg.load(_PATH)
	cfg.set_value(_SECTION, "room_id", room_id)
	cfg.set_value(_SECTION, "lobby_server_url", lobby_server_url)
	cfg.set_value(_SECTION, "player_id", safe_player_id)
	cfg.set_value(_SECTION, "username", username)
	cfg.set_value(_SECTION, "phase", phase)
	cfg.set_value(_SECTION, "timestamp", int(Time.get_unix_time_from_system()))
	cfg.save(_PATH)

static func load_session() -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(_PATH)
	if err != OK:
		return {}
	return {
		"room_id": str(cfg.get_value(_SECTION, "room_id", "")),
		"lobby_server_url": str(cfg.get_value(_SECTION, "lobby_server_url", "")),
		"player_id": str(cfg.get_value(_SECTION, "player_id", "")),
		"username": str(cfg.get_value(_SECTION, "username", "")),
		"phase": str(cfg.get_value(_SECTION, "phase", "")),
		"timestamp": int(cfg.get_value(_SECTION, "timestamp", 0)),
	}

static func clear_session() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(_PATH)
	if err != OK:
		return
	cfg.erase_section(_SECTION)
	cfg.save(_PATH)
