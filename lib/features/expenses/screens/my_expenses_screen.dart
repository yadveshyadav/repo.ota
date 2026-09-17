import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controller/expense_controller.dart';
import '../models/expense_models.dart';
import '../repositories/expense_repository.dart';
import '../../../shared/widgets/hero_animated_item.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_filter_sheet.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';

/// Mobile My Expenses List Screen supporting Search, Status/Category/Date Filters, Pagination & Refresh
class MyExpensesScreen extends StatefulWidget {
  final ExpenseRepository? repository;
  final ExpenseController? controller;
  final String? initialStatusFilter;

  const MyExpensesScreen({
    super.key,
    this.repository,
    this.controller,
    this.initialStatusFilter,
  });

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  late final ExpenseController _controller;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        ExpenseController(
          repository: widget.repository ?? ApiExpenseRepository(),
        );
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerStateChanged);
    _scrollController.addListener(_onScroll);

    if (widget.initialStatusFilter != null) {
      _controller.applyFilters(status: widget.initialStatusFilter);
    } else {
      _controller.fetchExpenses(page: 1);
    }
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
    _controller.removeListener(_onControllerStateChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(controller: _controller),
      ),
    );
  }

  void _openExpenseDetail(Expense expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(
          expense: expense,
          controller: _controller,
        ),
      ),
    );
  }

  void _openFilterSheet() {
    ExpenseFilterSheet.show(
      context: context,
      initialStatus: _controller.selectedStatus,
      initialCategory: _controller.selectedCategory,
      initialDateFrom: _controller.dateFrom,
      initialDateTo: _controller.dateTo,
      categories: _controller.categories,
      onApply: (status, category, dateFrom, dateTo) {
        _controller.applyFilters(
          status: status,
          category: category,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Expenses', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${_controller.totalCount} expense records', style: const TextStyle(color: AppColors.white, fontSize: 11)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.white),
            onPressed: _openAddExpense,
            tooltip: 'Add Expense',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: () => _controller.fetchExpenses(page: 1),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: () => _controller.fetchExpenses(page: 1),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                          hintText: 'Search title, ID, supplier...',
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
                  ),
                  const SizedBox(width: 10),

                  // Filter Button
                  InkWell(
                    onTap: _openFilterSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _controller.hasActiveFilters ? AppColors.lightGreenBg : AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _controller.hasActiveFilters ? AppColors.primaryGreen : AppColors.borderGray,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 20,
                            color: _controller.hasActiveFilters ? AppColors.primaryGreen : AppColors.deepNavy,
                          ),
                          if (_controller.hasActiveFilters) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Filters Summary Chips
              if (_controller.hasActiveFilters) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Filters:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                    TextButton(
                      onPressed: () => _controller.resetFilters(),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: const Text('Reset All', style: TextStyle(fontSize: 11, color: AppColors.criticalRed, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_controller.selectedStatus != 'ALL')
                      _buildActiveFilterChip('Status: ${_controller.selectedStatus}'),
                    if (_controller.selectedCategory != 'ALL')
                      _buildActiveFilterChip('Category ID: ${_controller.selectedCategory}'),
                    if (_controller.dateFrom != null && _controller.dateFrom!.isNotEmpty)
                      _buildActiveFilterChip('From: ${_controller.dateFrom}'),
                    if (_controller.dateTo != null && _controller.dateTo!.isNotEmpty)
                      _buildActiveFilterChip('To: ${_controller.dateTo}'),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Content View
              if (_controller.isLoadingList) ...[
                _buildSkeletons(),
              ] else if (_controller.listError != null) ...[
                _buildErrorBox(_controller.listError!),
              ] else if (_controller.expenses.isEmpty) ...[
                _buildEmptyBox(),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _controller.expenses.length + (_controller.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == _controller.expenses.length) {
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
                    final expense = _controller.expenses[index];
                    return HeroAnimatedItem(
                      index: index,
                      child: ExpenseCard(
                        expense: expense,
                        onTap: () => _openExpenseDetail(expense),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
    );
  }

  Widget _buildSkeletons() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.criticalRed, size: 40),
          const SizedBox(height: 10),
          const Text('Unable to load expenses', style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(msg, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _controller.fetchExpenses(page: 1),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.softGray, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.mutedTextGray),
          ),
          const SizedBox(height: 16),
          const Text('No Expenses Found', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          const Text('No expense records match your active search or filter criteria.', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openAddExpense,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
          ),
        ],
      ),
    );
  }
}
