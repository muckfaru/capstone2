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

### Lobby → Room → Loading → Arena (Complete Flow)

1. **Lobby Scene** (`code_breaker_lobby.gd`)
   - Polls `GET /api/rooms/list` every 5s
   - Host: `POST /api/rooms/create` → receives `room_id`
   - Client: Sees room in list → `POST /api/rooms/:id/join`
   - Both transition to room scene with `room_id`
   - **NO IP/PORT needed** - all REST operations

2. **Room Scene** (`code_breaker_room.gd`)
   - Polls `GET /api/rooms/:id` every 2s for room state
   - **Both connect to** `WS /ws/relay/:room_id` via `WebSocketRelayClient`
   - Displays player cards (host left, client right)
   - Client toggles READY → updates server + sends relay message
   - Host sees ready → clicks START MATCH
   - Host sends `game_start` relay message with `game_start_time`
   - **Relay client reparented to root** before scene change
   - Both transition to **loading screen**

3. **Loading Screen** (`code_breaker_loading.gd`) **[NEW!]**
   - Receives `relay_client` from room (adopts from root)
   - Shows two player cards with progress bars
   - **Left card = YOU, Right card = OPPONENT** (perspective-based)
   - Simulates loading: 30% → 60% → 100% (1.5s total)
   - Sends `loading_status: "ready"` via relay when complete
   - Waits for opponent's ready message
   - When both ready: 2s countdown → Arena
   - **Timeout:** 30s max, returns to room if sync fails
   - **Relay client reparented to root** before arena transition

4. **Arena Scene** (`code_breaker_arena.gd`)
   - Receives `relay_client` from loading (adopts from root)
   - Host generates snippet list → sends via relay
   - Client receives snippets → sends `client_ready`
   - Host receives ready → starts game for both
   - **Gameplay via relay messages:**
     - Type correct → `damage` message to opponent
     - Stats sync: `stats_update` (score, health) every 0.5s
     - Game end: `player_died` or `player_finished`
   - Game ends → **returns to room** (NOT landing)
   - Relay connection preserved throughout

### Relay Client Lifecycle (Node Preservation)
```
Room creates relay_client
  ↓
Room → Loading: Reparent to root
  ↓
Loading adopts from root
  ↓
Loading → Arena: Reparent to root
  ↓
Arena adopts from root
  ↓
Arena → Room: (if rematch) Reparent to root
```

**Why reparenting?** When `change_scene_to_packed()` is called, the current scene and all its children are freed. By moving `relay_client` to the scene root before transition, it survives the scene change and can be adopted by the next scene.

### Relay Message Types

**Connection Messages:**
```json
{"type": "player_connected", "player_id": "...", "username": "..."}
{"type": "player_disconnected", "player_id": "..."}
```

**Room Messages:**
```json
{"type": "player_status", "action": "ready", "player_id": "..."}
{"type": "game_start", "game_start_time": 1234567890}
```

**Loading Screen Messages:**
```json
{"type": "loading_status", "status": "loading|ready", "player_id": "..."}
```

**Arena Messages:**
```json
{"type": "snippet_list", "snippets": [...]}
{"type": "client_ready", "player_id": "..."}
{"type": "game_start", "player_id": "..."}
{"type": "damage", "damage": 2, "player_id": "..."}
{"type": "stats_update", "score": 15, "health": 94, "player_id": "..."}
{"type": "player_died", "player_id": "..."}
{"type": "player_finished", "time": 45.2, "wpm": 68}
```

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

| Purpose | File | Key Features |
|---------|------|--------------|
| **Auth & Presence** | `script/auth.gd` | Firebase auth, JWT tokens, online presence |
| **Chat System** | `script/ChatManager.gd` | RTDB polling, message sync, unread counts |
| **Server Config** | `script/MultiplayerConfig.gd` | PRODUCTION/LOCALHOST mode toggle |
| **Relay Client** | `script/WebSocketRelayClient.gd` | WebSocket wrapper, message send/receive, 150 lines |
| **Lobby** | `script/code_breaker_lobby.gd` | Room list polling (5s), create/join rooms |
| **Room** | `script/code_breaker_room.gd` | Room state polling (2s), relay setup, ready system, heartbeat |
| **Loading** | `script/code_breaker_loading.gd` | Player sync screen, progress bars, 30s timeout, relay preservation |
| **Arena** | `script/code_breaker_arena.gd` | 1v1 typing battle, damage system, stats sync (0.5s), relay messages |
| **Lobby Server** | `server/server.js` | Express + express-ws, REST API + WebSocket relay, in-memory rooms |

### Scene Hierarchy
```
scene/
├─ auth.tscn (autoload singleton)
├─ landing.tscn (hub with visibility toggles)
├─ code_breaker_lobby.tscn
├─ code_breaker_room.tscn
├─ code_breaker_loading.tscn ← NEW!
└─ code_breaker_arena.tscn
```

### Server Endpoints (server.js)
```javascript
// REST API
POST   /api/rooms/create      → Create room (returns room_id)
GET    /api/rooms/list        → List all active rooms
GET    /api/rooms/:id         → Get room details
POST   /api/rooms/:id/join    → Join as client
POST   /api/rooms/:id/leave   → Leave (with host promotion logic)
POST   /api/rooms/:id/heartbeat → Keep-alive (host only, 30s)
DELETE /api/rooms/:id         → Delete room

// WebSocket Relay
WS     /ws/relay/:room_id?player_id=X&username=Y
       → Real-time gameplay message relay
       → Max 2 players per room
       → Auto-cleanup on disconnect
```

## 🚀 Quick Checklist
- [x] HTTPRequest: create fresh + `queue_free()` after use
- [x] Chat paths: sort UIDs lexicographically always
- [x] Timers: add to scene tree for auto-cleanup
- [x] Meta: clear with `set_meta("key", null)` after reading
- [x] Token: check `Auth.current_id_token` before RTDB calls
- [x] Relay: Both players connect to same `/ws/relay/:room_id`
- [x] Leave: Handle 3 scenarios (client leaves, host leaves, host alone)
- [x] Heartbeat: Host only, 30s interval, stops on scene unload
- [x] Reparenting: Move relay_client to root before `change_scene_to_packed()`
- [x] Loading: 30s timeout, returns to room on failure
- [x] Stats Sync: Send on BOTH correct (damage) and wrong (self-damage)
- [x] Periodic Sync: Timer sends stats every 0.5s during gameplay

## 🌍 Cross-Network Multiplayer

**NO PORT FORWARDING REQUIRED!** Both players connect TO the relay server, which forwards messages:

```
PC (Home WiFi) ────────┐
                        ├──→ Render.com Relay Server ←──┐
Laptop (Starbucks) ────┘                                 │
                                                          │
Phone (Mobile Data) ──────────────────────────────────────┘
```

**Works on:**
- ✅ Different WiFi networks
- ✅ Mobile data vs home WiFi
- ✅ School/work networks (firewall-friendly)
- ✅ Any internet connection (outgoing only)

**Test Setup:**
1. PC (home): Create room, wait
2. Laptop (different location): Join room
3. Console logs show `[Room] ✅ Relay connected!`
4. Play across networks!

---

Last updated: Nov 2025 (Added Loading Screen + Arena Relay Integration)
See `RELAY_ARCHITECTURE.md` for architecture details.
