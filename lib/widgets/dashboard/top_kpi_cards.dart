import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';

/// Top 4 KPI Metrics Row displaying interactive real-time cards
class TopKpiCardsRow extends StatelessWidget {
  final Map<String, dynamic>? quickStats;
  final ValueChanged<String>? onTileTap;

  const TopKpiCardsRow({
    super.key,
    this.quickStats,
    this.onTileTap,
  });

  @override
  Widget build(BuildContext context) {
    final shotCount = quickStats?['shots_in_progress']?.toString() ?? '0';
    final taskCount = quickStats?['tasks_pending']?.toString() ?? '0';
    final alertCount = quickStats?['alerts_count']?.toString() ?? '0';
    final attendancePct = quickStats?['attendance_pct'] != null
        ? '${quickStats!['attendance_pct']}%'
        : '0%';

    void handleTap(String route) {
      if (onTileTap != null) {
        onTileTap!(route);
      } else {
        Navigator.of(context).pushNamed(route);
      }
    }

    final tiles = [
      _KpiTile(
        icon: Icons.article_outlined,
        iconBgColor: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        value: shotCount,
        label: 'Shot in Progress',
        onTap: () => handleTap(AppRoutes.tasks),
      ),
      _KpiTile(
        icon: Icons.precision_manufacturing_outlined,
        iconBgColor: const Color(0xFFD1FAE5),
        iconColor: const Color(0xFF059669),
        value: taskCount,
        label: 'Task Pending',
        onTap: () => handleTap(AppRoutes.tasks),
      ),
      _KpiTile(
        icon: Icons.notifications_none_rounded,
        iconBgColor: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        value: alertCount,
        label: 'Alert',
        onTap: () => handleTap(AppRoutes.alerts),
      ),
      _KpiTile(
        icon: Icons.people_outline_rounded,
        iconBgColor: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        value: attendancePct,
        label: 'Attendance',
        onTap: () => handleTap(AppRoutes.attendance),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 6),
          Expanded(child: tiles[1]),
          const SizedBox(width: 6),
          Expanded(child: tiles[2]),
          const SizedBox(width: 6),
          Expanded(child: tiles[3]),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedTextGray,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
