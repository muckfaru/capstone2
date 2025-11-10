# Code Breaker Relay Architecture (Option B)

## 🏗️ System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Render.com Cloud Server                           │
│                  https://codebreaker-lobby.onrender.com              │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │              Express.js Server (server.js)                  │    │
│  │                                                              │    │
│  │  📡 HTTP REST API                 🔌 WebSocket Relay       │    │
│  │  ├─ POST /api/rooms/create        ├─ /ws/relay/:room_id    │    │
│  │  ├─ GET  /api/rooms/list          │                         │    │
│  │  ├─ POST /api/rooms/:id/join      │  ┌──────────────────┐  │    │
│  │  ├─ POST /api/rooms/:id/leave     │  │  Room: abc123    │  │    │
│  │  └─ POST /api/rooms/:id/heartbeat │  │  Player 1 ←→ 2   │  │    │
│  │                                    │  └──────────────────┘  │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
         ▲                                           ▲
         │ HTTP/HTTPS                                │ WebSocket
         │ (Lobby ops)                               │ (Gameplay)
         │                                           │
    ┌────┴────┐                                 ┌────┴────┐
    │         │                                 │         │
┌───▼─────────▼───┐                     ┌───────▼─────────▼───┐
│   PC (mark2)     │                     │ Laptop (Mark123456) │
│   WiFi Network   │                     │   Mobile Data       │
│                  │                     │                     │
│  Godot Client    │                     │   Godot Client      │
│  ├─ Lobby        │◄───── See room ────►│   ├─ Lobby          │
│  ├─ Room         │                     │   ├─ Room           │
│  └─ Arena        │                     │   └─ Arena          │
└──────────────────┘                     └─────────────────────┘
```

## 🔄 Connection Flow

### Step 1: Room Creation (PC)
```
PC → Render Server
POST /api/rooms/create
{
  "host_id": "YTai...",
  "host_username": "mark2",
  "room_name": "mark2's room"
  // No IP/port needed!
}

Response: {"room_id": "room_abc123"}
```

### Step 2: Room Discovery (Laptop)
```
Laptop → Render Server
GET /api/rooms/list

Response: {
  "rooms": [
    {
      "room_id": "room_abc123",
      "room_name": "mark2's room",
      "host": {"username": "mark2"},
      "current_players": 1
    }
  ]
}
```

### Step 3: WebSocket Relay Connection
```
PC establishes WebSocket:
wss://codebreaker-lobby.onrender.com/ws/relay/room_abc123?player_id=YTai...&username=mark2

Laptop establishes WebSocket:
wss://codebreaker-lobby.onrender.com/ws/relay/room_abc123?player_id=XYZ...&username=Mark123456

Server now has 2 connections for room_abc123:
┌─────────────────────────────────────┐
│  Relay Server (room_abc123)         │
│                                     │
│  connections = [                    │
│    { player_id: "YTai...", ws: PC } │
│    { player_id: "XYZ...", ws: Laptop }│
│  ]                                  │
└─────────────────────────────────────┘
```

### Step 4: Gameplay Message Relay
```
PC sends message:
{
  "type": "game_action",
  "action": "word_typed",
  "data": { "word": "hello", "score": 3 }
}

Server receives from PC
↓
Server broadcasts to ALL OTHER players in room
↓
Laptop receives message

Laptop can respond:
{
  "type": "game_action", 
  "action": "word_typed",
  "data": { "word": "world", "score": 3 }
}
```

## 📁 Key Files

### Server Side
```
server/server.js
├─ Lines 45-120:  POST /api/rooms/create (optional IP/port)
├─ Lines 450-580: WebSocket relay endpoint
└─ Lines 560-575: broadcastToRoom() function
```

### Client Side
```
script/WebSocketRelayClient.gd
├─ connect_to_relay()    - Establish WS connection
├─ send_message()        - Send to other players via relay
├─ _process()            - Poll WS, receive messages
└─ Signals: connected_to_relay, message_received

script/code_breaker_room.gd
├─ _setup_relay_connection()  - Create relay client
├─ _on_relay_connected()      - Handle connection success
└─ _on_relay_message_received() - Handle game messages

script/code_breaker_lobby.gd
└─ _create_room_and_enter()   - Register room (no IP/port)
```

## 🎮 Message Types

### Connection Messages (auto by server)
```json
{
  "type": "player_connected",
  "player_id": "XYZ...",
  "username": "Mark123456"
}

{
  "type": "player_disconnected",
  "player_id": "XYZ..."
}
```

### Game Action Messages (sent by clients)
```json
{
  "type": "game_action",
  "action": "word_typed",
  "data": {
    "word": "hello",
    "score": 3,
    "timestamp": 1699...
  }
}

{
  "type": "game_action",
  "action": "damage_dealt",
  "data": {
    "damage": 2,
    "target": "opponent"
  }
}
```

## ⚡ Advantages vs Direct P2P (Option A)

| Feature | Option A (Direct P2P) | Option B (Relay) ✅ |
|---------|----------------------|---------------------|
| Port Forwarding | ❌ Required | ✅ Not needed |
| NAT Traversal | ❌ Complex | ✅ Simple |
| Firewall Issues | ❌ Common | ✅ Rare |
| Mobile Data | ❌ Often blocked | ✅ Works |
| Cross-Network | ❌ Difficult | ✅ Easy |
| Setup Time | ⏱️ 5-10 min | ⚡ Instant |
| Latency | 🚀 20-50ms | 📡 70-150ms |

## 🔧 Configuration

```gdscript
# script/MultiplayerConfig.gd
var current_mode: Mode = Mode.PRODUCTION

# URLs:
# - LOCALHOST: http://localhost:8080 (local testing)
# - PRODUCTION: https://codebreaker-lobby.onrender.com (deployed)

# WebSocket automatically converts:
# https:// → wss://
# http://  → ws://
```

## 🧪 Testing Checklist

- [x] Server accepts room creation without IP/port
- [x] WebSocket endpoint active at /ws/relay/:room_id
- [ ] PC creates room, sees "✅ Connected to relay!"
- [ ] Laptop joins room from different network
- [ ] Both players see each other in room
- [ ] Messages relay between players
- [ ] Game actions sync (typing, damage, etc.)

---

**Current Status:** Server deployed, client ready for testing! 🚀
