const express = require('express');
const expressWs = require('express-ws');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');

const app = express();
expressWs(app);

// Middleware
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 8080;

// Store active game rooms (lobby architecture)
// rooms = Map<room_id, RoomData>
const rooms = new Map();
const players = new Map();

// Room cleanup interval (remove inactive rooms every 60s)
setInterval(() => {
  const now = Date.now();
  for (const [room_id, room] of rooms.entries()) {
    // Remove rooms with no heartbeat for 90 seconds
    if (now - room.last_heartbeat > 90000) {
      console.log(`[Cleanup] Removing inactive room: ${room_id}`);
      rooms.delete(room_id);
    }
  }
}, 60000);

/**
 * =============================================================================
 * LOBBY SERVER API (Option A: Pure Direct Connection)
 * =============================================================================
 * 
 * Architecture:
 * - Lobby server stores room list with host PUBLIC IP + PORT
 * - Hosts create ENet servers on their PCs (with port forwarding)
 * - Clients get host connection info from lobby, connect directly
 * - No relay server needed (direct P2P via ENet)
 */

/**
 * POST /api/rooms/create
 * Create a new game room
 * 
 * Body: {
 *   host_id: "uid123",
 *   host_username: "PlayerName",
 *   host_avatar: "avatar1.png",
 *   host_level: 5,
 *   room_name: "My Room",
 *   game_type: "code_breaker",
 *   public_ip: "203.x.x.x",   // OPTIONAL: For Option A (Direct P2P)
 *   port: 7777,                // OPTIONAL: For Option A (Direct P2P)
 *   is_lan: false              // OPTIONAL: true if LAN only
 * }
 * 
 * Response: {
 *   room_id: "room_abc123",
 *   created_at: <timestamp>
 * }
 */
app.post('/api/rooms/create', (req, res) => {
  const {
    host_id,
    host_username,
    host_avatar,
    host_level,
    room_name,
    game_type,
    public_ip,
    port,
    is_lan
  } = req.body;

  // Validate required fields (Option B: Relay - no IP/port needed)
  if (!host_id || !host_username || !room_name) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['host_id', 'host_username', 'room_name']
    });
  }

  // Generate unique room ID
  const room_id = `room_${uuidv4().substring(0, 8)}`;
  const now = Date.now();

  // Create room data (Option B: public_ip/port optional)
  const room_data = {
    room_id,
    room_name,
    game_type: game_type || 'code_breaker',
    host: {
      player_id: host_id,
      username: host_username,
      avatar: host_avatar || 'default.png',
      level: host_level || 1,
      public_ip: public_ip || null,       // Optional for relay
      port: port || null,                 // Optional for relay
      is_lan: is_lan || false
    },
    client: null,              // No client yet
    status: 'waiting',         // waiting | in_game | finished
    max_players: 2,
    current_players: 1,
    created_at: now,
    last_heartbeat: now
  };

  rooms.set(room_id, room_data);

  const connection_info = public_ip && port ? `at ${public_ip}:${port}` : '(relay mode)';
  console.log(`[Lobby] Room created: ${room_id} by ${host_username} ${connection_info}`);

  res.json({
    room_id,
    created_at: now
  });
});

/**
 * GET /api/rooms/list
 * Get list of all active rooms (waiting or in_game)
 * 
 * Response: {
 *   rooms: [
 *     {
 *       room_id: "...",
 *       room_name: "...",
 *       game_type: "code_breaker",
 *       host: { username, avatar, level },
 *       status: "waiting",
 *       current_players: 1,
 *       max_players: 2,
 *       is_lan: false,
 *       created_at: <timestamp>
 *     }
 *   ],
 *   total: 5
 * }
 */
app.get('/api/rooms/list', (req, res) => {
  const active_rooms = Array.from(rooms.values())
    .filter(room => room.status === 'waiting' || room.status === 'in_game')
    .map(room => ({
      room_id: room.room_id,
      room_name: room.room_name,
      game_type: room.game_type,
      host: {
        username: room.host.username,
        avatar: room.host.avatar,
        level: room.host.level
      },
      status: room.status,
      current_players: room.current_players,
      max_players: room.max_players,
      is_lan: room.host.is_lan,
      created_at: room.created_at
    }));

  res.json({
    rooms: active_rooms,
    total: active_rooms.length
  });
});

