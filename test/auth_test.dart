import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/auth/controller/auth_controller.dart';
import 'package:hero_app/features/auth/models/auth_token.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthStorageService().clearSession();
  });

  group('AuthToken & UserModel JSON Parsing Unit Tests', () {
    test('AuthToken parses JWT pair correctly', () {
      final json = {
        'access': 'sample_access_jwt_token_123',
        'refresh': 'sample_refresh_jwt_token_456',
        'token_type': 'Bearer',
      };

      final token = AuthToken.fromJson(json);

      expect(token.accessToken, equals('sample_access_jwt_token_123'));
      expect(token.refreshToken, equals('sample_refresh_jwt_token_456'));
      expect(token.tokenType, equals('Bearer'));
    });

    test('AuthToken parses token field fallback correctly', () {
      final json = {
        'token': '9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b',
      };

      final token = AuthToken.fromJson(json);

      expect(token.accessToken, equals('9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b'));
    });

    test('UserModel parses user JSON fields correctly', () {
      final json = {
        'id': 42,
        'username': 'admin_user',
        'email': 'admin@fiberforce.in',
        'first_name': 'Fleet',
        'last_name': 'Administrator',
        'role': 'Fleet Admin',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('42'));
      expect(user.username, equals('admin_user'));
      expect(user.email, equals('admin@fiberforce.in'));
      expect(user.fullName, equals('Fleet Administrator'));
      expect(user.role, equals('Fleet Admin'));
    });
  });

  group('AuthStorageService Session Persistence & 10-Day Inactivity Tests', () {
    test('saveSession persists tokens, user, and lastActiveAt', () async {
      final token = const AuthToken(accessToken: 'jwt_123', refreshToken: 'ref_456');
      const user = UserModel(id: '1', username: 'admin', email: 'admin@hero.com');

      await AuthStorageService().saveSession(token: token, user: user);

      expect(AuthStorageService().isLoggedIn, isTrue);
      expect(AuthStorageService().accessToken, equals('jwt_123'));
      expect(AuthStorageService().currentUser?.username, equals('admin'));
      expect(AuthStorageService().lastActiveAt, isNotNull);
    });

    test('init() restores valid session if inactivity < 10 days and updates lastActiveAt', () async {
      SharedPreferences.setMockInitialValues({
        'hero_is_logged_in': true,
        'hero_access_token': 'jwt_123',
        'hero_refresh_token': 'ref_456',
        'hero_user_json': '{"id":"1","username":"admin","email":"admin@hero.com"}',
        'hero_last_active_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), // 4 days ago
      });

      await AuthStorageService().init(force: true);

      expect(AuthStorageService().isLoggedIn, isTrue);
      expect(AuthStorageService().accessToken, equals('jwt_123'));
      expect(AuthStorageService().currentUser?.username, equals('admin'));
      // Verifies that opening app resets rolling 10-day inactivity timer
      expect(DateTime.now().difference(AuthStorageService().lastActiveAt!).inHours, equals(0));
    });

    test('init() auto-logouts user if inactivity duration >= 10 days', () async {
      SharedPreferences.setMockInitialValues({
        'hero_is_logged_in': true,
        'hero_access_token': 'jwt_123',
        'hero_refresh_token': 'ref_456',
        'hero_user_json': '{"id":"1","username":"admin","email":"admin@hero.com"}',
        'hero_last_active_at': DateTime.now().subtract(const Duration(days: 11)).toIso8601String(), // 11 days ago
      });

      await AuthStorageService().init(force: true);

      expect(AuthStorageService().isLoggedIn, isFalse);
      expect(AuthStorageService().accessToken, isNull);
      expect(AuthStorageService().currentUser, isNull);
    });
  });

  group('AuthController Unit Tests', () {
    late MockAuthRepository mockRepo;
    late AuthController controller;

    setUp(() async {
      mockRepo = MockAuthRepository();
      controller = AuthController(repository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Successful login sets currentUser, token, and isAuthenticated', () async {
      expect(controller.isAuthenticated, isFalse);

      final success = await controller.login(
        username: 'admin',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.username, equals('admin'));
      expect(controller.errorMessage, isNull);
    });

    test('Failed login formats user-friendly error message', () async {
      final success = await controller.login(
        username: 'admin',
        password: 'invalid', // Triggers auth failure
      );

      expect(success, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, equals('Invalid username or password.'));
    });

    test('Logout clears current user and authentication state', () async {
      await controller.login(username: 'admin', password: 'password123');
      expect(controller.isAuthenticated, isTrue);

      await controller.logout();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.currentUser, isNull);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders LoginScreen form components and validates empty fields',
        (WidgetTester tester) async {
      final mockRepo = MockAuthRepository();
      final controller = AuthController(repository: mockRepo);
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            repository: mockRepo,
            controller: controller,
          ),
        ),
      );

      // Verify form elements
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Tap Sign In without filling form
      final signInButton = find.text('Sign In');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Expect validation error
      expect(find.text('Please enter your email or username'), findsOneWidget);
    });
  });
}
