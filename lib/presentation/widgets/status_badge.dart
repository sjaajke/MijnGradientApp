import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ConditionStatus status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ConditionStatus.ok => (AppTheme.statusOk, Icons.check_circle_rounded),
      ConditionStatus.warning => (AppTheme.statusWarning, Icons.warning_rounded),
      ConditionStatus.fault => (AppTheme.statusFault, Icons.error_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 4, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
