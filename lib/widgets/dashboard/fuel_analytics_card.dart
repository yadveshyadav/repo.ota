import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/fuel_analytics.dart';
import '../../shared/widgets/premium_card.dart';

/// Fuel Analytics Card showing Fuel Consumption & Refills with sparklines
class FuelAnalyticsCard extends StatelessWidget {
  final FuelAnalytics fuelAnalytics;

  const FuelAnalyticsCard({
    super.key,
    required this.fuelAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.0');

    return PremiumCard(
      title: 'Fuel Analytics',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Text(
          fuelAnalytics.periodLabel,
          style: AppTextStyles.caption,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;

          final consumptionWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_gas_station_outlined,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fuel Consumption',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${numberFormat.format(fuelAnalytics.fuelConsumed)} L',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${fuelAnalytics.periodLabel} · by machine',
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 45,
                child: _SparklineBarChart(
                  dataPoints: fuelAnalytics.consumptionDataPoints,
                  barColor: AppColors.primaryGreen,
                ),
              ),
            ],
          );

          final refillWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.opacity_rounded,
                    size: 16,
                    color: AppColors.infoBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fuel Refills',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${numberFormat.format(fuelAnalytics.fuelRefilled)} L',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${fuelAnalytics.refillCount} refills · ${fuelAnalytics.periodLabel}',
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 45,
                child: _SparklineBarChart(
                  dataPoints: fuelAnalytics.refillDataPoints,
                  barColor: AppColors.infoBlue,
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              children: [
                consumptionWidget,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.borderGray, height: 1),
                ),
                refillWidget,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: consumptionWidget),
              Container(
                width: 1,
                height: 110,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.borderGray,
              ),
              Expanded(child: refillWidget),
            ],
          );
        },
      ),
    );
  }
}

class _SparklineBarChart extends StatelessWidget {
  final List<double> dataPoints;
  final Color barColor;

  const _SparklineBarChart({
    required this.dataPoints,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} L',
                const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        alignment: BarChartAlignment.spaceAround,
        barGroups: dataPoints.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: barColor,
                width: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
