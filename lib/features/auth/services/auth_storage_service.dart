import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/attendance_storage_service.dart';
import '../models/auth_token.dart';
import '../models/user_model.dart';

/// Centralized Persistent Session & Token Storage Service
/// Implements rolling 10-day inactivity timeout session persistence
class AuthStorageService {
  static final AuthStorageService _instance = AuthStorageService._internal();
  factory AuthStorageService() => _instance;
  AuthStorageService._internal();

  static const String _keyAccessToken = 'hero_access_token';
  static const String _keyUatTaskAccessToken = 'uat_task_access_token';
  static const String _keyDevTaskAccessToken = 'dev_task_access_token';
  static const String _keyProdTaskAccessToken = 'prod_task_access_token';
  static const String _keyRefreshToken = 'hero_refresh_token';
  static const String _keyUserJson = 'hero_user_json';
  static const String _keyLastActiveAt = 'hero_last_active_at';
  static const String _keyIsLoggedIn = 'hero_is_logged_in';
  static const String _keyAuthBaseUrl = 'hero_auth_base_url';

  /// Maximum allowed inactivity duration before auto-logout (10 consecutive days)
  static const Duration maxInactivityDuration = Duration(days: 10);

  String? _accessToken;
  String? _uatTaskAccessToken;
  String? _devTaskAccessToken;
  String? _prodTaskAccessToken;
  String? _refreshToken;
  String? _authBaseUrl;
  UserModel? _currentUser;
  DateTime? _lastActiveAt;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  String? get accessToken => _accessToken;
  String? get uatTaskAccessToken => _uatTaskAccessToken;
  String? get devTaskAccessToken => _devTaskAccessToken;
  String? get prodTaskAccessToken => _prodTaskAccessToken;
  String? get refreshToken => _refreshToken;
  String? get authBaseUrl => _authBaseUrl;
  UserModel? get currentUser => _currentUser;
  DateTime? get lastActiveAt => _lastActiveAt;

  /// Returns true if session exists, user is authenticated, and inactivity duration < 10 days
  bool get isLoggedIn {
    if (!_isLoggedIn ||
        _accessToken == null ||
        _accessToken!.isEmpty ||
        _currentUser == null) {
      return false;
    }
    return !isSessionExpiredByInactivity;
  }

  /// Calculates whether inactivity duration >= 10 days
  bool get isSessionExpiredByInactivity {
    if (_lastActiveAt == null) return false;
    final inactivity = DateTime.now().difference(_lastActiveAt!);
    return inactivity >= maxInactivityDuration;
  }

  /// Initialize persistent storage and restore active session if < 10 days inactive
  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final savedToken = prefs.getString(_keyAccessToken);
      _uatTaskAccessToken = prefs.getString(_keyUatTaskAccessToken);
      _devTaskAccessToken = prefs.getString(_keyDevTaskAccessToken);
      _prodTaskAccessToken = prefs.getString(_keyProdTaskAccessToken);
      final savedRefreshToken = prefs.getString(_keyRefreshToken);
      _authBaseUrl = prefs.getString(_keyAuthBaseUrl);
      final savedUserJson = prefs.getString(_keyUserJson);
      final savedLastActiveStr = prefs.getString(_keyLastActiveAt);

      if (savedLoggedIn && savedToken != null && savedToken.isNotEmpty) {
        DateTime? parsedLastActive;
        if (savedLastActiveStr != null && savedLastActiveStr.isNotEmpty) {
          parsedLastActive = DateTime.tryParse(savedLastActiveStr);
        }

        UserModel? parsedUser;
        if (savedUserJson != null && savedUserJson.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(savedUserJson);
            parsedUser = UserModel.fromJson(map);
          } catch (e) {
            if (kDebugMode) {
              print('[AuthStorageService] Error parsing saved user json: $e');
            }
          }
        }

        parsedUser ??= const UserModel(
          id: '1',
          username: 'admin',
          email: 'admin@hero.com',
          name: 'Fleet Admin',
        );

