const mqtt = require('mqtt');
const { broadcast } = require('../ws/broadcaster');

function initMqttClient() {
  const brokerUrl = process.env.MQTT_BROKER || 'mqtt://localhost:1883';

  const client = mqtt.connect(brokerUrl, {
    clientId: 'ems-dashboard-' + Math.random().toString(16).substr(2, 8),
    reconnectPeriod: 5000,
    connectTimeout: 15000,
  });

  client.on('connect', () => {
    console.log('[MQTT] Connected to broker:', brokerUrl);
    client.subscribe('ems/dashboard/#', { qos: 1 }, (err) => {
      if (err) console.error('[MQTT] Subscribe error:', err.message);
      else console.log('[MQTT] Subscribed to ems/dashboard/#');
    });
  });

  client.on('message', (topic, message) => {
    let payload;
    try { payload = JSON.parse(message.toString()); } catch (_) { payload = message.toString(); }

    // topic: ems/dashboard/{sensor_type}/{sensor_id}  or  ems/dashboard/alert
    const parts = topic.split('/');
    const sensorType = parts[2] || 'unknown';
    const sensorId   = parts[3] || null;

    broadcast({ type: 'sensor_update', sensor_type: sensorType, sensor_id: sensorId, payload, topic });
  });

  client.on('error',     (err) => console.error('[MQTT] Error:', err.message));
  client.on('offline',   ()    => console.log('[MQTT] Broker offline'));
  client.on('reconnect', ()    => console.log('[MQTT] Reconnecting...'));
}

module.exports = { initMqttClient };
