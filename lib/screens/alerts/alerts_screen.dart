import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/alerts/controller/alert_controller.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/alert.dart';
import 'package:hero_app/repositories/alert_repository.dart';
import 'package:hero_app/screens/alerts/alert_detail_screen.dart';
import 'package:hero_app/shared/widgets/hero_animated_item.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';

/// Main Enterprise Alerts Screen displaying real-time fleet alerts
class AlertsScreen extends StatefulWidget {
  final AlertRepository? repository;
  final AlertController? controller;

  const AlertsScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertController _controller;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        AlertController(
          repository: widget.repository ?? ApiAlertRepository(),
        );
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerStateChanged);
    _scrollController.addListener(_onScroll);
    _controller.fetchAlerts(page: 1);
    _controller.startAutoRefresh();
  }

  void _onControllerStateChanged() {
    if (mounted) {
      if (_searchController.text != _controller.searchQuery) {
        _searchController.text = _controller.searchQuery;
      }
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_controller.hasNext && !_controller.isLoadingMore) {
        _controller.loadNextPage();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      Navigator.of(context).pushReplacementNamed(AppRoutes.liveStatus);
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
    }else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
    } else if (route == 'Stock & Spares' || route == 'Stock' || route == 'Inventory') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.inventory);
    } else if (route == 'Alert Center' || route == 'Alerts' || route == 'Alert') {
      // Already on Alerts Screen
    } else if (route == 'Notifications') {
      Navigator.of(context).pushNamed(AppRoutes.notifications);
    }
  }

  void _navigateToDetail(Alert alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(
          alert: alert,
          controller: _controller,
        ),
      ),
    );
  }

  void _navigateToMachine(String chassisNo) {
    if (chassisNo.isNotEmpty && chassisNo != 'N/A') {
      Navigator.of(context).pushNamed(
        AppRoutes.machineDetail,
        arguments: chassisNo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = mediaWidth >= 1024;
    final isMobile = mediaWidth < 640;

    final user = AuthStorageService().currentUser;
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? 'User');
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
                selectedRoute: 'Alerts',
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
              selectedRoute: 'Alerts',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: _handleSidebarRouteSelected,
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: () => _controller.fetchAlerts(page: 1),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                physics: const AlwaysScrollableScrollPhysics(),
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
                                  color: AppColors.criticalRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: AppColors.criticalRed, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Fleet Alerts',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                        ),
                                        if (_controller.unreadCount > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.criticalRed,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${_controller.unreadCount} Unread',
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Text(
                                      'Real-time critical, warning, and telemetry alert notifications',
                                      style: AppTextStyles.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: _controller.isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                                )
                              : const Icon(Icons.sync_rounded, color: AppColors.primaryGreen),
                          onPressed: () => _controller.fetchAlerts(page: 1),
                          tooltip: 'Sync Alerts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${_controller.totalCount})', AppColors.deepNavy),
                          _buildFilterChip('CRITICAL', '🔴 Critical (${_controller.criticalCount})', AppColors.criticalRed),
                          _buildFilterChip('WARNING', '🟠 Warning (${_controller.warningCount})', AppColors.warningAmber),
                          _buildFilterChip('INFO', '🔵 Info (${_controller.infoCount})', AppColors.infoBlue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Field
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => _controller.setSearchQuery(val),
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search title, machine code, message, or vendor...',
                          hintStyle: const TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedTextGray, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _controller.setSearchQuery('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Content View
                    if (_controller.isLoading) ...[
                      _buildSkeletonList(),
                    ] else if (_controller.errorMessage != null) ...[
                      _buildErrorView(),
                    ] else if (_controller.alerts.isEmpty) ...[
                      _buildEmptyView(),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _controller.alerts.length + (_controller.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == _controller.alerts.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                                ),
                              ),
                            );
                          }
                          final alert = _controller.alerts[index];
                          return HeroAnimatedItem(
                            index: index,
                            child: _buildAlertCard(alert),
                          );
                        },
                      ),
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

  Widget _buildFilterChip(String severityKey, String label, Color chipColor) {
    final isSelected = _controller.selectedSeverity == severityKey;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => _controller.setSeverityFilter(severityKey),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? chipColor : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : AppColors.borderGray,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.white : AppColors.deepNavy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    Color severityColor;
    IconData severityIcon;

    if (alert.isCritical) {
      severityColor = AppColors.criticalRed;
      severityIcon = Icons.error_outline_rounded;
    } else if (alert.isWarning) {
      severityColor = AppColors.warningAmber;
      severityIcon = Icons.warning_amber_rounded;
    } else {
      severityColor = AppColors.infoBlue;
      severityIcon = Icons.info_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: alert.isRead ? AppColors.white : severityColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isRead ? AppColors.borderGray : severityColor.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(alert),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Severity badge, Machine code, Read indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(severityIcon, color: severityColor, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alert.displaySeverity,
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (alert.chassisNumber != 'N/A') ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _navigateToMachine(alert.chassisNumber),
                          child: Text(
                            alert.chassisNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    alert.relativeTime,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title & Message Body
              Text(
                alert.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: alert.isRead ? FontWeight.bold : FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 12, color: AppColors.deepNavy, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Vendor Footer & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    alert.vendorName ?? 'Fleet Partner',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.mutedTextGray),
                  ),
                  Row(
                    children: [
                      if (!alert.isRead) ...[
                        TextButton.icon(
                          onPressed: () => _controller.markAsRead(alert.id),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                          label: const Text('Mark Read', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mutedTextGray),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 80, height: 18, color: AppColors.softGray),
                Container(width: 50, height: 14, color: AppColors.softGray),
              ],
            ),
            const SizedBox(height: 10),
            Container(width: 200, height: 16, color: AppColors.softGray),
            const SizedBox(height: 6),
            Container(width: double.infinity, height: 12, color: AppColors.softGray),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.criticalRed),
          const SizedBox(height: 12),
          const Text('Unable to load alerts', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          Text(
            _controller.errorMessage ?? 'Please check connection and retry.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _controller.fetchAlerts(page: 1),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.softGray,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 44, color: AppColors.mutedTextGray),
          ),
          const SizedBox(height: 16),
          const Text('No Alerts Found', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          const Text(
            'All fleet machines operating within normal parameters for the selected filters.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
