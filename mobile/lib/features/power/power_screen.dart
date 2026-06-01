import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/metric_tile.dart';
import '../../shared/widgets/trend_chart.dart';

class PowerScreen extends ConsumerStatefulWidget {
  const PowerScreen({super.key});

  @override
  ConsumerState<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends ConsumerState<PowerScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final snapshot = ref.watch(realtimeProvider);

    return AsyncValueView<List<Sensor>>(
      value: sensorsAsync,
      onRetry: () => ref.invalidate(sensorsProvider),
      data: (sensors) {
        final powers =
            sensors.where((s) => s.type == SensorTypes.power).toList();
        if (powers.isEmpty) {
          return const EmptyState(message: 'No power sensors', icon: Icons.bolt);
        }
        final selectedId = _selectedId ??= powers.first.id;
        final l = snapshot.latest[selectedId];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(readingsProvider);
            await ref.read(realtimeProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (powers.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(labelText: 'Sensor'),
                  items: powers
                      .map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedId = v),
                ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  MetricTile(
                      label: 'Power',
                      value: Fmt.num(l?.powerW, decimals: 0),
                      unit: 'W',
                      icon: Icons.bolt,
                      color: StatusColors.of(l?.status)),
                  MetricTile(
                      label: 'Voltage',
                      value: Fmt.num(l?.voltageV, decimals: 0),
                      unit: 'V',
                      icon: Icons.electrical_services),
                  MetricTile(
                      label: 'Current',
                      value: Fmt.num(l?.currentA),
                      unit: 'A',
                      icon: Icons.power),
                  MetricTile(
                      label: 'Power Factor',
                      value: Fmt.num(l?.powerFactor, decimals: 2),
                      icon: Icons.speed),
                  MetricTile(
                      label: 'Energy',
                      value: Fmt.num(l?.energyKwh, decimals: 1),
                      unit: 'kWh',
                      icon: Icons.battery_charging_full),
                  MetricTile(
                      label: 'Updated',
                      value: Fmt.timeOnly(l?.readingTs),
                      icon: Icons.schedule),
                ],
              ),
              const SizedBox(height: 20),
              Text('Power — last 24 hours',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _PowerTrend(sensorId: selectedId),
            ],
          ),
        );
      },
    );
  }
}

class _PowerTrend extends ConsumerWidget {
  const _PowerTrend({required this.sensorId});
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
        final watts = <FlSpot>[];
        for (final r in rows) {
          final t = DateTime.tryParse(r.readingTs)?.millisecondsSinceEpoch;
          final w = r.valueJson['power_w'];
          if (t != null && w is num) {
            watts.add(FlSpot(t.toDouble(), w.toDouble()));
          }
        }
        return TrendChart(series: [
          TrendSeries(
              label: 'Power W',
              color: StatusColors.warning,
              spots: watts),
        ]);
      },
    );
  }
}