/**
 * GET /api/rooms/:room_id
 * Get detailed information about a specific room
 * Used for polling room state from within the room scene
 * 
 * Response: {
 *   room_id: "...",
 *   room_name: "...",
 *   game_type: "code_breaker",
 *   host: { uid, username, avatar, level, status, public_ip, port, is_lan },
 *   client: { uid, username, avatar, level, status } | null,
 *   status: "waiting",
 *   current_players: 1,
 *   max_players: 2,
 *   created_at: <timestamp>,
 *   last_heartbeat: <timestamp>
 * }
 * OR 404: { error: "Room not found" }
 */
app.get('/api/rooms/:room_id', (req, res) => {
  const { room_id } = req.params;

  // Check if room exists
  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found',
      room_id
    });
  }

  // Return full room data
  res.json({
    room_id: room.room_id,
    room_name: room.room_name,
    game_type: room.game_type,
    host: room.host,
    client: room.client,
    status: room.status,
    current_players: room.current_players,
    max_players: room.max_players,
    created_at: room.created_at,
    last_heartbeat: room.last_heartbeat
  });
});

/**
 * POST /api/rooms/:room_id/join
 * Client joins a room and gets host connection info
 * 
 * Body: {
 *   client_id: "firebase_uid",
 *   client_username: "PlayerName",
 *   client_avatar: "avatar2.png",
 *   client_level: 3
 * }
 * 
 * Response: {
 *   host_ip: "203.x.x.x",
 *   host_port: 7777,
 *   host_username: "HostPlayer",
 *   room_name: "My Room"
 * }
 */
app.post('/api/rooms/:room_id/join', (req, res) => {
  const { room_id } = req.params;
  const { client_id, client_username, client_avatar, client_level } = req.body;

  // Validate
  if (!client_id || !client_username) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['client_id', 'client_username']
    });
  }

  // Check if room exists
  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found',
      room_id
    });
  }

  // Check if room is full
  if (room.client) {
    return res.status(400).json({
      error: 'Room is full'
    });
  }

  // Check if room is still waiting
  if (room.status !== 'waiting') {
    return res.status(400).json({
      error: 'Room is not accepting players',
      status: room.status
    });
  }

  // Add client to room
  room.client = {
    player_id: client_id,
    username: client_username,
    avatar: client_avatar || 'default.png',
    level: client_level || 1
  };
  room.current_players = 2;
  room.last_heartbeat = Date.now();

  console.log(`[Lobby] ${client_username} joined room ${room_id}`);

  // Return host connection info
  res.json({
    host_ip: room.host.public_ip,
    host_port: room.host.port,
    host_username: room.host.username,
    room_name: room.room_name,
    is_lan: room.host.is_lan
  });
});

/**
 * POST /api/rooms/:room_id/heartbeat
 * Host sends periodic heartbeat to keep room alive
 * 
 * Response: { ok: true }
 */
app.post('/api/rooms/:room_id/heartbeat', (req, res) => {
  const { room_id } = req.params;

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found'
    });
  }

  room.last_heartbeat = Date.now();
  res.json({ ok: true });
});

/**
 * POST /api/rooms/:room_id/status
 * Update room status (e.g., waiting → in_game → finished)
 * 
 * Body: { status: "in_game" | "finished" }
 */
app.post('/api/rooms/:room_id/status', (req, res) => {
  const { room_id } = req.params;
  const { status } = req.body;

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found'
    });
  }

  if (!['waiting', 'in_game', 'finished'].includes(status)) {
    return res.status(400).json({
      error: 'Invalid status',
      valid: ['waiting', 'in_game', 'finished']
    });
  }

  room.status = status;
  room.last_heartbeat = Date.now();

  console.log(`[Lobby] Room ${room_id} status: ${status}`);

  res.json({ ok: true });
});

