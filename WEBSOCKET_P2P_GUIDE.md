# WebSocket P2P Implementation for Code Breaker Arena

## Overview

Replaced HTTP polling with **real-time WebSocket P2P communication** for the Code Breaker arena. This provides:
- ✅ **Instant game state sync** (no 1s delay)
- ✅ **Signaling server** for player discovery
- ✅ **Direct P2P connection** between players
- ✅ **Fallback to RTDB** if WebSocket fails
- ✅ **Cloud-ready** (Render.com deployment)
- ✅ **JSON protocol** (readable, debuggable)

## Architecture

### Flow Diagram

```
Host & Client in Arena
    ↓
Both connect to Signaling Server (Node.js)
    ↓
Host: ws://signaling-server/ws/game (register as host)
Client: ws://signaling-server/ws/game (register as client)
    ↓
Signaling server detects both players ready
    ↓
Sends "start_game" message with opponent IP
    ↓
Both players establish Direct P2P WebSocket connection
    ↓
Real-time bidirectional game state sync
    ↓
If P2P fails → Fallback to signaling server relay
    ↓
If relay fails → Fallback to RTDB polling
```

## Message Protocol (JSON)

### Client → Server: Register

```json
{
  "type": "register",
  "room_id": "room123",
  "player_id": "firebase_uid",
  "username": "Player1",
  "is_host": true
}
```

### Client → Server: Ready

```json
{
  "type": "ready",
  "room_id": "room123"
}
```

### Client → Server/Opponent: Game Action

```json
{
  "type": "game_action",
  "room_id": "room123",
  "from_player": "firebase_uid",
  "action": {
    "score": 10,
    "health": 85,
    "guess": "ABCD",
    "timestamp": 1699123456
  }
}
```

### Client → Server: Ping (Heartbeat)

```json
{
  "type": "ping"
}
```

---

### Server → Client: Player Joined

```json
{
  "type": "player_joined",
  "opponent": {
    "username": "Player2",
    "player_id": "opponent_uid",
    "is_host": false
  }
}
```

### Server → Client: Start Game

```json
{
  "type": "start_game",
  "opponent_ip": "192.168.1.100",
  "game_start_time": 1699123456
}
```

### Server/Opponent → Client: Opponent Action

```json
{
  "type": "opponent_action",
  "action": {
    "score": 15,
    "health": 90,
    "guess": "XYZW"
  }
}
```

### Server → Client: Opponent Disconnect

```json
{
  "type": "opponent_disconnect"
}
```

### Server → Client: Error

```json
{
  "type": "error",
  "message": "Room not found"
}
```

---

### Server → Client: Pong

```json
{
  "type": "pong"
}
```

## File Structure

```
capstone2/
├── server/                          # Node.js signaling server
│   ├── package.json                # Dependencies
│   ├── server.js                   # Main signaling server
│   ├── .env.example                # Environment variables
│   └── RENDER_DEPLOYMENT.md        # Deployment guide
│
├── script/
│   ├── P2PWebSocketClient.gd       # WebSocket client (NEW)
│   ├── code_breaker_arena.gd       # Arena logic (UPDATED)
│   └── ...
│
└── scene/
    ├── code_breaker_arena.tscn
    └── ...
```

## Component Details

### 1. Node.js Signaling Server (`server/server.js`)

**Responsibilities:**
- Accept WebSocket connections from game clients
- Store player registration (room + player info)
- Detect when both players are ready
- Exchange opponent IP addresses
- Relay game actions if direct P2P unavailable
- Monitor heartbeat/keep-alive
- Clean up idle rooms after 5 minutes

**Key Functions:**
- `handleRegister()` - Register player in room
- `handleReady()` - Signal player readiness, initiate P2P
- `handleGameAction()` - Relay action to opponent
- `handleDisconnect()` - Clean up on disconnect
- `/health` endpoint - Check server status
- `/stats` endpoint - Monitor active rooms

**Features:**
- 30-second heartbeat (ping/pong)
- UUID generation for client tracking
- Auto-cleanup of empty rooms
- Error handling & logging

### 2. Godot P2P Client (`script/P2PWebSocketClient.gd`)

