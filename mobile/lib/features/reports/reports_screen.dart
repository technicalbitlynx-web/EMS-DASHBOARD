import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/utils/fmt.dart';
import 'pdf_builder.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  String? _busy;

  Future<void> _pickFrom() async {
    final d = await _pickDate(_from);
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await _pickDate(_to);
    if (d != null) setState(() => _to = d);
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<void> _shareBytes(
      List<int> bytes, String filename, String mime) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        text: 'EMS report',
      ),
    );
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(reportRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Date range', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('From: ${Fmt.tsShort(_from)}'),
                onPressed: _pickFrom,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('To: ${Fmt.tsShort(_to)}'),
                onPressed: _pickTo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ExportTile(
          title: 'Readings CSV',
          subtitle: 'All sensor readings in range',
          icon: Icons.table_chart_outlined,
          busy: _busy == 'csv',
          onTap: () => _run('csv', () async {
            final bytes =
                await repo.readingsCsv(from: _from, to: _to);
            await _shareBytes(bytes, 'ems_readings.csv', 'text/csv');
          }),
        ),
        _ExportTile(
          title: 'Alerts CSV',
          subtitle: 'Alert history in range',
          icon: Icons.warning_amber_outlined,
          busy: _busy == 'alerts',
          onTap: () => _run('alerts', () async {
            final bytes = await repo.alertsCsv(from: _from, to: _to);
            await _shareBytes(bytes, 'ems_alerts.csv', 'text/csv');
          }),
        ),
        _ExportTile(
          title: 'Summary PDF',
          subtitle: 'Generated on device',
          icon: Icons.picture_as_pdf_outlined,
          busy: _busy == 'pdf',
          onTap: () => _run('pdf', () async {
            final report = await repo.summary(from: _from, to: _to);
            final Uint8List bytes = await buildSummaryPdf(report);
            await Printing.sharePdf(
                bytes: bytes, filename: 'ems_summary.pdf');
          }),
        ),
      ],
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.busy,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: busy
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share),
        onTap: busy ? null : onTap,
      ),
    );
  }
}
