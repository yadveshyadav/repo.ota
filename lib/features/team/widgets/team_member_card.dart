import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_model.dart';

/// Responsive Mobile Team Member Card Component complying with Section 9 UI requirements
class TeamMemberCard extends StatelessWidget {
  final UserModel member;
  final VoidCallback onViewDetails;

  const TeamMemberCard({
    super.key,
    required this.member,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = member.isActive;
    final extraRolesCount = member.roles.length > 1 ? member.roles.length - 1 : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER: Avatar, Name, Username & Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or Initials
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Username: ${member.username}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedTextGray,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : AppColors.criticalRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppColors.successGreen.withValues(alpha: 0.3)
                        : AppColors.criticalRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isActive ? '• ACTIVE' : '• INACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.successGreen : AppColors.criticalRed,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20, color: AppColors.borderGray),

          // DETAILS GRID: Role, Vendor, Employee ID
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Role', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.role,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (extraRolesCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.infoBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+$extraRolesCount',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.infoBlue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Vendor', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(
                      member.displayVendor,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee ID', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(
                      member.displayEmployeeId,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phone', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                      const SizedBox(height: 2),
                      Text(
                        member.phoneNumber!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ACTION: View Details Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
