import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/features/tasks/controller/task_controller.dart';
import 'package:hero_app/features/tasks/screens/task_detail_screen.dart';
import 'package:hero_app/features/tasks/widgets/task_card.dart';
import 'package:hero_app/features/tasks/widgets/task_filter_bottom_sheet.dart';
import 'package:hero_app/features/tasks/widgets/task_summary_cards.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/repositories/task_repository.dart';
import 'package:hero_app/services/authorization_service.dart';
import 'package:hero_app/shared/widgets/skeleton_loader.dart';

/// Mobile-first Task Feed Screen for HERO Task Management
class TasksScreen extends StatefulWidget {
  final TaskRepository? repository;
  final TaskController? controller;

  const TasksScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TaskController _controller;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TaskController(
          repository: widget.repository ?? ApiTaskRepository(),
        );
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerChanged);
    _scrollController.addListener(_onScroll);
    _controller.fetchTasks(page: 0);
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
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openFilterBottomSheet() {
    TaskFilterBottomSheet.show(
      context,
      initialFilter: _controller.filter,
      availableVendors: _controller.availableVendors,
      availableSupervisors: _controller.availableSupervisors,
      availableDistricts: _controller.availableDistricts,
      availableCircles: _controller.availableCircles,
      onApplyFilters: (newFilter) {
        _controller.applyFilter(newFilter);
      },
    );
  }

  void _navigateToDetail(TaskModel task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ),
    );
  }

  Future<void> _handleCompleteTask(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Task'),
        content: Text(
          'Are you sure you want to mark "${task.taskCode}" as Completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _controller.completeTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Task ${task.taskCode} marked as Completed!'
                  : 'Failed to complete task.',
            ),
            backgroundColor:
                success ? AppColors.successGreen : AppColors.criticalRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'My Tasks',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Task Management',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _controller.isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: () => _controller.fetchTasks(page: _controller.currentPage),
            tooltip: 'Refresh Tasks',
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded, color: AppColors.white),
                onPressed: _openFilterBottomSheet,
                tooltip: 'Filter Tasks',
              ),
              if (_controller.filter.hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
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
          if (AuthorizationService.instance.can('tasks.create'))
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create Task dialog opened')),
                );
              },
              tooltip: 'Create Task',
            ),
        ],
      ),
      body: Column(
        children: [
          // Horizontally Scrollable Summary Cards Section
          TaskSummaryCardsBar(
            activeTaskType: _controller.filter.taskType,
            summaryCounts: _controller.summaryCounts,
            totalCount: _controller.totalCount,
            onSelectTaskType: (type) => _controller.selectTaskType(type),
          ),

          // Search Field & Active Filter Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => _controller.setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: 'Search tasks, code, block, district...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.mutedTextGray),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.borderGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.borderGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primaryGreen, width: 2),
                          ),
                        ),
                      ),
                    ),
                    if (_controller.filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _controller.clearFilters(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.criticalRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.criticalRed.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(
                            Icons.filter_alt_off_rounded,
                            color: AppColors.criticalRed,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Task List View with Pull to Refresh
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: () => _controller.fetchTasks(page: 0),
              child: _controller.isLoading
                  ? _buildSkeletonList()
                  : _controller.errorMessage != null
                      ? _buildErrorView()
                      : _controller.tasks.isEmpty
                          ? _buildEmptyView()
                          : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: ListView.separated(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  itemCount: _controller.tasks.length +
                                      (_controller.isLoadingMore ? 1 : 0),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    if (index == _controller.tasks.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final task = _controller.tasks[index];
                                    return TaskCard(
                                      task: task,
                                      onInspect: () => _navigateToDetail(task),
                                      onComplete: () => _handleCompleteTask(task),
                                    );
                                  },
                                ),
                              ),
                            ),
            ),
          ),

          // Bottom Pagination Bar
          if (!_controller.isLoading && _controller.errorMessage == null)
            _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderGray, width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page ${_controller.displayPageNumber} of ${_controller.totalPages}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Text(
                    '${_controller.totalCount} Tasks (${_controller.pageSize} per page)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedTextGray,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _controller.hasPrevious
                        ? () => _controller.previousPage()
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 16),
                    label: const Text('Prev', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      foregroundColor: AppColors.primaryGreen,
                      disabledForegroundColor: AppColors.mutedTextGray,
                      side: BorderSide(
                        color: _controller.hasPrevious
                            ? AppColors.primaryGreen
                            : AppColors.borderGray,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _controller.hasNext ? () => _controller.nextPage() : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    label: const Text('Next', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      foregroundColor: AppColors.primaryGreen,
                      disabledForegroundColor: AppColors.mutedTextGray,
                      side: BorderSide(
                        color: _controller.hasNext
                            ? AppColors.primaryGreen
                            : AppColors.borderGray,
                      ),
                    ),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: 5,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 110, height: 22),
                      SkeletonBox(width: 80, height: 20),
                    ],
                  ),
                  SizedBox(height: 10),
                  SkeletonBox(width: 180, height: 16),
                  SizedBox(height: 6),
                  SkeletonBox(width: 220, height: 12),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(width: double.infinity, height: 14)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(width: double.infinity, height: 14)),
                    ],
                  ),
                  SizedBox(height: 12),
                  SkeletonBox(width: double.infinity, height: 8),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(width: double.infinity, height: 36)),
                      SizedBox(width: 10),
                      Expanded(child: SkeletonBox(width: double.infinity, height: 36)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined,
                size: 56, color: AppColors.mutedTextGray),
            const SizedBox(height: 12),
            const Text('No Tasks Found', style: AppTextStyles.headingSmall),
            const SizedBox(height: 6),
            const Text(
              'No tasks are available for the selected filters.',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.criticalRed),
            const SizedBox(height: 12),
            Text(
              _controller.errorMessage ?? 'Unable to load tasks.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _controller.fetchTasks(page: 0),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
