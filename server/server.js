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
 * Host creates a new room and registers their public IP
 * 
 * Body: {
 *   host_id: "firebase_uid",
 *   host_username: "PlayerName",
 *   host_avatar: "avatar1.png",
 *   host_level: 5,
 *   room_name: "My Room",
 *   game_type: "code_breaker",
 *   public_ip: "203.x.x.x",   // Host's public IP
 *   port: 7777,                 // Host's ENet server port
 *   is_lan: false               // true if LAN only (192.168.x.x)
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

  // Validate required fields
  if (!host_id || !host_username || !room_name || !public_ip || !port) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['host_id', 'host_username', 'room_name', 'public_ip', 'port']
    });
  }

  // Generate unique room ID
  const room_id = `room_${uuidv4().substring(0, 8)}`;
  const now = Date.now();

  // Create room data
  const room_data = {
    room_id,
    room_name,
    game_type: game_type || 'code_breaker',
    host: {
      player_id: host_id,
      username: host_username,
      avatar: host_avatar || 'default.png',
      level: host_level || 1,
      public_ip,
      port,
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

  console.log(`[Lobby] Room created: ${room_id} by ${host_username} at ${public_ip}:${port}`);

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

// Start server
app.listen(PORT, () => {
  console.log(`\n🎮 Code Breaker Lobby Server v2.0`);
  console.log(`   Architecture: Pure Direct P2P (ENet)`);
  console.log(`   Port: ${PORT}`);
  console.log(`\n📡 API Endpoints:`);
  console.log(`   POST   http://localhost:${PORT}/api/rooms/create`);
  console.log(`   GET    http://localhost:${PORT}/api/rooms/list`);
  console.log(`   GET    http://localhost:${PORT}/api/rooms/:id`);
  console.log(`   POST   http://localhost:${PORT}/api/rooms/:id/join`);
  console.log(`   POST   http://localhost:${PORT}/api/rooms/:id/heartbeat`);
  console.log(`   DELETE http://localhost:${PORT}/api/rooms/:id`);
  console.log(`\n🔍 Monitoring:`);
  console.log(`   GET    http://localhost:${PORT}/health`);
  console.log(`   GET    http://localhost:${PORT}/stats`);
  console.log(`\n✅ Server ready!\n`);
});
