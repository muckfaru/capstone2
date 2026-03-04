# Copilot Instructions - Capstone 2 Project

## Project Overview
This is a Godot 4.4 educational game project featuring multiple minigames for cybersecurity education.

---

## Defuse the Trojan Minigame

### Core Files
- **Arena Script:** `script/defuse_trojan_arena.gd` - Main game logic
- **Enemy Script:** `script/defuse_trojan_enemy.gd` - Enemy behavior and typing progress
- **Arena Scene:** `scene/defuse_trojan_arena.tscn` - Main game scene
- **Enemy Scenes:** `scene/enemy_virus.tscn`, `enemy_worm.tscn`, `enemy_trojan.tscn`, `enemy_ransomware.tscn`
- **Player Scene:** `scene/defuse_trojan_player.tscn`
- **Projectile:** `scene/projectile.tscn`, `script/projectile.gd`

### Multiplayer (Co-op, 2–3 Players)

#### Multiplayer Flow (UI parity with Code Breaker / Akashic)
- Landing → Defuse Trojan Lobby → Room → Synchronized Loading → Shared Arena → Postgame
- Lobby/room uses the same "room list + room scene + ready gating" pattern as Code Breaker.

#### Core Multiplayer Files
- **Lobby Panel Scene:** `scene/defuse_trojan_lobby.tscn`
- **Lobby Panel Script:** `script/defuse_trojan_lobby.gd`
- **Room Scene:** `scene/defuse_trojan_room.tscn`
- **Room Script:** `script/defuse_trojan_room.gd`
- **Loading Scene (2–3 cards):** `scene/defuse_trojan_loading.tscn`
- **Loading Script:** `script/defuse_trojan_loading.gd`
- **Postgame Scene (inherits Code Breaker design):** `scene/defuse_trojan_postgame.tscn`
- **Postgame Script:** `script/defuse_trojan_postgame.gd`

#### Server / Lobby API Assumptions
- Lobby server `server/server.js` supports `game_type: "defuse_trojan"` and `max_players: 3`.
- Room JSON includes `client2` (3rd slot) and `game_start_time_ms` (scheduled start timestamp).

#### Scene Init Meta Contracts
These are passed via `get_tree().set_meta(...)` before `change_scene_to_file(...)`:
- `defuse_trojan_room_init` (room id, is_host, lobby url)
- `defuse_trojan_loading_init` (room data + relay client + `game_start_time_ms`)
- `defuse_trojan_arena_init` (mode `"multiplayer"`, relay client, room snapshot)
- `defuse_trojan_postgame_init` (results payload + optional relay client)

#### Relay / WebSocket Message Contracts (Arena)
Multiplayer uses a WebSocket relay client (`script/WebSocketRelayClient.gd`).

Host-authoritative rules:
- Host is authoritative for enemy spawn/state and enemy destruction.
- Clients request kills; host validates and broadcasts results.
- All peers render shots/projectiles (including host applying remote shots).

Key message types used by the arena:
- `dt_arena_sync_request` / `dt_arena_sync`: snapshot sync for late join/out-of-sync clients
- `dt_enemy_spawn`: host → clients spawn enemy with stable `enemy_id`
- `dt_enemy_state`: host → clients periodic state (positions + wave/health/scores)
- `dt_kill_request`: client → host request to destroy enemy
- `dt_enemy_destroy`: host → all; enemy destroyed (includes `by` player id, optional `points`)
- `dt_enemy_remove`: host → clients; remove enemy without scoring (cleanup)
- `dt_shot`: any → all; replicate projectile visuals for typing

Match end / postgame sync:
- `dt_match_end`: host → clients; instruct clients to compute local typing stats
- `dt_player_stats`: clients → host; send computed stats payload
- `dt_postgame`: host → all; final results payload to transition everyone to postgame

