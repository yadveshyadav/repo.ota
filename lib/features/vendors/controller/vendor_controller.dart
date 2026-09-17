import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/vendor.dart';
import '../../../repositories/vendor_repository.dart';

/// State Controller for Vendor & Partner Management feature
class VendorController extends ChangeNotifier {
  final VendorRepository repository;
  Timer? _debounceTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<Vendor> _vendors = [];
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  String _searchQuery = '';

  VendorController({
    required this.repository,
    int? pageSize,
  }) : _pageSize = pageSize ?? 10;

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  List<Vendor> get vendors => _vendors;

  int get currentPage => _currentPage;
  int get displayPageNumber => _currentPage + 1; // 1-based for UI display
  int get pageSize => _pageSize;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;

  String get searchQuery => _searchQuery;

  /// Primary fetch method retrieving paginated vendor data
  Future<void> fetchVendors({bool isSilent = false}) async {
    if (!isSilent) {
      if (_vendors.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await repository.getVendors(
        page: _currentPage,
        size: _pageSize,
        search: _searchQuery.trim(),
      );

      _vendors = response.vendors;
      _totalCount = response.totalCount;
      _totalPages = response.totalPages;
      _hasNext = response.hasNext;
      _hasPrevious = response.hasPrevious;

      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRefreshing = false;
      if (_vendors.isEmpty) {
        _errorMessage = 'Unable to load vendors. Please verify connection and retry.';
      } else {
        _errorMessage = 'Unable to refresh vendors.';
      }
      notifyListeners();
    }
  }

  /// Update search query with 400ms debounce and page reset
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _currentPage = 0; // Reset to page 0 on new search query
      fetchVendors();
    });
  }

  /// Clear active search query and reset page
  void clearSearch() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _currentPage = 0;
    fetchVendors();
  }

  /// Navigate to next page
  Future<void> nextPage() async {
    if (!_hasNext) return;
    _currentPage++;
    await fetchVendors();
  }

  /// Navigate to previous page
  Future<void> previousPage() async {
    if (_currentPage <= 0) return;
    _currentPage--;
    await fetchVendors();
  }

  /// Change page size
  Future<void> setPageSize(int size) async {
    if (_pageSize == size) return;
    _pageSize = size;
    _currentPage = 0;
    await fetchVendors();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
