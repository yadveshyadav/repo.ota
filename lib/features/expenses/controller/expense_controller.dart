import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_models.dart';
import '../repositories/expense_repository.dart';

/// Centralized Expense Management Controller for Dashboard, List, Form, Details, and Approvals
class ExpenseController extends ChangeNotifier {
  final ExpenseRepository repository;

  static const String _keyOfflineDraftJson = 'hero_expense_offline_draft_v1';

  bool _isLoadingDashboard = false;
  bool _isLoadingList = false;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  bool _isDisposed = false;

  String? _dashboardError;
  String? _listError;
  String? _formError;

  ExpenseDashboardStats? _dashboardStats;
  List<Expense> _expenses = [];
  int _totalCount = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasNext = false;

  List<ExpenseCategory> _categories = [];
  List<ExpenseSubcategory> _currentSubcategories = [];

  Expense? _selectedExpense;

  // Filter States
  String _selectedStatus = 'ALL';
  String _selectedCategory = 'ALL';
  String? _dateFrom;
  String? _dateTo;
  String _searchQuery = '';

  Timer? _searchDebounce;

  ExpenseController({ExpenseRepository? repository})
      : repository = repository ?? ApiExpenseRepository();

  // Getters
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingList => _isLoadingList;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSubmitting => _isSubmitting;

  String? get dashboardError => _dashboardError;
  String? get listError => _listError;
  String? get formError => _formError;

  ExpenseDashboardStats? get dashboardStats => _dashboardStats;
  List<Expense> get expenses => _expenses;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  bool get hasNext => _hasNext;

  List<ExpenseCategory> get categories => _categories;
  List<ExpenseSubcategory> get currentSubcategories => _currentSubcategories;

  Expense? get selectedExpense => _selectedExpense;

  String get selectedStatus => _selectedStatus;
  String get selectedCategory => _selectedCategory;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;
  String get searchQuery => _searchQuery;

  bool get hasActiveFilters =>
      _selectedStatus != 'ALL' ||
      _selectedCategory != 'ALL' ||
      (_dateFrom != null && _dateFrom!.isNotEmpty) ||
      (_dateTo != null && _dateTo!.isNotEmpty) ||
      _searchQuery.trim().isNotEmpty;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  /// Load Expense Dashboard Stats from GET /api/v1/expenses/dashboard_stats/
  Future<void> fetchDashboardStats() async {
    if (_isDisposed) return;
    _isLoadingDashboard = true;
    _dashboardError = null;
    notifyListeners();

    try {
      _dashboardStats = await repository.getDashboardStats();
      _isLoadingDashboard = false;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _isLoadingDashboard = false;
      _dashboardError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Fetch Categories from GET /api/v1/expenses/categories/
  Future<void> fetchCategories() async {
    if (_isDisposed) return;
    try {
      _categories = await repository.getCategories();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[ExpenseController] fetchCategories error: $e');
      }
    }
  }

  /// Fetch Subcategories when Category is selected
  Future<void> fetchSubcategories(String categoryId) async {
    if (_isDisposed || categoryId.isEmpty) return;
    try {
      // First check local subcategories embedded in selected category
      final matchedCat = _categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => const ExpenseCategory(id: '', name: ''),
      );

      if (matchedCat.subcategories.isNotEmpty) {
        _currentSubcategories = matchedCat.subcategories;
      } else {
        _currentSubcategories = await repository.getSubcategories(categoryId);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[ExpenseController] fetchSubcategories error: $e');
      }
    }
  }

