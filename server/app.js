'use strict';
const path    = require('path');
const express = require('express');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

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

// SPA catch-all: serve index.html for any non-API, non-file path
app.get(/^(?!\/api).*$/, (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.use((err, req, res, _next) => {
  console.error('[Server]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
