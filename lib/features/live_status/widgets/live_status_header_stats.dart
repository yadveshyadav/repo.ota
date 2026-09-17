import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';

/// Top header section displaying screen title, subtitle, and live fleet counts.
class LiveStatusHeaderStats extends StatelessWidget {
  final int totalMachines;
  final int liveMachines;
  final int offlineMachines;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final ValueChanged<String>? onFilterSelected;

  const LiveStatusHeaderStats({
    super.key,
    required this.totalMachines,
    required this.liveMachines,
    required this.offlineMachines,
    this.onRefresh,
    this.isRefreshing = false,
    this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Live Status',
                    style: AppTextStyles.displayMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          )
                        : const Icon(
                            Icons.sync_rounded,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                    onPressed: onRefresh,
                    tooltip: 'Sync Fleet Data',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'All machines at a glance · heading arrows + vitals',
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final badgesWidget = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatBadge(
              label: '$totalMachines machines',
              color: AppColors.deepNavy,
              bgColor: AppColors.softGray,
              borderColor: AppColors.borderGray,
              onTap: () => onFilterSelected?.call('All'),
            ),
            _StatBadge(
              label: '$liveMachines live',
              color: AppColors.successGreen,
              bgColor: AppColors.lightGreenBg,
              borderColor: AppColors.successGreen.withValues(alpha: 0.3),
              isDot: true,
              onTap: () => onFilterSelected?.call('Online'),
            ),
            _StatBadge(
              label: '$offlineMachines offline',
              color: AppColors.criticalRed,
              bgColor: AppColors.criticalRed.withValues(alpha: 0.08),
              borderColor: AppColors.criticalRed.withValues(alpha: 0.3),
              onTap: () => onFilterSelected?.call('Offline'),
            ),
          ],
        );

        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleWidget,
              const SizedBox(height: 10),
              badgesWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 12),
            badgesWidget,
          ],
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool isDot;
  final VoidCallback? onTap;

  const _StatBadge({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.isDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
