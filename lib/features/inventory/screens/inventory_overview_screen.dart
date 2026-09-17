import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/circle_stock_summary_model.dart';
import '../../../models/inventory_summary_model.dart';
import '../../../repositories/inventory_repository.dart';

import '../controller/inventory_controller.dart';
import '../widgets/circle_stock_card.dart';
import '../widgets/stock_issue_card.dart';
import '../widgets/stock_item_card.dart';
import 'stock_issue_detail_screen.dart';
import 'stock_item_detail_screen.dart';

/// Stock & Spares / Inventory Management Overview Screen
class StockInventoryOverviewScreen extends StatefulWidget {
  final InventoryRepository? repository;
  final InventoryController? controller;

  const StockInventoryOverviewScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<StockInventoryOverviewScreen> createState() => _StockInventoryOverviewScreenState();
}

class _StockInventoryOverviewScreenState extends State<StockInventoryOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final InventoryController _controller;
  late final TabController _workspaceTabController;

  final TextEditingController _itemsSearchTextController = TextEditingController();
  final TextEditingController _issuesSearchTextController = TextEditingController();

  final ScrollController _itemsScrollController = ScrollController();
  final ScrollController _issuesScrollController = ScrollController();

  // Circle Stock Summary Data
  final List<CircleStockSummaryModel> _circles = const [
    CircleStockSummaryModel(
      warehouseCode: 'WH-NAG-01',
      circleName: 'NAGAUR CIRCLE',
      totalMaterial: 15400.0,
      drumCount: 18,
      reservedQuantity: 300.0,
      vendorsIssued: 4,
    ),
    CircleStockSummaryModel(
      warehouseCode: 'WH-BAN-02',
      circleName: 'BANSWARA CIRCLE',
      totalMaterial: 12100.0,
      drumCount: 14,
      reservedQuantity: 500.0,
      vendorsIssued: 3,
    ),
    CircleStockSummaryModel(
      warehouseCode: 'WH-JAI-03',
      circleName: 'JAIPUR CIRCLE',
      totalMaterial: 19508.5,
      drumCount: 15,
      reservedQuantity: 400.0,
      vendorsIssued: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        InventoryController(
          repository: widget.repository ?? ApiInventoryRepository(),
        );

    _workspaceTabController = TabController(length: 2, vsync: this);

    _controller.fetchItems();
    _controller.fetchIssues();

    _itemsScrollController.addListener(_onItemsScroll);
    _issuesScrollController.addListener(_onIssuesScroll);
  }

  @override
  void dispose() {
    _itemsScrollController.dispose();
    _issuesScrollController.dispose();
    _itemsSearchTextController.dispose();
    _issuesSearchTextController.dispose();
    _workspaceTabController.dispose();
    super.dispose();
  }

  void _onItemsScroll() {
    if (_itemsScrollController.position.pixels >=
        _itemsScrollController.position.maxScrollExtent - 200) {
      _controller.loadNextItemsPage();
    }
  }

  void _onIssuesScroll() {
    if (_issuesScrollController.position.pixels >=
        _issuesScrollController.position.maxScrollExtent - 200) {
      _controller.loadNextIssuesPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock & Spares',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Inventory & Material Tracking',
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: _controller.refreshAll,
                tooltip: 'Refresh Inventory',
              ),
            ],
            bottom: TabBar(
              controller: _workspaceTabController,
              indicatorColor: AppColors.white,
              indicatorWeight: 3,
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Drums & Items'),
                Tab(text: 'Stock Issue Logs'),
              ],
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: TabBarView(
                controller: _workspaceTabController,
                children: [
                  _buildItemsTab(),
                  _buildIssuesTab(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // TAB 1: STOCK DRUMS & ITEMS
  Widget _buildItemsTab() {
    final summary = InventorySummaryModel(
      totalIssuedMaterial: _controller.itemsTotalElements > 0 ? 47008.5 : 0.0,
      drumsInventoryCount: _controller.itemsTotalElements,
      reservedQuantity: 1200.0,
      activeCirclesCount: _circles.length,
    );

    return RefreshIndicator(
      onRefresh: () => _controller.fetchItems(page: 0, forceRefresh: true),
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        controller: _itemsScrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero KPI Summary Cards
            _buildSummaryKpiHeader(summary),
            const SizedBox(height: 16),

            // Circle Stock Summary Row
            _buildCircleStockRow(),
            const SizedBox(height: 16),

            // Workspace Header & Search Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Drums & Items (${_controller.itemsTotalElements})',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _itemsSearchTextController,
              onChanged: _controller.setItemsSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search drum serial #, material, warehouse, vendor...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.mutedTextGray),
                suffixIcon: _itemsSearchTextController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _itemsSearchTextController.clear();
                          _controller.setItemsSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Item List Content
            if (_controller.isItemsLoading)
              _buildLoadingView()
            else if (_controller.itemsErrorMessage != null)
              _buildErrorView(_controller.itemsErrorMessage!, () => _controller.fetchItems(forceRefresh: true))
            else if (_controller.items.isEmpty)
              _buildEmptyView('No stock drums or items found.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controller.items.length,
                itemBuilder: (context, index) {
                  final item = _controller.items[index];
                  return StockItemCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockItemDetailScreen(item: item),
                        ),
                      );
                    },
                  );
                },
              ),

            if (_controller.isItemsLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // TAB 2: STOCK ISSUE LOGS
  Widget _buildIssuesTab() {
    return RefreshIndicator(
      onRefresh: () => _controller.fetchIssues(page: 0, forceRefresh: true),
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        controller: _issuesScrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stock Issue Transactions (${_controller.issuesTotalElements})',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _issuesSearchTextController,
              onChanged: _controller.setIssuesSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search issue #, transfer ref, warehouse, vendor...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.mutedTextGray),
                suffixIcon: _issuesSearchTextController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _issuesSearchTextController.clear();
                          _controller.setIssuesSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Issue List Content
            if (_controller.isIssuesLoading)
              _buildLoadingView()
            else if (_controller.issuesErrorMessage != null)
              _buildErrorView(_controller.issuesErrorMessage!, () => _controller.fetchIssues(forceRefresh: true))
            else if (_controller.issues.isEmpty)
              _buildEmptyView('No stock issue transactions recorded.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controller.issues.length,
                itemBuilder: (context, index) {
                  final issue = _controller.issues[index];
                  return StockIssueCard(
                    issue: issue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockIssueDetailScreen(issue: issue),
                        ),
                      );
                    },
                  );
                },
              ),

            if (_controller.isIssuesLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryKpiHeader(InventorySummaryModel summary) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiTile(
            title: 'Total Issued',
            value: summary.totalIssuedMaterial != null ? '${summary.totalIssuedMaterial!.toStringAsFixed(0)} m' : 'N/A',
            icon: Icons.inventory_outlined,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiTile(
            title: 'Drums',
            value: summary.drumsInventoryCount != null ? '${summary.drumsInventoryCount}' : '0',
            icon: Icons.inventory_2_outlined,
            color: AppColors.infoBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiTile(
            title: 'Reserved',
            value: summary.reservedQuantity != null ? '${summary.reservedQuantity!.toStringAsFixed(0)} m' : '0 m',
            icon: Icons.bookmark_border_rounded,
            color: AppColors.warningAmber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKpiTile(
            title: 'Circles',
            value: '${summary.activeCirclesCount ?? 0}',
            icon: Icons.circle_outlined,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCircleStockRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Circle-wise Stock Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _circles.length,
            itemBuilder: (context, index) {
              final circle = _circles[index];
              return CircleStockCard(circle: circle);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyView(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.mutedTextGray),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.criticalRed),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(fontSize: 13, color: AppColors.deepNavy), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