/**
 * POST /api/rooms/:room_id/ready
 * Update player ready status
 * Body: { player_id: "uid", ready: true/false }
 */
app.post('/api/rooms/:room_id/ready', (req, res) => {
  const { room_id } = req.params;
  const { player_id, ready } = req.body;

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found'
    });
  }

  // Update ready status for host or client
  if (room.host && room.host.player_id === player_id) {
    room.host.ready = ready;
    console.log(`[Lobby] Host ${room.host.username} ready: ${ready}`);
  } else if (room.client && room.client.player_id === player_id) {
    room.client.ready = ready;
    console.log(`[Lobby] Client ${room.client.username} ready: ${ready}`);
  } else {
    return res.status(404).json({
      error: 'Player not found in room'
    });
  }

  room.last_heartbeat = Date.now();

  res.json({ ok: true });
});

/**
 * POST /api/rooms/:room_id/leave
 * Player leaves the room (with host promotion logic)
 * Request body: { player_id: string }
 * 
 * Scenarios:
 * 1. Host leaves + client exists → Promote client to host
 * 2. Host leaves + no client → Delete room
 * 3. Client leaves → Remove client
 */
app.post('/api/rooms/:room_id/leave', (req, res) => {
  const { room_id } = req.params;
  const { player_id } = req.body;

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found'
    });
  }

  const is_host = room.host && room.host.player_id === player_id;
  const is_client = room.client && room.client.player_id === player_id;

  if (is_host) {
    console.log(`[Lobby] Host ${room.host.username} leaving room ${room_id}`);
    
    if (room.client) {
      // SCENARIO 1: Promote client to host
      console.log(`[Lobby] Promoting ${room.client.username} to host`);
      const new_host = room.client;
      room.host = new_host;
      room.client = null;
      room.current_players = 1;
      room.last_heartbeat = Date.now();
      
      // Send relay notification to new host about promotion
      broadcastToRoom(room_id, {
        type: 'host_promotion',
        new_host_id: new_host.player_id,
        new_host_username: new_host.username,
        old_host_id: player_id,
        message: 'You are now the host!'
      });
      
      res.json({ 
        ok: true, 
        promoted_to_host: true,
        new_host_id: new_host.player_id,
        message: 'You are now the host'
      });
    } else {
      // SCENARIO 2: Host is only player, delete room
      rooms.delete(room_id);
      console.log(`[Lobby] Room deleted (host left, no client): ${room_id}`);
      
      res.json({ 
        ok: true, 
        room_deleted: true,
        message: 'Room closed'
      });
    }
  } else if (is_client) {
    // SCENARIO 3: Client leaves
    console.log(`[Lobby] Client ${room.client.username} left room ${room_id}`);
    const client_username = room.client.username;
    room.client = null;
    room.current_players = 1;
    room.last_heartbeat = Date.now();
    
    // Notify host via relay
    broadcastToRoom(room_id, {
      type: 'player_left',
      player_id: player_id,
      username: client_username,
      message: 'Client has left the room'
    });
    
    res.json({ 
      ok: true,
      message: 'Left room successfully'
    });
  } else {
    res.status(404).json({
      error: 'Player not found in room'
    });
  }
});

/**
 * DELETE /api/rooms/:room_id
 * Host closes/deletes the room
 */
app.delete('/api/rooms/:room_id', (req, res) => {
  const { room_id } = req.params;

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found'
    });
  }

  rooms.delete(room_id);
  console.log(`[Lobby] Room deleted: ${room_id}`);

  res.json({ ok: true });
});

/**
 * =============================================================================
 * HEALTH & STATS ENDPOINTS
 * =============================================================================
 */

