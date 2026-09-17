import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/screens/attendance/attendance_capture_screen.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';

/// Screen displaying ONLY machines currently assigned to the authenticated operator/user
class AssignedMachinesScreen extends StatefulWidget {
  final AttendanceController controller;

  const AssignedMachinesScreen({
    super.key,
    required this.controller,
  });

  @override
  State<AssignedMachinesScreen> createState() => _AssignedMachinesScreenState();
}

class _AssignedMachinesScreenState extends State<AssignedMachinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.fetchAssignedMachines();
      widget.controller.fetchHistory();
    });
  }

  void _openMachineCapture(Machine machine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceCaptureScreen(
          controller: widget.controller,
          isCheckOut: false,
          selectedMachine: machine,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final isLoading = widget.controller.isLoadingToday;
        final assignedMachines = widget.controller.assignedMachines;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'My Assigned Machines',
                  style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Select an assigned machine to mark attendance',
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
                  widget.controller.fetchAssignedMachines();
                  widget.controller.fetchHistory();
                },
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : assignedMachines.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: assignedMachines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final machine = assignedMachines[index];
                        return _buildMachineTile(machine);
                      },
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.precision_manufacturing_outlined, size: 52, color: AppColors.mutedTextGray),
            SizedBox(height: 16),
            Text(
              'No Machine Assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
            ),
            SizedBox(height: 6),
            Text(
              'You do not have any active machine assignment. Please contact your fleet admin if you should be assigned to a machine.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineTile(Machine machine) {
    final todayRecord = widget.controller.getTodayAttendanceForMachine(machine.chassisNumber);
    final bool isMarked = todayRecord != null;

    return Container(
      padding: const EdgeInsets.all(16),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isMarked ? AppColors.primaryGreen : AppColors.deepNavy).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.precision_manufacturing_rounded, color: isMarked ? AppColors.primaryGreen : AppColors.deepNavy, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.deepNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Chassis: ${machine.chassisNumber}',
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray, fontFamily: 'monospace'),
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
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '• ASSIGNED',
                    style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(machine.model, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Site Location', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(machine.site, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
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
                            'Machine Attendance Marked Today',
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
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _openMachineCapture(machine),
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text('Mark Machine Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
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
