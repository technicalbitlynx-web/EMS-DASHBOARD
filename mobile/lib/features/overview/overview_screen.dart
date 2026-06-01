import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/status_badge.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(realtimeProvider);
    final sensorsAsync = ref.watch(sensorsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sensorsProvider);
        await ref.read(realtimeProvider.notifier).refresh();
      },
      child: AsyncValueView<List<Sensor>>(
        value: sensorsAsync,
        onRetry: () => ref.invalidate(sensorsProvider),
        data: (sensors) {
          final enabled = sensors.where((s) => s.enabled).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryRow(
                sensorCount: enabled.length,
                critical: snapshot.criticalCount,
                warning: snapshot.warningCount,
              ),
              const SizedBox(height: 8),
              if (enabled.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyState(message: 'No sensors registered'),
                )
              else
                ...enabled.map((s) =>
                    _SensorRow(sensor: s, latest: snapshot.latest[s.id])),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.sensorCount,
    required this.critical,
    required this.warning,
  });
  final int sensorCount;
  final int critical;
  final int warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _SummaryCard(
                label: 'Sensors',
                value: '$sensorCount',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.sensors)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryCard(
                label: 'Warnings',
                value: '$warning',
                color: StatusColors.warning,
                icon: Icons.warning_amber_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _SummaryCard(
                label: 'Critical',
                value: '$critical',
                color: StatusColors.critical,
                icon: Icons.error_outline)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.sensor, this.latest});
  final Sensor sensor;
  final LatestReading? latest;

  IconData get _icon {
    switch (sensor.type) {
      case SensorTypes.temperature:
        return Icons.thermostat;
      case SensorTypes.power:
        return Icons.bolt;
      case SensorTypes.door:
        return Icons.meeting_room;
      case SensorTypes.smoke:
        return Icons.local_fire_department;
      case SensorTypes.dehumidifier:
        return Icons.water_drop;
      default:
        return Icons.sensors;
    }
  }

  String _summary() {
    final l = latest;
    if (l == null) return 'No data';
    switch (sensor.type) {
      case SensorTypes.temperature:
        return '${Fmt.num(l.tempC, unit: '°C')} · ${Fmt.num(l.humidityPct, unit: '%')} RH';
      case SensorTypes.power:
        return '${Fmt.num(l.powerW, decimals: 0, unit: ' W')} · ${Fmt.num(l.voltageV, decimals: 0, unit: ' V')}';
      case SensorTypes.door:
        return l.doorOpen ? 'OPEN' : 'Closed';
      case SensorTypes.smoke:
        return l.smokeAlarm
            ? 'ALARM'
            : '${Fmt.num(l.smokeLevelPct, unit: '%')} smoke';
      case SensorTypes.dehumidifier:
        return l.dehumidifierOn ? 'Running' : 'Off';
      default:
        return Fmt.num(l.valueNumeric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = latest?.status ?? 'unknown';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: StatusColors.of(status).withValues(alpha: 0.15),
          child: Icon(_icon, color: StatusColors.of(status)),
        ),
        title: Text(sensor.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_summary()}\n${sensor.location ?? sensor.zone ?? ''} · ${Fmt.ago(latest?.readingTs)}',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        isThreeLine: true,
        trailing: StatusBadge(status: status),
      ),
    );
  }
}
