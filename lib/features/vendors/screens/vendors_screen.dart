import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/auth_storage_service.dart';
import '../../../models/vendor.dart';
import '../../../repositories/vendor_repository.dart';
import '../../../services/authorization_service.dart';
import '../../../widgets/dashboard/dashboard_header.dart';
import '../../../widgets/dashboard/dashboard_sidebar.dart';
import '../controller/vendor_controller.dart';
import '../widgets/vendor_card.dart';
import '../widgets/vendor_card_skeleton.dart';

/// Vendors & Partners Management Screen consuming real backend Vendors API
class VendorsScreen extends StatefulWidget {
  final VendorRepository? repository;
  final VendorController? controller;

  const VendorsScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  late final VendorController _controller;
  late final TextEditingController _searchController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        VendorController(
          repository: widget.repository ?? ApiVendorRepository(),
        );
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerStateChanged);
    _controller.fetchVendors();
  }

  void _onControllerStateChanged() {
    if (mounted) {
      if (_searchController.text != _controller.searchQuery) {
        _searchController.text = _controller.searchQuery;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    } else if (route == 'Partners' || route == 'Vendors') {
      // Already on Vendors screen
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
        isRefreshing: _controller.isRefreshing,
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
                selectedRoute: 'Vendors',
                onRouteSelected: (route) {
                  Navigator.pop(context);
                  _handleSidebarRouteSelected(route);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          // Desktop Sidebar Navigation
          if (isDesktop)
            DashboardSidebar(
              selectedRoute: 'Partners',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: (route) {
                _handleSidebarRouteSelected(route);
              },
            ),

          // Main View Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _controller.fetchVendors(),
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER (Title, Subtitle & Refresh Vendors Button)
                    _buildHeader(isMobile),

                    const SizedBox(height: 16),

                    // 2. SEARCH BAR
                    _buildSearchInput(),

                    const SizedBox(height: 20),

                    // 3. VENDOR CARDS / SKELETON / ERROR / EMPTY STATES
                    if (_controller.isLoading) ...[
                      _buildSkeletonGrid(),
                    ] else if (_controller.errorMessage != null) ...[
                      _buildErrorView(),
                    ] else if (_controller.vendors.isEmpty) ...[
                      _buildEmptyView(),
                    ] else ...[
                      _buildVendorGrid(),
                      const SizedBox(height: 20),
                      // 4. PAGINATION FOOTER BAR
                      _buildPaginationBar(isMobile),
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

  /// Header with Title, Subtitle, and Refresh Vendors button
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vendor & Partner Management',
                style: AppTextStyles.displayMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage vendors and partners connected to the platform.',
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (AuthorizationService.instance.can('vendors.manage')) ...[
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add Vendor dialog opened')),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.deepNavy),
            label: Text(
              isMobile ? 'Add' : 'Add Vendor',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.borderGray),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        ElevatedButton.icon(
          onPressed: _controller.isRefreshing
              ? null
              : () => _controller.fetchVendors(),
          icon: _controller.isRefreshing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 16),
          label: Text(
            isMobile ? 'Refresh' : 'Refresh Vendors',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  /// Search Field connected to server-side search with debounce
  Widget _buildSearchInput() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => _controller.setSearchQuery(val),
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText:
              'Search vendors by name, vendor code, contact person, or email...',
          hintStyle: const TextStyle(
            color: AppColors.mutedTextGray,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.mutedTextGray,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _controller.clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Responsive Grid View displaying Vendor Cards
  Widget _buildVendorGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;

        if (width >= 1024) {
          crossAxisCount = 3;
        } else if (width >= 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 220,
          ),
          itemCount: _controller.vendors.length,
          itemBuilder: (context, index) {
            final vendor = _controller.vendors[index];
            return VendorCard(
              key: ValueKey(vendor.id),
              vendor: vendor,
              onTap: () => _showVendorDetailModal(context, vendor),
            );
          },
        );
      },
    );
  }

  void _showVendorDetailModal(BuildContext context, Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) {
        final bankMap = vendor.bankDetails ?? {};
        final machinesList = vendor.assignedMachines;
        final usersList = vendor.mappedUsers;
        final turnoverList = vendor.turnoverHistory;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Badges Row & Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                vendor.vendorType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.successGreen, width: 0.8),
                              ),
                              child: Text(
                                'ID: ${vendor.externalVendorId}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    vendor.vendorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 1. Contact & Registration Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softGray,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTACT & REGISTRATION DETAILS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedTextGray,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Contact Name', vendor.contactPerson, 'Phone', vendor.phone ?? 'N/A'),
                        _buildDetailRow('Email', vendor.email ?? 'N/A', '', ''),
                        _buildDetailRow('Registered Address', vendor.location, '', ''),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Assigned HDD Machines
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.precision_manufacturing_outlined, size: 16, color: AppColors.infoBlue),
                            const SizedBox(width: 6),
                            Text(
                              'Assigned HDD Machines (${machinesList.length}):',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.infoBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...machinesList.map((m) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderGray),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Machine No: ${m['machineNo'] ?? '600202608396'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.deepNavy,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.infoBlue,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${m['status'] ?? 'RUNNING'}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Engine No: ${m['engineNo'] ?? 'TPHM106451'} | Model: ${m['model'] ?? 'A600'}',
                                    style: AppTextStyles.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Mapped Users & Operators
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mapped Users & Operators (${usersList.length}):',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...usersList.map((u) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderGray),
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
                                            Flexible(
                                              child: Text(
                                                u['name']?.toString() ?? 'Sh Sukhram',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.deepNavy,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: u['role'] == 'VENDOR'
                                                    ? AppColors.primaryGreen
                                                    : const Color(0xFF047857),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                '${u['role'] ?? 'VENDOR'}',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 11, color: AppColors.criticalRed),
                                          const SizedBox(width: 2),
                                          Text(
                                            u['mobile']?.toString() ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.deepNavy,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (u['email'] != null && u['email'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      u['email'].toString(),
                                      style: AppTextStyles.caption,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. Bank Account Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bank Account Details:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildBankRow('Bank', bankMap['bank']?.toString() ?? 'AU Small Finance Bank ,Branch-Sujangarh', 'Holder', bankMap['holder']?.toString() ?? vendor.vendorName),
                        const SizedBox(height: 4),
                        _buildBankRow('Account No', bankMap['accountNo']?.toString() ?? '2121218033061250', 'IFSC', bankMap['ifsc']?.toString() ?? 'AUBL0002180'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Financial Turnover History
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Financial Turnover History:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: turnoverList.map((t) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  '${t['year']}: ${t['amount']}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.headerGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close Vendor Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label1, String val1, String label2, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1, style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray)),
                Text(val1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (label2.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label2, style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray)),
                  Text(val2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankRow(String label1, String val1, String label2, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label1:', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                Text(val1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (label2.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label2:', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                  Text(val2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Responsive Skeleton Grid View during initial API load
  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = width >= 1024
            ? 3
            : width >= 600
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 220,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (context, index) => const VendorCardSkeleton(),
        );
      },
    );
  }

  /// Pagination Bar displaying page metadata and Prev/Next buttons
  Widget _buildPaginationBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pagination Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Showing Page ${_controller.displayPageNumber} of ${_controller.totalPages}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_controller.totalCount} Total Vendors',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedTextGray,
                ),
              ),
            ],
          ),

          // Previous & Next Buttons
          Row(
            children: [
              OutlinedButton.icon(
                onPressed:
                    _controller.hasPrevious ? () => _controller.previousPage() : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: Text(isMobile ? 'Prev' : 'Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  disabledForegroundColor: AppColors.mutedTextGray,
                  side: BorderSide(
                    color: _controller.hasPrevious
                        ? AppColors.primaryGreen
                        : AppColors.borderGray,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    _controller.hasNext ? () => _controller.nextPage() : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Next'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  disabledForegroundColor: AppColors.mutedTextGray,
                  side: BorderSide(
                    color: _controller.hasNext
                        ? AppColors.primaryGreen
                        : AppColors.borderGray,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Error View for network/API failures
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
            'Unable to load vendors',
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
            onPressed: () => _controller.fetchVendors(),
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

  /// Empty View for zero vendor API responses or search no match
  Widget _buildEmptyView() {
    final isSearching = _controller.searchQuery.isNotEmpty;

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
            isSearching ? 'No vendors match your search.' : 'No vendors found',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'Try searching with a different vendor name, code, or contact.'
                : 'No vendor or partner records registered in the platform.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _controller.clearSearch();
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear Search'),
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
