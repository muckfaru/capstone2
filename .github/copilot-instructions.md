# Copilot Instructions for capstone2

## 🎮 Big Picture
**Godot 4.4 multi-game social platform** combining Firebase authentication, real-time RTDB, WebSocket P2P networking, and turn-based gameplay. Architecture: Auth → Landing (hub) → Game Lobbies → Rooms (ready state) → Arenas (1v1 multiplayer). Two games: **Code Breaker** (typing race with P2P sync) and **Akashic TCG** (turn-based card game). Scene navigation uses visibility toggles, not tree swaps. REST via transient `HTTPRequest` nodes; P2P via Node.js WebSocket signaling server.

```
Firebase Auth ──→ Landing (profile/chat) ──→ Game Lobbies ──→ Rooms ──→ Arenas
                                                  │
                    Auth.gd (autoload: token, presence)
                    ChatManager.gd (autoload: polling)
```

## ��️ Core Singletons (Autoloads in project.godot)

| Singleton | File | Responsibility |
|-----------|------|-----------------|
| **Auth** | `scene/auth.tscn` + `script/auth.gd` | Firebase Auth: `current_id_token` (JWT), `current_local_id` (UID), `current_username`, `current_avatar`, `current_level`. Methods: `login()`, `sign_up()`, `login_with_google()`, `set_user_online()`, `set_user_offline()`. Emits `auth_response(code, response)`. Writes presence to RTDB. **Hard-coded credentials in lines 6–8.** |
| **ChatManager** | `script/ChatManager.gd` | RTDB polling for real-time chat. Two timers: 2s (current chat) + 5s (all unread counts). Methods: `set_current_user()`, `load_chat_history()`, `send_message()`, `get_unread_count()`. Signals: `message_received`, `chat_loaded`, `unread_count_changed`. |

## 📊 Data Schema

### RTDB (https://capstone-823dc-default-rtdb.firebaseio.com)
```
presence/<uid>
  └─ state: "online" | "offline"
     last_seen: unix_timestamp

chats/<user_a_user_b>/messages/<pushKey>
  └─ sender, text, timestamp, seen (IDs sorted lexicographically)

codebreaker_rooms/<roomId>
  ├─ host: {uid, username, level, status}
  ├─ client: {uid, username, level, status} | null
  ├─ room_name, state, game_state, game_start_time
```

### Firestore (capstone-823dc)
```
users/<uid> = {username, avatar, level, wins, losses, xp}
```

## ⚡ Critical Patterns

### 1. Transient HTTPRequest (HTTP REST)
Every REST call creates a new node and cleans up immediately:
```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request_completed.connect(func(_r, code, _h, body):
    http.queue_free()
    if code == 200:
        var data = JSON.parse_string(body.get_string_from_utf8())
)
http.request("GET", url)
```

### 2. Polling Timers (Scene-Local)
Create timers in `_ready()`, add to scene tree for auto-cleanup:
```gdscript
var _poll_timer = Timer.new()
_poll_timer.wait_time = 2.0
_poll_timer.autostart = true
_poll_timer.timeout.connect(_on_timeout)
add_child(_poll_timer)
```

**Intervals:** Lobby 5s, Room 2s, Chat 2s current / 5s unreads, Arena 100ms.

### 3. Chat Path Sorting (RTDB Keys)
Always sort UIDs lexicographically: `_get_chat_path(user1, user2)` → `"chats/" + sorted_users + "/messages"`.

### 4. Scene Navigation (Visibility Toggles)
Landing uses `visible = true/false` (not scene swaps). Pass data via `get_tree().set_meta()`.

### 5. Arena Transition Guard
Use `_transitioning_to_arena` flag to prevent double entries.

## 🌐 Code Breaker P2P Multiplayer

### WebSocket Signaling Server
**Location:** `server/server.js` (Express + express-ws). Render.com deployed.
- **Dev:** `ws://localhost:8080/ws/game`
- **Prod:** `wss://code-breaker-p2p-signaling.onrender.com/ws/game`

**Message Types:** register, player_joined, game_action, game_end.

### Arena Mechanics
- **SCORE_CORRECT = 3** pts, **DAMAGE_TO_ENEMY = 2** HP
- **SELF_DAMAGE_PENALTY = 2** HP
- **STARTING_HEALTH = 100**
- **Duration:** 180s (3 min)

### Game Flow
1. Lobby: Host creates, client joins, both READY
2. Room: Host polls 2s, clicks START
3. Arena: 100ms display timer, WebSocket P2P sync, opponent action signals
4. End: Health ≤ 0 → 3s wait → return to room

## 🛠️ Developer Workflows

### Local Multiplayer Testing
```bash
cd server && npm install && npm start  # Terminal 1
godot project.godot  # Terminal 2 (Editor + exported .exe)
```

### Debugging
- Auth: Check `Auth.current_id_token` not empty
- Chat: Use `ChatManager._get_chat_path()` helper
- WebSocket: Check `P2PWebSocketClient._connection_state`
- Arena: Look at `code_breaker_room.gd::_apply_room_snapshot()`

## 📚 Key Files

| Purpose | File |
|---------|------|
| Auth & Presence | `script/auth.gd`, `scene/auth.tscn` |
| Chat | `script/ChatManager.gd` |
| Lobby | `script/code_breaker_lobby.gd` (5s poll) |
| Room | `script/code_breaker_room.gd` (2s poll, transition) |
| Arena | `script/code_breaker_arena.gd` (100ms timer) |
| P2P | `script/P2PWebSocketClient.gd` |
| Server | `server/server.js` |

## 🚀 Quick Checklist
- [ ] HTTPRequest: create fresh + `queue_free()`
- [ ] Chat paths: sort UIDs always
- [ ] Timers: add to tree for auto-cleanup
- [ ] Arena: set `_transitioning_to_arena = true`
- [ ] Meta: clear with `set_meta("key", null)`
- [ ] Token: check before RTDB calls
- [ ] WebSocket: use dev for local, prod for builds

---

Last updated: Nov 2025. See `WEBSOCKET_P2P_GUIDE.md` and `QUICKSTART_MULTIPLAYER.md` for details.
