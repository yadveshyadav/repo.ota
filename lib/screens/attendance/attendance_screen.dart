import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/repositories/attendance_repository.dart';
import 'package:hero_app/screens/attendance/attendance_approval_screen.dart';
import 'package:hero_app/screens/attendance/attendance_capture_screen.dart';
import 'package:hero_app/screens/attendance/attendance_detail_screen.dart';
import 'package:hero_app/screens/attendance/attendance_history_screen.dart';
import 'package:hero_app/screens/breakdown/close_open_issues_screen.dart';
import 'package:hero_app/screens/breakdown/machine_issue_screens.dart';
import 'package:hero_app/services/api/breakdown_api_service.dart';
import 'package:hero_app/services/authorization_service.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';

/// Single-Page Continuous Attendance Screen combining Machine & Team Attendance on 1 page
class AttendanceScreen extends StatefulWidget {
  final AttendanceRepository? repository;

  const AttendanceScreen({
    super.key,
    this.repository,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final AttendanceRepository _repository;
  late final AttendanceController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _blinkController;

  final _breakdownApi = BreakdownApiService();
  Map<String, MachineOpenIssuesBucket> _openByChassis = {};
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiAttendanceRepository();
    _controller = AttendanceController(repository: _repository);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _controller.fetchTodayAttendance();
      _controller.fetchHistory();
      await _controller.fetchAssignedMachines();
      await _controller.fetchAuthorizedTeamMembers();
      await _loadOpenIssues();
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    _controller.fetchTodayAttendance();
    _controller.fetchHistory();
    await _controller.fetchAssignedMachines();
    await _controller.fetchAuthorizedTeamMembers();
    await _loadOpenIssues();
  }

  Future<void> _loadOpenIssues() async {
    final machines = _controller.assignedMachines;
    if (machines.isEmpty) {
      if (mounted) setState(() => _openByChassis = {});
      return;
    }

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
        for (final row in result.results) {
          if (row.machineChassisNo.isNotEmpty) {
            _openByChassis[row.machineChassisNo] = row;
          }
        }
      });
    } catch (_) {}
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
          controller: _controller,
          isCheckOut: false,
          selectedMachine: machine,
        ),
      ),
    );
    if (!mounted) return;
    _refreshAll();
  }

  Future<void> _onMarkMachineAttendancePressed(Machine machine) async {
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
        print('[AttendanceScreen] fetchOpenIssues non-blocking error ($e)');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();

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
    }

    if (!mounted) return;
    final working = await _askWorkingGate(machine);
    if (working == true) {
      _openMachineCapture(machine);
    } else if (working == false) {
      _openIssueTypeGate(machine);
    }
  }

  Future<bool?> _askWorkingGate(Machine machine) async {
    return await showModalBottomSheet<bool>(
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                ),
                const SizedBox(height: 4),
                const Text('Is this machine working?', style: TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
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
                const Text('What kind of issue?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                const SizedBox(height: 4),
                Text(machine.displayName, style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
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

  List<Machine> _getUnmarkedAssignedMachines() {
    final assigned = _controller.assignedMachines;
    final unmarked = <Machine>[];
    for (final m in assigned) {
      final chassis = m.chassisNumber.trim();
      final record = _controller.getTodayAttendanceForMachine(chassis);
      if (record != null) continue;

      final bucket = _issuesFor(m);
      if (bucket?.hasOpenIssue == true || m.isMaintenance || m.isUnderBreakdown) continue;

      unmarked.add(m);
    }
    return unmarked;
  }

  Future<void> _openTeamMemberCapture(UserModel member) async {
    final unmarkedMachines = _getUnmarkedAssignedMachines();
    if (unmarkedMachines.isNotEmpty) {
      final machine = unmarkedMachines.first;

      final working = await _askWorkingGate(machine);
      if (working == null) return;

      if (working) {
        await _openMachineCapture(machine);
        if (_controller.getTodayAttendanceForMachine(machine.chassisNumber) == null) {
          return;
        }
      } else {
        await _openIssueTypeGate(machine);
        await _loadOpenIssues();
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceCaptureScreen(
          controller: _controller,
          isCheckOut: false,
          targetTeamMember: member,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _controller.fetchAuthorizedTeamMembers();
        _controller.fetchHistory();
        setState(() {});
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _handleSidebarRouteSelected(String route) {
    if (route == 'Dashboard') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else if (route == 'Total Machines' || route == 'Machines' || route == 'Online' || route == 'Offline' || route == 'Maintenance') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.machines);
    } else if (route == 'Machine Shifting' || route == 'Machine Transfers' || route == 'Transfers' || route == 'Shifting') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.machineTransfers);
    } else if (route == 'Live Tracking' || route == 'Live Status' || route == 'Map View') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.liveStatus);
    } else if (route == 'My Tasks' || route == 'Tasks') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.tasks);
    } else if (route == 'Team') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.team);
    } else if (route == 'Vendors' || route == 'Partners') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.vendors);
    } else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
    } else if (route == 'Users') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.users);
    } else if (route == 'Roles & Permissions' || route == 'Roles') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.roles);
    } else if (route == 'Attendance') {
      // Already on Attendance Screen
    } else if (route == 'Expenses') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.expenses);
    } else if (route == 'Stock & Spares' || route == 'Stock' || route == 'Inventory') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.inventory);
    } else if (route == 'Breakdown' || route == 'Breakdowns') {
      Navigator.of(context).pushNamed(AppRoutes.breakdowns);
    } else if (route == 'Alert Center' || route == 'Alerts' || route == 'Alert') {
      Navigator.of(context).pushNamed(AppRoutes.alerts);
    } else if (route == 'Notifications') {
      Navigator.of(context).pushNamed(AppRoutes.notifications);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$route module coming soon'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = mediaWidth >= 1024;
    final isMobile = mediaWidth < 640;

    final user = AuthStorageService().currentUser;
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username.isNotEmpty == true ? user!.username : 'User');
    final userRole = user?.role.isNotEmpty == true ? user!.role : 'ADMIN';
    final userInitials = user?.initials ?? 'U';

    final bool isNormalEmployee = user != null &&
        user.username.toLowerCase().startsWith('employee') &&
        !user.isAdmin;

    final bool canApprove = !isNormalEmployee || AuthorizationService.instance.can('attendance.approve');

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final pendingCount = _controller.history.where((r) => r.isPendingApproval || r.status == 'PENDING').length;
        final assignedMachines = _controller.assignedMachines;
        final teamMembers = _controller.teamMembers;

        final markedMachineCount = _controller.markedMachineCount;
        final markedMemberCount = _controller.markedMemberCount;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.backgroundGray,
          appBar: DashboardHeader(
            isMobile: !isDesktop,
            isSidebarCollapsed: _isSidebarCollapsed,
            userName: userName,
            userRole: userRole,
            userInitials: userInitials.isNotEmpty ? userInitials : 'AS',
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            onSidebarToggle: _toggleSidebar,
          ),
          drawer: !isDesktop
              ? Drawer(
                  width: 280,
                  child: DashboardSidebar(
                    selectedRoute: 'Attendance',
                    onRouteSelected: (route) {
                      Navigator.pop(context);
                      _handleSidebarRouteSelected(route);
                    },
                  ),
                )
              : null,
          body: Row(
            children: [
              if (isDesktop)
                DashboardSidebar(
                  selectedRoute: 'Attendance',
                  isCollapsed: _isSidebarCollapsed,
                  onRouteSelected: _handleSidebarRouteSelected,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightGreenBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryGreen, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Employee & Machine Attendance',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                      ),
                                      Text(
                                        'Daily Machine Attendance & Team Member Attendance on One Page',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (canApprove) ...[
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.verified_user_outlined, color: AppColors.primaryGreen),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => AttendanceApprovalScreen(controller: _controller),
                                          ),
                                        );
                                      },
                                      tooltip: 'Attendance Approval',
                                    ),
                                    if (pendingCount > 0)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.warningAmber,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$pendingCount',
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.history_rounded, color: AppColors.deepNavy),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceHistoryScreen(controller: _controller),
                                    ),
                                  );
                                },
                                tooltip: 'Attendance History',
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: AppColors.deepNavy),
                                onPressed: _refreshAll,
                                tooltip: 'Refresh Status',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 1: MACHINE ATTENDANCE
                      _buildSectionHeader(
                        icon: Icons.precision_manufacturing_rounded,
                        title: 'Machine Attendance',
                        countText: '${assignedMachines.length} Assigned Machines',
                        markedBadgeText: '$markedMachineCount Marked Today',
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 12),
                      _buildMachineAttendanceSection(assignedMachines),

                      const SizedBox(height: 28),

                      // SECTION 2: TEAM ATTENDANCE
                      _buildSectionHeader(
                        icon: Icons.groups_rounded,
                        title: 'Team Attendance',
                        countText: '${teamMembers.length} Authorized Members',
                        markedBadgeText: '$markedMemberCount Marked Today',
                        color: AppColors.infoBlue,
                      ),
                      const SizedBox(height: 12),
                      _buildTeamAttendanceSection(teamMembers),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String countText,
    required String markedBadgeText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                  ),
                  Text(
                    countText,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              markedBadgeText,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineAttendanceSection(List<Machine> assignedMachines) {
    if (_controller.isLoadingToday) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }

    if (assignedMachines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          children: const [
            Icon(Icons.precision_manufacturing_outlined, size: 40, color: AppColors.mutedTextGray),
            SizedBox(height: 10),
            Text('No Machine Assigned', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
            SizedBox(height: 4),
            Text('You do not have any active machine assignment.', style: TextStyle(color: AppColors.mutedTextGray, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignedMachines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final machine = assignedMachines[index];
        return _buildMachineTile(machine);
      },
    );
  }

  Widget _buildTeamAttendanceSection(List<UserModel> teamMembers) {
    if (_controller.isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }

    return Column(
      children: [
        if (teamMembers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: const [
                Icon(Icons.people_outline_rounded, size: 40, color: AppColors.mutedTextGray),
                SizedBox(height: 10),
                Text('No Authorized Team Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                SizedBox(height: 4),
                Text('You do not have any employees assigned under your team authority.', style: TextStyle(color: AppColors.mutedTextGray, fontSize: 12)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teamMembers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = teamMembers[index];
              return _buildTeamMemberTile(member);
            },
          ),
      ],
    );
  }

  Widget _buildMachineTile(Machine machine) {
    final todayRecord = _controller.getTodayAttendanceForMachine(machine.chassisNumber);
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
                          decoration: const BoxDecoration(color: AppColors.criticalRed, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          openCount > 1 ? 'UNDER BREAKDOWN ($openCount)' : 'UNDER BREAKDOWN',
                          style: const TextStyle(color: AppColors.criticalRed, fontSize: 10, fontWeight: FontWeight.bold),
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
                  child: const Text('• ASSIGNED', style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.criticalRed),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
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
                          controller: _controller,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.deepNavy),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _onMarkMachineAttendancePressed(machine),
                icon: Icon(hasOpenIssue ? Icons.warning_amber_rounded : Icons.fingerprint_rounded, size: 18),
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

  Widget _buildTeamMemberTile(UserModel member) {
    final todayRecord = _controller.getTodayAttendanceForUser(
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy),
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
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attendance Marked Today',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
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
                          controller: _controller,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.deepNavy),
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
