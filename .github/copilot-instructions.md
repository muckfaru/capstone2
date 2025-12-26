# Copilot Instructions for capstone2

## 🎮 Big Picture
**Godot 4.4 multi-game social platform** with Firebase authentication and **WebSocket Relay multiplayer** (no port forwarding required). Architecture: Auth → Landing (hub) → Game Lobbies → Rooms → Loading → Arenas (1v1 gameplay). Two games: **Code Breaker** (submit-based typing combat) and **Akashic TCG** (turn-based card game). Scene navigation uses visibility toggles for Landing, `change_scene_to_packed()` for game flows. REST via transient `HTTPRequest` nodes; Multiplayer via **Node.js relay server** on Render.com.

```
Firebase Auth ──→ Landing (profile/chat) ──→ Game Lobbies ──→ Rooms ──→ Loading ──→ Arenas
                           │                        │               │          │
                    Auth.gd (autoload)      Relay Connection   Sync Screen  Combat
                    ChatManager.gd          (no port fwd!)     (30s max)   (Submit-Based)
```

## 🎓 Tutorial System

**XP-Based Progression** - Complete tutorials to earn XP, unlock ranks, and unlock games (like Code Breaker).

### Tutorial Manager (Autoload Singleton)
- **File:** `script/TutorialManager.gd`
- **Firestore Integration:** Saves/loads completed tutorials, total XP, unlocked games
- **Rank System:** 9 ranks (Iron → Bronze → Silver → Gold → Platinum → Diamond → Master → Grandmaster → Challenger)
- **Game Unlocks:**
  - **Akashic TCG:** Always unlocked (0 XP)
  - **Code Breaker:** Unlocked at 500 XP
  - **Game 3:** Future (1500 XP)

### Tutorial Categories
**Beginner Tutorials:**
- `tutorial_beginner.tscn` - Password strength basics (timed challenge, 30s)
- `tutorial_cyber_fundamentals.gd` - Core cybersecurity concepts
- `tutorial_network_basics.gd` - Ports, IPs, traffic analysis
- `tutorial_password_basics.gd` - Password fortress battle game
- `tutorial_malware_types.gd` - Types of malware

**Intermediate Tutorials:**
- `tutorial_phishing_lab.tscn` - Email classification lab (5 emails, phishing vs. legitimate)
- `malware_trojan_tutorial.tscn` - Trojan horse attack simulation

**Advanced Tutorials:**
- `tutorial_encryption_basics.gd` - Caesar cipher + ransomware explanation
- `tutorial_advance.tscn` - Advanced scenarios
- `tutorial_advance_interactive.tscn` - Interactive advanced labs

### XP Rewards
- **90%+ score:** 200 XP (A grade)
- **80-89% score:** 150 XP (B grade)
- **70-79% score:** 100 XP (C grade)
- **50-69% score:** 50 XP (D grade)
- **Below 50%:** 0 XP (F grade - fail)

### Tutorial Flow
```
Landing (Tutorial Button)
    ↓
Mode Selection (Beginner/Intermediate/Advanced)
    ↓
Select Tutorial
    ↓
Complete Challenge (timed/scored)
    ↓
TutorialManager.complete_tutorial(id, score, max_score)
    ↓
Calculate Grade & XP:
  - Score 90%+ → 200 XP (A)
  - Score 80-89% → 150 XP (B)
  - Score 70-79% → 100 XP (C)
  - Score 50-69% → 50 XP (D)
  - Score <50% → 0 XP (F - fail)
    ↓
Save to Firestore → Award XP → Check rank up → Check game unlocks
    ↓
Emit Signals:
  - xp_updated(new_xp)
  - rank_up(new_rank) [if ranking up]
  - game_unlocked(game_name) [if unlocking game]
    ↓
Return to Mode Selection
```

### Tutorial Manager API
```gdscript
# Core Methods
TutorialManager.complete_tutorial(tutorial_id: String, score: int, max_score: int) → void
TutorialManager.load_user_data() → void (from Firestore)
TutorialManager.save_user_data() → void (to Firestore)
TutorialManager.get_rank() → Dictionary  # {rank_number, rank_name, xp_progress}
TutorialManager.is_game_unlocked(game_name: String) → bool

# Properties
TutorialManager.total_xp → int
TutorialManager.current_rank → String
TutorialManager.unlocked_games → Array[String]
TutorialManager.completed_tutorials → Dictionary
```

### Game Unlock Thresholds
| Game | XP Required | Status |
|------|-------------|--------|
| Akashic TCG | 0 XP | Always unlocked |
| Code Breaker | 500 XP | Unlock via tutorials |
| Game 3 | 1500 XP | Future |

