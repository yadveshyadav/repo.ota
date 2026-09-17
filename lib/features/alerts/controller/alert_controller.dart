import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../models/alert.dart';
import '../../../models/app_notification.dart';
import '../../../repositories/alert_repository.dart';
import '../../../services/notification_service.dart';

/// State Controller managing real-time Alert fetching, 20-second background polling,
/// app lifecycle integration, baseline ID tracking, deduplication, search, filters, and in-app banners.
class AlertController extends ChangeNotifier with WidgetsBindingObserver {
  final AlertRepository repository;
  final Duration pollingInterval;

  Timer? _debounceTimer;
  Timer? _pollingTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _isDisposed = false;
  String? _errorMessage;

  List<Alert> _alerts = [];
  int _totalCount = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasNext = false;

  String _searchQuery = '';
  String _selectedSeverity = 'ALL';

  // Real-time tracking & deduplication
  final Set<String> _seenAlertIds = {};
  bool _isBaselineEstablished = false;

  AlertController({
    AlertRepository? repository,
    this.pollingInterval = const Duration(seconds: 20),
  }) : repository = repository ?? ApiAlertRepository() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<Alert> get alerts => _filteredAlerts();
  List<Alert> get rawAlerts => _alerts;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  bool get hasNext => _hasNext;
  String get searchQuery => _searchQuery;
  String get selectedSeverity => _selectedSeverity;

  int get unreadCount => _alerts.where((a) => !a.isRead).length;
  int get criticalCount => _alerts.where((a) => a.isCritical).length;
  int get warningCount => _alerts.where((a) => a.isWarning).length;
  int get infoCount => _alerts.where((a) => a.isInfo).length;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      fetchAlerts(isPolling: true);
      startAutoRefresh();
    }
  }

  /// Start 20-second controlled background polling
  void startAutoRefresh() {
    stopAutoRefresh();
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      fetchAlerts(isPolling: true);
    });
  }

  /// Stop background polling
  void stopAutoRefresh() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Fetch paginated alerts from API with baseline tracking & new alert detection
  Future<void> fetchAlerts({
    int page = 1,
    bool isSilent = false,
    bool isPolling = false,
  }) async {
    if (_isDisposed) return;

    if (!isSilent && !isPolling) {
      if (_alerts.isEmpty) {
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
      final response = await repository.getAlerts(
        page: page,
        size: _pageSize,
        severity: _selectedSeverity,
        search: _searchQuery,
      );

      if (_isDisposed) return;

      final incomingAlerts = response.alerts;

      if (!_isBaselineEstablished) {
        // Initial load: Establish baseline tracking without firing pop-up notifications
        for (final a in incomingAlerts) {
          _seenAlertIds.add(a.id);
        }
        _isBaselineEstablished = true;
        _alerts = List.from(incomingAlerts);
      } else {
        // Subsequent poll / refresh: Detect newly created alerts
        final newAlerts = <Alert>[];
        for (final a in incomingAlerts) {
          if (!_seenAlertIds.contains(a.id)) {
            _seenAlertIds.add(a.id);
            newAlerts.add(a);
          }
        }

        if (page == 1) {
          // Replace or prepend
          final existingMap = {for (final a in _alerts) a.id: a};
          for (final a in incomingAlerts) {
            existingMap[a.id] = a;
          }
          _alerts = existingMap.values.toList();
          _alerts.sort((a, b) {
            final dtA = a.createdAt ?? DateTime.now();
            final dtB = b.createdAt ?? DateTime.now();
            return dtB.compareTo(dtA);
          });
        } else {
          final existingIds = _alerts.map((a) => a.id).toSet();
          for (final a in incomingAlerts) {
            if (!existingIds.contains(a.id)) {
              _alerts.add(a);
            }
          }
        }

        // Deliver top in-app banner & notification for newly detected alerts
        if (newAlerts.isNotEmpty && (isPolling || isSilent)) {
          for (final alert in newAlerts) {
            _deliverNewAlertNotification(alert);
          }
        }
      }

      _totalCount = response.totalCount;
      _totalPages = response.totalPages;
      _currentPage = response.currentPage;
      _hasNext = response.hasNext;
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      if (kDebugMode) {
        print('[AlertController] fetchAlerts error: $e');
      }
      _isLoading = false;
      _isRefreshing = false;
      if (_alerts.isEmpty) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
    }
  }

  /// Deliver in-app top pop-up notification & register notification event
  void _deliverNewAlertNotification(Alert alert) {
    final notifType = alert.isCritical
        ? 'CRITICAL_ALERT'
        : alert.isWarning
            ? 'WARNING_ALERT'
            : 'INFO_ALERT';

    final appNotif = AppNotification(
      id: 'NOTIF_ALERT_${alert.id}',
      recipientId: 'all',
      type: notifType,
      title: alert.title,
      message: '${alert.message} (${alert.chassisNumber})',
      createdAt: alert.createdAt ?? DateTime.now(),
    );

    NotificationService().addNotification(
      appNotif,
      showPopup: true,
    );
  }

  /// Load next page for pagination / infinite scroll
  Future<void> loadNextPage() async {
    if (!_hasNext || _isLoadingMore || _isDisposed) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await repository.getAlerts(
        page: nextPage,
        size: _pageSize,
        severity: _selectedSeverity,
        search: _searchQuery,
      );

      final existingIds = _alerts.map((a) => a.id).toSet();
      for (final a in response.alerts) {
        _seenAlertIds.add(a.id);
        if (!existingIds.contains(a.id)) {
          _alerts.add(a);
        }
      }

      _currentPage = response.currentPage;
      _hasNext = response.hasNext;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Mark specific alert as read
  Future<bool> markAsRead(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isRead: true);
      notifyListeners();
    }

    try {
      final success = await repository.markAsRead(alertId);
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Set severity filter chip
  void setSeverityFilter(String severity) {
    if (_selectedSeverity == severity) return;
    _selectedSeverity = severity;
    _currentPage = 1;
    fetchAlerts(page: 1);
  }

  /// Update search query with debouncing
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _currentPage = 1;
      fetchAlerts(page: 1);
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        _currentPage = 1;
        fetchAlerts(page: 1);
      });
    }
  }

  /// Filter active list locally for fast UI responsiveness
  List<Alert> _filteredAlerts() {
    return _alerts.where((alert) {
      if (_selectedSeverity != 'ALL') {
        if (alert.severity.toUpperCase() != _selectedSeverity.toUpperCase()) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = alert.title.toLowerCase().contains(q);
        final matchMsg = alert.message.toLowerCase().contains(q);
        final matchChassis = alert.chassisNumber.toLowerCase().contains(q);
        final matchVendor = alert.vendorName?.toLowerCase().contains(q) ?? false;
        final matchType = alert.alertType?.toLowerCase().contains(q) ?? false;

        if (!matchTitle && !matchMsg && !matchChassis && !matchVendor && !matchType) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopAutoRefresh();
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
