import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_model.dart';

/// Detailed View Screen for a single Team Member displaying Profile, Roles, Permissions, Vendor, and Account details
class TeamMemberDetailScreen extends StatelessWidget {
  final UserModel member;

  const TeamMemberDetailScreen({
    super.key,
    required this.member,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return 'N/A';
    }
  }

  Map<String, List<String>> _groupPermissions(List<String> perms) {
    final Map<String, List<String>> grouped = {};
    for (final p in perms) {
      if (p.contains('.')) {
        final parts = p.split('.');
        final module = parts.first.toUpperCase();
        final action = parts.last.toUpperCase();
        grouped.putIfAbsent(module, () => []).add(action);
      } else {
        grouped.putIfAbsent('GENERAL', () => []).add(p.toUpperCase());
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedPerms = _groupPermissions(member.permissions);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Member Profile',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              member.displayEmployeeId,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PROFILE CARD
            _buildSectionCard(
              title: 'PROFILE INFORMATION',
              icon: Icons.person_outline_rounded,
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          member.initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.displayName,
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Username: ${member.username}',
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: member.isActive
                                    ? AppColors.successGreen.withValues(alpha: 0.12)
                                    : AppColors.criticalRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                member.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: member.isActive ? AppColors.successGreen : AppColors.criticalRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.borderGray),
                  _buildDetailRow('Employee ID', member.displayEmployeeId),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Email Address', member.email.isNotEmpty ? member.email : 'N/A'),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Phone Number', member.phoneNumber ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. ROLE & ACCESS CARD
            _buildSectionCard(
              title: 'ROLE & PERMISSIONS',
              icon: Icons.admin_panel_settings_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Primary Role', member.role),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Assigned Roles', member.roles.join(', ')),
                  const Divider(height: 20, color: AppColors.borderGray),

                  const Text(
                    'Assigned Module Permissions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (groupedPerms.isEmpty)
                    const Text('No direct permissions assigned.', style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray))
                  else
                    ...groupedPerms.entries.map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: entry.value
                                    .map((act) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppColors.borderGray),
                                          ),
                                          child: Text(
                                            act,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. VENDOR CARD
            _buildSectionCard(
              title: 'VENDOR ASSIGNMENT',
              icon: Icons.storefront_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Vendor Firm', member.displayVendor),
                  if (member.vendorDetails != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow('Vendor Code', member.vendorDetails!['vendor_code']?.toString() ?? 'N/A'),
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow('Vendor Type', member.vendorDetails!['vendor_type']?.toString() ?? 'COMPANY'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. ACCOUNT CARD
            _buildSectionCard(
              title: 'ACCOUNT DETAILS',
              icon: Icons.history_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Account Status', member.isActive ? 'Active' : 'Inactive'),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Date Joined', _formatDate(member.dateJoined)),
                  if (member.externalUserId != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow('External User ID', member.externalUserId!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.deepNavy,
            ),
          ),
        ),
      ],
    );
  }
}
