import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/tasks/widgets/task_media_gallery.dart';
import 'package:hero_app/models/task_master_snapshots.dart';

/// Dedicated HDD Shots Log Screen / Modal Sheet for Field Execution Inspection
class HddShotsScreen extends StatelessWidget {
  final List<HddShotModel> shots;
  final String taskCode;

  const HddShotsScreen({
    super.key,
    required this.shots,
    this.taskCode = '',
  });

  static void show(BuildContext context, {required List<HddShotModel> shots, String taskCode = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HddShotsScreen(shots: shots, taskCode: taskCode),
    );
  }

  String _formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null || lat == 0.0) return 'Location not available';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.alt_route_rounded, color: AppColors.warningAmber, size: 22),
                  SizedBox(width: 8),
                  Text('HDD Shots Log', style: AppTextStyles.headingSmall),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${shots.length} Shots',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (shots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No HDD shots logged for this task.',
                  style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final shot = shots[index];
                  return _buildShotCard(shot);
                },
              ),
            ),

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

  Widget _buildShotCard(HddShotModel shot) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shot #${shot.shotNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shot.shotId,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mutedTextGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // HDD Shot Metrics Grid
          Row(
            children: [
              Expanded(child: _buildMetricTile('Shot Length', '${shot.lengthMeters} m')),
              Expanded(child: _buildMetricTile('Depth', '${shot.depthMeters ?? '2.1'} m')),
              Expanded(child: _buildMetricTile('Pipe Dia', '${shot.pipeDiameterMm ?? '110'} mm')),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderGray),
          const SizedBox(height: 8),

          _buildDetailRow('Start Coordinates', _formatLocation(shot.startLatitude, shot.startLongitude)),
          const SizedBox(height: 4),
          _buildDetailRow('End Coordinates', _formatLocation(shot.endLatitude, shot.endLongitude)),

          if (shot.photo != null) ...[
            const SizedBox(height: 10),
            TaskMediaGalleryWidget(
              title: 'HDD Shot Verification Photo',
              mediaList: [shot.photo!],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
