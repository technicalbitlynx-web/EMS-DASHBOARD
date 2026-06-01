import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/utils/fmt.dart';
import '../../data/realtime/realtime_controller.dart';
import '../auth/session.dart';
import '../access/access_screen.dart';
import '../admin/admin_screen.dart';
import '../air_quality/air_quality_screen.dart';
import '../alerts/alerts_screen.dart';
import '../dehumidifier/dehumidifier_screen.dart';
import '../environment/environment_screen.dart';
import '../overview/overview_screen.dart';
import '../power/power_screen.dart';
import '../reports/reports_screen.dart';

class _TabDef {
  const _TabDef(this.key, this.label, this.icon, this.body);
  final String key;
  final String label;
  final IconData icon;
  final Widget body;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab, this.focusAlertId});

  final String? initialTab;
  final int? focusAlertId;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  late List<_TabDef> _tabs;

  List<_TabDef> _buildTabs(bool isAdmin) => [
        _TabDef('overview', 'Overview', Icons.dashboard_outlined,
            const OverviewScreen()),
        _TabDef('environment', 'Environment', Icons.thermostat_outlined,
            const EnvironmentScreen()),
        _TabDef('power', 'Power', Icons.bolt_outlined, const PowerScreen()),
        _TabDef('access', 'Access', Icons.meeting_room_outlined,
            const AccessScreen()),
        _TabDef('air_quality', 'Air Quality', Icons.air_outlined,
            const AirQualityScreen()),
        _TabDef('dehumidifier', 'Dehumidifier', Icons.water_drop_outlined,
            const DehumidifierScreen()),
        _TabDef('alerts', 'Alerts', Icons.notifications_outlined,
            AlertsScreen(focusAlertId: widget.focusAlertId)),
        _TabDef('reports', 'Reports', Icons.assessment_outlined,
            const ReportsScreen()),
        if (isAdmin)
          _TabDef('admin', 'Admin', Icons.admin_panel_settings_outlined,
              const AdminScreen()),
      ];

  void _ensureController(bool isAdmin) {
    _tabs = _buildTabs(isAdmin);
    if (_controller == null || _controller!.length != _tabs.length) {
      final initialIndex = widget.initialTab == null
          ? 0
          : _tabs.indexWhere((t) => t.key == widget.initialTab);
      _controller?.dispose();
      _controller = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final isAdmin = user?.isAdmin ?? false;
    _ensureController(isAdmin);

    final snapshot = ref.watch(realtimeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EMS Monitor', style: TextStyle(fontSize: 17)),
            Text(
              snapshot.updatedAt == null
                  ? 'Connecting…'
                  : 'Updated ${Fmt.timeOnly(snapshot.updatedAt)}'
                      '${snapshot.error != null ? ' · offline' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: snapshot.error != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (snapshot.criticalCount + snapshot.warningCount > 0)
            _AlertCountBadge(
              count: snapshot.criticalCount + snapshot.warningCount,
              critical: snapshot.criticalCount > 0,
              onTap: () {
                final i = _tabs.indexWhere((t) => t.key == 'alerts');
                if (i >= 0) _controller!.animateTo(i);
              },
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(realtimeProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') ref.read(sessionProvider.notifier).logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              PopupMenuItem(
                enabled: false,
                child: Text('Role: ${user?.role ?? '—'}'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.icon, size: 20), text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: _tabs.map((t) => t.body).toList(),
      ),
    );
  }
}

class _AlertCountBadge extends StatelessWidget {
  const _AlertCountBadge({
    required this.count,
    required this.critical,
    required this.onTap,
  });
  final int count;
  final bool critical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = critical
        ? Theme.of(context).colorScheme.error
        : Colors.amber.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
