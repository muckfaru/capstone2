extends Control

## CODE BREAKER ARENA - Submit-Based Typing Combat
## 🎮 NEW MECHANICS (v3.0):
## - Type code in input field, press ENTER to submit
## - ✅ Correct submission: +3 score, -2 opponent HP
## - ❌ Wrong submission: -2 self HP (penalty)
## - First to 0 HP = LOSE
## - Case-sensitive, exact match required

# UI References
@onready var _host_name_label: Label = $HeaderPanel/HostNameLabel
@onready var _timer_label: Label = $HeaderPanel/TimerLabel
@onready var _client_name_label: Label = $HeaderPanel/ClientNameLabel
@onready var _ws_indicator: ColorRect = $HeaderPanel/WSIndicator
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _p1_score: Label = $VBox/ScorePanel/ScoreP1
@onready var _p2_score: Label = $VBox/ScorePanel/ScoreP2
@onready var _p1_health: ProgressBar = $VBox/ScorePanel/P1HealthBar
@onready var _p2_health: ProgressBar = $VBox/ScorePanel/P2HealthBar

# Typing UI
@onready var _code_display: RichTextLabel = $VBox/CodeDisplayPanel/CodeDisplay
@onready var _input_field: LineEdit = $VBox/InputField

const RTDB_BASE := "https://capstone-823dc-default-rtdb.firebaseio.com"
const ROOMS_PATH := "/codebreaker_rooms"
const GAME_DURATION := 180.0  # 3 minute match (or until someone dies)

# NEW GAME MECHANICS CONSTANTS
const SCORE_CORRECT := 3           # Points for correct submission
const DAMAGE_TO_ENEMY := 2         # HP damage to opponent on correct
const SELF_DAMAGE_PENALTY := 2     # HP damage to self on wrong submission
const STARTING_HEALTH := 100       # Starting health for both players

# Game state
var _room_id: String = ""
var _is_host: bool = false
var _player_id: String = ""
var _host_username: String = "Player 1"
var _client_username: String = "Player 2"
var _game_start_time: float = 0.0
var _peer_id: int = 1

# Typing challenge - SEQUENTIAL RACE MODE
var _snippet_list: Array[String] = []  # Shuffled list of snippets
var _my_snippet_index: int = 0  # Which snippet I'm currently on (0-based)
var _opponent_snippet_index: int = 0  # Which snippet opponent is on
var _code_snippet: String = ""
var _start_time: float = 0.0

# Player stats
var player_score: int = 0:
	set(value):
		player_score = value
		_update_my_score_display()

var player_health: int = STARTING_HEALTH:
	set(value):
		player_health = clampi(value, 0, STARTING_HEALTH)
		_update_my_health_display()
		# Check for death
		if player_health <= 0:
			_on_player_died()

# Opponent tracking (received via RPC)
var _opponent_score: int = 0
var _opponent_health: int = STARTING_HEALTH
var _opponent_alive: bool = true

# Multiplayer
var _sync_timer: Timer
var _game_active: bool = false

