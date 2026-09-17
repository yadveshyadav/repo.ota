import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/services/auth_storage_service.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/authorization_service.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../widgets/dashboard/dashboard_header.dart';
import '../../../widgets/dashboard/dashboard_sidebar.dart';
import '../controller/team_controller.dart';
import '../widgets/team_filter_sheet.dart';
import '../widgets/team_member_card.dart';
import 'team_member_detail_screen.dart';

/// Main API-backed Team & Staff Management Screen for HERO / VehicleIQ
class TeamScreen extends StatefulWidget {
  final UserRepository? repository;
  final TeamController? controller;

  const TeamScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamController _controller;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TeamController(
          repository: widget.repository ?? ApiUserRepository(),
        );
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerChanged);
    _scrollController.addListener(_onScroll);
    _controller.fetchTeamMembers(page: 0);
  }

  void _onControllerChanged() {
    if (mounted) {
      if (_searchController.text != _controller.searchQuery) {
        _searchController.text = _controller.searchQuery;
      }
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      if (_controller.hasNext && !_controller.isLoadingMore) {
        _controller.loadNextPage();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _controller.removeListener(_onControllerChanged);
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
      // Already on Team Screen
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

  void _openFilterSheet() {
    TeamFilterSheet.show(
      context,
      initialFilter: _controller.filter,
      availableRoles: _controller.availableRoles,
      availableVendors: _controller.availableVendors,
      onApplyFilters: (newFilter) {
        _controller.applyFilter(newFilter);
      },
    );
  }

  void _navigateToDetail(UserModel member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamMemberDetailScreen(member: member),
      ),
    );
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

    // Verify team.view permission
    final canViewTeam = AuthorizationService.instance.can('team.view') || user?.isAdmin == true;

    if (!canViewTeam) {
      return Scaffold(
        appBar: DashboardHeader(
          isMobile: !isDesktop,
          userName: userName,
          userRole: userRole,
          userInitials: userInitials,
          onMenuPressed: () {},
          onSidebarToggle: () {},
        ),
        body: const Center(
          child: Text('Access Denied: You don\'t have permission to view the team.'),
        ),
      );
    }

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
                selectedRoute: 'Team',
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
              selectedRoute: 'Team',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: _handleSidebarRouteSelected,
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: () => _controller.fetchTeamMembers(page: 0),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PAGE HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.lightGreenBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.people_outline_rounded, color: AppColors.primaryGreen, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Team & Staff Management',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                ),
                                Text(
                                  'Manage users, staff, roles and vendor assignments',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: _controller.isRefreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                                )
                              : const Icon(Icons.refresh_rounded, color: AppColors.deepNavy),
                          onPressed: () => _controller.fetchTeamMembers(page: 0),
                          tooltip: 'Refresh Team Members',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SUMMARY CARDS ROW (Section 2 & 27)
                    _buildSummaryGrid(isMobile),
                    const SizedBox(height: 16),

                    // SEARCH BAR & FILTER BUTTON (Section 11 & 12)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => _controller.setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Search team members by name, ID, role, vendor...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedTextGray),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _controller.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderGray),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderGray),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openFilterSheet,
                              icon: const Icon(Icons.filter_list_rounded, size: 18),
                              label: Text(isMobile ? '' : 'Filter'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: 14,
                                ),
                                side: const BorderSide(color: AppColors.borderGray),
                                foregroundColor: AppColors.deepNavy,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            if (_controller.filter.hasActiveFilters)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.warningAmber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_controller.filter.activeFilterCount}',
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
                    ),
                    const SizedBox(height: 16),

                    // MAIN TEAM CONTENT AREA
                    if (_controller.isLoading)
                      _buildSkeletonList()
                    else if (_controller.errorMessage != null)
                      _buildErrorView()
                    else if (_controller.filteredMembers.isEmpty)
                      _buildEmptyView()
                    else ...[
                      if (!isMobile)
                        _buildTabletTableView()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.filteredMembers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final member = _controller.filteredMembers[index];
                            return TeamMemberCard(
                              member: member,
                              onViewDetails: () => _navigateToDetail(member),
                            );
                          },
                        ),

                      if (_controller.isLoadingMore) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
                              SizedBox(width: 10),
                              Text('Loading more team members...', style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryTile(
                      title: 'Total Staff',
                      value: '${_controller.totalCount}',
                      subtitle: 'API Metadata Total',
                      icon: Icons.people_alt_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryTile(
                      title: 'Loaded',
                      value: '${_controller.loadedCount}',
                      subtitle: 'Current Page List',
                      icon: Icons.download_done_rounded,
                      color: AppColors.infoBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryTile(
                      title: 'Active Staff',
                      value: '${_controller.loadedActiveCount}',
                      subtitle: 'In Loaded Batch',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryTile(
                      title: 'Mapped Vendors',
                      value: '${_controller.loadedVendorCount}',
                      subtitle: 'Distinct Firms',
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                title: 'Total Staff',
                value: '${_controller.totalCount}',
                subtitle: 'API Metadata Total',
                icon: Icons.people_alt_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryTile(
                title: 'Loaded Batch',
                value: '${_controller.loadedCount}',
                subtitle: 'Current Page List',
                icon: Icons.download_done_rounded,
                color: AppColors.infoBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryTile(
                title: 'Active Staff',
                value: '${_controller.loadedActiveCount}',
                subtitle: 'In Loaded Batch',
                icon: Icons.check_circle_rounded,
                color: AppColors.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryTile(
                title: 'Mapped Vendors',
                value: '${_controller.loadedVendorCount}',
                subtitle: 'Distinct Firms',
                icon: Icons.storefront_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletTableView() {
    final list = _controller.filteredMembers;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.softGray),
          columns: const [
            DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Assigned Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: list.map((m) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                        child: Text(m.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ),
                      const SizedBox(width: 8),
                      Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                    ],
                  ),
                ),
                DataCell(Text(m.username, style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text(m.displayEmployeeId, style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text(m.role)),
                DataCell(Text(m.displayVendor)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: m.isActive ? AppColors.successGreen.withValues(alpha: 0.12) : AppColors.criticalRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: m.isActive ? AppColors.successGreen : AppColors.criticalRed),
                    ),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _navigateToDetail(m),
                    child: const Text('Details', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 44, height: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 16),
                        SizedBox(height: 6),
                        SkeletonBox(width: 100, height: 12),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 70, height: 22),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SkeletonBox(width: double.infinity, height: 14)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(width: double.infinity, height: 14)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 52, color: AppColors.mutedTextGray),
            const SizedBox(height: 12),
            const Text('No matching team members', style: AppTextStyles.headingSmall),
            const SizedBox(height: 6),
            const Text(
              'Try changing your search query or clear active filters.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _controller.clearFilters(),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: AppColors.criticalRed),
            const SizedBox(height: 12),
            Text(
              _controller.errorMessage ?? 'Unable to load team members.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _controller.fetchTeamMembers(page: 0),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
