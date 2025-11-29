# Use Case Diagram - Code Breaker Multiplayer Platform

## Complete System Use Case Diagram

```mermaid
graph TB
    subgraph Actors
        Guest[👤 Guest User]
        Player[👤 Registered Player]
        Host[👤 Game Host]
        Client[👤 Game Client]
    end
    
    subgraph "Authentication System"
        UC1[Sign Up]
        UC2[Login with Email]
        UC3[Login with Google]
        UC4[Logout]
    end
    
    subgraph "Social Features"
        UC5[View Profile]
        UC6[Edit Profile]
        UC7[Add Friend]
        UC8[View Friend List]
        UC9[Send Chat Message]
        UC10[Receive Chat Message]
        UC11[View Unread Messages]
    end
    
    subgraph "Lobby Management"
        UC12[Browse Available Rooms]
        UC13[Create Game Room]
        UC14[Join Game Room]
        UC15[Leave Room]
        UC16[View Room Details]
    end
    
    subgraph "Room Operations - Host"
        UC17[Set Room Settings]
        UC18[Wait for Client]
        UC19[Start Match]
        UC20[Kick Player]
    end
    
    subgraph "Room Operations - Client"
        UC21[View Room Info]
        UC22[Toggle Ready Status]
        UC23[Wait for Host Start]
    end
    
    subgraph "Gameplay - Code Breaker"
        UC24[View Code Snippet]
        UC25[Type Code]
        UC26[Submit Answer]
        UC27[Deal Damage]
        UC28[Receive Damage]
        UC29[View Score]
        UC30[View Health]
        UC31[Win Match]
        UC32[Lose Match]
    end
    
    subgraph "Post-Game"
        UC33[View Game Results]
        UC34[Request Rematch]
        UC35[Return to Lobby]
        UC36[View Statistics]
    end
    
    subgraph "External Systems"
        Firebase[🔥 Firebase Auth]
        RTDB[📊 Realtime Database]
        Firestore[💾 Firestore]
        RelayServer[🌐 Relay Server]
    end
    
    %% Guest Interactions
    Guest --> UC1
    Guest --> UC2
    Guest --> UC3
    
    %% Player Interactions
    Player --> UC2
    Player --> UC3
    Player --> UC4
    Player --> UC5
    Player --> UC6
    Player --> UC7
    Player --> UC8
    Player --> UC9
    Player --> UC10
    Player --> UC11
    Player --> UC12
    Player --> UC13
    Player --> UC14
    Player --> UC15
    Player --> UC16
    
    %% Host Interactions
    Host --> UC13
    Host --> UC17
    Host --> UC18
    Host --> UC19
    Host --> UC20
    
    %% Client Interactions
    Client --> UC14
    Client --> UC21
    Client --> UC22
    Client --> UC23
    
    %% Both Host and Client in Arena
    Host --> UC24
    Host --> UC25
    Host --> UC26
    Host --> UC27
    Host --> UC28
    Host --> UC29
    Host --> UC30
    Host --> UC31
    Host --> UC32
    
    Client --> UC24
    Client --> UC25
    Client --> UC26
    Client --> UC27
    Client --> UC28
    Client --> UC29
    Client --> UC30
    Client --> UC31
    Client --> UC32
    
    %% Post-Game
    Host --> UC33
    Host --> UC34
    Host --> UC35
    Host --> UC36
    
    Client --> UC33
    Client --> UC34
    Client --> UC35
    Client --> UC36
    
    %% External System Connections
    UC1 -.->|authenticate| Firebase
    UC2 -.->|authenticate| Firebase
    UC3 -.->|authenticate| Firebase
    UC4 -.->|sign out| Firebase
    
    UC5 -.->|read| Firestore
    UC6 -.->|write| Firestore
    UC7 -.->|write| Firestore
    UC8 -.->|read| Firestore
    
    UC9 -.->|write| RTDB
    UC10 -.->|read| RTDB
    UC11 -.->|read| RTDB
    
    UC12 -.->|GET /api/rooms/list| RelayServer
    UC13 -.->|POST /api/rooms/create| RelayServer
    UC14 -.->|POST /api/rooms/join| RelayServer
    UC15 -.->|POST /api/rooms/leave| RelayServer
    
    UC19 -.->|WebSocket relay| RelayServer
    UC24 -.->|WebSocket relay| RelayServer
    UC25 -.->|WebSocket relay| RelayServer
    UC26 -.->|WebSocket relay| RelayServer
    UC27 -.->|WebSocket relay| RelayServer
    UC28 -.->|WebSocket relay| RelayServer
    
    UC33 -.->|write| Firestore
    UC36 -.->|read| Firestore
    
    %% Styling
    style Guest fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style Player fill:#4ecdc4,stroke:#0d9488,color:#fff
    style Host fill:#f9ca24,stroke:#f0932b,color:#000
    style Client fill:#95e1d3,stroke:#0d9488,color:#000
    
    style Firebase fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style RTDB fill:#ffa502,stroke:#ff6348,color:#fff
    style Firestore fill:#ff6348,stroke:#ff4757,color:#fff
    style RelayServer fill:#48c774,stroke:#23d160,color:#fff
```

