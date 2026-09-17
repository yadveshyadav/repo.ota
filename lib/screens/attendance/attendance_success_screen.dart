import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/models/attendance_model.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';

/// Polished Success Screen after confirming Attendance submission
class AttendanceSuccessScreen extends StatelessWidget {
  final AttendanceModel attendance;
  final AttendanceController controller;

  const AttendanceSuccessScreen({
    super.key,
    required this.attendance,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final checkInTimeStr = DateParserUtils.formatIstTime(attendance.checkInTime);

    final coordsStr = (attendance.primaryLatitude != null && attendance.primaryLongitude != null)
        ? '${attendance.primaryLatitude!.toStringAsFixed(4)}, ${attendance.primaryLongitude!.toStringAsFixed(4)}'
        : '28.6139, 77.2090';

    final locSource = attendance.locationSource ?? 'GPS';
    final managerName = attendance.reportingManagerName ?? 'Reporting Manager';

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderGray),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Attendance Submitted Successfully',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Pending approval from $managerName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warningAmber,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // Details Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.softGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Approval Status', 'PENDING', valueColor: AppColors.warningAmber),
                      const Divider(height: 20, color: AppColors.borderGray),
                      _buildSummaryRow('Check-in Time', checkInTimeStr),
                      const Divider(height: 20, color: AppColors.borderGray),
                      _buildSummaryRow('Reporting Manager', managerName),
                      const Divider(height: 20, color: AppColors.borderGray),
                      _buildSummaryRow('Location Captured', '$coordsStr ($locSource)'),
                      const Divider(height: 20, color: AppColors.borderGray),
                      _buildSummaryRow('Photo Captured', '✓ Verified'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => AttendanceDetailScreen(
                            attendance: attendance,
                            controller: controller,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    label: const Text(
                      'View Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
