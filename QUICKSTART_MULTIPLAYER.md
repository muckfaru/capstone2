# Quick Start: Testing MultiplayerAPI Refactor

## Prerequisites
- Godot 4.4
- Two instances (Editor + Exported build, or two computers on same network)
- Firebase Auth credentials configured

## Local Testing (Same Computer)

### Step 1: Prepare Two Instances
```bash
# Terminal 1: Run Godot Editor
godot project.godot

# Terminal 2: Export and run executable
# Project → Export → Windows Desktop → Export Project
# Then run the .exe
```

### Step 2: Login Both Instances
- Use different accounts for each instance
- Or use test accounts:
  - Instance 1: host@test.com
  - Instance 2: client@test.com

### Step 3: Start a Match
**Instance 1 (Host):**
1. Go to Code Breaker Lobby
2. Click "CREATE ROOM"
3. Wait for client to join
4. Click "START MATCH"

**Instance 2 (Client):**
1. Go to Code Breaker Lobby
2. See host's room appear
3. Click "JOIN"
4. Click "READY"
5. Wait for host to start

### Step 4: Type Battle!
- A code snippet appears on screen
- Type it character-by-character
- Watch opponent's progress bar
- First to finish or highest score wins!

## LAN Testing (Two Computers)

### Network Setup
Both computers must be on **same network** (same WiFi or ethernet).

### Step 1: Find Host IP
On host computer:
```bash
# Windows
ipconfig

# Look for "IPv4 Address" like 192.168.1.X

# Linux/Mac
ifconfig

# Look for inet like 192.168.1.X
```

### Step 2: Update Code (Optional)
The new implementation auto-discovers host IP via RTDB, but if it fails:

Edit `script/code_breaker_room.gd` line ~495:
```gdscript
# Fallback IP if discovery fails
var success = mp_manager.setup_client("192.168.1.X", 9999)  # Use host's IP
```

### Step 3: Check Firewall
On host computer, allow incoming on port 9999:
```bash
# Windows Firewall
# Control Panel → Windows Defender Firewall → Advanced Settings
# Inbound Rules → New Rule → Port → TCP 9999 → Allow

# Linux (ufw)
sudo ufw allow 9999/tcp
```

### Step 4: Test Connection
Follow same steps as local testing above.

## Troubleshooting

### "Connection failed" Error
**Check:**
- Both on same network
- Firewall allows port 9999
- Host started server before client connected
- Check Godot console for `[MultiplayerManager]` logs

### "Failed to discover host IP"
**Solutions:**
1. Wait 10 seconds after host creates room (IP publishing delay)
2. Manually set IP in code (see LAN Testing Step 2)
3. Check RTDB has `network_info` node under room

### Opponent's Progress Not Updating
**Check:**
- `WSIndicator` is GREEN (top of arena)
- Console shows `[Arena] Peer connected: X`
- Try typing slower (verify local updates work first)

### "Multiplayer connection timeout"
**Solutions:**
1. Increase timeout in `code_breaker_room.gd` line ~506:
   ```gdscript
   var timeout = 20.0  # Increase from 10.0
   ```
2. Check host created server successfully
3. Verify network connectivity

## Debug Console Logs

### Expected Logs (Host)
```
[CodeBreakerRoom] Setting up multiplayer peer...
[MultiplayerManager] Setting up as host on port 9999
[MultiplayerManager] Host ready, waiting for client...
[NetworkDiscovery] Host IP published: 192.168.1.5:9999
[MultiplayerManager] Peer connected: 2
[CodeBreakerArena] Multiplayer Arena starting
[Arena] Peer connected: 2
[Arena] Client connected! Starting game...
```

### Expected Logs (Client)
```
[CodeBreakerRoom] Setting up multiplayer peer...
[NetworkDiscovery] Host IP received: 192.168.1.5
[MultiplayerManager] Connecting to host: 192.168.1.5:9999
[MultiplayerManager] Successfully connected to server
[CodeBreakerArena] Multiplayer Arena starting
[Arena] Connected to server (host)
[Arena] Received code snippet: 67 chars
```

## Performance Monitoring

### Check FPS
Press F3 in-game to show debug overlay.
- **Target**: 60 FPS
- **Min acceptable**: 30 FPS

### Network Stats
Watch `WSIndicator` color:
- 🟢 **Green**: Connected (good)
- 🟡 **Yellow**: Connecting (wait)
- 🔴 **Red**: Disconnected (error)

## Next Steps After Testing

1. **Verify typing sync**: Both players should see each other's progress update in real-time
2. **Test disconnect**: Close one instance, other should return to room after 3s
3. **Test rematch**: Return to lobby, create new room, repeat
4. **Measure latency**: Use ping tool to check network delay
5. **Report bugs**: Note console errors and steps to reproduce

## Known Issues (Current Build)

- [ ] Progress bars may lag slightly (interpolation not implemented)
- [ ] No reconnection if connection drops mid-game
- [ ] Host IP discovery may timeout on slow networks (increase timeout)
- [ ] No visual feedback for opponent keystrokes (coming soon)
- [ ] Code display doesn't highlight typed characters yet

## Success Indicators

✅ Both players see same code snippet  
✅ Typing updates opponent's progress bar within 1 second  
✅ Game ends when timer reaches 00:00  
✅ Winner/loser displayed correctly  
✅ Both return to room after match  

---

**Happy typing!** If you encounter issues not listed here, check `MULTIPLAYER_API_REFACTOR.md` for detailed architecture info.
