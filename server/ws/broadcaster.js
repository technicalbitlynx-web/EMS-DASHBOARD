const { WebSocketServer } = require('ws');

const wsClients = new Set();

function initWsServer(httpServer) {
  const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

  wss.on('connection', (ws) => {
    wsClients.add(ws);
    try { ws.send(JSON.stringify({ type: 'connected', ts: new Date().toISOString() })); } catch (_) {}
    ws.on('close', () => wsClients.delete(ws));
    ws.on('error', () => wsClients.delete(ws));
  });

  console.log('[WS] WebSocket server ready on /ws');
}

function broadcast(msg) {
  const data = JSON.stringify(msg);
  wsClients.forEach(ws => {
    try { if (ws.readyState === 1) ws.send(data); } catch (_) {}
  });
}

module.exports = { initWsServer, broadcast };
