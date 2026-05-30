const express = require('express');
const pool    = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/settings
router.get('/', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT key, value FROM app_settings ORDER BY key');
    const settings = {};
    rows.forEach(r => { settings[r.key] = r.value; });
    res.json(settings);
  } catch (err) { next(err); }
});

// GET /api/settings/:key
router.get('/:key', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT value FROM app_settings WHERE key = $1', [req.params.key]);
    if (!rows[0]) return res.status(404).json({ error: 'Setting not found' });
    res.json(rows[0].value);
  } catch (err) { next(err); }
});

// PUT /api/settings/:key  (admin)
router.put('/:key', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    await pool.query(
      'INSERT INTO app_settings (key, value, updated_at) VALUES ($1, $2::jsonb, NOW()) ON CONFLICT (key) DO UPDATE SET value = app_settings.value || $2::jsonb, updated_at = NOW()',
      [req.params.key, JSON.stringify(req.body)]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// POST /api/settings/retention/apply  (admin) — delete old readings
router.post('/retention/apply', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    const { rows: cfg } = await pool.query("SELECT value FROM app_settings WHERE key = 'general'");
    const days = cfg[0] ? (cfg[0].value.dataRetentionDays || 90) : 90;
    const { rowCount } = await pool.query(
      'DELETE FROM sensor_readings WHERE reading_ts < NOW() - ($1 || \' days\')::interval',
      [String(days)]
    );
    res.json({ success: true, deleted: rowCount, retention_days: days });
  } catch (err) { next(err); }
});

module.exports = router;
