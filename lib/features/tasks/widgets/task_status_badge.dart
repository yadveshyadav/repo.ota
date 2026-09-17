import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Centralized Status Configuration for Task Management
class TaskStatusConfig {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final IconData icon;

  const TaskStatusConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
  });

  static TaskStatusConfig getConfig(String status) {
    final normalized = status.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'CREATED':
        return const TaskStatusConfig(
          label: 'CREATED',
          backgroundColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF4B5563),
          borderColor: Color(0xFFE5E7EB),
          icon: Icons.fiber_manual_record_rounded,
        );
      case 'PLANNING':
        return const TaskStatusConfig(
          label: 'PLANNING',
          backgroundColor: Color(0xFFE0F2FE),
          textColor: Color(0xFF0369A1),
          borderColor: Color(0xFFBAE6FD),
          icon: Icons.alt_route_rounded,
        );
      case 'IN_PROGRESS':
        return const TaskStatusConfig(
          label: 'IN PROGRESS',
          backgroundColor: Color(0xFFDBEAFE),
          textColor: Color(0xFF1D4ED8),
          borderColor: Color(0xFFBFDBFE),
          icon: Icons.cached_rounded,
        );
      case 'PENDING':
        return const TaskStatusConfig(
          label: 'PENDING',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          borderColor: Color(0xFFFDE68A),
          icon: Icons.hourglass_empty_rounded,
        );
      case 'APPROVAL_PENDING':
      case 'UNDER_REVIEW':
        return const TaskStatusConfig(
          label: 'APPROVAL PENDING',
          backgroundColor: Color(0xFFFFEDD5),
          textColor: Color(0xFFC2410C),
          borderColor: Color(0xFFFED7AA),
          icon: Icons.verified_user_outlined,
        );
      case 'COMPLETED':
      case 'APPROVED':
        return const TaskStatusConfig(
          label: 'COMPLETED',
          backgroundColor: Color(0xFFD1FAE5),
          textColor: Color(0xFF047857),
          borderColor: Color(0xFFA7F3D0),
          icon: Icons.check_circle_rounded,
        );
      case 'CANCELLED':
        return const TaskStatusConfig(
          label: 'CANCELLED',
          backgroundColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF6B7280),
          borderColor: Color(0xFFE5E7EB),
          icon: Icons.cancel_outlined,
        );
      case 'REJECTED':
        return const TaskStatusConfig(
          label: 'REJECTED',
          backgroundColor: Color(0xFFFEE2E2),
          textColor: Color(0xFFB91C1C),
          borderColor: Color(0xFFFECACA),
          icon: Icons.error_outline_rounded,
        );
      default:
        return TaskStatusConfig(
          label: status.toUpperCase(),
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: AppColors.deepNavy,
          borderColor: const Color(0xFFE5E7EB),
          icon: Icons.circle_outlined,
        );
    }
  }
}

/// Reusable Task Status Badge Component with Centralized Config
class TaskStatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const TaskStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = TaskStatusConfig.getConfig(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: isCompact ? 10 : 12,
            color: config.textColor,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: config.textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
