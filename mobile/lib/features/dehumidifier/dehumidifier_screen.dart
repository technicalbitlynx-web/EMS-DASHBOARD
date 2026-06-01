import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';

class DehumidifierScreen extends ConsumerWidget {
  const DehumidifierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final snapshot = ref.watch(realtimeProvider);

    return AsyncValueView<List<Sensor>>(
      value: sensorsAsync,
      onRetry: () => ref.invalidate(sensorsProvider),
      data: (sensors) {
        final units =
            sensors.where((s) => s.type == SensorTypes.dehumidifier).toList();
        return RefreshIndicator(
          onRefresh: () => ref.read(realtimeProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (units.isEmpty)
                const EmptyState(
                    message: 'No dehumidifier units', icon: Icons.water_drop)
              else
                ...units.map((s) {
                  final l = snapshot.latest[s.id];
                  final on = l?.dehumidifierOn ?? false;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (on
                                      ? StatusColors.normal
                                      : StatusColors.unknown)
                                  .withValues(alpha: 0.12),
                              border: Border.all(
                                color: on
                                    ? StatusColors.normal
                                    : StatusColors.unknown,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.water_drop,
                              size: 48,
                              color: on
                                  ? StatusColors.normal
                                  : StatusColors.unknown,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(s.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            on ? 'RUNNING' : 'OFF',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: on
                                  ? StatusColors.normal
                                  : StatusColors.unknown,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.location ?? ''} · ${Fmt.ago(l?.readingTs)}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12),
                          ),
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
