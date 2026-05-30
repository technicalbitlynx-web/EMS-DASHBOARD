const { Pool } = require('pg');

// Build the pg config from either:
//   DATABASE_URL + DATABASE_PASSWORD  (Supabase / PaaS — avoids URL-encoding issues)
//   or individual POSTGRES_* env vars (local / Docker)
function buildConfig() {
  const url = process.env.DATABASE_URL;
  if (url) {
    const parsed  = new URL(url);
    const password = process.env.DATABASE_PASSWORD || decodeURIComponent(parsed.password || '');
    return {
      host:     parsed.hostname,
      port:     Number(parsed.port) || 5432,
      database: parsed.pathname.replace(/^\//, '') || 'postgres',
      user:     parsed.username || 'postgres',
      password,
      ssl:      { rejectUnauthorized: false },
      max: 10,
      idleTimeoutMillis:      30000,
      connectionTimeoutMillis: 10000,
    };
  }
  return {
    host:     process.env.POSTGRES_HOST     || 'localhost',
    port:     Number(process.env.POSTGRES_PORT) || 5432,
    database: process.env.POSTGRES_DB       || 'ems_dashboard',
    user:     process.env.POSTGRES_USER     || 'ems',
    password: process.env.POSTGRES_PASSWORD || '',
    ssl:      process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
    max: 10,
    idleTimeoutMillis:      30000,
    connectionTimeoutMillis: 10000,
  };
}

const pool = new Pool(buildConfig());

pool.on('error', (err) => {
  console.error('[DB] Pool error:', err.message);
});

module.exports = pool;
