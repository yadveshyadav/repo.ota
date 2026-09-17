import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/update/widgets/ota_update_dialogs.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../services/authorization_service.dart';

/// Navigation Sidebar driven completely by central Authorization Permissions & RBAC
class DashboardSidebar extends StatefulWidget {
  final String selectedRoute;
  final ValueChanged<String>? onRouteSelected;
  final bool isCollapsed;
  final int totalMachines;
  final int onlineMachines;
  final int offlineMachines;
  final int maintenanceMachines;

  const DashboardSidebar({
    super.key,
    this.selectedRoute = 'Dashboard',
    this.onRouteSelected,
    this.isCollapsed = false,
    this.totalMachines = 25,
    this.onlineMachines = 5,
    this.offlineMachines = 17,
    this.maintenanceMachines = 3,
  });

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  late String _activeItem;
  bool _machinesExpanded = true;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.selectedRoute;
  }

  void _selectItem(String item) {
    setState(() {
      _activeItem = item;
    });
    if (widget.onRouteSelected != null) {
      widget.onRouteSelected!(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double targetWidth = widget.isCollapsed ? 72.0 : 280.0;
    final user = AuthStorageService().currentUser;

    return ListenableBuilder(
      listenable: AuthorizationService.instance,
      builder: (context, child) {
        final auth = AuthorizationService.instance;

        // Build Navigation Structure
        final sections = _buildNavigationSections(auth);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: targetWidth,
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              right: BorderSide(color: AppColors.borderGray, width: 1),
            ),
          ),
          child: SafeArea(
            top: true,
            bottom: true,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    children: [
                      for (final section in sections) ...[
                        // Section Header (Omitted if section is empty)
                        if (!widget.isCollapsed && section.visibleItems.isNotEmpty)
                          _buildGroupHeader(section.title),

                        for (final item in section.visibleItems) ...[
                          if (item.title == 'Machines') ...[
                            if (widget.isCollapsed)
                              _SidebarTile(
                                icon: item.icon,
                                title: item.title,
                                isSelected: _activeItem == 'Total Machines' ||
                                    _activeItem == 'Machines' ||
                                    _activeItem == 'Online' ||
                                    _activeItem == 'Offline' ||
                                    _activeItem == 'Maintenance',
                                isCollapsed: true,
                                badge: '${widget.totalMachines}',
                                onTap: () => _selectItem('Total Machines'),
                              )
                            else
                              _ExpandableSidebarTile(
                                icon: item.icon,
                                title: item.title,
                                isExpanded: _machinesExpanded,
                                onToggle: () {
                                  setState(() {
                                    _machinesExpanded = !_machinesExpanded;
                                  });
                                },
                                children: [
                                  _SidebarSubTile(
                                    title: 'Total Machines',
                                    count: '${widget.totalMachines}',
                                    isSelected: _activeItem == 'Total Machines' || _activeItem == 'Machines',
                                    onTap: () => _selectItem('Total Machines'),
                                  ),
                                  _SidebarSubTile(
                                    title: 'Online',
                                    count: '${widget.onlineMachines}',
                                    badgeColor: AppColors.successGreen,
                                    isSelected: _activeItem == 'Online',
                                    onTap: () => _selectItem('Online'),
                                  ),
                                  _SidebarSubTile(
                                    title: 'Offline',
                                    count: '${widget.offlineMachines}',
                                    badgeColor: AppColors.mutedTextGray,
                                    isSelected: _activeItem == 'Offline',
                                    onTap: () => _selectItem('Offline'),
                                  ),
                                  _SidebarSubTile(
                                    title: 'Maintenance',
                                    count: '${widget.maintenanceMachines}',
                                    badgeColor: AppColors.warningAmber,
                                    isSelected: _activeItem == 'Maintenance',
                                    onTap: () => _selectItem('Maintenance'),
                                  ),
                                ],
                              ),
                          ] else ...[
                            _SidebarTile(
                              icon: item.icon,
                              title: item.title,
                              isSelected: _activeItem == item.title ||
                                  (item.title == 'Live Tracking' && _activeItem == 'Live Status') ||
                                  (item.title == 'My Tasks' && _activeItem == 'Tasks') ||
                                  (item.title == 'Refuel Records' && _activeItem == 'Refuel') ||
                                  (item.title == 'Reports' && _activeItem == 'Report Center') ||
                                  (item.title == 'Alert Center' && _activeItem == 'Alerts') ||
                                  (item.title == 'Vendors' && (_activeItem == 'Partners' || _activeItem == 'Vendors & Partners')),
                              isCollapsed: widget.isCollapsed,
                              onTap: () => _selectItem(item.title),
                            ),
                          ],
                        ],
                        if (section.visibleItems.isNotEmpty)
                          const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderGray),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  child: widget.isCollapsed
                      ? const Icon(Icons.shield_outlined,
                          size: 18, color: AppColors.mutedTextGray)
                      : Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 16, color: AppColors.mutedTextGray),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user != null ? '${user.role} Portal' : 'VehicleIQ Platform v1.0',
                                style: AppTextStyles.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () => OtaUpdateDialogs.performAppUpdateCheck(context, isManualCheck: true),
                              child: const Icon(Icons.system_update_rounded, size: 16, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.mutedTextGray,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  List<_NavSectionData> _buildNavigationSections(AuthorizationService auth) {
    final allSections = [
      _NavSectionData(
        title: 'MAIN',
        items: [
          _NavItemData(
            title: 'Dashboard',
            permission: 'dashboard.view',
            icon: Icons.grid_view_rounded,
          ),
        ],
      ),
      _NavSectionData(
        title: 'OPERATIONS',
        items: [
          _NavItemData(
            title: 'Machines',
            permission: 'machines.view',
            icon: Icons.precision_manufacturing_outlined,
          ),
          _NavItemData(
            title: 'Live Tracking',
            permission: 'tracking.view',
            icon: Icons.navigation_outlined,
          ),
          _NavItemData(
            title: 'My Tasks',
            permission: 'tasks.view',
            icon: Icons.assignment_outlined,
          ),
          _NavItemData(
            title: 'Team',
            permission: 'team.view',
            icon: Icons.people_outline_rounded,
          ),
          _NavItemData(
            title: 'Attendance',
            permission: 'attendance.view',
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
      _NavSectionData(
        title: 'FINANCE & FUEL',
        items: [
          _NavItemData(
            title: 'Expenses',
            permission: 'expenses.view',
            icon: Icons.attach_money_rounded,
          ),
          _NavItemData(
            title: 'Fuel Logs',
            permission: 'fuel.view',
            icon: Icons.local_gas_station_outlined,
          ),
          _NavItemData(
            title: 'Refuel Records',
            permission: 'refuel.view',
            icon: Icons.sync_alt_rounded,
          ),
          _NavItemData(
            title: 'Reports',
            permission: 'reports.view',
            icon: Icons.description_outlined,
          ),
        ],
      ),
      _NavSectionData(
        title: 'MAINTENANCE',
        items: [
          _NavItemData(
            title: 'Maintenance',
            permission: 'maintenance.view',
            icon: Icons.build_outlined,
          ),
          _NavItemData(
            title: 'Breakdowns',
            permission: 'breakdowns.view',
            icon: Icons.warning_amber_rounded,
          ),
          _NavItemData(
            title: 'Alert Center',
            permission: 'notifications.view',
            icon: Icons.error_outline_rounded,
          ),
        ],
      ),
      _NavSectionData(
        title: 'INVENTORY',
        items: [
          _NavItemData(
            title: 'Stock & Spares',
            permission: 'inventory.view',
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
      _NavSectionData(
        title: 'MANAGEMENT',
        items: [
          _NavItemData(
            title: 'Vendors',
            permission: 'vendors.view',
            icon: Icons.storefront_outlined,
          ),
          _NavItemData(
            title: 'Users',
            permission: 'users.view',
            icon: Icons.person_outline_rounded,
          ),
          _NavItemData(
            title: 'Roles & Permissions',
            permission: 'roles.view',
            icon: Icons.admin_panel_settings_outlined,
          ),
        ],
      ),
      _NavSectionData(
        title: 'SYSTEM',
        items: [
          _NavItemData(
            title: 'Notifications',
            permission: 'notifications.view',
            icon: Icons.notifications_none_rounded,
          ),
          _NavItemData(
            title: 'Settings',
            permission: 'settings.view',
            icon: Icons.settings_outlined,
          ),
          _NavItemData(
            title: 'Check for App Update',
            permission: 'dashboard.view',
            icon: Icons.system_update_rounded,
          ),
        ],
      ),
    ];

    // Filter sections and items dynamically based on auth.can(permission)
    return allSections.map((section) {
      final visible = section.items.where((item) => auth.can(item.permission)).toList();
      return _NavSectionData(
        title: section.title,
        items: section.items,
        visibleItems: visible,
      );
    }).toList();
  }
}

class _NavSectionData {
  final String title;
  final List<_NavItemData> items;
  final List<_NavItemData> visibleItems;

  _NavSectionData({
    required this.title,
    required this.items,
    List<_NavItemData>? visibleItems,
  }) : visibleItems = visibleItems ?? items;
}

class _NavItemData {
  final String title;
  final String permission;
  final IconData icon;

  _NavItemData({
    required this.title,
    required this.permission,
    required this.icon,
  });
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final String? badge;

  const _SidebarTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    this.isCollapsed = false,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? AppColors.lightGreenBg : Colors.transparent;
    final iconColor =
        isSelected ? AppColors.primaryGreen : AppColors.mutedTextGray;
    final textColor =
        isSelected ? AppColors.primaryGreen : AppColors.deepNavy;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? const Border(
                    left: BorderSide(color: AppColors.primaryGreen, width: 3),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment:
                isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: title,
        preferBelow: false,
        child: content,
      );
    }

    return content;
  }
}

class _ExpandableSidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ExpandableSidebarTile({
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.mutedTextGray, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.deepNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.mutedTextGray,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _SidebarSubTile extends StatelessWidget {
  final String title;
  final String? count;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarSubTile({
    required this.title,
    this.count,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? AppColors.lightGreenBg : Colors.transparent;
    final textColor =
        isSelected ? AppColors.primaryGreen : AppColors.deepNavy;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.primaryGreen)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count!,
                    style: TextStyle(
                      color: badgeColor ?? AppColors.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
