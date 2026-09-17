import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/models/role_model.dart';
import 'package:hero_app/services/authorization_service.dart';

void main() {
  group('AuthorizationService Unit Tests', () {
    late AuthorizationService authService;

    setUp(() {
      authService = AuthorizationService.instance;
      authService.clear();
    });

    test('ADMIN role initializes with full permissions capability', () {
      const user = UserModel(
        id: '1',
        username: 'admin',
        email: 'admin@hero.com',
        role: 'ADMIN',
        roles: ['ADMIN'],
      );

      authService.initialize(user: user);

      expect(authService.can('dashboard.view'), isTrue);
      expect(authService.can('machines.view'), isTrue);
      expect(authService.can('machines.create'), isTrue);
      expect(authService.can('machines.update'), isTrue);
      expect(authService.can('machines.delete'), isTrue);
      expect(authService.can('machines.manage'), isTrue);
      expect(authService.can('users.view'), isTrue);
      expect(authService.can('roles.view'), isTrue);
    });

    test('OPERATOR role initializes with restricted operator permissions', () {
      const user = UserModel(
        id: '5',
        username: 'operator',
        email: 'operator@hero.com',
        role: 'OPERATOR',
        roles: ['OPERATOR'],
      );

      authService.initialize(user: user);

      expect(authService.can('dashboard.view'), isTrue);
      expect(authService.can('machines.view'), isTrue);
      expect(authService.can('tasks.view'), isTrue);

      // Restricted permissions should return false
      expect(authService.can('machines.create'), isFalse);
      expect(authService.can('users.view'), isFalse);
      expect(authService.can('roles.view'), isFalse);
    });

    test('Hierarchical manage permission grants action capabilities', () {
      const user = UserModel(
        id: '10',
        username: 'custom_user',
        email: 'custom@hero.com',
        role: 'CUSTOM',
        roles: ['CUSTOM'],
        permissions: ['machines.manage'],
      );

      authService.initialize(user: user);

      // machines.manage should grant machines.create, machines.update, machines.delete
      expect(authService.can('machines.create'), isTrue);
      expect(authService.can('machines.update'), isTrue);
      expect(authService.can('machines.delete'), isTrue);
      expect(authService.can('machines.view'), isTrue);

      // Unrelated modules remain unauthorized
      expect(authService.can('users.manage'), isFalse);
      expect(authService.can('users.view'), isFalse);
    });

    test('canAny and canAll evaluate list of permission codes correctly', () {
      const user = UserModel(
        id: '2',
        username: 'pm',
        email: 'pm@hero.com',
        role: 'PROJECT_MANAGER',
        roles: ['PROJECT_MANAGER'],
      );

      authService.initialize(user: user);

      expect(authService.canAny(['machines.create', 'unauthorized.code']), isTrue);
      expect(authService.canAll(['dashboard.view', 'machines.view', 'tasks.view']), isTrue);
      expect(authService.canAll(['dashboard.view', 'roles.manage']), isFalse);
    });

    test('Custom role with dynamic permissions works automatically without code changes', () {
      final customRole = RoleModel(
        id: 99,
        name: 'SITE_OPERATOR',
        code: 'SITE_OPERATOR',
        isSystem: false,
        permissionCodes: const ['dashboard.view', 'machines.view', 'tasks.view', 'tasks.update'],
      );

      const user = UserModel(
        id: '12',
        username: 'site_op',
        email: 'siteop@hero.com',
        role: 'SITE_OPERATOR',
        roles: ['SITE_OPERATOR'],
      );

      authService.initialize(user: user, roles: [customRole]);

      expect(authService.can('dashboard.view'), isTrue);
      expect(authService.can('machines.view'), isTrue);
      expect(authService.can('tasks.view'), isTrue);
      expect(authService.can('tasks.update'), isTrue);

      expect(authService.can('machines.create'), isFalse);
      expect(authService.can('users.view'), isFalse);
    });

    test('Union of permissions for multiple assigned roles', () {
      final roleA = RoleModel(
        id: 101,
        name: 'Role A',
        code: 'ROLE_A',
        permissionCodes: const ['machines.view'],
      );

      final roleB = RoleModel(
        id: 102,
        name: 'Role B',
        code: 'ROLE_B',
        permissionCodes: const ['tasks.view'],
      );

      const user = UserModel(
        id: '15',
        username: 'multi_role_user',
        email: 'multi@hero.com',
        role: 'ROLE_A',
        roles: ['ROLE_A', 'ROLE_B'],
      );

      authService.initialize(user: user, roles: [roleA, roleB]);

      expect(authService.can('machines.view'), isTrue);
      expect(authService.can('tasks.view'), isTrue);
      expect(authService.can('users.view'), isFalse);
    });

    test('Logout clears authorization state completely', () {
      const user = UserModel(
        id: '1',
        username: 'admin',
        email: 'admin@hero.com',
        role: 'ADMIN',
        roles: ['ADMIN'],
      );

      authService.initialize(user: user);
      expect(authService.can('dashboard.view'), isTrue);

      authService.clear();

      expect(authService.effectivePermissions, isEmpty);
      expect(authService.currentUser, isNull);
    });
  });
}
