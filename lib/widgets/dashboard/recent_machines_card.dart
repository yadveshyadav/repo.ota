import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine.dart';
import '../machines/machine_card_widget.dart';

/// Recent Machines section on Dashboard showing the latest API machines
class RecentMachinesCard extends StatelessWidget {
  final List<Machine> machines;
  final VoidCallback? onViewAllPressed;
  final ValueChanged<Machine>? onMachineSelected;

  const RecentMachinesCard({
    super.key,
    required this.machines,
    this.onViewAllPressed,
    this.onMachineSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (machines.isEmpty) return const SizedBox.shrink();

    final recentList = machines.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Fleet Activity',
              style: AppTextStyles.headingMedium,
            ),
            TextButton.icon(
              onPressed: onViewAllPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkHeroGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final machine = recentList[index];
            return MachineCardWidget(
              machine: machine,
              onTap: () => onMachineSelected?.call(machine),
            );
          },
        ),
      ],
    );
  }
}
