const express = require('express');
const pool    = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

// ── Alert History ────────────────────────────────────────────────

// GET /api/alerts/active  — unresolved alerts
router.get('/active', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT ah.*, s.name AS sensor_name, s.location
      FROM alert_history ah
      LEFT JOIN sensors s ON s.id = ah.sensor_id
      WHERE ah.resolved_at IS NULL
      ORDER BY ah.triggered_at DESC
      LIMIT 100
    `);
    res.json(rows);
  } catch (err) { next(err); }
});

// GET /api/alerts/history
router.get('/history', requireAuth, async (req, res, next) => {
  try {
    const limit  = Math.min(Number(req.query.limit) || 100, 500);
    const offset = Number(req.query.offset) || 0;
    const { from, to, sensor_id, severity } = req.query;

    const params = [];
    const where  = [];
    let idx = 1;
    if (from)      { where.push(`ah.triggered_at >= $${idx++}`); params.push(from); }
    if (to)        { where.push(`ah.triggered_at <= $${idx++}`); params.push(to); }
    if (sensor_id) { where.push(`ah.sensor_id = $${idx++}`);     params.push(sensor_id); }
    if (severity)  { where.push(`ah.severity = $${idx++}`);      params.push(severity); }

    const { rows } = await pool.query(`
      SELECT ah.*, s.name AS sensor_name, s.location
      FROM alert_history ah
      LEFT JOIN sensors s ON s.id = ah.sensor_id
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY ah.triggered_at DESC
      LIMIT $${idx} OFFSET $${idx + 1}
    `, [...params, limit, offset]);
    res.json(rows);
  } catch (err) { next(err); }
});

// PUT /api/alerts/:id/acknowledge  (admin/operator)
router.put('/:id/acknowledge', requireAuth, requireRole('admin', 'operator'), async (req, res, next) => {
  try {
    await pool.query(
      'UPDATE alert_history SET acknowledged_by = $1, acknowledged_at = NOW(), resolved_at = NOW() WHERE id = $2',
      [req.user.username, req.params.id]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// ── Alert Rules ──────────────────────────────────────────────────

// GET /api/alerts/rules
router.get('/rules', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT ar.*, s.name AS sensor_name, s.type AS sensor_type
      FROM alert_rules ar
      JOIN sensors s ON s.id = ar.sensor_id
      ORDER BY s.type, s.name, ar.severity DESC, ar.metric
    `);
    res.json(rows);
  } catch (err) { next(err); }
});

// POST /api/alerts/rules  (admin/operator)
router.post('/rules', requireAuth, requireRole('admin', 'operator'), async (req, res, next) => {
  try {
    const { sensor_id, metric, operator, threshold, severity, cooldown_minutes } = req.body;
    if (!sensor_id || !metric || !operator || threshold === undefined || !severity)
      return res.status(400).json({ error: 'sensor_id, metric, operator, threshold and severity required' });
    const validOps = ['>', '<', '>=', '<=', '=', '!='];
    if (!validOps.includes(operator))
      return res.status(400).json({ error: 'Invalid operator' });
    if (!['warning', 'critical'].includes(severity))
      return res.status(400).json({ error: 'severity must be warning or critical' });

    const { rows } = await pool.query(
      'INSERT INTO alert_rules (sensor_id, metric, operator, threshold, severity, cooldown_minutes) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [sensor_id, metric, operator, threshold, severity, cooldown_minutes || 15]
    );
    res.status(201).json(rows[0]);
  } catch (err) { next(err); }
});

// PUT /api/alerts/rules/:id  (admin/operator)
router.put('/rules/:id', requireAuth, requireRole('admin', 'operator'), async (req, res, next) => {
  try {
    const { metric, operator, threshold, severity, enabled, cooldown_minutes } = req.body;
    await pool.query(
      `UPDATE alert_rules SET
        metric           = COALESCE($1, metric),
        operator         = COALESCE($2, operator),
        threshold        = COALESCE($3, threshold),
        severity         = COALESCE($4, severity),
        enabled          = COALESCE($5, enabled),
        cooldown_minutes = COALESCE($6, cooldown_minutes)
       WHERE id = $7`,
      [metric || null, operator || null, threshold ?? null, severity || null, enabled ?? null, cooldown_minutes || null, req.params.id]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// DELETE /api/alerts/rules/:id  (admin)
router.delete('/rules/:id', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    await pool.query('DELETE FROM alert_rules WHERE id = $1', [req.params.id]);
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
