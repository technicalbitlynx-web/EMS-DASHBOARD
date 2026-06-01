import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/status_colors.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../../domain/models/alert.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/status_badge.dart';
import '../auth/session.dart';
import 'rule_editor.dart';

enum _View { active, history, rules }

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key, this.focusAlertId});
  final int? focusAlertId;

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _View _view = _View.active;
  String? _severityFilter;

  @override
  Widget build(BuildContext context) {
    final canWrite =
        ref.watch(sessionProvider.select((s) => s.user?.canWrite ?? false));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_View>(
            segments: const [
              ButtonSegment(value: _View.active, label: Text('Active')),
              ButtonSegment(value: _View.history, label: Text('History')),
              ButtonSegment(value: _View.rules, label: Text('Rules')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        Expanded(child: _buildBody(canWrite)),
      ],
    );
  }

  Widget _buildBody(bool canWrite) {
    switch (_view) {
      case _View.active:
        return _ActiveList(canWrite: canWrite, focusId: widget.focusAlertId);
      case _View.history:
        return _HistoryList(
          severity: _severityFilter,
          onFilter: (s) => setState(() => _severityFilter = s),
        );
      case _View.rules:
        return _RulesList(canWrite: canWrite);
    }
  }
}

class _ActiveList extends ConsumerWidget {
  const _ActiveList({required this.canWrite, this.focusId});
  final bool canWrite;
  final int? focusId;

  Future<void> _acknowledge(BuildContext context, WidgetRef ref, Alert a) async {
    try {
      await ref.read(alertRepositoryProvider).acknowledge(a.id);
      await ref.read(realtimeProvider.notifier).refresh();
      ref.invalidate(alertHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert acknowledged')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(realtimeProvider).activeAlerts;
    if (alerts.isEmpty) {
      return const EmptyState(
          message: 'No active alerts', icon: Icons.check_circle_outline);
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(realtimeProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: alerts.length,
        itemBuilder: (_, i) {
          final a = alerts[i];
          final highlight = focusId != null && a.id == focusId;
          return Card(
            color: highlight
                ? StatusColors.severity(a.severity).withValues(alpha: 0.08)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.sensorName ?? a.sensorId,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      StatusBadge(status: a.severity, severity: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(a.message),
                  const SizedBox(height: 6),
                  Text(Fmt.ts(a.triggeredAt),
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (canWrite) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Acknowledge'),
                        onPressed: () => _acknowledge(context, ref, a),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.severity, required this.onFilter});
  final String? severity;
  final ValueChanged<String?> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(alertHistoryProvider(AlertHistoryQuery(severity: severity)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Severity:'),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: severity,
                hint: const Text('All'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'warning', child: Text('Warning')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: onFilter,
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Alert>>(
            value: async,
            onRetry: () => ref.invalidate(alertHistoryProvider),
            data: (rows) {
              if (rows.isEmpty) {
                return const EmptyState(message: 'No alert history');
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(alertHistoryProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final a = rows[i];
                    return ListTile(
                      leading: Icon(Icons.circle,
                          size: 12,
                          color: StatusColors.severity(a.severity)),
                      title: Text(a.message,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${a.sensorName ?? a.sensorId} · ${Fmt.ts(a.triggeredAt)}'
                          '${a.isResolved ? ' · resolved' : ''}'),
                      trailing: a.isAcknowledged
                          ? const Icon(Icons.done_all,
                              size: 18, color: StatusColors.normal)
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RulesList extends ConsumerWidget {
  const _RulesList({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertRulesProvider);
    final isAdmin =
        ref.watch(sessionProvider.select((s) => s.user?.isAdmin ?? false));

    return Stack(
      children: [
        AsyncValueView<List<AlertRule>>(
          value: async,
          onRetry: () => ref.invalidate(alertRulesProvider),
          data: (rules) {
            if (rules.isEmpty) {
              return const EmptyState(message: 'No alert rules defined');
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(alertRulesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: rules.length,
                itemBuilder: (_, i) {
                  final r = rules[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                          '${r.sensorName ?? r.sensorId}: ${r.metric} ${r.operator} ${r.threshold}'),
                      subtitle: Text(
                          '${r.severity} · cooldown ${r.cooldownMinutes ?? 0}m'),
                      leading: Switch(
                        value: r.enabled,
                        onChanged: canWrite
                            ? (v) => _toggle(context, ref, r, v)
                            : null,
                      ),
                      trailing: canWrite
                          ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  showRuleEditor(context, ref, rule: r);
                                } else if (v == 'delete') {
                                  _delete(context, ref, r);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                if (isAdmin)
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (canWrite)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => showRuleEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Rule'),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, AlertRule r, bool v) async {
    try {
      await ref
          .read(alertRepositoryProvider)
          .updateRule(r.id, {'enabled': v});
      ref.invalidate(alertRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AlertRule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('${r.metric} ${r.operator} ${r.threshold}'),
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
      await ref.read(alertRepositoryProvider).deleteRule(r.id);
      ref.invalidate(alertRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
