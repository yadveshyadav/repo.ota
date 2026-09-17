import 'package:flutter/foundation.dart';
import '../../../repositories/auth_repository.dart';
import '../models/user_model.dart';

/// State Controller managing Login and Authentication lifecycle
class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

  AuthController({required this.repository});

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => repository.isLoggedIn() || _currentUser != null;

  /// Perform authentication request to real login API endpoint
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await repository.login(
        username: username,
        password: password,
      );

      _currentUser = user;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _formatErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Perform logout and clear tokens
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await repository.logout();
    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Check saved authentication state during splash boot
  Future<bool> checkAuthBoot() async {
    if (repository.isLoggedIn()) {
      _currentUser = await repository.getCurrentUser();
      notifyListeners();
      return _currentUser != null;
    }
    return false;
  }

  /// Format user-friendly error message based on exception
  String _formatErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();

    if (str.contains('400') || str.contains('401') || str.contains('invalid') || str.contains('credential')) {
      return 'Invalid username or password.';
    }
    if (str.contains('403')) {
      return 'Access denied. You do not have permission to log in.';
    }
    if (str.contains('404')) {
      return 'Authentication endpoint not found on server.';
    }
    if (str.contains('429')) {
      return 'Too many login attempts. Please try again later.';
    }
    if (str.contains('500') || str.contains('server error')) {
      return 'Something went wrong on the server. Please try again.';
    }
    if (str.contains('network') || str.contains('socket') || str.contains('connection') || str.contains('timeout')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    return 'Login failed. Please verify your credentials and try again.';
  }
}
