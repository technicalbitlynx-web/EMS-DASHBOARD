import 'package:flutter/material.dart';

import '../../core/theme/status_colors.dart';

/// Small coloured pill showing a status or severity label.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.severity = false});

  final String status;
  final bool severity;

  @override
  Widget build(BuildContext context) {
    final color =
        severity ? StatusColors.severity(status) : StatusColors.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            StatusColors.label(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
