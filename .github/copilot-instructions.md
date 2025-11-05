# Copilot Instructions for capstone2

## Big Picture
**Multi-game social platform** (Godot 4.4, Forward+ renderer). Authentication via Firebase → Landing hub with profile, friends, chat, game lobbies (Code Breaker + Akashic TCG). Game flow: lobby → room (ready state) → arena (1v1 P2P multiplayer or turn-based). Data: RTDB for real-time presence/chat/rooms, Firestore for user profiles. Scene navigation via visibility toggles (not tree swaps). REST calls via transient `HTTPRequest` nodes; P2P gaming via WebSocket signaling server.

## Architecture Overview
```
Auth (Firebase) → Landing (hub) → Game Lobbies → Rooms (waiting) → Arenas (gameplay)
├─ Auth.gd (autoload): token + presence management
├─ ChatManager.gd (autoload): 2s polling (current chat) + 5s polling (all unread)
├─ RTDB: presence, chats, room state, game state
├─ Firestore: user profiles (username, avatar, level, stats)
└─ WebSocket server: P2P signaling for Code Breaker arena
```

## Singletons & Core Services
| Autoload | File | Role |
|----------|------|------|
| `Auth` | `scene/auth.tscn` + `script/auth.gd` | Auth state: `current_id_token` (JWT), `current_local_id` (Firebase UID), `current_username`, `current_avatar`, `current_level`. Methods: `login(email, pwd)`, `sign_up(email, pwd)`, `login_with_google()`, `exchange_google_code()`, `set_user_online()`, `set_user_offline()`. Emits `auth_response(code, response)`. Hard-coded credentials in lines 6-8. |
| `ChatManager` | `script/ChatManager.gd` | Real-time chat via RTDB polling. Emits: `message_received(msg_dict)`, `chat_loaded(messages_array)`, `unread_count_changed(user_id, count)`. Methods: `set_current_user(user_id)`, `load_chat_history(other_id)`, `send_message(text)`, `mark_chat_as_read(other_id)`, `get_unread_count(user_id)`. Dual timers: 2s for current chat, 5s for all chats' unreads. |

## Data Model
**RTDB** (`https://capstone-823dc-default-rtdb.firebaseio.com`):
- `presence/<localId> = {state: "online"|"offline", last_seen: unix_timestamp}`
- `chats/<sorted_user_ids>/messages/<pushKey> = {sender, text, timestamp, seen}` (user IDs sorted lexicographically, joined with `_`)
- `codebreaker_rooms/<roomId> = {host, client, room_name, state, max_players, visibility, game_start_time, game_state: {scores, health}}`
- `akashic_tcg_rooms/<roomId> = {...}` (similar structure)

**Firestore** (`capstone-823dc`):
- `users/<uid> = {username, avatar, level, wins, losses, xp}`

## Key Patterns & Conventions

### 1. HTTP Request Pattern (Transient)
Every REST call creates a **new** `HTTPRequest` node, connects once, then `queue_free()`s:
```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request_completed.connect(func(_result, code, _headers, body):
    http.queue_free()
    if code == 200:
        var data = JSON.parse_string(body.get_string_from_utf8())
        # process data
)
http.request("GET", url)
```
# Copilot Instructions for capstone2

## Big Picture
Multi-game social platform (Godot 4.4, Forward+ renderer). Authentication via Firebase → Landing hub with profile, friends, chat, game lobbies (Code Breaker + Akashic TCG). Game flow: lobby → room (ready state) → arena (1v1 P2P multiplayer or turn-based). Data: RTDB for real-time presence/chat/rooms, Firestore for user profiles. Scene navigation via visibility toggles (not tree swaps). REST calls via transient HTTPRequest nodes; P2P gaming via WebSocket signaling server.

## Architecture Overview
```
Auth (Firebase) → Landing (hub) → Game Lobbies → Rooms (waiting) → Arenas (gameplay)
├─ Auth.gd (autoload): token + presence management
├─ ChatManager.gd (autoload): 2s polling (current chat) + 5s polling (all unread)
├─ RTDB: presence, chats, room state, game state
├─ Firestore: user profiles (username, avatar, level, stats)
└─ WebSocket server: P2P signaling for Code Breaker arena
```

## Singletons & Core Services
| Autoload | File | Role |
|----------|------|------|
| Auth | scene/auth.tscn + script/auth.gd | Auth state: current_id_token (JWT), current_local_id (Firebase UID), current_username, current_avatar, current_level. Methods: login(email, pwd), sign_up(email, pwd), login_with_google(), exchange_google_code(), set_user_online(), set_user_offline(). Emits auth_response(code, response). Hard-coded credentials in lines 6-8. |
| ChatManager | script/ChatManager.gd | Real-time chat via RTDB polling. Emits: message_received(msg_dict), chat_loaded(messages_array), unread_count_changed(user_id, count). Methods: set_current_user(user_id), load_chat_history(other_id), send_message(text), mark_chat_as_read(other_id), get_unread_count(user_id). Dual timers: 2s for current chat, 5s for all chats' unreads. |

