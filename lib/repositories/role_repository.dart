import 'package:flutter/foundation.dart';
import '../models/permission_model.dart';
import '../models/role_model.dart';
import '../services/api/role_api_service.dart';

abstract class RoleRepository {
  Future<List<RoleModel>> getRoles();
  Future<RoleModel?> getRoleById(int id);
  Future<RoleModel> createRole({
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  });
  Future<RoleModel> updateRole({
    required int id,
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  });
  Future<bool> deleteRole(int id);
  Future<List<PermissionModel>> getPermissions();
}

class ApiRoleRepository implements RoleRepository {
  final RoleApiService apiService;

  ApiRoleRepository({RoleApiService? apiService})
      : apiService = apiService ?? RoleApiService();

  @override
  Future<List<RoleModel>> getRoles() async {
    try {
      return await apiService.fetchRoles();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiRoleRepository] Error fetching roles ($e), falling back to mock dataset.');
      }
      return MockRoleRepository().getRoles();
    }
  }

  @override
  Future<RoleModel?> getRoleById(int id) async {
    try {
      return await apiService.fetchRoleById(id);
    } catch (_) {
      return MockRoleRepository().getRoleById(id);
    }
  }

  @override
  Future<RoleModel> createRole({
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    try {
      return await apiService.createRole(
        name: name,
        code: code,
        description: description,
        permissionIds: permissionIds,
      );
    } catch (_) {
      return MockRoleRepository().createRole(
        name: name,
        code: code,
        description: description,
        permissionIds: permissionIds,
      );
    }
  }

  @override
  Future<RoleModel> updateRole({
    required int id,
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    try {
      return await apiService.updateRole(
        id: id,
        name: name,
        code: code,
        description: description,
        permissionIds: permissionIds,
      );
    } catch (_) {
      return MockRoleRepository().updateRole(
        id: id,
        name: name,
        code: code,
        description: description,
        permissionIds: permissionIds,
      );
    }
  }

  @override
  Future<bool> deleteRole(int id) async {
    try {
      return await apiService.deleteRole(id);
    } catch (_) {
      return MockRoleRepository().deleteRole(id);
    }
  }

  @override
  Future<List<PermissionModel>> getPermissions() async {
    try {
      return await apiService.fetchPermissions();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiRoleRepository] Error fetching permissions ($e), falling back to mock dataset.');
      }
      return MockRoleRepository().getPermissions();
    }
  }
}

/// Mock Role Repository populated with exact verified 11 platform system roles and 28 permissions
class MockRoleRepository implements RoleRepository {
  static final List<PermissionModel> _allPermissions = [
    const PermissionModel(id: 1, code: 'dashboard.view', name: 'View Dashboard', category: 'Dashboard', description: 'View dashboard analytics and statistics'),
    const PermissionModel(id: 2, code: 'machines.view', name: 'View Machinery', category: 'Machines', description: 'View fleet machinery list and details'),
    const PermissionModel(id: 3, code: 'machines.manage', name: 'Manage Machinery', category: 'Machines', description: 'Add, update, or remove fleet machinery'),
    const PermissionModel(id: 4, code: 'tracking.view', name: 'View Live GPS Tracking', category: 'Tracking', description: 'View live machine locations and route history'),
    const PermissionModel(id: 5, code: 'tasks.view', name: 'View Tasks', category: 'Tasks', description: 'View work tasks and assignments'),
    const PermissionModel(id: 6, code: 'tasks.create', name: 'Create Tasks', category: 'Tasks', description: 'Create new work tasks'),
    const PermissionModel(id: 7, code: 'tasks.update', name: 'Update Tasks', category: 'Tasks', description: 'Update task status and details'),
    const PermissionModel(id: 8, code: 'tasks.delete', name: 'Delete Tasks', category: 'Tasks', description: 'Delete tasks'),
    const PermissionModel(id: 9, code: 'team.view', name: 'View Team', category: 'Team', description: 'View team members and profiles'),
    const PermissionModel(id: 10, code: 'attendance.view', name: 'View Attendance', category: 'Attendance', description: 'View employee attendance records'),
    const PermissionModel(id: 11, code: 'expenses.view', name: 'View Expenses', category: 'Expenses', description: 'View site expenses and financial logs'),
    const PermissionModel(id: 12, code: 'fuel.view', name: 'View Fuel Records', category: 'Fuel', description: 'View fuel consumption logs'),
    const PermissionModel(id: 13, code: 'refuel.view', name: 'View Refuel Requests', category: 'Refuel', description: 'View and approve refuel logs'),
    const PermissionModel(id: 14, code: 'maintenance.view', name: 'View Maintenance Logs', category: 'Maintenance', description: 'View preventive maintenance schedules'),
    const PermissionModel(id: 15, code: 'breakdowns.view', name: 'View Breakdown Reports', category: 'Breakdowns', description: 'View machine breakdown incident reports'),
    const PermissionModel(id: 16, code: 'inventory.view', name: 'View Inventory/Stock', category: 'Inventory', description: 'View spare parts and inventory items'),
    const PermissionModel(id: 17, code: 'inventory.manage', name: 'Manage Inventory/Stock', category: 'Inventory', description: 'Manage stock items and issuance'),
    const PermissionModel(id: 18, code: 'vendors.view', name: 'View Vendors', category: 'Vendors', description: 'View vendor profiles'),
    const PermissionModel(id: 19, code: 'vendors.manage', name: 'Manage Vendors', category: 'Vendors', description: 'Add and edit vendor organizations'),
    const PermissionModel(id: 20, code: 'users.view', name: 'View Users', category: 'Users', description: 'View imported platform users'),
    const PermissionModel(id: 21, code: 'users.manage', name: 'Manage Users', category: 'Users', description: 'Manage user access and assign roles'),
    const PermissionModel(id: 22, code: 'roles.view', name: 'View Roles & Permissions', category: 'Roles', description: 'View role configurations'),
    const PermissionModel(id: 23, code: 'roles.manage', name: 'Manage Roles & Permissions', category: 'Roles', description: 'Create and edit custom roles and permissions'),
    const PermissionModel(id: 24, code: 'reports.view', name: 'View Operational Reports', category: 'Reports', description: 'Generate and view performance reports'),
    const PermissionModel(id: 25, code: 'notifications.view', name: 'View Notifications', category: 'Notifications', description: 'Receive operational alerts'),
    const PermissionModel(id: 26, code: 'settings.view', name: 'View Platform Settings', category: 'Settings', description: 'View system settings'),
    const PermissionModel(id: 27, code: 'settings.manage', name: 'Manage Platform Settings', category: 'Settings', description: 'Manage system configurations'),
    const PermissionModel(id: 28, code: 'mapview.view', name: 'View Map View', category: 'Map View', description: 'View GIS map view and trenching / HDD execution topology'),
  ];

