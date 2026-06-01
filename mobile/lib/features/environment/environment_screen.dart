import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/radial_gauge.dart';
import '../../shared/widgets/trend_chart.dart';

class EnvironmentScreen extends ConsumerStatefulWidget {
  const EnvironmentScreen({super.key});

  @override
  ConsumerState<EnvironmentScreen> createState() => _EnvironmentScreenState();
}

class _EnvironmentScreenState extends ConsumerState<EnvironmentScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final snapshot = ref.watch(realtimeProvider);

    return AsyncValueView<List<Sensor>>(
      value: sensorsAsync,
      onRetry: () => ref.invalidate(sensorsProvider),
      data: (sensors) {
        final temps =
            sensors.where((s) => s.type == SensorTypes.temperature).toList();
        if (temps.isEmpty) {
          return const EmptyState(
              message: 'No temperature sensors', icon: Icons.thermostat);
        }
        final selectedId = _selectedId ??= temps.first.id;
        final latest = snapshot.latest[selectedId];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(readingsProvider);
            await ref.read(realtimeProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (temps.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(labelText: 'Sensor'),
                  items: temps
                      .map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                runSpacing: 16,
                children: [
                  RadialGauge(
                    value: latest?.tempC,
                    min: 0,
                    max: 40,
                    label: 'Temperature',
                    unit: '°C',
                    color: StatusColors.of(latest?.status),
                  ),
                  RadialGauge(
                    value: latest?.humidityPct,
                    min: 0,
                    max: 100,
                    label: 'Humidity',
                    unit: '% RH',
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Last 24 hours',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _Trend(sensorId: selectedId),
            ],
          ),
        );
      },
    );
  }
}

class _Trend extends ConsumerWidget {
  const _Trend({required this.sensorId});
  final String sensorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      readingsProvider(ReadingsQuery(sensorId: sensorId, hours: 24)),
    );
    return AsyncValueView<List<Reading>>(
      value: async,
      onRetry: () => ref.invalidate(readingsProvider),
      data: (rows) {
        final temp = <FlSpot>[];
        final hum = <FlSpot>[];
        for (final r in rows) {
          final t = DateTime.tryParse(r.readingTs)?.millisecondsSinceEpoch;
          if (t == null) continue;
          final x = t.toDouble();
          final tc = r.valueJson['temp_c'];
          final h = r.valueJson['humidity_pct'];
          if (tc is num) temp.add(FlSpot(x, tc.toDouble()));
          if (h is num) hum.add(FlSpot(x, h.toDouble()));
        }
        return TrendChart(series: [
          TrendSeries(
              label: 'Temp °C', color: StatusColors.critical, spots: temp),
          TrendSeries(label: 'Humidity %', color: Colors.blue, spots: hum),
        ]);
      },
    );
  }
}