func _ready() -> void:
	print("[CodeBreakerArena] Multiplayer Arena starting")
	
	# CRITICAL: Check if multiplayer peer is set
	if multiplayer.multiplayer_peer == null:
		push_error("[CodeBreakerArena] ERROR: No multiplayer peer set! Connection was not established in room.")
		_status_label.text = "Multiplayer connection failed!"
		if _ws_indicator:
			_ws_indicator.color = Color.RED
		await get_tree().create_timer(3.0).timeout
		_leave_arena()
		return
	
	print("[CodeBreakerArena] Multiplayer peer active. My ID: %d" % multiplayer.get_unique_id())
	print("[CodeBreakerArena] Current peers: %s" % str(multiplayer.get_peers()))
	
	# Setup multiplayer callbacks
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Load init data
	if get_tree().has_meta("code_breaker_arena_init"):
		var init = get_tree().get_meta("code_breaker_arena_init")
		_room_id = str(init.get("room_id", ""))
		_is_host = bool(init.get("is_host", false))
		_player_id = str(Auth.current_local_id if Auth else "unknown")
		_host_username = str(init.get("host_name", "Player 1"))
		
		if init.has("room_data"):
			var room_data = init.get("room_data")
			if room_data.has("host"):
				_host_username = str(room_data["host"].get("username", "Player 1"))
			if room_data.has("client"):
				_client_username = str(room_data["client"].get("username", "Player 2"))
			if room_data.has("game_start_time"):
				_game_start_time = float(room_data.get("game_start_time", 0))
		
		# Get multiplayer peer (should be set by room before scene change)
		if init.has("peer_id"):
			_peer_id = int(init.get("peer_id", 1))
		
		get_tree().set_meta("code_breaker_arena_init", null)
	
	# Update UI
	_host_name_label.text = _host_username
	_client_name_label.text = _client_username
	_status_label.text = "Waiting for opponent..." if _is_host else "Connecting to host..."
	
	# Setup display timer (100ms for countdown)
	_sync_timer = Timer.new()
	_sync_timer.wait_time = 0.1
	_sync_timer.timeout.connect(_on_display_timer_timeout)
	add_child(_sync_timer)
	_sync_timer.start()
	
	# Setup multiplayer synchronizer polling timer
	var sync_poll_timer = Timer.new()
	sync_poll_timer.wait_time = 0.05  # 50ms sync polling
	sync_poll_timer.timeout.connect(_poll_opponent_properties)
	add_child(sync_poll_timer)
	sync_poll_timer.start()
	
	# Connect input field signals ONCE in _ready()
	if _input_field:
		_input_field.text_submitted.connect(_on_input_submitted)
	
	# Initial indicator
	if _ws_indicator:
		_ws_indicator.color = Color.YELLOW
	
	# Generate snippet list (host generates, then syncs to client)
	if _is_host:
		_generate_snippet_list()
		_code_display.text = _code_snippet  # Show immediately on host
		call_deferred("_wait_for_client")
	else:
		# Client: Request snippet list from host when ready
		print("[Arena] 👋 Client ready! Requesting snippet list from host...")
		call_deferred("_request_code_from_host")

func _wait_for_client() -> void:
	"""Host waits for client to connect before starting"""
	var wait_count = 0
	var max_wait = 30  # 15 seconds max wait (0.5s * 30)
	
	while multiplayer.get_peers().size() == 0 and wait_count < max_wait:
		print("[Arena] Waiting for client to connect... (%d/30)" % wait_count)
		await get_tree().create_timer(0.5).timeout
		wait_count += 1
	
	if multiplayer.get_peers().size() == 0:
		push_error("[Arena] Client never connected after 15 seconds. Returning to room.")
		_status_label.text = "Client connection timeout!"
		if _ws_indicator:
			_ws_indicator.color = Color.RED
		await get_tree().create_timer(3.0).timeout
		_leave_arena()
	else:
		print("[Arena] ✅ Client connected! Waiting for them to request code...")
		# Client will request code via _send_code_request RPC when ready
		# Then client will notify us via _client_ready_to_start when they have it
		# At that point, game will start automatically

# =============================================================================
# MULTIPLAYER CALLBACKS
# =============================================================================

func _on_peer_connected(id: int) -> void:
	print("[Arena] Peer connected: %d" % id)
	if _ws_indicator:
		_ws_indicator.color = Color.GREEN
	_status_label.text = "Opponent connected!"
	
	# Code snippet sync happens in _wait_for_client() after connection

func _on_peer_disconnected(id: int) -> void:
	print("[Arena] Peer disconnected: %d" % id)
	if _ws_indicator:
		_ws_indicator.color = Color.RED
	_status_label.text = "Opponent disconnected!"
	
	await get_tree().create_timer(3.0).timeout
	_leave_arena()

func _on_connected_to_server() -> void:
	print("[Arena] Connected to server (host)")
	if _ws_indicator:
		_ws_indicator.color = Color.GREEN

func _on_connection_failed() -> void:
	print("[Arena] Connection to host failed!")
	_status_label.text = "Connection failed. Returning to room..."
	if _ws_indicator:
		_ws_indicator.color = Color.RED
	
	await get_tree().create_timer(3.0).timeout
	_leave_arena()

func _on_server_disconnected() -> void:
	print("[Arena] Host disconnected!")
	_status_label.text = "Host disconnected. Returning to room..."
	if _ws_indicator:
		_ws_indicator.color = Color.RED
	
	await get_tree().create_timer(3.0).timeout
	_leave_arena()

# =============================================================================
# CODE SNIPPET GENERATION
# =============================================================================