---

## Detailed Use Cases by Feature

### 1. Authentication System

```mermaid
graph LR
    Guest[👤 Guest] --> SignUp[Sign Up]
    Guest --> EmailLogin[Login with Email]
    Guest --> GoogleLogin[Login with Google]
    
    SignUp --> Firebase[🔥 Firebase Auth]
    EmailLogin --> Firebase
    GoogleLogin --> Google[🔐 Google OAuth]
    Google --> Firebase
    
    Firebase --> Profile[Create Profile]
    Profile --> Firestore[💾 Firestore]
    
    Firestore --> Landing[Navigate to Landing Hub]
    
    style Guest fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Firebase fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Firestore fill:#ff6348,stroke:#333,stroke-width:2px,color:#fff
    style Landing fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
```

### 2. Social Features

```mermaid
graph TB
    Player[👤 Player] --> ViewProfile[View Profile]
    Player --> EditProfile[Edit Profile]
    Player --> SendMessage[Send Chat Message]
    Player --> ViewFriends[View Friend List]
    Player --> AddFriend[Add Friend]
    
    ViewProfile --> Firestore[💾 Firestore]
    EditProfile --> Firestore
    ViewFriends --> Firestore
    AddFriend --> Firestore
    
    SendMessage --> RTDB[📊 Realtime Database]
    Player --> ReceiveMessage[Receive Messages]
    ReceiveMessage --> RTDB
    
    Player --> ViewUnread[View Unread Count]
    ViewUnread --> RTDB
    
    style Player fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style Firestore fill:#ff6348,stroke:#333,stroke-width:2px,color:#fff
    style RTDB fill:#ffa502,stroke:#333,stroke-width:2px,color:#fff
```

### 3. Game Lobby Flow

```mermaid
graph TD
    Player[👤 Player] --> EnterLobby[Enter Code Breaker Lobby]
    
    EnterLobby --> Choice{Action?}
    
    Choice -->|Host| CreateRoom[Create Room<br/>POST /api/rooms/create]
    Choice -->|Join| BrowseRooms[Browse Rooms<br/>GET /api/rooms/list]
    
    CreateRoom --> RelayServer[🌐 Relay Server]
    BrowseRooms --> RelayServer
    
    RelayServer --> RoomID[Receive room_id]
    
    BrowseRooms --> SelectRoom[Select Room]
    SelectRoom --> JoinRoom[Join Room<br/>POST /api/rooms/join]
    JoinRoom --> RelayServer
    
    RoomID --> WaitInRoom[Wait in Room]
    JoinRoom --> WaitInRoom
    
    WaitInRoom --> ConnectWS[Connect WebSocket<br/>WS /ws/relay/room_id]
    ConnectWS --> RelayServer
    
    style Player fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style RelayServer fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style CreateRoom fill:#f9ca24,stroke:#333,stroke-width:2px
    style BrowseRooms fill:#95e1d3,stroke:#333,stroke-width:2px
```

