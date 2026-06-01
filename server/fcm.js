'use strict';

// Lazy-initialised Firebase Admin wrapper for sending push notifications.
// The service-account JSON is supplied via the FCM_SERVICE_ACCOUNT env var
// (either raw JSON or base64-encoded JSON). When it is absent, push is a no-op
// so the rest of the app keeps working without Firebase configured.

let _app = null;
let _messaging = null;
let _initTried = false;

function _init() {
  if (_initTried) return _messaging;
  _initTried = true;

  const raw = process.env.FCM_SERVICE_ACCOUNT;
  if (!raw) {
    console.warn('[FCM] FCM_SERVICE_ACCOUNT not set — push disabled');
    return null;
  }

  let admin;
  try {
    admin = require('firebase-admin');
  } catch (_) {
    console.warn('[FCM] firebase-admin not installed — push disabled');
    return null;
  }

  try {
    const json = raw.trim().startsWith('{')
      ? raw
      : Buffer.from(raw, 'base64').toString('utf8');
    const credentials = JSON.parse(json);
    _app = admin.apps && admin.apps.length
      ? admin.app()
      : admin.initializeApp({ credential: admin.credential.cert(credentials) });
    _messaging = admin.messaging(_app);
    console.log('[FCM] Firebase Admin initialised');
  } catch (err) {
    console.error('[FCM] init failed:', err.message);
    _messaging = null;
  }
  return _messaging;
}

/**
 * Send a notification to a list of device tokens.
 * Returns { successCount, failureCount, invalidTokens[] }.
 */
async function sendToTokens(tokens, { title, body, data }) {
  const messaging = _init();
  if (!messaging || !tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0, invalidTokens: [] };
  }

  const message = {
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v)])
    ),
    android: { priority: 'high' },
    tokens,
  };

  const res = await messaging.sendEachForMulticast(message);
  const invalidTokens = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument'
      ) {
        invalidTokens.push(tokens[i]);
      }
    }
  });

  return {
    successCount: res.successCount,
    failureCount: res.failureCount,
    invalidTokens,
  };
}

function isConfigured() {
  return Boolean(process.env.FCM_SERVICE_ACCOUNT);
}

module.exports = { sendToTokens, isConfigured };
