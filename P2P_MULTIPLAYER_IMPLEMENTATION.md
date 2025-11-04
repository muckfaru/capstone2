# P2P Multiplayer Implementation for Code Breaker Arena

## Overview
Implemented peer-to-peer 1v1 multiplayer game flow where:
- **Host** presses "START MATCH" button to initiate the game
- **Both players** transition to the arena scene simultaneously
- **Timer countdown** displays synchronously across both clients (15-second match)
- **Game state** syncs via RTDB polling every 1 second (no WebSocket required)

## Architecture

### Data Flow
```
Room Lobby → Room (waiting) → Host clicks START → Arena (15s countdown + P2P sync)
```

### Game State Structure in RTDB
```
/codebreaker_rooms/{room_id}/
  ├─ host: {username, uid, level, status}
  ├─ client: {username, uid, level, status}
  ├─ state: "waiting" | "in_game" | "completed"
  ├─ game_start_time: <unix_timestamp>  (set by host when START pressed)
  └─ game_state: {                       (updated every 1s during game)
       ├─ host_score: <int>
       ├─ client_score: <int>
       ├─ host_health: <0-100>
       ├─ client_health: <0-100>
       └─ status: "running" | "completed"
     }
```

## File Changes

### 1. `script/code_breaker_room.gd` (Modified)

**New Method: `_on_start_pressed()`**
- Only callable by host
- Updates room state to `"in_game"`
- Sets `game_start_time` to current Unix timestamp in RTDB
- Fetches full room data and passes it to arena via meta

**New Method: `_transition_to_arena()`**
- Fetches current room snapshot from RTDB
- Prepares arena init data:
  ```gdscript
  {
    "room_id": <string>,
    "is_host": <bool>,
    "host_name": <string>,
    "room_data": {
      "host": {...},
      "client": {...},
      "game_start_time": <int>
    }
  }
  ```
- Stores in `get_tree().set_meta("code_breaker_arena_init", ...)`
- Changes scene to `code_breaker_arena.tscn`

### 2. `script/code_breaker_arena.gd` (Completely Rewritten)

**Timer Display Synchronization:**
- `_sync_timer` (100ms): Updates countdown display locally
  - Calculates: `remaining = GAME_DURATION - (now - game_start_time)`
  - Formatted as MM:SS (e.g., "00:15" → "00:00")
  - No network latency affects display smoothness

**Game State Sync:**
- `_sync_poll_timer` (1s interval): Fetches game state from RTDB
  - Polls: `GET /rooms/{room_id}/game_state.json`
  - Updates scores and health bars
  - Updates sync indicator (green = connected, yellow = stale)

**Host Initialization:**
- Creates initial game state in RTDB with:
  ```
  {
    "host_score": 0,
    "client_score": 0,
    "host_health": 100,
    "client_health": 100,
    "status": "running",
    "start_time": <unix_timestamp>
  }
  ```

**Game Lifecycle:**
1. Load arena → show player names and timer
2. Both clients fetch room_data from meta
3. Host writes initial game_state to RTDB
4. Both clients start dual timers
5. Timer updates every 100ms (local)
6. Game state fetched every 1s (sync scores/health)
7. Timer reaches 00:00 → game ends
8. After 3s delay → return to room lobby
9. Clean up game_state node from RTDB

### 3. Scene: `code_breaker_arena.tscn` (Already properly structured)

The scene already has all necessary UI elements:
- `HeaderPanel/TimerLabel` - Displays MM:SS countdown (green)
- `HeaderPanel/HostNameLabel` - Player 1 name (cyan)
- `HeaderPanel/ClientNameLabel` - Player 2 name (red)
- `HeaderPanel/WSIndicator` - Connection status dot
- `VBox/StatusLabel` - Status text
- `VBox/ScorePanel/ScoreP1` & `ScoreP2` - Score display
- `VBox/ScorePanel/P1HealthBar` & `P2HealthBar` - Health bars

## Key Design Decisions

### Why Dual Timers in Arena?
1. **`_sync_timer` (100ms)**: Provides smooth, low-latency countdown display
   - No network calls needed
   - Calculated locally based on server-provided `game_start_time`
   - Both clients converge to same remaining time (ΔT = clock offset)

2. **`_sync_poll_timer` (1s)**: Fetches only essential game logic state
   - Scores, health, match status
   - Cheap operation (small JSON payload)
   - Sufficient for turn-based game logic

### Why No WebSocket?
- Existing HTTP + Timer pattern is proven in this codebase
- RTDB poll (1s) is acceptable for Code Breaker (likely turn-based)
- Reduces complexity; no separate WebSocket handler needed
- Token-based auth works seamlessly with REST

### Why Host Initializes Game State?
- Single source of truth for game clock
- Client can verify host is alive (by checking state updates)
- Prevents race conditions (no dual writes to game_state)

## Implementation Checklist

- ✅ Host START button triggers state change + arena transition
- ✅ Both players receive init data via `get_tree().set_meta()`
- ✅ Countdown timer displays locally (no polling)
- ✅ Game state syncs every 1s (scores, health)
- ✅ Connection indicator shows status (green/yellow)
- ✅ Auto-end at 00:00 + return to room after 3s
- ✅ RTDB cleanup on arena exit
- ✅ Player names displayed correctly

## Testing Steps

1. **Host Perspective:**
   - Create room → Wait for client to join → Click "START MATCH"
   - Should transition to arena with player names and 15s timer

2. **Client Perspective:**
   - Join existing room → See host and client ready statuses
   - Room state should poll and detect state="in_game"
   - Should auto-transition to arena

3. **Timer Sync:**
   - Open arena on two separate clients simultaneously
   - Timer should be within ±1s across both clients
   - Should countdown to 00:00 smoothly

4. **Game End:**
   - Let timer reach 00:00
   - After 3s, should return to room automatically
   - RTDB game_state node should be deleted

## Future Enhancements

1. **Player Input Handling:**
   - Each player's action (guess) → written to `game_state/player_actions`
   - Opponent polls for opponent's last action
   - Scores updated based on correct/incorrect responses

2. **Disconnect Handling:**
   - Monitor presence changes during game
   - If opponent disconnected: show warning, option to rejoin or forfeit

3. **Replay Feature:**
   - Store game moves in RTDB at `game_results/{match_id}`
   - Allow replay on room return

4. **Win/Loss Recording:**
   - Update player stats in Firestore after match
   - Record in player profile (wins, losses, rating)

## Code References

- **Room to Arena transition**: `code_breaker_room.gd` lines 327-380
- **Arena timer sync**: `code_breaker_arena.gd` lines 79-93
- **Arena state polling**: `code_breaker_arena.gd` lines 95-128
- **RTDB paths**: Constants in both scripts (RTDB_BASE, ROOMS_PATH)
