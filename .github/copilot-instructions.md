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
