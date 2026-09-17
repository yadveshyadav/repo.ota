import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/machine.dart';
import '../../repositories/machine_repository.dart';
import '../../widgets/dashboard/dashboard_header.dart';
import '../../widgets/dashboard/dashboard_sidebar.dart';
import '../../widgets/machines/machine_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'machine_detail_screen.dart';

/// Modern Enterprise Machine Listing Screen matching HERO WEB Reference
class MachineListScreen extends StatefulWidget {
  final String initialStatusFilter;
  final MachineRepository? repository;

  const MachineListScreen({
    super.key,
    this.initialStatusFilter = 'All',
    this.repository,
  });

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  late final MachineRepository _repository;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _errorMessage;
  List<Machine> _allFetchedMachines = [];
  List<Machine> _filteredMachines = [];

  String _searchQuery = '';
  late String _selectedFilter;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMachineRepository();
    _selectedFilter = widget.initialStatusFilter;
    _fetchMachines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMachines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var machines = await _repository.getAllMachines();
      if (!mounted) return;

      final user = AuthStorageService().currentUser;
      if (user != null && user.isVendorUser && user.vendors.isNotEmpty) {
        final vendorNames = user.vendors
            .map((v) => v['name']?.toString().toLowerCase())
            .whereType<String>()
            .toSet();

        machines = machines.where((m) {
          final mVendor = m.vendorName?.toLowerCase();
          if (mVendor == null) return false;
          return vendorNames.contains(mVendor) ||
              vendorNames.any((v) => mVendor.contains(v));
        }).toList();
      }

