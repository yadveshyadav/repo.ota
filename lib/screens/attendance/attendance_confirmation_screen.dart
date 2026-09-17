import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/screens/attendance/attendance_success_screen.dart';
import '../../shared/widgets/safe_image_widget.dart';

/// Pre-submission Review screen showing Employee / Machine, Date, Time, Status, Photo, Coordinates, and Confirmation button
class AttendanceConfirmationScreen extends StatefulWidget {
  final AttendanceController controller;
  final bool isCheckOut;
  final Machine? selectedMachine;
  final UserModel? targetTeamMember;

  const AttendanceConfirmationScreen({
    super.key,
    required this.controller,
    required this.isCheckOut,
    this.selectedMachine,
    this.targetTeamMember,
  });

  @override
  State<AttendanceConfirmationScreen> createState() => _AttendanceConfirmationScreenState();
}

class _AttendanceConfirmationScreenState extends State<AttendanceConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    final location = widget.controller.capturedLocation;
    final photoBytes = widget.controller.capturedPhotoBytes;
    final photoPath = widget.controller.capturedPhotoPath;
    final isSubmitting = widget.controller.isSubmitting;
    final errorMessage = widget.controller.errorMessage;

    final user = AuthStorageService().currentUser;
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username.isNotEmpty == true ? user!.username : 'User');

    final actionLabel = widget.isCheckOut ? 'Check Out' : 'Check In';
    final title = 'Review & Confirm Attendance';

    String subjectLabel = 'Employee';
    String subjectValue = userName;

    if (widget.selectedMachine != null) {
      subjectLabel = 'Assigned Machine';
      subjectValue = '${widget.selectedMachine!.displayName} (${widget.selectedMachine!.chassisNumber})';
    } else if (widget.targetTeamMember != null) {
      subjectLabel = 'Marked For';
      subjectValue = '${widget.targetTeamMember!.displayName} (${widget.targetTeamMember!.displayEmployeeId})';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Banner
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.criticalRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.criticalRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: AppColors.criticalRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Employee & Date Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                children: [
                  _buildMetaRow(
                    icon: Icons.person_outline_rounded,
                    label: subjectLabel,
                    value: subjectValue,
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildMetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateParserUtils.formatIstDate(DateTime.now()),
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildMetaRow(
                    icon: Icons.access_time_rounded,
                    label: 'Check-in Time',
                    value: DateParserUtils.formatIstTime(DateTime.now()),
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildMetaRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Status',
                    value: 'Pending Approval',
                    badgeColor: AppColors.warningAmber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Photo Preview Box
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImageWidget(
                  photoPath: photoPath,
                  photoBytes: photoBytes,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Captured Location Metadata Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DEVICE LOCATION (GPS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                  const SizedBox(height: 10),
                  _buildMetaRow(
                    icon: Icons.location_on_rounded,
                    label: 'Latitude',
                    value: location != null ? location.latitude.toStringAsFixed(6) : '28.6139',
                  ),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildMetaRow(
                    icon: Icons.location_on_rounded,
                    label: 'Longitude',
                    value: location != null ? location.longitude.toStringAsFixed(6) : '77.2090',
                  ),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildMetaRow(
                    icon: Icons.gps_fixed_rounded,
                    label: 'Location Source',
                    value: widget.controller.locationSource,
                    badgeColor: widget.controller.useTestLocation ? AppColors.warningAmber : AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notice Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your attendance record will be submitted for manager approval with photo & GPS verification.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.deepNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            widget.controller.resetCaptureState();
                            Navigator.of(context).pop();
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Retake / Edit', style: TextStyle(color: AppColors.deepNavy, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            final success = widget.selectedMachine != null
                                ? await widget.controller.submitMachineCheckIn(widget.selectedMachine!)
                                : widget.targetTeamMember != null
                                    ? await widget.controller.submitTeamCheckIn(widget.targetTeamMember!)
                                    : widget.isCheckOut
                                        ? await widget.controller.submitCheckOut()
                                        : await widget.controller.submitCheckIn();

                            if (mounted) {
                              if (success) {
                                final currentAtt = widget.controller.todayAttendance;
                                if (currentAtt != null) {
                                  navigator.pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceSuccessScreen(
                                        attendance: currentAtt,
                                        controller: widget.controller,
                                      ),
                                    ),
                                  );
                                } else {
                                  navigator.pop();
                                }
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(widget.controller.errorMessage ?? 'Attendance submission failed. Please try again.'),
                                    backgroundColor: AppColors.criticalRed,
                                  ),
                                );
                              }
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      isSubmitting ? 'Confirming...' : 'Confirm $actionLabel',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isCheckOut ? AppColors.warningAmber : AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    Color? badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mutedTextGray),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
          ],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.deepNavy).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: badgeColor ?? AppColors.deepNavy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
