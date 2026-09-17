import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/utilization.dart';
import '../../shared/widgets/premium_card.dart';

/// Utilization Donut Chart Card showing Working, Moving, Idle breakdown
class UtilizationCard extends StatelessWidget {
  final Utilization utilization;

  const UtilizationCard({
    super.key,
    required this.utilization,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      title: 'Utilization',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Text(
          utilization.periodLabel,
          style: AppTextStyles.caption,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryCompact = constraints.maxWidth < 340;
          final chartSize = isVeryCompact ? 110.0 : 125.0;
          final centerSpace = isVeryCompact ? 35.0 : 40.0;

          return Row(
            children: [
              // Donut Chart with Center Focal Text
              SizedBox(
                width: chartSize,
                height: chartSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: centerSpace,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: AppColors.primaryGreen,
                            value: utilization.working,
                            showTitle: false,
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: AppColors.movingBlue,
                            value: utilization.moving,
                            showTitle: false,
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: AppColors.idleOrange,
                            value: utilization.idle,
                            showTitle: false,
                            radius: 16,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${utilization.working.toInt()}%',
                          style: TextStyle(
                            fontSize: isVeryCompact ? 18 : 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          utilization.periodLabel,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: isVeryCompact ? 12 : 20),
              // Breakdown Legend Items
              Expanded(
                child: Column(
                  children: [
                    _UtilizationLegendItem(
                      label: 'Working',
                      percentage: utilization.working,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 10),
                    _UtilizationLegendItem(
                      label: 'Moving',
                      percentage: utilization.moving,
                      color: AppColors.movingBlue,
                    ),
                    const SizedBox(height: 10),
                    _UtilizationLegendItem(
                      label: 'Idle',
                      percentage: utilization.idle,
                      color: AppColors.idleOrange,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UtilizationLegendItem extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _UtilizationLegendItem({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
