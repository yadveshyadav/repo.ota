import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/stock_issue_model.dart';
import '../../../models/stock_item_model.dart';
import '../../../repositories/inventory_repository.dart';

/// Centralized Controller managing Stock Items & Stock Issues state via ChangeNotifier
class InventoryController extends ChangeNotifier {
  final InventoryRepository repository;
  Timer? _itemsDebounceTimer;
  Timer? _issuesDebounceTimer;

  // Stock Items State
  bool _isItemsLoading = true;
  bool _isItemsRefreshing = false;
  bool _isItemsLoadingMore = false;
  String? _itemsErrorMessage;
  List<StockItemModel> _items = [];
  int _itemsCurrentPage = 0;
  int _itemsPageSize = 20;
  int _itemsTotalElements = 0;
  int _itemsTotalPages = 1;
  String _itemsSearchQuery = '';

  // Stock Issues State
  bool _isIssuesLoading = true;
  bool _isIssuesRefreshing = false;
  bool _isIssuesLoadingMore = false;
  String? _issuesErrorMessage;
  List<StockIssueModel> _issues = [];
  int _issuesCurrentPage = 0;
  int _issuesPageSize = 20;
  int _issuesTotalElements = 0;
  int _issuesTotalPages = 1;
  String _issuesSearchQuery = '';

  InventoryController({required this.repository});

  // Getters for Stock Items
  bool get isItemsLoading => _isItemsLoading;
  bool get isItemsRefreshing => _isItemsRefreshing;
  bool get isItemsLoadingMore => _isItemsLoadingMore;
  String? get itemsErrorMessage => _itemsErrorMessage;
  List<StockItemModel> get items => _items;
  int get itemsCurrentPage => _itemsCurrentPage;
  int get itemsPageSize => _itemsPageSize;
  int get itemsTotalElements => _itemsTotalElements;
  int get itemsTotalPages => _itemsTotalPages;
  bool get itemsHasNext => _itemsCurrentPage + 1 < _itemsTotalPages;
  String get itemsSearchQuery => _itemsSearchQuery;

  // Getters for Stock Issues
  bool get isIssuesLoading => _isIssuesLoading;
  bool get isIssuesRefreshing => _isIssuesRefreshing;
  bool get isIssuesLoadingMore => _isIssuesLoadingMore;
  String? get issuesErrorMessage => _issuesErrorMessage;
  List<StockIssueModel> get issues => _issues;
  int get issuesCurrentPage => _issuesCurrentPage;
  int get issuesPageSize => _issuesPageSize;
  int get issuesTotalElements => _issuesTotalElements;
  int get issuesTotalPages => _issuesTotalPages;
  bool get issuesHasNext => _issuesCurrentPage + 1 < _issuesTotalPages;
  String get issuesSearchQuery => _issuesSearchQuery;

