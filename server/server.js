const express = require('express');
const expressWs = require('express-ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
expressWs(app);

const PORT = process.env.PORT || 8080;

// Store active game rooms and players
const rooms = new Map();
const players = new Map();

/**
 * Message Protocol:
 * 
 * CLIENT → SERVER:
 * {
 *   type: "register",
 *   room_id: "...",
 *   player_id: "...",
 *   username: "...",
 *   is_host: true/false
 * }
 * 
 * {
 *   type: "ready",
 *   room_id: "...",
 *   player_id: "..."
 * }
 * 
 * {
 *   type: "game_action",
 *   room_id: "...",
 *   from_player: "...",
 *   action: { score, health, guess, etc }
 * }
 * 
 * SERVER → CLIENT:
 * {
 *   type: "player_joined",
 *   opponent: { username, is_host, player_id }
 * }
 * 
 * {
 *   type: "start_game",
 *   opponent_ip: "...",
 *   opponent_port: ...,
 *   game_start_time: <unix_timestamp>
 * }
 * 
 * {
 *   type: "opponent_action",
 *   action: { score, health, guess, etc }
 * }
 */

// WebSocket route for game signaling
app.ws('/ws/game', (ws, req) => {
  const clientId = uuidv4();
  console.log(`[CONNECT] Client connected: ${clientId}`);

  let playerId = null;
  let roomId = null;
  let isHost = false;

  ws.on('message', (msg) => {
    try {
      const data = JSON.parse(msg);
      console.log(`[MSG from ${clientId}] ${data.type}:`, data);

      switch (data.type) {
        case 'register':
          handleRegister(ws, clientId, data);
          playerId = data.player_id;
          roomId = data.room_id;
          isHost = data.is_host;
          break;

        case 'ready':
          handleReady(ws, clientId, data);
          break;

        case 'game_action':
          handleGameAction(ws, clientId, data);
          break;

        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;

        default:
          console.log(`[UNKNOWN] Unknown message type: ${data.type}`);
      }
    } catch (error) {
      console.error(`[ERROR] Failed to parse message:`, error);
    }
  });

  ws.on('close', () => {
    console.log(`[DISCONNECT] Client disconnected: ${clientId}`);
    if (roomId && playerId) {
      handleDisconnect(roomId, playerId);
    }
  });

  ws.on('error', (error) => {
    console.error(`[ERROR] WebSocket error for ${clientId}:`, error);
  });
});

/**
 * Handle player registration
 */
function handleRegister(ws, clientId, data) {
  const { room_id, player_id, username, is_host } = data;

  if (!room_id || !player_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Missing room_id or player_id' }));
    return;
  }

  // Store player info
  players.set(clientId, {
    playerId: player_id,
    roomId: room_id,
    username: username,
    isHost: is_host,
    ws: ws,
    ip: getClientIp(ws),
    ready: false
  });

  // Initialize room if doesn't exist
  if (!rooms.has(room_id)) {
    rooms.set(room_id, {
      host: null,
      client: null,
      createdAt: Date.now()
    });
  }

  const room = rooms.get(room_id);

  // Assign player to room slot
  if (is_host) {
    room.host = { clientId, playerId: player_id, username };
  } else {
    room.client = { clientId, playerId: player_id, username };
  }

  console.log(`[ROOM ${room_id}] Player registered:`, { player_id, username, is_host });

  // Notify both players if room is full
  if (room.host && room.client) {
    const hostWs = players.get(room.host.clientId)?.ws;
    const clientWs = players.get(room.client.clientId)?.ws;

    if (hostWs && clientWs) {
      // Send opponent info to host
      hostWs.send(JSON.stringify({
        type: 'player_joined',
        opponent: {
          username: room.client.username,
          player_id: room.client.playerId,
          is_host: false
        }
      }));

      // Send opponent info to client
      clientWs.send(JSON.stringify({
        type: 'player_joined',
        opponent: {
          username: room.host.username,
          player_id: room.host.playerId,
          is_host: true
        }
      }));

      console.log(`[ROOM ${room_id}] Both players ready for P2P connection`);
    }
  }
}

/**
 * Handle ready signal from player
 */
function handleReady(ws, clientId, data) {
  const { room_id } = data;
  const room = rooms.get(room_id);

  if (!room || (!room.host || !room.client)) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room not ready' }));
    return;
  }

  const playerInfo = players.get(clientId);
  if (playerInfo) {
    playerInfo.ready = true;
  }

  // Check if both players are ready
  const hostPlayer = players.get(room.host.clientId);
  const clientPlayer = players.get(room.client.clientId);

  if (hostPlayer?.ready && clientPlayer?.ready) {
    // Both ready - send connection info for direct P2P
    const gameStartTime = Math.floor(Date.now() / 1000);

    // Send to host
    hostPlayer.ws.send(JSON.stringify({
      type: 'start_game',
      opponent_ip: clientPlayer.ip,
      game_start_time: gameStartTime
    }));

    // Send to client
    clientPlayer.ws.send(JSON.stringify({
      type: 'start_game',
      opponent_ip: hostPlayer.ip,
      game_start_time: gameStartTime
    }));

    console.log(`[ROOM ${room_id}] Game started - P2P info sent to both players`);
  }
}

