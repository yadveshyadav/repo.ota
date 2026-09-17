import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/services/auth_storage_service.dart';
import '../../../widgets/dashboard/dashboard_header.dart';
import '../../../widgets/dashboard/dashboard_sidebar.dart';
import '../controller/expense_controller.dart';
import '../models/expense_models.dart';
import '../repositories/expense_repository.dart';
import 'add_expense_screen.dart';
import 'my_expenses_screen.dart';

/// Mobile-First Expense Dashboard Screen displaying real API statistics and category breakdown
class ExpenseDashboardScreen extends StatefulWidget {
  final ExpenseRepository? repository;
  final ExpenseController? controller;

  const ExpenseDashboardScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<ExpenseDashboardScreen> createState() => _ExpenseDashboardScreenState();
}

class _ExpenseDashboardScreenState extends State<ExpenseDashboardScreen> {
  late final ExpenseController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        ExpenseController(
          repository: widget.repository ?? ApiExpenseRepository(),
        );
    _controller.addListener(_onControllerStateChanged);
    _controller.fetchDashboardStats();
    _controller.fetchCategories();
  }

  void _onControllerStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
    }
  }

  void _openAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(controller: _controller),
      ),
    );
  }

  void _openMyExpenses({String? initialStatus}) {
    if (initialStatus != null) {
      _controller.applyFilters(status: initialStatus);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyExpensesScreen(
          controller: _controller,
          initialStatusFilter: initialStatus,
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
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? 'User');
    final userRole = user?.role.isNotEmpty == true ? user!.role : 'ADMIN';
    final userInitials = user?.initials ?? 'U';

    final stats = _controller.dashboardStats;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      appBar: DashboardHeader(
        isMobile: !isDesktop,
        isSidebarCollapsed: _isSidebarCollapsed,
        userName: userName,
        userRole: userRole,
        userInitials: userInitials,
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onSidebarToggle: _toggleSidebar,
      ),
      drawer: !isDesktop
          ? Drawer(
              width: 280,
              child: DashboardSidebar(
                selectedRoute: 'Expenses',
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
              selectedRoute: 'Expenses',
              isCollapsed: _isSidebarCollapsed,
              onRouteSelected: _handleSidebarRouteSelected,
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: () async {
                await _controller.fetchDashboardStats();
                await _controller.fetchCategories();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Expenses',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                            ),
                            Text(
                              'Track site costs, bills and approvals',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAddExpense,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('+ Add Expense'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Navigation Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionNavCard(
                            title: 'My Expenses',
                            subtitle: 'View all bills & status',
                            icon: Icons.receipt_long_rounded,
                            color: AppColors.primaryGreen,
                            onTap: () => _openMyExpenses(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionNavCard(
                            title: 'Pending Approvals',
                            subtitle: '${stats?.submittedCount ?? 0} pending review',
                            icon: Icons.pending_actions_rounded,
                            color: AppColors.movingBlue,
                            onTap: () => _openMyExpenses(initialStatus: 'SUBMITTED'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Dashboard Metrics Section
                    if (_controller.isLoadingDashboard) ...[
                      _buildMetricSkeletons(),
                    ] else if (_controller.dashboardError != null) ...[
                      _buildErrorBox(_controller.dashboardError!),
                    ] else if (stats != null) ...[
                      // Summary Grid Cards
                      GridView.count(
                        crossAxisCount: isMobile ? 2 : (isDesktop ? 4 : 3),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isMobile ? 1.5 : 1.6,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildMetricTile(
                            title: 'Total Expenses',
                            value: formatInr(stats.totalAmount),
                            subtitle: '${stats.totalCount} records',
                            icon: Icons.account_balance_wallet_outlined,
                            accentColor: AppColors.deepNavy,
                          ),
                          _buildMetricTile(
                            title: 'This Month',
                            value: formatInr(stats.monthAmount),
                            subtitle: 'Monthly spend',
                            icon: Icons.calendar_month_outlined,
                            accentColor: AppColors.primaryGreen,
                          ),
                          _buildMetricTile(
                            title: 'Pending Approval',
                            value: formatInr(stats.submittedAmount),
                            subtitle: '${stats.submittedCount} pending',
                            icon: Icons.hourglass_empty_rounded,
                            accentColor: AppColors.movingBlue,
                            onTap: () => _openMyExpenses(initialStatus: 'SUBMITTED'),
                          ),
                          _buildMetricTile(
                            title: 'Approved',
                            value: formatInr(stats.approvedAmount),
                            subtitle: '${stats.approvedCount} approved',
                            icon: Icons.check_circle_outline_rounded,
                            accentColor: AppColors.successGreen,
                            onTap: () => _openMyExpenses(initialStatus: 'APPROVED'),
                          ),
                          _buildMetricTile(
                            title: 'Paid',
                            value: '${stats.paidCount} Paid',
                            subtitle: 'Settled bills',
                            icon: Icons.payments_outlined,
                            accentColor: const Color(0xFF059669),
                            onTap: () => _openMyExpenses(initialStatus: 'PAID'),
                          ),
                          _buildMetricTile(
                            title: 'Rejected',
                            value: '${stats.rejectedCount} Rejected',
                            subtitle: 'Action needed',
                            icon: Icons.cancel_outlined,
                            accentColor: AppColors.criticalRed,
                            onTap: () => _openMyExpenses(initialStatus: 'REJECTED'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Category Breakdown Section
                      if (stats.byCategory.isNotEmpty) ...[
                        const Text(
                          'Category Breakdown',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stats.byCategory.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final catSum = stats.byCategory[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderGray),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.category_outlined, size: 18, color: AppColors.primaryGreen),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            catSum.category,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.deepNavy),
                                          ),
                                          Text(
                                            '${catSum.count} expenses',
                                            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    formatInr(catSum.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
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

  Widget _buildActionNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                  Icon(icon, size: 16, color: accentColor),
                ],
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                overflow: TextOverflow.ellipsis,
              ),
              Text(subtitle, style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSkeletons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)))),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.criticalRed, size: 36),
          const SizedBox(height: 8),
          const Text('Unable to load dashboard stats', style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _controller.fetchDashboardStats,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
          ),
        ],
      ),
    );
  }
}
