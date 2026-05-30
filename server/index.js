'use strict';
const http = require('http');
const path = require('path');
const fs   = require('fs');
const app  = require('./app');

const PORT = Number(process.env.PORT || 3001);

// ── HTTP + WebSocket server ──────────────────────────────────────
const httpServer = http.createServer(app);

const { initWsServer } = require('./ws/broadcaster');
initWsServer(httpServer);

const { initMqttClient } = require('./mqtt/client');
const pool = require('./db');

async function waitForDb(retries = 10) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query('SELECT 1');
      console.log('[DB] Connected');
      return true;
    } catch (err) {
      console.log(`[DB] Not ready (${i + 1}/${retries}):`, err.message);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  console.error('[DB] Could not connect after retries');
  return false;
}

async function initSchema() {
  const schemaPath = path.join(__dirname, 'db', 'schema.sql');
  if (!fs.existsSync(schemaPath)) return;
  try {
    const sql = fs.readFileSync(schemaPath, 'utf8');
    await pool.query(sql);
    console.log('[DB] Schema initialised');
  } catch (err) {
    console.error('[DB] Schema init error:', err.message);
  }
}

httpServer.listen(PORT, async () => {
  console.log(`EMS Dashboard listening on http://localhost:${PORT}`);
  const connected = await waitForDb();
  if (connected) {
    await initSchema();
    if (process.env.ENABLE_SIMULATOR === 'true') {
      const { initSimulator } = require('./simulator');
      initSimulator();
    }
  }
  initMqttClient();
});
