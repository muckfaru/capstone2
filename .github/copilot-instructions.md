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
- Lobby/room uses the same “room list + room scene + ready gating” pattern as Code Breaker.

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
Postgame reuses Code Breaker’s visual design via scene inheritance and renders up to 3 player cards.

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
- [ ] Host sees client projectiles and clients see each other’s projectiles
- [ ] Wave UI/notifications update consistently from host state sync
- [ ] Clients can request kills; host broadcasts destroy; scores attribute to the correct player
- [ ] Postgame triggers for all peers and shows consistent cards (score/WPM/accuracy/streak)

### Stability / Type-Safety Gotchas (Godot 4.4)
- Relay/state dictionaries can contain stale references. Never assume a Node pulled from a dictionary is valid.
  - Always guard with `is_instance_valid(node)` before use.
  - When invalid, `erase(id)` from mappings like `_enemies_by_id` and request resync.
- Avoid typed assignments directly from dictionary lookups (can throw “invalid previously freed instance”).
  - Prefer `var any = dict.get(key, null)` then validate/cast: `var n := any as Node2D`.
- Some project settings treat warnings as errors; explicitly type values when inference fails.
  - Example: `var cached_bg: String = str(Auth.get_remote_card_bg(pid))`.
