# EMS Monitor — Flutter mobile app

A native Android app for monitoring the bank server room from a phone (over
cellular or LAN). It consumes the existing EMS REST API and mirrors the web
dashboard with full feature parity: live readings, environment/power charts,
access & air-quality, dehumidifier, alerts (acknowledge + rules), reports
(CSV/PDF), admin (users/sensors/retention), and push notifications for critical
alerts.

## Architecture

```
lib/
  core/            config, Dio network client + auth interceptor, secure storage,
                   theme, go_router, formatting utils
  domain/models/   plain immutable models (User, Sensor, Reading, Alert, …)
  data/
    repositories/  one thin repository per API resource
    realtime/      RealtimeController — polling (default) or WebSocket transport
  features/        auth, shell, overview, environment, power, access,
                   air_quality, dehumidifier, alerts, reports, admin, notifications
  shared/          reusable widgets (gauge, charts, badges) + data providers
```

- **State:** Riverpod. **Routing:** go_router. **Charts:** fl_chart + a custom
  radial-gauge painter. **HTTP:** dio (Bearer-token interceptor, 401 → logout).
- **Realtime is pluggable.** Default is **REST polling** (works on Vercel
  serverless). Set `REALTIME_TRANSPORT=ws` to use the WebSocket `/ws` instead —
  only works against a persistent host (e.g. DigitalOcean), not Vercel.

## Configuration (build-time, via `--dart-define`)

| Key | Default | Notes |
|-----|---------|-------|
| `API_BASE_URL` | `http://10.0.2.2:3002` | Backend base URL. `10.0.2.2` = host loopback from the Android emulator. Use your Vercel HTTPS URL or LAN IP for a real device. |
| `REALTIME_TRANSPORT` | `polling` | `polling` or `ws`. |
| `POLL_INTERVAL_SECONDS` | `15` | Polling cadence. |
| `ENABLE_PUSH` | `false` | Set `true` only after adding `google-services.json` (see Push below). |

You can also change the server URL at runtime: on the login screen tap the
**server icon** (top-right) and enter any base URL — it's saved on the device.

## Run (development)

```bash
cd mobile
flutter pub get

# Android emulator → local backend on the host (port 3002):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3002

# Physical phone on the same Wi-Fi as the dev machine:
flutter run --dart-define=API_BASE_URL=http://<your-PC-LAN-IP>:3002
```

The debug build permits cleartext HTTP (for LAN testing); release builds are
HTTPS-only.

## Build the installable APK

```bash
# Release (HTTPS backend, e.g. Vercel):
flutter build apk --release --dart-define=API_BASE_URL=https://<your-app>.vercel.app
# → build/app/outputs/flutter-apk/app-release.apk

# Debug (allows http:// to a LAN server for immediate testing):
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk
```

Install on the phone: transfer the `.apk` and tap it (enable "install unknown
apps"), or `adb install app-release.apk`. On first launch, if the server isn't
the default, tap the **server icon** on the login screen and enter the URL.

> Release uses the **debug signing key** for now. For Play Store or stable
> update identity, generate a keystore (`keytool`) and configure
> `android/key.properties` + `signingConfigs`.

## Push notifications (FCM) — optional setup

Push is **off by default** and the app runs fully without it. To enable:

1. Create a Firebase project, add an Android app with package
   `com.ems.ems_mobile`, download **`google-services.json`** into
   `mobile/android/app/`.
2. Add the Google-services Gradle plugin (project + app `build.gradle.kts`).
3. Build with `--dart-define=ENABLE_PUSH=true`.
4. **Backend:** set `FCM_SERVICE_ACCOUNT` (Firebase service-account JSON) and
   `CRON_SECRET` env vars on the server. The Vercel cron
   (`/api/cron/dispatch-alerts`, every minute) sends a push for each new alert.
   Note: on Vercel-only, alert rows are produced only by a real data source
   (MQTT/hardware) — the built-in simulator runs on a persistent host, not on
   serverless.

The app requests notification permission after login, registers its FCM token
(`POST /api/devices/register`), and deep-links a notification tap to the
relevant alert.

## Backend additions that power the app

All additive (new tables/routes only): `device_tokens` table + `pushed_at`
column (`server/db/schema.sql`), `server/routes/devices.js`,
`server/routes/cron.js`, `server/fcm.js`, plus the Vercel cron entry. The app
otherwise reuses the existing `/api/*` endpoints unchanged.