### Rank Progression (9 Levels)
| Rank | XP Range | Status |
|------|----------|--------|
| 1. Iron | 0 - 199 | Beginner |
| 2. Bronze | 200 - 399 | Progressing |
| 3. Silver | 400 - 699 | Code Breaker Unlocked! 🔓 |
| 4. Gold | 700 - 1099 | Advanced |
| 5. Platinum | 1100 - 1599 | Expert |
| 6. Diamond | 1600 - 2299 | Master |
| 7. Master | 2300 - 3199 | Elite |
| 8. Grandmaster | 3200 - 4499 | Legendary |
| 9. Challenger | 4500+ | Peak |

### Tutorial Leveling System Flow

```
Complete Tutorial
    ↓
Calculate Score (%)
    ↓
Grade Assignment:
  - 90%+ → 200 XP (A) - Excellent
  - 80-89% → 150 XP (B) - Good
  - 70-79% → 100 XP (C) - Pass
  - 50-69% → 50 XP (D) - Attempted
  - <50% → 0 XP (F) - Failed
    ↓
Get Old Rank (before XP)
    ↓
Add XP: total_xp += xp_earned
    ↓
Get New Rank (after XP)
    ↓
Rank Up? (emit rank_up signal if new rank)
    ↓
Check Game Unlocks:
  - Akashic TCG: 0 XP (always unlocked)
  - Code Breaker: 500 XP ✓
  - Game 3: 1500 XP (future)
    ↓
Save All to Firestore:
  - User XP & rank
  - Completed tutorials
  - Unlocked games
    ↓
Emit Signals:
  - xp_updated(new_xp)
  - rank_up(new_rank) [if ranking up]
  - game_unlocked(game_name) [if unlocking]
  - save_completed()
```

### Leveling Mechanics
- **XP Accumulates:** Never resets, only increases
- **Rank Based on Total XP:** Check which bracket (0-199, 200-399, etc.)
- **Progress Bar:** Shows XP progress within current rank bracket
- **One-Time Per Tutorial:** Can't farm same tutorial multiple times for XP
- **Firestore Persistence:** All progress saved to Firebase (uid-based)

### Rank Icons & Colors
| Rank | Color | Icon |
|------|-------|------|
| Iron | Grey | IRON.png |
| Bronze | Bronze | BRONZE.png |
| Silver | Silver | SILVER.png |
| Gold | Gold | GOLD.png |
| Platinum | Cyan | PLATINUM.png |
| Diamond | Blue | DIAMOND.png |
| Master | Purple | MASTER.png |
| Grandmaster | Red | GRAND MASTER.png |
| Challenger | Cyan | CHALLENGER.png |

### Signals
- `xp_updated(new_xp: int)` - XP changed
- `rank_up(new_rank: Dictionary)` - Player ranked up
- `game_unlocked(game_name: String)` - New game unlocked
- `data_loaded()` - Firestore data loaded
- `save_completed()` - Save finished

## 🏗️ Architecture: WebSocket Relay

**NO PORT FORWARDING NEEDED** - Both players connect TO server, server relays messages.

### Server Infrastructure
- **Production:** `https://codebreaker-lobby.onrender.com` (Render.com free tier)
- **Local Dev:** `http://localhost:8080` (for testing)
- **Tech Stack:** Express.js + express-ws + in-memory room storage
- **Endpoints:**
  - `POST /api/rooms/create` - Register room (no IP/port needed)
  - `GET /api/rooms/list` - List active rooms (supports `?game_type=code_breaker|akashic_tcg`)
  - `GET /api/rooms/:id` - Get room details (includes `status`)
  - `POST /api/rooms/:id/join` - Join as client
  - `POST /api/rooms/:id/leave` - Leave room (with host promotion)
  - `POST /api/rooms/:id/heartbeat` - Keep room alive (30s interval)
  - `POST /api/rooms/:id/status` - Update room `status` (`waiting|in_game|finished`)
  - `WS /ws/relay/:room_id` - WebSocket relay for gameplay

