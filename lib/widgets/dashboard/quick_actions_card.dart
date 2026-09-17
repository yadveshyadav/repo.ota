import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/premium_card.dart';

/// Quick Actions widget for high-frequency fleet operator workflows
class QuickActionsCard extends StatelessWidget {
  final ValueChanged<String>? onActionSelected;

  const QuickActionsCard({
    super.key,
    this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.precision_manufacturing_rounded,
                label: 'View Fleet',
                color: AppColors.primaryGreen,
                onTap: () => onActionSelected?.call('Total Machines'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.wifi_tethering_rounded,
                label: 'Live Status',
                color: AppColors.successGreen,
                onTap: () => onActionSelected?.call('Online'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.local_gas_station_rounded,
                label: 'Refuel Log',
                color: AppColors.infoBlue,
                onTap: () => onActionSelected?.call('Refuel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.notifications_active_rounded,
                label: 'Alerts',
                color: AppColors.warningAmber,
                onTap: () => onActionSelected?.call('Alerts'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.deepNavy,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
