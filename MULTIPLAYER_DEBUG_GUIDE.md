# Debugging MultiplayerAPI Connection Issues

## What Was the Problem?

The arena was stuck in "Waiting for client to connect..." because:
1. ❌ Both players transition to arena simultaneously
2. ❌ P2P WebSocket connection wasn't fully established before scene change
3. ❌ No timeout or error handling for failed connections

## Fixes Applied

### 1. `code_breaker_room.gd` - Better Connection Verification
- ✅ Increased timeout to 15 seconds
- ✅ Added progress logging every 2 seconds
- ✅ Return to lobby if connection fails
- ✅ Verify multiplayer peer is not null before transitioning

### 2. `code_breaker_arena.gd` - Connection Validation
- ✅ Check `multiplayer.multiplayer_peer != null` on startup
- ✅ Log peer ID and connected peers
- ✅ Added 15-second timeout for client connection (host side)
- ✅ Return to room if connection fails

### 3. `MultiplayerManager.gd` - Better Logging
- ✅ Clearer connection status messages

## How to Test

### Step 1: Check Console for Connection Flow

**Expected Host Logs:**
```
[CodeBreakerRoom] Setting up multiplayer peer...
[MultiplayerManager] Setting up as host on port 9999
[MultiplayerManager] Host server created on port 9999
[MultiplayerManager] Waiting for client to connect...
[MultiplayerManager] Multiplayer connection ready!
[CodeBreakerRoom] Multiplayer peer connected! Peer ID: 1
[CodeBreakerArena] Multiplayer Arena starting
[CodeBreakerArena] Multiplayer peer active. My ID: 1
[Arena] Waiting for client to connect... (0/30)
[Arena] Peer connected: 2  ← CLIENT JOINED
[Arena] Client connected! Starting game...
```

**Expected Client Logs:**
```
[NetworkDiscovery] Host IP received: 192.168.1.X
[CodeBreakerRoom] Setting up multiplayer peer...
[MultiplayerManager] Connecting to host: 192.168.1.X:9999
[MultiplayerManager] Successfully connected to server
[CodeBreakerRoom] Multiplayer peer connected! Peer ID: 2
[CodeBreakerArena] Multiplayer Arena starting
[CodeBreakerArena] Multiplayer peer active. My ID: 2
[Arena] Connected to server (host)
[Arena] Received code snippet: XX chars
```

### Step 2: Common Issues & Solutions

#### Issue: "No multiplayer peer set!"
**Cause:** Connection timeout in room  
**Solution:**
- Check firewall allows port 9999
- Verify both on same network
- Check host IP was published to RTDB

#### Issue: "Waiting for client to connect... (timeout)"
**Cause:** Client can't reach host  
**Solution:**
- Verify host's IP is reachable: `ping <host_ip>`
- Check host created server successfully
- Try increasing timeout in `code_breaker_room.gd` line 503

#### Issue: "Connection failed: X"
**Cause:** WebSocket creation error  
**Solution:**
- Code X = connection error type
- Check Godot console for specific error
- Verify no other program using port 9999

### Step 3: Manual Debug Test

If automatic connection fails, you can test manually:

#### Option A: Use Localhost (Same Computer)
In `script/NetworkDiscovery.gd`, hardcode:
```gdscript
func get_local_network_ip() -> String:
    return "127.0.0.1"  # Force localhost
```

#### Option B: Hardcode Client Connection
In `script/code_breaker_room.gd` line ~495, replace:
```gdscript
var success = mp_manager.setup_client(ip_data["ip"], 9999)
```
With:
```gdscript
var success = mp_manager.setup_client("192.168.1.X", 9999)  # Host's IP
```

### Step 4: Verify Port is Open

**Windows (Host):**
```powershell
# Check if port 9999 is listening
netstat -an | Select-String "9999"

# Expected output:
# TCP    0.0.0.0:9999    0.0.0.0:0    LISTENING
```

**Allow in Firewall:**
```powershell
New-NetFirewallRule -DisplayName "Godot P2P" -Direction Inbound -LocalPort 9999 -Protocol TCP -Action Allow
```

## Network Requirements

### LAN Setup:
- ✅ Both on same WiFi/network
- ✅ Host IP format: `192.168.X.X` or `10.X.X.X`
- ✅ Firewall allows incoming TCP port 9999
- ✅ Router allows local P2P communication

### Internet Play (Not Yet Supported):
- ❌ Requires port forwarding or relay server
- ❌ Or migrate to WebRTC for NAT traversal

## Quick Checklist

Before starting a match:
- [ ] Both players logged in
- [ ] Host creates room successfully
- [ ] Client sees and joins room
- [ ] Console shows "[MultiplayerManager]" logs
- [ ] No errors in red
- [ ] Host presses START
- [ ] Both enter arena within 5 seconds

## Still Not Working?

1. **Check Godot version**: Must be 4.4+ (WebSocketMultiplayerPeer requires it)
2. **Restart Godot**: Clear cached scenes
3. **Test with localhost first**: Both instances on same computer
4. **Check RTDB**: Verify `network_info` exists under room
5. **Increase timeouts**: Edit values in room script
6. **Enable verbose logging**: Add more `print()` statements

---

**Most Common Fix:** Make sure firewall isn't blocking port 9999 on the host computer!
