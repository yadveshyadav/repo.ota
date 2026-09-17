import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine.dart';

/// Reusable Machine Data Table Widget with status badges and actions
class MachineTableWidget extends StatelessWidget {
  final List<Machine> machines;
  final ValueChanged<Machine>? onMachineSelected;

  const MachineTableWidget({
    super.key,
    required this.machines,
    this.onMachineSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (machines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48, color: AppColors.mutedTextGray),
              SizedBox(height: 12),
              Text(
                'No matching machines found',
                style: AppTextStyles.headingSmall,
              ),
              SizedBox(height: 4),
              Text(
                'Try adjusting your search or filter parameters.',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(AppColors.softGray),
            headingRowHeight: 48,
            dataRowMaxHeight: 56,
            horizontalMargin: 16,
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Text('Machine ID', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Machine Name', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Type', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Location', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Current Step', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Status', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Last Active', style: AppTextStyles.titleMedium),
              ),
              DataColumn(
                label: Text('Actions', style: AppTextStyles.titleMedium),
              ),
            ],
            rows: machines.map((machine) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      machine.chassisNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      machine.machineName,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Text(
                        machine.machineType,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 4),
                        Text(machine.location, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(machine.currentStep, style: AppTextStyles.bodyMedium),
                  ),
                  DataCell(
                    _MachineStatusBadge(status: machine.status),
                  ),
                  DataCell(
                    Text(machine.lastActive, style: AppTextStyles.caption),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primaryGreen),
                      onPressed: () {
                        if (onMachineSelected != null) {
                          onMachineSelected!(machine);
                        }
                      },
                      tooltip: 'View Telemetry Details',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MachineStatusBadge extends StatelessWidget {
  final String status;

  const _MachineStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    if (status.toLowerCase().contains('online') ||
        status.toLowerCase().contains('working')) {
      bg = AppColors.successGreen.withValues(alpha: 0.12);
      text = AppColors.successGreen;
    } else if (status.toLowerCase().contains('idle')) {
      bg = AppColors.warningAmber.withValues(alpha: 0.12);
      text = AppColors.warningAmber;
    } else {
      bg = AppColors.mutedTextGray.withValues(alpha: 0.12);
      text = AppColors.mutedTextGray;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