  /// Fetch Paginated Expense List from GET /api/v1/expenses/
  Future<void> fetchExpenses({int page = 1, bool isRefresh = false}) async {
    if (_isDisposed) return;

    if (page == 1) {
      _isLoadingList = true;
      _listError = null;
      notifyListeners();
    } else {
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final response = await repository.getExpenses(
        page: page,
        size: _pageSize,
        status: _selectedStatus,
        category: _selectedCategory,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _searchQuery,
      );

      if (_isDisposed) return;

      if (page == 1) {
        _expenses = List.from(response.results);
      } else {
        final existingIds = _expenses.map((e) => e.id).toSet();
        for (final item in response.results) {
          if (!existingIds.contains(item.id)) {
            _expenses.add(item);
          }
        }
      }

      _totalCount = response.totalCount;
      _totalPages = response.totalPages;
      _currentPage = response.currentPage;
      _hasNext = response.hasNext;

      _isLoadingList = false;
      _isLoadingMore = false;
      _listError = null;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _isLoadingList = false;
      _isLoadingMore = false;
      if (page == 1) {
        _listError = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
    }
  }

  /// Load Next Page for Infinite Scrolling
  Future<void> loadNextPage() async {
    if (!_hasNext || _isLoadingMore || _isDisposed) return;
    await fetchExpenses(page: _currentPage + 1);
  }

  /// Fetch Detailed Expense from GET /api/v1/expenses/{id}/
  Future<void> fetchExpenseDetail(String id) async {
    if (_isDisposed) return;
    try {
      _selectedExpense = await repository.getExpenseDetail(id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[ExpenseController] fetchExpenseDetail error: $e');
      }
    }
  }

  /// Create Expense / Save Draft via POST /api/v1/expenses/
  Future<Expense?> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  }) async {
    if (_isDisposed) return null;
    _isSubmitting = true;
    _formError = null;
    notifyListeners();

    try {
      final created = await repository.createExpense(
        fields: fields,
        attachmentFile: attachmentFile,
      );

      _isSubmitting = false;
      notifyListeners();

      // Clear local offline draft on successful submit
      clearOfflineDraft();

      // Refresh Dashboard and List
      fetchDashboardStats();
      fetchExpenses(page: 1);

      return created;
    } catch (e) {
      if (_isDisposed) return null;
      _isSubmitting = false;
      _formError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Submit existing Draft via POST /api/v1/expenses/{id}/submit/
  Future<bool> submitDraft(String id) async {
    if (_isDisposed) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      final updated = await repository.submitDraft(id);
      _selectedExpense = updated;
      _isSubmitting = false;
      notifyListeners();

      fetchDashboardStats();
      fetchExpenses(page: 1);
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Approve Expense via POST /api/v1/expenses/{id}/approve/
  Future<bool> approveExpense(String id) async {
    if (_isDisposed) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      final updated = await repository.approveExpense(id);
      _selectedExpense = updated;
      _isSubmitting = false;
      notifyListeners();

      fetchDashboardStats();
      fetchExpenses(page: 1);
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Reject Expense via POST /api/v1/expenses/{id}/reject/
  Future<bool> rejectExpense(String id, String reason) async {
    if (_isDisposed) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      final updated = await repository.rejectExpense(id, reason);
      _selectedExpense = updated;
      _isSubmitting = false;
      notifyListeners();

      fetchDashboardStats();
      fetchExpenses(page: 1);
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Mark Expense as Paid via POST /api/v1/expenses/{id}/pay/
  Future<bool> payExpense(String id, String paymentMode, String paymentReference) async {
    if (_isDisposed) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      final updated = await repository.payExpense(id, paymentMode, paymentReference);
      _selectedExpense = updated;
      _isSubmitting = false;
      notifyListeners();

      fetchDashboardStats();
      fetchExpenses(page: 1);
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Apply Filters
  Future<void> applyFilters({
    String? status,
    String? category,
    String? dateFrom,
    String? dateTo,
  }) async {
    if (status != null) _selectedStatus = status;
    if (category != null) _selectedCategory = category;
    _dateFrom = dateFrom;
    _dateTo = dateTo;
    await fetchExpenses(page: 1);
  }

  /// Reset Filters
  Future<void> resetFilters() async {
    _selectedStatus = 'ALL';
    _selectedCategory = 'ALL';
    _dateFrom = null;
    _dateTo = null;
    _searchQuery = '';
    await fetchExpenses(page: 1);
  }

  /// Set Search Query with debouncing
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      fetchExpenses(page: 1);
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        fetchExpenses(page: 1);
      });
    }
  }

  /// Offline Draft Local Storage Preservation
  Future<void> saveOfflineDraft(Map<String, String> formData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyOfflineDraftJson, jsonEncode(formData));
    } catch (e) {
      if (kDebugMode) {
        print('[ExpenseController] saveOfflineDraft error: $e');
      }
    }
  }

  Future<Map<String, String>?> loadOfflineDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_keyOfflineDraftJson);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k, v.toString()));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ExpenseController] loadOfflineDraft error: $e');
      }
    }
    return null;
  }

  Future<void> clearOfflineDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyOfflineDraftJson);
    } catch (_) {}
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
