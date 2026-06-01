'use strict';

const express = require('express');
const pool = require('../db');
const { sendToTokens } = require('../fcm');

const router = express.Router();

// Validates the shared cron secret. Vercel Cron sends
// `Authorization: Bearer <CRON_SECRET>` when CRON_SECRET is configured; we also
// accept an `x-cron-secret` header or `?secret=` query for manual testing.
function checkSecret(req) {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false; // refuse if not configured — never open by default
  const header = req.headers.authorization || '';
  const bearer = header.startsWith('Bearer ') ? header.slice(7) : null;
  return (
    bearer === secret ||
    req.headers['x-cron-secret'] === secret ||
    req.query.secret === secret
  );
}

// POST /api/cron/dispatch-alerts — find newly triggered, un-pushed alerts and
// send a push for each. Idempotent: pushed_at guards against double-send.
router.post('/dispatch-alerts', async (req, res, next) => {
  if (!checkSecret(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  try {
    const { rows: alerts } = await pool.query(
      `SELECT id, sensor_id, message, severity, triggered_at
         FROM alert_history
        WHERE pushed_at IS NULL
          AND triggered_at > NOW() - INTERVAL '1 hour'
        ORDER BY triggered_at
        LIMIT 50`
    );
    if (alerts.length === 0) {
      return res.json({ dispatched: 0, devices: 0 });
    }

    const { rows: deviceRows } = await pool.query(
      'SELECT token FROM device_tokens'
    );
    const tokens = deviceRows.map((r) => r.token);

    let dispatched = 0;
    const deadTokens = new Set();

    for (const a of alerts) {
      if (tokens.length > 0) {
        const result = await sendToTokens(tokens, {
          title:
            a.severity === 'critical'
              ? '🚨 Critical: Server Room'
              : '⚠️ Warning: Server Room',
          body: a.message,
          data: {
            alertId: a.id,
            severity: a.severity,
            sensor_id: a.sensor_id,
          },
        });
        result.invalidTokens.forEach((t) => deadTokens.add(t));
      }
      await pool.query(
        'UPDATE alert_history SET pushed_at = NOW() WHERE id = $1',
        [a.id]
      );
      dispatched += 1;
    }

    // Prune tokens FCM reported as invalid.
    if (deadTokens.size > 0) {
      await pool.query('DELETE FROM device_tokens WHERE token = ANY($1)', [
        Array.from(deadTokens),
      ]);
    }

    res.json({
      dispatched,
      devices: tokens.length,
      pruned: deadTokens.size,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
