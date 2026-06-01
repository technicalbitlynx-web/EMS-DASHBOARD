import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/status_badge.dart';

class AirQualityScreen extends ConsumerWidget {
  const AirQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final snapshot = ref.watch(realtimeProvider);

    return AsyncValueView<List<Sensor>>(
      value: sensorsAsync,
      onRetry: () => ref.invalidate(sensorsProvider),
      data: (sensors) {
        final smoke =
            sensors.where((s) => s.type == SensorTypes.smoke).toList();
        return RefreshIndicator(
          onRefresh: () => ref.read(realtimeProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (smoke.isEmpty)
                const EmptyState(
                    message: 'No air-quality sensors', icon: Icons.air)
              else
                ...smoke.map((s) {
                  final l = snapshot.latest[s.id];
                  final level = l?.smokeLevelPct ?? 0;
                  final alarm = l?.smokeAlarm ?? false;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: alarm
                                      ? StatusColors.critical
                                      : StatusColors.of(l?.status)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              StatusBadge(
                                  status: alarm
                                      ? 'critical'
                                      : (l?.status ?? 'unknown')),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(Fmt.num(level, unit: '%'),
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              const Text('smoke level'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (level / 100).clamp(0, 1),
                              minHeight: 10,
                              color: alarm
                                  ? StatusColors.critical
                                  : StatusColors.warning,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${s.location ?? ''} · ${Fmt.ago(l?.readingTs)}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12),
                          ),
                          if (alarm) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: StatusColors.critical
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('⚠ SMOKE ALARM ACTIVE',
                                  style: TextStyle(
                                      color: StatusColors.critical,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