        _accessToken = savedToken;
        _refreshToken = savedRefreshToken;
        _currentUser = parsedUser;
        _lastActiveAt = parsedLastActive ?? DateTime.now();
        _isLoggedIn = true;

        // Check rolling 10-day inactivity timeout
        if (isSessionExpiredByInactivity) {
          final daysInactive = DateTime.now().difference(_lastActiveAt!).inDays;
          if (kDebugMode) {
            print(
              '[AuthStorageService] Session expired due to $daysInactive days of inactivity (>= 10 days). Clearing session.',
            );
          }
          await clearSession();
        } else {
          // Session is valid! Touch lastActiveAt to reset 10-day inactivity timer for latest opening
          await touchLastActive();
          if (kDebugMode) {
            print(
              '[AuthStorageService] Restored valid session for ${_currentUser?.fullName}. Updated lastActiveAt to ${DateTime.now()}.',
            );
          }
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthStorageService] Init error: $e');
      }
    } finally {
      _isInitialized = true;
    }
  }

  /// Save active session details upon successful authentication
  Future<void> saveSession({
    required AuthToken token,
    UserModel? user,
    String? authBaseUrl,
  }) async {
    final now = DateTime.now();

    _accessToken = token.accessToken;
    _refreshToken = token.refreshToken;
    _authBaseUrl = authBaseUrl;
    _currentUser =
        user ??
        const UserModel(id: '1', username: 'admin', email: 'admin@hero.com');
    _lastActiveAt = now;
    _isLoggedIn = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, token.accessToken);
      await prefs.setString(_keyRefreshToken, token.refreshToken ?? '');
      if (_authBaseUrl != null && _authBaseUrl!.isNotEmpty) {
        await prefs.setString(_keyAuthBaseUrl, _authBaseUrl!);
      } else {
        await prefs.remove(_keyAuthBaseUrl);
      }
      await prefs.setString(_keyUserJson, jsonEncode(_currentUser!.toJson()));
      await prefs.setString(_keyLastActiveAt, now.toIso8601String());
      await prefs.setBool(_keyIsLoggedIn, true);
    } catch (e) {
      if (kDebugMode) {
        print('[AuthStorageService] Save session error: $e');
      }
    }
  }

  /// Update rolling inactivity timestamp whenever app is opened or actively used
  Future<void> touchLastActive() async {
    final now = DateTime.now();
    _lastActiveAt = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastActiveAt, now.toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('[AuthStorageService] Touch last active error: $e');
      }
    }
  }

  Future<void> saveUatTaskAccessToken(String token) async {
    _uatTaskAccessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUatTaskAccessToken, token);
  }

  Future<void> saveDevTaskAccessToken(String token) async {
    _devTaskAccessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDevTaskAccessToken, token);
  }

  Future<void> saveProdTaskAccessToken(String token) async {
    _prodTaskAccessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProdTaskAccessToken, token);
  }

  /// Update current user profile
  Future<void> updateUser(UserModel user) async {
    _currentUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserJson, jsonEncode(user.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('[AuthStorageService] Update user error: $e');
      }
    }
  }

  /// Clear all stored tokens and session data on explicit logout or 10-day inactivity expiration
  Future<void> clearSession() async {
    _accessToken = null;
    _uatTaskAccessToken = null;
    _devTaskAccessToken = null;
    _prodTaskAccessToken = null;
    _refreshToken = null;
    _authBaseUrl = null;
    _currentUser = null;
    _lastActiveAt = null;
    _isLoggedIn = false;
    _isInitialized = false;

    await AttendanceStorageService().clearAllRecords();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyUatTaskAccessToken);
      await prefs.remove(_keyDevTaskAccessToken);
      await prefs.remove(_keyProdTaskAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyAuthBaseUrl);
      await prefs.remove(_keyUserJson);
      await prefs.remove(_keyLastActiveAt);
      await prefs.remove(_keyIsLoggedIn);
    } catch (e) {
      if (kDebugMode) {
        print('[AuthStorageService] Clear session error: $e');
      }
    }
  }
}
