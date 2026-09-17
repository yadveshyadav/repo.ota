import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/vendor.dart';

/// Presentation-only Vendor Card widget matching HERO WEB Vendor Reference
class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;

  const VendorCard({
    super.key,
    required this.vendor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = vendor.isActive;
    final statusColor = isActive ? AppColors.successGreen : AppColors.mutedTextGray;
    final codeText = vendor.vendorCode ?? 'VEN-001';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER (Vendor Code Badge & Status Badge)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dark Green Vendor Code Badge (697F18B0, 6337F4A9, etc.)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.headerGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      codeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // Status Badge (• ACTIVE)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${vendor.status.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. COMPANY / VENDOR NAME
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                vendor.vendorName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                  height: 1.25,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 8),

            // 3. CONTACT DETAILS (Contact Person, Email, Phone, Location)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Person & Email
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppColors.mutedTextGray,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vendor.email != null && vendor.email!.isNotEmpty
                              ? '${vendor.contactPerson} (${vendor.email})'
                              : vendor.contactPerson,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Phone
                  if (vendor.phone != null && vendor.phone!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.mutedTextGray,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vendor.phone!,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.mutedTextGray,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vendor.location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedTextGray,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            const Divider(height: 1, color: AppColors.borderGray),

            // 4. FOOTER (Machine Count & Member Count)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Machine Count Link
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.precision_manufacturing_rounded,
                        size: 15,
                        color: AppColors.infoBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${vendor.machineCount} HDD Machines',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.infoBlue,
                        ),
                      ),
                    ],
                  ),

                  // Member Count Link
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 15,
                        color: AppColors.deepNavy,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${vendor.memberCount} Members',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
