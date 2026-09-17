import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/engine_hours.dart';
import '../../shared/widgets/premium_card.dart';

/// Engine Hours Card showing total operating time breakdown & animated progress bars
class EngineHoursCard extends StatelessWidget {
  final EngineHours engineHours;
  final ValueChanged<DateTime>? onDateChanged;

  const EngineHoursCard({
    super.key,
    required this.engineHours,
    this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd / MM / yyyy');

    return PremiumCard(
      title: 'Engine Hours',
      trailing: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: engineHours.date,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && onDateChanged != null) {
            onDateChanged!(picked);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.mutedTextGray),
              const SizedBox(width: 6),
              Text(
                dateFormat.format(engineHours.date),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  engineHours.formatDuration(engineHours.total),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                'Total engine hours',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Percentage Metrics
          Row(
            children: [
              Expanded(
                child: _MetricBadge(
                  label: 'Utilization',
                  value: '${engineHours.workingPercentage.toStringAsFixed(1)}%',
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBadge(
                  label: 'Idle',
                  value: '${engineHours.idlePercentage.toStringAsFixed(1)}%',
                  color: AppColors.idleOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Breakdown Progress Bars
          _ProgressBarRow(
            label: 'Working',
            valueText: engineHours.formatDuration(engineHours.working),
            percentage: engineHours.workingPercentage / 100,
            barColor: AppColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          _ProgressBarRow(
            label: 'Moving',
            valueText: engineHours.formatDuration(engineHours.moving),
            percentage: 0.15,
            barColor: AppColors.movingBlue,
          ),
          const SizedBox(height: 12),
          _ProgressBarRow(
            label: 'Idle',
            valueText: engineHours.formatDuration(engineHours.idle),
            percentage: engineHours.idlePercentage / 100,
            barColor: AppColors.idleOrange,
          ),
          const SizedBox(height: 12),
          _ProgressBarRow(
            label: 'Avg per machine',
            valueText: engineHours.formatDuration(engineHours.averagePerMachine),
            percentage: 0.45,
            barColor: AppColors.infoBlue,
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double percentage;
  final Color barColor;

  const _ProgressBarRow({
    required this.label,
    required this.valueText,
    required this.percentage,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text(
              valueText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: AppColors.softGray,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
