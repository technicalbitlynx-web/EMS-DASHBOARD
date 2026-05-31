'use strict';
const path = require('path');
const fs   = require('fs');
const express = require('express');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app  = express();
const pool = require('./db');

// ── Lazy schema init ─────────────────────────────────────────────
let _schemaPromise = null;
function ensureSchema() {
  if (!_schemaPromise) {
    const sql = fs.readFileSync(path.join(__dirname, 'db', 'schema.sql'), 'utf8');
    _schemaPromise = pool.query(sql)
      .then(() => console.log('[App] Schema ready'))
      .catch(err => { console.error('[App] Schema init error:', err.message); _schemaPromise = null; });
  }
  return _schemaPromise;
}

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// ── PWA routes (before express.static) ──────────────────────────

// Manifest served inline — guaranteed regardless of file bundling,
// and with the correct Content-Type that PWA Builder requires.
app.get('/manifest.json', (req, res) => {
  res.setHeader('Content-Type', 'application/manifest+json');
  res.setHeader('Cache-Control', 'no-cache');
  res.json({
    id:               'com.ems.dashboard',
    name:             'Bank Server Room EMS',
    short_name:       'EMS',
    description:      'Environmental Monitoring System — Bank Server Room',
    categories:       ['business'],
    dir:              'ltr',
    start_url:        '/',
    scope:            '/',
    display:          'standalone',
    orientation:      'any',
    background_color: '#0f172a',
    theme_color:      '#2563eb',
    icons: [
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' }
    ]
  });
});

// Service worker
app.get('/sw.js', (req, res) => {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Service-Worker-Allowed', '/');
  res.sendFile(path.join(__dirname, '..', 'public', 'sw.js'));
});

// ── Static assets (JS, CSS, images, icons) ───────────────────────
app.use(express.static(path.join(__dirname, '..', 'public')));

// ── Run schema init before every API call ────────────────────────
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

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'connected', ts: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ ok: false, db: 'error', error: err.message, ts: new Date().toISOString() });
  }
});

// ── SPA catch-all ────────────────────────────────────────────────
// no-store so Vercel CDN never caches a stale HTML page
app.get(/^(?!\/api).*$/, (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.use((err, req, res, _next) => {
  console.error('[Server]', err.message);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

module.exports = app;
