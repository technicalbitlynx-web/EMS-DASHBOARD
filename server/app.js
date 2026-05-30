'use strict';
const path = require('path');
const fs   = require('fs');
const express = require('express');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app  = express();
const pool = require('./db');

// ── Lazy schema init ─────────────────────────────────────────────
// Runs once per process on the first API request.
// Uses IF NOT EXISTS / ON CONFLICT so it is fully idempotent.
let _schemaPromise = null;
function ensureSchema() {
  if (!_schemaPromise) {
    const sql = fs.readFileSync(path.join(__dirname, 'db', 'schema.sql'), 'utf8');
    _schemaPromise = pool.query(sql)
      .then(() => console.log('[App] Schema ready'))
      .catch(err => {
        console.error('[App] Schema init error:', err.message);
        _schemaPromise = null; // allow retry on next request
      });
  }
  return _schemaPromise;
}

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, '..', 'public')));

// Run schema init before every API call (no-op after first success)
app.use('/api', (req, res, next) => {
  ensureSchema().then(() => next()).catch(() => next());
});

// ── API routes ───────────────────────────────────────────────────
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/sensors',  require('./routes/sensors'));
app.use('/api/readings', require('./routes/readings'));
app.use('/api/alerts',   require('./routes/alerts'));
app.use('/api/reports',  require('./routes/reports'));
app.use('/api/settings', require('./routes/settings'));

// Enhanced health check — verifies DB connectivity
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'connected', ts: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ ok: false, db: 'error', error: err.message, ts: new Date().toISOString() });
  }
});

// SPA catch-all: serve index.html for any non-API, non-file path
app.get(/^(?!\/api).*$/, (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.use((err, req, res, _next) => {
  console.error('[Server]', err.message);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

module.exports = app;
