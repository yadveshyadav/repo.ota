import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/models/attendance_model.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';
import '../../shared/widgets/safe_image_widget.dart';

/// User Attendance History Timeline Screen displaying local attendance records,
/// photo thumbnails, location badges, and status filters.
class AttendanceHistoryScreen extends StatefulWidget {
  final AttendanceController controller;

  const AttendanceHistoryScreen({
    super.key,
    required this.controller,
  });

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    widget.controller.fetchHistory();
  }

  List<AttendanceModel> get _filteredHistory {
    if (_selectedFilter == 'ALL') return widget.controller.history;
    return widget.controller.history.where((item) {
      if (_selectedFilter == 'PRESENT') return item.status == 'PRESENT' || item.isCheckedIn || item.isApproved;
      if (_selectedFilter == 'APPROVED') return item.isApproved;
      if (_selectedFilter == 'PENDING') return item.isPendingApproval;
      if (_selectedFilter == 'REJECTED') return item.isRejected;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final isLoading = widget.controller.isLoadingHistory;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            elevation: 0,
            title: const Text(
              'Attendance History',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: () => widget.controller.fetchHistory(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Pills Bar
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill('ALL', 'All Records'),
                      const SizedBox(width: 8),
                      _buildFilterPill('PRESENT', 'Present'),
                      const SizedBox(width: 8),
                      _buildFilterPill('APPROVED', 'Approved'),
                      const SizedBox(width: 8),
                      _buildFilterPill('PENDING', 'Pending'),
                      const SizedBox(width: 8),
                      _buildFilterPill('REJECTED', 'Rejected'),
                    ],
                  ),
                ),
              ),

              // Attendance History List
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                    : _filteredHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.mutedTextGray),
                                SizedBox(height: 12),
                                Text('No attendance history found.', style: TextStyle(color: AppColors.mutedTextGray, fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredHistory.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredHistory[index];
                              return _buildHistoryCard(item);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(AttendanceModel item) {
    final dateStr = DateParserUtils.formatIstDate(item.checkInTime ?? item.createdAt);
    final inTimeStr = DateParserUtils.formatIstTime(item.checkInTime ?? item.createdAt);

    final photoPath = item.primaryImagePath;

    final coordsStr = (item.primaryLatitude != null && item.primaryLongitude != null)
        ? '${item.primaryLatitude!.toStringAsFixed(4)}, ${item.primaryLongitude!.toStringAsFixed(4)}'
        : '28.6139, 77.2090';

    final locSource = item.locationSource ?? 'GPS';

    Color statusColor = AppColors.primaryGreen;
    String statusText = item.displayStatus.toUpperCase();
    if (!item.isSynced) {
      statusColor = AppColors.infoBlue;
      statusText = 'OFFLINE (PENDING SYNC)';
    } else if (item.isApproved || item.status == 'PRESENT') {
      statusColor = AppColors.primaryGreen;
    } else if (item.isRejected) {
      statusColor = AppColors.criticalRed;
    } else if (item.isPendingApproval) {
      statusColor = AppColors.warningAmber;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !item.isSynced ? AppColors.infoBlue.withValues(alpha: 0.4) : AppColors.borderGray,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AttendanceDetailScreen(
                attendance: item,
                controller: widget.controller,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Photo Thumbnail Box
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImageWidget(
                    photoPath: photoPath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            dateStr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '• $statusText',
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check-in: $inTimeStr',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.mutedTextGray),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '$coordsStr ($locSource)',
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedTextGray, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String code, String label) {
    final isSelected = _selectedFilter == code;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = code;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightGreenBg : AppColors.softGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : AppColors.borderGray),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryGreen : AppColors.deepNavy,
          ),
        ),
      ),
    );
  }
}