app.get('/', (req, res) => {
  res.json({
    service: 'Code Breaker Lobby Server',
    service: 'Code Breaker Lobby Server',
    status: 'running',
    version: '2.0.0 - Pure Direct Architecture',
    architecture: 'Lobby Server + Direct P2P (ENet)',
    endpoints: {
      'POST /api/rooms/create': 'Create new room (host registration)',
      'GET /api/rooms/list': 'List all active rooms',
      'POST /api/rooms/:id/join': 'Join room (get host IP)',
      'POST /api/rooms/:id/heartbeat': 'Keep room alive',
      'POST /api/rooms/:id/status': 'Update room status',
      'DELETE /api/rooms/:id': 'Delete room',
      '/health': 'Health check',
      '/stats': 'Server statistics'
    }
  });
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  const active_rooms = Array.from(rooms.values()).filter(r => r.status !== 'finished');
  const waiting_rooms = Array.from(rooms.values()).filter(r => r.status === 'waiting');
  const in_game_rooms = Array.from(rooms.values()).filter(r => r.status === 'in_game');

  res.json({
    status: 'ok',
    uptime: process.uptime(),
    rooms: {
      total: rooms.size,
      active: active_rooms.length,
      waiting: waiting_rooms.length,
      in_game: in_game_rooms.length
    },
    timestamp: new Date().toISOString()
  });
});

/**
 * Simple ping endpoint to wake up server from sleep
 */
app.get('/ping', (req, res) => {
  res.json({ 
    status: 'pong',
    timestamp: Date.now()
  });
});

/**
 * Stats endpoint
 */
app.get('/stats', (req, res) => {
  res.json({
    rooms: Array.from(rooms.entries()).map(([roomId, room]) => ({
      roomId,
      hasHost: !!room.host,
      hasClient: !!room.client,
      createdAt: room.createdAt
    })),
    totalPlayers: players.size,
    timestamp: new Date().toISOString()
  });
});

/**
 * =============================================================================
 * WEBSOCKET RELAY FOR MULTIPLAYER GAMEPLAY (Option B Architecture)
 * =============================================================================
 * 
 * WebSocket endpoint: /ws/relay/:room_id
 * 
 * Flow:
 * 1. Both players connect to ws://server/ws/relay/<room_id>
 * 2. Server tracks connections per room
 * 3. When player sends message, relay to other player in same room
 * 4. Supports: game_action, ready_state, chat, etc.
 */

// Store WebSocket connections per room
// wsConnections = Map<room_id, Set<{ws, player_id, username}>>
const wsConnections = new Map();

app.ws('/ws/relay/:room_id', (ws, req) => {
  const { room_id } = req.params;
  const player_id = req.query.player_id || 'unknown';
  const username = req.query.username || 'Player';
  
  console.log(`[WebSocket] ${username} (${player_id}) connecting to room ${room_id}`);
  
  // Get or create connection set for this room
  if (!wsConnections.has(room_id)) {
    wsConnections.set(room_id, new Set());
  }
  
  const roomConnections = wsConnections.get(room_id);

  // If the same player_id reconnects (e.g., reconnect from another device),
  // replace the old connection instead of rejecting due to room full.
  // This prevents the "stuck in loading / stuck waiting for snippet" split-brain.
  let replacedConnection = null;
  for (const existing of roomConnections) {
    if (existing.player_id === player_id) {
      replacedConnection = existing;
      break;
    }
  }
  if (replacedConnection) {
    console.log(`[WebSocket] Replacing existing session for ${username} (${player_id}) in room ${room_id}`);
    // Mark so the old socket's close handler won't broadcast a disconnect.
    replacedConnection.replaced = true;
    try {
      replacedConnection.ws.close();
    } catch (e) {
      // ignore
    }
    roomConnections.delete(replacedConnection);
  }
  
  // Check if room is full (max 2 players)
  if (roomConnections.size >= 2) {
    console.log(`[WebSocket] Room ${room_id} is full, rejecting connection`);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Room is full'
    }));
    ws.close();
    return;
  }
  
  // Add connection to room
  const connection = { ws, player_id, username };
  roomConnections.add(connection);
  
  console.log(`[WebSocket] ${username} joined room ${room_id}. Players in room: ${roomConnections.size}/2`);
  
  // Notify all players in room about connection
  broadcastToRoom(room_id, {
    type: 'player_connected',
    player_id: player_id,
    username: username,
    players_count: roomConnections.size
  }, connection);
  
  // Handle incoming messages
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log(`[WebSocket] ${username}: ${data.type}`);
      
      // Relay message to other player(s) in the same room
      broadcastToRoom(room_id, data, connection);
      
    } catch (error) {
      console.error(`[WebSocket] Invalid message from ${username}:`, error);
    }
  });
  
  // Handle disconnect
  ws.on('close', () => {
    console.log(`[WebSocket] ${username} disconnected from room ${room_id}`);
    roomConnections.delete(connection);

    // If this socket was replaced by a reconnect, don't broadcast a disconnect.
    if (!connection.replaced) {
      // Notify other players
      broadcastToRoom(room_id, {
        type: 'player_disconnected',
        player_id: player_id,
        username: username,
        players_count: roomConnections.size
      });
    }
    
    // Clean up empty rooms
    if (roomConnections.size === 0) {
      console.log(`[WebSocket] Room ${room_id} is empty, removing`);
      wsConnections.delete(room_id);
    }
  });
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connected',
    room_id: room_id,
    player_id: player_id,
    players_count: roomConnections.size
  }));
});

