import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/sensor.dart';
import '../../shared/providers/data_providers.dart';

Future<void> showSensorEditor(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SensorEditorDialog(ref: ref),
  );
}

class _SensorEditorDialog extends StatefulWidget {
  const _SensorEditorDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_SensorEditorDialog> createState() => _SensorEditorDialogState();
}

class _SensorEditorDialogState extends State<_SensorEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _zone = TextEditingController();
  final _mqtt = TextEditingController();
  String _type = SensorTypes.temperature;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _location.dispose();
    _zone.dispose();
    _mqtt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.ref.read(sensorRepositoryProvider).create({
        'id': _id.text.trim(),
        'type': _type,
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'zone': _zone.text.trim(),
        'mqtt_topic': _mqtt.text.trim().isEmpty
            ? 'ems/raw/$_type/${_id.text.trim()}'
            : _mqtt.text.trim(),
      });
      widget.ref.invalidate(sensorsProvider);
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
      title: const Text('New sensor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _id,
                decoration:
                    const InputDecoration(labelText: 'ID (e.g. temp_zone2)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: SensorTypes.all
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextFormField(
                controller: _zone,
                decoration: const InputDecoration(labelText: 'Zone'),
              ),
              TextFormField(
                controller: _mqtt,
                decoration: const InputDecoration(
                    labelText: 'MQTT topic (optional)'),
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
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