**Responsibilities:**
- Connect to signaling server via WebSocket
- Register current player
- Listen for opponent discovery
- Receive "start_game" signal with opponent info
- Attempt direct P2P connection
- Send/receive game actions
- Handle disconnection & fallback

**Signals:**
```gdscript
signal connection_established()
signal opponent_action_received(action: Dictionary)
signal opponent_disconnected()
signal connection_error(error: String)
```

**Key Methods:**
- `connect_to_game(room_id, player_id, username, is_host, use_production)` - Initial connection
- `send_game_action(action: Dictionary)` - Send to opponent
- `disconnect_game()` - Clean disconnect
- `get_connection_status()` - Current state
- `get_game_start_time()` - Fetch start time

**Features:**
- Automatic heartbeat every 30s
- Fallback to relay if direct P2P unavailable
- Binary & JSON protocol support
- Connection state tracking

### 3. Updated Arena Script (`script/code_breaker_arena.gd`)

**Changes from HTTP polling:**
- Replaced `_sync_poll_timer` (1s RTDB polling) with WebSocket
- Removed `_fetch_game_state()` (HTTP polling)
- Added `_setup_p2p_connection()` - Initialize WebSocket
- Added `_on_opponent_action()` - Handle real-time updates
- Added `_fallback_to_rtdb()` - Fallback mechanism
- Kept 100ms display timer (local countdown)

**Key Methods:**
- `_setup_p2p_connection()` - Initialize P2P client
- `_on_p2p_connected()` - Handle successful connection
- `_on_opponent_action()` - Receive opponent state
- `_on_opponent_disconnected()` - Handle disconnect
- `_on_p2p_error()` - Handle errors + fallback
- `send_player_action(score, health)` - API for game logic
- `_on_display_timer_timeout()` - Local countdown (100ms)
- `_fallback_to_rtdb()` - Fallback polling
- `_poll_rtdb_state()` - RTDB fallback polling

**Local Timer (100ms):**
```gdscript
func _on_display_timer_timeout() -> void:
	var elapsed = Time.get_unix_time_from_system() - _game_start_time
	var remaining = max(0.0, GAME_DURATION - elapsed)
	# Display MM:SS format (no network latency)
```

## Deployment Guide

### Local Testing

1. **Start Node.js server:**
   ```bash
   cd server
   npm install
   npm start
   ```
   Server runs on `ws://localhost:8080/ws/game`

2. **In Godot:** (default dev URL is used)
   ```gdscript
   const SIGNALING_SERVER_DEV = "ws://localhost:8080/ws/game"
   ```

3. **Open game in two Godot windows**
   - One as host, one as client
   - Both should connect and sync real-time

### Production Deployment (Render.com)

1. **Create Render Account**
   - Go to https://render.com
   - Sign up (free tier available)

2. **Deploy Server**
   - Click "New +" → "Web Service"
   - Connect GitHub (capstone2 repo)
   - **Name:** `code-breaker-p2p-signaling`
   - **Root:** `server`
   - **Runtime:** Node
   - **Build:** `npm install`
   - **Start:** `npm start`
   - **Environment:** PORT=8080, NODE_ENV=production

3. **Update Godot Config**
   ```gdscript
   const SIGNALING_SERVER_PROD = "wss://code-breaker-p2p-signaling.onrender.com/ws/game"
   
   func _setup_p2p_connection() -> void:
       _p2p_client.connect_to_game(
           _room_id, _player_id, username, _is_host,
           use_production: true  # Enable for production
       )
   ```

4. **Monitor**
   - Health: `https://code-breaker-p2p-signaling.onrender.com/health`
   - Stats: `https://code-breaker-p2p-signaling.onrender.com/stats`

### Render.com Notes

- **Free tier:** Spins down after 15 min inactivity (cold start ~30s)
- **Starter tier ($7/mo):** Always running, no cold starts
- For development, free tier is fine with client-side retry logic

## Fallback Strategy

### Tier 1: Direct P2P (Ideal)
- Zero-latency peer-to-peer
- Both players connect to each other directly
- Best performance

