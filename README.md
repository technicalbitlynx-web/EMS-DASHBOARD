# Bank Server Room — Environmental Monitoring System (EMS) Dashboard

> **Bitlynx Controls Ltd** · Lugoda Branch · 2026  
> A bespoke, browser-based IoT dashboard for real-time monitoring of a bank server room environment.

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Features](#features)
4. [Technology Stack](#technology-stack)
5. [Sensor Coverage](#sensor-coverage)
6. [Dashboard Tabs](#dashboard-tabs)
7. [Project Structure](#project-structure)
8. [Getting Started (Local)](#getting-started-local)
9. [Deploying to DigitalOcean](#deploying-to-digitalocean)
10. [Environment Variables](#environment-variables)
11. [Data Simulator](#data-simulator)
12. [MQTT Topic Schema](#mqtt-topic-schema)
13. [API Reference](#api-reference)
14. [User Roles](#user-roles)
15. [Node-RED Flows](#node-red-flows)

---

## Overview

This dashboard is the **Application Layer** of a four-tier IoT Environmental Monitoring System deployed in a bank server room. It provides real-time situational awareness, historical trend analysis, threshold-based alerting, and exportable reports — all accessible from any browser on the LAN or via the internet.

The system monitors:

| Category | Parameters |
|---|---|
| Temperature & Humidity | °C, % RH per zone |
| Power Quality | Voltage (V), Current (A), Active Power (W), Power Factor, Energy (kWh) |
| Door / Access Control | Open / Closed state with event log |
| Smoke & Gas Detection | Level (%), alarm state, gas type |
| Dehumidifier | On/Off state, runtime log |

---

## System Architecture

```
Sensors (RS485 / I²C / GPIO / Analog)
        │
        ▼  Modbus RTU / UART / GPIO
  IoT Edge Nodes / Microcontrollers
        │
        ▼  MQTT publish  →  ems/raw/{type}/{id}
  Eclipse Mosquitto  (MQTT Broker, port 1883)
        │
        ▼  MQTT subscribe
     Node-RED  (Data Flow Engine, port 1880)
       ├── Normalise & validate payloads
       ├── Evaluate threshold rules
       ├── Write to PostgreSQL
       └── Republish  →  ems/dashboard/{type}/{id}
        │
        ▼  MQTT subscribe  ems/dashboard/#
  Express.js API Server  (port 3001)
       ├── REST API  (/api/*)
       └── WebSocket Server  (/ws)
        │
        ▼  HTTP + WebSocket
  Browser Dashboard  (Bespoke HTML SPA)
        │
        ▼  (time-series storage)
  Supabase PostgreSQL  (cloud-hosted)
```

**Gateway Hardware:** Industrial Mini PC (DIN-rail, Windows 11) running Mosquitto, Node-RED, and the Express.js server on the local LAN.

---

## Features

- **Real-time gauges** — SVG circular gauges update live via WebSocket (no page refresh needed)
- **9-tab dashboard** — dedicated view per sensor category plus Alerts, Reports, and Admin
- **Historical charts** — 24-hour trend lines via Chart.js, selectable per sensor
- **Threshold alerting** — configurable warning/critical rules per sensor metric
- **Alert management** — active alert list, acknowledgement, full history log
- **PDF export** — client-side PDF generation with jsPDF and summary tables
- **CSV export** — server-side streaming CSV for sensor readings and alert history
- **Role-based access control** — Admin / Operator / Viewer roles enforced server-side via JWT
- **Light / Dark theme** — persisted per browser
- **Responsive layout** — works on desktop, tablet, and mobile
- **Data simulator** — realistic 7-day historical seed + live 30-second updates (for demo/testing)

---

## Technology Stack

| Layer | Technology |
|---|---|
| **Backend** | Node.js 20 + Express.js 4 |
| **Database** | PostgreSQL 16 (Supabase cloud / local Docker) |
| **Real-time** | WebSocket (`ws` npm package) |
| **MQTT client** | `mqtt` npm package (v5) |
| **Authentication** | JWT (`jsonwebtoken`) + bcryptjs |
| **Data flows** | Node-RED with `pg` global context |
| **MQTT broker** | Eclipse Mosquitto 2 |
| **Frontend** | Vanilla HTML5 / CSS3 / JavaScript (no framework) |
| **Charts** | Chart.js 4 (CDN) |
| **PDF export** | jsPDF + jsPDF-autoTable (CDN) |
| **Icons / Fonts** | Font Awesome 6 + Google Fonts (Poppins) |
| **Cloud hosting** | DigitalOcean App Platform |
| **Containerisation** | Docker + Docker Compose (optional) |

---

## Sensor Coverage

### B.1.1 — Sensing Layer

| Sensor | Model | Parameter | Interface |
|---|---|---|---|
| Temperature & Humidity | Sensirion SHT40 / RS485 Industrial Probe | 0–70 °C / 0–100 % RH ±2 % | I²C / Modbus RTU |
| Power Monitoring | PZEM-004T v3.0 / CT Clamp | Voltage, Current, Power, PF, Energy | UART / RS485 |
| Door & Access | Magnetic Reed Switch | Open / Closed | GPIO Digital |
| Smoke / Gas | MQ-2 / MQ-135 | Smoke, CO, NH₃ | Analog / GPIO |
| Dehumidifier State | Dantherm CDP 45 dry-contact relay | On / Off | GPIO Digital |

### Default Alert Thresholds

| Parameter | Warning | Critical |
|---|---|---|
| Temperature | > 24 °C | > 27 °C |
| Humidity | > 70 % or < 35 % | > 80 % or < 25 % |
| Power Factor | < 0.85 | < 0.75 |
| Current | > 80 A | > 100 A |
| Smoke Level | > 20 % | > 50 % |

All thresholds are fully configurable via the **Admin → Alert Rules** panel.

---

## Dashboard Tabs

| Tab | Description |
|---|---|
| **Overview** | Status grid — one card per sensor, colour-coded by severity. Summary stats. |
| **Environment** | Zone selector, temperature and humidity circular gauges, 24-hour trend chart. |
| **Power** | Voltage, Current, Power, and Power Factor gauges. Energy accumulator. Trend chart. |
| **Access** | Door status tiles (open/closed icons). Recent door event log table. |
| **Air Quality** | Smoke/gas level bar gauges. Alarm state LED. Gas type label. |
| **Dehumidifier** | On/Off state indicator. State history log. |
| **Alerts** | Active alert list with acknowledge button. History table with severity filter. Alert rule builder (CRUD). |
| **Reports** | Date range selectors. CSV download for sensor data and alerts. PDF report generation. |
| **Admin** | User management (CRUD). Sensor registry (CRUD). Data retention settings. *(Admin role only)* |

---

## Project Structure

```
EMS Dashboard/
├── .do/
│   └── app.yaml              ← DigitalOcean App Platform config
├── mosquitto/
│   └── config/
│       └── mosquitto.conf    ← Mosquitto broker config
├── node-red/
│   ├── flows.json            ← Node-RED data ingestion flows (6 tabs)
│   └── settings.js           ← Node-RED config (pg pool in global context)
├── public/
│   ├── index.html            ← Login / setup page
│   ├── dashboard.html        ← Main 9-tab SPA dashboard
│   └── app-api.js            ← Fetch API helper library
├── server/
│   ├── index.js              ← Express app entry point
│   ├── simulator.js          ← Data simulator (seed + live)
│   ├── db/
│   │   ├── schema.sql        ← PostgreSQL schema (auto-applied on startup)
│   │   └── index.js          ← pg Pool (supports DATABASE_URL + DATABASE_PASSWORD)
│   ├── middleware/
│   │   └── auth.js           ← JWT auth + role guard middleware
│   ├── mqtt/
│   │   └── client.js         ← MQTT subscriber → WebSocket broadcaster
│   ├── routes/
│   │   ├── auth.js           ← Login, register, user management
│   │   ├── sensors.js        ← Sensor registry CRUD + latest readings
│   │   ├── readings.js       ← Historical queries + summary stats
│   │   ├── alerts.js         ← Alert history, rules, acknowledge
│   │   ├── reports.js        ← CSV + JSON report endpoints
│   │   └── settings.js       ← App settings with JSONB merge
│   └── ws/
│       └── broadcaster.js    ← WebSocket server + broadcast()
├── .env.example              ← Environment variable template
├── .gitignore
├── docker-compose.yml        ← Optional: full local stack (Mosquitto + Node-RED + DB + App)
├── Dockerfile                ← Express.js app container
├── Dockerfile.nodered        ← Node-RED container with pg installed
├── package.json
├── start.ps1                 ← Windows one-click start script (no Docker)
└── README.md
```

---

## Getting Started (Local)

### Prerequisites

- [Node.js 20+](https://nodejs.org/)
- A [Supabase](https://supabase.com) project **or** PostgreSQL running locally
- *(Optional)* [Eclipse Mosquitto](https://mosquitto.org/) for live sensor data

### 1. Clone and install

```powershell
git clone https://github.com/technicalbitlynx-web/ems-dashboard.git
cd ems-dashboard
npm install
```

### 2. Configure environment

```powershell
Copy-Item .env.example .env
# Edit .env with your Supabase connection string and password
```

Key variables to set:

```env
DATABASE_URL=postgresql://postgres.YOUR_PROJECT@aws-0-REGION.pooler.supabase.com:6543/postgres
DATABASE_PASSWORD=your_supabase_password
JWT_SECRET=your_long_random_secret
ENABLE_SIMULATOR=true        # set to false once real sensors are connected
```

### 3. Start

```powershell
.\start.ps1
# or directly:
node server/index.js
```

The server will:
1. Connect to PostgreSQL
2. Auto-create all tables and seed default sensors/thresholds
3. Seed 7 days of simulated historical data (first run only, if `ENABLE_SIMULATOR=true`)
4. Start the live simulator (30-second updates)
5. Open `http://localhost:3001`

### 4. First login

Go to `http://localhost:3001` → click **"Create admin account"** to complete the initial setup.

---

## Deploying to DigitalOcean

### App Platform (Recommended — $5/month)

1. Push this repo to GitHub
2. Go to [cloud.digitalocean.com/apps](https://cloud.digitalocean.com/apps) → **Create App**
3. Connect GitHub → select the `ems-dashboard` repo → branch `main`
4. Choose **Basic · 512 MB · Frankfurt** region
5. Set the following environment variables (mark `DATABASE_PASSWORD` and `JWT_SECRET` as **Secret**):

| Variable | Value |
|---|---|
| `DATABASE_URL` | Your Supabase pooler connection string |
| `DATABASE_PASSWORD` | Your Supabase database password |
| `JWT_SECRET` | A long random string |
| `ENABLE_SIMULATOR` | `true` (for demo) / `false` (for production with real sensors) |

6. Click **Deploy** — your public HTTPS URL appears in ~3 minutes.

The `.do/app.yaml` file in this repo pre-configures the deployment settings.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string (without password) |
| `DATABASE_PASSWORD` | Yes | Database password (kept separate to avoid URL-encoding issues) |
| `PORT` | No | HTTP port — defaults to `3001` |
| `JWT_SECRET` | Yes | Secret key for signing JWT tokens |
| `MQTT_BROKER` | No | MQTT broker URL, e.g. `mqtt://localhost:1883` |
| `ENABLE_SIMULATOR` | No | Set `true` to run the built-in data simulator |

---

## Data Simulator

When `ENABLE_SIMULATOR=true`, the server runs a built-in sensor data simulator:

**Historical seed (runs once on first startup)**
- Generates 7 days of readings at 5-minute intervals for all 7 sensors
- ~14,000 rows inserted in batched queries
- Includes realistic daily curves (warmer afternoons, higher load during business hours)
- Pre-seeds 6 alert history entries (temperature spike, smoke warning, door event, power factor dip)

**Live simulation (runs every 30 seconds)**
- Continuously generates new readings for all sensors
- Broadcasts updates via WebSocket — gauges animate in real-time
- Values use smooth exponential smoothing to avoid jarring jumps

**Realistic value ranges:**

| Sensor | Normal Range | Behaviour |
|---|---|---|
| Temperature | 22–26 °C | Daily sine curve; peaks 14:00 EAT |
| Humidity | 45–65 % RH | Dehumidifier activates at > 60 %, deactivates at < 50 % |
| Voltage | 228–235 V | Small Gaussian noise around 231 V |
| Current | 22–52 A | Higher during business hours (08:00–20:00) |
| Power Factor | 0.88–0.96 | Slow drift with small noise |
| Smoke Level | 0.4–8 % | Rare spikes to 19–27 % (simulated test events) |
| Door | Closed | ~3 open events per day during business hours |

---

## MQTT Topic Schema

### Raw topics (edge nodes → Mosquitto)

```
ems/raw/temperature/{sensor_id}    {"temp_c": 24.3, "humidity_pct": 55.1, "timestamp": "..."}
ems/raw/power/{sensor_id}          {"voltage_v": 231, "current_a": 45.2, "power_w": 10451, "power_factor": 0.92, "energy_kwh": 1234.5, "timestamp": "..."}
ems/raw/door/{sensor_id}           {"state": "open"|"closed", "timestamp": "..."}
ems/raw/smoke/{sensor_id}          {"level_pct": 5.2, "alarm": false, "gas_type": "smoke", "timestamp": "..."}
ems/raw/dehumidifier/{sensor_id}   {"state": "on"|"off", "timestamp": "..."}
```

### Processed topics (Node-RED → Express)

```
ems/dashboard/temperature/{id}     {...raw + status: "normal"|"warning"|"critical"}
ems/dashboard/power/{id}           {...raw + status}
ems/dashboard/door/{id}            {...raw + is_open: bool + status}
ems/dashboard/smoke/{id}           {...raw + status}
ems/dashboard/dehumidifier/{id}    {...raw + is_on: bool}
ems/dashboard/alert                {sensor_id, sensor_type, metric, value, threshold, severity, message, timestamp}
```

---

## API Reference

All endpoints except `/api/auth/login` and `/api/auth/setup` require `Authorization: Bearer <token>`.

| Method | Path | Role | Description |
|---|---|---|---|
| `POST` | `/api/auth/setup` | Public | Create first admin account (one-time) |
| `POST` | `/api/auth/login` | Public | Login, returns JWT token |
| `POST` | `/api/auth/register` | Admin | Create new user |
| `GET` | `/api/auth/users` | Admin | List all users |
| `PUT` | `/api/auth/users/:email` | Admin | Update user role/details |
| `DELETE` | `/api/auth/users/:email` | Admin | Delete user |
| `GET` | `/api/sensors` | All | List all sensors |
| `GET` | `/api/sensors/latest` | All | Latest reading per sensor |
| `POST` | `/api/sensors` | Admin | Register sensor |
| `PUT` | `/api/sensors/:id` | Admin/Op | Update sensor config/thresholds |
| `DELETE` | `/api/sensors/:id` | Admin | Delete sensor |
| `GET` | `/api/readings` | All | Historical readings (filter by sensor, date range) |
| `GET` | `/api/readings/summary` | All | Min/max/avg stats per sensor |
| `GET` | `/api/alerts/active` | All | Unresolved alerts |
| `GET` | `/api/alerts/history` | All | Alert log (paginated, filterable) |
| `PUT` | `/api/alerts/:id/acknowledge` | Admin/Op | Acknowledge alert |
| `GET` | `/api/alerts/rules` | All | List threshold rules |
| `POST` | `/api/alerts/rules` | Admin/Op | Create rule |
| `PUT` | `/api/alerts/rules/:id` | Admin/Op | Update rule |
| `DELETE` | `/api/alerts/rules/:id` | Admin | Delete rule |
| `GET` | `/api/reports/csv` | All | Download sensor data as CSV |
| `GET` | `/api/reports/alerts-csv` | All | Download alert history as CSV |
| `GET` | `/api/reports/summary-json` | All | Summary data for PDF generation |
| `GET` | `/api/settings` | All | Get all app settings |
| `PUT` | `/api/settings/:key` | Admin | Update setting group |
| `POST` | `/api/settings/retention/apply` | Admin | Delete readings older than retention period |
| `GET` | `/api/health` | Public | Server health check |

---

## User Roles

| Role | Capabilities |
|---|---|
| **Admin** | Full access — user management, sensor configuration, alert rules, data deletion, all reports |
| **Operator** | View all dashboards, acknowledge alerts, configure thresholds, export reports |
| **Viewer** | Read-only — view dashboards and download reports; cannot modify any configuration |

---

## Node-RED Flows

Six flows run automatically when Node-RED starts:

| Tab | Topic Subscribed | Function |
|---|---|---|
| Temperature & Humidity | `ems/raw/temperature/#` | Parse → threshold check → DB write → re-publish to `ems/dashboard/temperature/#` |
| Power Monitoring | `ems/raw/power/#` | Parse → threshold check → DB write → re-publish |
| Door & Access | `ems/raw/door/#` | Parse → open event check → DB write → re-publish |
| Smoke & Gas | `ems/raw/smoke/#` | Parse → alarm check → DB write → re-publish |
| Dehumidifier | `ems/raw/dehumidifier/#` | Parse → state log → DB write → re-publish |
| Alert Logging | `ems/dashboard/alert` | INSERT into `alert_history` table |

The PostgreSQL connection is configured via environment variables (`POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`) which are injected into the Node-RED container via Docker Compose.

---

## License

Proprietary — © 2026 Bitlynx Controls Ltd. All rights reserved.

---

*Built with ❤ by Bitlynx Controls Ltd for reliable, real-time server room monitoring.*
