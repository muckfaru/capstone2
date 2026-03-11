# CyberArena — Complete Game Flow Document

**End-to-end user journey from launch to completion**

---

## Table of Contents

1. [High-Level Flow Diagram](#1-high-level-flow-diagram)
2. [Authentication Flow](#2-authentication-flow)
3. [New User Journey (Story Mode)](#3-new-user-journey-story-mode)
4. [Returning User Journey](#4-returning-user-journey)
5. [Landing Page Navigation](#5-landing-page-navigation)
6. [Tutorial Game Flow](#6-tutorial-game-flow)
7. [Multiplayer Game Flows](#7-multiplayer-game-flows)
8. [Teacher / Classroom Flow](#8-teacher--classroom-flow)
9. [Student Quiz Flow](#9-student-quiz-flow)
10. [Progression & Unlock Flow](#10-progression--unlock-flow)
11. [Economy & Shop Flow](#11-economy--shop-flow)
12. [Scene-by-Scene Map](#12-scene-by-scene-map)
13. [Technical Contracts & Meta Keys](#13-technical-contracts--meta-keys)

---

## 1. High-Level Flow Diagram

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                        CYBERARENA FLOW                           │
  └──────────────────────────────────────────────────────────────────┘

  ┌──────────┐     ┌──────────┐     ┌────────────────────────┐
  │  Login   │────→│  Signup  │────→│  Email Verification    │
  │ login.gd │←────│signup.gd │     │ email_verification.gd  │
  └────┬─────┘     └──────────┘     └────────────────────────┘
       │
       ├── New User ──→ 3D Story Mode ──→ CA Recruitment ──→ Landing
       │
       └── Returning ──→ Landing Page (direct)
                              │
           ┌──────────────────┼──────────────────────────┐
           │                  │                          │
           ▼                  ▼                          ▼
     ┌───────────┐   ┌──────────────┐          ┌──────────────┐
     │ Tutorial   │   │ Multiplayer  │          │   Teacher    │
     │  Mode      │   │   Games      │          │  Dashboard   │
     │(13 games)  │   │(3 PvP games) │          │(Room/Quiz)   │
     └─────┬──────┘   └──────┬───────┘          └──────┬───────┘
           │                 │                         │
           ▼                 ▼                         ▼
     ┌───────────┐   ┌──────────────┐          ┌──────────────┐
     │ XP Award  │   │  Postgame    │          │  Leaderboard │
     │ Rank Up   │   │  Results     │          │  (Students)  │
     └───────────┘   └──────────────┘          └──────────────┘
           │                 │                         │
           └─────────────────┴─────────────────────────┘
                              │
                              ▼
                     ┌──────────────┐
                     │  Landing     │
                     │  (Return)    │
                     └──────────────┘
```

---

## 2. Authentication Flow

### Login Flow

```
login.tscn (login.gd)
    │
    ├── Email/Password Login
    │     ├── Validate email format
    │     ├── Firebase Auth REST API call
    │     ├── On success → check Firestore for user record
    │     │     ├── User exists → check for active Code Breaker / Akashic session
    │     │     │     ├── Active session → offer Resume
    │     │     │     └── No session → landing.tscn
    │     │     └── User does not exist → story intro
    │     └── On failure → show error message
    │
    └── Google OAuth Login
          ├── Launch OAuth code exchange
          ├── Get Google tokens
          ├── Firebase signInWithIdp
          ├── Check Firestore for user record
          └── Same routing as email login
```

### Signup Flow

```
signup.tscn (signup.gd)
    │
    ├── Email/Password Registration
    │     ├── Validate email (regex)
    │     ├── Validate password (6+ chars)
    │     ├── Firebase Auth REST API call
    │     ├── Create Firestore user document
    │     └── Route to story intro
    │
    └── Google OAuth Registration
          ├── Same OAuth flow as login
          ├── Check if user is new
          └── Create Firestore document → story intro
```

---

## 3. New User Journey (Story Mode)

```
signup.gd / login.gd (new user detected)
    │
    ▼
story_cutscene.gd (Visual Novel)
    │  5 panels: "Want CyberRun 2026" → "Can't afford ₱1,000"
    │  → "Search for free download" → click/space to advance
    │
    ▼
Main.tscn (Main.gd) — 3D Apartment Scene
    │  player.gd: WASD movement, mouse look, E to interact
    │  story_manager.gd: Shows exploration tips → intro monologue
    │  Player approaches computer desk → press E
    │
    ▼
computer_desktop.tscn (computer_desktop.gd) — Desktop Simulation
    │  Windows-style OS: Browser, Messages, Files
    │  Player downloads "SuperGame_Setup.exe"
    │
    ├── spawn_malware_popups() — Popup windows flood screen
    ├── show_infection_result() — System shows infection message
    ├── show_shutdown_animation() — Fake shutdown/crash
    │
    ▼
Main.tscn (returns) — Post-Infection Sequence
    │  GlobalState.returning_from_computer = true
    │  GlobalState.computer_infected = true
    │
    ├── _start_post_infection_sequence() [via call_deferred]
    ├── add_fade_in() — Screen fades in
    ├── start_panic_sequence() — Dialogue: "I've been hacked!"
    │
    ├── dialogue_manager.gd shows dialogue
    ├── trigger_hologram_call() — "Anonymouse" hologram appears
    │
    ├── CHOICE: "Accept CyberArena invitation?"
    │     │
    │     ├── YES → GlobalState.joined_ca_organization = true
    │     │         → intro_cybersecurity.tscn (CA training)
    │     │         → intro_cybersecurity.gd: Learn 5 domains
    │     │         → landing.tscn
    │     │
    │     └── NO → landing.tscn (normal progression)
    │
    ▼
landing.tscn — Player Hub
```

---

## 4. Returning User Journey

```
login.gd (existing user detected)
    │
    ├── Check for active Code Breaker session
    │     └── If found → offer "Resume Match" button on landing
    │
    ├── Check for active Akashic TCG session
    │     └── If found → offer "Resume Match" button on landing
    │
    └── Route to landing.tscn
         │
         ▼
    landing.tscn (landing.gd)
         │
         ├── Load profile (avatar, XP, rank, win/loss)
         ├── Load tutorial completion status
         ├── Load cosmetic equipment
         ├── Determine unlocked games
         └── Display full hub UI
```

---

## 5. Landing Page Navigation

```
landing.tscn (landing.gd)
    │
    ├── [Profile Panel] — View/edit avatar, see XP, rank, stats
    │
    ├── [Tutorial Mode] → mode_selection.tscn (mode_selection.gd)
    │     ├── Beginner → tutorial list
    │     ├── Intermediate → tutorial list
    │     └── Advanced → tutorial list
    │     Each button → launches corresponding tutorial scene
    │
    ├── [Defuse the Trojan] → defuse_trojan_lobby.tscn
    │
    ├── [Code Breaker] → code_breaker_lobby.tscn
    │
    ├── [Akashic TCG] → akashic_tcg_lobby.tscn
    │
    ├── [Join Room] → JoinRoomPopup
    │     ├── Enter room code
    │     ├── Check quiz or gamemode room type
    │     ├── If restricted → show student number field
    │     └── Join → waiting screen (student mode)
    │
    ├── [Chat] → chat.tscn
    │
    ├── [Friends] → friend_list.tscn
    │
    ├── [Shop] → shop_panel.tscn
    │
    ├── [Inventory] → inventory_panel.tscn
    │
    ├── [Leaderboards] → per-game ranking view
    │
    └── [Settings] → SettingsPanel.tscn
```

---

## 6. Tutorial Game Flow

### Generic Tutorial Pattern

All tutorials follow the same lifecycle:

```
mode_selection.gd → selects game
    │
    ▼
Tutorial Scene (tutorial_*.tscn)
    │
    ├── _ready() — Initialize UI, detect GameMode
    │     ├── Check get_tree().has_meta("gamemode_room_code")
    │     │     ├── YES → GameMode (hide quit buttons, prepare server submit)
    │     │     └── NO → Solo Mode (normal tutorial)
    │     └── Load lesson content
    │
    ├── PHASE 1: Introduction / Briefing
    │     └── Read content, click Next / type "next"
    │
    ├── PHASE 2: Learning / Interactive Demo
    │     └── Animations, drag-and-drop, or visual demonstrations
    │
    ├── PHASE 3: Practice / Challenge
    │     └── Player performs tasks (typing, clicking, dragging)
    │
    ├── PHASE 4: Quiz / Assessment
    │     └── Answer questions, timed challenges
    │
    ├── COMPLETE
    │     ├── Calculate final score
    │     ├── Solo: TutorialManager.save_tutorial_result(score)
    │     │     ├── Compute XP (0–200 based on %)
    │     │     ├── Save to Firestore
    │     │     ├── Check rank up
    │     │     └── Award CyberCoins
    │     │
    │     └── GameMode: POST /api/gamemode/:code/submit
    │           ├── Send { score, max_score, time_taken_ms }
    │           ├── Set leaderboard meta keys
    │           └── Change scene to gamemode_leaderboard.tscn
    │
    └── Return to landing.tscn (solo) or leaderboard (GameMode)
```

### Per-Game Phase Details

**Cybersecurity Fundamentals:** INTRO → CIA_TRIAD → THREAT_MODEL → COMPLETE  
**Network Basics:** INTRO → IP_LESSON → PORT_LESSON → PROTOCOL_LESSON → COMPLETE  
**Drop Zone Defender:** TUTORIAL → 8 WAVES (drag-drop) → VICTORY/DEFEAT  
**Threat Identification Lab:** 90-second timed lab → 6 incident reports → SCORE  
**Asset vs Threats:** 5 WAVES → click-defend → VICTORY/DEFEAT  
**Encryption Basics:** INTRO → LEARN_WHEEL → PRACTICE_MODE → CHALLENGE_MODE → RANSOMWARE → COMPLETE  
**Crypt Contract:** 5 MISSIONS × 3 MESSAGES → VICTORY/DEFEAT  
**Phishing Detection Lab:** 90-second timed → 8 EMAILS → RESULTS  
**Incident Commander:** 10 WAVES → type commands → VICTORY/DEFEAT  
**Crypto Sorter:** Progressive WAVES → sort algorithms → SCORE  
**RSA Key Lab:** RSA_LEARN → RSA_PRACTICE → DH_LEARN → DH_PRACTICE → QUIZ  
**Password Fortress:** BRIEFING → PASSWORD_BUILD → BATTLE (5 waves) → VICTORY/DEFEAT  
**Security Guardian:** INTRO → PLAYING (10 waves) → DEBRIEF  

---

## 7. Multiplayer Game Flows

### Defuse the Trojan (2–3 Players)

```
Landing → defuse_trojan_lobby.tscn (defuse_trojan_lobby.gd)
    │     Room list + Create Room button
    │
    ├── Create Room → POST to server
    └── Join Room → Enter existing room
         │
         ▼
defuse_trojan_room.tscn (defuse_trojan_room.gd)
    │  2–3 player cards, Ready button (client), Start button (host)
    │  Meta: defuse_trojan_room_init
    │
    ├── All clients Ready → Host clicks START
    │
    ▼
defuse_trojan_loading.tscn (defuse_trojan_loading.gd)
    │  Synchronized loading with progress bars
    │  Meta: defuse_trojan_loading_init (includes game_start_time_ms)
    │  Countdown: 3... 2... 1...
    │
    ▼
defuse_trojan_arena.tscn (defuse_trojan_arena.gd)
    │  Meta: defuse_trojan_arena_init (mode "multiplayer", relay client, room snapshot)
    │
    │  HOST:
    │  ├── Spawns enemies (dt_enemy_spawn) → broadcasts to clients
    │  ├── Periodic state sync (dt_enemy_state)
    │  ├── Validates kill requests (dt_kill_request → dt_enemy_destroy)
    │  └── Sends dt_match_end when game ends
    │
    │  CLIENTS:
    │  ├── Receive enemy spawns and render
    │  ├── Type keywords → fire projectiles (dt_shot → all peers)
    │  ├── Send kill requests on word completion
    │  └── Receive destroy confirmations
    │
    │  ALL PLAYERS:
    │  ├── Type keywords to destroy enemies
    │  ├── Can switch targets mid-word
    │  ├── Progress stored per enemy
    │  └── Scores tracked per player (_scores_by_player)
    │
    ▼
Match End:
    │  Host sends dt_match_end
    │  Clients compute local typing stats
    │  Clients send dt_player_stats
    │  Host compiles and sends dt_postgame
    │
    ▼
defuse_trojan_postgame.tscn (defuse_trojan_postgame.gd)
    │  Meta: defuse_trojan_postgame_init
    │  Up to 3 player cards:
    │    - mode, duration_ms, wave_reached
    │    - score, wpm, accuracy_pct, longest_streak
    │
    └── Return to Lobby or Landing
```

### Code Breaker (1v1)

```
Landing → code_breaker_lobby.tscn (code_breaker_lobby.gd)
    │     Room list + Create Room button
    │
    ├── Create Room → POST to relay server
    └── Join Room
         │
         ▼
code_breaker_room.tscn (code_breaker_room.gd)
    │  2 player cards (Host left, Client right)
    │  Client clicks READY → Host clicks START
    │
    ▼
code_breaker_loading.tscn (code_breaker_loading.gd)
    │  Synchronized countdown
    │
    ▼
code_breaker_arena.tscn (code_breaker_arena.gd)
    │
    │  GAMEPLAY (3–4 minute match):
    │  ├── Both players see code snippet
    │  ├── Type characters exactly (case-sensitive)
    │  ├── Correct char: +3 score, -2 opponent HP
    │  ├── Wrong char: -3 score, restart line
    │  ├── Snippet timer: 15s per code block
    │  ├── Power-ups drop: Heal, Freeze, Extend, Shield
    │  └── Session saved to Firestore (resume on disconnect)
    │
    │  WIN CONDITION:
    │  ├── Opponent HP reaches 0
    │  ├── Finish typing code first
    │  └── Time expires → higher score/HP wins
    │
    ▼
code_breaker_postgame.tscn (code_breaker_postgame.gd)
    │  Results: score, accuracy, damage dealt/taken, fastest snippet
    │
    └── Return to Room (rematch) or Lobby
```

### Akashic TCG (1v1)

```
Landing → akashic_tcg_lobby.tscn (akashic_tcg_lobby.gd)
    │     Room list + Create Room button
    │
    ├── Create Room
    └── Join Room
         │
         ▼
akashic_tcg_room.tscn (akashic_tcg_room.gd)
    │  2 player cards, Ready/Start flow
    │
    ▼
akashic_tcg_loading.tscn (akashic_tcg_loading.gd)
    │  Synchronized countdown
    │
    ▼
akashic_tcg_arena.tscn (akashic_tcg_arena.gd)
    │
    │  GAMEPLAY (turn-based):
    │  ├── Draw cards from deck
    │  ├── Play cards using resources (limited per turn)
    │  ├── Attack opponent's System Integrity or Firewall
    │  ├── 30-second turn timer (auto-pass)
    │  └── Session can be saved/resumed
    │
    ▼
akashic_tcg_postgame.tscn (akashic_tcg_postgame.gd)
    │  Results
    │
    └── Return to Lobby
```

---

## 8. Teacher / Classroom Flow

### Game Mode Flow (Teacher Creates, Students Play)

```
TEACHER SIDE:
═════════════
TeacherCreateRoom.tscn (TeacherCreateRoom.gd)
    │
    ├── Select "Game Mode"
    ├── Choose minigame from catalog
    ├── Set player count (1–50)
    ├── (Optional) Enable student number whitelist
    │     └── Enter comma-separated student numbers
    ├── Click Create → POST /api/gamemode/create
    │     └── Returns room_code (e.g., "ABC123")
    │
    ▼
TeacherRoomPanel.tscn (TeacherLobby.gd) — Teacher Mode
    │  Displays: Room name, room code, player count
    │  10 player slots with avatar + rank textures
    │  Polls /api/gamemode/:code/info every 3s
    │  Shows: [+ Student] button, Chat, [Start] button
    │
    ├── Students join → slots fill with avatar + rank
    ├── (Optional) Add more students via [+ Student] popup
    │
    ├── Click [Start] → POST /api/gamemode/:code/start
    │     └── Sets server status to "active"
    │
    ▼
Teacher waits → Students play → Teacher views leaderboard


STUDENT SIDE:
═════════════
landing.tscn → [Join Room] → JoinRoomPopup.gd
    │
    ├── Enter room code
    ├── GET /api/gamemode/:code/info → check has_student_restriction
    │     ├── YES → show student number field → enter number
    │     └── NO → proceed directly
    ├── POST /api/gamemode/:code/join
    │     └── { player_id, username, avatar, xp, student_number }
    │
    ▼
gamemode_student_waiting.tscn (gamemode_student_waiting.gd)
    │  Loads TeacherRoomPanel in student mode
    │  Meta keys: gamemode_room_code, gamemode_lobby_url,
    │             gamemode_game_name, gamemode_game_scene
    │  Polls server for status change
    │  Shows "⏳ Waiting for teacher to start..."
    │
    ├── Server status changes to "active"
    │
    ▼
Game Scene (whichever minigame teacher selected)
    │  get_tree().has_meta("gamemode_room_code") = true
    │  Quit buttons hidden
    │  Back button disabled
    │
    ├── Player completes game
    ├── POST /api/gamemode/:code/submit
    │     └── { player_id, score, max_score, time_taken_ms }
    │
    ▼
gamemode_leaderboard.tscn (gamemode_leaderboard.gd)
    │  Meta: gamemode_leaderboard_room_code, gamemode_leaderboard_lobby_url
    │  Polls GET /api/gamemode/:code/results every 5s
    │  Highlights current player with "(You)" and cyan row
    │  Back to Landing button
    │
    └── landing.tscn
```

---

## 9. Student Quiz Flow

### Multiple Choice Quiz

```
TEACHER SIDE:
═════════════
TeacherCreateRoom.tscn → Select "Multiple Choice"
    │
    ├── quiz_creation_panel.tscn (QuizCreationPanel.gd)
    │     ├── Create questions (text + 4 choices + correct answer)
    │     ├── Set time per question, total questions
    │     ├── (Optional) Student number whitelist
    │     └── POST /api/quiz/create → returns room code
    │
    ▼
TeacherRoomPanel.tscn (TeacherLobby.gd) — Teacher Mode
    │  Same lobby UI as Game Mode
    │  Students join with room code
    │  Teacher clicks [Start Quiz]
    │
    ▼
Teacher sees live results / statistics panel


STUDENT SIDE:
═════════════
landing.tscn → [Join Room] → Enter quiz room code
    │
    ├── POST /api/quiz/:code/join
    │
    ▼
StudentQuizScene.tscn (StudentQuizScene.gd)
    │
    ├── WAITING SCREEN
    │     ├── Polls /api/quiz/:code/info for status="active"
    │     ├── BackButton visible (can leave during wait)
    │     └── Timer starts when teacher clicks Start
    │
    ├── GRID SCREEN (after start)
    │     ├── All questions shown as numbered buttons
    │     ├── Color-coded: answered (green) / unanswered (gray)
    │     └── Click any button to jump to question
    │
    ├── QUESTION SCREEN
    │     ├── Question text + 4 answer buttons
    │     ├── Per-question timer (auto-advance on expire)
    │     ├── Quiz-wide timer (overall limit)
    │     ├── Select answer → button highlights
    │     └── Navigate: Next / Previous / Grid
    │
    ├── SUBMIT
    │     ├── POST /api/quiz/:code/submit
    │     │     └── { player_id, answers: [...] }
    │     ├── Server strips correct_answer (anti-cheat)
    │     └── Server calculates and returns score
    │
    ├── SCORE SCREEN
    │     ├── Shows total score, per-question breakdown
    │     ├── Correct/wrong indicators
    │     └── Back to landing button
    │
    └── landing.tscn
```

---

## 10. Progression & Unlock Flow

```
Player completes tutorial
    │
    ▼
TutorialManager.save_tutorial_result(game_id, score, max_score)
    │
    ├── Calculate percentage: score / max_score × 100
    │
    ├── Calculate XP:
    │     ├── 90%+ → 200 XP
    │     ├── 80%+ → 150 XP
    │     ├── 70%+ → 100 XP
    │     ├── 50%+ → 50 XP
    │     └── <50% → 0 XP
    │
    ├── Add to total_xp
    │
    ├── Check rank up:
    │     ├── Old rank = get_rank(old_xp)
    │     ├── New rank = get_rank(new_xp)
    │     ├── If different → emit rank_up signal
    │     │     └── rank_up_notification.tscn shown
    │     └── Save rank to Firestore
    │
    ├── Check game unlocks:
    │     ├── Tutorial completion flags stored
    │     ├── Next game in prerequisite chain unlocked
    │     └── Emit game_unlocked signal (if newly unlocked)
    │
    ├── Award CyberCoins:
    │     └── CyberCoinManager.award(amount)
    │
    └── Save all to Firestore

Prerequisite Chain:
═══════════════════
Cybersecurity Fundamentals (always unlocked)
    → Network Basics
        → Drop Zone Defender
            → Threat Identification Lab
                → Asset vs Threats
                    → Encryption Basics
                        → Crypt Contract
                            → Phishing Detection Lab
                                → Incident Commander
                                    → Crypto Sorter
                                        → RSA Key Lab
                                            → Password Fortress
                                                → Security Guardian
```

---

## 11. Economy & Shop Flow

```
CyberCoin Sources:
══════════════════
Tutorial Completion → fixed coin amount per game
XP Earned → small conversion bonus
Daily Login → claim once per 24 hours

Shop Purchase Flow:
═══════════════════
landing.tscn → [Shop] → shop_panel.tscn (shop_panel.gd)
    │
    ├── Browse tabs: Avatars | Backgrounds | Skins
    ├── Select item → Detail panel (preview, rarity, price)
    │
    ├── [Buy] → Check coin balance
    │     ├── Sufficient → Deduct coins, add to inventory, save to Firestore
    │     └── Insufficient → Show "Not enough CyberCoins" message
    │
    └── [Equip] → Apply cosmetic to player profile
          ├── Avatar → Auth.current_avatar updated
          ├── Background → Card background for games
          └── Skin → Ship/card cosmetic for specific game

Inventory Flow:
═══════════════
landing.tscn → [Inventory] → inventory_panel.tscn (inventory_panel.gd)
    │
    ├── Categories: Badges | Cards | Avatars | Skins
    ├── Sort: by rarity | date | name
    ├── Select item → Detail view
    ├── [Equip] / [Unequip] → Toggle cosmetic on/off
    └── Preview → See how item looks
```

---

## 12. Scene-by-Scene Map

### Authentication & Onboarding

| Scene | Script | Purpose |
|-------|--------|---------|
| `login.tscn` | `login.gd` | Email/Google login |
| `signup.tscn` | `signup.gd` | Account creation |
| `email_verification.tscn` | `email_verification.gd` | Email verify prompt |
| `intro_scene.tscn` | `intro_scene.gd` | Story cutscene entry |
| `Main.tscn` | `Main.gd` | 3D apartment exploration |
| `computer_desktop.tscn` | `computer_desktop.gd` | Desktop OS simulation |
| `intro_cybersecurity.tscn` | `intro_cybersecurity.gd` | CA organization intro |

### Hub & Navigation

| Scene | Script | Purpose |
|-------|--------|---------|
| `landing.tscn` | `landing.gd` | Main hub / home screen |
| `mode_selection.tscn` | `mode_selection.gd` | Difficulty/game chooser |
| `SettingsPanel.tscn` | `settings_panel.gd` | Audio/display settings |
| `view_player_profile.tscn` | `view_player_profile.gd` | Profile viewer |

### Beginner Tutorials

| Scene | Script | Game |
|-------|--------|------|
| `tutorial_cyber_fundamentals.tscn` | `tutorial_cyber_fundamentals.gd` | CIA Triad & Threat Models |
| `tutorial_network_basics.tscn` | `tutorial_network_basics.gd` | IP, Ports, Protocols |
| `datavsnetwork.tscn` | `datavsnetworkgmmanager.gd` | Drop Zone Defender |
| `tutorial_malware_types.tscn` | `tutorial_malware_types.gd` | Threat Identification |
| `Assetandthreat.tscn` | `GameManager.gd` | Asset vs Threats |

### Intermediate Tutorials

| Scene | Script | Game |
|-------|--------|------|
| `tutorial_encryption_basics.tscn` | `tutorial_encryption_basics.gd` | Caesar Cipher |
| `PhoneEncryption.tscn` | `PhoneEncryption.gd` | Crypt Contract |
| `tutorial_phishing_lab.tscn` | `tutorial_phishing_lab.gd` | Phishing Detection Lab |
| `SOCmain.tscn` | `SOCMain.gd` | Incident Commander |

### Advanced Tutorials

| Scene | Script | Game |
|-------|--------|------|
| `crypto_sorter.tscn` | `crypto_sorter.gd` | Crypto Sorter |
| `rsa_key_lab.tscn` | `rsa_key_lab.gd` | RSA Key Lab |
| `tutorial_password_basics.tscn` | `tutorial_password_basics.gd` | Password Fortress |
| `authgmMain.tscn` | `authgmMain.gd` | Security Guardian |

### Additional Games

| Scene | Script | Game |
|-------|--------|------|
| `Asymmetricmain.tscn` | `Asymmetricmain.gd` | Asymmetric Crypto Tutorial |
| `CipherShield.tscn` | `CipherShield.gd` | Symmetric Encryption Defense |
| `hash_integrity_game.tscn` | `hash_integrity_game.gd` | Hash Integrity Game |
| `desvsaesmain.tscn` | `desvsaesmain.gd` | DES vs AES Battle |
| `DataVault.tscn` | `DataVault.gd` | Firewall Traffic Inspector |
| `NTMainGame.tscn` | `NTMainGame.gd` | Network Traffic Inspector |
| `DigitalForensicsScene.tscn` | `DigitalForensicsScene.gd` | Digital Forensics |
| `incedentmain.tscn` | `incedentmain.gd` | Incident Response Terminal |
| `MalwareDefense.tscn` | `MalwareDefense.gd` | Malware Classification |
| `malware_trojan_tutorial.tscn` | `malware_trojan_tutorial.gd` | Trojan Walkthrough |
| `network_defense_game.tscn` | `network_defense_game.gd` | Network Defense Game |
| `confidentiality_game.tscn` | — | Confidentiality Game |

### Multiplayer — Defuse the Trojan

| Scene | Script | Purpose |
|-------|--------|---------|
| `defuse_trojan_lobby.tscn` | `defuse_trojan_lobby.gd` | Room list & creation |
| `defuse_trojan_room.tscn` | `defuse_trojan_room.gd` | Room with player cards |
| `defuse_trojan_loading.tscn` | `defuse_trojan_loading.gd` | Synchronized loading |
| `defuse_trojan_arena.tscn` | `defuse_trojan_arena.gd` | Main typing game |
| `defuse_trojan_postgame.tscn` | `defuse_trojan_postgame.gd` | Results & stats |

### Multiplayer — Code Breaker

| Scene | Script | Purpose |
|-------|--------|---------|
| `code_breaker_lobby.tscn` | `code_breaker_lobby.gd` | Room list & creation |
| `code_breaker_room.tscn` | `code_breaker_room.gd` | Room with player cards |
| `code_breaker_loading.tscn` | `code_breaker_loading.gd` | Synchronized loading |
| `code_breaker_arena.tscn` | `code_breaker_arena.gd` | Main code typing game |
| `code_breaker_postgame.tscn` | `code_breaker_postgame.gd` | Results & stats |

### Multiplayer — Akashic TCG

| Scene | Script | Purpose |
|-------|--------|---------|
| `akashic_tcg_lobby.tscn` | `akashic_tcg_lobby.gd` | Room list & creation |
| `akashic_tcg_room.tscn` | `akashic_tcg_room.gd` | Room with player cards |
| `akashic_tcg_loading.tscn` | `akashic_tcg_loading.gd` | Synchronized loading |
| `akashic_tcg_arena.tscn` | `akashic_tcg_arena.gd` | Card battle game |
| `akashic_tcg_postgame.tscn` | `akashic_tcg_postgame.gd` | Results |

### Teacher / Classroom

| Scene | Script | Purpose |
|-------|--------|---------|
| `TeacherCreateRoom.tscn` | `TeacherCreateRoom.gd` | Room creation dashboard |
| `TeacherRoomPanel.tscn` | `TeacherLobby.gd` | Shared lobby (teacher + student) |
| `quiz_creation_panel.tscn` | `QuizCreationPanel.gd` | Quiz question editor |
| `StudentQuizScene.tscn` | `StudentQuizScene.gd` | Student quiz interface |
| `gamemode_student_waiting.tscn` | `gamemode_student_waiting.gd` | Student waiting for game start |
| `gamemode_leaderboard.tscn` | `gamemode_leaderboard.gd` | Student/teacher results view |

### Social & Cosmetics

| Scene | Script | Purpose |
|-------|--------|---------|
| `chat.tscn` | `chat.gd` | Messaging system |
| `friend_list.tscn` | `friend_list.gd` | Friends list |
| `shop_panel.tscn` | `shop_panel.gd` | Cosmetic shop |
| `inventory_panel.tscn` | `inventory_panel.gd` | Item collection |
| `edit_profile_popup.tscn` | — | Profile editor |
| `rank_up_notification.tscn` | `rank_up_notification.gd` | Rank up celebration |

---

## 13. Technical Contracts & Meta Keys

### Scene Init Meta Contracts

These are passed via `get_tree().set_meta(...)` before `change_scene_to_file(...)`:

**Defuse the Trojan:**
| Meta Key | Data | Set By |
|----------|------|--------|
| `defuse_trojan_room_init` | room_id, is_host, lobby_url | Lobby → Room |
| `defuse_trojan_loading_init` | room_data, relay_client, game_start_time_ms | Room → Loading |
| `defuse_trojan_arena_init` | mode "multiplayer", relay_client, room_snapshot | Loading → Arena |
| `defuse_trojan_postgame_init` | results_payload, relay_client | Arena → Postgame |

**Game Mode (Student):**
| Meta Key | Data | Set By |
|----------|------|--------|
| `gamemode_room_code` | Room code string | mode_selection → waiting |
| `gamemode_lobby_url` | Server base URL | mode_selection → waiting |
| `gamemode_game_name` | Display name | mode_selection → waiting |
| `gamemode_game_scene` | Scene path | mode_selection → waiting |
| `gamemode_start_time_ms` | Ticks at game launch | waiting → game |

**GameMode Leaderboard:**
| Meta Key | Data | Set By |
|----------|------|--------|
| `gamemode_leaderboard_room_code` | Room code | Game → Leaderboard |
| `gamemode_leaderboard_lobby_url` | Server URL | Game → Leaderboard |

### Global Singletons (Autoloads)

| Singleton | Script | Purpose |
|-----------|--------|---------|
| `Auth` | `auth.gd` | Firebase authentication, tokens, user data |
| `GlobalState` | `GlobalState.gd` | Story progression flags |
| `TutorialManager` | `TutorialManager.gd` | XP, ranks, game unlocks, tutorial results |
| `DialogueManager` | `dialogue_manager.gd` | Dialogue box lifecycle |
| `CyberCoinManager` | `CyberCoinManager.gd` | In-game currency |
| `ShopManager` | `ShopManager.gd` | Shop catalog and purchases |
| `SettingsManager` | `SettingsManager.gd` | User preferences |
| `ChatManager` | `ChatManager.gd` | Real-time messaging |

### Server API Summary

**Base URL:** `https://codebreaker-lobby.onrender.com`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Server status + code_version |
| `/api/gamemode/create` | POST | Create game mode room |
| `/api/gamemode/:code/info` | GET | Room info + players |
| `/api/gamemode/:code/join` | POST | Student joins room |
| `/api/gamemode/:code/start` | POST | Teacher starts game |
| `/api/gamemode/:code/submit` | POST | Submit score |
| `/api/gamemode/:code/results` | GET | Get all results |
| `/api/gamemode/:code/add-students` | POST | Add whitelist students |
| `/api/quiz/create` | POST | Create quiz room |
| `/api/quiz/:code/info` | GET | Quiz room info |
| `/api/quiz/:code/questions` | GET | Get questions (no answers) |
| `/api/quiz/:code/join` | POST | Student joins quiz |
| `/api/quiz/:code/submit` | POST | Submit answers |
| `/api/quiz/:code/add-students` | POST | Add whitelist students |

---

*This document serves as the complete technical and user-facing flow reference for the CyberArena project.*
