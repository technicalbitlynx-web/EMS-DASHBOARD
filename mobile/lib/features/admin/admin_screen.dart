import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/user.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import 'sensor_editor.dart';
import 'user_editor.dart';

enum _AdminView { users, sensors, maintenance }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  _AdminView _view = _AdminView.users;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_AdminView>(
            segments: const [
              ButtonSegment(value: _AdminView.users, label: Text('Users')),
              ButtonSegment(value: _AdminView.sensors, label: Text('Sensors')),
              ButtonSegment(
                  value: _AdminView.maintenance, label: Text('Maint.')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (_view) {
      case _AdminView.users:
        return const _UsersTab();
      case _AdminView.sensors:
        return const _SensorsTab();
      case _AdminView.maintenance:
        return const _MaintenanceTab();
    }
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usersProvider);
    return Stack(
      children: [
        AsyncValueView<List<User>>(
          value: async,
          onRetry: () => ref.invalidate(usersProvider),
          data: (users) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(usersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u.role[0].toUpperCase())),
                    title: Text(u.displayName),
                    subtitle: Text('${u.email} · ${u.role}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          showUserEditor(context, ref, user: u);
                        } else if (v == 'delete') {
                          _delete(context, ref, u);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => showUserEditor(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('User'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(u.email),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteUser(u.email);
      ref.invalidate(usersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _SensorsTab extends ConsumerWidget {
  const _SensorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sensorsProvider);
    return Stack(
      children: [
        AsyncValueView<List<Sensor>>(
          value: async,
          onRetry: () => ref.invalidate(sensorsProvider),
          data: (sensors) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(sensorsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              itemCount: sensors.length,
              itemBuilder: (_, i) {
                final s = sensors[i];
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                        '${s.id} · ${s.type} · ${s.location ?? s.zone ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _delete(context, ref, s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => showSensorEditor(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Sensor'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Sensor s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sensor?'),
        content: Text('${s.name} (${s.id})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sensorRepositoryProvider).remove(s.id);
      ref.invalidate(sensorsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _MaintenanceTab extends ConsumerStatefulWidget {
  const _MaintenanceTab();

  @override
  ConsumerState<_MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<_MaintenanceTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Apply data retention'),
            subtitle:
                const Text('Delete readings older than the retention period'),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _applyRetention,
          ),
        ),
      ],
    );
  }

  Future<void> _applyRetention() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply retention?'),
        content: const Text(
            'This permanently deletes readings older than the configured retention period.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).applyRetention();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retention applied')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
