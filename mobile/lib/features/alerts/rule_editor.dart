import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/alert.dart';
import '../../shared/providers/data_providers.dart';

/// Opens a modal to create or edit an alert rule.
Future<void> showRuleEditor(
  BuildContext context,
  WidgetRef ref, {
  AlertRule? rule,
}) async {
  final sensors = await ref.read(sensorRepositoryProvider).list();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _RuleEditorDialog(
      ref: ref,
      rule: rule,
      sensorChoices: {for (final s in sensors) s.id: s.name},
    ),
  );
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({
    required this.ref,
    required this.rule,
    required this.sensorChoices,
  });
  final WidgetRef ref;
  final AlertRule? rule;
  final Map<String, String> sensorChoices;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _sensorId = widget.rule?.sensorId;
  late final _metric =
      TextEditingController(text: widget.rule?.metric ?? 'temp_c');
  late String _operator = widget.rule?.operator ?? '>';
  late final _threshold = TextEditingController(
      text: widget.rule?.threshold.toString() ?? '');
  late String _severity = widget.rule?.severity ?? 'warning';
  late final _cooldown = TextEditingController(
      text: (widget.rule?.cooldownMinutes ?? 5).toString());
  bool _busy = false;

  bool get _isEdit => widget.rule != null;

  @override
  void dispose() {
    _metric.dispose();
    _threshold.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sensorId == null) return;
    setState(() => _busy = true);
    final body = {
      'sensor_id': _sensorId,
      'metric': _metric.text.trim(),
      'operator': _operator,
      'threshold': double.tryParse(_threshold.text.trim()) ?? 0,
      'severity': _severity,
      'cooldown_minutes': int.tryParse(_cooldown.text.trim()) ?? 5,
    };
    try {
      final repo = widget.ref.read(alertRepositoryProvider);
      if (_isEdit) {
        await repo.updateRule(widget.rule!.id, body);
      } else {
        await repo.createRule(body);
      }
      widget.ref.invalidate(alertRulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit rule' : 'New alert rule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _sensorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sensor'),
                items: widget.sensorChoices.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                validator: (v) => v == null ? 'Required' : null,
                onChanged: _isEdit ? null : (v) => setState(() => _sensorId = v),
              ),
              TextFormField(
                controller: _metric,
                decoration: const InputDecoration(
                    labelText: 'Metric (e.g. temp_c, power_w)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _operator,
                      decoration:
                          const InputDecoration(labelText: 'Operator'),
                      items: const ['>', '<', '>=', '<=', '=', '!=']
                          .map((o) =>
                              DropdownMenuItem(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (v) => setState(() => _operator = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _threshold,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration:
                          const InputDecoration(labelText: 'Threshold'),
                      validator: (v) =>
                          double.tryParse(v?.trim() ?? '') == null
                              ? 'Number'
                              : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _severity,
                      decoration:
                          const InputDecoration(labelText: 'Severity'),
                      items: const ['warning', 'critical']
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _severity = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cooldown,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cooldown (m)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