      setState(() {
        _allFetchedMachines = machines;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to fetch machine list: $e';
        _isLoading = false;
      });
    }
  }

  // Calculate dynamic filter counts
  int get _countAll => _allFetchedMachines.length;
  int get _countCommissioned => _allFetchedMachines.where((m) => m.isCommissioned == true).length;
  int get _countA600 => _allFetchedMachines.where((m) => m.model.toUpperCase().contains('A600')).length;
  int get _countA800 => _allFetchedMachines.where((m) => m.model.toUpperCase().contains('A800')).length;
  int get _countRunning => _allFetchedMachines.where((m) => m.isWorking).length;
  int get _countIdle => _allFetchedMachines.where((m) => m.isIdle).length;
  int get _countMaintenance => _allFetchedMachines.where((m) => m.isMaintenance).length;

  void _applyFilters() {
    setState(() {
      _filteredMachines = _allFetchedMachines.where((machine) {
        // 1. Search Filter
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase().trim();
          final matchesChassis = machine.chassisNumber.toLowerCase().contains(q);
          final matchesName = machine.machineName.toLowerCase().contains(q);
          final matchesModel = machine.model.toLowerCase().contains(q);
          final matchesSite = machine.site.toLowerCase().contains(q);
          final matchesOperator = machine.operatorName.toLowerCase().contains(q);
          final matchesFuelCard = (machine.fuelCardText ?? '').toLowerCase().contains(q);

          if (!matchesChassis &&
              !matchesName &&
              !matchesModel &&
              !matchesSite &&
              !matchesOperator &&
              !matchesFuelCard) {
            return false;
          }
        }

        // 2. Filter Pills
        final filter = _selectedFilter.toLowerCase();
        if (filter == 'commissioned') {
          if (machine.isCommissioned != true) return false;
        } else if (filter == 'a600') {
          if (!machine.model.toUpperCase().contains('A600')) return false;
        } else if (filter == 'a800') {
          if (!machine.model.toUpperCase().contains('A800')) return false;
        } else if (filter == 'running') {
          if (!machine.isWorking) return false;
        } else if (filter == 'idle') {
          if (!machine.isIdle) return false;
        } else if (filter == 'maintenance') {
          if (!machine.isMaintenance) return false;
        }

        return true;
      }).toList();
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
      setState(() {
        _selectedFilter = 'All';
      });
      _applyFilters();
    } else if (route == 'Live Tracking' || route == 'Live Status' || route == 'Map View') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.liveStatus);
    } else if (route == 'My Tasks' || route == 'Tasks') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.tasks);
    } else if (route == 'Team') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.team);
    } else if (route == 'Partners' || route == 'Vendors') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.vendors);
    } else if (route == 'Users') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.users);
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

  void _navigateToDetail(Machine machine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineDetailScreen(
          chassisNo: machine.machineChassisNo,
          repository: _repository,
        ),
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      appBar: DashboardHeader(
        isMobile: !isDesktop,
        userName: userName,
        userRole: userRole,
        userInitials: userInitials.isNotEmpty ? userInitials : 'AS',
        onMenuPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      drawer: !isDesktop
          ? Drawer(
              width: 280,
              child: DashboardSidebar(
                selectedRoute: 'Total Machines',
                totalMachines: _countAll,
                onlineMachines: _countRunning,
                offlineMachines: _countIdle,
                maintenanceMachines: _countMaintenance,
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
              selectedRoute: 'Total Machines',
              totalMachines: _countAll,
              onlineMachines: _countRunning,
              offlineMachines: _countIdle,
              maintenanceMachines: _countMaintenance,
              onRouteSelected: (route) {
                _handleSidebarRouteSelected(route);
              },
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMachines,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER ROW (Title, API Badge, Subtitle & Sync Button)
                    _buildHeader(isMobile),

                    const SizedBox(height: 16),

                    // 2. SEARCH INPUT BAR
                    _buildSearchInput(),

                    const SizedBox(height: 14),

                    // 3. FILTER PILLS BAR
                    _buildFilterPillsBar(),

                    const SizedBox(height: 18),

                    // 4. MACHINE GRID / SKELETON / ERROR / EMPTY STATES
                    if (_isLoading) ...[
                      _buildSkeletonGrid(),
                    ] else if (_errorMessage != null) ...[
                      _buildErrorState(),
                    ] else if (_filteredMachines.isEmpty) ...[
                      _buildEmptyState(),
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

  /// Header matching HERO WEB Machines Reference
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text(
                    'Machines',
                    style: AppTextStyles.displayMedium,
                  ),

                  // FiberForce API Badge with Live Broadcast Pulse Dot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.headerGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sensors_rounded,
                          color: AppColors.successGreen,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'FiberForce API ($_countAll)',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Live HDD Fleet from FiberForce REST API (api.hdd.fiberforce.in)',
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Sync API Button
        OutlinedButton.icon(
          onPressed: _fetchMachines,
          icon: const Icon(Icons.sync_rounded, size: 15, color: AppColors.deepNavy),
          label: Text(
            isMobile ? 'Sync' : 'Sync API',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.borderGray, width: 1),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  /// Full Width Search Input
  Widget _buildSearchInput() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          _searchQuery = val;
          _applyFilters();
        },
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText:
              'Search by chassis (e.g. 600202608396), model (A600/A800), site, operator, or fuel card...',
          hintStyle: const TextStyle(
            color: AppColors.mutedTextGray,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.mutedTextGray,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilters();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  /// Filter Pills Bar matching HERO WEB exact choices
  Widget _buildFilterPillsBar() {
    final filterChoices = [
      {'key': 'All', 'label': 'All ($_countAll)'},
      {'key': 'Commissioned', 'label': 'Commissioned ($_countCommissioned)'},
      {'key': 'A600', 'label': 'A600 ($_countA600)'},
      {'key': 'A800', 'label': 'A800 ($_countA800)'},
      {'key': 'Running', 'label': 'Running ($_countRunning)'},
      {'key': 'Idle', 'label': 'Idle ($_countIdle)'},
      {'key': 'Maintenance', 'label': 'Maintenance ($_countMaintenance)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filterChoices.map((item) {
          final key = item['key']!;
          final label = item['label']!;
          final isSelected = _selectedFilter.toLowerCase() == key.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFilter = key;
                });
                _applyFilters();
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.deepNavy : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.deepNavy : AppColors.borderGray,
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
        }).toList(),
      ),
    );
  }

  /// Responsive Machine Grid View
  Widget _buildMachineGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;

        if (width >= 1100) {
          crossAxisCount = 3;
        } else if (width >= 650) {
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
            mainAxisExtent: 245,
          ),
          itemCount: _filteredMachines.length,
          itemBuilder: (context, index) {
            final machine = _filteredMachines[index];
            return MachineCardWidget(
              key: ValueKey(machine.chassisNumber),
              machine: machine,
              onTap: () => _navigateToDetail(machine),
            );
          },
        );
      },
    );
  }

  /// Responsive Skeleton Grid Loading View
  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = width >= 1100
            ? 3
            : width >= 650
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 245,
          ),
          itemCount: crossAxisCount * 2,
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 50, height: 16),
                    SkeletonBox(width: 60, height: 16),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonBox(width: 140, height: 18),
                SizedBox(height: 4),
                SkeletonBox(width: 110, height: 12),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(width: 80, height: 18),
                    SizedBox(width: 6),
                    SkeletonBox(width: 90, height: 18),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonBox(width: 130, height: 14),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 70, height: 16),
                    SkeletonBox(width: 80, height: 16),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
          const Text(
            'No machines match your filter',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Try selecting another filter chip or clearing your search term.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              _searchQuery = '';
              _selectedFilter = 'All';
              _applyFilters();
            },
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
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
            'Unable to load machines',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Please check your connection and try again.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchMachines,
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
}
