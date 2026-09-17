import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../services/authorization_service.dart';

/// Modal dialog displaying comprehensive User Profile details
class UserProfileDialog extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onEditPressed;

  const UserProfileDialog({
    super.key,
    required this.user,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final isMobile = media.width < 640;
    final canManageUsers = AuthorizationService.instance.can('users.manage');

    final initials = user.displayName
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();

    final vendorName = user.vendorName ??
        user.vendorDetails?['name']?.toString() ??
        (user.vendors.isNotEmpty ? user.vendors.first['name']?.toString() : null) ??
        'Internal Infrastructure';

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: media.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Avatar, Name, Role & Close Button
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  child: Text(
                    initials.isNotEmpty ? initials : 'U',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: user.isActive
                                  ? AppColors.successGreen.withValues(alpha: 0.15)
                                  : AppColors.mutedTextGray.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              user.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                color: user.isActive ? AppColors.successGreen : AppColors.mutedTextGray,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.username,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user.role,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedTextGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.mutedTextGray),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.borderGray),

            // Main Details Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Contact Information
                    const Text(
                      'CONTACT INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTextGray,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.email_outlined,
                            label: 'Email Address',
                            value: user.email.isNotEmpty ? user.email : '--',
                          ),
                          const Divider(height: 16, color: AppColors.borderGray),
                          _buildDetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            value: user.phoneNumber?.isNotEmpty == true ? user.phoneNumber! : '--',
                          ),
                          if (user.employeeId != null && user.employeeId!.isNotEmpty) ...[
                            const Divider(height: 16, color: AppColors.borderGray),
                            _buildDetailRow(
                              icon: Icons.badge_outlined,
                              label: 'Employee ID',
                              value: user.employeeId!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Organization & Vendor Assignment
                    const Text(
                      'ORGANIZATION & VENDOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTextGray,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.storefront_outlined,
                            label: 'Assigned Vendor',
                            value: vendorName,
                          ),
                          const Divider(height: 16, color: AppColors.borderGray),
                          _buildDetailRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Assigned Roles',
                            value: user.roles.join(', '),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Effective Permissions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EFFECTIVE PERMISSIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedTextGray,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${user.permissions.length} Granted',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: user.permissions.isEmpty
                          ? const Text(
                              'Standard Role Capabilities Applied',
                              style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: user.permissions.map((perm) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderGray),
                                  ),
                                  child: Text(
                                    perm,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 24, color: AppColors.borderGray),

            // Bottom Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: const BorderSide(color: AppColors.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close', style: TextStyle(color: AppColors.deepNavy)),
                ),
                if (canManageUsers) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEditPressed?.call();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit User Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedTextGray),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
