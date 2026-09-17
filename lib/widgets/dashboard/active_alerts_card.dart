import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/alert.dart';
import '../../shared/widgets/premium_card.dart';

/// Active Alerts Card showing latest critical/warning fleet alerts
class ActiveAlertsCard extends StatelessWidget {
  final List<Alert> alerts;
  final VoidCallback? onViewAllPressed;

  const ActiveAlertsCard({
    super.key,
    required this.alerts,
    this.onViewAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      title: 'Active alerts',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.criticalRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${alerts.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.criticalRed,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onViewAllPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: AppTextStyles.labelMedium,
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.primaryGreen),
              ],
            ),
          ),
        ],
      ),
      child: alerts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No active alerts. All fleet systems operating normally.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 16, color: AppColors.borderGray),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _AlertItemRow(alert: alert);
              },
            ),
    );
  }
}

class _AlertItemRow extends StatelessWidget {
  final Alert alert;

  const _AlertItemRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    IconData iconData;

    switch (alert.severity.toLowerCase()) {
      case 'critical':
        iconBg = AppColors.criticalRed.withValues(alpha: 0.1);
        iconColor = AppColors.criticalRed;
        iconData = Icons.error_outline_rounded;
        break;
      case 'warning':
        iconBg = AppColors.warningAmber.withValues(alpha: 0.1);
        iconColor = AppColors.warningAmber;
        iconData = Icons.warning_amber_rounded;
        break;
      default:
        iconBg = AppColors.infoBlue.withValues(alpha: 0.1);
        iconColor = AppColors.infoBlue;
        iconData = Icons.info_outline_rounded;
    }

    return InkWell(
      onTap: () {
        if (alert.chassisNumber != 'N/A') {
          Navigator.of(context).pushNamed(
            AppRoutes.machineDetail,
            arguments: alert.chassisNumber,
          );
        } else {
          Navigator.of(context).pushNamed(AppRoutes.alerts);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.machineId} · ${alert.chassisNumber}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              alert.relativeTime,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
