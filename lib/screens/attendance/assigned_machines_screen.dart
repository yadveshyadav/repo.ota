import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/screens/attendance/attendance_capture_screen.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';
import 'package:hero_app/screens/breakdown/close_open_issues_screen.dart';
import 'package:hero_app/screens/breakdown/machine_issue_screens.dart';
import 'package:hero_app/services/api/breakdown_api_service.dart';

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

class _AssignedMachinesScreenState extends State<AssignedMachinesScreen>
    with SingleTickerProviderStateMixin {
  final _breakdownApi = BreakdownApiService();
  Map<String, MachineOpenIssuesBucket> _openByChassis = {};
  bool _loadingIssues = false;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.fetchAssignedMachines();
      widget.controller.fetchHistory();
      await _loadOpenIssues();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await widget.controller.fetchAssignedMachines();
    widget.controller.fetchHistory();
    await _loadOpenIssues();
  }

  Future<void> _loadOpenIssues() async {
    final machines = widget.controller.assignedMachines;
    if (machines.isEmpty) {
      if (mounted) setState(() => _openByChassis = {});
      return;
    }

    setState(() => _loadingIssues = true);
    try {
      final chassisList = machines
          .map((m) => m.chassisNumber)
          .where((c) => c.isNotEmpty && c != 'N/A')
          .toSet()
          .toList();
      final result = await _breakdownApi.fetchOpenIssues(chassisList: chassisList);
      if (!mounted) return;
      setState(() {
        _openByChassis = Map<String, MachineOpenIssuesBucket>.from(result.byChassis);
        // also index results
        for (final row in result.results) {
          if (row.machineChassisNo.isNotEmpty) {
            _openByChassis[row.machineChassisNo] = row;
          }
        }
        _loadingIssues = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingIssues = false);
    }
  }

  MachineOpenIssuesBucket? _issuesFor(Machine machine) {
    final chassisList = [
      machine.chassisNumber,
      machine.machineChassisNo,
      if (machine.serialNumber != null) machine.serialNumber!,
      if (machine.id.isNotEmpty) machine.id,
    ].where((c) => c.isNotEmpty && c != 'N/A').toSet();

    for (final c in chassisList) {
      if (_openByChassis.containsKey(c)) return _openByChassis[c];
      final lower = c.toLowerCase().trim();
      for (final entry in _openByChassis.entries) {
        final keyLower = entry.key.toLowerCase().trim();
        if (keyLower == lower ||
            (keyLower.isNotEmpty && (keyLower.contains(lower) || lower.contains(keyLower)))) {
          return entry.value;
        }
      }
    }
    return null;
  }

  Future<void> _openMachineCapture(Machine machine) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceCaptureScreen(
          controller: widget.controller,
          isCheckOut: false,
          selectedMachine: machine,
        ),
      ),
    );
    if (!mounted) return;
    _refreshAll();
  }

  /// 1) Fetch open OEM/Ops → close & verify if any
  /// 2) Then Working / Not Working normal flow
  Future<void> _onMarkAttendancePressed(Machine machine) async {
    // Show brief loading while refreshing open issues for this chassis
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    MachineOpenIssuesBucket? bucket;
    try {
      final result = await _breakdownApi.fetchOpenIssues(
        machineChassisNo: machine.chassisNumber,
      );
      bucket = result.forChassis(machine.chassisNumber);
      if (mounted) {
        setState(() {
          if (bucket != null) {
            _openByChassis[machine.chassisNumber] = bucket;
          } else {
            _openByChassis.remove(machine.chassisNumber);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AssignedMachinesScreen] fetchOpenIssues non-blocking error ($e)');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // loading

    if (bucket != null && bucket.hasOpenIssue) {
      final openBucket = bucket;
      final cleared = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CloseOpenIssuesScreen(
            machine: machine,
            initialBucket: openBucket,
          ),
        ),
      );
      await _loadOpenIssues();
      if (!mounted || cleared != true) return;

      // Re-check once more before continuing
      try {
        final again = await _breakdownApi.fetchOpenIssues(
          machineChassisNo: machine.chassisNumber,
        );
        final stillOpen = again.forChassis(machine.chassisNumber);
        if (stillOpen != null && stillOpen.hasOpenIssue) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Close all open issues before marking attendance.'),
              backgroundColor: AppColors.criticalRed,
            ),
          );
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    await _askWorkingGate(machine);
  }

  Future<void> _askWorkingGate(Machine machine) async {
    final working = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  machine.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Is this machine working?',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedTextGray),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: const Text('Working', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.report_problem_outlined, size: 20),
                    label: const Text('Not Working', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.criticalRed,
                      side: const BorderSide(color: AppColors.criticalRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || working == null) return;

    if (working) {
      _openMachineCapture(machine);
      return;
    }

    await _openIssueTypeGate(machine);
  }

  Future<void> _openIssueTypeGate(Machine machine) async {
    final isExternal = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text(
                  'What kind of issue?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  machine.displayName,
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.build_circle_outlined, size: 20),
                    label: const Text('External (OEM Breakdown)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.handyman_outlined, size: 20),
                    label: const Text('Internal (Ops Stop)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepNavy,
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || isExternal == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isExternal
            ? ReportOemBreakdownScreen(machine: machine)
            : OpenOpsStopScreen(machine: machine),
      ),
    );
    await _loadOpenIssues();
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
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              if (_loadingIssues)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: _refreshAll,
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
    final openBucket = _issuesFor(machine);
    final hasOpenIssue = openBucket?.hasOpenIssue == true;
    final openCount = openBucket?.openCount ?? 0;
    final topIssue = (openBucket?.issues.isNotEmpty == true) ? openBucket!.issues.first : null;

    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        final borderColor = hasOpenIssue
            ? AppColors.criticalRed.withValues(alpha: 0.35 + (_blinkController.value * 0.55))
            : (isMarked ? AppColors.primaryGreen.withValues(alpha: 0.4) : AppColors.borderGray);
        final bgColor = hasOpenIssue
            ? Color.lerp(
                AppColors.white,
                AppColors.criticalRed.withValues(alpha: 0.10),
                _blinkController.value,
              )!
            : AppColors.white;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: hasOpenIssue ? 1.6 : 1),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Opacity(
            opacity: hasOpenIssue ? (0.92 + (_blinkController.value * 0.08)) : 1,
            child: child,
          ),
        );
      },
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
                        color: (hasOpenIssue
                                ? AppColors.criticalRed
                                : (isMarked ? AppColors.primaryGreen : AppColors.deepNavy))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.precision_manufacturing_rounded,
                        color: hasOpenIssue
                            ? AppColors.criticalRed
                            : (isMarked ? AppColors.primaryGreen : AppColors.deepNavy),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.deepNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Chassis: ${machine.chassisNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedTextGray,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasOpenIssue)
                FadeTransition(
                  opacity: _blinkController.drive(CurveTween(curve: Curves.easeInOut)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.criticalRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.criticalRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          openCount > 1 ? 'UNDER BREAKDOWN ($openCount)' : 'UNDER BREAKDOWN',
                          style: const TextStyle(
                            color: AppColors.criticalRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isMarked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (!todayRecord.isSynced
                            ? AppColors.infoBlue
                            : todayRecord.isApproved
                                ? AppColors.successGreen
                                : todayRecord.isRejected
                                    ? AppColors.criticalRed
                                    : AppColors.warningAmber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (!todayRecord.isSynced
                              ? AppColors.infoBlue
                              : todayRecord.isApproved
                                  ? AppColors.successGreen
                                  : todayRecord.isRejected
                                      ? AppColors.criticalRed
                                      : AppColors.warningAmber)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    !todayRecord.isSynced
                        ? '• OFFLINE (PENDING SYNC)'
                        : todayRecord.isApproved
                            ? '• APPROVED'
                            : todayRecord.isRejected
                                ? '• REJECTED'
                                : '• PENDING APPROVAL',
                    style: TextStyle(
                      color: !todayRecord.isSynced
                          ? AppColors.infoBlue
                          : todayRecord.isApproved
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

          if (hasOpenIssue && topIssue != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.criticalRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${topIssue.isOem ? 'OEM' : 'Ops'} ${topIssue.ttNumber ?? ''}'.trim(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.criticalRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topIssue.reason.isNotEmpty ? topIssue.reason : 'Open issue — close before attendance',
                    style: const TextStyle(fontSize: 12, color: AppColors.deepNavy, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 20, color: AppColors.borderGray),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(
                      machine.model,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Site Location', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                    const SizedBox(height: 2),
                    Text(
                      machine.site,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isMarked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openIssueTypeGate(machine),
                    icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.criticalRed),
                    label: const Text('Report Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.criticalRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.criticalRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                onPressed: () => _onMarkAttendancePressed(machine),
                icon: Icon(
                  hasOpenIssue ? Icons.warning_amber_rounded : Icons.fingerprint_rounded,
                  size: 18,
                ),
                label: Text(
                  hasOpenIssue ? 'Resolve issues & mark attendance' : 'Mark Machine Attendance',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasOpenIssue ? AppColors.criticalRed : AppColors.primaryGreen,
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
