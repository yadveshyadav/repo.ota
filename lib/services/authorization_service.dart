import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';
import '../models/role_model.dart';

/// Centralized Authorization Service managing effective user permissions and RBAC logic.
class AuthorizationService extends ChangeNotifier {
  static final AuthorizationService _instance = AuthorizationService._internal();
  factory AuthorizationService() => _instance;
  static AuthorizationService get instance => _instance;

  AuthorizationService._internal();

  UserModel? _currentUser;
  Set<String> _effectivePermissions = <String>{};
  List<RoleModel> _allSystemRoles = <RoleModel>[];

  UserModel? get currentUser => _currentUser;
  Set<String> get effectivePermissions => Set.unmodifiable(_effectivePermissions);

  /// Initialize authorization state for the current logged-in user.
  void initialize({
    UserModel? user,
    List<RoleModel>? roles,
    List<String>? directPermissions,
  }) {
    if (roles != null) {
      _allSystemRoles = List.from(roles);
    }

    if (user != null) {
      _currentUser = user;
    }

    _recalculatePermissions(directPermissions);
    notifyListeners();
  }

  /// Update active roles and permissions for current user
  void updatePermissions({
    required List<String> permissions,
    UserModel? updatedUser,
  }) {
    if (updatedUser != null) {
      _currentUser = updatedUser;
    }
    _effectivePermissions = Set.from(permissions);
    notifyListeners();
  }

  /// Helper to normalize role strings (e.g. "Fleet Admin" -> "FLEET_ADMIN")
  static String _normalizeRole(String role) {
    return role.trim().toUpperCase().replaceAll(' ', '_');
  }

