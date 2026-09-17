import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/repositories/attendance_repository.dart';
import 'package:hero_app/screens/attendance/assigned_machines_screen.dart';
import 'package:hero_app/screens/attendance/attendance_approval_screen.dart';
import 'package:hero_app/screens/attendance/attendance_history_screen.dart';
import 'package:hero_app/screens/attendance/team_attendance_screen.dart';
import 'package:hero_app/services/authorization_service.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';

/// Main Enterprise Attendance Screen & Hub for HERO / VehicleIQ
class AttendanceScreen extends StatefulWidget {
  final AttendanceRepository? repository;

  const AttendanceScreen({
    super.key,
    this.repository,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceRepository _repository;
  late final AttendanceController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiAttendanceRepository();
    _controller = AttendanceController(repository: _repository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fetchTodayAttendance();
      _controller.fetchHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _handleSidebarRouteSelected(String route) {
    if (route == 'Dashboard') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else if (route == 'Total Machines' ||
        route == 'Machines' ||
        route == 'Online' ||
        route == 'Offline' ||
        route == 'Maintenance') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.machines);
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
                      // Page Header
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
                                        'Daily GPS-verified attendance check-in, machine attendance, and approvals',
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
                                icon: const Icon(Icons.refresh_rounded, color: AppColors.deepNavy),
                                onPressed: () {
                                  _controller.fetchTodayAttendance();
                                  _controller.fetchHistory();
                                },
                                tooltip: 'Refresh Status',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Business Section Cards: Machine Attendance vs Team Attendance
                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionHubTile(
                              icon: Icons.precision_manufacturing_rounded,
                              title: 'Machine Attendance',
                              subtitle: 'Mark attendance for your assigned machine',
                              badge: '',
                              color: AppColors.primaryGreen,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AssignedMachinesScreen(controller: _controller),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSectionHubTile(
                              icon: Icons.groups_rounded,
                              title: 'Team Attendance',
                              subtitle: 'Manage self & authorized team attendance',
                              badge: canApprove ? '' : 'Employee',
                              color: AppColors.infoBlue,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeamAttendanceScreen(controller: _controller),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Quick Action Links Stack
                      Column(
                        children: [
                          if (canApprove) ...[
                            _buildActionTile(
                              icon: Icons.verified_user_outlined,
                              title: 'Attendance Approval',
                              subtitle: 'Review team member attendance submissions',
                              badge: pendingCount > 0 ? '$pendingCount Pending' : 'Admin',
                              badgeColor: pendingCount > 0 ? AppColors.warningAmber : AppColors.primaryGreen,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceApprovalScreen(controller: _controller),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildActionTile(
                            icon: Icons.history_rounded,
                            title: 'Attendance History',
                            subtitle: 'View your past check-in & check-out logs',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AttendanceHistoryScreen(controller: _controller),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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

  Widget _buildSectionHubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.warningAmber).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? AppColors.warningAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedTextGray),
          ],
        ),
      ),
    );
  }
}
