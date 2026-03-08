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

// ═══════════════════════════════════════════════════════════════════════════
// CyberQuiz — Quizizz-inspired quiz rooms (separate from game rooms)
// ═══════════════════════════════════════════════════════════════════════════
const quizRooms = new Map(); // Map<room_code, QuizRoomData>

// ═══════════════════════════════════════════════════════════════════════════
// GameMode — Teacher-created minigame rooms (students play & submit scores)
// ═══════════════════════════════════════════════════════════════════════════
const gameModeRooms = new Map(); // Map<room_code, GameModeRoomData>

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
  // CyberQuiz room cleanup (5 min timeout)
  for (const [code, qr] of quizRooms.entries()) {
    if (now - qr.last_heartbeat > 300000) {
      console.log(`[Cleanup] Removing inactive quiz room: ${code}`);
      quizRooms.delete(code);
    }
  }
  // GameMode room cleanup (5 min timeout)
  for (const [code, gr] of gameModeRooms.entries()) {
    if (now - gr.last_heartbeat > 300000) {
      console.log(`[Cleanup] Removing inactive game mode room: ${code}`);
      gameModeRooms.delete(code);
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
    host_card_bg,
    max_players,
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

  // Normalize/validate game_type so lobbies can filter reliably.
  const normalizedGameType = typeof game_type === 'string' ? game_type.trim().toLowerCase() : '';
  const allowedGameTypes = new Set(['code_breaker', 'akashic_tcg', 'defuse_trojan']);
  const finalGameType = allowedGameTypes.has(normalizedGameType) ? normalizedGameType : 'code_breaker';

  // Allow room size override for specific game types; clamp to [2..3] for now.
  const requestedMax = Number.isFinite(Number(max_players)) ? Number(max_players) : null;
  let finalMaxPlayers = requestedMax != null ? requestedMax : (finalGameType === 'defuse_trojan' ? 3 : 2);
  finalMaxPlayers = Math.max(2, Math.min(3, finalMaxPlayers));

  // Create room data (Option B: public_ip/port optional)
  const room_data = {
    room_id,
    room_name,
    game_type: finalGameType,
    host: {
      player_id: host_id,
      username: host_username,
      avatar: host_avatar || 'default.png',
      level: host_level || 1,
      card_bg: typeof host_card_bg === 'string' ? host_card_bg : '',
      public_ip: public_ip || null,       // Optional for relay
      port: port || null,                 // Optional for relay
      is_lan: is_lan || false
    },
    client: null,              // 2nd player slot (legacy)
    client2: null,             // 3rd player slot (used by defuse_trojan)
    status: 'waiting',         // waiting | in_game | finished
    game_start_time_ms: 0,     // scheduled start timestamp (server time, ms since epoch)
    max_players: finalMaxPlayers,
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
  const requestedType = typeof req.query.game_type === 'string' ? req.query.game_type.trim().toLowerCase() : '';

  const active_rooms = Array.from(rooms.values())
    .filter(room => room.status === 'waiting' || room.status === 'in_game')
    .filter(room => (requestedType ? String(room.game_type || '').toLowerCase() === requestedType : true))
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
    client2: room.client2,
    status: room.status,
    game_start_time_ms: room.game_start_time_ms || 0,
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
  const { client_id, client_username, client_avatar, client_level, client_card_bg } = req.body;

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
  const maxPlayers = typeof room.max_players === 'number' ? room.max_players : 2;
  const currentPlayers = Number(room.current_players || 1);
  if (currentPlayers >= maxPlayers) {
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

  // Add client to room (supports up to 3 players with client2)
  const joiningPlayer = {
    player_id: client_id,
    username: client_username,
    avatar: client_avatar || 'default.png',
    level: client_level || 1,
    card_bg: typeof client_card_bg === 'string' ? client_card_bg : ''
  };

  if (!room.client) {
    room.client = joiningPlayer;
  } else if (maxPlayers >= 3 && !room.client2) {
    room.client2 = joiningPlayer;
  } else {
    return res.status(400).json({
      error: 'Room is full'
    });
  }

  room.current_players = Math.min(maxPlayers, currentPlayers + 1);
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
  const { status, game_start_time_ms, game_start_in_ms } = req.body;

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
  // Optional: schedule a synchronized game start time.
  // Prefer server-authored timestamps via game_start_in_ms.
  if (typeof game_start_in_ms === 'number' && Number.isFinite(game_start_in_ms)) {
    const clamped = Math.max(0, Math.min(60000, Math.floor(game_start_in_ms)));
    room.game_start_time_ms = Date.now() + clamped;
  } else if (typeof game_start_time_ms === 'number' && Number.isFinite(game_start_time_ms)) {
    room.game_start_time_ms = Math.floor(game_start_time_ms);
  }
  room.last_heartbeat = Date.now();

  console.log(`[Lobby] Room ${room_id} status: ${status}`);

  res.json({ ok: true, game_start_time_ms: room.game_start_time_ms || 0 });
});

/**
 * POST /api/rooms/:room_id/cosmetics
 * Update player cosmetics for an existing room.
 * Body: { player_id: "uid", card_bg: "res://..." }
 */
app.post('/api/rooms/:room_id/cosmetics', (req, res) => {
  const { room_id } = req.params;
  const { player_id, card_bg } = req.body;

  if (!player_id) {
    return res.status(400).json({
      error: 'Missing required fields',
      required: ['player_id']
    });
  }

  const room = rooms.get(room_id);
  if (!room) {
    return res.status(404).json({
      error: 'Room not found',
      room_id
    });
  }

  const newBg = typeof card_bg === 'string' ? card_bg : '';

  if (room.host && room.host.player_id === player_id) {
    room.host.card_bg = newBg;
    room.last_heartbeat = Date.now();
    return res.json({ ok: true, updated: 'host', room_id });
  }

  if (room.client && room.client.player_id === player_id) {
    room.client.card_bg = newBg;
    room.last_heartbeat = Date.now();
    return res.json({ ok: true, updated: 'client', room_id });
  }

  if (room.client2 && room.client2.player_id === player_id) {
    room.client2.card_bg = newBg;
    room.last_heartbeat = Date.now();
    return res.json({ ok: true, updated: 'client2', room_id });
  }

  return res.status(400).json({
    error: 'Player not in room',
    room_id,
    player_id
  });
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
  } else if (room.client2 && room.client2.player_id === player_id) {
    room.client2.ready = ready;
    console.log(`[Lobby] Client2 ${room.client2.username} ready: ${ready}`);
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
  const is_client2 = room.client2 && room.client2.player_id === player_id;

  if (is_host) {
    console.log(`[Lobby] Host ${room.host.username} leaving room ${room_id}`);

    if (room.client || room.client2) {
      // Promote next available client to host
      const new_host = room.client || room.client2;
      console.log(`[Lobby] Promoting ${new_host.username} to host`);

      // Remove promoted player from their slot, then shift remaining player into client slot.
      if (room.client && room.client.player_id === new_host.player_id) {
        room.client = null;
      } else if (room.client2 && room.client2.player_id === new_host.player_id) {
        room.client2 = null;
      }

      // Shift remaining client2 into client if needed.
      if (!room.client && room.client2) {
        room.client = room.client2;
        room.client2 = null;
      }

      room.host = new_host;
      const remaining = (room.client ? 1 : 0) + (room.client2 ? 1 : 0);
      room.current_players = 1 + remaining;
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

    // Shift client2 into client slot if present
    if (room.client2) {
      room.client = room.client2;
      room.client2 = null;
    }

    const remaining = (room.client ? 1 : 0) + (room.client2 ? 1 : 0);
    room.current_players = 1 + remaining;
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
  } else if (is_client2) {
    console.log(`[Lobby] Client2 ${room.client2.username} left room ${room_id}`);
    const client2_username = room.client2.username;
    room.client2 = null;
    const remaining = (room.client ? 1 : 0) + (room.client2 ? 1 : 0);
    room.current_players = 1 + remaining;
    room.last_heartbeat = Date.now();

    broadcastToRoom(room_id, {
      type: 'player_left',
      player_id: player_id,
      username: client2_username,
      message: 'Player has left the room'
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
    code_version: 'question-stats-v1',
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
      hasClient2: !!room.client2,
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

  // Check if room is full (default 2; defuse_trojan uses 3)
  const lobbyRoom = rooms.get(room_id);
  const maxPlayers = lobbyRoom && typeof lobbyRoom.max_players === 'number' ? lobbyRoom.max_players : 2;
  if (roomConnections.size >= maxPlayers) {
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

  console.log(`[WebSocket] ${username} joined room ${room_id}. Players in room: ${roomConnections.size}/${maxPlayers}`);

  // Notify all players in room about connection
  broadcastToRoom(room_id, {
    type: 'player_connected',
    player_id: player_id,
    username: username,
    players_count: roomConnections.size,
    max_players: maxPlayers
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
        players_count: roomConnections.size,
        max_players: maxPlayers
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
    players_count: roomConnections.size,
    max_players: maxPlayers
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
 * CYBERQUIZ API ENDPOINTS
 * =============================================================================
 */

// POST /api/quiz/create — Teacher creates a quiz room
app.post('/api/quiz/create', (req, res) => {
  const { room_code, room_name, host_id, host_username, quiz_data, time_per_question, max_players, allowed_students } = req.body;

  if (!room_code || !host_id || !quiz_data) {
    return res.status(400).json({ error: 'Missing required fields: room_code, host_id, quiz_data' });
  }

  if (quizRooms.has(room_code)) {
    return res.status(409).json({ error: 'Room code already exists' });
  }

  const questions = quiz_data.questions || [];
  if (questions.length === 0) {
    return res.status(400).json({ error: 'Quiz must have at least one question' });
  }

  const quizRoom = {
    room_code,
    room_name: room_name || 'CyberQuiz Room',
    host_id,
    host_username: host_username || 'Teacher',
    quiz_data: {
      questions,
      time_per_question: time_per_question || 30
    },
    players: [],
    max_players: Math.min(Math.max(2, max_players || 10), 10),
    allowed_students: Array.isArray(allowed_students) ? allowed_students.map(s => String(s).trim().toUpperCase()).filter(Boolean) : [],
    status: 'waiting', // waiting | active | finished
    created_at: Date.now(),
    last_heartbeat: Date.now()
  };

  quizRooms.set(room_code, quizRoom);
  console.log(`[CyberQuiz] Room created: ${room_code} by ${host_username} (${questions.length} questions)`);
  questions.forEach((q, i) => {
    console.log(`[CyberQuiz DEBUG] Stored Q${i}: question="${q.question}" correct_answer="${q.correct_answer}" choices=${JSON.stringify(q.choices)}`);
  });

  res.json({
    ok: true,
    room_code,
    room_name: quizRoom.room_name,
    question_count: questions.length,
    max_players: quizRoom.max_players
  });
});

// GET /api/quiz/:code/info — Get room info (player list, status)
app.get('/api/quiz/:code/info', (req, res) => {
  const code = req.params.code.toUpperCase();
  const qr = quizRooms.get(code);

  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  res.json({
    ok: true,
    room_code: qr.room_code,
    room_name: qr.room_name,
    host_username: qr.host_username,
    status: qr.status,
    max_players: qr.max_players,
    question_count: qr.quiz_data.questions.length,
    time_per_question: qr.quiz_data.time_per_question,
    has_student_restriction: Array.isArray(qr.allowed_students) && qr.allowed_students.length > 0,
    players: qr.players.map(p => ({
      player_id: p.player_id,
      username: p.username,
      avatar: p.avatar || 'default.png',
      xp: p.xp || 0,
      finished: p.finished,
      score: p.finished ? p.score : undefined
    }))
  });
});

// POST /api/quiz/:code/join — Student joins quiz room
app.post('/api/quiz/:code/join', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { player_id, username, avatar, xp, student_number } = req.body;

  if (!player_id || !username) {
    return res.status(400).json({ error: 'Missing required fields: player_id, username' });
  }

  const qr = quizRooms.get(code);
  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  if (qr.status !== 'waiting') {
    return res.status(403).json({ error: 'Quiz has already started' });
  }

  if (qr.players.length >= qr.max_players) {
    return res.status(403).json({ error: 'Room is full' });
  }

  // Student number whitelist validation
  if (Array.isArray(qr.allowed_students) && qr.allowed_students.length > 0) {
    if (!student_number) {
      return res.status(403).json({ error: 'This room requires a student number to join.' });
    }
    const normalised = String(student_number).trim().toUpperCase();
    if (!qr.allowed_students.includes(normalised)) {
      return res.status(403).json({ error: 'Your student number is not authorized for this room.' });
    }
    // Check if student number already used by another player
    const alreadyUsed = qr.players.find(p => p.student_number === normalised && p.player_id !== player_id);
    if (alreadyUsed) {
      return res.status(403).json({ error: 'This student number is already in use by another player.' });
    }
  }

  // Check if player already joined (allow rejoin)
  const existing = qr.players.find(p => p.player_id === player_id);
  if (existing) {
    // Update avatar/xp on rejoin
    if (avatar) existing.avatar = avatar;
    if (xp !== undefined) existing.xp = xp;
    if (student_number) existing.student_number = String(student_number).trim().toUpperCase();
    console.log(`[CyberQuiz] Player rejoined: ${username} in ${code}`);
    return res.json({ ok: true, status: qr.status, rejoined: true });
  }

  qr.players.push({
    player_id,
    username,
    avatar: avatar || 'default.png',
    xp: xp || 0,
    student_number: student_number ? String(student_number).trim().toUpperCase() : '',
    answers: [],
    score: 0,
    finished: false,
    joined_at: Date.now()
  });

  qr.last_heartbeat = Date.now();
  console.log(`[CyberQuiz] Player joined: ${username} in ${code} (${qr.players.length}/${qr.max_players})`);

  res.json({
    ok: true,
    status: qr.status,
    players_count: qr.players.length,
    max_players: qr.max_players
  });
});

// POST /api/quiz/:code/add-students — Teacher adds student numbers to whitelist
app.post('/api/quiz/:code/add-students', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { host_id, student_numbers } = req.body;

  const qr = quizRooms.get(code);
  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  if (host_id && qr.host_id !== host_id) {
    return res.status(403).json({ error: 'Only the host can modify the whitelist' });
  }

  if (!Array.isArray(student_numbers) || student_numbers.length === 0) {
    return res.status(400).json({ error: 'student_numbers must be a non-empty array' });
  }

  if (!Array.isArray(qr.allowed_students)) {
    qr.allowed_students = [];
  }

  const added = [];
  for (const sn of student_numbers) {
    const normalised = String(sn).trim().toUpperCase();
    if (normalised && !qr.allowed_students.includes(normalised)) {
      qr.allowed_students.push(normalised);
      added.push(normalised);
    }
  }

  console.log(`[CyberQuiz] Added ${added.length} student(s) to whitelist for ${code}: ${added.join(', ')}`);
  res.json({ ok: true, added: added.length, total: qr.allowed_students.length });
});

// POST /api/quiz/:code/start — Teacher starts the quiz
app.post('/api/quiz/:code/start', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { host_id } = req.body;

  const qr = quizRooms.get(code);
  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  if (host_id && qr.host_id !== host_id) {
    return res.status(403).json({ error: 'Only the host can start the quiz' });
  }

  if (qr.status !== 'waiting') {
    return res.status(400).json({ error: 'Quiz is not in waiting state' });
  }

  if (qr.players.length === 0) {
    return res.status(400).json({ error: 'No students have joined yet' });
  }

  qr.status = 'active';
  qr.started_at = Date.now();
  qr.last_heartbeat = Date.now();
  console.log(`[CyberQuiz] Quiz started: ${code} with ${qr.players.length} players`);

  res.json({ ok: true, status: 'active', players_count: qr.players.length });
});

// GET /api/quiz/:code/questions — Student fetches questions (only when active)
app.get('/api/quiz/:code/questions', (req, res) => {
  const code = req.params.code.toUpperCase();
  const qr = quizRooms.get(code);

  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  if (qr.status !== 'active') {
    return res.status(403).json({ error: 'Quiz has not started yet', status: qr.status });
  }

  // Send questions without correct answers (prevent cheating)
  const sanitizedQuestions = qr.quiz_data.questions.map((q, i) => ({
    index: i,
    question: q.question,
    choices: q.choices || q.options || [],
    time_limit: q.time_limit || qr.quiz_data.time_per_question
  }));

  res.json({
    ok: true,
    room_name: qr.room_name,
    time_per_question: qr.quiz_data.time_per_question,
    questions: sanitizedQuestions
  });
});

// POST /api/quiz/:code/submit — Student submits answers (score calculated server-side)
app.post('/api/quiz/:code/submit', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { player_id, answers } = req.body;

  if (!player_id) {
    return res.status(400).json({ error: 'Missing player_id' });
  }

  const qr = quizRooms.get(code);
  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  const player = qr.players.find(p => p.player_id === player_id);
  if (!player) {
    return res.status(404).json({ error: 'Player not found in this room' });
  }

  // Calculate score server-side by comparing answers to correct_answer
  const submittedAnswers = answers || [];
  const questions = qr.quiz_data.questions || [];
  let score = 0;
  console.log(`[CyberQuiz DEBUG] Scoring ${questions.length} questions for ${player.username}`);
  console.log(`[CyberQuiz DEBUG] Raw submitted answers: ${JSON.stringify(submittedAnswers)}`);
  for (let i = 0; i < questions.length; i++) {
    const rawCorrect = questions[i].correct_answer || '';
    const rawStudent = submittedAnswers[i] || '';
    // Normalize: trim whitespace, collapse multiple spaces, lowercase
    const correctAns = rawCorrect.trim().replace(/\s+/g, ' ').toLowerCase();
    const studentAns = rawStudent.trim().replace(/\s+/g, ' ').toLowerCase();
    const match = studentAns.length > 0 && studentAns === correctAns;
    console.log(`[CyberQuiz DEBUG] Q${i}: `);
    console.log(`  raw_correct="${rawCorrect}" raw_student="${rawStudent}"`);
    console.log(`  normalized_correct="${correctAns}" normalized_student="${studentAns}"`);
    console.log(`  match=${match}`);
    if (match) {
      score++;
    }
  }

  player.answers = submittedAnswers;
  player.score = score;
  player.finished = true;
  player.finished_at = Date.now();
  qr.last_heartbeat = Date.now();

  console.log(`[CyberQuiz] ${player.username} submitted in ${code}: score=${score}/${questions.length}`);

  // Check if all players finished
  const allFinished = qr.players.every(p => p.finished);
  if (allFinished) {
    qr.status = 'finished';
    console.log(`[CyberQuiz] All players finished in ${code}`);
  }

  // Per-question results so client can show correct/wrong indicators
  const question_results = questions.map((q, i) => {
    const rawCorrect = (q.correct_answer || '').trim().replace(/\s+/g, ' ').toLowerCase();
    const rawStudent = (submittedAnswers[i] || '').trim().replace(/\s+/g, ' ').toLowerCase();
    const is_correct = rawStudent.length > 0 && rawStudent === rawCorrect;
    return {
      question_index: i,
      is_correct,
      correct_answer: q.correct_answer || '',
      student_answer: submittedAnswers[i] || '',
      question_text: q.question || `Q${i + 1}`,
      choices: q.choices || []
    };
  });

  res.json({
    ok: true,
    score: score,
    total_questions: questions.length,
    all_finished: allFinished,
    status: qr.status,
    question_results
  });
});

// GET /api/quiz/:code/results — Get final leaderboard + per-question stats
app.get('/api/quiz/:code/results', (req, res) => {
  const code = req.params.code.toUpperCase();
  const qr = quizRooms.get(code);

  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  // Sort by score descending, then by finish time ascending
  const leaderboard = [...qr.players]
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return (a.finished_at || Infinity) - (b.finished_at || Infinity);
    })
    .map((p, rank) => ({
      rank: rank + 1,
      player_id: p.player_id,
      username: p.username,
      score: p.score,
      finished: p.finished,
      total_questions: qr.quiz_data.questions.length
    }));

  // Per-question statistics: how many students got each question correct/wrong
  const questions = qr.quiz_data.questions || [];
  const finishedPlayers = qr.players.filter(p => p.finished);
  const question_stats = questions.map((q, i) => {
    let correct = 0;
    let wrong = 0;
    for (const p of finishedPlayers) {
      const rawCorrect = (q.correct_answer || '').trim().replace(/\s+/g, ' ').toLowerCase();
      const rawStudent = ((p.answers || [])[i] || '').trim().replace(/\s+/g, ' ').toLowerCase();
      if (rawStudent.length > 0 && rawStudent === rawCorrect) {
        correct++;
      } else if (p.finished) {
        wrong++;
      }
    }
    return {
      question_index: i + 1,
      question_text: q.question || `Q${i + 1}`,
      correct,
      wrong,
      total: finishedPlayers.length
    };
  });

  res.json({
    ok: true,
    room_name: qr.room_name,
    status: qr.status,
    total_questions: qr.quiz_data.questions.length,
    leaderboard,
    question_stats
  });
});

// POST /api/quiz/:code/heartbeat — Keep quiz room alive
app.post('/api/quiz/:code/heartbeat', (req, res) => {
  const code = req.params.code.toUpperCase();
  const qr = quizRooms.get(code);

  if (!qr) {
    return res.status(404).json({ error: 'Quiz room not found' });
  }

  qr.last_heartbeat = Date.now();
  res.json({ ok: true });
});

/**
 * =============================================================================
 * GAMEMODE API ENDPOINTS (Teacher-created minigame rooms)
 * =============================================================================
 */

// POST /api/gamemode/create — Teacher creates a game mode room
app.post('/api/gamemode/create', (req, res) => {
  const { room_code, room_name, host_id, host_username, game_name, game_scene, difficulty, max_players, allowed_students } = req.body;

  if (!room_code || !host_id || !game_name) {
    return res.status(400).json({ error: 'Missing required fields: room_code, host_id, game_name' });
  }

  if (gameModeRooms.has(room_code)) {
    return res.status(409).json({ error: 'Room code already exists' });
  }

  // Whitelist: normalize student numbers (trim, uppercase)
  const normalizedAllowed = Array.isArray(allowed_students)
    ? allowed_students.map(s => String(s).trim().toUpperCase()).filter(s => s.length > 0)
    : [];

  const gameRoom = {
    room_code,
    room_name: room_name || 'Game Room',
    host_id,
    host_username: host_username || 'Teacher',
    game_name,
    game_scene: game_scene || '',
    difficulty: difficulty || '',
    players: [],
    max_players: Math.min(Math.max(2, max_players || 50), 50),
    allowed_students: normalizedAllowed,
    status: 'waiting', // waiting | active | finished
    started_at: null,
    created_at: Date.now(),
    last_heartbeat: Date.now()
  };

  gameModeRooms.set(room_code, gameRoom);
  console.log(`[GameMode] Room created: ${room_code} by ${host_username} — game: ${game_name}`);

  res.json({
    ok: true,
    room_code,
    room_name: gameRoom.room_name,
    game_name,
    max_players: gameRoom.max_players
  });
});

// GET /api/gamemode/:code/info — Get room info (player list, status)
app.get('/api/gamemode/:code/info', (req, res) => {
  const code = req.params.code.toUpperCase();
  const gr = gameModeRooms.get(code);

  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  res.json({
    ok: true,
    room_code: gr.room_code,
    room_name: gr.room_name,
    host_username: gr.host_username,
    game_name: gr.game_name,
    game_scene: gr.game_scene,
    difficulty: gr.difficulty,
    status: gr.status,
    max_players: gr.max_players,
    has_student_restriction: Array.isArray(gr.allowed_students) && gr.allowed_students.length > 0,
    players: gr.players.map(p => ({
      player_id: p.player_id,
      username: p.username,
      avatar: p.avatar || 'default.png',
      xp: p.xp || 0,
      finished: p.finished,
      score: p.finished ? p.score : undefined,
      max_score: p.finished ? p.max_score : undefined,
      time_taken_ms: p.finished ? p.time_taken_ms : undefined
    }))
  });
});

// POST /api/gamemode/:code/join — Student joins a game mode room
app.post('/api/gamemode/:code/join', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { player_id, username, avatar, xp } = req.body;

  if (!player_id || !username) {
    return res.status(400).json({ error: 'Missing player_id or username' });
  }

  const gr = gameModeRooms.get(code);
  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  // Whitelist check: if room has allowed_students, validate student_number
  const { student_number } = req.body;
  if (Array.isArray(gr.allowed_students) && gr.allowed_students.length > 0) {
    if (!student_number || String(student_number).trim().length === 0) {
      return res.status(403).json({ error: 'Please enter your student number.' });
    }
    const normalized = String(student_number).trim().toUpperCase();
    if (!gr.allowed_students.includes(normalized)) {
      return res.status(403).json({ error: 'Your student number is not authorized for this room.' });
    }
    // Check if student number already used by another player
    const alreadyUsed = gr.players.find(p => p.student_number === normalized);
    if (alreadyUsed && alreadyUsed.player_id !== player_id) {
      return res.status(403).json({ error: 'This student number has already joined.' });
    }
  }

  // Check if already joined
  const existing = gr.players.find(p => p.player_id === player_id);
  if (existing) {
    // Update avatar/xp if provided
    if (avatar) existing.avatar = avatar;
    if (xp !== undefined) existing.xp = xp;
    console.log(`[GameMode] Player rejoined: ${username} in ${code}`);
    return res.json({ ok: true, rejoined: true, status: gr.status, game_name: gr.game_name, game_scene: gr.game_scene });
  }

  if (gr.players.length >= gr.max_players) {
    return res.status(403).json({ error: 'Room is full' });
  }

  const normalizedStudentNum = student_number ? String(student_number).trim().toUpperCase() : '';
  gr.players.push({
    player_id,
    username,
    avatar: avatar || 'default.png',
    xp: xp || 0,
    student_number: normalizedStudentNum,
    joined_at: Date.now(),
    finished: false,
    score: 0,
    max_score: 0,
    time_taken_ms: 0
  });

  gr.last_heartbeat = Date.now();
  console.log(`[GameMode] Player joined: ${username} in ${code} (${gr.players.length}/${gr.max_players})`);

  res.json({
    ok: true,
    status: gr.status,
    game_name: gr.game_name,
    game_scene: gr.game_scene,
    players_count: gr.players.length
  });
});

// POST /api/gamemode/:code/add-students — Teacher adds student numbers to whitelist
app.post('/api/gamemode/:code/add-students', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { host_id, student_numbers } = req.body;

  const gr = gameModeRooms.get(code);
  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  if (host_id && gr.host_id !== host_id) {
    return res.status(403).json({ error: 'Only the host can modify the whitelist' });
  }

  if (!Array.isArray(student_numbers) || student_numbers.length === 0) {
    return res.status(400).json({ error: 'student_numbers must be a non-empty array' });
  }

  if (!Array.isArray(gr.allowed_students)) {
    gr.allowed_students = [];
  }

  const added = [];
  for (const sn of student_numbers) {
    const normalised = String(sn).trim().toUpperCase();
    if (normalised && !gr.allowed_students.includes(normalised)) {
      gr.allowed_students.push(normalised);
      added.push(normalised);
    }
  }

  console.log(`[GameMode] Added ${added.length} student(s) to whitelist for ${code}: ${added.join(', ')}`);
  res.json({ ok: true, added: added.length, total: gr.allowed_students.length });
});

// POST /api/gamemode/:code/start — Teacher starts the game
app.post('/api/gamemode/:code/start', (req, res) => {
  const code = req.params.code.toUpperCase();
  const gr = gameModeRooms.get(code);

  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  if (gr.status !== 'waiting') {
    return res.status(400).json({ error: 'Game is not in waiting state' });
  }

  if (gr.players.length === 0) {
    return res.status(400).json({ error: 'No students have joined yet' });
  }

  gr.status = 'active';
  gr.started_at = Date.now();
  gr.last_heartbeat = Date.now();
  console.log(`[GameMode] Game started: ${code} — ${gr.game_name} with ${gr.players.length} players`);

  res.json({ ok: true, status: 'active', players_count: gr.players.length });
});

// POST /api/gamemode/:code/submit — Student submits score + time
app.post('/api/gamemode/:code/submit', (req, res) => {
  const code = req.params.code.toUpperCase();
  const { player_id, score, max_score, time_taken_ms } = req.body;

  if (!player_id) {
    return res.status(400).json({ error: 'Missing player_id' });
  }

  const gr = gameModeRooms.get(code);
  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  const player = gr.players.find(p => p.player_id === player_id);
  if (!player) {
    return res.status(404).json({ error: 'Player not found in this room' });
  }

  player.score = score || 0;
  player.max_score = max_score || 0;
  player.time_taken_ms = time_taken_ms || 0;
  player.finished = true;
  player.finished_at = Date.now();
  gr.last_heartbeat = Date.now();

  console.log(`[GameMode] ${player.username} submitted in ${code}: score=${score}/${max_score} time=${time_taken_ms}ms`);

  // Check if all players finished
  const allFinished = gr.players.every(p => p.finished);
  if (allFinished) {
    gr.status = 'finished';
    console.log(`[GameMode] All players finished in ${code}`);
  }

  res.json({
    ok: true,
    score: player.score,
    max_score: player.max_score,
    time_taken_ms: player.time_taken_ms,
    all_finished: allFinished,
    status: gr.status
  });
});

// GET /api/gamemode/:code/results — Get leaderboard (sorted by score desc, then time asc)
app.get('/api/gamemode/:code/results', (req, res) => {
  const code = req.params.code.toUpperCase();
  const gr = gameModeRooms.get(code);

  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  // Sort: finished first, then by score desc, then by time asc (faster is better)
  const sorted = [...gr.players].sort((a, b) => {
    if (a.finished !== b.finished) return a.finished ? -1 : 1;
    if (a.score !== b.score) return b.score - a.score;
    return a.time_taken_ms - b.time_taken_ms;
  });

  const leaderboard = sorted.map((p, i) => ({
    rank: i + 1,
    player_id: p.player_id,
    username: p.username,
    finished: p.finished,
    score: p.score,
    max_score: p.max_score,
    time_taken_ms: p.time_taken_ms
  }));

  res.json({
    ok: true,
    room_name: gr.room_name,
    game_name: gr.game_name,
    status: gr.status,
    leaderboard
  });
});

// POST /api/gamemode/:code/heartbeat — Keep room alive
app.post('/api/gamemode/:code/heartbeat', (req, res) => {
  const code = req.params.code.toUpperCase();
  const gr = gameModeRooms.get(code);

  if (!gr) {
    return res.status(404).json({ error: 'Game room not found' });
  }

  gr.last_heartbeat = Date.now();
  res.json({ ok: true });
});

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
  console.log(`\n📝 CyberQuiz API:`);
  console.log(`   POST   http://${localIP}:${PORT}/api/quiz/create`);
  console.log(`   GET    http://${localIP}:${PORT}/api/quiz/:code/info`);
  console.log(`   POST   http://${localIP}:${PORT}/api/quiz/:code/join`);
  console.log(`   POST   http://${localIP}:${PORT}/api/quiz/:code/start`);
  console.log(`   GET    http://${localIP}:${PORT}/api/quiz/:code/questions`);
  console.log(`   POST   http://${localIP}:${PORT}/api/quiz/:code/submit`);
  console.log(`   GET    http://${localIP}:${PORT}/api/quiz/:code/results`);
  console.log(`   POST   http://${localIP}:${PORT}/api/quiz/:code/heartbeat`);
  console.log(`\n🎮 GameMode API:`);
  console.log(`   POST   http://${localIP}:${PORT}/api/gamemode/create`);
  console.log(`   GET    http://${localIP}:${PORT}/api/gamemode/:code/info`);
  console.log(`   POST   http://${localIP}:${PORT}/api/gamemode/:code/join`);
  console.log(`   POST   http://${localIP}:${PORT}/api/gamemode/:code/start`);
  console.log(`   POST   http://${localIP}:${PORT}/api/gamemode/:code/submit`);
  console.log(`   GET    http://${localIP}:${PORT}/api/gamemode/:code/results`);
  console.log(`   POST   http://${localIP}:${PORT}/api/gamemode/:code/heartbeat`);
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