## Data Model
RTDB (https://capstone-823dc-default-rtdb.firebaseio.com):
- presence/<localId> = {state: "online"|"offline", last_seen: unix_timestamp}
- chats/<sorted_user_ids>/messages/<pushKey> = {sender, text, timestamp, seen} (user IDs sorted lexicographically, joined with _)
- codebreaker_rooms/<roomId> = {host, client, room_name, state, max_players, visibility, game_start_time, game_state: {scores, health}}
- akashic_tcg_rooms/<roomId> = {...} (similar structure)

Firestore (capstone-823dc):
- users/<uid> = {username, avatar, level, wins, losses, xp}

## Key Patterns & Conventions

### 1. HTTP Request Pattern (Transient)
Every REST call creates a new HTTPRequest node, connects once, then queue_free()s:
```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request_completed.connect(func(_result, code, _headers, body):
        http.queue_free()
        if code == 200:
                var data = JSON.parse_string(body.get_string_from_utf8())
                # process data
)
http.request("GET", url)
```

# Copilot Instructions for capstone2

This repo is a Godot 4.4 multi-game social platform using Firebase (Auth + RTDB + Firestore) and a Node WebSocket signaling server for 1v1 P2P in Code Breaker. Scenes navigate via visibility toggles and pass data through SceneTree meta.

## Architecture at a glance
- Flow: Auth → Landing (hub) → Game Lobbies → Rooms (ready state) → Arenas.
- Auth singleton: script/auth.gd (referenced by scene/auth.tscn). Exposes current_id_token, current_local_id, username/level and emits auth_response(code, response). Presence writes to RTDB at presence/<uid>.
- Chat: script/ChatManager.gd polls RTDB. Signals: message_received, chat_loaded, unread_count_changed.
- Code Breaker: script/code_breaker_lobby.gd (5s room polling), script/code_breaker_room.gd (2s state polling + start/ready flow), script/code_breaker_arena.gd (100ms local timer + WebSocket P2P with RTDB fallback).
- P2P signaling: server/server.js (Express + express-ws). Godot client: script/P2PWebSocketClient.gd.

## Data sources
- RTDB base: https://capstone-823dc-default-rtdb.firebaseio.com
        - presence/<uid> = {state, last_seen}
        - chats/<a_b>/messages/<pushKey> = {sender, text, timestamp, seen} where a_b is the two UIDs sorted lexicographically
        - codebreaker_rooms/<roomId> = {host, client, room_name, state, game_start_time, game_state?}
- Firestore: users/<uid> = {username, avatar, level, wins, losses, xp}

## Project conventions (do these here)
- Transient HTTPRequest: create a new HTTPRequest, connect once, and queue_free() in the callback. Example: see script/ChatManager.gd: _poll_new_messages() and script/code_breaker_lobby.gd: _fetch_rooms().
- Polling intervals: Lobby 5s (POLL_INTERVAL), Room 2s, Chat 2s current / 5s all-chats. Timers are added via add_child() so they clean up with the scene.
- Scene navigation: don’t swap the whole tree for subpanels; toggle visibility from scene/landing.tscn. When changing scenes, pass init via get_tree().set_meta(...) and read it in target _ready().
- Chat key sorting: always sort UIDs when building chat paths. Use ChatManager._get_chat_path(user1, user2).
- Token guard: never call Firebase endpoints without Auth.current_id_token.
- Arena transition guard: script/code_breaker_room.gd uses _transitioning_to_arena to avoid double scene changes.

## Code Breaker specifics you’ll reuse
- Start flow (host): code_breaker_room.gd::_on_start_pressed() sets state="in_game" and passes room snapshot via SceneTree meta to arena.
- Client detection: code_breaker_room.gd::_apply_room_snapshot() transitions when it sees state == "in_game".
- Arena timer: code_breaker_arena.gd uses a 100ms display timer based on game_start_time; game ends at 00:00, waits 3s, then returns to room.
- WebSocket P2P: P2PWebSocketClient.gd API
        - connect: connect_to_game(room_id, player_id, username, is_host, use_production)
        - signals: connection_established, opponent_action_received(action), opponent_disconnected, connection_error(error)
        - send: send_game_action({score, health, ...})
        - server URLs: dev ws://localhost:8080/ws/game, prod wss://code-breaker-p2p-signaling.onrender.com/ws/game
- RTDB fallback: code_breaker_arena.gd::_fallback_to_rtdb() starts 1s polling if WebSocket fails.

## Runbook (local dev)
- Requirements: Godot 4.4, Node 18+.
- Start signaling server: cd server; npm install; npm start (listens at ws://localhost:8080/ws/game; health at http://localhost:8080/health).
- Launch game: open project.godot in Godot; main entry is scene/landing.tscn (hub). Log in via Firebase; auth.gd contains API key and Google OAuth values used in dev.
- Verify presence: after login, Auth.set_user_online() writes to presence/<uid>.

## Examples to copy
- Create RTDB request (POST/PUT/PATCH): see code_breaker_lobby.gd::_create_room_and_enter, code_breaker_room.gd::_on_ready_toggled, auth.gd::_set_presence.
- Poll pattern: code_breaker_lobby.gd::_ready (5s room refresh), code_breaker_room.gd::_on_poll_timeout (2s), ChatManager.gd (2s/5s).
- Meta handoff: set in lobby/room, read in arena: keys code_breaker_room_init and code_breaker_arena_init.

## Common pitfalls
- Forgetting to sort chat IDs → duplicate chat threads. Always use the helper.
- Reusing an HTTPRequest → dangling connections. Create-per-call and free on completion.
- Changing scenes without checking get_tree() or without _transitioning_to_arena guard.
- Missing token in RTDB/Identity calls → 401/permission issues.

If anything here is unclear or you spot drift from the current code, tell me which section to expand or correct and I’ll refine it.
**Display timer** (100ms, local) + **State sync timer** (1s, RTDB):