/**
 * Forward game action to opponent (relay mode if direct P2P fails)
 */
function handleGameAction(ws, clientId, data) {
  const { room_id, to_player } = data;
  const room = rooms.get(room_id);

  if (!room) {
    return;
  }

  // Find opponent's connection
  let opponentClientId = null;
  if (room.host?.clientId === clientId) {
    opponentClientId = room.client?.clientId;
  } else if (room.client?.clientId === clientId) {
    opponentClientId = room.host?.clientId;
  }

  if (opponentClientId) {
    const opponent = players.get(opponentClientId);
    if (opponent?.ws) {
      opponent.ws.send(JSON.stringify({
        type: 'opponent_action',
        action: data.action
      }));
    }
  }
}

/**
 * Handle player disconnect
 */
function handleDisconnect(roomId, playerId) {
  const room = rooms.get(roomId);
  if (!room) return;

  console.log(`[ROOM ${roomId}] Player disconnected: ${playerId}`);

  // Notify opponent
  if (room.host?.playerId === playerId && room.client) {
    const clientPlayer = players.get(room.client.clientId);
    if (clientPlayer?.ws) {
      clientPlayer.ws.send(JSON.stringify({
        type: 'opponent_disconnect'
      }));
    }
    room.host = null;
  } else if (room.client?.playerId === playerId && room.host) {
    const hostPlayer = players.get(room.host.clientId);
    if (hostPlayer?.ws) {
      hostPlayer.ws.send(JSON.stringify({
        type: 'opponent_disconnect'
      }));
    }
    room.client = null;
  }

  // Clean up empty rooms after 5 minutes
  if (!room.host && !room.client) {
    setTimeout(() => {
      if (rooms.has(roomId)) {
        const currentRoom = rooms.get(roomId);
        if (!currentRoom.host && !currentRoom.client) {
          rooms.delete(roomId);
          console.log(`[CLEANUP] Removed empty room: ${roomId}`);
        }
      }
    }, 300000); // 5 minutes
  }
}

/**
 * Get client IP address
 */
function getClientIp(ws) {
  // Try to get from socket
  if (ws._socket?.remoteAddress) {
    let ip = ws._socket.remoteAddress;
    // Remove IPv6 prefix if present
    if (ip.substr(0, 7) === '::ffff:') {
      ip = ip.substr(7);
    }
    return ip;
  }
  return 'unknown';
}

/**
 * Root endpoint
 */
app.get('/', (req, res) => {
  res.json({
    name: 'Code Breaker P2P Signaling Server',
    status: 'running',
    version: '1.0.0',
    websocket: 'Connect to wss://code-breaker-p2p-signaling.onrender.com/ws/game',
    endpoints: {
      health: '/health',
      stats: '/stats'
    }
  });
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    rooms: rooms.size,
    players: players.size,
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
  console.log(`✅ P2P Signaling Server running on port ${PORT}`);
  console.log(`   WebSocket: ws://localhost:${PORT}/ws/game`);
  console.log(`   Health: http://localhost:${PORT}/health`);
  console.log(`   Stats: http://localhost:${PORT}/stats`);
});