func _generate_snippet_list() -> void:
	"""Generate a SHUFFLED list of ALL security commands for sequential race"""
	# Educational security commands - learn while playing!
	var cmd_snippets = [
		# Windows CMD/PowerShell commands
		"scan /system /deep",
		"check-integrity --files",
		"firewall enable /all",
		"netstat -a -n",
		"tasklist /malware",
		"killvirus /id:0231",
		"clean temp /force",
		"quarantine threat_virus.exe",
		"update-defender /latest",
		"restore system --safe",
	]
	
	var terminal_snippets = [
		# Linux/Unix terminal commands
		"sudo chkrootkit",
		"sudo rkhunter --check",
		"sudo ufw enable",
		"sudo systemctl stop trojan.service",
		"sudo rm -rf /tmp/malware",
		"sudo apt update && sudo apt upgrade",
		"sudo find / -name \"virus*\"",
		"sudo chmod -x /usr/bin/fakephish",
		"sudo iptables -L",
		"sudo reboot --safe-mode",
	]
	
	# Combine and SHUFFLE for random order
	var all_snippets = cmd_snippets + terminal_snippets
	all_snippets.shuffle()
	
	# Convert to typed array
	_snippet_list.clear()
	for snippet in all_snippets:
		_snippet_list.append(str(snippet))
	
	_my_snippet_index = 0  # Start at first snippet
	
	# Load first snippet
	_code_snippet = _snippet_list[0]
	
	print("[Arena] 🏁 Generated sequential race with %d snippets (shuffled)" % _snippet_list.size())
	print("[Arena] 🛡️ Starting snippet #1: %s" % _code_snippet)

func _advance_to_next_snippet() -> void:
	"""Move to next snippet in the list. If at end, regenerate list (UNLIMITED!)"""
	_my_snippet_index += 1
	
	# Check if we completed the entire list
	if _my_snippet_index >= _snippet_list.size():
		print("[Arena] 🔄 Completed all %d snippets! Regenerating new list..." % _snippet_list.size())
		_generate_snippet_list()  # Regenerate for unlimited play!
		_my_snippet_index = 0
	else:
		_code_snippet = _snippet_list[_my_snippet_index]
	
	# Sync my progress to opponent
	_sync_snippet_progress.rpc(_my_snippet_index, _snippet_list.size())
	
	print("[Arena] ➡️ Advanced to snippet #%d/%d: %s" % [
		_my_snippet_index + 1,
		_snippet_list.size(),
		_code_snippet
	])

func _request_code_from_host() -> void:
	"""Client requests code snippet from host"""
	if not _is_host and multiplayer.get_peers().size() > 0:
		var host_id = 1  # Host is always ID 1
		print("[Arena] 📞 Requesting code from host (ID: %d)..." % host_id)
		_send_code_request.rpc_id(host_id)

@rpc("any_peer", "call_remote", "reliable")
func _send_code_request() -> void:
	"""Client asks host for snippet list"""
	if _is_host:
		var requester_id = multiplayer.get_remote_sender_id()
		print("[Arena] 📞 Client %d requesting snippet list. Sending..." % requester_id)
		_sync_snippet_list.rpc_id(requester_id, _snippet_list)

@rpc("any_peer", "call_remote", "reliable")
func _sync_snippet_list(snippet_list_raw: Array) -> void:
	"""Host syncs the ENTIRE snippet list to client"""
	_snippet_list.clear()
	for snippet in snippet_list_raw:
		_snippet_list.append(str(snippet))
	
	_my_snippet_index = 0
	_code_snippet = _snippet_list[0]
	
	print("[Arena] 📥 Received snippet list: %d snippets" % _snippet_list.size())
	
	if _code_display:
		_code_display.text = _code_snippet
		print("[Arena] ✅ Starting snippet #1 displayed: %s" % _code_snippet)
	
	# Client is now ready, wait a bit then notify host (ONLY IF GAME NOT STARTED YET!)
	if not _is_host and not _game_active:
		await get_tree().create_timer(0.2).timeout
		print("[Arena] ✅ Client ready to start!")
		_client_ready_to_start.rpc_id(1)  # Tell host we're ready

