# CyberArena — Project Overview

**A Gamified Cybersecurity Education Platform built with Godot 4.4**

---

## Table of Contents

1. [Project Summary](#project-summary)
2. [Technology Stack](#technology-stack)
3. [Architecture Overview](#architecture-overview)
4. [Core Systems](#core-systems)
5. [Game Modes](#game-modes)
6. [Educational Content Map](#educational-content-map)
7. [Multiplayer Infrastructure](#multiplayer-infrastructure)
8. [Teacher & Classroom Features](#teacher--classroom-features)
9. [Economy & Cosmetics](#economy--cosmetics)
10. [3D Story Mode](#3d-story-mode)
11. [File & Folder Structure](#file--folder-structure)

---

## Project Summary

CyberArena is an educational game designed to teach cybersecurity concepts through interactive minigames, tutorials, and competitive multiplayer experiences. It targets an IT-323 (Information Assurance) curriculum, covering topics from basic CIA Triad principles to advanced RSA cryptography and digital forensics.

### Key Features

- **13+ educational minigames** covering cybersecurity fundamentals, encryption, network security, malware, authentication, and forensics
- **3 competitive multiplayer games** — Defuse the Trojan, Code Breaker, and Akashic TCG
- **3D immersive story mode** with first-person exploration and a malware infection narrative
- **Teacher dashboard** for creating quiz rooms and game mode sessions with student whitelisting
- **XP & rank progression** system (9 tiers: Iron → Challenger)
- **In-game economy** with CyberCoins, a cosmetic shop, and inventory
- **Real-time chat and friends** system
- **Firebase authentication** (email/password + Google OAuth)
- **Firestore persistence** for player data, scores, and cosmetics

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| **Game Engine** | Godot 4.4 (GDScript) |
| **Authentication** | Firebase Auth (REST API) |
| **Database** | Cloud Firestore |
| **Server** | Node.js / Express (server.js) |
| **Hosting** | Render.com (free tier) |
| **Multiplayer Relay** | WebSocket (WebSocketRelayClient.gd) |
| **3D Assets** | GLTF models, custom shaders |
| **UI** | Godot Control nodes, custom StyleBox themes |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     GODOT CLIENT                         │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │  Auth.gd  │  │GlobalState│  │  TutorialManager.gd │  │
│  │(Singleton)│  │(Singleton)│  │    (Singleton)       │  │
│  └─────┬─────┘  └────┬─────┘  └──────────┬───────────┘  │
│        │              │                   │              │
│  ┌─────┴──────────────┴───────────────────┴──────────┐  │
│  │              Scene Manager / Navigation            │  │
│  │  login → signup → intro → landing → games         │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────┐ ┌─────────────┐ ┌────────────────────┐  │
│  │  13+ Games  │ │  3 PvP Games│ │  Teacher Dashboard │  │
│  │ (Tutorials) │ │(Multiplayer)│ │  (Room Creation)   │  │
│  └──────┬──────┘ └──────┬──────┘ └─────────┬──────────┘  │
│         │               │                  │             │
└─────────┼───────────────┼──────────────────┼─────────────┘
          │               │                  │
          ▼               ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│   Firebase   │  │  Relay WS    │  │  Express Server  │
│  (Auth + DB) │  │  (Real-time) │  │  (Room/Quiz API) │
└──────────────┘  └──────────────┘  └──────────────────┘
```

---

## Core Systems

### Authentication (auth.gd — Global Singleton)

- Firebase email/password login and registration
- Google OAuth2 support
- Token refresh and session persistence
- Stores: `current_id_token`, `current_local_id`, `current_username`, `current_avatar`
- Email verification flow
- Cosmetic equipment tracking (card backgrounds, badges)

### XP & Rank Progression (TutorialManager.gd — Global Singleton)

**9-Tier Ranking System:**

| Rank | XP Required | Icon |
|------|-------------|------|
| Iron | 0 – 199 | IRON.png |
| Bronze | 200 – 399 | BRONZE.png |
| Silver | 400 – 699 | SILVER.png |
| Gold | 700 – 1,099 | GOLD.png |
| Platinum | 1,100 – 1,599 | PLATINUM.png |
| Diamond | 1,600 – 2,299 | DIAMOND.png |
| Master | 2,300 – 3,199 | MASTER.png |
| Grandmaster | 3,200 – 4,499 | GRAND MASTER.png |
| Challenger | 4,500+ | CHALLENGER.png |

**XP Awards (based on score percentage):**
- 90%+ → 200 XP
- 80%+ → 150 XP
- 70%+ → 100 XP
- 50%+ → 50 XP
- Below 50% → 0 XP

**Game Unlocking:** Tutorials unlock in a linear prerequisite chain. Completing earlier lessons unlocks later ones.

### Global State (GlobalState.gd — Global Singleton)

Tracks story progression flags:
- `returning_from_computer` — Player returning from malware infection
- `computer_infected` — Computer has been compromised
- `joined_ca_organization` — Joined the CyberArena secret agent organization
- `ca_training_completed` — Passed CA training mission

### Dialogue System (dialogue_manager.gd — Autoload)

- Global dialogue box with typewriter text effect
- Advance with Space or Enter
- Choice system with styled buttons
- Prevents player input during active dialogue
- Used across story, tutorials, and 3D scenes

---

## Game Modes

### Solo Educational Games (13 Tutorials)

| # | Game | Topic | Difficulty |
|---|------|-------|-----------|
| 1 | Cybersecurity Fundamentals | CIA Triad, Threat Models | Beginner |
| 2 | Network Basics | IP, Ports, Protocols | Beginner |
| 3 | Drop Zone Defender | Data vs Network Attack Classification | Beginner |
| 4 | Threat Identification Lab | 6 Threat Categories | Beginner |
| 5 | Asset vs Threats | Asset Defense, 5-Wave Battle | Beginner |
| 6 | Encryption Basics | Caesar Cipher, Ransomware | Intermediate |
| 7 | Crypt Contract | RSA-style Key Generation, 5 Missions | Intermediate |
| 8 | Phishing Detection Lab | Email Analysis, Red Flags | Intermediate |
| 9 | Incident Commander | SOC Terminal Defense, 10 Waves | Intermediate |
| 10 | Crypto Sorter | Symmetric vs Asymmetric Classification | Advanced |
| 11 | RSA Key Lab | RSA & Diffie-Hellman Key Exchange | Advanced |
| 12 | Password Fortress Defender | Password Strength, Crack Attacks | Advanced |
| 13 | Security Guardian | Authentication Approval/Denial | Advanced |

### Additional Educational Experiences

| Game | Topic | Description |
|------|-------|-------------|
| Asymmetric Cryptography Tutorial | RSA Concepts | Alice/Bob/Eve visual demonstration |
| CipherShield | AES Encryption Defense | Encrypt & transmit messages under attack |
| Hash Integrity Game | Hash Functions | MD5 vs SHA-256 tamper detection |
| DES vs AES Battle | Algorithm Comparison | Why DES is obsolete |
| Data Vault | Firewall & Traffic Inspection | Allow/Deny network traffic decisions |
| Network Traffic Inspector | SOC Analyst Simulator | IDS/IPS pattern analysis |
| Digital Forensics Scene | Terminal Forensics | Evidence collection & incident response |
| Incident Response Terminal | CMD Malware Removal | Real Windows commands simulation |
| Malware Defense | Malware Classification | 5-phase detection to prevention |
| Trojan Horse Walkthrough | Social Engineering | Hacker POV attack simulation |

### Competitive Multiplayer Games (3)

| Game | Players | Mechanic | Description |
|------|---------|----------|-------------|
| **Defuse the Trojan** | 2–3 | Typing Combat | Type cybersecurity keywords to destroy enemies |
| **Code Breaker** | 1v1 | Code Snippet Racing | Type code accurately to damage opponent |
| **Akashic TCG** | 1v1 | Card Strategy | Security-themed trading card battles |

---

## Educational Content Map

The curriculum is organized into 7 lesson groups covering IT-323 (Information Assurance):

### Lesson 1: Introduction to Information Assurance
- CIA Triad (Confidentiality, Integrity, Availability)
- Threat modeling (Threat vs Vulnerability vs Risk)
- IP addresses, ports, protocols
- Network attack classification

### Lesson 2: Threats & Assets
- 6 threat categories (Social Engineering, Malware, Network, Insider, Physical, Data Breach)
- Asset identification and defense strategies
- Defensive tools (Firewall, Antivirus, Backup, Access Control)

### Lesson 3: Symmetric Encryption
- Caesar Cipher mechanics
- AES encryption principles
- Ransomware and why modern encryption is unbreakable
- Key generation and message encryption/decryption

### Lesson 4: DES, Triple DES & AES
- DES obsolescence demonstration
- Email-based encryption audit (approve/flag configurations)
- Terminal-based encryption defense commands

### Lesson 5: Public-Key Cryptography
- Symmetric vs Asymmetric classification
- RSA concepts (Alice/Bob/Eve model)
- One-way functions and key distribution problem

### Lesson 6: RSA & Diffie-Hellman
- RSA key generation (p, q, n, φ, e, d)
- Diffie-Hellman key exchange simulation
- Real-world scenarios (SSL, TLS, Forward Secrecy)

### Lesson 7: Authentication
- Password strength mechanics
- Brute force / Dictionary / Rainbow table attacks
- Authentication request evaluation (approve/deny)
- Trust scoring and threat detection

---

## Multiplayer Infrastructure

### WebSocket Relay System

Used for Defuse the Trojan (2–3 player co-op):

```
Host (Player 1) ←──WebSocket──→ Relay Server ←──WebSocket──→ Client (Player 2/3)
```

- **Host-authoritative**: Host controls enemy spawns, state, and destruction
- **Client requests**: Clients send kill requests; host validates and broadcasts
- **State sync**: Periodic state updates (positions, wave, health, scores)
- **Projectile replication**: All peers see each other's typing shots

### Key Message Types

| Message | Direction | Purpose |
|---------|-----------|---------|
| `dt_enemy_spawn` | Host → Clients | Spawn enemy with stable ID |
| `dt_enemy_state` | Host → Clients | Periodic state (positions, wave, health) |
| `dt_kill_request` | Client → Host | Request to destroy enemy |
| `dt_enemy_destroy` | Host → All | Enemy destroyed (with attribution) |
| `dt_shot` | Any → All | Replicate typing projectile visuals |
| `dt_match_end` | Host → Clients | Signal match over |
| `dt_postgame` | Host → All | Final results for postgame screen |

### Express Server API

**Endpoint Base:** `https://codebreaker-lobby.onrender.com`

**GameMode Endpoints:**
- `POST /api/gamemode/create` — Create room
- `GET /api/gamemode/:code/info` — Room info + player list
- `POST /api/gamemode/:code/join` — Join room
- `POST /api/gamemode/:code/start` — Teacher starts game
- `POST /api/gamemode/:code/submit` — Submit score
- `GET /api/gamemode/:code/results` — Get leaderboard

**Quiz Endpoints:**
- `POST /api/quiz/create` — Create quiz room
- `GET /api/quiz/:code/questions` — Get questions (correct answers stripped)
- `POST /api/quiz/:code/submit` — Submit answers (server-side grading)

---

## Teacher & Classroom Features

### Room Creation (TeacherCreateRoom.gd)

Teachers can create two types of rooms:

1. **Game Mode Room** — Select a minigame, students play and submit scores
2. **Multiple Choice Quiz** — Create custom questions, students answer in real-time

### Student Number Whitelist

- Teachers can optionally restrict room access by student number
- Comma/newline-separated list (e.g., `21-2169, 21-2170`)
- Server validates on join; rejects unauthorized students
- Teachers can add additional students from the lobby

### Room Flow

```
Teacher creates room → Gets room code → Students join by code
    → Teacher sees live player list (avatars + ranks)
    → Teacher clicks Start → All students launch game simultaneously
    → Students play and submit scores → Leaderboard displayed
```

### Student Leaderboard

- Real-time polling every 5 seconds
- Highlights current player with "(You)" suffix
- Time-only layout for certain games (e.g., Encryption)
- Teacher and student views available

---

## Economy & Cosmetics

### CyberCoins (CyberCoinManager — Autoload)

| Source | Amount |
|--------|--------|
| Tutorial completion | Fixed per tutorial |
| XP conversion | Small coins based on XP earned |
| Daily bonus | Claimable once per day |

### Shop (shop_panel.gd)

Three categories:
- **Avatars** — Character portraits with rarity tiers
- **Backgrounds** — Game-specific card backgrounds (Defuse Trojan, Code Breaker)
- **Skins** — Ship skins, card backs, break effects

**Rarity Tiers:** Common (gray) → Uncommon → Rare → Epic → Legendary (gold)

### Avatar System (AvatarCatalog.gd)

- 17 built-in avatars (`avatar1.png` – `avatar18.png`, no avatar13)
- Custom avatar upload support (`user://` paths)
- 30-day cooldown between avatar changes
- Used in profiles, lobbies, leaderboards, and chat

### Inventory (inventory_panel.gd)

- Categories: Badges, Cards, Avatars, Skins
- Sort by rarity, date, or name
- Equip/unequip functionality
- Item detail view with preview

---

## 3D Story Mode

### Narrative Arc

The game begins with an immersive 3D story that motivates cybersecurity education:

1. **Visual Novel Intro** (story_cutscene.gd)
   - 5-panel story: Player wants "CyberRun 2026" game but can't afford ₱1,000
   - Discovers a "free download" link online

2. **3D Apartment Exploration** (Main.gd + player.gd)
   - First-person WASD + mouse look movement
   - Furnished room with interactive computer desk
   - Press E to interact with objects

3. **Computer Desktop** (computer_desktop.gd)
   - Windows-style desktop OS simulation
   - Browser, Messages, and Files applications
   - Player downloads the suspicious "free game"

4. **Malware Infection Sequence**
   - Popup windows flood the screen
   - System appears to crash/shutdown
   - Player witnesses the consequences of their download

5. **Post-Infection & Recruitment** (Main.gd)
   - Panic sequence with dialogue
   - Hologram character "Anonymouse" appears
   - Offers to recruit player into CyberArena (secret cybersecurity organization)
   - **Player chooses:** Accept (join CA for training) or Decline

6. **Routes:**
   - **Accept** → CA training mission (intro_cybersecurity.gd) → Full game
   - **Decline** → Landing page with normal tutorial progression

---

## File & Folder Structure

```
capstone2/
├── 3D/                    # 3D model imports (.glb, textures)
├── asset/                 # Game assets
│   ├── avatars/           # Player avatars (avatar1-18.png)
│   ├── defuse_trojan/     # Defuse Trojan spritesheets
│   └── rankicon/          # Rank tier icons (IRON-CHALLENGER)
├── data/                  # Game data files
├── docs/                  # Documentation
├── Neo3D/                 # Additional 3D assets
├── scene/                 # Godot scene files (.tscn)
│   ├── landing.tscn       # Main hub
│   ├── login.tscn         # Login screen
│   ├── Main.tscn          # 3D room
│   ├── tutorial_*.tscn    # Tutorial scenes
│   ├── defuse_trojan_*.tscn  # Defuse Trojan scenes
│   ├── code_breaker_*.tscn   # Code Breaker scenes
│   └── akashic_tcg_*.tscn    # Akashic TCG scenes
├── script/                # GDScript files (.gd)
│   ├── auth.gd            # Firebase authentication (Singleton)
│   ├── GlobalState.gd     # Game state flags (Singleton)
│   ├── TutorialManager.gd # XP/rank system (Singleton)
│   ├── landing.gd         # Landing page hub
│   ├── tutorial_*.gd      # Tutorial game scripts
│   ├── defuse_trojan_*.gd # Defuse Trojan scripts
│   ├── code_breaker_*.gd  # Code Breaker scripts
│   ├── akashic_tcg_*.gd   # Akashic TCG scripts
│   ├── TeacherCreateRoom.gd  # Teacher room management
│   ├── TeacherLobby.gd       # Room lobby (teacher + student)
│   └── WebSocketRelayClient.gd # Multiplayer relay
├── server/                # Node.js Express server
│   └── server.js          # API endpoints
├── shader/                # Custom shaders
│   └── remove_white_bg.gdshader
├── ui/                    # UI resources
└── project.godot          # Godot project configuration
```

---

## Deployment

### Server (Render.com)

- **Platform:** Render.com free tier (auto-deploy from GitHub `main`)
- **URL:** `https://codebreaker-lobby.onrender.com`
- **Build Command:** `npm install`
- **Start Command:** `node server.js`
- **Verify:** `GET /health` → check `code_version` field
- **Note:** In-memory storage — all data lost on restart/redeploy

### Client

- Export via Godot 4.4 export presets
- Desktop builds (Windows primary)
- Avatar loading uses `AvatarCatalog.DISPLAY_NAMES.keys()` instead of `DirAccess` (required for .pck exports)
