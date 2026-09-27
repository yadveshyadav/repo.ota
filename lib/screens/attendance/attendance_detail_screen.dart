import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
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
  String? _resolvedPhotoUrl;
  bool _isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _resolvePhotoUrl();
  }

  Future<void> _resolvePhotoUrl() async {
    final rawKey = widget.attendance.primaryImagePath;
    if (rawKey == null || rawKey.isEmpty) return;

    if (rawKey.startsWith('http://') ||
        rawKey.startsWith('https://') ||
        rawKey.startsWith('data:') ||
        rawKey.startsWith('/')) {
      setState(() {
        _resolvedPhotoUrl = rawKey;
      });
      return;
    }

    setState(() {
      _isLoadingPhoto = true;
    });

    try {
      final url = await widget.controller.repository.getPhotoUrl(
        musterId: widget.attendance.id,
        photoKey: rawKey,
      );
      if (mounted) {
        setState(() {
          _resolvedPhotoUrl = url.isNotEmpty ? url : rawKey;
          _isLoadingPhoto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedPhotoUrl = rawKey;
          _isLoadingPhoto = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final att = widget.attendance;

        final dateStr = DateParserUtils.formatIstDate(att.checkInTime);
        final timeStr = DateParserUtils.formatIstTime(att.checkInTime);
        final submittedAtStr = DateParserUtils.formatDisplay(att.createdAt ?? att.checkInTime);

        final approvedAtStr = att.approvedAt != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(att.approvedAt!)
            : '-';

        final photoPath = _resolvedPhotoUrl ?? att.primaryImagePath;
        final locSource = att.locationSource ?? 'GPS';

        Color statusColor = AppColors.warningAmber;
        String statusText = 'PENDING APPROVAL';

        if (!att.isSynced) {
          statusColor = AppColors.infoBlue;
          statusText = 'OFFLINE (PENDING SYNC)';
        } else if (att.isApproved || att.status == 'PRESENT') {
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
                      if (_isLoadingPhoto) ...[
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
                                SizedBox(width: 10),
                                Text('Fetching photo view URL...', style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
                              ],
                            ),
                          ),
                        ),
                      ] else if (photoPath != null && photoPath.isNotEmpty) ...[
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

                // 3. LOCATION & GPS COORDINATES SECTION
                _buildSectionCard(
                  title: 'LOCATION & GPS COORDINATES',
                  icon: Icons.location_on_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.softGray,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Location Source', style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray)),
                                Text(locSource, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                              ],
                            ),
                            const Divider(height: 16, color: AppColors.borderGray),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Latitude', style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray)),
                                Text(
                                  att.primaryLatitude != null && att.primaryLatitude != 0.0
                                      ? att.primaryLatitude!.toStringAsFixed(6)
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: AppColors.borderGray),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Longitude', style: TextStyle(fontSize: 11, color: AppColors.mutedTextGray)),
                                Text(
                                  att.primaryLongitude != null && att.primaryLongitude != 0.0
                                      ? att.primaryLongitude!.toStringAsFixed(6)
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy, fontFamily: 'monospace'),
                                ),
                              ],
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
              ],
            ),
          ),
        );
      },
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