@rpc("any_peer", "call_remote", "unreliable")
func _sync_snippet_progress(opponent_index: int, total_snippets: int) -> void:
	"""Opponent tells us which snippet they're on"""
	_opponent_snippet_index = opponent_index
	
	# Update status to show progress race
	var my_progress = _my_snippet_index + 1
	var opp_progress = opponent_index + 1
	
	print("[Arena] 📊 Progress - You: %d/%d | Opponent: %d/%d" % [
		my_progress, _snippet_list.size(),
		opp_progress, total_snippets
	])

@rpc("any_peer", "call_remote", "reliable")
func _client_ready_to_start() -> void:
	"""Client notifies host that they received code and are ready"""
	if _is_host:
		print("[Arena] ✅ Client confirmed ready! Starting game...")
		_start_typing_game()  # Start for host
		_start_typing_game.rpc()  # Start for everyone

@rpc("any_peer", "call_remote", "reliable")
func _start_typing_game() -> void:
	"""Start the typing challenge - SUBMIT-BASED MECHANICS"""
	# Safety check: Make sure we have the code snippet
	if _code_snippet.is_empty():
		push_error("[Arena] ❌ Cannot start game - no code snippet!")
		_status_label.text = "ERROR: No code snippet received!"
		return
	
	_start_time = Time.get_unix_time_from_system()
	player_score = 0
	player_health = STARTING_HEALTH
	_game_active = true
	
	_status_label.text = "🛡️ TYPE SECURITY COMMAND & PRESS ENTER!"
	
	if _code_display:
		_code_display.text = _code_snippet
		print("[Arena] �️ Security command displayed: %s" % _code_snippet)
	
	if _input_field:
		_input_field.editable = true
		_input_field.text = ""
		_input_field.placeholder_text = "Type the security command and press ENTER..."
		call_deferred("_grab_input_focus")
	
	print("[Arena] 🛡️ SECURITY BREACH! Neutralize with command: %d chars" % _code_snippet.length())
	print("[Arena] 💪 System Health: %d | Defense Score: %d" % [player_health, player_score])

func _grab_input_focus() -> void:
	"""Deferred focus grab to ensure UI is ready"""
	if _input_field:
		_input_field.grab_focus()
		print("[Arena] ⌨️ Input field focused and ready")

# =============================================================================
# TYPING MECHANICS - SUBMIT-BASED COMBAT SYSTEM
# =============================================================================
# NEW RULES (v3.0):
# ✅ Type code in input field, press ENTER to submit
# ✅ Correct submission: +3 score, -2 enemy HP
# ❌ Wrong submission: -2 self HP (penalty)
# 💀 First to 0 HP = LOSE
# 🎯 Case-sensitive, exact match required

func _on_input_submitted(submitted_text: String) -> void:
	"""Called when player presses ENTER - CHECK SUBMISSION"""
	if not _game_active:
		return
	
	print("[Arena] 📝 Checking submission: '%s'" % submitted_text.substr(0, 50))
	
	# EXACT MATCH REQUIRED (case-sensitive)
	if submitted_text == _code_snippet:
		# ✅ CORRECT SUBMISSION!
		print("[Arena] ✅ VIRUS NEUTRALIZED! +3 defense score, attacking opponent system")
		player_score += SCORE_CORRECT
		
		# Update MY score display immediately
		_update_my_score_display()
		_update_my_health_display()
		
		# Deal damage to opponent
		_deal_damage_to_opponent.rpc(DAMAGE_TO_ENEMY, "")
		
		# Visual feedback
		_flash_success()
		var progress_text = "✅ CORRECT! (%d/%d) | +3 Score | Enemy -2 HP" % [
			_my_snippet_index + 1,
			_snippet_list.size()
		]
		_status_label.text = progress_text
		
		# ADVANCE to next snippet in sequential list
		_advance_to_next_snippet()
		if _code_display:
			_code_display.text = _code_snippet
		
		# Clear input for next round
		_input_field.text = ""
	else:
		# ❌ WRONG SUBMISSION!
		print("[Arena] ❌ INCORRECT COMMAND! System compromised, taking damage")
		player_health -= SELF_DAMAGE_PENALTY
		
		# Update MY health display immediately
		_update_my_health_display()
		_update_my_score_display()
		
		# Check if I died
		if player_health <= 0:
			_on_player_died()
			return
		
		# Visual feedback
		_flash_error()
		var progress_text = "❌ WRONG! (%d/%d) | -2 HP Penalty" % [
			_my_snippet_index + 1,
			_snippet_list.size()
		]
		_status_label.text = progress_text
		
		# ADVANCE to next snippet anyway (both correct & wrong advance!)
		_advance_to_next_snippet()
		if _code_display:
			_code_display.text = _code_snippet
		
		# Clear input to try again
		_input_field.text = ""

