# Copilot instructions for this repo

## Big picture
**Multi-game social platform** (Godot 4.4 Forward+ renderer). Users authenticate, manage friends/presence, chat, and play mini-games (Code Breaker, Akashic TCG). Data flows: Firebase auth → RTDB (presence, chat, game rooms) ↔ Firestore (user profiles). Scene tree driven by visibility toggles; transient HTTP requests via `HTTPRequest` nodes.

## Architecture & flow
```
Login/Signup (Auth) → Landing (profile, friend list, chat, game lobbies)
  ├─ Friend List: displays online/offline, friend requests, initiates chats
  ├─ Chat: draggable DMs, real-time via RTDB polling + signals
  ├─ Game Lobbies: Code Breaker, Akashic TCG
  │   ├─ *_lobby.gd: poll RTDB for available rooms every 5s, create/join UI
  │   └─ *_room.gd: poll room state every 2s, sync player readiness/presence
  └─ Navigation: parent visibility (not tree changes); e.g., Landing.show(CodeBreakerLobby)
```

## Data model & services
- **Auth**: Firebase Identity Toolkit (REST) → `id_token` (JWT) + `localId`. Hard-coded API key & OAuth in `script/auth.gd` lines 6-8.
- **RTDB**: `https://capstone-823dc-default-rtdb.firebaseio.com`
  - `presence/<localId> = {state: "online"|"offline", last_seen: <unix_timestamp>}`
  - `chats/<sortedUserIds>/messages/<pushKey> = {sender, text, timestamp, seen}` (IDs sorted lexicographically, joined with `_`)
  - Game rooms: e.g., `codebreaker_rooms/<roomId> = {host, state, players, ready_flags}`
- **Firestore** (`capstone-823dc`): user profiles (username, avatar, level, stats)

## Singletons & core scripts
| Autoload | File | Role |
|----------|------|------|
| `Auth` | `script/auth.gd` (attached to `scene/auth.tscn`) | Auth state: `current_id_token`, `current_local_id`, `current_username`, `current_avatar`, `current_level`. Methods: `login()`, `sign_up()`, `set_user_online()`, `set_user_offline()`. Emits `auth_response(code, response)`. |
| `ChatManager` | `script/ChatManager.gd` (direct GDScript autoload) | Chat polling & state. Emits: `message_received(msg_dict)`, `chat_loaded(messages_array)`, `unread_count_changed(user_id, count)`. Methods: `set_current_user(user_id)`, `load_chat_history(other_id)`, `send_message(text)`, `mark_chat_as_read(other_id)`, `get_unread_count(user_id)`. Polls current chat every 2s, all chats for unreads every 5s. |

## Key patterns
1. **HTTP + Signals**: Each REST call creates a new `HTTPRequest` node, connects `request_completed`, processes response, then `queue_free()`s. Example in `login.gd` lines 83-95.
2. **Polling + Timers**: Game lobbies poll RTDB every 5s (`POLL_INTERVAL`). ChatManager uses two `Timer`s: 2s for current chat, 5s for unread scan.
3. **Scene navigation**: Show/hide panels on Landing (e.g., `_setup_navigation()` in `landing.gd`). Pass init data via `get_tree().set_meta("code_breaker_room_init", {...})` before scene change (see `code_breaker_lobby.gd` line 130).
4. **UI node refs**: Use `@onready var label: Label = $Path/To/Node` for early binding; guard with `if node:` checks before connect.
5. **Draggable windows**: `Chat` panel is top-level draggable; grab `_handle` node's `gui_input` to detect drag (see `chat.gd` lines 27-36).
6. **Anonymous toggle pattern**: `create_room_popup.gd` shows locking a LineEdit while toggling—store prior text and swap on toggle (lines 42-47).

## Auth flow (contract)
1. Call `Auth.sign_up(email, pwd)` or `Auth.login(email, pwd)`
2. Wait for `Auth.auth_response(code, response)` signal
3. On success (200), read `Auth.current_id_token` (JWT) and `Auth.current_local_id` (Firebase UID)
4. Call `Auth.set_user_online()` to set presence
5. **POST-auth**: fetch user profile from Firestore; set `ChatManager.set_current_user(Auth.current_local_id)` to enable chat

Optional: Google OAuth: call `Auth.exchange_google_code(code)` → same response contract.