  /// Recalculate effective permissions from user roles and direct permissions.
  void _recalculatePermissions(List<String>? directPermissions) {
    final permissions = <String>{};

    if (_currentUser == null) {
      _effectivePermissions = permissions;
      return;
    }

    // 1. Direct permissions from user model
    if (_currentUser!.permissions.isNotEmpty) {
      permissions.addAll(_currentUser!.permissions);
    }

    if (directPermissions != null && directPermissions.isNotEmpty) {
      permissions.addAll(directPermissions);
    }

    // 2. Permissions derived from registered system roles
    if (_currentUser!.roles.isNotEmpty && _allSystemRoles.isNotEmpty) {
      for (final roleCode in _currentUser!.roles) {
        final normCode = _normalizeRole(roleCode);
        final matchedRole = _allSystemRoles.firstWhere(
          (r) => _normalizeRole(r.code) == normCode || _normalizeRole(r.name) == normCode,
          orElse: () => RoleModel(id: 0, name: roleCode, code: roleCode),
        );
        if (matchedRole.permissionCodes.isNotEmpty) {
          permissions.addAll(matchedRole.permissionCodes);
        }
      }
    }

    // 3. Role-based Default Permissions
    final rawUserRoles = <String>{};
    rawUserRoles.addAll(_currentUser!.roles);
    if (_currentUser!.role.isNotEmpty) {
      rawUserRoles.add(_currentUser!.role);
    }
    final userRoles = rawUserRoles.map((r) => _normalizeRole(r)).toSet();

    final isAdminUser = _currentUser!.isAdmin ||
        userRoles.contains('ADMIN') ||
        userRoles.contains('FLEET_ADMIN') ||
        userRoles.contains('FLEETADMIN');

    if (isAdminUser) {
      permissions.addAll([
        'dashboard.view',
        'machines.view', 'machines.create', 'machines.update', 'machines.delete', 'machines.manage',
        'tracking.view',
        'tasks.view', 'tasks.create', 'tasks.update', 'tasks.delete', 'tasks.manage',
        'team.view', 'attendance.view', 'attendance.approve', 'expenses.view', 'fuel.view', 'refuel.view',
        'maintenance.view', 'breakdowns.view', 'inventory.view', 'inventory.manage',
        'vendors.view', 'vendors.manage',
        'users.view', 'users.create', 'users.update', 'users.delete', 'users.manage',
        'roles.view', 'roles.create', 'roles.update', 'roles.delete', 'roles.manage',
        'reports.view', 'notifications.view', 'settings.view', 'settings.manage', 'mapview.view',
      ]);
    } else if (permissions.isEmpty) {
      // Apply role-based default capability sets only if no explicit permissions were supplied from API
      if (userRoles.contains('PROJECT_MANAGER') || userRoles.contains('PROJECTMANAGER')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'machines.manage', 'tracking.view',
          'tasks.view', 'tasks.create', 'tasks.update', 'tasks.delete',
          'team.view', 'attendance.view', 'attendance.approve', 'expenses.view', 'fuel.view', 'refuel.view',
          'maintenance.view', 'breakdowns.view', 'inventory.view', 'inventory.manage',
          'vendors.view', 'users.view', 'reports.view', 'notifications.view', 'settings.view', 'mapview.view',
        ]);
      } else if (userRoles.contains('ENGINEER') || userRoles.contains('SITE_ENGINEER')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view',
          'tasks.view', 'tasks.create', 'tasks.update', 'attendance.view', 'team.view',
          'maintenance.view', 'breakdowns.view', 'inventory.view',
          'reports.view', 'notifications.view', 'mapview.view',
        ]);
      } else if (userRoles.contains('SUPERVISOR')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view',
          'tasks.view', 'tasks.update', 'attendance.view', 'attendance.approve', 'team.view',
          'fuel.view', 'refuel.view', 'notifications.view', 'mapview.view',
        ]);
      } else if (userRoles.contains('OPERATOR')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view', 'tasks.view', 'team.view',
          'attendance.view', 'fuel.view', 'refuel.view', 'notifications.view',
        ]);
      } else if (userRoles.contains('VENDOR')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view', 'tasks.view',
          'team.view', 'attendance.view', 'attendance.approve',
          'maintenance.view', 'breakdowns.view', 'fuel.view', 'refuel.view', 'reports.view', 'notifications.view',
        ]);
      } else if (userRoles.contains('VIEWER')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view', 'reports.view', 'mapview.view',
        ]);
      } else if (userRoles.contains('ALL_VIEWER') || userRoles.contains('ALLVIEWER')) {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view', 'tasks.view', 'team.view',
          'attendance.view', 'expenses.view', 'fuel.view', 'refuel.view',
          'maintenance.view', 'breakdowns.view', 'inventory.view',
          'vendors.view', 'users.view', 'roles.view', 'reports.view', 'notifications.view', 'settings.view', 'mapview.view',
        ]);
      } else {
        permissions.addAll([
          'dashboard.view', 'machines.view', 'tracking.view', 'tasks.view', 'attendance.view', 'team.view', 'reports.view', 'notifications.view',
        ]);
      }
    }

    _effectivePermissions = permissions;
  }

  /// Core authorization check: checks if user has capability for [permissionCode]
  bool can(String permissionCode) {
    if (permissionCode.isEmpty) return true;

    // Direct match check
    if (_effectivePermissions.contains(permissionCode)) {
      return true;
    }

    // Hierarchy check: module.manage grants module.create, module.update, module.delete, module.view, etc.
    if (permissionCode.contains('.')) {
      final parts = permissionCode.split('.');
      final module = parts.first;
      final managePermission = '$module.manage';

      if (_effectivePermissions.contains(managePermission)) {
        return true;
      }
    }

    return false;
  }

  /// Returns true if user has ANY of the provided permissions
  bool canAny(List<String> permissions) {
    if (permissions.isEmpty) return true;
    return permissions.any((p) => can(p));
  }

  /// Returns true if user has ALL of the provided permissions
  bool canAll(List<String> permissions) {
    if (permissions.isEmpty) return true;
    return permissions.every((p) => can(p));
  }

  /// Clear session state on logout
  void clear() {
    _currentUser = null;
    _effectivePermissions.clear();
    _allSystemRoles.clear();
    notifyListeners();
  }
}