### Room Lifecycle
```
1. Host: POST /create → room_id
2. Client: GET /list → sees room → POST /join
3. Both: WS /ws/relay/:room_id → connected
4. Host: Clicks START → both transition to arena
5. Arena: WebSocket relays game actions (typing, damage, etc.)
6. Game ends → both transition to Post-Game Analytics; room `status` becomes `finished`
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
| **TutorialManager** | `script/TutorialManager.gd` | XP/rank tracking, tutorial completion, game unlocks. Methods: `complete_tutorial()`, `get_rank()`, `is_game_unlocked()`, `load_user_data()`, `save_user_data()`. Signals: `xp_updated`, `rank_up`, `game_unlocked`, `data_loaded`, `save_completed`. Firestore integration for persistence. |
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
users/<uid> = {
  username, avatar, level, wins, losses, xp,
  total_xp: int,              // Total XP earned from tutorials
  unlocked_games: [String],   // Array of unlocked game IDs
  tutorials: {                // Map of completed tutorials
    <tutorial_id>: {
      score: int,
      max_score: int,
      percentage: float,
      xp_earned: int,
      timestamp: int
    }
  }
}
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
users/<uid> = {
  username, avatar, level, wins, losses, xp,
  total_xp: int,              // Total XP earned from tutorials
  unlocked_games: [String],   // Array of unlocked game IDs
  tutorials: {                // Map of completed tutorials
    <tutorial_id>: {
      score: int,
      max_score: int,
      percentage: float,
      xp_earned: int,
      timestamp: int
    }
  }
}
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

## ♻️ Reconnect + Session Persistence (Code Breaker)

**Goal:** LoL-style resume after crash/relogin without desync.

### Session Store
- **File:** `script/CodeBreakerSessionStore.gd`
- **Persistence:** `ConfigFile` saved to `user://code_breaker_session.cfg`
- **Saved fields (typical):** `room_id`, `lobby_url`, `player_id` (may be empty), `phase` (`room|loading|arena`), `timestamp`
- **Important rule:** never persist placeholder `player_id == "unknown"` (store as empty) to avoid false mismatch wipes.

### Status-Aware Resume Routing
After auth, the client validates the session via `GET /api/rooms/:id` and routes by `status`:
- `waiting` → go to Room
- `in_game` → go to Reconnect
- `finished` → go to Postgame (`result_unknown` is allowed on resume)
- `404` / room missing → clear session and stay on Landing

### Landing Resume Safety Net
- Landing retry logic avoids clearing sessions on transient network failures.
- When resuming, it will try both the **saved lobby URL** (from the session) and the **current URL** (from `MultiplayerConfig`) to handle `localhost` ↔ `production` mismatches.

## ♻️ Reconnect + Session Persistence (Akashic TCG)

**Goal:** recover from disconnect/crash without getting stuck in Room/Loading/Arena.

### Session Store
- **File:** `script/AkashicTCGSessionStore.gd`
- **Persistence:** `ConfigFile` saved to `user://akashic_tcg_session.cfg`
- **Saved fields:** `room_id`, `lobby_server_url`, `player_id` (may be empty), `username`, `phase` (`room|loading|arena`), `timestamp`
- **Important rule:** never persist placeholder `player_id == "unknown"` (store as empty).

### Status-Aware Resume Routing
- Implemented in both `script/login.gd` (immediate post-login) and `script/landing.gd` (safety net).
- The client validates the session via `GET /api/rooms/:id` and routes by `status`:
  - `waiting` → Room
  - `in_game` → Reconnect (`scene/akashic_tcg_reconnect.tscn`)
  - `finished` → Postgame (`result_unknown` allowed)
  - `404` → clear session and stay on Landing

### Scene-Level Recovery
- `script/akashic_tcg_room.gd`, `script/akashic_tcg_loading.gd`, and `script/akashic_tcg_arena.gd` route to reconnect on relay disconnect/timeouts.
- `script/akashic_tcg_postgame.gd` clears the session on entry to prevent reconnect loops into finished matches.

## 🃏 Akashic TCG Multiplayer + Round-Based State Sync

**Authority model:** Host-authoritative. Host owns canonical game state and broadcasts `state_sync` with monotonically increasing `version`.

### Core Scenes
1. Lobby → `script/akashic_tcg_lobby.gd`
2. Room → `script/akashic_tcg_room.gd` (ready/start, heartbeat, relay connect)
3. Loading → `script/akashic_tcg_loading.gd` (handshake `loading_status`/`loading_status_request`)
4. Arena → `script/akashic_tcg_arena.gd` (simultaneous submit-per-round + relay state sync)
5. Reconnect → `script/akashic_tcg_reconnect.gd` (routes to Loading or Arena depending on last known `phase`)
6. Postgame → `script/akashic_tcg_postgame.gd`

### Arena Protocol (Akashic)
Client-to-host action requests:
```json
{ "type": "tgc_action_request", "room_id": "...", "actor": "uid", "action": "submit_card", "payload": {"hand_index": 2, "card_id": "virus"}, "known_version": 12, "client_action_id": 7 }

{ "type": "tgc_action_request", "room_id": "...", "actor": "uid", "action": "cancel_card", "payload": {"slot_index": 0}, "known_version": 12, "client_action_id": 8 }

{ "type": "tgc_action_request", "room_id": "...", "actor": "uid", "action": "pass", "payload": {}, "known_version": 13, "client_action_id": 8 }

{ "type": "tgc_action_request", "room_id": "...", "actor": "uid", "action": "concede", "payload": {}, "known_version": 13, "client_action_id": 9 }
```

