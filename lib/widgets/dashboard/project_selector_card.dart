import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Dark Green Project Selector & Date Filter Bar matching Screen 1 reference design
class ProjectSelectorCard extends StatelessWidget {
  final String currentProject;
  final String selectedDate;
  final String? lastUpdatedText;

  const ProjectSelectorCard({
    super.key,
    this.currentProject = 'Mumbai Coastal Road',
    this.selectedDate = '12 May 2025',
    this.lastUpdatedText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.headerGreen,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Location Pin Icon Circle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),

          // Project Title Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Project',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentProject,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Vertical Divider
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.white.withValues(alpha: 0.3),
          ),

          // Date Selector Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                selectedDate,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.white,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
