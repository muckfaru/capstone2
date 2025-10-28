# Capstone2 Copilot Instructions

## Project Overview
**Capstone2** is a Godot 4.4 multiplayer game platform featuring real-time chat, friend management, and competitive mini-games (e.g., "Code Breaker"). The backend uses Firebase (Authentication, Firestore for user profiles, Realtime Database for messaging).

## Architecture

### Core Components
1. **Auth Singleton** (`script/auth.gd`) - Global authentication handler
   - Manages Firebase email/password and Google OAuth login flows
   - Stores: `current_id_token`, `current_local_id`, `current_username`, `current_avatar`
   - Emits: `auth_response(response_code, Dictionary)` signal on auth completion
   - Handles token refresh and user presence state

2. **ChatManager Singleton** (`script/ChatManager.gd`) - Real-time messaging coordination
   - Polls Realtime Database for new messages (2s interval)
   - Tracks unread counts per user via `unread_count_changed` signal
   - Uses chat path: `conversations/{user1_id}/{user2_id}/messages`
   - Stores local copy of received message keys to avoid duplicates

3. **Scene Architecture** - Each major UI section has a `.tscn` + `.gd` pair
   - `landing.gd` - Main hub; loads user profile, instantiates chat panel
   - `friend_list.gd` - Friend/request management with presence dots
   - `chat.gd` - Draggable chat window, top-level positioning
   - `code_breaker_lobby.gd` / `code_breaker_room.gd` - Game lobbies and gameplay

### Data Flow Patterns
- **Auth Flow**: Email/password or Google OAuth → Firebase ID token → stored in `Auth` singleton
- **Chat Flow**: `ChatManager` polls → signals to `chat.gd` → UI updates + message display
- **Profile Updates**: Firestore REST API (PATCH) with `updateMask` fieldPaths
- **Presence**: Realtime Database write on login/logout + periodic refresh

## Firebase Integration

### Endpoints
- **Auth**: `https://identitytoolkit.googleapis.com/v1/accounts:*`
- **Firestore**: `https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents`
- **Realtime DB**: `https://capstone-823dc-default-rtdb.firebaseio.com`

### Key Collections
- `users/{uid}` - Profile data (username, level, wins, losses, avatar, requests_received, friends_list)
- `conversations/{user1}/{user2}/messages/{msgId}` - Chat messages
- `presences/{uid}` - Online status timestamp

### Auth Credentials
Located in `script/auth.gd` (review before deployment):
- API Key, Google OAuth Client ID/Secret, Redirect URI (localhost:8765 for dev)

## Development Patterns

### HTTPRequest Usage
**Pattern**: Create ephemeral HTTPRequest nodes with inline callbacks instead of storing reusable instances (except `landing.gd`).
```gdscript
var http := HTTPRequest.new()
add_child(http)
http.request_completed.connect(func(_r, code, _h, body):
    http.queue_free()
    if code != 200: return
    var data = JSON.parse_string(body.get_string_from_utf8())
    # Handle data
)
http.request(url, headers, HTTPClient.METHOD_GET)
```

### Signal-Based Auth
Auth responses propagate via `Auth.auth_response.connect(callback)` in login/signup scenes.
Always disconnect before reconnecting to prevent duplicate handlers.

### Firestore Field Mapping
Profile updates require wrapper format:
```gdscript
"fields": {
    "username": {"stringValue": value},
    "level": {"integerValue": str(value)},
    "wins": {"integerValue": str(value)}
}
```
Include `updateMask.fieldPaths` in URL query parameters for PATCH operations.

### Timer-Based Polling
Real-time updates use recurring timers (typically 2-5s intervals) instead of WebSocket listeners:
- `ChatManager._listen_timer` (2s) - polls current chat for new messages
- `ChatManager._all_chats_monitor_timer` (5s) - checks unread counts
- `friend_list.refresh_timer` (5s) - refreshes friend list

## Scene-Specific Conventions

### Chat Panel Dragging
`chat.gd` uses `top_level = true` to enable free positioning independent of parent layout. Handle node captured in `_handle` to enable mouse dragging. Connect `gui_input` → `_on_gui_input` for drag logic.

### Avatar Management
- Loaded from `res://asset/avatars/` directory at runtime via `DirAccess`
- File format: `.png`, `.jpg`, `.jpeg`, `.webp`
- 30-day cooldown enforced on profile save; tracked via `last_avatar_change` Unix timestamp

### Presence Indicators
Friend list displays online status as small dots (size: 10x10) overlaid on usernames via `Control` positioning and color coding (typically green for online).

## Testing & Debugging

### Common Issues
1. **"Auth singleton not registered"** - Ensure `Auth.gd` scene loads first (check `project.godot` autoload order)
2. **Chat not appearing** - Verify `landing.gd` calls `_instantiate_chat_panel()` and `ChatManager` is initialized
3. **Profile save fails** - Check Firestore security rules allow authenticated user write to their own document
4. **Message not received** - Check unread polling; may be rate-limited if too many concurrent HTTP requests

### Debug Output
Enable with prefix patterns in console:
- `[AUTH]` - Authentication events
- `[ChatManager]` - Messaging state
- `[Chat]` - Chat UI lifecycle
- `[FriendList]` - Friend management
- `[DEBUG]` - General setup (e.g., singleton registration)

## Key Files Reference
- **Auth/Singletons**: `scene/auth.tscn`, `script/auth.gd`, `script/ChatManager.gd`
- **UI Scenes**: `scene/landing.tscn`, `scene/chat.tscn`, `scene/friend_list.tscn`
- **Game**: `scene/code_breaker_*.tscn` (lobby and room scenes)
- **Config**: `project.godot` (autoload definitions, window settings)

## When Adding New Features
1. Declare signals at script top for cross-scene communication
2. Use `Auth` singleton to access current user context (don't duplicate auth state)
3. Create HTTPRequest nodes ephemeral; connect `request_completed` with inline lambda
4. Follow Firestore update URL pattern: include `updateMask.fieldPaths` for each modified field
5. Add console debug prefix matching existing patterns
6. Test locally with `REDIRECT_URI = "http://127.0.0.1:8765"` before deploying
