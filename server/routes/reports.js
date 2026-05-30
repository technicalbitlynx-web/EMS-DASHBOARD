const express  = require('express');
const { stringify } = require('csv-stringify/sync');
const pool     = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// GET /api/reports/csv
// Query params: sensor_type, sensor_id, from (ISO), to (ISO)
router.get('/csv', requireAuth, async (req, res, next) => {
  try {
    const { sensor_type, sensor_id, from, to } = req.query;
    const params = [];
    const where  = [];
    let idx = 1;

    if (sensor_id)   { where.push(`sr.sensor_id = $${idx++}`);   params.push(sensor_id); }
    if (sensor_type) { where.push(`sr.sensor_type = $${idx++}`); params.push(sensor_type); }
    if (from)        { where.push(`sr.reading_ts >= $${idx++}`); params.push(from); }
    if (to)          { where.push(`sr.reading_ts <= $${idx++}`); params.push(to); }

    const { rows } = await pool.query(`
      SELECT
        sr.reading_ts AT TIME ZONE 'Africa/Dar_es_Salaam' AS reading_ts,
        sr.sensor_id,
        sr.sensor_type,
        s.name     AS sensor_name,
        s.location,
        s.zone,
        sr.value_numeric,
        sr.unit,
        sr.value_json
      FROM sensor_readings sr
      JOIN sensors s ON s.id = sr.sensor_id
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY sr.reading_ts DESC
      LIMIT 10000
    `, params);

    const csvRows = [
      ['Timestamp', 'Sensor ID', 'Type', 'Sensor Name', 'Location', 'Zone', 'Value', 'Unit', 'Full Payload'],
      ...rows.map(r => [
        new Date(r.reading_ts).toISOString(),
        r.sensor_id,
        r.sensor_type,
        r.sensor_name,
        r.location,
        r.zone,
        r.value_numeric,
        r.unit,
        JSON.stringify(r.value_json),
      ]),
    ];

    const dateTag  = from ? from.slice(0, 10) : 'all';
    const dateTag2 = to   ? to.slice(0, 10)   : 'now';
    const filename = `ems_report_${dateTag}_to_${dateTag2}.csv`;

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(stringify(csvRows));
  } catch (err) { next(err); }
});

// GET /api/reports/alerts-csv
router.get('/alerts-csv', requireAuth, async (req, res, next) => {
  try {
    const { from, to, severity } = req.query;
    const params = [];
    const where  = [];
    let idx = 1;
    if (from)     { where.push(`triggered_at >= $${idx++}`); params.push(from); }
    if (to)       { where.push(`triggered_at <= $${idx++}`); params.push(to); }
    if (severity) { where.push(`severity = $${idx++}`);      params.push(severity); }

    const { rows } = await pool.query(`
      SELECT triggered_at, sensor_id, severity, message, acknowledged_by, acknowledged_at, resolved_at
      FROM alert_history
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY triggered_at DESC
      LIMIT 5000
    `, params);

    const csvRows = [
      ['Triggered At', 'Sensor ID', 'Severity', 'Message', 'Acknowledged By', 'Acknowledged At', 'Resolved At'],
      ...rows.map(r => [
        new Date(r.triggered_at).toISOString(),
        r.sensor_id, r.severity, r.message,
        r.acknowledged_by || '',
        r.acknowledged_at ? new Date(r.acknowledged_at).toISOString() : '',
        r.resolved_at     ? new Date(r.resolved_at).toISOString()     : '',
      ]),
    ];

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="ems_alerts.csv"');
    res.send(stringify(csvRows));
  } catch (err) { next(err); }
});

// GET /api/reports/summary-json  — for browser-side PDF generation with jsPDF
router.get('/summary-json', requireAuth, async (req, res, next) => {
  try {
    const { from, to } = req.query;
    const fromTs = from || new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const toTs   = to   || new Date().toISOString();

    const [readingsSummary, alertsSummary, sensors] = await Promise.all([
      pool.query(`
        SELECT sr.sensor_id, sr.sensor_type, s.name, s.location,
               ROUND(MIN(sr.value_numeric)::numeric, 2) AS min_val,
               ROUND(MAX(sr.value_numeric)::numeric, 2) AS max_val,
               ROUND(AVG(sr.value_numeric)::numeric, 2) AS avg_val,
               COUNT(*) AS reading_count,
               MAX(sr.reading_ts) AS last_reading
        FROM sensor_readings sr JOIN sensors s ON s.id = sr.sensor_id
        WHERE sr.reading_ts BETWEEN $1 AND $2
        GROUP BY sr.sensor_id, sr.sensor_type, s.name, s.location
        ORDER BY sr.sensor_type, sr.sensor_id
      `, [fromTs, toTs]),
      pool.query(`
        SELECT severity, COUNT(*) AS count
        FROM alert_history WHERE triggered_at BETWEEN $1 AND $2
        GROUP BY severity
      `, [fromTs, toTs]),
      pool.query('SELECT id, type, name, location, zone, enabled FROM sensors ORDER BY type, name'),
    ]);

    res.json({
      generated_at: new Date().toISOString(),
      period: { from: fromTs, to: toTs },
      sensors: sensors.rows,
      readings_summary: readingsSummary.rows,
      alerts_summary: alertsSummary.rows,
    });
  } catch (err) { next(err); }
});

module.exports = router;
