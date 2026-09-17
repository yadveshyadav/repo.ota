import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/features/live_status/controller/live_status_controller.dart';
import 'package:hero_app/features/live_status/widgets/live_machine_card.dart';
import 'package:hero_app/features/live_status/widgets/live_status_filter_bar.dart';
import 'package:hero_app/features/live_status/widgets/live_status_header_stats.dart';
import 'package:hero_app/features/live_status/widgets/machine_card_skeleton.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';

/// Main Enterprise Live Status Screen for real-time fleet telemetry monitoring
class LiveStatusScreen extends StatefulWidget {
  final MachineRepository? repository;
  final LiveStatusController? controller;

  const LiveStatusScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  late final LiveStatusController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        LiveStatusController(
          repository: widget.repository ?? ApiMachineRepository(),
        );
    _controller.addListener(_onControllerStateChanged);
    _controller.fetchMachines();
    _controller.startAutoRefresh();
  }

  void _onControllerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.stopAutoRefresh();
    _controller.removeListener(_onControllerStateChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
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
      // Already on Live Status screen
    } else if (route == 'My Tasks' || route == 'Tasks') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.tasks);
    } else if (route == 'Team') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.team);
    } else if (route == 'Vendors' || route == 'Partners') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.vendors);
    } else if (route == 'Users') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.users);
    } else if (route == 'Roles & Permissions' || route == 'Roles') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.roles);
    } else if (route == 'Attendance') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.attendance);
    } else if (route == 'Expenses') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.expenses);
    } else if (route == 'Stock & Spares' || route == 'Stock' || route == 'Inventory') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.inventory);
    } else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      appBar: DashboardHeader(
        isMobile: !isDesktop,
        isSidebarCollapsed: _isSidebarCollapsed,
        userName: userName,
        userRole: userRole,
        userInitials: userInitials,
        onMenuPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        onSidebarToggle: _toggleSidebar,
      ),
      drawer: !isDesktop
          ? Drawer(
              width: 280,
              child: DashboardSidebar(
                selectedRoute: 'Live Status',
                onRouteSelected: (route) {
                  Navigator.pop(context);
                  _handleSidebarRouteSelected(route);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          // Desktop Navigation Sidebar
          if (isDesktop)
            DashboardSidebar(
              selectedRoute: 'Live Status',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: (route) {
                _handleSidebarRouteSelected(route);
              },
            ),

          // Main View Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _controller.fetchMachines(),
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Live Status Header with Fleet Statistics Counters
                    LiveStatusHeaderStats(
                      totalMachines: _controller.totalCount,
                      liveMachines: _controller.liveCount,
                      offlineMachines: _controller.offlineCount,
                      onRefresh: () => _controller.fetchMachines(),
                      isRefreshing: _controller.isRefreshing,
                      onFilterSelected: (f) => _controller.setFilter(f),
                    ),

                    const SizedBox(height: 16),

                    // 2. Search Field & Status Filter Chips Bar
                    LiveStatusFilterBar(
                      searchQuery: _controller.searchQuery,
                      selectedFilter: _controller.selectedFilter,
                      onSearchChanged: (q) => _controller.setSearchQuery(q),
                      onFilterSelected: (f) => _controller.setFilter(f),
                    ),

                    const SizedBox(height: 20),

                    // 3. Grid Content / Loading / Error / Empty States
                    if (_controller.isLoading) ...[
                      _buildSkeletonGrid(),
                    ] else if (_controller.errorMessage != null) ...[
                      _buildErrorView(),
                    ] else if (_controller.machines.isEmpty) ...[
                      _buildEmptyView(),
                    ] else ...[
                      _buildMachineGrid(),
                    ],

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

  /// Responsive Machine Grid built using LayoutBuilder
  Widget _buildMachineGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;

        if (width >= 1200) {
          crossAxisCount = 5;
        } else if (width >= 850) {
          crossAxisCount = 3;
        } else if (width >= 550) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 295,
          ),
          itemCount: _controller.machines.length,
          itemBuilder: (context, index) {
            final machine = _controller.machines[index];
            return LiveMachineCard(
              key: ValueKey(machine.chassisNumber),
              machine: machine,
            );
          },
        );
      },
    );
  }

  /// Responsive Grid Skeleton Loading View
  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = width >= 1200
            ? 5
            : width >= 850
                ? 3
                : width >= 550
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 295,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (context, index) => const MachineCardSkeleton(),
        );
      },
    );
  }

  /// Error State View with Retry button
  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.criticalRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.criticalRed,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load machine data',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _controller.errorMessage ?? 'Please check connection and retry.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _controller.fetchMachines(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty State View handling zero fleet or no filter/search match
  Widget _buildEmptyView() {
    final isFiltered = _controller.searchQuery.isNotEmpty ||
        _controller.selectedFilter != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.softGray,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.mutedTextGray,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No machines match your filter' : 'No machines found',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try adjusting search term or status filter settings.'
                : 'No machine telemetry records registered in the fleet.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _controller.setSearchQuery('');
                _controller.setFilter('All');
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
