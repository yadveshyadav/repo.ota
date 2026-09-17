import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/attendance_model.dart';
import '../../shared/widgets/safe_image_widget.dart';

/// Full Attendance Review & Detail Screen displaying employee info, stored photo,
/// verified location coordinates on map, and admin approval controls.
class AttendanceDetailScreen extends StatefulWidget {
  final AttendanceModel attendance;
  final AttendanceController controller;

  const AttendanceDetailScreen({
    super.key,
    required this.attendance,
    required this.controller,
  });

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  final TextEditingController _rejectionController = TextEditingController();

  @override
  void dispose() {
    _rejectionController.dispose();
    super.dispose();
  }

  bool _isSelfRecord() {
    final currentUser = AuthStorageService().currentUser;
    if (currentUser == null) return false;

    final cId = currentUser.id;
    final cEmpId = currentUser.employeeId ?? '';
    final cUsername = currentUser.username.toLowerCase();
    final cName = currentUser.displayName.toLowerCase();

    return widget.attendance.userId == cId ||
        (widget.attendance.employeeId != null && widget.attendance.employeeId == cEmpId) ||
        widget.attendance.userName.toLowerCase() == cUsername ||
        widget.attendance.userName.toLowerCase() == cName;
  }

  void _openFullScreenImage(String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Attendance Photo', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: AppImageWidget(
                photoPath: imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleApprove() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isSelfRecord()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot approve your own attendance.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    final dateStr = widget.attendance.checkInTime != null
        ? DateFormat('dd MMMM yyyy').format(widget.attendance.checkInTime!)
        : DateFormat('dd MMMM yyyy').format(DateTime.now());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Attendance'),
        content: Text('Are you sure you want to approve attendance for ${widget.attendance.userName} ($dateStr)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.controller.approveAttendance(widget.attendance.id);

      if (mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Attendance approved for ${widget.attendance.userName}'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleReject() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isSelfRecord()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot reject your own attendance.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    _rejectionController.clear();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please specify a reason for rejecting ${widget.attendance.userName}\'s attendance:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionController,
              decoration: const InputDecoration(
                hintText: 'e.g., Photo unclear, Location out of bounds',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason.'),
                    backgroundColor: AppColors.criticalRed,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.criticalRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true && _rejectionController.text.trim().isNotEmpty) {
      final success = await widget.controller.rejectAttendance(
        widget.attendance.id,
        _rejectionController.text.trim(),
      );

      if (mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Attendance rejected for ${widget.attendance.userName}'),
            backgroundColor: AppColors.criticalRed,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attendance;
    final currentUser = AuthStorageService().currentUser;
    final isManager = att.canBeApprovedBy(currentUser);
    final isPending = att.isPendingApproval || att.status == 'PENDING';

    final dateStr = DateParserUtils.formatIstDate(att.checkInTime);
    final timeStr = DateParserUtils.formatIstTime(att.checkInTime);
    final submittedAtStr = DateParserUtils.formatDisplay(att.createdAt ?? att.checkInTime);

    final approvedAtStr = att.approvedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(att.approvedAt!)
        : '-';

    final photoPath = att.primaryImagePath;
    final locSource = att.locationSource ?? 'GPS';

    Color statusColor = AppColors.warningAmber;
    String statusText = 'PENDING APPROVAL';

    if (att.isApproved || att.status == 'PRESENT') {
      statusColor = AppColors.primaryGreen;
      statusText = 'APPROVED';
    } else if (att.isRejected || att.status == 'REJECTED') {
      statusColor = AppColors.criticalRed;
      statusText = 'REJECTED';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Text('Attendance Review', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ATTENDANCE DETAILS SECTION
            _buildSectionCard(
              title: 'ATTENDANCE DETAILS',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  _buildDetailRow('Employee', att.userName),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Employee ID', att.employeeId ?? 'EMP001'),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Date', dateStr),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Check-in Time', timeStr),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Status', statusText, valueColor: statusColor),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. ATTENDANCE PHOTO SECTION
            _buildSectionCard(
              title: 'ATTENDANCE PHOTO',
              icon: Icons.camera_alt_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoPath != null && photoPath.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _openFullScreenImage(photoPath),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.softGray,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppImageWidget(
                                photoPath: photoPath,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('No photo captured for this session', style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. LOCATION & GPS SECTION
            _buildSectionCard(
              title: 'LOCATION & GPS MAP',
              icon: Icons.map_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Source: $locSource', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      Text(
                        att.primaryLatitude != null && att.primaryLongitude != null && att.primaryLatitude != 0.0 && att.primaryLongitude != 0.0
                            ? '${att.primaryLatitude!.toStringAsFixed(6)}, ${att.primaryLongitude!.toStringAsFixed(6)}'
                            : 'Location not available',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (att.primaryLatitude != null && att.primaryLongitude != null && att.primaryLatitude != 0.0 && att.primaryLongitude != 0.0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(att.primaryLatitude!, att.primaryLongitude!),
                            initialZoom: 14.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.infocrats.hero',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(att.primaryLatitude!, att.primaryLongitude!),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.criticalRed,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.location_off_outlined, color: AppColors.mutedTextGray, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Location not available',
                            style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. APPROVAL INFORMATION & AUDIT LOG
            _buildSectionCard(
              title: 'APPROVAL INFORMATION',
              icon: Icons.history_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Submitted', submittedAtStr),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Approval Status', statusText, valueColor: statusColor),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Approved / Rejected By', att.approvedBy ?? '-'),
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildDetailRow('Approved / Rejected At', approvedAtStr),
                  if (att.rejectionReason != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow('Rejection Reason', att.rejectionReason!, valueColor: AppColors.criticalRed),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Manager Action Buttons
            if (isManager && isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.controller.isSubmitting ? null : _handleReject,
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.criticalRed),
                      label: const Text('✕ Reject Attendance', style: TextStyle(color: AppColors.criticalRed, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.criticalRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.controller.isSubmitting ? null : _handleApprove,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('✓ Approve Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
        const SizedBox(width: 8),
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
