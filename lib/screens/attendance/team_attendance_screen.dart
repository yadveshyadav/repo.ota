import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/screens/attendance/attendance_capture_screen.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';

/// Team Attendance Screen displaying Authorized Team Members for Supervisor Attendance Marking
class TeamAttendanceScreen extends StatefulWidget {
  final AttendanceController controller;

  const TeamAttendanceScreen({
    super.key,
    required this.controller,
  });

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.fetchAuthorizedTeamMembers();
    widget.controller.fetchHistory();
  }

  void _openTeamMemberCapture(UserModel member) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceCaptureScreen(
          controller: widget.controller,
          isCheckOut: false,
          targetTeamMember: member,
        ),
      ),
    );
    if (mounted) {
      widget.controller.fetchAuthorizedTeamMembers();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Team Attendance',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Mark attendance for your authorized team members',
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
              widget.controller.fetchHistory();
            },
          ),
        ],
      ),
      body: _buildTeamMembersTab(),
    );
  }

  Widget _buildTeamMembersTab() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final isLoading = widget.controller.isLoadingHistory;
        final teamMembers = widget.controller.teamMembers;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }

        if (teamMembers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.people_outline_rounded, size: 52, color: AppColors.mutedTextGray),
                  SizedBox(height: 16),
                  Text('No Authorized Team Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                  SizedBox(height: 6),
                  Text('You do not have any employees assigned under your team authority.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: teamMembers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final member = teamMembers[index];
            return _buildTeamMemberTile(member);
          },
        );
      },
    );
  }

  Widget _buildTeamMemberTile(UserModel member) {
    final todayRecord = widget.controller.getTodayAttendanceForUser(
      member.id,
      employeeId: member.displayEmployeeId,
      userName: member.displayName,
    );

    final bool isMarked = todayRecord != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMarked ? AppColors.primaryGreen.withValues(alpha: 0.4) : AppColors.borderGray,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: (isMarked ? AppColors.primaryGreen : AppColors.deepNavy).withValues(alpha: 0.15),
                      child: Text(
                        member.initials,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMarked ? AppColors.primaryGreen : AppColors.deepNavy,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.deepNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${member.displayEmployeeId} · ${member.role}',
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
              if (isMarked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (todayRecord.isApproved
                            ? AppColors.successGreen
                            : todayRecord.isRejected
                                ? AppColors.criticalRed
                                : AppColors.warningAmber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (todayRecord.isApproved
                              ? AppColors.successGreen
                              : todayRecord.isRejected
                                  ? AppColors.criticalRed
                                  : AppColors.warningAmber)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    todayRecord.isApproved
                        ? '• APPROVED'
                        : todayRecord.isRejected
                            ? '• REJECTED'
                            : '• PENDING APPROVAL',
                    style: TextStyle(
                      color: todayRecord.isApproved
                          ? AppColors.successGreen
                          : todayRecord.isRejected
                              ? AppColors.criticalRed
                              : AppColors.warningAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (isMarked) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attendance Marked Today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceDetailScreen(
                          attendance: todayRecord,
                          controller: widget.controller,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.deepNavy,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _openTeamMemberCapture(member),
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: Text(
                  'Mark Attendance for ${member.displayName.split(' ').first}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGreen),
                  foregroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
