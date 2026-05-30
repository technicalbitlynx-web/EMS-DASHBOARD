const express = require('express');
const pool    = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/sensors
router.get('/', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM sensors ORDER BY type, name');
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/sensors/latest  — last reading per sensor (for dashboard init)
router.get('/latest', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT DISTINCT ON (sensor_id)
        sr.sensor_id, sr.sensor_type, sr.reading_ts, sr.value_numeric, sr.value_json, sr.unit,
        s.name, s.location, s.zone, s.thresholds, s.enabled
      FROM sensor_readings sr
      JOIN sensors s ON s.id = sr.sensor_id
      WHERE s.enabled = true
      ORDER BY sensor_id, reading_ts DESC
    `);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/sensors/:id
router.get('/:id', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM sensors WHERE id = $1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Sensor not found' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// POST /api/sensors  (admin)
router.post('/', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    const { id, type, name, location, zone, mqtt_topic, thresholds } = req.body;
    if (!id || !type || !name || !mqtt_topic)
      return res.status(400).json({ error: 'id, type, name and mqtt_topic required' });
    const validTypes = ['temperature', 'power', 'door', 'smoke', 'dehumidifier'];
    if (!validTypes.includes(type))
      return res.status(400).json({ error: 'Invalid sensor type' });

    await pool.query(
      'INSERT INTO sensors (id, type, name, location, zone, mqtt_topic, thresholds) VALUES ($1,$2,$3,$4,$5,$6,$7)',
      [id, type, name, location || '', zone || 'Main', mqtt_topic, JSON.stringify(thresholds || {})]
    );
    res.status(201).json({ success: true });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: 'Sensor ID or MQTT topic already exists' });
    next(err);
  }
});

// PUT /api/sensors/:id  (admin/operator)
router.put('/:id', requireAuth, requireRole('admin', 'operator'), async (req, res, next) => {
  try {
    const { name, location, zone, thresholds, enabled } = req.body;
    await pool.query(
      `UPDATE sensors SET
        name       = COALESCE($1, name),
        location   = COALESCE($2, location),
        zone       = COALESCE($3, zone),
        thresholds = COALESCE($4::jsonb, thresholds),
        enabled    = COALESCE($5, enabled)
       WHERE id = $6`,
      [name || null, location ?? null, zone || null, thresholds ? JSON.stringify(thresholds) : null, enabled ?? null, req.params.id]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// DELETE /api/sensors/:id  (admin)
router.delete('/:id', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    await pool.query('DELETE FROM sensors WHERE id = $1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
