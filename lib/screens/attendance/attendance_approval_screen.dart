import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/attendance_model.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';
import '../../shared/widgets/safe_image_widget.dart';

/// Admin & Supervisor Attendance Approval Screen displaying pending attendance submissions,
/// filtered specifically for the user's authorized team members.
class AttendanceApprovalScreen extends StatefulWidget {
  final AttendanceController controller;

  const AttendanceApprovalScreen({
    super.key,
    required this.controller,
  });

  @override
  State<AttendanceApprovalScreen> createState() => _AttendanceApprovalScreenState();
}

class _AttendanceApprovalScreenState extends State<AttendanceApprovalScreen> {
  String _selectedFilter = 'PENDING';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.fetchAuthorizedTeamMembers();
    widget.controller.fetchPendingApprovals();
    widget.controller.fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }

  /// Filters all records down to authorized team members only
  List<AttendanceModel> get _teamRecords {
    final Map<String, AttendanceModel> combined = {};

    for (final item in widget.controller.pendingApprovals) {
      combined[item.id] = item;
    }
    for (final item in widget.controller.history) {
      if (!combined.containsKey(item.id)) {
        combined[item.id] = item;
      }
    }

    final currentUser = AuthStorageService().currentUser;
    final teamMembers = widget.controller.teamMembers;

    return combined.values.where((item) {
      if (currentUser == null) return true;

      // Match by reporting manager ID
      if (item.reportingManagerId != null &&
          item.reportingManagerId!.isNotEmpty &&
          item.reportingManagerId == currentUser.id) {
        return true;
      }

      if (teamMembers.isEmpty) return true;

      final recUserId = item.userId.trim().toLowerCase();
      final recMarkedForId = (item.markedForUserId ?? '').trim().toLowerCase();
      final recEmpId = (item.employeeId ?? '').trim().toLowerCase();
      final recUserName = item.userName.trim().toLowerCase();

      for (final member in teamMembers) {
        final mId = member.id.trim().toLowerCase();
        final mEmpId = member.displayEmployeeId.trim().toLowerCase();
        final mName = member.displayName.trim().toLowerCase();
        final mUsername = member.username.trim().toLowerCase();

        if (recUserId == mId ||
            (recMarkedForId.isNotEmpty && recMarkedForId == mId) ||
            (recEmpId.isNotEmpty && (recEmpId == mEmpId || recEmpId == mId)) ||
            (recUserName.isNotEmpty && (recUserName == mName || recUserName == mUsername))) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  List<AttendanceModel> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    final teamList = _teamRecords;

    return teamList.where((item) {
      if (_selectedFilter == 'PENDING' && !item.isPendingApproval && item.status != 'PENDING') {
        return false;
      }
      if (_selectedFilter == 'APPROVED' && !item.isApproved && item.status != 'PRESENT') {
        return false;
      }
      if (_selectedFilter == 'REJECTED' && !item.isRejected && item.status != 'REJECTED') {
        return false;
      }

      if (query.isNotEmpty) {
        final nameMatch = item.userName.toLowerCase().contains(query);
        final empIdMatch = (item.employeeId ?? '').toLowerCase().contains(query);
        return nameMatch || empIdMatch;
      }

      return true;
    }).toList();
  }

  bool _isSelfRecord(AttendanceModel record) {
    final currentUser = AuthStorageService().currentUser;
    if (currentUser == null) return false;

    final cId = currentUser.id;
    final cEmpId = currentUser.employeeId ?? '';
    final cUsername = currentUser.username.toLowerCase();
    final cName = currentUser.displayName.toLowerCase();

    return record.userId == cId ||
        (record.employeeId != null && record.employeeId == cEmpId) ||
        record.userName.toLowerCase() == cUsername ||
        record.userName.toLowerCase() == cName;
  }

  Future<void> _handleApprove(AttendanceModel item) async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isSelfRecord(item)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot approve your own attendance record.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    final dateStr = item.checkInTime != null
        ? DateFormat('dd MMMM yyyy').format(item.checkInTime!)
        : DateFormat('dd MMMM yyyy').format(DateTime.now());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Attendance'),
        content: Text('Are you sure you want to approve attendance for ${item.userName} ($dateStr)?'),
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
      final success = await widget.controller.approveAttendance(item.id);

      if (mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Attendance approved for ${item.userName}'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(widget.controller.errorMessage ?? 'Unable to approve attendance. Please verify permissions.'),
              backgroundColor: AppColors.criticalRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject(AttendanceModel item) async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isSelfRecord(item)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot reject your own attendance record.'),
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
            Text('Please specify a reason for rejecting ${item.userName}\'s attendance:'),
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
        item.id,
        _rejectionController.text.trim(),
      );

      if (mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Attendance rejected for ${item.userName}'),
              backgroundColor: AppColors.criticalRed,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(widget.controller.errorMessage ?? 'Unable to reject attendance.'),
              backgroundColor: AppColors.criticalRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final teamRecords = _teamRecords;
        final pendingCount = teamRecords.where((r) => r.isPendingApproval || r.status == 'PENDING').length;
        final approvedCount = teamRecords.where((r) => r.isApproved || r.status == 'PRESENT').length;
        final rejectedCount = teamRecords.where((r) => r.isRejected || r.status == 'REJECTED').length;

        final isLoading = widget.controller.isLoadingHistory;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Attendance Approval',
                  style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Review and approve attendance submitted by users',
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: () {
                  widget.controller.fetchAuthorizedTeamMembers();
                  widget.controller.fetchPendingApprovals();
                  widget.controller.fetchHistory();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Summary Cards
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Pending',
                        count: pendingCount,
                        color: AppColors.warningAmber,
                        isSelected: _selectedFilter == 'PENDING',
                        onTap: () => setState(() => _selectedFilter = 'PENDING'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Approved',
                        count: approvedCount,
                        color: AppColors.primaryGreen,
                        isSelected: _selectedFilter == 'APPROVED',
                        onTap: () => setState(() => _selectedFilter = 'APPROVED'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Rejected',
                        count: rejectedCount,
                        color: AppColors.criticalRed,
                        isSelected: _selectedFilter == 'REJECTED',
                        onTap: () => setState(() => _selectedFilter = 'REJECTED'),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Row
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search employee name or ID...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.mutedTextGray),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: AppColors.softGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderGray),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.borderGray),

              // Filter Chips Row
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterPill('PENDING', 'Pending ($pendingCount)'),
                    const SizedBox(width: 8),
                    _buildFilterPill('APPROVED', 'Approved ($approvedCount)'),
                    const SizedBox(width: 8),
                    _buildFilterPill('REJECTED', 'Rejected ($rejectedCount)'),
                    const SizedBox(width: 8),
                    _buildFilterPill('ALL', 'All'),
                  ],
                ),
              ),

              // Records List
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                    : _filteredRecords.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredRecords.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredRecords[index];
                              return _buildApprovalCard(item);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.softGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.borderGray,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.mutedTextGray,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AppColors.deepNavy,
              ),
            ),
          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.verified_outlined, size: 52, color: AppColors.successGreen),
            SizedBox(height: 16),
            Text(
              '✓ All Caught Up',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
            ),
            SizedBox(height: 6),
            Text(
              'No attendance is waiting for approval for your team.',
              style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCard(AttendanceModel item) {
    final dateStr = DateParserUtils.formatIstDate(item.checkInTime ?? item.createdAt);
    final inTimeStr = DateParserUtils.formatIstTime(item.checkInTime ?? item.createdAt);

    final photoPath = item.primaryImagePath;
    final coordsStr = (item.primaryLatitude != null && item.primaryLongitude != null)
        ? '${item.primaryLatitude!.toStringAsFixed(4)}, ${item.primaryLongitude!.toStringAsFixed(4)}'
        : '28.6139, 77.2090';

    final locSource = item.locationSource ?? 'GPS';
    final isPending = item.isPendingApproval || item.status == 'PENDING';

    Color statusColor = AppColors.warningAmber;
    String statusLabel = 'PENDING APPROVAL';
    IconData statusIcon = Icons.hourglass_empty_rounded;

    if (item.isApproved || item.status == 'PRESENT') {
      statusColor = AppColors.primaryGreen;
      statusLabel = 'APPROVED';
      statusIcon = Icons.check_circle_rounded;
    } else if (item.isRejected || item.status == 'REJECTED') {
      statusColor = AppColors.criticalRed;
      statusLabel = 'REJECTED';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: User Avatar & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      child: Text(
                        item.userName.isNotEmpty ? item.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.employeeId != null)
                            Text(
                              'ID: ${item.employeeId}',
                              style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),

          // Content Row: Photo & Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImageWidget(
                    photoPath: photoPath,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.deepNavy),
                        ),
                        Text(
                          'Time: $inTimeStr',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.mutedTextGray),
                        const SizedBox(width: 4),
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
            ],
          ),
          const SizedBox(height: 14),

          // Actions
          if (isPending)
            Row(
              children: [
                // Reject / Approve temporarily disabled
                // Expanded(
                //   child: OutlinedButton.icon(
                //     onPressed: widget.controller.isSubmitting ? null : () => _handleReject(item),
                //     icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.criticalRed),
                //     label: const Text('Reject', style: TextStyle(color: AppColors.criticalRed, fontWeight: FontWeight.bold, fontSize: 13)),
                //     style: OutlinedButton.styleFrom(
                //       side: const BorderSide(color: AppColors.criticalRed),
                //       padding: const EdgeInsets.symmetric(vertical: 10),
                //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 10),
                // Expanded(
                //   child: ElevatedButton.icon(
                //     onPressed: widget.controller.isSubmitting ? null : () => _handleApprove(item),
                //     icon: const Icon(Icons.check_circle_outline, size: 16),
                //     label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: AppColors.primaryGreen,
                //       foregroundColor: AppColors.white,
                //       padding: const EdgeInsets.symmetric(vertical: 10),
                //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 10),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primaryGreen),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceDetailScreen(
                          attendance: item,
                          controller: widget.controller,
                        ),
                      ),
                    );
                  },
                  tooltip: 'View Full Detail',
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceDetailScreen(
                        attendance: item,
                        controller: widget.controller,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryGreen),
                label: const Text('View Full Detail', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
