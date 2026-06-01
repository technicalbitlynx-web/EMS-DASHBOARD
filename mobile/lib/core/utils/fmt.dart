import 'package:intl/intl.dart';

/// Formatting helpers matching the web dashboard's display conventions.
class Fmt {
  const Fmt._();

  static final _dateTime = DateFormat('MMM d, HH:mm:ss');
  static final _dateShort = DateFormat('MMM d, HH:mm');
  static final _timeOnly = DateFormat('HH:mm:ss');

  static DateTime? _parse(dynamic ts) {
    if (ts == null) return null;
    if (ts is DateTime) return ts.toLocal();
    final s = ts.toString();
    return DateTime.tryParse(s)?.toLocal();
  }

  static String ts(dynamic value) {
    final d = _parse(value);
    return d == null ? '—' : _dateTime.format(d);
  }

  static String tsShort(dynamic value) {
    final d = _parse(value);
    return d == null ? '—' : _dateShort.format(d);
  }

  static String timeOnly(dynamic value) {
    final d = _parse(value);
    return d == null ? '—' : _timeOnly.format(d);
  }

  /// Relative "x ago" label, falling back to absolute for old timestamps.
  static String ago(dynamic value) {
    final d = _parse(value);
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return _dateShort.format(d);
  }

  static String num(dynamic value, {int decimals = 1, String unit = ''}) {
    if (value == null) return '—';
    double? n;
    if (value is double) {
      n = value;
    } else if (value is int) {
      n = value.toDouble();
    } else {
      n = double.tryParse(value.toString());
    }
    if (n == null) return value.toString();
    final s = n.toStringAsFixed(decimals);
    return unit.isEmpty ? s : '$s$unit';
  }
}
