const express = require('express');
const pool    = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// GET /api/readings
// Query params: sensor_id, sensor_type, from (ISO), to (ISO), limit (default 500)
router.get('/', requireAuth, async (req, res, next) => {
  try {
    const { sensor_id, sensor_type, from, to } = req.query;
    const limit = Math.min(Number(req.query.limit) || 500, 5000);

    const params = [];
    const where  = [];
    let idx = 1;

    if (sensor_id)   { where.push(`sensor_id = $${idx++}`);   params.push(sensor_id); }
    if (sensor_type) { where.push(`sensor_type = $${idx++}`); params.push(sensor_type); }
    if (from)        { where.push(`reading_ts >= $${idx++}`);  params.push(from); }
    if (to)          { where.push(`reading_ts <= $${idx++}`);  params.push(to); }

    const sql = `
      SELECT sr.id, sr.sensor_id, sr.sensor_type, sr.reading_ts, sr.value_numeric, sr.value_json, sr.unit,
             s.name AS sensor_name, s.location, s.zone
      FROM sensor_readings sr
      JOIN sensors s ON s.id = sr.sensor_id
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY reading_ts DESC
      LIMIT $${idx}
    `;
    params.push(limit);

    const { rows } = await pool.query(sql, params);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/readings/summary
// Returns aggregated stats (min/max/avg) per sensor for a time window
router.get('/summary', requireAuth, async (req, res, next) => {
  try {
    const { from, to, sensor_type } = req.query;
    const params = [];
    const where  = [];
    let idx = 1;
    if (sensor_type) { where.push(`sr.sensor_type = $${idx++}`); params.push(sensor_type); }
    if (from)        { where.push(`sr.reading_ts >= $${idx++}`); params.push(from); }
    if (to)          { where.push(`sr.reading_ts <= $${idx++}`); params.push(to); }

    const { rows } = await pool.query(`
      SELECT sr.sensor_id, sr.sensor_type, s.name, s.location,
             MIN(sr.value_numeric) AS min_val,
             MAX(sr.value_numeric) AS max_val,
             AVG(sr.value_numeric) AS avg_val,
             COUNT(*)              AS reading_count,
             MAX(sr.reading_ts)    AS last_reading
      FROM sensor_readings sr
      JOIN sensors s ON s.id = sr.sensor_id
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      GROUP BY sr.sensor_id, sr.sensor_type, s.name, s.location
      ORDER BY sr.sensor_type, sr.sensor_id
    `, params);
    res.json(rows);
  } catch (err) { next(err); }
});

module.exports = router;
