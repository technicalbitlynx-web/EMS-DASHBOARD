'use strict';

const express = require('express');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// POST /api/devices/register — register/refresh this device's FCM token.
router.post('/register', requireAuth, async (req, res, next) => {
  try {
    const token = String(req.body.token || '').trim();
    const platform = String(req.body.platform || 'android').trim();
    if (!token) return res.status(400).json({ error: 'token is required' });

    await pool.query(
      `INSERT INTO device_tokens (token, user_email, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (token)
       DO UPDATE SET user_email = EXCLUDED.user_email, platform = EXCLUDED.platform`,
      [token, req.user.email, platform]
    );
    res.status(201).json({ success: true });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/devices/:token — unregister on logout.
router.delete('/:token', requireAuth, async (req, res, next) => {
  try {
    await pool.query('DELETE FROM device_tokens WHERE token = $1', [
      req.params.token,
    ]);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