### 4. Host Operations

```mermaid
graph TD
    Host[👤 Host] --> CreateRoom[Create Room]
    CreateRoom --> SetSettings[Configure Room Settings]
    SetSettings --> WaitPlayer[Wait for Client to Join]
    
    WaitPlayer --> ClientJoins{Client Joins?}
    ClientJoins -->|No| WaitPlayer
    ClientJoins -->|Yes| ViewClient[View Client Info]
    
    ViewClient --> CheckReady{Client Ready?}
    CheckReady -->|No| CheckReady
    CheckReady -->|Yes| StartMatch[Start Match]
    
    StartMatch --> SendStart[Send game_start via Relay]
    SendStart --> RelayServer[🌐 Relay Server]
    
    Host --> KickOption[Kick Player - Optional]
    KickOption --> RemoveClient[Remove Client from Room]
    RemoveClient --> WaitPlayer
    
    style Host fill:#f9ca24,stroke:#333,stroke-width:2px,color:#000
    style StartMatch fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style RelayServer fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
```

### 5. Client Operations

```mermaid
graph TD
    Client[👤 Client] --> BrowseRooms[Browse Available Rooms]
    BrowseRooms --> SelectRoom[Select Room]
    SelectRoom --> JoinRoom[Join Room]
    
    JoinRoom --> ViewRoomInfo[View Room Details]
    ViewRoomInfo --> ConnectRelay[Connect to Relay]
    ConnectRelay --> RelayServer[🌐 Relay Server]
    
    ConnectRelay --> ToggleReady[Toggle Ready Status]
    ToggleReady --> SendReady[Send player_status via Relay]
    SendReady --> RelayServer
    
    ToggleReady --> WaitHostStart[Wait for Host to Start]
    WaitHostStart --> ReceiveStart{Host Started?}
    ReceiveStart -->|No| WaitHostStart
    ReceiveStart -->|Yes| TransitionArena[Transition to Arena]
    
    Client --> LeaveRoom[Leave Room - Optional]
    LeaveRoom --> RemoveSelf[Remove Self from Room]
    RemoveSelf --> RelayServer
    
    style Client fill:#95e1d3,stroke:#333,stroke-width:2px
    style ToggleReady fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style TransitionArena fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style RelayServer fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
```

### 6. Arena Gameplay

```mermaid
graph TD
    Player[👤 Player] --> EnterArena[Enter Arena]
    EnterArena --> Countdown[3-2-1 Countdown]
    Countdown --> ViewSnippet[View Code Snippet]
    
    ViewSnippet --> TypeCode[Type Code in LineEdit]
    TypeCode --> Submit[Press ENTER to Submit]
    
    Submit --> CheckAnswer{Correct?}
    
    CheckAnswer -->|Yes| AddScore[+100 Score]
    AddScore --> DealDamage[-10 Enemy HP]
    DealDamage --> Sparkles[Sparkle Effect]
    Sparkles --> SendDamage[Send damage via Relay]
    SendDamage --> RelayServer[🌐 Relay Server]
    
    CheckAnswer -->|No| SelfDamage[-8 Self HP]
    SelfDamage --> ShakeEffect[Shake + Explosion]
    ShakeEffect --> SendStats[Send stats_update via Relay]
    SendStats --> RelayServer
    
    RelayServer --> ReceiveDamage[Receive Opponent's Damage]
    ReceiveDamage --> UpdateHealth[Update Health Bar]
    
    SendDamage --> CheckEnd{Game End?}
    SendStats --> CheckEnd
    
    CheckEnd -->|HP = 0| GameOver[Game Over]
    CheckEnd -->|Time Out| GameOver
    CheckEnd -->|Continue| ViewSnippet
    
    GameOver --> ViewResults[View Results]
    
    style Player fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style EnterArena fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style AddScore fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style SelfDamage fill:#ff4757,stroke:#333,stroke-width:2px,color:#fff
    style RelayServer fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
```

### 7. Post-Game Flow

