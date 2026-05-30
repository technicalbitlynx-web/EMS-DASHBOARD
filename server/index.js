const path    = require('path');
const http    = require('http');
const express = require('express');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const PORT = Number(process.env.PORT || 3001);

const app = express();
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, '..', 'public')));

// ── API routes ───────────────────────────────────────────────────
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/sensors',  require('./routes/sensors'));
app.use('/api/readings', require('./routes/readings'));
app.use('/api/alerts',   require('./routes/alerts'));
app.use('/api/reports',  require('./routes/reports'));
app.use('/api/settings', require('./routes/settings'));

app.get('/api/health', (req, res) => res.json({ ok: true, ts: new Date().toISOString() }));

// SPA catch-all: serve index.html for any non-API path
app.get(/^(?!\/api).*$/, (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// Error handler
app.use((err, req, res, _next) => {
  console.error('[Server]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ── HTTP + WebSocket server ──────────────────────────────────────
const httpServer = http.createServer(app);

const { initWsServer } = require('./ws/broadcaster');
initWsServer(httpServer);

const { initMqttClient } = require('./mqtt/client');

const fs   = require('fs');
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
