import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/app/app.dart';
import 'package:hero_app/core/constants/app_constants.dart';
import 'package:hero_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hero_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:hero_app/features/auth/presentation/widgets/hero_logo.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('1. Splash screen renders HERO branding and tagline',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HeroApp());

    // Verify SplashScreen is displayed
    expect(find.byType(SplashScreen), findsOneWidget);

    // Verify Hero Branding Logo and Tagline are rendered
    expect(find.byType(HeroLogo), findsOneWidget);
    expect(find.text(AppConstants.taglineLine1), findsOneWidget);
    expect(find.text(AppConstants.taglineLine2), findsOneWidget);

    await tester.pumpAndSettle(const Duration(milliseconds: 3500));
  });

  testWidgets('2. Splash screen navigates to Login screen after animation',
      (WidgetTester tester) async {
    await AuthStorageService().clearSession();
    await tester.pumpWidget(const HeroApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    // Fast-forward time past splash screen duration (3200ms)
    await tester.pumpAndSettle(const Duration(milliseconds: 3500));

    // Verify transition to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(AppConstants.welcomeBack), findsOneWidget);
  });

  testWidgets('3 & 4. Login screen renders username and password fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Check Welcome text
    expect(find.text(AppConstants.welcomeBack), findsOneWidget);
    expect(find.text(AppConstants.signInSubtitle), findsOneWidget);

    // Check Username/Email field label
    expect(find.text(AppConstants.emailOrUsernameLabel), findsOneWidget);

    // Check Password field label
    expect(find.text(AppConstants.passwordLabel), findsOneWidget);
  });

  testWidgets('5. Password visibility toggle works',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Find password field
    final passwordFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == AppConstants.passwordHint,
    );
    expect(passwordFieldFinder, findsOneWidget);

    TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);

    // Tap visibility toggle button
    final toggleIconFinder = find.byIcon(Icons.visibility_outlined);
    expect(toggleIconFinder, findsOneWidget);
    await tester.tap(toggleIconFinder);
    await tester.pump();

    // Verify obscureText changed to false
    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isFalse);

    // Tap again to obscure password
    final hideIconFinder = find.byIcon(Icons.visibility_off_outlined);
    expect(hideIconFinder, findsOneWidget);
    await tester.tap(hideIconFinder);
    await tester.pump();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('6 & 7. Empty form validation shows errors when Sign In tapped',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Find Sign In button
    final signInButtonFinder = find.text(AppConstants.signInButton);
    expect(signInButtonFinder, findsOneWidget);

    // Tap Sign In button without filling fields
    await tester.tap(signInButtonFinder);
    await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

    // Verify validation error messages are displayed
    expect(find.text(AppConstants.emailRequired), findsOneWidget);
    expect(find.text(AppConstants.passwordRequired), findsOneWidget);
  });

  testWidgets('8. Login screen does not overflow on small screen sizes',
      (WidgetTester tester) async {
    // Set small phone screen size (320x480)
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

    // Verify no RenderFlex overflow occurs on small screen dimensions
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Reset view configuration
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
