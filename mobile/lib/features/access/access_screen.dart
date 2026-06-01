import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/reading.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';

class AccessScreen extends ConsumerWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final snapshot = ref.watch(realtimeProvider);
    final eventsAsync = ref.watch(
      readingsProvider(
          const ReadingsQuery(sensorType: SensorTypes.door, hours: 168, limit: 50)),
    );

    return AsyncValueView<List<Sensor>>(
      value: sensorsAsync,
      onRetry: () => ref.invalidate(sensorsProvider),
      data: (sensors) {
        final doors =
            sensors.where((s) => s.type == SensorTypes.door).toList();
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(readingsProvider);
            await ref.read(realtimeProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (doors.isEmpty)
                const EmptyState(
                    message: 'No access sensors',
                    icon: Icons.meeting_room_outlined)
              else
                ...doors.map((s) {
                  final l = snapshot.latest[s.id];
                  final open = l?.doorOpen ?? false;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        open ? Icons.lock_open : Icons.lock,
                        color: open
                            ? StatusColors.critical
                            : StatusColors.normal,
                        size: 30,
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                          '${s.location ?? ''} · ${Fmt.ago(l?.readingTs)}'),
                      trailing: Text(
                        open ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: open
                              ? StatusColors.critical
                              : StatusColors.normal,
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text('Recent events',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              AsyncValueView<List<Reading>>(
                value: eventsAsync,
                onRetry: () => ref.invalidate(readingsProvider),
                data: (events) {
                  if (events.isEmpty) {
                    return const EmptyState(message: 'No door events');
                  }
                  return Column(
                    children: events.take(50).map((e) {
                      final open = (e.valueJson['is_open'] == true) ||
                          (e.valueJson['state'] == 'open');
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          open ? Icons.lock_open : Icons.lock,
                          size: 18,
                          color: open
                              ? StatusColors.critical
                              : StatusColors.normal,
                        ),
                        title: Text(e.sensorName ?? e.sensorId),
                        subtitle: Text(Fmt.ts(e.readingTs)),
                        trailing: Text(open ? 'Opened' : 'Closed'),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
