import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/team_filter.dart';
import '../../../repositories/user_repository.dart';
import '../../auth/models/user_model.dart';

/// State Controller managing Paginated Team Members fetching, Infinite Scroll (100 items per page),
/// Debounced Search, Dynamic Filters, and Detailed Staff State.
class TeamController extends ChangeNotifier {
  final UserRepository repository;
  Timer? _debounceTimer;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<UserModel> _members = [];
  int _totalCount = 448;
  int _totalPages = 5;
  int _currentPage = 0;
  int _pageSize = 100;
  bool _hasNext = false;

  String _searchQuery = '';
  TeamFilterModel _filter = const TeamFilterModel();

  final Set<String> _availableRoles = {'ADMIN', 'PROJECT_MANAGER', 'ENGINEER', 'SUPERVISOR', 'OPERATOR', 'VENDOR', 'VIEWER'};
  final Set<String> _availableVendors = {};

  TeamController({required this.repository});

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  List<UserModel> get members => _members;
  int get loadedCount => _members.length;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  int get displayPageNumber => _currentPage + 1;
  int get pageSize => _pageSize;
  bool get hasNext => _hasNext;
  String get searchQuery => _searchQuery;
  TeamFilterModel get filter => _filter;

  List<String> get availableRoles => _availableRoles.toList()..sort();
  List<String> get availableVendors => _availableVendors.toList()..sort();

  // Calculated Stats from loaded records
  int get loadedActiveCount => _members.where((m) => m.isActive).length;
  int get loadedInactiveCount => _members.where((m) => !m.isActive).length;
  int get loadedVendorCount => _availableVendors.length;

  /// Filtered Team Members list based on Search and Filter selections
  List<UserModel> get filteredMembers {
    return _members.where((m) {
      // 1. Status Filter
      if (_filter.status == 'ACTIVE' && !m.isActive) return false;
      if (_filter.status == 'INACTIVE' && m.isActive) return false;

      // 2. Role Filter
      if (_filter.role != 'ALL') {
        final rFilter = _filter.role.toUpperCase();
        final matchesRole = m.role.toUpperCase() == rFilter ||
            m.roles.map((r) => r.toUpperCase()).contains(rFilter);
        if (!matchesRole) return false;
      }

      // 3. Vendor Filter
      if (_filter.vendor != 'ALL') {
        if (m.displayVendor.toLowerCase() != _filter.vendor.toLowerCase()) {
          return false;
        }
      }

      // 4. Search Query Filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameMatch = m.displayName.toLowerCase().contains(q);
        final usernameMatch = m.username.toLowerCase().contains(q);
        final empIdMatch = m.displayEmployeeId.toLowerCase().contains(q);
        final emailMatch = m.email.toLowerCase().contains(q);
        final phoneMatch = (m.phoneNumber ?? '').toLowerCase().contains(q);
        final vendorMatch = m.displayVendor.toLowerCase().contains(q);
        final roleMatch = m.role.toLowerCase().contains(q) ||
            m.roles.any((r) => r.toLowerCase().contains(q));

        return nameMatch ||
            usernameMatch ||
            empIdMatch ||
            emailMatch ||
            phoneMatch ||
            vendorMatch ||
            roleMatch;
      }

      return true;
    }).toList();
  }

  /// Fetch team members page from API (size = 100)
  Future<void> fetchTeamMembers({int page = 0, bool isSilent = false}) async {
    if (!isSilent) {
      if (_members.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await repository.getUsersResponse(
        page: page,
        size: _pageSize,
        search: '',
      );

      if (page == 0) {
        _members = [];
      }

      _appendUniqueMembers(response.users);
      _totalCount = response.totalCount;
      _totalPages = response.totalPages;
      _currentPage = response.currentPage;
      _pageSize = response.pageSize;
      _hasNext = response.hasNext;

      _updateAvailableFilters(response.users);

      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRefreshing = false;
      if (_members.isEmpty) {
        _errorMessage = _formatErrorMessage(e);
      }
      notifyListeners();
    }
  }

  /// Load next page for infinite scroll / pagination
  Future<void> loadNextPage() async {
    if (!_hasNext || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPageNum = _currentPage + 1;
      final response = await repository.getUsersResponse(
        page: nextPageNum,
        size: _pageSize,
        search: '',
      );

      _appendUniqueMembers(response.users);
      _currentPage = response.currentPage;
      _totalPages = response.totalPages;
      _totalCount = response.totalCount;
      _hasNext = response.hasNext;

      _updateAvailableFilters(response.users);

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Prevent duplicates using user ID
  void _appendUniqueMembers(List<UserModel> newUsers) {
    for (final u in newUsers) {
      final existingIndex = _members.indexWhere((existing) => existing.id == u.id);
      if (existingIndex != -1) {
        _members[existingIndex] = u;
      } else {
        _members.add(u);
      }
    }
  }

  /// Aggregates distinct roles and vendors for dynamic filter options
  void _updateAvailableFilters(List<UserModel> loaded) {
    for (final m in loaded) {
      if (m.role.isNotEmpty) _availableRoles.add(m.role.toUpperCase());
      for (final r in m.roles) {
        if (r.isNotEmpty) _availableRoles.add(r.toUpperCase());
      }
      final vName = m.displayVendor;
      if (vName.isNotEmpty && vName != 'Unassigned Vendor') {
        _availableVendors.add(vName);
      }
    }
  }

  /// Update search query with 300ms debouncing
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      notifyListeners();
    });
  }

  /// Apply filter model
  void applyFilter(TeamFilterModel newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  /// Clear all search queries and active filters
  void clearFilters() {
    _filter = const TeamFilterModel();
    _searchQuery = '';
    notifyListeners();
  }

  /// Format user-friendly error messages
  String _formatErrorMessage(dynamic e) {
    final str = e.toString().toLowerCase();

    if (str.contains('401') || str.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (str.contains('403') || str.contains('forbidden')) {
      return 'You don\'t have permission to view the team.';
    }
    if (str.contains('504') || str.contains('timeout') || str.contains('devtunnel') || str.contains('html')) {
      return 'Unable to connect to the Team service. Please check that the development API tunnel is running.';
    }
    if (str.contains('network') || str.contains('socket') || str.contains('connection')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    return 'Unable to load team members. Please check your network or try again.';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