/**
 * Broadcast message to all players in a room except sender
 */
function broadcastToRoom(room_id, message, excludeConnection = null) {
  const roomConnections = wsConnections.get(room_id);
  if (!roomConnections) return;
  
  const messageStr = JSON.stringify(message);
  
  for (const connection of roomConnections) {
    if (connection !== excludeConnection && connection.ws.readyState === 1) { // 1 = OPEN
      connection.ws.send(messageStr);
    }
  }
}

/**
 * =============================================================================
 * SERVER START
 * =============================================================================
 */

// Start server
// Bind to 0.0.0.0 to accept connections from any network interface
app.listen(PORT, '0.0.0.0', () => {
  const os = require('os');
  const networkInterfaces = os.networkInterfaces();
  let localIP = 'localhost';
  
  // Find local IP address
  for (const name of Object.keys(networkInterfaces)) {
    for (const net of networkInterfaces[name]) {
      // Skip internal and non-IPv4 addresses
      if (net.family === 'IPv4' && !net.internal) {
        localIP = net.address;
        break;
      }
    }
  }
  
  console.log(`\n🎮 Code Breaker Lobby Server v2.1`);
  console.log(`   Architecture: WebSocket Relay (Option B)`);
  console.log(`   Port: ${PORT}`);
  console.log(`   Local Network: http://${localIP}:${PORT}`);
  console.log(`\n📡 HTTP API Endpoints:`);
  console.log(`   POST   http://${localIP}:${PORT}/api/rooms/create`);
  console.log(`   GET    http://${localIP}:${PORT}/api/rooms/list`);
  console.log(`   GET    http://${localIP}:${PORT}/api/rooms/:id`);
  console.log(`   POST   http://${localIP}:${PORT}/api/rooms/:id/join`);
  console.log(`   POST   http://${localIP}:${PORT}/api/rooms/:id/leave`);
  console.log(`   POST   http://${localIP}:${PORT}/api/rooms/:id/heartbeat`);
  console.log(`   DELETE http://${localIP}:${PORT}/api/rooms/:id`);
  console.log(`\n🔌 WebSocket Relay:`);
  console.log(`   WS     ws://${localIP}:${PORT}/ws/relay/:room_id`);
  console.log(`\n🔍 Monitoring:`);
  console.log(`   GET    http://${localIP}:${PORT}/health`);
  console.log(`   GET    http://${localIP}:${PORT}/stats`);
  console.log(`\n💡 Access from other devices on same WiFi:`);
  console.log(`   Use: http://${localIP}:${PORT}`);
  console.log(`   WebSocket: ws://${localIP}:${PORT}`);
  console.log(`\n✅ Server ready with WebSocket relay!\n`);
});
