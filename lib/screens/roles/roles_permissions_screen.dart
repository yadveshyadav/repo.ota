import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/permission_model.dart';
import '../../models/role_model.dart';
import '../../repositories/role_repository.dart';
import '../../services/authorization_service.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../widgets/dashboard/dashboard_header.dart';
import '../../widgets/dashboard/dashboard_sidebar.dart';
import 'widgets/create_edit_role_dialog.dart';

/// Enterprise Roles and Permissions Management Screen for HERO / VehicleIQ
class RolesPermissionsScreen extends StatefulWidget {
  final RoleRepository? repository;

  const RolesPermissionsScreen({
    super.key,
    this.repository,
  });

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen>
    with SingleTickerProviderStateMixin {
  late final RoleRepository _repository;
  late final TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  String? _errorMessage;

  List<RoleModel> _roles = [];
  List<PermissionModel> _permissions = [];

  String _roleSearchQuery = '';
  String _permissionSearchQuery = '';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiRoleRepository();
    _tabController = TabController(length: 2, vsync: this);
    _loadRolesAndPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRolesAndPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getRoles(),
        _repository.getPermissions(),
      ]);

      if (!mounted) return;

      setState(() {
        _roles = results[0] as List<RoleModel>;
        _permissions = results[1] as List<PermissionModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load roles and permissions: $e';
      });
    }
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
      // Already on Roles & Permissions Screen
    }else if (route == 'Refuel Records' || route == 'Refuel' || route == 'Fuel Logs') {
      Navigator.of(context).pushNamed(AppRoutes.refuel);
    } else if (route == 'Attendance') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.attendance);
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

  List<RoleModel> get _filteredRoles {
    if (_roleSearchQuery.trim().isEmpty) return _roles;
    final q = _roleSearchQuery.toLowerCase().trim();
    return _roles.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          (r.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<PermissionModel> get _filteredPermissions {
    return _permissions.where((p) {
      if (_selectedCategory != 'ALL' && p.category.toUpperCase() != _selectedCategory.toUpperCase()) {
        return false;
      }
      if (_permissionSearchQuery.trim().isNotEmpty) {
        final q = _permissionSearchQuery.toLowerCase().trim();
        return p.name.toLowerCase().contains(q) ||
            p.code.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<String> get _categories {
    final set = _permissions.map((p) => p.category.toUpperCase()).toSet().toList();
    set.sort();
    return ['ALL', ...set];
  }

  Future<void> _openCreateEditRoleDialog([RoleModel? role]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEditRoleDialog(
        existingRole: role,
        allPermissions: _permissions,
        repository: _repository,
      ),
    );

    if (result == true) {
      _loadRolesAndPermissions();
    }
  }

  Future<void> _deleteRole(RoleModel role) async {
    if (role.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System roles cannot be deleted.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Role'),
        content: Text('Are you sure you want to delete role "${role.name}"? Users assigned to this role will lose associated capabilities.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.criticalRed, foregroundColor: AppColors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteRole(role.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role "${role.name}" deleted successfully.')),
          );
        }
        _loadRolesAndPermissions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete role: $e'), backgroundColor: AppColors.criticalRed),
          );
        }
      }
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

    final canManageRoles = AuthorizationService.instance.can('roles.manage');

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
                selectedRoute: 'Roles & Permissions',
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
              selectedRoute: 'Roles & Permissions',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: _handleSidebarRouteSelected,
            ),
          Expanded(
            child: Column(
              children: [
                // Header & Tabs Bar
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(bottom: BorderSide(color: AppColors.borderGray)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreenBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Roles & Permissions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                Text(
                                  'Manage platform roles, access policies, and granular capabilities',
                                  style: AppTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (canManageRoles) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openCreateEditRoleDialog(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(isMobile ? 'Add' : 'Create Custom Role'),
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
                      const SizedBox(height: 16),

                      // Tabs Bar (Roles | Permissions)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: AppColors.primaryGreen,
                          unselectedLabelColor: AppColors.mutedTextGray,
                          indicatorColor: AppColors.primaryGreen,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          tabs: [
                            Tab(
                              child: Row(
                                children: [
                                  const Icon(Icons.security_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Roles (${_roles.length})'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                children: [
                                  const Icon(Icons.key_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Permissions (${_permissions.length})'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Tab Body View
                Expanded(
                  child: _isLoading
                      ? _buildSkeletonLoader()
                      : _errorMessage != null
                          ? _buildErrorView()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildRolesTab(isMobile, canManageRoles),
                                _buildPermissionsTab(isMobile),
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

  Widget _buildRolesTab(bool isMobile, bool canManageRoles) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Roles Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _roleSearchQuery = val;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search roles by name, code, or description...',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.mutedTextGray),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Roles List Grid
          if (_filteredRoles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No roles found matching your search.',
                  style: TextStyle(color: AppColors.mutedTextGray),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1100
                    ? 3
                    : constraints.maxWidth > 700
                        ? 2
                        : 1;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _filteredRoles.map((role) {
                    final itemWidth = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;
                    return SizedBox(
                      width: itemWidth,
                      child: _buildRoleCard(role, canManageRoles),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(RoleModel role, bool canManageRoles) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: role.isSystem
                      ? AppColors.primaryGreen.withValues(alpha: 0.12)
                      : AppColors.deepNavy.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  role.isSystem ? Icons.shield_rounded : Icons.person_outline_rounded,
                  color: role.isSystem ? AppColors.primaryGreen : AppColors.deepNavy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            role.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: role.isSystem
                                ? AppColors.successGreen.withValues(alpha: 0.15)
                                : AppColors.primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            role.isSystem ? 'SYSTEM ROLE' : 'CUSTOM ROLE',
                            style: TextStyle(
                              color: role.isSystem ? AppColors.successGreen : AppColors.primaryGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.code,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedTextGray,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Role Description
          Text(
            role.description?.isNotEmpty == true
                ? role.description!
                : 'No description specified for this role configuration.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedTextGray, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Role Stats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: AppColors.mutedTextGray),
                      const SizedBox(width: 6),
                      Text(
                        '${role.userCount} Users',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.deepNavy),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      Text(
                        '${role.permissionCodes.length} Perms',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderGray),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canManageRoles) ...[
                OutlinedButton.icon(
                  onPressed: () => _openCreateEditRoleDialog(role),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Permissions', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: const BorderSide(color: AppColors.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                if (!role.isSystem) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.criticalRed, size: 18),
                    onPressed: () => _deleteRole(role),
                    tooltip: 'Delete Role',
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _permissionSearchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search permissions by code, capability name, or description...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.mutedTextGray),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Category Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    icon: const Icon(Icons.filter_list_rounded, color: AppColors.primaryGreen, size: 18),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text('Category: $cat', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Permissions Table
          Container(
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
                headingRowColor: WidgetStateProperty.all(AppColors.backgroundGray),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Capability / Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Permission Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Assigned Roles', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _filteredPermissions.map((perm) {
                  final rolesUsingPermCount = _roles.where((r) => r.permissionCodes.contains(perm.code)).length;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primaryGreen),
                            const SizedBox(width: 8),
                            Text(perm.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGray,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: Text(
                            perm.code,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            perm.category,
                            style: const TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          perm.description.isNotEmpty ? perm.description : '-',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$rolesUsingPermCount Roles',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.criticalRed),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Error loading data', style: AppTextStyles.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRolesAndPermissions,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
