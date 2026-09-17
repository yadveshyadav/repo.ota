import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/alert.dart';
import 'package:hero_app/models/dashboard_summary.dart';
import 'package:hero_app/repositories/attendance_repository.dart';
import 'package:hero_app/repositories/dashboard_repository.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/shared/widgets/skeleton_loader.dart';
import 'package:hero_app/widgets/dashboard/active_alerts_card.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';
import 'package:hero_app/widgets/dashboard/dashboard_tasks_card.dart';
import 'package:hero_app/widgets/dashboard/machine_and_fuel_status_card.dart';
import 'package:hero_app/widgets/dashboard/project_selector_card.dart';
import 'package:hero_app/widgets/dashboard/summary_card.dart';
import 'package:hero_app/screens/machines/machine_list_screen.dart';
import 'package:hero_app/screens/dashboard/controllers/machine_dashboard_controller.dart';
import 'package:hero_app/core/update/widgets/ota_update_dialogs.dart';

/// Main Enterprise Dashboard Screen matching Screen 1 reference design
class DashboardScreen extends StatefulWidget {
  final DashboardRepository? repository;
  final MachineRepository? machineRepository;

  const DashboardScreen({
    super.key,
    this.repository,
    this.machineRepository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository;
  late final MachineRepository _machineRepository;
  late final MachineDashboardController _machineController;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSidebarCollapsed = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  DashboardSummary? _summary;
  List<Alert>? _alerts;

  String _currentRoute = 'Dashboard';

  String get _formattedLastUpdated {
    if (_lastUpdated == null) return 'Updating...';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 10) return 'Updated just now';
    if (diff.inSeconds < 60) return 'Updated ${diff.inSeconds} sec ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    return 'Updated ${diff.inHours} hr ago';
  }

  late final AttendanceController _attendanceController;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiDashboardRepository();
    _machineRepository = widget.machineRepository ?? ApiMachineRepository();
    _machineController = MachineDashboardController(
      repository: _machineRepository,
    );
    _attendanceController = AttendanceController(repository: ApiAttendanceRepository());
    _machineController.addListener(_onMachineStateChanged);
    _loadDashboardData();
    _attendanceController.fetchTodayAttendance();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OtaUpdateDialogs.performAppUpdateCheck(context, isManualCheck: false);
      }
    });
  }

  void _onMachineStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _machineController.removeListener(_onMachineStateChanged);
    _machineController.dispose();
    _attendanceController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({String rpmFilter = 'Day'}) async {
    if (_summary == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    _machineController.refresh();

    try {
      // Step 1: Fetch summary first so top cards render immediately (< 100ms)
      final summary = await _repository.getSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
      }

      // Step 2: Fetch background alerts asynchronously
      _repository.getActiveAlerts().then((val) {
        if (mounted) setState(() => _alerts = val);
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_summary == null) {
          _errorMessage = 'Unable to refresh dashboard: $e';
        }
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _handleRouteSelected(String route) {
    if (route == 'Dashboard') {
      setState(() {
        _currentRoute = 'Dashboard';
      });
    } else if (route == 'Machines' || route == 'Total Machines') {
      _navigateToMachines('All');
    } else if (route == 'Online') {
      _navigateToMachines('Online');
    } else if (route == 'Offline') {
      _navigateToMachines('Offline');
    } else if (route == 'Maintenance') {
      _navigateToMachines('Maintenance');
    } else if (route == 'Live Tracking' || route == 'Live Status' || route == 'Map View') {
      Navigator.of(context).pushNamed(AppRoutes.liveStatus);
    } else if (route == 'My Tasks' || route == 'Tasks') {
      Navigator.of(context).pushNamed(AppRoutes.tasks);
    } else if (route == 'Team') {
      Navigator.of(context).pushNamed(AppRoutes.team);
    } else if (route == 'Vendors' || route == 'Partners') {
      Navigator.of(context).pushNamed(AppRoutes.vendors);
    } else if (route == 'Users') {
      Navigator.of(context).pushNamed(AppRoutes.users);
    } else if (route == 'Roles & Permissions' || route == 'Roles') {
      Navigator.of(context).pushNamed(AppRoutes.roles);
    } else if (route == 'Attendance') {
      Navigator.of(context).pushNamed(AppRoutes.attendance);
    } else if (route == 'Breakdown' || route == 'Breakdowns') {
      Navigator.of(context).pushNamed(AppRoutes.breakdowns);
    } else if (route == 'Expenses') {
      Navigator.of(context).pushNamed(AppRoutes.expenses);
    } else if (route == 'Stock & Spares' || route == 'Stock' || route == 'Inventory') {
      Navigator.of(context).pushNamed(AppRoutes.inventory);
    } else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
    } else if (route == 'Alert Center' || route == 'Alerts' || route == 'Alert') {
      Navigator.of(context).pushNamed(AppRoutes.alerts);
    } else if (route == 'Notifications') {
      Navigator.of(context).pushNamed(AppRoutes.notifications);
    } else if (route == 'Check for App Update' || route == 'Check for Updates' || route == 'Update') {
      OtaUpdateDialogs.performAppUpdateCheck(context, isManualCheck: true);
    } else {
      setState(() {
        _currentRoute = route;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$route module coming soon'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToMachines(String statusFilter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineListScreen(
          initialStatusFilter: statusFilter,
          repository: _machineRepository,
        ),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
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

    final totalMachinesCount = _machineController.state.totalMachines > 0
        ? _machineController.state.totalMachines
        : (_summary?.totalMachines ?? _machineController.state.machines.length);

    final onlineMachinesCount = _machineController.state.runningMachines > 0
        ? _machineController.state.runningMachines
        : (_summary?.onlineMachines ?? _machineController.state.machines.where((m) => m.isWorking).length);

    final offlineMachinesCount = (_machineController.state.offlineMachines > 0 || _machineController.state.idleMachines > 0)
        ? (_machineController.state.offlineMachines + _machineController.state.idleMachines)
        : (_summary?.offlineMachines ?? _machineController.state.machines.where((m) => m.isOffline || m.isIdle).length);

    final maintenanceMachinesCount = _machineController.state.maintenanceMachines > 0
        ? _machineController.state.maintenanceMachines
        : (_summary?.maintenanceMachines ?? _machineController.state.machines.where((m) => m.isMaintenance).length);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      appBar: DashboardHeader(
        isMobile: !isDesktop,
        isSidebarCollapsed: _isSidebarCollapsed,
        isRefreshing: _isRefreshing,
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
                selectedRoute: _currentRoute,
                totalMachines: totalMachinesCount,
                onlineMachines: onlineMachinesCount,
                offlineMachines: offlineMachinesCount,
                maintenanceMachines: maintenanceMachinesCount,
                onRouteSelected: (route) {
                  Navigator.pop(context);
                  _handleRouteSelected(route);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          // Persistent Sidebar on Desktop
          if (isDesktop)
            DashboardSidebar(
              selectedRoute: _currentRoute,
              isCollapsed: _isSidebarCollapsed,
              totalMachines: totalMachinesCount,
              onlineMachines: onlineMachinesCount,
              offlineMachines: offlineMachinesCount,
              maintenanceMachines: maintenanceMachinesCount,
              onRouteSelected: (route) {
                _handleRouteSelected(route);
              },
            ),

          // Main Content View
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoading(isMobile)
                : _errorMessage != null
                    ? _buildErrorView()
                    : RefreshIndicator(
                        onRefresh: _loadDashboardData,
                        color: AppColors.primaryGreen,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Current Project & Date Selector Bar
                              ProjectSelectorCard(
                                currentProject:
                                    _summary?.projectName ?? 'Sujangarh-SITE Project',
                                selectedDate:
                                    _summary?.currentDate ?? '05 Sep 2026',
                                lastUpdatedText: _formattedLastUpdated,
                              ),

                              const SizedBox(height: 16),

                              // 2. Single 4-Card Top Summary Row (Machines, Attendance, Breakdown, Alerts)
                              if (_summary != null)
                                SummaryCardsRow(
                                  summary: _summary!,
                                  machineState: _machineController.state,
                                  alertsCount: _alerts?.length,
                                  isMobile: isMobile,
                                  onCardTap: (filter) =>
                                      _handleRouteSelected(filter),
                                ),

                              const SizedBox(height: 16),

                              // 4. Machine Status & Fuel Status Cards
                              MachineAndFuelStatusRow(
                                onViewAllMachines: () =>
                                    _navigateToMachines('All'),
                                machineStatusWidget: _summary?.machineStatusWidget,
                                fuelStatusWidget: _summary?.fuelStatusWidget,
                              ),

                              const SizedBox(height: 16),

                              // 6. My Task (Today) Section
                              const MyTasksCard(),

                              const SizedBox(height: 16),

                              // 7. Active Alerts Card
                              if (_alerts != null)
                                ActiveAlertsCard(
                                  alerts: _alerts!,
                                  onViewAllPressed: () {
                                    Navigator.of(context).pushNamed(AppRoutes.alerts);
                                  },
                                ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: double.infinity, height: 50),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: SkeletonBox(width: double.infinity, height: 80)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 80)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 80)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 80)),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(child: SkeletonBox(width: double.infinity, height: double.infinity)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.criticalRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to load dashboard data',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