```mermaid
graph TD
    Player[👤 Player] --> GameOver[Game Over]
    GameOver --> ViewResults[View Match Results]
    
    ViewResults --> UpdateStats[Update Statistics]
    UpdateStats --> Firestore[💾 Firestore]
    
    ViewResults --> Choice{Next Action?}
    
    Choice -->|Rematch| SendRematch[Request Rematch]
    SendRematch --> RelayServer[🌐 Relay Server]
    RelayServer --> WaitOpponent{Opponent Agrees?}
    WaitOpponent -->|Yes| ReturnRoom[Return to Room]
    WaitOpponent -->|No| Lobby[Return to Lobby]
    
    Choice -->|Leave| LeaveRoom[Leave Room]
    LeaveRoom --> LeaveLogic{Who Leaves?}
    
    LeaveLogic -->|Host Alone| DeleteRoom[Delete Room]
    LeaveLogic -->|Client| RemoveClient[Remove Client]
    LeaveLogic -->|Host w/ Client| PromoteClient[Promote Client to Host]
    
    DeleteRoom --> RelayServer
    RemoveClient --> RelayServer
    PromoteClient --> RelayServer
    
    DeleteRoom --> Lobby
    RemoveClient --> Lobby
    
    Choice -->|View Stats| ViewProfile[View Profile & Statistics]
    ViewProfile --> Firestore
    
    style Player fill:#4ecdc4,stroke:#333,stroke-width:2px,color:#fff
    style ViewResults fill:#eb4d4b,stroke:#333,stroke-width:2px,color:#fff
    style Firestore fill:#ff6348,stroke:#333,stroke-width:2px,color:#fff
    style RelayServer fill:#48c774,stroke:#333,stroke-width:2px,color:#fff
    style Lobby fill:#95e1d3,stroke:#333,stroke-width:2px
```

---

## Actor Descriptions

| Actor | Role | Capabilities |
|-------|------|--------------|
| **Guest User** | Unauthenticated visitor | Can sign up or login only |
| **Registered Player** | Authenticated user | Access all social features, browse lobbies, view profile |
| **Game Host** | Room creator | Create rooms, configure settings, start matches, kick players |
| **Game Client** | Room joiner | Join rooms, toggle ready status, participate in matches |

---

## Use Case Priority Matrix

### Critical (Must Have)
- ✅ UC1: Sign Up
- ✅ UC2: Login with Email
- ✅ UC3: Login with Google
- ✅ UC12: Browse Available Rooms
- ✅ UC13: Create Game Room
- ✅ UC14: Join Game Room
- ✅ UC19: Start Match
- ✅ UC24-32: Core Gameplay

### High Priority (Should Have)
- ✅ UC5: View Profile
- ✅ UC9: Send Chat Message
- ✅ UC10: Receive Chat Message
- ✅ UC15: Leave Room
- ✅ UC33: View Game Results
- ✅ UC34: Request Rematch

### Medium Priority (Nice to Have)
- ⏳ UC6: Edit Profile
- ⏳ UC7: Add Friend
- ⏳ UC8: View Friend List
- ⏳ UC11: View Unread Messages
- ⏳ UC36: View Statistics

### Future Enhancements
- 🔮 UC20: Kick Player
- 🔮 Tournament Mode
- 🔮 Ranked Matches
- 🔮 Achievements System

---

## System Boundaries

### Client-Side (Godot)
- Authentication UI
- Social features UI
- Lobby browser
- Room management
- Arena gameplay
- Real-time rendering

### Server-Side (Render.com)
- Room registry (in-memory)
- WebSocket relay
- REST API endpoints
- Heartbeat monitoring

### External Services
- Firebase Auth (authentication)
- Firestore (user profiles, stats)
- Realtime Database (chat, presence)

---

## Import Instructions for app.diagrams.net

1. Go to **https://app.diagrams.net/**
2. Click **Arrange → Insert → Advanced → Mermaid**
3. Copy ONE diagram from above (without ` ```mermaid ` wrapper)
4. Click **Insert**
5. Diagram becomes editable!

**Note:** The main "Complete System Use Case Diagram" provides a high-level overview, while the detailed diagrams show specific user flows for each feature area.