#### Typing + Score Attribution (Multiplayer)
- Each keypress fires a projectile locally AND sends a `dt_shot` event so other peers can render it.
- Final projectile triggers kill request (`dt_kill_request`) from clients; host calls authoritative destroy.
- Score is tracked per-player (`_scores_by_player`) and displayed from the local player id.

#### Postgame Analytics (Per-Player Cards)
Postgame reuses Code Breaker's visual design via scene inheritance and renders up to 3 player cards.

Per-player card fields (minimal schema):
- Match summary: `mode`, `duration_ms`, `wave_reached`
- Score: `score`
- Typing: `wpm`, `accuracy_pct`, `longest_streak`

### Game Mechanics

#### Typing System
- Player types command words (snippets) to destroy enemies
- Each keystroke fires a projectile; completing the word destroys the enemy
- **Target Switching:** Player can switch targets by typing a different enemy's word
  - If typed text doesn't match current target, system checks if it matches another enemy
  - Priority: closest enemy to player (bottom of screen)
  - Stored progress per enemy - can return to previous target and continue from where left off

#### Key Functions in `defuse_trojan_arena.gd`
- `_process_typing()` - Main typing logic with 4 cases:
  1. Word match (typed_text matches enemy word prefix)
  2. Continue stored progress (typed_text continues enemy's stored progress)
  3. Switch to different enemy (last letter can start/continue another enemy)
  4. Error (no match)
- `_handle_match(enemy, text)` - Handles successful match
- `_switch_to_enemy(enemy, new_typed_text)` - Switches target with correct text
- `_find_matching_enemy(text)` - Finds closest enemy whose word starts with text
- `_find_enemy_with_stored_progress(text)` - Finds enemy with matching stored progress

#### Enemy Progress Storage (`defuse_trojan_enemy.gd`)
- `current_typed_text: String` - Stores player's typing progress on this enemy
- `update_typed_progress(typed)` - Updates and stores progress
- `get_typed_progress()` - Returns stored progress
- Progress persists when player switches to different target

#### Wave System
- Enemies spawn until wave quota reached (`enemies_per_wave + wave`)
- Wave advances ONLY when ALL enemies are destroyed (wave clear required)
- `wave_spawning_complete: bool` - Tracks if all enemies for wave have spawned
- `_advance_to_next_wave()` - Called when all enemies cleared

### Enemy Configuration
- **Base Speed:** 10.0 (adjustable in `defuse_trojan_enemy.gd`)
- **Scale:** 0.2 x 0.2 for all enemy types
- **Types:** virus, worm, trojan, ransomware (each has own scene and SpriteFrames)
- **Shader:** `shader/remove_white_bg.gdshader` - Removes white/black backgrounds from sprites

### Player Configuration
- **Scale:** 0.2 x 0.18 in `defuse_trojan_player.tscn`
- **Rotation:** Player rotates to face target when firing (`_rotate_player_to_target()`)

### UI Elements
- Health bar and HP label (left side)
- Score, Wave, Combo labels (top-right, anchored)
- Typed display (center bottom)

### Assets Location
- Spritesheets: `asset/defuse_trojan/`
- SpriteFrames: `asset/defuse_trojan/*_frames.tres`
- Background: `asset/defuse_trojan/space_background.jpg`

---

## CyberQuiz (Multiple Choice Quiz)

### Core Files
- **Quiz Creation:** `script/QuizCreationPanel.gd`
- **Student Quiz:** `script/StudentQuizScene.gd`
- **Teacher Stats:** `script/TeacherCreateRoom.gd`

### Scoring & Anti-Cheat
- **Authoritative Scoring:** Always calculate quiz scores on the server side (`server/server.js`).
- **Anti-Cheat:** The server `/api/quiz/:code/questions` endpoint **strips** `correct_answer` from the payload sent to students.
- **Client Submission:** Students should only send their `answers` array to the `/submit` endpoint. The server response will contain the calculated score.

### UI & Layout Rules
- **Teacher Statistics:** When displaying the leaderboard or real-time results in the `StatisticsPanel`, ensure the placeholder `StatsGrid` (containing Graph, HighScore, Rankings) is hidden (`stats_grid.visible = false`) to prevent layout overlaps.
- **Scene Tree Paths:** Always verify `@onready` paths against `.tscn` structure. For example, `score_grid` in `StudentQuizScene` is often nested under a `ContentRow` container.

---

## Cybersecurity Fundamentals (Game Mode — Multiplayer)

### Overview
Teacher creates a room → students join via room code → teacher starts → all students launch the same game scene. Uses the **GameMode** server endpoints (separate from CyberQuiz).

### Core Files
- **Teacher Room Creation:** `script/TeacherCreateRoom.gd` — teacher creates room, selects game
- **Room Panel Scene:** `scene/TeacherRoomPanel.tscn` — shared UI for teacher & student room view
- **Room Panel Script:** `script/TeacherLobby.gd` — manages player slots, avatar/rank, polling, dual-mode (teacher/student)
- **Student Waiting Screen:** `script/gamemode_student_waiting.gd` — loads TeacherRoomPanel in student mode
- **Student Waiting Scene:** `scene/gamemode_student_waiting.tscn`
- **Student Join Flow:** `script/mode_selection.gd` → `_try_gamemode_join()` — sends join request with avatar + XP

### Server Endpoints (GameMode)
All endpoints in `server/server.js` under `/api/gamemode/`:
- `POST /api/gamemode/create` — Teacher creates a room (returns `room_code`)
- `GET /api/gamemode/:code/info` — Get room info: players list (with `avatar`, `xp`), status, game_name, game_scene
- `POST /api/gamemode/:code/join` — Student joins room (sends `player_id`, `username`, `avatar`, `xp`)
- `POST /api/gamemode/:code/start` — Teacher starts the game (sets status to `"active"`)
- `POST /api/gamemode/:code/submit` — Student submits score after game ends
- `GET /api/gamemode/:code/results` — Get all player results
- `POST /api/gamemode/:code/heartbeat` — Keep room alive

### Server Player Data Schema
When a player joins via `/join`, the server stores:
```json
{
  "player_id": "string",
  "username": "string",
  "avatar": "avatar1.png",
  "xp": 300,
  "joined_at": 1234567890,
  "finished": false,
  "score": 0,
  "max_score": 0,
  "time_taken_ms": 0
}
```
The `/info` endpoint returns `avatar` + `xp` per player for the room panel to display.

### Server Deployment
- **Platform:** Render.com (free tier, auto-deploy from GitHub `main` branch)
- **URL:** `https://codebreaker-lobby.onrender.com`
- **Root Directory (on Render):** `server/`
- **Build Command:** `npm install`
- **Start Command:** `node server.js`
- **Version Check:** The `/health` endpoint includes `code_version` field to verify which code is deployed. Always confirm this after pushing server changes.
- **IMPORTANT:** Render free tier can be slow to deploy. After `git push`, wait 2–3 minutes and confirm via `/health` → `code_version`. If the field is missing or old, manually trigger deploy from the Render dashboard ("Manual Deploy → Deploy latest commit").

### TeacherRoomPanel (Shared Room UI)

#### Scene Structure (`scene/TeacherRoomPanel.tscn`)
- **TopBar:** RoomNameLabel, RoomCodeLabel, PlayerCountLabel, BackButton
- **SlotGrid:** 10 player slots (Slot1–Slot10), each containing:
  - `VBox` → `AvatarPanel/AvatarTexture` + `NameLabel` + `RankPanel/RankTexture`
- **BottomBar:** ChatInput + StartQuizButton (hidden in student mode)

#### Slot Node Hierarchy
```
SlotX (PanelContainer)
  └─ VBox (VBoxContainer)
      ├─ AvatarPanel (PanelContainer, 56×56)
      │    └─ AvatarTexture (TextureRect, expand_mode=1, stretch_mode=5)
      ├─ NameLabel (Label, 90×auto)
      └─ RankPanel (PanelContainer, 70×24)
           └─ RankTexture (TextureRect, expand_mode=1, stretch_mode=5)
```

#### StyleBox Resources (Sub-resources in .tscn)
- `StyleBoxFlat_slot_empty` — empty slot border (`corner_radius = 8`, dark bg)
- `StyleBoxFlat_avatar_bg` — avatar border (`corner_radius = 4`, square shape)
- `StyleBoxFlat_rank_bg` — rank badge border (`corner_radius = 4`)

#### Runtime Style Overrides (`TeacherLobby.gd`)
The script overrides slot styles at runtime via `_slot_style(filled)` and `_avatar_style(filled)`:
- **`_slot_style(true)`:** Neon cyan border with glow shadow for filled slots
- **`_slot_style(false)`:** Dim border for empty slots
- **`_avatar_style(true)`:** Bright cyan border for filled avatar
- **`_avatar_style(false)`:** Dim border for empty avatar placeholder
- **IMPORTANT:** Both functions use `corner_radius = 4` for avatar (square) and `corner_radius = 8` for slot. If you change the shape in .tscn but not in the script's style helpers, the script will override it at runtime.

### TeacherLobby.gd — Dual-Mode Script

#### Teacher Mode
- Called via `show_lobby(room_code, room_name, minigame, difficulty, player_count)`
- Shows Start button, chat input
- Polls via `start_gamemode_polling()` → `_poll_gamemode_players()`
- Start button → emits `quiz_started` signal

#### Student Mode
- Called via `show_lobby_student_mode(room_code, game_name, game_scene, lobby_url, player_count)`
- Hides Start button and chat input
- Shows "⏳ Waiting for teacher to start the game..." with animated dots
- Polls via `start_gamemode_polling_student()` → `_poll_gamemode_student()`
- When server status changes to `"active"`, emits `game_started(data)` signal

#### Key Signals
- `quiz_started(room_code)` — Teacher pressed Start
- `lobby_closed` — Back button pressed
- `game_started(data)` — Student mode: teacher started the game (data = full server response dict)

#### Player Data Flow
1. Student joins → `mode_selection.gd` → `_try_gamemode_join()` sends `{ player_id, username, avatar, xp }`
2. Server stores player with avatar + xp
3. Lobby polls `/api/gamemode/:code/info` every 3 seconds
4. `_sync_players_from_server()` processes server response:
   - Extracts `avatar` (filename) and `xp` (int) per player
   - Calls `_load_avatar_texture(avatar_file)` → returns `Texture2D`
   - Calls `_load_rank_texture_from_xp(xp)` → returns rank icon `Texture2D`
   - Calls `add_player(name, avatar_tex, rank_tex)`
5. `_refresh_all_slots()` assigns textures to `AvatarTexture` and `RankTexture` nodes

#### Avatar Loading (`_load_avatar_texture`)
Handles three path formats:
- **Plain filename** (e.g., `"avatar3.png"`) → loads from `res://asset/avatars/avatar3.png`
- **`res://` path** → loads directly
- **`user://` path** (custom avatar) → loads with `Image.load_from_file()`, resizes to 80×80
- Returns `null` for `"default.png"` or empty string

#### Rank Loading (`_load_rank_texture_from_xp`)
- Uses `TutorialManager.get_rank(xp)` to get rank dict with `"icon"` path
- Falls back to `res://asset/rankicon/IRON.png` if lookup fails

### Avatar & Rank Assets
- **Avatar files:** `res://asset/avatars/avatar1.png` through `avatar18.png` (17 files, no avatar13)
- **Auth singleton:** `Auth.current_avatar` stores the avatar filename (e.g., `"avatar1.png"` or `"user://custom_avatar_xxx.png"`)
- **Rank icon files:** `res://asset/rankicon/IRON.png`, `BRONZE.png`, `SILVER.png`, `GOLD.png`, `PLATINUM.png`, `DIAMOND.png`, `MASTER.png`, `GRAND MASTER.png`, `CHALLENGER.png`
- **TutorialManager.RANK_THRESHOLDS:** Iron 0–199 XP, Bronze 200–399, Silver 400–699, Gold 700–1099, Platinum 1100–1599, Diamond 1600–2299, Master 2300–3199, Grandmaster 3200–4499, Challenger 4500+
- **XP source:** `TutorialManager.total_xp` (not `Auth.current_level` — that is a separate Firestore field)

### Student Waiting Flow (`gamemode_student_waiting.gd`)
1. Reads meta keys from `get_tree()`: `gamemode_room_code`, `gamemode_lobby_url`, `gamemode_game_name`, `gamemode_game_scene`
2. Instantiates `TeacherRoomPanel.tscn` and calls `show_lobby_student_mode()`
3. Connects `game_started` signal → sets meta + launches game scene
4. Connects `lobby_closed` signal → returns to landing

#### Scene Init Meta Contracts (GameMode Student)
Set by `mode_selection.gd` → `_try_gamemode_join()` before `change_scene_to_file(gamemode_student_waiting.tscn)`:
- `gamemode_room_code` — room code string (e.g., `"ABC123"`)
- `gamemode_lobby_url` — server base URL (e.g., `"https://codebreaker-lobby.onrender.com"`)
- `gamemode_game_name` — display name (e.g., `"Cybersecurity Fundamentals"`)
- `gamemode_game_scene` — scene path (e.g., `"res://scene/tutorial_cyber_fundamentals.tscn"`)

### GameMode Testing Checklist
- [ ] Teacher creates room and sees room code + player slots
- [ ] Student joins with room code and sees same TeacherRoomPanel (no Start button)
- [ ] Student avatar loads correctly in room panel (square border, correct image)
- [ ] Student rank icon shows correctly based on XP
- [ ] Player list updates in real-time (3s polling) for both teacher and student
- [ ] "Waiting for teacher to start..." message animates dots
- [ ] Teacher clicks Start → all students detect status change and launch game scene
- [ ] Server `/health` shows `code_version` field matching latest push
- [ ] Students can submit score/time to server when game completes
- [ ] Teacher leaderboard shows correct columns per game type

### GameMode-Supported Games

All three games detect GameMode via `get_tree().has_meta("gamemode_room_code")` and read meta:
- `gamemode_room_code` — room code
- `gamemode_lobby_url` — server base URL
- `gamemode_start_time_ms` — `Time.get_ticks_msec()` at game launch (set by `gamemode_student_waiting.gd`)

In GameMode:
- Close/quit buttons are hidden or blocked
- Back button on first section/phase returns nothing (cannot quit)
- On game completion, score + time are POSTed to `/api/gamemode/:code/submit`
- After submission, student returns to `landing.tscn`

#### 1. Cybersecurity Fundamentals
- **Script:** `script/tutorial_cyber_fundamentals.gd`
- **Sections:** INTRO → CIA_TRIAD → THREAT_MODEL → COMPLETE
- **Score submission:** `score = xp_earned (100)`, `max_score = 100`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** On COMPLETE, submits score → redirects to student leaderboard (skips CIA Triad tutorial transition)

#### 2. Network Basics (Tutorial + Defense Game)
- **Tutorial Script:** `script/tutorial_network_basics.gd`
- **Defense Game Script:** `script/network_defense_game.gd`
- **Flow:** Tutorial (INTRO→IP→PORT→PROTOCOL→COMPLETE) → Defense Game (4 phases + victory/game over)
- **Score submission:** Defense game submits `score` (accumulated points) with `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Tutorial passes meta to defense game. Defense game hides quit button, disables retry, shows "SUBMIT & FINISH" on both victory and game over → redirects to student leaderboard.

#### 3. Encryption (Caesar Cipher)
- **Script:** `script/tutorial_encryption_basics.gd`
- **Phases:** INTRO → LEARN_WHEEL → PRACTICE_MODE → CHALLENGE_MODE → RANSOMWARE_EXPLANATION → COMPLETE
- **Score submission:** `score = 0`, `max_score = 0` (time-only game)
- **Leaderboard:** Time column only (Score column hidden)
- **GameMode behavior:** On COMPLETE, submits time → redirects to student leaderboard. Both teacher and student leaderboard detect "Encryption" in game name and hide Score column.

#### 4. Password Fortress Defender
- **Script:** `script/tutorial_password_basics.gd`
- **GameState enum:** BRIEFING → PASSWORD_BUILD → BATTLE → VICTORY → DEFEAT
- **Score submission:** `score = player_score`, `max_score = 200`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides CloseButton, blocks back on wave 0, blocks confirm-quit. On final wave completion submits score → redirects to student leaderboard.

#### 5. Malware Types Overview
- **Script:** `script/tutorial_malware_types.gd`
- **Phases:** Timed (90s), 6 incident reports to classify
- **Score submission:** `score = final_score (0-100)`, `max_score = 100`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides CloseButton, blocks back/confirm-quit. On time expired, submits partial score. On FINISH, submits computed score → redirects to student leaderboard.

#### 6. Drop Zone Defender
- **Script:** `script/datavsnetworkgmmanager.gd`
- **Phases:** Tutorial → 8 waves of drag-and-drop attack classification
- **Score submission:** `score = score (accumulated)`, `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides Quit button, blocks ESC. On victory, submits score → leaderboard. On game over (system critical), submits partial score → leaderboard (no retry).

#### 7. Phishing Detection Lab (Two-Part Chain)
- **Intro Script:** `scene/phishing_intro.gd` — Splash page chains to lab
- **Lab Script:** `script/tutorial_phishing_lab.gd` — Gmail-style email analysis
- **Phases:** 8 emails to analyze (90s timer), actions: Reply/Spam/Delete
- **Score submission:** `score = score`, `max_score = 1200` (8 emails × 150 max)
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Intro hides BackButton. Lab hides BackButton. On final results OK → submits score → leaderboard. On time expired → shows results → OK → submits → leaderboard.

#### 8. Asset vs Threats
- **Script:** `script/GameManager.gd`
- **Phases:** Wave-based (5 waves), click-to-defend threats on assets
- **Score submission:** `score = score (accumulated)`, `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides Quit button, blocks ESC. On victory (`win_game()`), submits score → leaderboard. On game over (`show_game_over()`), submits partial score → leaderboard (no restart).

#### 9. Crypt Contract
- **Script:** `script/PhoneEncryption.gd`
- **Phases:** Mission-based (5 missions), create encryption keys to protect phone data
- **Score submission:** `score = score (accumulated)`, `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides Quitbtn. On victory (`victory()`), submits score → leaderboard (skips victory panel). On game over (`game_over()`), submits partial score → leaderboard (skips retry). VictoryPanel QuitButton also submits in GameMode.

#### 10. Incident Commander
- **Script:** `script/SOCMain.gd`
- **Phases:** Wave-based (10 waves), SOC command-line defense
- **Score submission:** `score = score (accumulated)`, `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides Quit button, blocks ESC, blocks keyboard shortcuts (R/SPACE/ENTER) from restarting. On victory, submits score → leaderboard. On game over (debrief), submits partial score → leaderboard (no restart). `_on_victory_exit()` and `_on_debrief_restart()` both redirect to submit in GameMode.

#### 11. Security Guardian
- **Script:** `script/authgmMain.gd`
- **Phases:** Scenario-based (10 waves), approve/deny authentication requests
- **Score submission:** `score = correct_decisions * 10 + attacks_blocked * 5`, `max_score = 500`
- **Leaderboard:** Score + Time columns
- **GameMode behavior:** Hides ExitButton, blocks ESC, blocks replay. On victory (`_show_debrief()`), submits score → leaderboard (skips debrief panel). On game over (`_show_game_over()`), submits partial score → leaderboard (skips debrief panel). `_on_continue_pressed()` also submits in GameMode.

### Student Leaderboard
- **Scene:** `scene/gamemode_leaderboard.tscn`
- **Script:** `script/gamemode_leaderboard.gd`
- **Meta keys:** `gamemode_leaderboard_room_code`, `gamemode_leaderboard_lobby_url` (set by game scripts before transition)
- **Polling:** Every 5 seconds via `GET /api/gamemode/:code/results`
- **Features:** Highlights current player with "(You)" suffix and cyan row background. Shows time-only layout for Encryption.
- **Flow:** All 11 games → submit score → set leaderboard meta → change scene to `gamemode_leaderboard.tscn` → student views live leaderboard → "Back to Landing" button

### Teacher Leaderboard Customization
- `_update_gamemode_leaderboard()` in `TeacherCreateRoom.gd` checks if game name contains "encryption"
- If true: shows only `#`, `Player`, `Time` columns. "playing..." shown in Time column for unfinished players.
- If false: shows `#`, `Player`, `Score`, `Time` columns (default behavior)

---

## Development Notes

### Common Patterns
- Enemy scenes use `AnimatedSprite2D` with `SpriteFrames` resources
- UI nodes dynamically created in enemy script (WordLabel, TypedProgress, TargetIndicator)
- Shader applied via `ShaderMaterial` on sprites

### Testing Checklist
- [ ] Target switching works (type different enemy's word)
- [ ] Stored progress persists when switching
- [ ] Returning to previous target continues from stored progress
- [ ] Wave clear required before advancing
- [ ] Priority targeting (closest enemy first)
- [ ] Player rotates when shooting

### Multiplayer Testing Checklist
- [ ] Room supports 2–3 players (Host + Client + Client2)
- [ ] Ready gating works: host can start only when all present clients are ready
- [ ] Loading screen starts simultaneously (via `game_start_time_ms` or relay fallback)
- [ ] Host sees client projectiles and clients see each other's projectiles
- [ ] Wave UI/notifications update consistently from host state sync
- [ ] Clients can request kills; host broadcasts destroy; scores attribute to the correct player
- [ ] Postgame triggers for all peers and shows consistent cards (score/WPM/accuracy/streak)

### Stability / Type-Safety Gotchas (Godot 4.4)
- Relay/state dictionaries can contain stale references. Never assume a Node pulled from a dictionary is valid.
  - Always guard with `is_instance_valid(node)` before use.
  - When invalid, `erase(id)` from mappings like `_enemies_by_id` and request resync.
- Avoid typed assignments directly from dictionary lookups (can throw "invalid previously freed instance").
  - Prefer `var any = dict.get(key, null)` then validate/cast: `var n := any as Node2D`.
- Some project settings treat warnings as errors; explicitly type values when inference fails.
  - Example: `var cached_bg: String = str(Auth.get_remote_card_bg(pid))`.

### UI Style Gotchas
- **Runtime style overrides:** `TeacherLobby.gd` creates `StyleBoxFlat` at runtime via `_slot_style()` and `_avatar_style()`. Changing corner_radius or colors in the `.tscn` alone won't work — the script overrides them on every `_refresh_all_slots()` call. Always update BOTH the `.tscn` sub-resources AND the script's style helper functions.
- **Avatar shape:** Avatar slots use `corner_radius = 4` (square with slight rounding). This is set in both `StyleBoxFlat_avatar_bg` in the `.tscn` AND `_avatar_style()` in `TeacherLobby.gd`.

### Render Deployment Notes
- Server code is in `server/server.js` — single file Node.js/Express app
- After pushing to `main`, Render auto-deploys but can take 2–5 minutes on free tier
- Always verify deployment via `GET /health` → check `code_version` field
- If `code_version` is missing or stale: go to Render dashboard → Manual Deploy → Deploy latest commit
- The server uses in-memory Maps (`gameModeRooms`, `quizRooms`, `rooms`) — all data is lost on restart/redeploy