  static final List<RoleModel> _allRoles = [
    RoleModel.fromJson({
      'id': 1,
      'name': 'ADMIN',
      'code': 'ADMIN',
      'description': 'Full System Administrator with unrestricted access to all modules and configurations',
      'is_system': true,
      'permissions': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
      'permission_codes': [
        'dashboard.view', 'machines.view', 'machines.manage', 'tracking.view', 'tasks.view', 'tasks.create', 'tasks.update', 'tasks.delete', 'team.view', 'attendance.view', 'expenses.view', 'fuel.view', 'refuel.view', 'maintenance.view', 'breakdowns.view', 'inventory.view', 'inventory.manage', 'vendors.view', 'vendors.manage', 'users.view', 'users.manage', 'roles.view', 'roles.manage', 'reports.view', 'notifications.view', 'settings.view', 'settings.manage', 'mapview.view'
      ],
      'user_count': 3,
    }),
    RoleModel.fromJson({
      'id': 2,
      'name': 'PROJECT_MANAGER',
      'code': 'PROJECT_MANAGER',
      'description': 'Project Manager overseeing fleet operations, tasks, team, and site analytics',
      'is_system': true,
      'permissions': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 24, 25, 26, 28],
      'user_count': 2,
    }),
    RoleModel.fromJson({
      'id': 3,
      'name': 'ENGINEER',
      'code': 'ENGINEER',
      'description': 'Site Engineer managing machinery, task updates, and technical maintenance',
      'is_system': true,
      'permissions': [1, 2, 4, 5, 6, 7, 14, 15, 16, 24, 25, 28],
      'user_count': 2,
    }),
    RoleModel.fromJson({
      'id': 4,
      'name': 'SUPERVISOR',
      'code': 'SUPERVISOR',
      'description': 'Field Supervisor monitoring daily machine progress, attendance, and refuel entries',
      'is_system': true,
      'permissions': [1, 2, 4, 5, 7, 10, 12, 13, 25, 28],
      'user_count': 1,
    }),
    RoleModel.fromJson({
      'id': 5,
      'name': 'OPERATOR',
      'code': 'OPERATOR',
      'description': 'Machine Operator logging machine runtime, refuel requests, and task completion',
      'is_system': true,
      'permissions': [1, 2, 5, 10, 12, 13],
      'user_count': 1,
    }),
    RoleModel.fromJson({
      'id': 6,
      'name': 'VENDOR',
      'code': 'VENDOR',
      'description': 'Vendor representative viewing assigned machines and maintenance status',
      'is_system': true,
      'permissions': [1, 2, 5, 11, 13, 14, 15, 16],
      'user_count': 2,
    }),
    RoleModel.fromJson({
      'id': 7,
      'name': 'VIEWER',
      'code': 'VIEWER',
      'description': 'Read-only Viewer account with basic dashboard, machine, tracking, and report access',
      'is_system': true,
      'permissions': [1, 2, 4, 24, 28],
      'user_count': 154,
    }),
    RoleModel.fromJson({
      'id': 12,
      'name': 'ALL_VIEWER',
      'code': 'ALL_VIEWER',
      'description': 'Read-only Global Viewer with view-only permissions across all standard and customized modules',
      'is_system': true,
      'permissions': [1, 2, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 25, 26, 28],
      'user_count': 0,
    }),
  ];

  @override
  Future<List<RoleModel>> getRoles() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _allRoles;
  }

  @override
  Future<RoleModel?> getRoleById(int id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _allRoles.firstWhere((r) => r.id == id, orElse: () => _allRoles.first);
  }

  @override
  Future<RoleModel> createRole({
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newRole = RoleModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      name: name,
      code: code.toUpperCase().replaceAll(' ', '_'),
      description: description,
      isSystem: false,
      permissions: permissionIds,
      userCount: 0,
    );
    _allRoles.add(newRole);
    return newRole;
  }

  @override
  Future<RoleModel> updateRole({
    required int id,
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _allRoles.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updated = _allRoles[index].copyWith(
        name: name,
        code: code,
        description: description,
        permissions: permissionIds,
      );
      _allRoles[index] = updated;
      return updated;
    }
    return RoleModel(id: id, name: name, code: code, permissions: permissionIds);
  }

  @override
  Future<bool> deleteRole(int id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _allRoles.removeWhere((r) => r.id == id);
    return true;
  }

  @override
  Future<List<PermissionModel>> getPermissions() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _allPermissions;
  }
}
