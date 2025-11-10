# Copilot Instructions for capstone2

## 🎮 Big Picture
**Godot 4.4 multi-game social platform** with Firebase authentication and **WebSocket Relay multiplayer** (no port forwarding required). Architecture: Auth → Landing (hub) → Game Lobbies → Rooms → Arenas (1v1 gameplay). Two games: **Code Breaker** (typing race) and **Akashic TCG** (turn-based card game). Scene navigation uses visibility toggles for Landing, `change_scene_to_packed()` for game flows. REST via transient `HTTPRequest` nodes; Multiplayer via **Node.js relay server** on Render.com.

```
Firebase Auth ──→ Landing (profile/chat) ──→ Game Lobbies ──→ Rooms ──→ Arenas
                           │                        │               │
                    Auth.gd (autoload)      Relay Connection   WebSocket Relay
                    ChatManager.gd          (no port fwd!)     (gameplay sync)
```

## 🏗️ Architecture: WebSocket Relay (Option B)

**NO PORT FORWARDING NEEDED** - Both players connect TO server, server relays messages.

### Server Infrastructure
- **Production:** `https://codebreaker-lobby.onrender.com` (Render.com free tier)
- **Local Dev:** `http://localhost:8080` (for testing)
- **Tech Stack:** Express.js + express-ws + in-memory room storage
- **Endpoints:**
  - `POST /api/rooms/create` - Register room (no IP/port needed)
  - `GET /api/rooms/list` - List active rooms
  - `POST /api/rooms/:id/join` - Join as client
  - `POST /api/rooms/:id/leave` - Leave room (with host promotion)
  - `POST /api/rooms/:id/heartbeat` - Keep room alive (30s interval)
  - `WS /ws/relay/:room_id` - WebSocket relay for gameplay

### Room Lifecycle
```
1. Host: POST /create → room_id
2. Client: GET /list → sees room → POST /join
3. Both: WS /ws/relay/:room_id → connected
4. Host: Clicks START → both transition to arena
5. Arena: WebSocket relays game actions (typing, damage, etc.)
6. Game ends → both return to room (with relay preserved)
7. Either: POST /leave → room deleted OR host promoted
```

### Relay Message Protocol
```json
{
  "type": "player_status",
  "action": "ready",
  "player_id": "uid123"
}

{
  "type": "game_start",
  "game_start_time": 1234567890
}

{
  "type": "game_action",
  "action": "word_typed",
  "score": 15,
  "health": 94
}
```
```


## 🔧 Core Singletons (Autoloads in project.godot)

| Singleton | File | Responsibility |
|-----------|------|-----------------|
| **Auth** | `scene/auth.tscn` + `script/auth.gd` | Firebase Auth: `current_id_token` (JWT), `current_local_id` (UID), `current_username`, `current_avatar`, `current_level`. Methods: `login()`, `sign_up()`, `login_with_google()`, `set_user_online()`, `set_user_offline()`. Emits `auth_response(code, response)`. Writes presence to RTDB. **Hard-coded credentials in lines 6–8.** |
| **ChatManager** | `script/ChatManager.gd` | RTDB polling for real-time chat. Two timers: 2s (current chat) + 5s (all unread counts). Methods: `set_current_user()`, `load_chat_history()`, `send_message()`, `get_unread_count()`. Signals: `message_received`, `chat_loaded`, `unread_count_changed`. |
| **MultiplayerConfig** | `script/MultiplayerConfig.gd` | Server URL configuration. `current_mode` = `Mode.PRODUCTION` or `Mode.LOCALHOST`. Returns lobby server URL for room operations and relay connections. Used by lobby and room scenes. |

## 📊 Data Schema

### Lobby Server (In-Memory Map)
```javascript
rooms.set(room_id, {
  room_id: "room_abc123",
  room_name: "Player's Room",
  game_type: "code_breaker",
  host: {
    player_id: "uid123",
    username: "Player1",
    avatar: "avatar1.png",
    level: 5,
    ready: true
  },
  client: {
    player_id: "uid456",
    username: "Player2",
    avatar: "avatar2.png",
    level: 3,
    ready: false
  } | null,
  status: "waiting" | "in_game" | "finished",
  current_players: 1,
  max_players: 2,
  created_at: timestamp,
  last_heartbeat: timestamp
})
```

### RTDB (Legacy - Chat Only)
```
presence/<uid>
  └─ state: "online" | "offline"
     last_seen: unix_timestamp

chats/<user_a_user_b>/messages/<pushKey>
  └─ sender, text, timestamp, seen (IDs sorted lexicographically)