func _on_typing_finished() -> void:
	"""Player could finish typing (not used in submit-based mode)"""
	# In submit-based mode, game ends when someone reaches 0 HP
	pass

func _on_player_died() -> void:
	"""NEW: Player health reached 0 - GAME OVER"""
	_game_active = false
	
	if _input_field:
		_input_field.editable = false
	
	_status_label.text = "💀 YOU DIED! Health: 0"
	
	# Notify opponent
	_on_opponent_died.rpc()
	
	print("[Arena] 💀 Player died! Health: 0")
	
	# Wait then show defeat screen
	await get_tree().create_timer(3.0).timeout
	_end_game_defeat()

func _show_error_message(msg: String) -> void:
	"""Display error message temporarily"""
	_status_label.text = msg
	await get_tree().create_timer(1.0).timeout
	if _game_active:
		_status_label.text = "⚔️ CODE BREAKER DUEL - TYPE TO ATTACK!"

func _flash_error() -> void:
	"""Flash red indicator when player makes mistake"""
	if _status_label:
		var original_color = _status_label.modulate
		_status_label.modulate = Color.RED
		await get_tree().create_timer(0.15).timeout
		_status_label.modulate = original_color

func _flash_success() -> void:
	"""Flash green indicator when player hits correct key"""
	if _status_label:
		var original_color = _status_label.modulate
		_status_label.modulate = Color.GREEN
		await get_tree().create_timer(0.05).timeout
		_status_label.modulate = original_color

# =============================================================================
# RPC CALLS (Multiplayer Combat System)
# =============================================================================

@rpc("any_peer", "call_remote", "reliable")
func _deal_damage_to_opponent(damage: int, _character: String) -> void:
	"""NEW: Receive damage from opponent's correct keystroke"""
	player_health -= damage
	print("[Arena] 💥 Took %d damage! Health: %d" % [damage, player_health])
	
	# Update MY health display immediately
	_update_my_health_display()
	_update_my_score_display()
	
	# Check if I died from this damage
	if player_health <= 0:
		_on_player_died()
		return
	
	# Flash damage indicator
	if _ws_indicator:
		var original_color = _ws_indicator.color
		_ws_indicator.color = Color.RED
		await get_tree().create_timer(0.2).timeout
		_ws_indicator.color = original_color

@rpc("any_peer", "call_remote", "unreliable")
func _on_line_restarted() -> void:
	"""Opponent restarted their current line due to error"""
	print("[Arena] 😏 Opponent made an error and restarted their line!")

@rpc("any_peer", "call_remote", "reliable")
func _on_opponent_died() -> void:
	"""Opponent's health reached 0"""
	_opponent_alive = false
	_status_label.text = "💀 OPPONENT DIED! YOU WIN!"
	print("[Arena] 🎉 Opponent died! Victory!")
	
	# End game with victory
	await get_tree().create_timer(3.0).timeout
	_end_game_victory()

@rpc("any_peer", "call_remote", "reliable")
func _on_player_finished(time: float, wpm: int, _accuracy: float) -> void:
	"""Opponent finished typing the entire snippet"""
	print("[Arena] ⚠️ Opponent completed code! Time: %.2f s | WPM: %d" % [time, wpm])
	_status_label.text = "Opponent finished! Time: %.2f s" % time
	
	# If we're still alive but they finished, they might win
	await get_tree().create_timer(2.0).timeout
	if _game_active:
		_end_game_defeat()

# =============================================================================
# PROPERTY SYNCHRONIZATION (RPC-based since MultiplayerSynchronizer needs peer authority)
# =============================================================================

func _poll_opponent_properties() -> void:
	"""Poll opponent's synced properties via RPC"""
	# Request opponent's current stats
	if multiplayer.get_peers().size() > 0:
		_request_opponent_stats.rpc()

@rpc("any_peer", "call_remote", "unreliable")
func _request_opponent_stats() -> void:
	"""Opponent requests our current stats"""
	var sender_id = multiplayer.get_remote_sender_id()
	_send_my_stats.rpc_id(sender_id, player_score, player_health)

