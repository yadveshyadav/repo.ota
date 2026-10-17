import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/features/team/controller/team_controller.dart';
import 'package:hero_app/features/team/screens/team_member_detail_screen.dart';
import 'package:hero_app/features/team/screens/team_screen.dart';
import 'package:hero_app/features/team/widgets/team_member_card.dart';
import 'package:hero_app/models/user_response.dart';
import 'package:hero_app/repositories/user_repository.dart';
import 'package:hero_app/services/authorization_service.dart';

class MockUserRepository implements UserRepository {
  List<UserModel> mockUsers = [];
  int mockTotal = 448;
  int mockTotalPages = 5;

  MockUserRepository() {
    mockUsers = List.generate(
      100,
      (index) => UserModel(
        id: 'user_${index + 1}',
        username: index == 0 ? '8764129290' : '9876500${index + 10}',
        email: 'user${index + 1}@telecrats.com',
        name: index == 0 ? 'Kulwinder Singh' : 'Staff Member ${index + 1}',
        role: index % 3 == 0 ? 'SUPERVISOR' : (index % 2 == 0 ? 'ENGINEER' : 'OPERATOR'),
        roles: const ['SUPERVISOR', 'OPERATOR'],
        permissions: const ['breakdowns.view', 'attendance.view', 'stock.view', 'team.view'],
        vendorName: 'Telecrats',
        phoneNumber: '8764129290',
        employeeId: index == 0 ? '8764129290' : 'EMP-${index + 100}',
        isActive: index % 5 != 0,
        dateJoined: DateTime(2026, 1, 15),
      ),
    );
  }

  @override
  Future<UserResponse> getUsersResponse({
    int page = 0,
    int size = 100,
    String search = '',
  }) async {
    return UserResponse(
      users: mockUsers,
      totalCount: mockTotal,
      totalPages: mockTotalPages,
      currentPage: page,
      pageSize: size,
      hasNext: page + 1 < mockTotalPages,
      hasPrevious: page > 0,
    );
  }

  @override
  Future<List<UserModel>> getUsers({int page = 0, String search = ''}) async => mockUsers;

  @override
  Future<UserModel> createUser({
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async =>
      mockUsers.first;

  @override
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async =>
      mockUsers.first;

  @override
  Future<bool> deleteUser(String id) async => true;
}

void main() {
  group('UserModel & UserResponse API Parser Tests', () {
    test('Parses full team member API JSON payload correctly', () {
      final json = {
        'id': '6a7c2b4f8e16e804697f18b0',
        'username': '8764129290',
        'name': 'Kulwinder Singh',
        'email': 'kulwinder@telecrats.com',
        'employee_id': '8764129290',
        'phone_number': '8764129290',
        'vendor_name': 'Telecrats',
        'role': 'SUPERVISOR',
        'roles': ['SUPERVISOR', 'OPERATOR'],
        'permissions': ['breakdowns.view', 'attendance.view', 'team.view'],
        'is_active': true,
        'date_joined': '2026-01-15T10:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, '6a7c2b4f8e16e804697f18b0');
      expect(user.username, '8764129290');
      expect(user.displayName, 'Kulwinder Singh');
      expect(user.displayEmployeeId, '8764129290');
      expect(user.displayVendor, 'Telecrats');
      expect(user.role, 'SUPERVISOR');
      expect(user.isActive, isTrue);
      expect(user.initials, 'KS');
    });

    test('Parses UserResponse paginated structure with 448 count and 5 pages', () {
      final json = {
        'success': true,
        'message': 'Request successful',
        'data': {
          'count': 448,
          'total': 448,
          'page': 0,
          'size': 100,
          'total_pages': 5,
          'results': [
            {
              'id': '101',
              'username': '8764129290',
              'name': 'Kulwinder Singh',
              'role': 'SUPERVISOR',
            }
          ]
        }
      };

      final response = UserResponse.fromJson(json);

      expect(response.users.length, 1);
      expect(response.totalCount, 448);
      expect(response.totalPages, 5);
      expect(response.currentPage, 0);
      expect(response.pageSize, 100);
      expect(response.hasNext, isTrue);
    });
  });

  group('TeamController Unit Tests', () {
    late MockUserRepository mockRepo;
    late TeamController controller;

    setUp(() {
      mockRepo = MockUserRepository();
      controller = TeamController(repository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial fetch loads page 0 and retains total 448 metadata', () async {
      await controller.fetchTeamMembers(page: 0);

      expect(controller.isLoading, isFalse);
      expect(controller.loadedCount, 100);
      expect(controller.totalCount, 448);
      expect(controller.totalPages, 5);
      expect(controller.members.first.displayName, 'Kulwinder Singh');
    });

    test('Searching by name filters loaded members correctly', () async {
      await controller.fetchTeamMembers(page: 0);

      controller.setSearchQuery('Kulwinder');

      expect(controller.filteredMembers.length, 1);
      expect(controller.filteredMembers.first.displayName, 'Kulwinder Singh');
    });

    test('Filtering by active status updates filtered list', () async {
      await controller.fetchTeamMembers(page: 0);

      controller.applyFilter(controller.filter.copyWith(status: 'ACTIVE'));

      expect(controller.filteredMembers.every((m) => m.isActive), isTrue);
    });
  });

  group('TeamScreen & Component Widget Tests', () {
    setUp(() {
      AuthorizationService.instance.initialize(
        user: const UserModel(
          id: '1',
          username: 'admin',
          email: 'admin@hero.com',
          role: 'ADMIN',
          roles: ['ADMIN'],
        ),
      );
    });

    testWidgets('Renders TeamMemberCard with avatar, role, vendor, and action button',
        (tester) async {
      const member = UserModel(
        id: '1',
        username: '8764129290',
        email: 'kulwinder@telecrats.com',
        name: 'Kulwinder Singh',
        role: 'SUPERVISOR',
        vendorName: 'Telecrats',
        employeeId: '8764129290',
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeamMemberCard(
              member: member,
              onViewDetails: () {},
            ),
          ),
        ),
      );

      expect(find.text('Kulwinder Singh'), findsOneWidget);
      expect(find.text('Username: 8764129290'), findsOneWidget);
      expect(find.text('SUPERVISOR'), findsOneWidget);
      expect(find.text('Telecrats'), findsOneWidget);
      expect(find.text('• ACTIVE'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('Renders TeamScreen header, summary cards, and search bar',
        (tester) async {
      final mockRepo = MockUserRepository();
      final controller = TeamController(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: TeamScreen(
            repository: mockRepo,
            controller: controller,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Team & Staff Management'), findsOneWidget);
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('448'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Renders TeamMemberDetailScreen with profile, permissions, and vendor info',
        (tester) async {
      const member = UserModel(
        id: '1',
        username: '8764129290',
        email: 'kulwinder@telecrats.com',
        name: 'Kulwinder Singh',
        role: 'SUPERVISOR',
        roles: ['SUPERVISOR', 'OPERATOR'],
        permissions: ['breakdowns.view', 'attendance.view', 'team.view'],
        vendorName: 'Telecrats',
        employeeId: '8764129290',
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TeamMemberDetailScreen(member: member),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Team Member Profile'), findsOneWidget);
      expect(find.text('Kulwinder Singh'), findsOneWidget);
      expect(find.text('ROLE & PERMISSIONS'), findsOneWidget);
      expect(find.text('VENDOR ASSIGNMENT'), findsOneWidget);
    });
  });
}
