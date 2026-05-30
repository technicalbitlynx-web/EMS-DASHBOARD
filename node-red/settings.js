// Node-RED settings for EMS Dashboard
// The pgPool in functionGlobalContext lets function nodes INSERT to PostgreSQL
// without the node-red-node-postgresql contrib package.

const { Pool } = require('pg');

const pgPool = new Pool({
  host:     process.env.POSTGRES_HOST     || 'db',
  port:     Number(process.env.POSTGRES_PORT) || 5432,
  database: process.env.POSTGRES_DB       || 'ems_dashboard',
  user:     process.env.POSTGRES_USER     || 'ems',
  password: process.env.POSTGRES_PASSWORD || 'ems_secure_2026',
  max: 5,
  idleTimeoutMillis: 30000,
});

pgPool.on('error', (err) => {
  console.error('[Node-RED pgPool]', err.message);
});

module.exports = {
  uiPort: process.env.PORT || 1880,

  mqttReconnectTime: 15000,
  serialReconnectTime: 15000,
  debugMaxLength: 1000,

  // Allow function nodes to use external modules via require()
  functionExternalModules: false,

  // Expose pgPool to all function nodes via global.get('pgPool')
  functionGlobalContext: {
    pgPool,
  },

  exportGlobalContextKeys: false,

  logging: {
    console: {
      level: 'info',
      metrics: false,
      audit: false,
    },
  },

  editorTheme: {
    page: {
      title: 'EMS — Node-RED Flow Editor',
    },
    header: {
      title: 'EMS Flow Editor',
    },
    projects: {
      enabled: false,
    },
  },

  // Flows file name (in /data volume)
  flowFile: 'flows.json',

  // Credential encryption secret — set via env in docker-compose
  credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET || 'ems_nodered_secret_2026',
};
