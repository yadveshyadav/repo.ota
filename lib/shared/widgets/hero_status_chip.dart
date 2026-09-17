import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Unified, high-contrast Status Chip component for status indicators across all modules
class HeroStatusChip extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const HeroStatusChip({
    super.key,
    required this.status,
    this.fontSize = 10,
    this.padding,
  });

  Color get _color {
    final s = status.toUpperCase().trim();
    if (s.contains('CRITICAL') || s.contains('REJECT') || s.contains('CANCEL') || s.contains('OFFLINE') || s.contains('FAIL')) {
      return AppColors.criticalRed;
    }
    if (s.contains('WARN') || s.contains('MAINTENANCE') || s.contains('PENDING') || s.contains('DRAFT') || s.contains('IDLE')) {
      return AppColors.warningAmber;
    }
    if (s.contains('APPROV') || s.contains('COMPLETE') || s.contains('RUNNING') || s.contains('ONLINE') || s.contains('ACTIVE') || s.contains('PAID') || s.contains('SUCCESS')) {
      return AppColors.successGreen;
    }
    if (s.contains('PROGRESS') || s.contains('SUBMIT') || s.contains('MOVING')) {
      return AppColors.movingBlue;
    }
    return AppColors.mutedTextGray;
  }

  IconData get _icon {
    final s = status.toUpperCase().trim();
    if (s.contains('CRITICAL') || s.contains('FAIL')) return Icons.error_outline_rounded;
    if (s.contains('REJECT') || s.contains('CANCEL')) return Icons.cancel_outlined;
    if (s.contains('WARN') || s.contains('MAINTENANCE')) return Icons.warning_amber_rounded;
    if (s.contains('APPROV') || s.contains('COMPLETE') || s.contains('SUCCESS')) return Icons.check_circle_outline_rounded;
    if (s.contains('PAID')) return Icons.payments_outlined;
    if (s.contains('RUNNING') || s.contains('ONLINE') || s.contains('ACTIVE')) return Icons.sensors_rounded;
    if (s.contains('PROGRESS') || s.contains('SUBMIT') || s.contains('MOVING')) return Icons.send_rounded;
    if (s.contains('DRAFT')) return Icons.edit_note_rounded;
    return Icons.circle;
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _color;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: fontSize + 2, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: chipColor,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
