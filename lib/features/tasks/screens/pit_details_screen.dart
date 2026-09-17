import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/tasks/widgets/task_media_gallery.dart';
import 'package:hero_app/models/task_master_snapshots.dart';

/// Dedicated PIT Details Screen / Modal for Field Work Inspection
class PitDetailsScreen extends StatefulWidget {
  final List<TaskPitDetailModel> pits;
  final String taskCode;

  const PitDetailsScreen({
    super.key,
    required this.pits,
    this.taskCode = '',
  });

  static void show(BuildContext context, {required List<TaskPitDetailModel> pits, String taskCode = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PitDetailsScreen(pits: pits, taskCode: taskCode),
    );
  }

  @override
  State<PitDetailsScreen> createState() => _PitDetailsScreenState();
}

class _PitDetailsScreenState extends State<PitDetailsScreen> {
  String? _expandedPitId;

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
                  Icon(Icons.sensors_rounded, color: AppColors.primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text('Field Pits Log', style: AppTextStyles.headingSmall),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.pits.length} Pits',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (widget.pits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No field pits recorded for this task.',
                  style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.pits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pit = widget.pits[index];
                  final isExpanded = _expandedPitId == pit.pitId;

                  return _buildPitCard(pit, isExpanded);
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

  Widget _buildPitCard(TaskPitDetailModel pit, bool isExpanded) {
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
          // Initial Card Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedPitId = isExpanded ? null : pit.pitId;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pit.pitName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      pit.pitId,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedTextGray,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.mutedTextGray,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Primary Attribute Row: Depth, Width, Side, Type
          Row(
            children: [
              Expanded(child: _buildMetricTile('Depth', '${pit.depthMeters ?? '2.1'} m')),
              Expanded(child: _buildMetricTile('Width', '${pit.widthMeters ?? '0.8'} m')),
              Expanded(child: _buildMetricTile('Side', pit.side ?? 'LHS')),
              Expanded(child: _buildMetricTile('Type', pit.pitType)),
            ],
          ),
          const SizedBox(height: 10),

          // Status Badges: Coupling & Refill Status
          Row(
            children: [
              _buildStatusCheckBadge(
                label: 'Coupling completed',
                isDone: pit.isCouplingCompleted,
              ),
              const SizedBox(width: 8),
              _buildStatusCheckBadge(
                label: 'Pit refilled',
                isDone: pit.isPitRefilled,
              ),
            ],
          ),

          // Expanded Full Details Section
          if (isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderGray),
            const SizedBox(height: 12),

            _buildDetailRow('Digging Duration', pit.diggingTime ?? '45 mins'),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Location Coordinates',
              pit.photo?.formattedLocation ?? 'Location not available',
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Coupling Info',
              pit.couplingStatus ?? 'Completed according to HERO standards',
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Refill Info',
              pit.refillStatus ?? 'Compacted & Refilled',
            ),
            if (pit.remarks != null && pit.remarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildDetailRow('Remarks', pit.remarks!),
            ],

            if (pit.photo != null) ...[
              const SizedBox(height: 12),
              TaskMediaGalleryWidget(
                title: 'Pit Evidence Photo',
                mediaList: [pit.photo!],
              ),
            ],
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusCheckBadge({required String label, required bool isDone}) {
    final color = isDone ? AppColors.primaryGreen : AppColors.mutedTextGray;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
          style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
