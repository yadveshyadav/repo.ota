import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hero_app/models/task_filter.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/repositories/task_repository.dart';

/// State Controller managing paginated task fetching, category filtering,
/// mobile filter bottom sheet, debounced search, and pagination state.
class TaskController extends ChangeNotifier {
  final TaskRepository repository;
  Timer? _debounceTimer;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<TaskModel> _tasks = [];
  int _totalCount = 0;
  int _totalPages = 1;
  int _currentPage = 0;
  int _pageSize = 100;
  bool _hasNext = false;
  bool _hasPrevious = false;

  Map<String, int> _summaryCounts = {};

  String _searchQuery = '';
  TaskFilterModel _filter = const TaskFilterModel();

  TaskController({required this.repository});

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  List<TaskModel> get tasks => _tasks;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  int get displayPageNumber => _currentPage + 1;
  int get pageSize => _pageSize;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;
  String get searchQuery => _searchQuery;
  TaskFilterModel get filter => _filter;
  Map<String, int> get summaryCounts => _summaryCounts;

  Set<String> get availableVendors => _tasks
      .map((t) => t.vendorName)
      .where((v) => v.isNotEmpty && v != 'Unassigned Vendor')
      .toSet();

  Set<String> get availableSupervisors => _tasks
      .map((t) => t.supervisorName)
      .where((s) => s.isNotEmpty && s != 'Unassigned Supervisor')
      .toSet();

  Set<String> get availableDistricts => _tasks
      .map((t) => t.district)
      .where((d) => d.isNotEmpty && d != 'N/A')
      .toSet();

  Set<String> get availableCircles => _tasks
      .map((t) => t.circle)
      .where((c) => c.isNotEmpty && c != 'N/A')
      .toSet();

  /// Fetch paginated tasks from API
  Future<void> fetchTasks({int page = 0, bool isSilent = false}) async {
    if (!isSilent) {
      if (_tasks.isEmpty) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      } else {
        _isRefreshing = true;
        _errorMessage = null;
        notifyListeners();
      }
    }

    try {
      final response = await repository.getTasks(
        page: page,
        size: _pageSize,
        filters: _filter,
        search: _searchQuery,
      );

      _tasks = response.tasks;
      _totalCount = response.totalCount;
      _totalPages = response.totalPages;
      _currentPage = response.currentPage;
      _pageSize = response.pageSize;
      _hasNext = response.hasNext;
      _hasPrevious = response.hasPrevious;

      if (response.summaryCounts.isNotEmpty) {
        _summaryCounts = Map.from(response.summaryCounts);
      } else {
        final Map<String, int> dynamicSummary = {'ALL': response.totalCount};
        for (final task in response.tasks) {
          dynamicSummary[task.taskType] = (dynamicSummary[task.taskType] ?? 0) + 1;
        }
        _summaryCounts = dynamicSummary;
      }

      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[TaskController] fetchTasks error: $e');
      }
      _tasks = [];
      _totalCount = 0;
      _totalPages = 1;
      _currentPage = 0;
      _hasNext = false;
      _hasPrevious = false;
      _summaryCounts = {};
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Load next page for infinite scrolling / pagination
  Future<void> loadNextPage() async {
    if (!_hasNext || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPageNum = _currentPage + 1;
      final response = await repository.getTasks(
        page: nextPageNum,
        size: _pageSize,
        filters: _filter,
        search: _searchQuery,
      );

      final existingIds = _tasks.map((t) => t.id).toSet();
      for (final task in response.tasks) {
        if (!existingIds.contains(task.id)) {
          _tasks.add(task);
        }
      }
      _currentPage = response.currentPage;
      _hasNext = response.hasNext;
      _hasPrevious = response.hasPrevious;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Select summary card / task type filter
  void selectTaskType(String taskType) {
    if (_filter.taskType == taskType) return;
    _filter = _filter.copyWith(taskType: taskType);
    _currentPage = 0;
    fetchTasks(page: 0);
  }

  /// Apply mobile filter bottom sheet state
  void applyFilter(TaskFilterModel newFilter) {
    _filter = newFilter;
    _currentPage = 0;
    fetchTasks(page: 0);
  }

  /// Reset all filters
  void clearFilters() {
    _filter = const TaskFilterModel();
    _searchQuery = '';
    _currentPage = 0;
    fetchTasks(page: 0);
  }

  /// Update search query with 300ms debouncing
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _currentPage = 0;
      fetchTasks(page: 0);
    });
  }

  /// Go to next page
  void nextPage() {
    if (_hasNext) {
      fetchTasks(page: _currentPage + 1);
    }
  }

  /// Go to previous page
  void previousPage() {
    if (_hasPrevious && _currentPage > 0) {
      fetchTasks(page: _currentPage - 1);
    }
  }

  /// Complete task action
  Future<bool> completeTask(String taskId) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final existing = _tasks[index];
        _tasks[index] = TaskModel.fromJson({
          'id': existing.id,
          'taskCode': existing.taskCode,
          'displayName': existing.displayName,
          'taskType': existing.taskType,
          'taskLevel': existing.taskLevel,
          'status': 'COMPLETED',
          'stage': 'REVIEW',
          'approvalStatus': 'APPROVED',
          'locationCode': existing.locationCode,
          'locationSnapshot': {
            'code': existing.locationCode,
            'name': existing.locationName,
            'district': existing.district,
            'circle': existing.circle,
            'blockName': existing.blockName,
            'state': existing.state,
          },
          'assigneeSnapshot': {
            'id': 'usr_881',
            'name': existing.assigneeName,
            'designation': existing.designation,
            'mobile': existing.mobile,
          },
          'vendorName': existing.vendorName,
          'partnerName': existing.partnerName,
          'supervisorName': existing.supervisorName,
          'creatorName': existing.creatorName,
          'plannedScope': existing.plannedScope,
          'remainingScope': 0.0,
          'completedScope': existing.plannedScope,
          'progress': 100.0,
          'createdAt': existing.createdAt?.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'completedAt': DateTime.now().toIso8601String(),
        });
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
