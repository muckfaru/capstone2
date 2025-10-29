# Copilot instructions for this repo

## Big picture
- Godot 4.4 project (Forward+ renderer). Open `project.godot` in the editor; the main scene is set by UID in project settings.
- Code: GDScript in `script/`; scenes in `scene/` (`*.tscn`). Common 1:1 naming: `scene/foo.tscn` ↔ `script/foo.gd`.
- Autoload singletons:
  - `Auth` → `scene/auth.tscn` (`script/auth.gd`): Firebase auth, Google OAuth, presence.
  - `ChatManager` → `script/ChatManager.gd`: chat history, polling, unread counts, send/seen updates.

## Services and data model
- Firebase Identity Toolkit (REST) for email/password and Google IdP; Google OAuth code exchange → Firebase `id_token`.
- RTDB base: `https://capstone-823dc-default-rtdb.firebaseio.com`.
  - Presence: `presence/<localId> = { state: online|offline, last_seen: <unix> }`.
  - Chats: `chats/<sortedUser1>_<sortedUser2>/messages/<pushKey> = { sender, text, timestamp, seen }` (user IDs sorted then joined with `_`).

## Patterns to follow
- Signals + timers: `ChatManager` emits `message_received`, `chat_loaded`, `unread_count_changed`; polls current chat every 2s and unread across chats every 5s.
- HTTP with transient `HTTPRequest` nodes (create, connect `request_completed`, then `queue_free`).
- `Auth` keeps global state: `current_id_token`, `current_local_id`, `current_username`, `current_avatar`, `current_level`.
- UI access via `$` with `@onready` vars; e.g., `@onready var http_request: HTTPRequest = $HTTPRequest`.

## Key flows (contracts)
- Auth: call `sign_up`/`login` or `exchange_google_code` → `login_with_google`; listen to `auth_response(code, response)`; on success read `Auth.current_id_token` and `Auth.current_local_id`; update presence via `set_user_online/offline`.
- Chat: call `ChatManager.set_current_user(Auth.current_local_id)` post-login; open a thread with `load_chat_history(other_user_id)`; send via `send_message(text)`; mark as read with `mark_chat_as_read(other_user_id)`.

## Working in this project
- Run/edit with the Godot Editor. Screens live under `scene/` (e.g., `landing.tscn`, `login.tscn`, lobbies/rooms, chat UIs).
- New UI: create `scene/*.tscn`, attach `script/*.gd`, wire signals; call `Auth`/`ChatManager` as globals.
- Chat UI tips: use `unread_count_changed` for badges; optionally call `initialize_unread_for_friend(friend_id)` after listing friends; always sort user IDs when building chat paths.
- Example UX pattern: `script/create_room_popup.gd` shows toggling an "Anonymous" name that locks the `LineEdit` while preserving the last non-anonymous input.

## Gotchas
- Guard REST calls on `Auth.current_id_token` being non-empty.
- Don’t reuse `HTTPRequest` instances; each call creates and frees one.
- Main scene is stored by UID; if changed, update Project Settings → Run.
- API keys/OAuth client IDs are hard-coded in `script/auth.gd`.