### Tier 2: Relay via Signaling Server
- If direct P2P fails, use signaling server as relay
- Game actions sent to server, forwarded to opponent
- ~50-100ms latency (server round-trip)

### Tier 3: RTDB Polling (Last Resort)
- If WebSocket fails completely, fall back to HTTP polling
- Every 1s fetch game state from RTDB
- ~1s latency
- Automatic activation with `_fallback_to_rtdb()`

## Game State Synchronization

### Real-time Action Flow

```
Host scores point:
  → send_player_action(score=10, health=100)
  → P2PWebSocketClient.send_game_action({score: 10, health: 100})
  → WebSocket message sent to signaling server
  → Server forwards to client
  → Client receives "opponent_action" signal
  → _on_opponent_action() updates UI instantly
```

### Local Display Timer

- **NOT synced via network** - runs locally
- Calculated from `game_start_time` (server timestamp)
- Updates every 100ms for smooth display
- Both clients converge to same time (within ±1s clock offset)

## Testing Checklist

- [ ] Server health check: `http://localhost:8080/health`
- [ ] Two clients can register in same room
- [ ] Both receive "player_joined" signal
- [ ] Both receive "start_game" signal with timestamp
- [ ] Score changes sync instantly
- [ ] Health bar updates instantly
- [ ] Timer counts down smoothly
- [ ] Disconnect handled gracefully
- [ ] Fallback to RTDB if server unavailable
- [ ] Production deployment on Render.com works

## Performance Metrics

| Metric | HTTP Polling | WebSocket |
|--------|--------------|-----------|
| Latency | ~1000ms | ~50-100ms |
| Update frequency | 1s (polling) | Real-time |
| Network usage | Higher (periodic requests) | Lower (event-driven) |
| Server load | Moderate | Lower |
| Connection stability | Stable | Requires heartbeat |

## Security Considerations

**Current Implementation (Development):**
- No authentication on signaling server
- No encryption (WS, not WSS in dev)
- Room IDs from game data (not secret)

**For Production:**
```
1. Use WSS (WebSocket Secure)
2. Validate Firebase auth token on server
3. Use Firebase ID token in WebSocket handshake
4. Implement rate limiting on signaling server
5. Add room password or secure token exchange
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Connection refused" | Server not running | `npm start` in server/ |
| "WebSocket closed" | Network issue or server down | Check `/health` endpoint |
| Long latency | Too many hops | Check opponent_ip is correct |
| Falls back to RTDB | P2P unavailable (NAT) | Use relay instead |
| Cold start on Render | Free tier | Use Starter tier or keep warm |

## Future Enhancements

1. **WebRTC for direct P2P**
   - True peer-to-peer with UDP
   - Lower latency than WebSocket relay
   - Requires TURN/STUN servers

2. **Message Compression**
   - Gzip JSON or binary protocol
   - Reduce bandwidth usage

3. **Automated Testing**
   - Load test signaling server
   - Test with 1000+ concurrent players

4. **Analytics**
   - Track connection success rates
   - Monitor latency distribution
   - Alert on server errors

5. **Rate Limiting**
   - Prevent spam/DOS
   - Throttle game action frequency

## Code Examples

### Sending Game Action from Arena

```gdscript
func send_player_action(score: int, health: int) -> void:
	"""Called by game logic when player scores or takes damage"""
	_local_score = score
	_local_health = health
	_send_game_action({
		"score": score,
		"health": health
	})
```

### Receiving Opponent Action

```gdscript
func _on_opponent_action(action: Dictionary) -> void:
	"""Real-time callback when opponent sends update"""
	_opponent_score = action.get("score", 0)
	_opponent_health = action.get("health", 100)
	_update_ui_display()  # Instant UI update
```

### Connection Management

```gdscript
func _on_p2p_error(error: String) -> void:
	"""Handle connection error with fallback"""
	print("WebSocket error: %s" % error)
	await get_tree().create_timer(2.0).timeout
	_fallback_to_rtdb()  # Switch to polling
```

## References

- Node.js Express-WS: https://github.com/HenningM/express-ws
- Godot WebSocketPeer: https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html
- Render.com Deployment: https://render.com/docs