Host state broadcast (full state snapshot):
```json
{ "type": "tgc_state_sync", "room_id": "...", "state": {"version": 13, "turn": 4, "priority": "uid_host", "pending": {"uid_host": ["virus"], "uid_client": []}, "pending_costs": {"uid_host": [2], "uid_client": []}, "round_done": {"uid_host": false, "uid_client": false}, "resolve_scheduled": false, "winner_id": "", "players": {"uid_host": {"si": 20, "fw": 0, "bw": 2, "bw_max": 10, "plays_left": 3, "status": {}}, "uid_client": {"si": 20, "fw": 0, "bw": 2, "bw_max": 10, "plays_left": 3, "status": {}}}}, "meta": {"type": "action"} }
```

State recovery:
```json
{ "type": "tgc_request_state", "player_id": "uid" }
```

Validation/feedback:
```json
{ "type": "tgc_action_reject", "reason": "invalid|no_state|game_over|unknown_actor" }
```

Match end:
```json
{ "type": "tgc_match_end", "winner_id": "uid", "reason": "si_zero|concede" }
```

## 🧠 Akashic TCG Mechanics (Final v0.1)

**Theme:** Hacker vs Hacker (spell/status-based). **1v1 simultaneous rounds (both submit, then resolve).**

### Core Stats + Limits
- **SI (System Integrity / HP):** 20 per player. At 0 → lose.
- **FW (Firewall):** absorbs damage before SI, **max 12** (unless an attack bypasses it).
- **BW (Bandwidth / resource):** max **10**; carries over (spending reduces it, PASS does not).
  - Start of each round: gain BW (cap 10): rounds 1-2 `+2`, rounds 3-6 `+3`, rounds 7-10 `+4`, rounds 11+ `+5`.
  - **Lag:** reduces that round’s BW gain by `1`.
- **Plays per round:** **up to 3 submissions** (submit up to 3 affordable cards, or **PASS** to finish early).
- **Hand limit:** **7** (excess burns/discards to prevent hoarding).

### Round Loop (High Level)
1. Round start: apply start-of-round effects (e.g., Infected tick), BW refresh, draw
2. Each player can **submit up to 3 cards** this round (as long as they have BW and plays left), or **PASS** to finish early
3. Players may **cancel** a submitted card (click their dropped slot) to return it to hand and refund BW/plays **as long as resolution hasn’t been scheduled**
4. If a player has **no affordable plays** (or no plays left), they are auto-marked as done
5. When both players are done: a short reveal window plays, then resolve in **priority order** (host first, then alternate each round)
6. Next round starts

### UX Notes (Arena)
- **Center dropped cards:** shows up to 3 submissions per player for the current round.
- **Reveal timing:** opponent cards stay face-down until **both players are done**, then **reveal all at once** before resolve.
- **Hover tooltips:** hovering a card shows name, cost, and effect text.
- **Undo:** clicking your own dropped card cancels it (before resolve), returning it to hand and refunding BW/plays.

### Final Card Set (10 cards, using existing assets)
Defense:
- **MFA** (cost 1): blocks the next **Phishing**.
- **IDS** (cost 2): reduces the next incoming attack by **3**, then draws **1**.
- **Encryption Key** (cost 2): reduces **Phishing/Virus/Trojan** by **2**.
- **Firewall Shield** (cost 2): increases FW (refill/boost).
- **Antivirus Core** (cost 2): removes infection-style statuses (e.g., **Infected**).

Attack:
- **Phishing** (cost 1, base dmg 2)
- **Virus** (cost 2, low dmg + **Infected**)
- **Trojan Horse** (cost 3, base dmg 3): **bypasses FW** (hits SI directly).
- **DOS** (cost 2, base dmg 4)
- **DDOS** (cost 4, base dmg 8)

### Damage / Mitigation Order (Important)
When an attack resolves, apply mitigation in this order:
1. **MFA** (blocks *Phishing* or *Trojan*)
2. **IDS** (−3 damage, then draw 1)
3. **Encryption** (−2 damage; applies to Phishing/Virus/Trojan)
4. **FW soak** (remaining damage reduces FW)
5. **SI** (remaining damage reduces SI)

**Trojan rule:** Trojan damage bypasses FW (goes to SI) while still being eligible for mitigation effects (IDS/Encryption) if active.

### Statuses (Final)
- **MFA Active:** blocks next Phishing.
- **IDS Active:** next incoming attack −3, then draw 1.
- **Encrypted:** next incoming attack −2.
- **Infected:** tick damage at start of turn until cleansed by Antivirus.
- **Credential Compromised:** boosts next defense effectiveness (one-time).
- **Lag:** next turn BW refresh −1.
- **Backdoor:** next **Attack** card costs −1; consumed only when an Attack is played.

