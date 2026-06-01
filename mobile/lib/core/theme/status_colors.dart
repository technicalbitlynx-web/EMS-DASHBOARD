import 'package:flutter/material.dart';

/// Status palette mirroring the web dashboard's normal/warning/critical tokens.
class StatusColors {
  const StatusColors._();

  static const normal = Color(0xFF16A34A); // green-600
  static const warning = Color(0xFFD97706); // amber-600
  static const critical = Color(0xFFDC2626); // red-600
  static const unknown = Color(0xFF64748B); // slate-500

  static Color of(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'normal':
      case 'ok':
        return normal;
      case 'warning':
      case 'warn':
        return warning;
      case 'critical':
      case 'crit':
      case 'alarm':
        return critical;
      default:
        return unknown;
    }
  }

  /// Severity color for alerts (warning|critical).
  static Color severity(String? sev) {
    switch ((sev ?? '').toLowerCase()) {
      case 'critical':
        return critical;
      case 'warning':
        return warning;
      default:
        return unknown;
    }
  }

  static String label(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + s.substring(1);
  }
}