```

### Firestore (capstone-823dc)
```
users/<uid> = {username, avatar, level, wins, losses, xp}
```


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

**Intervals:** Lobby 5s, Room 2s (lobby server polling), Chat 2s current / 5s unreads.

### 3. Chat Path Sorting (RTDB Keys)
Always sort UIDs lexicographically: `_get_chat_path(user1, user2)` → `"chats/" + sorted_users + "/messages"`.

### 4. Scene Navigation (Visibility Toggles)
Landing uses `visible = true/false` (not scene swaps). Pass data via `get_tree().set_meta()`.

### 5. WebSocket Relay Connection
Both host and client connect to same relay endpoint:
```gdscript
var _relay_client := WebSocketRelayClient.new()
add_child(_relay_client)
_relay_client.connect_to_relay(relay_url, room_id, player_id, username)
_relay_client.message_received.connect(_on_relay_message)
```

## 🌐 Code Breaker Multiplayer Flow

### Lobby → Room → Arena
1. **Lobby Scene** (`code_breaker_lobby.gd`)
   - Polls `GET /api/rooms/list` every 5s
   - Host: `POST /api/rooms/create` (no IP/port needed!)
   - Client: `POST /api/rooms/:id/join`
   - Both transition to room scene

2. **Room Scene** (`code_breaker_room.gd`)
   - Polls `GET /api/rooms/:id` every 2s
   - Both connect to `WS /ws/relay/:room_id`
   - Client clicks READY → sends relay message
   - Host sees ready → clicks START MATCH
   - Host sends `game_start` relay message
   - Both transition to arena

3. **Arena Scene** (`code_breaker_arena.gd`)
   - Receives relay_client from room (preserved!)
   - WebSocket relays gameplay actions
   - Type code → damage opponent
   - Game ends → returns to room (NOT landing)

### Leave/Delete Logic (3 Scenarios)
```
1. Host + Client in room → Client leaves:
   - DELETE client from room
   - Broadcast "player_left" via relay
   - Keep room alive

2. Host + Client in room → Host leaves:
   - PROMOTE client to host
   - Broadcast "host_promotion" via relay
   - Keep room alive

3. Host alone → Host leaves:
   - DELETE entire room
   - Close relay connections
```

### Heartbeat System
- **Host only** sends `POST /api/rooms/:id/heartbeat` every 30s
- Server deletes rooms with no heartbeat > 90s
- Heartbeat stops when room scene unloads


## 🛠️ Developer Workflows

### Local Multiplayer Testing
```bash
cd server && npm install && npm start  # Terminal 1 (http://localhost:8080)
godot project.godot  # Terminal 2 (Test with Editor + exported .exe)
```

### Switching Server Modes
```gdscript
# script/MultiplayerConfig.gd
var current_mode: Mode = Mode.PRODUCTION  # Render.com
# var current_mode: Mode = Mode.LOCALHOST  # Local testing
```

### Debugging
- Auth: Check `Auth.current_id_token` not empty
- Chat: Use `ChatManager._get_chat_path()` helper
- WebSocket: Check `_relay_client.is_relay_connected()`
- Room: Look at `code_breaker_room.gd::_apply_lobby_room_snapshot()`
- Relay: Server logs show connections/disconnections in real-time

## 📚 Key Files

| Purpose | File |
|---------|------|
| Auth & Presence | `script/auth.gd`, `scene/auth.tscn` |
| Chat | `script/ChatManager.gd` |
| Lobby | `script/code_breaker_lobby.gd` (5s poll) |
| Room | `script/code_breaker_room.gd` (2s poll, relay connection) |
| Arena | `script/code_breaker_arena.gd` (gameplay sync via relay) |
| Relay Client | `script/WebSocketRelayClient.gd` |
| Lobby Server | `server/server.js` (Express + express-ws) |
| Config | `script/MultiplayerConfig.gd` |

## 🚀 Quick Checklist
- [ ] HTTPRequest: create fresh + `queue_free()`
- [ ] Chat paths: sort UIDs always
- [ ] Timers: add to tree for auto-cleanup
- [ ] Meta: clear with `set_meta("key", null)`
- [ ] Token: check before RTDB calls
- [ ] Relay: Both players connect to same `/ws/relay/:room_id`
- [ ] Leave: Handle 3 scenarios (client leaves, host leaves, host alone)
- [ ] Heartbeat: Host only, 30s interval

---

Last updated: Nov 2025. See `RELAY_ARCHITECTURE.md` and `WEBSOCKET_P2P_GUIDE.md` for details.