## Chat flow (contract)
1. **Open chat with friend** `X`: call `ChatManager.load_chat_history(X_id)` → listens to `chat_loaded` signal
2. **Send**: call `ChatManager.send_message(text)` → RTDB push + signal `message_received`
3. **Mark read**: call `ChatManager.mark_chat_as_read(X_id)` before closing chat
4. **Unread count**: listen to `unread_count_changed` signal; optionally call `ChatManager.initialize_unread_for_friend(friend_id)` after friend list loads
5. **Always sort user IDs** when building chat path keys: `if user1_id > user2_id: swap`

## Game room flow (lobby → room → arena)
1. **Lobby** (e.g., `code_breaker_lobby.gd`): poll rooms every 5s, display list
2. **Create**: popup dialog collects room name + anonymous flag; create RTDB entry + pass init data to room scene
3. **Join**: set init meta → change scene to room
4. **Room** (e.g., `code_breaker_room.gd`): poll RTDB every 2s for state changes (player join, ready flags)
   - Host presses "START MATCH" (`_on_start_pressed()`) → updates room `state: "in_game"` + `game_start_time`, transitions to arena
   - Client polls room → detects `state: "in_game"` → auto-transitions to arena via `_transition_to_arena_from_poll()`
   - Both pass room data via `get_tree().set_meta("code_breaker_arena_init", {...})`
5. **Arena** (e.g., `code_breaker_arena.gd`): P2P 1v1 game with **no polling for gameplay**
   - Host initializes game state in RTDB at `rooms/<roomId>/game_state` with initial scores/health
   - Both players: sync timer every 100ms locally (countdown from `game_start_time`), poll game state every 1s (scores, health)
   - Game runs 3-minute (180s) countdown; on zero, auto-ends and returns to room
6. **Leave room**: delete RTDB room entry, return to lobby via visibility toggle

## P2P Arena pattern (1v1 multiplayer games)
- **Dual timer architecture**: 
  - **Display timer** (`_sync_timer`, 100ms): Local countdown from `game_start_time`, smooth MM:SS display with zero latency
  - **State sync timer** (`_sync_poll_timer`, 1s): Fetches remote game state (scores, health) from RTDB
- **Host responsibilities**: Writes initial game state to `rooms/<roomId>/game_state` at game start; both players read and display it
- **No gameplay input polling**: Each player's actions (guesses, scores) are written immediately to RTDB; opponent polls every 1s
- **Arena transition safety**: 
  - Room uses `_transitioning_to_arena` flag to prevent duplicate transitions
  - Both host and client check `get_tree()` validity before scene changes
  - Client detects state change and calls `_transition_to_arena_from_poll()` with full room data
- **Game end**: Timer reaches 00:00 → stop timers → await 3s → clean up `game_state` in RTDB → return to room
- **Connection indicator**: `WSIndicator` ColorRect shows sync status (green=connected, yellow=stale, red=error)

## Common gotchas & conventions
- **Guard token checks**: Always verify `Auth.current_id_token` is non-empty before REST calls.
- **Transient HTTP**: Never reuse `HTTPRequest` instances; create new per call.
- **Sorted chat keys**: User IDs in paths must be sorted lexicographically; `_build_chat_key(a, b)` helper in ChatManager.
- **UI navigation**: Don't tree-swap scenes; toggle visibility on Landing's child panels.
- **Timer cleanup**: Add timers via `add_child()` so they free with parent.
- **Main scene UID**: Stored in `project.godot` line 11; if changed, update Project Settings → Run.
- **@onready binding**: Order doesn't matter; Godot binds after `_ready()` is called, before script executes.
- **Signal connection order**: Connect in `_ready()` before any method might emit; use `.is_connected()` check to avoid double-connects.
- **Arena transition guard**: Use `_transitioning_to_arena` flag in room to prevent duplicate scene changes during polling.
- **Scene tree safety**: Always check `if get_tree():` before calling `set_meta()` or `change_scene_to_packed()` during transitions.
- **Game duration**: Set in `code_breaker_arena.gd` via `GAME_DURATION` constant (currently 180.0 = 3 minutes).

## Implementation checklist (Code Breaker P2P)
- ✅ Host START button → `_on_start_pressed()` → updates room state to "in_game"
- ✅ Client polls → detects state change → calls `_transition_to_arena_from_poll()`
- ✅ Both transition with room data via `get_tree().set_meta("code_breaker_arena_init", ...)`
- ✅ Arena displays countdown (MM:SS) updated locally every 100ms
- ✅ Arena syncs scores/health every 1s from RTDB
- ✅ Connection indicator shows sync status
- ✅ Auto-end at 00:00 + return to room after 3s
- ✅ RTDB cleanup on arena exit (delete game_state node)
