import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_parser_utils.dart';
import '../../features/attendance/controller/attendance_controller.dart';
import '../../models/attendance_model.dart';
import '../../shared/widgets/premium_card.dart';

/// Attendance Card for Dashboard displaying today's attendance state & action buttons
class DashboardAttendanceCard extends StatelessWidget {
  final AttendanceController controller;
  final VoidCallback onMarkAttendance;
  final VoidCallback onCheckOut;
  final ValueChanged<AttendanceModel>? onViewDetails;

  const DashboardAttendanceCard({
    super.key,
    required this.controller,
    required this.onMarkAttendance,
    required this.onCheckOut,
    this.onViewDetails,
  });

  void _handleMarkAttendancePressed(BuildContext context) {
    if (controller.todayAttendance != null &&
        controller.todayAttendance!.status != 'NOT_CHECKED_IN') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Attendance Already Marked'),
          content: const Text('Attendance has already been marked for today.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (controller.todayAttendance != null) {
                  onViewDetails?.call(controller.todayAttendance!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text('View Today\'s Attendance'),
            ),
          ],
        ),
      );
      return;
    }

    onMarkAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final attendanceRecord = controller.todayAttendance;
        final isLoading = controller.isLoadingToday;

        final bool isMarked = attendanceRecord != null &&
            (attendanceRecord.status == 'PRESENT' || attendanceRecord.isCheckedIn || attendanceRecord.isCheckedOut);

        return PremiumCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Today\'s Attendance',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            'GPS Location & Photo Verification',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (attendanceRecord != null && isMarked) _buildStatusBadge(attendanceRecord),
                ],
              ),
              const SizedBox(height: 16),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2),
                  ),
                )
              else if (!isMarked)
                _buildNotCheckedInView(context)
              else
                _buildMarkedView(attendanceRecord),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotCheckedInView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.mutedTextGray),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Not Marked • Start your workday with photo & GPS verification',
                style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _handleMarkAttendancePressed(context),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text(
              'Mark Attendance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkedView(AttendanceModel attendance) {
    final checkInTimeString = attendance.checkInTime != null
        ? _formatTime(attendance.checkInTime!)
        : '--:--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check-in Time',
                      style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkInTimeString,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Photo Verification',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryGreen),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Photo ✓ Captured',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(height: 28, width: 1, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Status',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            attendance.isTestLocation ? 'Test Location' : 'GPS Captured',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => onViewDetails?.call(attendance),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(AttendanceModel attendance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'PRESENT',
        style: TextStyle(
          color: AppColors.successGreen,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateParserUtils.formatIstTime(dt);
  }
}