@rpc("any_peer", "call_remote", "unreliable")
func _send_my_stats(score: int, health: int) -> void:
	"""Receive opponent's stats and update display"""
	# Store opponent's stats
	_opponent_score = score
	_opponent_health = health
	
	if _is_host:
		# Host displays opponent (client) on right side
		_p2_score.text = "P2: %d" % score
		if _p2_health:
			_p2_health.value = health
	else:
		# Client displays opponent (host) on left side
		_p1_score.text = "P1: %d" % score
		if _p1_health:
			_p1_health.value = health

# =============================================================================
# UI UPDATES (My own stats)
# =============================================================================

func _update_my_score_display() -> void:
	if _is_host:
		_p1_score.text = "P1: %d" % player_score
	else:
		_p2_score.text = "P2: %d" % player_score

func _update_my_health_display() -> void:
	if _is_host:
		if _p1_health:
			_p1_health.value = player_health
	else:
		if _p2_health:
			_p2_health.value = player_health

func _on_display_timer_timeout() -> void:
	"""Update countdown timer display every 100ms"""
	var elapsed = Time.get_unix_time_from_system() - _game_start_time
	var remaining = max(0.0, GAME_DURATION - elapsed)
	
	var total_secs = int(remaining)
	var mins: int = floori(total_secs / 60.0)
	var secs: int = total_secs % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]
	
	# Check if time's up (timeout = highest score wins)
	if remaining <= 0.0:
		_end_game_timeout()

# =============================================================================
# GAME END - NEW HEALTH-BASED SYSTEM
# =============================================================================

func _end_game_victory() -> void:
	"""NEW: Victory - Either opponent died or you finished first"""
	_game_active = false
	_sync_timer.stop()
	
	if _input_field:
		_input_field.editable = false
	
	_status_label.text = "🎉 VICTORY! Score: %d | Opponent Health: %d" % [player_score, _opponent_health]
	_timer_label.text = "YOU WIN!"
	
	print("[Arena] 🏆 VICTORY! Final Score: %d" % player_score)
	
	# Return to room after delay
	await get_tree().create_timer(5.0).timeout
	_leave_arena()

func _end_game_defeat() -> void:
	"""NEW: Defeat - Either you died or opponent finished first"""
	_game_active = false
	_sync_timer.stop()
	
	if _input_field:
		_input_field.editable = false
	
	_status_label.text = "💀 DEFEAT! Score: %d | Your Health: %d" % [player_score, player_health]
	_timer_label.text = "YOU LOSE!"
	
	print("[Arena] 💀 DEFEAT! Final Score: %d" % player_score)
	
	# Return to room after delay
	await get_tree().create_timer(5.0).timeout
	_leave_arena()

func _end_game_timeout() -> void:
	"""NEW: Time ran out - Highest score wins"""
	_game_active = false
	_sync_timer.stop()
	
	if _input_field:
		_input_field.editable = false
	
	# Determine winner by score AND health
	var we_won = false
	var is_draw = false
	
	if player_health > _opponent_health:
		we_won = true
	elif player_health == _opponent_health:
		# Same health, check score
		if player_score > _opponent_score:
			we_won = true
		elif player_score == _opponent_score:
			is_draw = true
	
	if is_draw:
		_status_label.text = "⚔️ DRAW! Score: %d | Health: %d" % [player_score, player_health]
		_timer_label.text = "DRAW!"
	elif we_won:
		_status_label.text = "🎉 VICTORY! Score: %d | Health: %d" % [player_score, player_health]
		_timer_label.text = "YOU WIN!"
	else:
		_status_label.text = "💀 DEFEAT! Score: %d | Health: %d" % [player_score, player_health]
		_timer_label.text = "YOU LOSE!"
	
	print("[Arena] ⏰ TIMEOUT! Winner: %s | Score: %d vs %d | Health: %d vs %d" % [
		"YOU" if we_won else "OPPONENT" if not is_draw else "DRAW",
		player_score, _opponent_score,
		player_health, _opponent_health
	])
	
	# Return to room after delay
	await get_tree().create_timer(5.0).timeout
	_leave_arena()

func _leave_arena() -> void:
	"""Clean up and return to room"""
	# Disconnect multiplayer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Return to room scene
	var room_scene := load("res://scene/code_breaker_room.tscn")
	if room_scene:
		get_tree().change_scene_to_packed(room_scene)