### Mid/Late Game Gating (Option B: Shuffle‑In Packages)
To prevent early DOS/DDOS dominance:
- On a player’s **4th turn taken**: shuffle **2× DOS** into their deck.
- On a player’s **6th turn taken**: shuffle **2× DDOS** into their deck.

### Win / Exit
- Win when opponent SI reaches 0.
- **Concede** exists in protocol, but current arena UX uses **PASS** + auto-resolve.

## 🌐 Code Breaker Multiplayer Flow

### Lobby → Room → Loading → Arena (Complete Flow)

1. **Lobby Scene** (`code_breaker_lobby.gd`)
  - Polls `GET /api/rooms/list?game_type=code_breaker` every 5s
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

3. **Loading Screen** (`code_breaker_loading.gd`) **[IMPROVED!]**
   - Receives `relay_client` from room (adopts from root)
   - Shows two player cards with progress bars
   - **Left card = YOU, Right card = OPPONENT** (perspective-based)
   - Simulates loading: 30% → 60% → 100% (1.5s total)
   - Sends `loading_status: "ready"` via relay when complete
   - Waits for opponent's ready message
   - When both ready: 2s countdown → Arena
  - **Timeout:** 60s max, returns to room if sync fails
   - **Retry System:** 5 retry attempts (increased from 3), every 2s
   - **Settling Delay:** 4.0s initial wait (increased from 0.5s) before first message
   - **Verbose Logging:** Timestamps on all messages, connection status tracking, message delay measurement
  - **Self-healing sync:** uses `loading_status_request` to re-announce state after reconnect/message loss
  - **Robust handling:** ignores self-echo relay messages; on relay reconnect it re-sends own status + requests opponent status
   - **Relay client reparented to root** before arena transition

4. **Arena Scene** (`code_breaker_arena.gd`)
   - Receives `relay_client` from loading (adopts from root)
   - **Health Bar Initialization:** Explicitly sets min/max/value to 100 on scene start
   - **3-2-1 Countdown:** Centered countdown with bounce animation before game starts
   - **Timer Pause:** 3-minute timer paused during countdown, starts after "TYPE!"
   - **Stats Sync Timer:** Only starts AFTER countdown (prevents premature stats updates)
   - **Game Timer Fix:** Uses `Time.get_ticks_msec() / 1000.0` for consistency (not unix time)
   - Host generates snippet list → sends via relay
   - Client receives snippets → sends `client_ready`
   - Host receives ready → starts game for both
   - **Submit-Based Combat System:**
     - Type code in input field, press ENTER to submit
     - ✅ Correct submission: +100 score, -10 opponent HP
     - ❌ Wrong submission: -8 self HP (penalty)
     - First to 0 HP = LOSE
     - Case-sensitive, exact match required
   - **🎁 POWER-UP SYSTEM (Random per snippet):**
     - 🛡️ **10% SHIELD** (grey panel) - 15s invincibility: blocks all damage + self-damage penalty
     - 🧊 **10% FREEZE_TIME** (ice blue panel) - 15s snippet timer freeze (main timer keeps running)
     - 🟡 **25% EXTEND_TIME** (yellow panel) - 20s buff: +15s per snippet, +8s main timer (one-time)
     - 💚 **30% HEAL** (green panel) - +10 HP on correct answer
     - ⚪ **25% NORMAL** (white panel) - no bonus
   - **Power-Up Effects:**
     - Shield: Enemy damage = 0, wrong answer = 0 penalty, 15s carry-over
     - Freeze: Snippet timer shows "⏸️ FROZEN", no countdown, 15s carry-over
     - Extend: Snippet timer gets +15s bonus, main timer +8s, 20s carry-over across snippets
     - Heal: Instant +10 HP when correct (no carry-over, one-time per snippet)
   - **Gameplay via relay messages:**
     - Type correct → `damage` message to opponent (or blocked if shield active)
     - Stats sync: `stats_update` (score, health) every 0.5s
     - Game end: `player_died` or `player_finished`
   - **Visual Effects:**
     - Shake animations on damage (health bar + screen shake on critical)
     - Bounce/scale animations on countdown numbers
     - Success sparkle particles on correct answer (15 particles)
     - Explosion particles on damage (12 normal / 25 critical)
     - Panel shadows for depth (8-12px shadows)
     - Text outlines on countdown (8px black outline + cyan shadow)
     - Pop/bubble animations on code panel (3 presets: subtle/normal/dramatic)
     - Panel color changes show active power-up (different Sprite2D visible per type)
   - **Battle Music:** Auto-fade in on start, stops on leave
   - Game ends → **transitions to post-game analytics** (NOT room/landing)
  - **Room status:** on match end/leave, posts `POST /api/rooms/:id/status` with `finished` to prevent reconnect loops into dead sessions
   - Relay connection cleaned up on game end

