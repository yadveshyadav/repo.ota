import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/models/task_model.dart';

/// Lightweight contextual bottom sheet displaying Stakeholder Contact Details
class ContactDetailsBottomSheet extends StatelessWidget {
  final TaskModel task;

  const ContactDetailsBottomSheet({
    super.key,
    required this.task,
  });

  static void show(BuildContext context, {required TaskModel task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactDetailsBottomSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title Header
          Row(
            children: const [
              Icon(Icons.badge_rounded, color: AppColors.primaryGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Stakeholder Contact Info',
                style: AppTextStyles.headingSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildDetailRow('Assignee', task.assigneeName, '${task.designation} (${task.mobile})'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Vendor Firm', task.vendorName, 'Partner: ${task.partnerName}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Supervisor', task.supervisorName, ''),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Project Manager', task.projectManagerName, ''),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Approver', task.approverName, 'Approval: ${task.approvalStatus}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Creator', task.creatorName, ''),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepNavy,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.borderGray),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.mutedTextGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedTextGray,
            ),
          ),
      ],
    );
  }
}
