import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models/user.dart';
import '../../shared/providers/data_providers.dart';

Future<void> showUserEditor(BuildContext context, WidgetRef ref,
    {User? user}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UserEditorDialog(ref: ref, user: user),
  );
}

class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({required this.ref, this.user});
  final WidgetRef ref;
  final User? user;

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.user?.email);
  late final _username = TextEditingController(text: widget.user?.username);
  final _password = TextEditingController();
  late final _fullName = TextEditingController(text: widget.user?.fullName);
  late final _department =
      TextEditingController(text: widget.user?.department ?? 'Operations');
  late final _phone = TextEditingController(text: widget.user?.phone);
  late String _role = widget.user?.role ?? 'viewer';
  bool _busy = false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    _department.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = widget.ref.read(authRepositoryProvider);
      if (_isEdit) {
        await repo.updateUser(widget.user!.email, {
          'full_name': _fullName.text.trim(),
          'role': _role,
          'department': _department.text.trim(),
          'phone': _phone.text.trim(),
        });
      } else {
        await repo.register({
          'email': _email.text.trim(),
          'username': _username.text.trim(),
          'password': _password.text,
          'full_name': _fullName.text.trim(),
          'role': _role,
          'department': _department.text.trim(),
          'phone': _phone.text.trim(),
        });
      }
      widget.ref.invalidate(usersProvider);
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
      title: Text(_isEdit ? 'Edit user' : 'New user'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_isEdit,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Valid email' : null,
              ),
              TextFormField(
                controller: _username,
                enabled: !_isEdit,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              if (!_isEdit)
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Min 4 chars' : null,
                ),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const ['admin', 'operator', 'viewer']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              TextFormField(
                controller: _department,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