6. **Reconnect Scene** (`code_breaker_reconnect.gd`)
  - Used when a player relogs mid-match (`status == in_game`).
  - Re-establishes relay connection, then forces a sync path into Loading/Arena using relay messages.

5. **Post-Game Analytics** (`code_breaker_postgame.gd`) **[NEW!]**
   - Shows match results with animated card reveal
   - **Winner Determination:** Based on health comparison (consistent for both players)
   - **Data Display:**
     - Winner badge (🏆 WINNER) - only ONE player gets this
     - Status: ✅ VICTORY or ❌ DEFEATED
     - XP earned: +500 (winner) or +0 (loser)
     - Game duration: formatted as "Xm Ys"
     - Power-ups used: count of activated buffs
   - **Firestore Integration:**
     - Saves XP to `users/{uid}/total_xp`
     - Records match history to `match_history/{match_id}`
   - **Back to Landing:** Button navigates to landing hub (NOT lobby)
   - Relay connection freed on exit

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
{"type": "loading_status", "status": "loading|ready", "player_id": "...", "timestamp": 1234567890}
{"type": "loading_status_request", "player_id": "...", "timestamp": 1234567890}
```

**Arena Messages:**
```json
{"type": "snippet_list", "snippets": [...]}
{"type": "client_ready", "player_id": "..."}
{"type": "game_start", "player_id": "..."}
{"type": "damage", "damage": 10, "player_id": "..."}
{"type": "stats_update", "score": 100, "health": 92, "player_id": "...", "timestamp": 1234567890}
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

## 🎁 Power-Up System (Arena)

**Random Power-Ups** - Each snippet randomly gets a power-up type (shown via colored panel). Correct answer = activate power-up buff!

### Power-Up Distribution
| Type | Chance | Panel | Effect | Duration |
|------|--------|-------|--------|----------|
| **SHIELD** 🛡️ | 10% | Grey | 0 damage from attacks + 0 penalty on wrong | 15s carry-over |
| **FREEZE_TIME** 🧊 | 10% | Ice Blue | Snippet timer frozen (main timer running) | 15s carry-over |
| **EXTEND_TIME** 🟡 | 25% | Yellow | +15s per snippet, +8s main timer (one-time) | 20s carry-over |
| **HEAL** 💚 | 30% | Green | +10 HP instant | One-time per snippet |
| **NORMAL** ⚪ | 25% | White | No bonus | N/A |

### Power-Up Logic
```gdscript
// During pop animation, randomly select power-up:
var rand_value = randf()
if rand_value < 0.10:
    _current_powerup = PowerUpType.SHIELD
elif rand_value < 0.20:
    _current_powerup = PowerUpType.FREEZE_TIME
elif rand_value < 0.45:
    _current_powerup = PowerUpType.EXTEND_TIME
elif rand_value < 0.75:
    _current_powerup = PowerUpType.HEAL
else:
    _current_powerup = PowerUpType.NORMAL

// On correct answer, apply power-up effect
match _current_powerup:
    PowerUpType.SHIELD:
        _shield_active = true
        _shield_time_remaining = 15.0
    PowerUpType.FREEZE_TIME:
        _time_frozen = true
        _freeze_time_remaining = 15.0
    PowerUpType.EXTEND_TIME:
        _extend_time_active = true
        _extend_time_remaining = 20.0
        _snippet_time_remaining += 15.0
        _game_start_time += 8.0
    PowerUpType.HEAL:
        player_health += 10
```

### Power-Up Effects Details
- **SHIELD (Grey Panel):** Blocks enemy damage + self-damage penalty for 15 seconds. Persists across multiple snippets.
- **FREEZE_TIME (Ice Blue Panel):** Pauses snippet timer (not main timer) for 15 seconds. Allows unlimited time to type current snippets. Persists across multiple snippets.
- **EXTEND_TIME (Yellow Panel):** Gives 20-second buff where every new snippet starts with +15s (30s instead of 15s). One-time +8s bonus to main match timer.
- **HEAL (Green Panel):** Restores +10 HP when correct answer submitted. No carry-over, one-time per snippet.


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
| **TGC Session Store** | `script/AkashicTCGSessionStore.gd` | Persists Akashic room/session (`user://akashic_tcg_session.cfg`) for resume routing |
| **Lobby** | `script/code_breaker_lobby.gd` | Room list polling (5s), create/join rooms |
| **Room** | `script/code_breaker_room.gd` | Room state polling (2s), relay setup, ready system, heartbeat |
| **Loading** | `script/code_breaker_loading.gd` | Player sync screen, progress bars, 30s timeout, relay preservation |
| **Arena** | `script/code_breaker_arena.gd` | 1v1 submit-based typing combat, power-up system (5 types), damage system (±10 HP), shield/freeze/extend/heal buffs, stats sync (0.5s), relay messages, animations, particles, music |
| **TGC Lobby** | `script/akashic_tcg_lobby.gd` | Lobby server `/api/rooms/*` integration; filters `game_type == "akashic_tcg"` |
| **TGC Room** | `script/akashic_tcg_room.gd` | Ready/start + heartbeat + relay connect; routes to reconnect on disconnect |
| **TGC Loading** | `script/akashic_tcg_loading.gd` | Loading handshake; routes to reconnect on timeout/disconnect |
| **TGC Arena** | `script/akashic_tcg_arena.gd` | Host-authoritative round-based submit system; `tgc_state_sync`/`tgc_action_request` |
| **TGC Reconnect** | `script/akashic_tcg_reconnect.gd` | Reconnect/resume routing into Loading or Arena based on session `phase` |
| **TGC Postgame** | `script/akashic_tcg_postgame.gd` | Minimal result screen; clears TGC session on entry |
| **Lobby Server** | `server/server.js` | Express + express-ws, REST API + WebSocket relay, in-memory rooms |