  /// Fetch paginated Stock Issue Items
  Future<void> fetchItems({
    int page = 0,
    bool forceRefresh = false,
    bool isSilent = false,
  }) async {
    if (!isSilent) {
      if (_items.isEmpty) {
        _isItemsLoading = true;
      } else {
        _isItemsRefreshing = true;
      }
      _itemsErrorMessage = null;
      notifyListeners();
    }

    try {
      final res = await repository.getStockIssueItems(
        page: page,
        size: _itemsPageSize,
        search: _itemsSearchQuery,
        forceRefresh: forceRefresh,
      );

      _items = _deduplicateItems(res.items);
      _itemsCurrentPage = res.currentPage;
      _itemsPageSize = res.pageSize;
      _itemsTotalElements = res.totalElements;
      _itemsTotalPages = res.totalPages;
      _isItemsLoading = false;
      _isItemsRefreshing = false;
      _itemsErrorMessage = null;
      notifyListeners();
    } catch (e) {
      _isItemsLoading = false;
      _isItemsRefreshing = false;
      _itemsErrorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Load next page for Stock Items
  Future<void> loadNextItemsPage() async {
    if (!itemsHasNext || _isItemsLoadingMore) return;
    _isItemsLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _itemsCurrentPage + 1;
      final res = await repository.getStockIssueItems(
        page: nextPage,
        size: _itemsPageSize,
        search: _itemsSearchQuery,
      );

      final combined = List<StockItemModel>.from(_items)..addAll(res.items);
      _items = _deduplicateItems(combined);
      _itemsCurrentPage = res.currentPage;
      _itemsTotalElements = res.totalElements;
      _itemsTotalPages = res.totalPages;
      _isItemsLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isItemsLoadingMore = false;
      notifyListeners();
    }
  }

  /// Fetch paginated Stock Issues
  Future<void> fetchIssues({
    int page = 0,
    bool forceRefresh = false,
    bool isSilent = false,
  }) async {
    if (!isSilent) {
      if (_issues.isEmpty) {
        _isIssuesLoading = true;
      } else {
        _isIssuesRefreshing = true;
      }
      _issuesErrorMessage = null;
      notifyListeners();
    }

    try {
      final res = await repository.getStockIssues(
        page: page,
        size: _issuesPageSize,
        search: _issuesSearchQuery,
        forceRefresh: forceRefresh,
      );

      _issues = _deduplicateIssues(res.issues);
      _issuesCurrentPage = res.currentPage;
      _issuesPageSize = res.pageSize;
      _issuesTotalElements = res.totalElements;
      _issuesTotalPages = res.totalPages;
      _isIssuesLoading = false;
      _isIssuesRefreshing = false;
      _issuesErrorMessage = null;
      notifyListeners();
    } catch (e) {
      _isIssuesLoading = false;
      _isIssuesRefreshing = false;
      _issuesErrorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Load next page for Stock Issues
  Future<void> loadNextIssuesPage() async {
    if (!issuesHasNext || _isIssuesLoadingMore) return;
    _isIssuesLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _issuesCurrentPage + 1;
      final res = await repository.getStockIssues(
        page: nextPage,
        size: _issuesPageSize,
        search: _issuesSearchQuery,
      );

      final combined = List<StockIssueModel>.from(_issues)..addAll(res.issues);
      _issues = _deduplicateIssues(combined);
      _issuesCurrentPage = res.currentPage;
      _issuesTotalElements = res.totalElements;
      _issuesTotalPages = res.totalPages;
      _isIssuesLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isIssuesLoadingMore = false;
      notifyListeners();
    }
  }

  /// Update Stock Items Search Query with 300ms debouncing
  void setItemsSearchQuery(String query) {
    if (_itemsSearchQuery == query) return;
    _itemsSearchQuery = query;

    _itemsDebounceTimer?.cancel();
    _itemsDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _itemsCurrentPage = 0;
      fetchItems(page: 0, forceRefresh: true);
    });
  }

  /// Update Stock Issues Search Query with 300ms debouncing
  void setIssuesSearchQuery(String query) {
    if (_issuesSearchQuery == query) return;
    _issuesSearchQuery = query;

    _issuesDebounceTimer?.cancel();
    _issuesDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _issuesCurrentPage = 0;
      fetchIssues(page: 0, forceRefresh: true);
    });
  }

  /// Refresh all inventory datasets
  Future<void> refreshAll() async {
    await Future.wait([
      fetchItems(page: 0, forceRefresh: true),
      fetchIssues(page: 0, forceRefresh: true),
    ]);
  }

  /// Stable key deduplication for Stock Items
  List<StockItemModel> _deduplicateItems(List<StockItemModel> list) {
    final Map<String, StockItemModel> map = {};
    for (final item in list) {
      map[item.stableKey] = item;
    }
    return map.values.toList();
  }

  /// Stable key deduplication for Stock Issues
  List<StockIssueModel> _deduplicateIssues(List<StockIssueModel> list) {
    final Map<String, StockIssueModel> map = {};
    for (final issue in list) {
      map[issue.stableKey] = issue;
    }
    return map.values.toList();
  }

  @override
  void dispose() {
    _itemsDebounceTimer?.cancel();
    _issuesDebounceTimer?.cancel();
    super.dispose();
  }
}
