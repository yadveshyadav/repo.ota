import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/role_model.dart';
import '../../models/user_response.dart';
import '../../repositories/role_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/authorization_service.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../widgets/dashboard/dashboard_header.dart';
import '../../widgets/dashboard/dashboard_sidebar.dart';
import 'widgets/create_edit_user_dialog.dart';
import 'widgets/user_profile_dialog.dart';

/// Enterprise Platform Users Management Screen for HERO / VehicleIQ
class UsersScreen extends StatefulWidget {
  final UserRepository? userRepository;
  final RoleRepository? roleRepository;

  const UsersScreen({
    super.key,
    this.userRepository,
    this.roleRepository,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UserRepository _userRepository;
  late final RoleRepository _roleRepository;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  String? _errorMessage;

  List<UserModel> _users = [];
  List<RoleModel> _availableRoles = [];

  // Pagination State (20 Users Per Page)
  int _currentPage = 0;
  int _pageSize = 20;
  int _totalUsersCount = 0;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _userRepository = widget.userRepository ?? ApiUserRepository();
    _roleRepository = widget.roleRepository ?? ApiRoleRepository();
    _loadUsersData(page: 0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsersData({int page = 0}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _userRepository.getUsersResponse(
          page: page,
          size: _pageSize,
          search: _searchQuery,
        ),
        if (_availableRoles.isEmpty)
          _roleRepository.getRoles()
        else
          Future.value(_availableRoles),
      ]);

      if (!mounted) return;

      final userResponse = results[0] as UserResponse;
      final roles = results[1] as List<RoleModel>;

      setState(() {
        _users = userResponse.users;
        _totalUsersCount = userResponse.totalCount;
        _totalPages = userResponse.totalPages;
        _currentPage = userResponse.currentPage;
        _pageSize = userResponse.pageSize;
        _hasNextPage = userResponse.hasNext;
        _hasPreviousPage = userResponse.hasPrevious;
        _availableRoles = roles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load users list: $e';
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchQuery != query) {
        _searchQuery = query;
        _currentPage = 0;
        _loadUsersData(page: 0);
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
      // Already on Users Screen
    } else if (route == 'Roles & Permissions' || route == 'Roles') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.roles);
    } else if (route == 'Attendance') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.attendance);
    } else if (route == 'Expenses') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.expenses);
    } else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
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

  List<UserModel> get _filteredUsers {
    return _users.where((user) {
      if (_statusFilter == 'ACTIVE' && !user.isActive) return false;
      if (_statusFilter == 'INACTIVE' && user.isActive) return false;
      return true;
    }).toList();
  }

  void _openUserProfileModal(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => UserProfileDialog(
        user: user,
        onEditPressed: () => _openCreateEditUserDialog(user),
      ),
    );
  }

  Future<void> _openCreateEditUserDialog([UserModel? user]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEditUserDialog(
        existingUser: user,
        availableRoles: _availableRoles,
        repository: _userRepository,
      ),
    );

    if (result == true) {
      _loadUsersData(page: _currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isDesktop = mediaWidth >= 1024;
    final isMobile = mediaWidth < 640;

    final currentUser = AuthStorageService().currentUser;
    final userName = currentUser?.displayName.isNotEmpty == true ? currentUser!.displayName : (currentUser?.username.isNotEmpty == true ? currentUser!.username : 'User');
    final userRole = currentUser?.role.isNotEmpty == true ? currentUser!.role : 'ADMIN';
    final userInitials = currentUser?.initials ?? 'U';

    final canManageUsers = AuthorizationService.instance.can('users.manage');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      appBar: DashboardHeader(
        isMobile: !isDesktop,
        isSidebarCollapsed: _isSidebarCollapsed,
        isRefreshing: _isLoading,
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
                selectedRoute: 'Users',
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
              selectedRoute: 'Users',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: _handleSidebarRouteSelected,
            ),
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(bottom: BorderSide(color: AppColors.borderGray)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'User Management',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                if (_totalUsersCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_totalUsersCount Total',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Text(
                              'Manage platform users, contact credentials, and assigned roles',
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (canManageUsers) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _openCreateEditUserDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(isMobile ? 'Add' : 'Add New User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Search & Filter Toolbar
                Container(
                  color: AppColors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: 12,
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundGray,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderGray),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Search users by name, username, email...',
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedTextGray, size: 20),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderGray),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatusFilterPill('ALL', 'All Users'),
                                    _buildStatusFilterPill('ACTIVE', 'Active'),
                                    _buildStatusFilterPill('INACTIVE', 'Inactive'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderGray),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                    hintText: 'Search users by name, username, email, or role...',
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedTextGray, size: 20),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchChanged('');
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Status Filter Pills
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundGray,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderGray),
                              ),
                              child: Row(
                                children: [
                                  _buildStatusFilterPill('ALL', 'All Users'),
                                  _buildStatusFilterPill('ACTIVE', 'Active'),
                                  _buildStatusFilterPill('INACTIVE', 'Inactive'),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                // Main Content Body
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonLoader()
                      : _errorMessage != null
                          ? _buildErrorView()
                          : _filteredUsers.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      'No users found matching your filters.',
                                      style: TextStyle(color: AppColors.mutedTextGray),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.all(isMobile ? 12 : 20),
                                        child: isMobile
                                            ? _buildMobileUserCardsList(canManageUsers)
                                            : _buildDesktopUserTable(canManageUsers),
                                      ),
                                    ),

                                    // Pagination Footer Control
                                    _buildPaginationBar(),
                                  ],
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Responsive Desktop Data Table with Clickable Rows
  Widget _buildDesktopUserTable(bool canManageUsers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(AppColors.backgroundGray),
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Username / Email', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Assigned Role(s)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredUsers.map((user) {
              final initials = user.displayName
                  .split(' ')
                  .where((e) => e.isNotEmpty)
                  .map((e) => e[0])
                  .take(2)
                  .join('')
                  .toUpperCase();

              return DataRow(
                onSelectChanged: (_) => _openUserProfileModal(user),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                          child: Text(
                            initials.isNotEmpty ? initials : 'U',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.deepNavy),
                            ),
                            if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                              Text(
                                user.phoneNumber!,
                                style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(user.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text(user.email, style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray)),
                      ],
                    ),
                  ),
                  DataCell(
                    Wrap(
                      spacing: 6,
                      children: user.roles.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? AppColors.successGreen.withValues(alpha: 0.15)
                            : AppColors.mutedTextGray.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        user.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: user.isActive ? AppColors.successGreen : AppColors.mutedTextGray,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: AppColors.deepNavy, size: 18),
                          onPressed: () => _openUserProfileModal(user),
                          tooltip: 'View Profile',
                        ),
                        if (canManageUsers)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen, size: 18),
                            onPressed: () => _openCreateEditUserDialog(user),
                            tooltip: 'Edit User Roles',
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Mobile & Compact User Cards List with Clear Layout & Click to Profile
  Widget _buildMobileUserCardsList(bool canManageUsers) {
    return Column(
      children: _filteredUsers.map((user) {
        final initials = user.displayName
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join('')
            .toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: InkWell(
            onTap: () => _openUserProfileModal(user),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          initials.isNotEmpty ? initials : 'U',
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                              Text(
                                user.phoneNumber!,
                                style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? AppColors.successGreen.withValues(alpha: 0.15)
                              : AppColors.mutedTextGray.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          user.isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: user.isActive ? AppColors.successGreen : AppColors.mutedTextGray,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Username / Email', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                          Text(user.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.mutedTextGray),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    children: user.roles.map((r) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Pagination Footer Bar (20 Users Per Page)
  Widget _buildPaginationBar() {
    final startItem = _totalUsersCount == 0 ? 0 : (_currentPage * _pageSize) + 1;
    final endItem = min((_currentPage + 1) * _pageSize, _totalUsersCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem - $endItem of $_totalUsersCount Users (Page ${_currentPage + 1} of $_totalPages)',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _hasPreviousPage && !_isLoading
                    ? () => _loadUsersData(page: _currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: AppColors.borderGray),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _hasNextPage && !_isLoading
                    ? () => _loadUsersData(page: _currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterPill(String code, String label) {
    final isSelected = _statusFilter == code;

    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = code;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryGreen : AppColors.mutedTextGray,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: const [
          SkeletonBox(width: double.infinity, height: 48),
          SizedBox(height: 16),
          Expanded(child: SkeletonBox(width: double.infinity, height: double.infinity)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    String cleanMsg = _errorMessage ?? 'Error loading users';
    cleanMsg = cleanMsg.replaceAll('Failed to load users list:', '').replaceAll('Exception:', '').replaceAll('Network error:', '').trim();
    if (cleanMsg.isEmpty) cleanMsg = 'Unable to connect to backend server';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.criticalRed),
            const SizedBox(height: 16),
            Text(
              cleanMsg,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your network connection or backend server status and try again.',
              style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadUsersData(page: _currentPage),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