### Arena Animation Functions
```gdscript
_shake_node(node, intensity, duration)           // Shake any UI node horizontally
_shake_screen(intensity, duration)               // Shake entire screen (X/Y axis)
_bounce_scale(node, scale_multiplier, duration)  // Bounce/scale effect with tween
_spawn_success_particles(position)               // Spawn 15 sparkle particles on correct answer
_spawn_damage_explosion(position, is_critical)   // Spawn 12-25 explosion particles on damage
```

### Scene Hierarchy
```
scene/
├─ auth.tscn (autoload singleton)
├─ landing.tscn (hub with visibility toggles)
├─ code_breaker_lobby.tscn
├─ code_breaker_room.tscn
├─ code_breaker_reconnect.tscn
├─ code_breaker_loading.tscn
├─ code_breaker_arena.tscn
├─ code_breaker_postgame.tscn
├─ akashic_tcg_lobby.tscn
├─ akashic_tcg_room.tscn
├─ akashic_tcg_loading.tscn
├─ akashic_tcg_arena.tscn
├─ akashic_tcg_reconnect.tscn
└─ akashic_tcg_postgame.tscn
```

### Server Endpoints (server.js)
```javascript
// REST API
POST   /api/rooms/create      → Create room (returns room_id)
GET    /api/rooms/list        → List all active rooms (optional `?game_type=code_breaker|akashic_tcg`)
GET    /api/rooms/:id         → Get room details
POST   /api/rooms/:id/join    → Join as client
POST   /api/rooms/:id/leave   → Leave (with host promotion logic)
POST   /api/rooms/:id/heartbeat → Keep-alive (host only, 30s)
POST   /api/rooms/:id/status  → Update room status (waiting|in_game|finished)
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
- [x] Loading: 60s timeout, returns to room on failure
- [x] Resume routing: `GET /api/rooms/:id` decides Room/Reconnect/Postgame/Landing
- [x] Room status: set `finished` on match end to stop reconnect loops
- [x] Stats Sync: Send on BOTH correct (damage) and wrong (self-damage)
- [x] Periodic Sync: Timer sends stats every 0.5s during gameplay
- [x] Countdown: 3-2-1-TYPE centered with bounce animations, timer paused during countdown
- [x] Visual Effects: Shake animations (damage), particles (success/damage), panel shadows
- [x] Battle Music: Fade in on start (-80dB → -5dB over 2s), stop on leave
- [x] Tutorial System: Award XP via `TutorialManager.complete_tutorial(id, score, max_score)`
- [x] Tutorial XP: 200/150/100/50/0 for A/B/C/D/F grades (70%+ to pass)
- [x] Game Unlocks: Check `TutorialManager.is_game_unlocked("code_breaker")` before showing game

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

**Latest Updates (Dec 11, 2025):**
- ✅ **Post-Game Analytics Scene:** Complete results screen with winner/loser cards, XP awards, match duration
- ✅ **Winner Determination Fix:** Health-based logic ensures only ONE winner per match (no double winners bug)
- ✅ **Firestore XP Integration:** Auto-saves +500 XP for winner, +0 for loser to `users/{uid}/total_xp`
- ✅ **Match History Recording:** Saves detailed match data to `match_history/{match_id}` collection
- ✅ **Back to Landing Button:** Post-game returns to landing hub (not lobby)
- ✅ **Health Bar Initialization:** Explicit min/max/value setup (0-100) prevents display bugs
- ✅ **Stats Sync Timer Fix:** Only starts AFTER countdown completes, prevents premature stats updates
- ✅ **Game Timer Consistency:** Uses `Time.get_ticks_msec() / 1000.0` throughout for accurate duration tracking
- ✅ **Loading Screen Improvements:**
  - Timeout increased: 45s → 60s
  - Retry attempts: 3 → 5
  - Settling delay: 0.5s → 1.5s
  - Verbose logging with timestamps and message delay tracking
- ✅ **Race Condition Mitigation:** Longer settling delays and more retries improve sync reliability
- ✅ **Debug Logging Enhanced:** All relay messages now include timestamps for delay measurement

**Latest Updates (Dec 14, 2025):**
- ✅ **Reconnect/Resume Stability:** Status-aware routing (`waiting|in_game|finished|404`) prevents reconnect loops after match end or room deletion
- ✅ **Loading Sync Reliability:** Self-healing handshake via `loading_status_request` reduces “stuck on loading” deadlocks
- ✅ **Lobby URL Mismatch Hardening:** Resume tries saved lobby URL + current `MultiplayerConfig` URL (localhost ↔ production)
- ✅ **Match Completion State:** Arena posts `finished` to `/api/rooms/:id/status` so late relogs don’t rejoin dead `in_game` sessions

**Latest Updates (Dec 20, 2025):**
- ✅ **Akashic TCG Session Store:** `script/AkashicTCGSessionStore.gd` persisted sessions for resume routing
- ✅ **Akashic Reconnect Scene:** `scene/akashic_tcg_reconnect.tscn` routes back into Loading/Arena
- ✅ **Landing/Login Resume:** `script/landing.gd` + `script/login.gd` now route `waiting|in_game|finished|404` for Akashic too
- ✅ **Round-Based Arena State Sync:** `script/akashic_tcg_arena.gd` host-authoritative `tgc_state_sync` + `tgc_action_request`
- ✅ **Disconnect Recovery:** Room/Loading/Arena route to reconnect on relay disconnect/timeout

**Previous Updates (Dec 8, 2025):**
- ✅ **Tutorial System Overhaul:** Complete XP-based progression system with 9 ranks (Iron to Challenger)
- ✅ **TutorialManager Singleton:** Autoload that tracks completion, XP, ranks, and game unlocks
- ✅ **Tutorial Categories:** Beginner (4 tutorials), Intermediate (2 tutorials), Advanced (2 tutorials)
- ✅ **Grading System:** A/B/C/D/F grades with XP rewards (200/150/100/50/0 XP)
- ✅ **Game Unlock Progression:** Code Breaker unlocks at 500 XP
- ✅ **Phishing Lab:** Interactive 5-email classification challenge with real-world examples
- ✅ **Password Fortress:** Battle-style tutorial teaching password strength
- ✅ **Encryption Basics:** Caesar cipher hands-on lab with ransomware explanation
- ✅ **Firestore Integration:** Persistent tutorial progress, XP, and unlocked games
- ✅ **Mode Selection UI:** Shows rank icon, XP progress bar, and game unlock status
- ✅ **Submit-Based Combat System:** Type in input field + ENTER to submit (not character-by-character)
- ✅ **New Damage Model:** +100 score & -10 enemy HP on correct, -8 self HP on wrong submission
- ✅ **First to 0 HP loses** (not progress-based racing anymore)
- ✅ **Arena Countdown System:** 3-2-1-TYPE centered countdown with bounce animations, timer paused during countdown
- ✅ **Visual Effects Suite:** Health bar shake on damage, screen shake on critical (<30% HP), bounce animations on countdown
- ✅ **Particle Systems:** Success sparkles (15 particles) on correct answer, explosion particles (12-25) on damage
- ✅ **UI Polish:** Panel shadows (8-12px), text outlines on countdown (8px outline + cyan shadow)
- ✅ **Battle Music:** Auto-fade in on arena start (-80dB → -5dB over 2s), stops cleanly on leave
- ✅ **Menu System:** Toggle menu panel with hamburger button
- ✅ **POWER-UP SYSTEM (NEW!):** 5 random power-up types per snippet:
  - 🛡️ **SHIELD** (10%): 15s invincibility, blocks enemy damage + self-damage penalty
  - 🧊 **FREEZE_TIME** (10%): 15s snippet timer freeze (main timer keeps running)
  - 🟡 **EXTEND_TIME** (25%): 20s buff with +15s per snippet, +8s main timer (one-time)
  - 💚 **HEAL** (30%): +10 HP instant on correct answer
  - ⚪ **NORMAL** (25%): No bonus
- ✅ **Power-Up Panel System:** Color-coded panels (grey/ice-blue/yellow/green/white) shown during pop animation
- ✅ **Power-Up Carry-Over:** Shield, Freeze, and Extend buffs persist across multiple snippets
- ✅ **Damage Blocking:** Shield blocks oka enemy attacks AND self-damage penalties during 15s duration


