-- ================================================================
-- EMS Dashboard — PostgreSQL Schema
-- Bank Server Room Environmental Monitoring System
-- ================================================================

-- Users & RBAC
CREATE TABLE IF NOT EXISTS users (
  email         TEXT PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'viewer'
                  CHECK (role IN ('admin', 'operator', 'viewer')),
  department    TEXT NOT NULL DEFAULT 'Operations',
  phone         TEXT NOT NULL DEFAULT '',
  preferences   JSONB NOT NULL DEFAULT '{"theme":"light","notifications":true}'::jsonb,
  last_login    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Quick-login identifier history
CREATE TABLE IF NOT EXISTS login_history (
  identifier TEXT PRIMARY KEY,
  last_used  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sensor registry — one row per physical sensor/actuator
CREATE TABLE IF NOT EXISTS sensors (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL
                CHECK (type IN ('temperature','power','door','smoke','dehumidifier')),
  name        TEXT NOT NULL,
  location    TEXT NOT NULL DEFAULT '',
  zone        TEXT NOT NULL DEFAULT 'Main',
  mqtt_topic  TEXT NOT NULL UNIQUE,
  thresholds  JSONB NOT NULL DEFAULT '{}'::jsonb,
  enabled     BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Time-series sensor readings (core table)
CREATE TABLE IF NOT EXISTS sensor_readings (
  id            BIGSERIAL PRIMARY KEY,
  sensor_id     TEXT NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
  sensor_type   TEXT NOT NULL,
  reading_ts    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  value_numeric NUMERIC(18,4),           -- primary numeric value (temp, voltage, etc.)
  value_json    JSONB NOT NULL DEFAULT '{}'::jsonb,  -- full payload
  unit          TEXT NOT NULL DEFAULT '',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sr_sensor_ts   ON sensor_readings (sensor_id, reading_ts DESC);
CREATE INDEX IF NOT EXISTS idx_sr_type_ts     ON sensor_readings (sensor_type, reading_ts DESC);

-- Alert threshold rules (configurable per sensor/metric)
CREATE TABLE IF NOT EXISTS alert_rules (
  id               SERIAL PRIMARY KEY,
  sensor_id        TEXT NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
  metric           TEXT NOT NULL,
  operator         TEXT NOT NULL CHECK (operator IN ('>','<','>=','<=','=','!=')),
  threshold        NUMERIC(18,4) NOT NULL,
  severity         TEXT NOT NULL CHECK (severity IN ('warning','critical')),
  enabled          BOOLEAN NOT NULL DEFAULT true,
  cooldown_minutes INTEGER NOT NULL DEFAULT 15,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alert event history
CREATE TABLE IF NOT EXISTS alert_history (
  id              BIGSERIAL PRIMARY KEY,
  rule_id         INTEGER REFERENCES alert_rules(id) ON DELETE SET NULL,
  sensor_id       TEXT NOT NULL,
  triggered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ,
  message         TEXT NOT NULL,
  severity        TEXT NOT NULL,
  acknowledged_by TEXT,
  acknowledged_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ah_triggered  ON alert_history (triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_ah_sensor     ON alert_history (sensor_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_ah_unresolved ON alert_history (resolved_at) WHERE resolved_at IS NULL;

-- Application-wide settings
CREATE TABLE IF NOT EXISTS app_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- Default seed data
-- ================================================================

INSERT INTO app_settings (key, value) VALUES
  ('general', '{"theme":"light","refreshRate":10,"dataRetentionDays":90}'::jsonb),
  ('alerts',  '{"emailEnabled":false,"smsEnabled":false,"smtpHost":"","smtpPort":587,"smtpUser":"","smtpFrom":"ems@bank.local","smsGateway":""}'::jsonb),
  ('display', '{"tempUnit":"C","pressureUnit":"bar","energyUnit":"kWh","siteName":"Bank Server Room"}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Default sensors (update IDs/topics at commissioning)
INSERT INTO sensors (id, type, name, location, zone, mqtt_topic, thresholds) VALUES
  ('temp_zone1',       'temperature',  'Temperature Sensor — Zone 1', 'Server Aisle A',      'Zone 1',   'ems/raw/temperature/zone1',       '{"temp_c":{"warn_hi":24,"crit_hi":27,"warn_lo":15,"crit_lo":10},"humidity_pct":{"warn_hi":70,"crit_hi":80,"warn_lo":35,"crit_lo":25}}'::jsonb),
  ('temp_zone2',       'temperature',  'Temperature Sensor — Zone 2', 'Server Aisle B',      'Zone 2',   'ems/raw/temperature/zone2',       '{"temp_c":{"warn_hi":24,"crit_hi":27,"warn_lo":15,"crit_lo":10},"humidity_pct":{"warn_hi":70,"crit_hi":80,"warn_lo":35,"crit_lo":25}}'::jsonb),
  ('power_main',       'power',        'Main Power Feed',             'Distribution Board',  'Utility',  'ems/raw/power/main',              '{"power_factor":{"warn_lo":0.85,"crit_lo":0.75},"current_a":{"warn_hi":80,"crit_hi":100},"voltage_v":{"warn_hi":250,"crit_hi":260,"warn_lo":210,"crit_lo":200}}'::jsonb),
  ('door_main',        'door',         'Main Entry Door',             'Server Room Entrance','Security', 'ems/raw/door/main',               '{"alarm_on_open":true}'::jsonb),
  ('door_rack',        'door',         'Rack Cabinet Door',           'Rack Row A',          'Security', 'ems/raw/door/rack',               '{"alarm_on_open":true}'::jsonb),
  ('smoke_sensor1',    'smoke',        'Smoke Detector — Centre',     'Ceiling Centre',      'Main',     'ems/raw/smoke/sensor1',           '{"level_pct":{"warn_hi":20,"crit_hi":50}}'::jsonb),
  ('dehumidifier_main','dehumidifier', 'Dantherm CDP 45',             'North Wall',          'Main',     'ems/raw/dehumidifier/unit1',      '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Default alert rules
INSERT INTO alert_rules (sensor_id, metric, operator, threshold, severity, cooldown_minutes) VALUES
  ('temp_zone1',    'temp_c',       '>',  27,   'critical', 5),
  ('temp_zone1',    'temp_c',       '>',  24,   'warning',  15),
  ('temp_zone1',    'humidity_pct', '>',  70,   'warning',  15),
  ('temp_zone1',    'humidity_pct', '>',  80,   'critical', 5),
  ('temp_zone2',    'temp_c',       '>',  27,   'critical', 5),
  ('temp_zone2',    'temp_c',       '>',  24,   'warning',  15),
  ('temp_zone2',    'humidity_pct', '>',  70,   'warning',  15),
  ('temp_zone2',    'humidity_pct', '>',  80,   'critical', 5),
  ('power_main',    'power_factor', '<',  0.85, 'warning',  30),
  ('power_main',    'power_factor', '<',  0.75, 'critical', 10),
  ('power_main',    'current_a',    '>',  80,   'warning',  15),
  ('power_main',    'current_a',    '>',  100,  'critical', 5),
  ('smoke_sensor1', 'level_pct',    '>',  20,   'warning',  5),
  ('smoke_sensor1', 'level_pct',    '>',  50,   'critical', 1)
ON CONFLICT DO NOTHING;
