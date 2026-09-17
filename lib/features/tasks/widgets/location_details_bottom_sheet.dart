import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/models/task_model.dart';

/// Lightweight contextual bottom sheet displaying Location & Network Telemetry details
class LocationDetailsBottomSheet extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onOpenMap;

  const LocationDetailsBottomSheet({
    super.key,
    required this.task,
    this.onOpenMap,
  });

  static void show(BuildContext context, {required TaskModel task, VoidCallback? onOpenMap}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationDetailsBottomSheet(
        task: task,
        onOpenMap: onOpenMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordsText = (task.latitude != null && task.longitude != null && task.latitude != 0.0)
        ? '${task.latitude!.toStringAsFixed(6)}, ${task.longitude!.toStringAsFixed(6)}'
        : 'Location not available';

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
              Icon(Icons.location_on_rounded, color: AppColors.primaryGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Location Details',
                style: AppTextStyles.headingSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildDetailRow('Location Name', task.locationName),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('District & Circle', '${task.district}, ${task.circle}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Block & State', '${task.blockName}, ${task.state}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Location Code', task.locationCode),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('OLT IP / BA & CMP', '${task.telemetry.oltIp} (${task.telemetry.baCmp})'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('Company Phase', task.telemetry.companyPhase),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildDetailRow('GPS Coordinates', coordsText),

          const SizedBox(height: 20),

          // Action: Open Map button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (onOpenMap != null) onOpenMap!();
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Open Map View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mutedTextGray,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
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
