# Capstone 2 - Complete System Flow (Cyber Security Game Platform)

## Instructions for draw.io Import:
1. Go to **https://app.diagrams.net/**
2. Click **Arrange → Insert → Advanced → Mermaid**
3. Copy ONE diagram below (WITHOUT the ```mermaid wrapper)
4. Paste and click **Insert**
5. Diagram appears as editable elements!

---

## 1. Complete User Journey (Tutorial Unlock System)

```mermaid
graph TD
    A[Open App] --> B{Logged In?}
    
    B -->|No| C[Login/Sign Up]
    B -->|Yes| D[Landing Hub]
    
    C --> E[Create Username]
    E --> F[Mode Selection Screen]
    
    F --> G{Select Knowledge Level}
    G -->|Beginner| H[Tutorial Beginner]
    G -->|Intermediate| I[Tutorial Intermediate]
    G -->|Advanced| J[Tutorial Advanced]
    
    H --> K[Complete Beginner Challenges]
    I --> L[Complete Intermediate Challenges]
    J --> M[Complete Advanced Challenges]
    
    K --> N[Unlock Code Breaker Game]
    L --> O[Unlock Defuse The Trojan]
    M --> P[Unlock Akashic TCG]
    
    N --> D
    O --> D
    P --> D
    
    D --> Q[Game Select Panel]
    Q --> R[Play Unlocked Games]
    R --> S[Match Complete]
    S --> D
    
    style A fill:#ff6b6b,stroke:#333,stroke-width:3px,color:#fff
    style F fill:#f9ca24,stroke:#333,stroke-width:2px
    style K fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style L fill:#ffa502,stroke:#333,stroke-width:2px,color:#fff
    style M fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style D fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
```

---

## 2. Authentication Flow (Firebase)

```mermaid
graph TD
    A[App Launch] --> B{Token Exists?}
    
    B -->|No| C[Login Screen]
    B -->|Yes| D[Validate Token]
    
    C --> E{Choose Method}
    E -->|Email| F[Email + Password]
    E -->|Google| G[Google OAuth]
    
    F --> H[Firebase Auth API]
    G --> I[Google Consent]
    I --> J[Exchange Code]
    J --> H
    
    H --> K{Success?}
    K -->|No| L[Show Error]
    K -->|Yes| M[Store Tokens]
    
    L --> C
    D --> M
    
    M --> N[Write RTDB Presence]
    N --> O[Fetch User Profile]
    O --> P{Has Username?}
    
    P -->|No| Q[Create Username Scene]
    P -->|Yes| R[Landing Hub]
    
    Q --> S[Mode Selection]
    
    style C fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style M fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style R fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style S fill:#f9ca24,stroke:#333,stroke-width:2px
```

---

## 3. Mode Selection & Tutorial Unlock System

```mermaid
graph TD
    A[Username Created] --> B[Mode Selection Screen]
    
    B --> C[Select Knowledge Level]
    
    C --> D[Beginner]
    C --> E[Intermediate]
    C --> F[Advanced]
    
    D --> G[Tutorial: Password Security]
    E --> H[Tutorial: Network Security]
    F --> I[Tutorial: Cryptography]
    
    G --> J[Challenge: Create Strong Password]
    H --> K[Challenge: Identify Threats]
    I --> L[Challenge: Decrypt Messages]
    
    J --> M{Pass?}
    K --> N{Pass?}
    L --> O{Pass?}
    
    M -->|Yes| P[Unlock Code Breaker]
    M -->|No| G
    
    N -->|Yes| Q[Unlock Defuse The Trojan]
    N -->|No| H
    
    O -->|Yes| R[Unlock Akashic TCG]
    O -->|No| I
    
    P --> S[Landing Hub]
    Q --> S
    R --> S
    
    S --> T[Access Unlocked Games]
    
    style B fill:#f9ca24,stroke:#333,stroke-width:2px
    style D fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#ffa502,stroke:#333,stroke-width:2px,color:#fff
    style F fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style P fill:#3273dc,stroke:#333,stroke-width:2px,color:#fff
    style Q fill:#9b59b6,stroke:#333,stroke-width:2px,color:#fff
    style R fill:#e67e22,stroke:#333,stroke-width:2px,color:#fff
```

---

## 4. Code Breaker Multiplayer Flow (WebSocket Relay)

```mermaid
graph TD
    A[Enter Code Breaker] --> B[Lobby Scene]
    
    B --> C{Host or Join?}
    C -->|Host| D[POST /api/rooms/create]
    C -->|Join| E[GET /api/rooms/list]
    
    D --> F[Wait for Client]
    E --> G[Select Room]
    G --> H[POST /api/rooms/join]
    
    F --> I{Client Joined?}
    I -->|Yes| J[Room Scene]
    I -->|No| F
    
    H --> J
    
    J --> K[WS /ws/relay/room_id]
    K --> L[Client Ready Toggle]
    L --> M{Both Ready?}
    
    M -->|No| L
    M -->|Yes| N[Host Clicks START]
    
    N --> O[Loading Screen]
    O --> P[Both Players Sync]
    P --> Q[Arena Scene]
    
    Q --> R[3-2-1 Countdown]
    R --> S[Type Code Snippets]
    
    S --> T{Correct?}
    T -->|Yes| U[+Score, Damage Enemy]
    T -->|No| V[Self Damage]
    
    U --> W{Game Over?}
    V --> W
    
    W -->|No| S
    W -->|Yes| X[Show Results]
    
    X --> Y{Rematch?}
    Y -->|Yes| J
    Y -->|No| Z[Leave Room]
    
    Z --> B
    
    style B fill:#95e1d3,stroke:#333,stroke-width:2px
    style J fill:#f9ca24,stroke:#333,stroke-width:2px
    style Q fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style K fill:#6c5ce7,stroke:#333,stroke-width:2px,color:#fff
```

---

## 5. Landing Hub Navigation

```mermaid
graph LR
    A[Landing Hub] --> B[Home Panel]
    A --> C[Game Select Panel]
    A --> D[Ranking Panel]
    A --> E[Profile Panel]
    A --> F[Friend List]
    A --> G[Chat System]
    
    C --> H[Code Breaker Lobby]
    C --> I[Defuse The Trojan]
    C --> J[Akashic TCG Lobby]
    
    H --> K[Room Scene]
    J --> L[TCG Room Scene]
    
    K --> M[Arena Scene]
    L --> N[TCG Arena]
    
    M --> A
    N --> A
    
    style A fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style C fill:#95e1d3,stroke:#333,stroke-width:2px
    style H fill:#3273dc,stroke:#333,stroke-width:2px,color:#fff
    style M fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
```

---

## 6. WebSocket Relay Architecture (No Port Forwarding)

```mermaid
graph LR
    A[PC Host<br/>Home WiFi] -->|POST /create| B[Render.com Server]
    C[Laptop Client<br/>Starbucks WiFi] -->|GET /list| B
    C -->|POST /join| B
    
    B -->|WebSocket| D[Express.js Relay]
    
    A <-->|WS /ws/relay/room_id| D
    C <-->|WS /relay/room_id| D
    
    D -->|In-Memory| E[(Room Data)]
    
    A -.->|Heartbeat 30s| B
    
    F[Phone<br/>Mobile Data] -->|Works| D
    
    style A fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style C fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style D fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#f9ca24,stroke:#333,stroke-width:2px
```

---

## 7. Data Storage Architecture

```mermaid
graph TB
    A[Godot Client] --> B[Auth.gd]
    A --> C[ChatManager.gd]
    A --> D[Lobby Script]
    
    B -->|Authenticate| E[Firebase Auth]
    B -->|Presence| F[RTDB]
    B -->|User Data| G[Firestore]
    
    C -->|Chat| F
    
    D -->|REST| H[Render.com Server]
    D -->|WebSocket| H
    
    H -->|Store| I[(In-Memory Rooms)]
    
    E --> J[Email + Google OAuth]
    
    F --> K[presence/uid<br/>chats/]
    
    G --> L[users/uid<br/>username, level, wins]
    
    I --> M[room_id, host, client]
    
    style B fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style F fill:#ffa502,stroke:#333,stroke-width:2px,color:#fff
    style G fill:#ff6348,stroke:#333,stroke-width:2px,color:#fff
    style H fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
```

---

## 8. Arena Gameplay State Machine

```mermaid
stateDiagram-v2
    [*] --> Lobby
    Lobby --> Room: Create/Join
    
    state Room {
        [*] --> Waiting
        Waiting --> ClientJoined
        ClientJoined --> BothReady
        BothReady --> Starting
    }
    
    Room --> Loading
    
    state Loading {
        [*] --> Syncing
        Syncing --> BothReady
        BothReady --> Countdown
    }
    
    Loading --> Arena
    
    state Arena {
        [*] --> Countdown321
        Countdown321 --> Playing
        
        state Playing {
            [*] --> Typing
            Typing --> Submit
            Submit --> Correct: Match
            Submit --> Wrong: Mismatch
            
            Correct --> DamageEnemy
            Wrong --> SelfDamage
            
            DamageEnemy --> CheckWin
            SelfDamage --> CheckWin
            
            CheckWin --> Victory: HP = 0
            CheckWin --> Typing: Continue
        }
        
        Playing --> Timeout: 4 Minutes
        Timeout --> Victory
    }
    
    Victory --> GameOver
    GameOver --> Room: Rematch
    GameOver --> Lobby: Leave
```

---

## 9. Leave Room Logic (Host Promotion)

```mermaid
graph TD
    A[Player Clicks LEAVE] --> B{Who Leaving?}
    
    B -->|Host| C{Client Exists?}
    C -->|Yes| D[Promote Client to Host]
    C -->|No| E[Delete Room]
    
    B -->|Client| F[Remove Client]
    
    D --> G[Broadcast host_promotion]
    F --> H[Broadcast player_left]
    E --> I[Close WebSocket]
    
    G --> J[Room Still Active]
    H --> J
    I --> K[Return to Lobby]
    
    J --> L[Update UI]
    
    style D fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style F fill:#ffa502,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#ff4757,stroke:#333,stroke-width:2px,color:#fff
```

---

## Key Features

✅ **Tutorial Unlock System:** Complete tutorials to unlock specific games  
✅ **Knowledge Levels:** Beginner, Intermediate, Advanced (each unlocks different game)  
✅ **Cross-Network Multiplayer:** No port forwarding (WebSocket relay)  
✅ **Real-time Chat:** RTDB polling system  
✅ **Profile System:** Track stats, level, wins, losses  
✅ **Scene Preservation:** WebSocket relay persists across scene changes  

---

## How to Use

### Import to draw.io:
1. Go to https://app.diagrams.net/
2. Click **Arrange → Insert → Advanced → Mermaid**
3. Copy ONE diagram code (without ` ```mermaid ` wrapper)
4. Paste and click Insert
5. Edit as needed!

### Export to PNG:
1. Select diagram
2. **File → Export as → PNG**
3. Adjust settings (zoom: 100%, border: 10px)
4. Save to `docs/flowcharts/`
