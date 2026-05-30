const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const pool    = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router     = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'ems_jwt_secret_change_in_production';

function makeToken(user) {
  return jwt.sign(
    { email: user.email, username: user.username, role: user.role, full_name: user.full_name },
    JWT_SECRET,
    { expiresIn: '24h' }
  );
}

// POST /api/auth/login
router.post('/login', async (req, res, next) => {
  try {
    const identifier = String(req.body.identifier || '').trim().toLowerCase();
    const password   = String(req.body.password   || '');
    if (!identifier || !password)
      return res.status(400).json({ error: 'Identifier and password required' });

    const { rows } = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR username = $1',
      [identifier]
    );
    const user = rows[0];
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    await pool.query('UPDATE users SET last_login = NOW() WHERE email = $1', [user.email]);
    await pool.query(
      'INSERT INTO login_history (identifier, last_used) VALUES ($1, NOW()) ON CONFLICT (identifier) DO UPDATE SET last_used = NOW()',
      [identifier]
    );

    res.json({
      token: makeToken(user),
      user: {
        email:      user.email,
        username:   user.username,
        full_name:  user.full_name,
        role:       user.role,
        department: user.department,
      },
    });
  } catch (err) { next(err); }
});

// POST /api/auth/register  (admin only after first user)
router.post('/register', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    const { email, username, password, full_name, role, department, phone } = req.body;
    if (!email || !username || !password)
      return res.status(400).json({ error: 'email, username and password are required' });
    if (!['admin', 'operator', 'viewer'].includes(role))
      return res.status(400).json({ error: 'role must be admin, operator, or viewer' });

    const hash = await bcrypt.hash(String(password), 10);
    await pool.query(
      'INSERT INTO users (email, username, password_hash, full_name, role, department, phone) VALUES ($1,$2,$3,$4,$5,$6,$7)',
      [email.toLowerCase().trim(), username.trim(), hash, full_name || username, role, department || 'Operations', phone || '']
    );
    res.status(201).json({ success: true });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: 'Email or username already taken' });
    next(err);
  }
});

// POST /api/auth/setup  (creates first admin — only works when no users exist)
router.post('/setup', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT COUNT(*) FROM users');
    if (Number(rows[0].count) > 0)
      return res.status(403).json({ error: 'Setup already complete' });

    const { email, username, password, full_name } = req.body;
    if (!email || !username || !password)
      return res.status(400).json({ error: 'email, username and password required' });

    const hash = await bcrypt.hash(String(password), 10);
    const { rows: ins } = await pool.query(
      'INSERT INTO users (email, username, password_hash, full_name, role, department) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [email.toLowerCase().trim(), username.trim(), hash, full_name || username, 'admin', 'IT Operations']
    );
    res.status(201).json({ token: makeToken(ins[0]), user: { email: ins[0].email, username: ins[0].username, role: ins[0].role } });
  } catch (err) { next(err); }
});

// GET /api/auth/me
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT email, username, full_name, role, department, phone, last_login, created_at FROM users WHERE email = $1',
      [req.user.email]
    );
    if (!rows[0]) return res.status(404).json({ error: 'User not found' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// GET /api/auth/login-history
router.get('/login-history', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT identifier FROM login_history ORDER BY last_used DESC LIMIT 5');
    res.json(rows.map(r => r.identifier));
  } catch (err) { next(err); }
});

// GET /api/auth/users  (admin)
router.get('/users', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT email, username, full_name, role, department, phone, last_login, created_at FROM users ORDER BY created_at DESC'
    );
    res.json(rows);
  } catch (err) { next(err); }
});

// PUT /api/auth/users/:email  (admin)
router.put('/users/:email', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    const { full_name, role, department, phone } = req.body;
    if (role && !['admin', 'operator', 'viewer'].includes(role))
      return res.status(400).json({ error: 'Invalid role' });
    await pool.query(
      'UPDATE users SET full_name = COALESCE($1, full_name), role = COALESCE($2, role), department = COALESCE($3, department), phone = COALESCE($4, phone) WHERE email = $5',
      [full_name || null, role || null, department || null, phone || null, req.params.email]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// DELETE /api/auth/users/:email  (admin)
router.delete('/users/:email', requireAuth, requireRole('admin'), async (req, res, next) => {
  try {
    if (req.params.email === req.user.email)
      return res.status(400).json({ error: 'Cannot delete your own account' });
    await pool.query('DELETE FROM users WHERE email = $1', [req.params.email]);
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
