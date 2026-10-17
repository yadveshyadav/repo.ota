import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/repositories/dashboard_repository.dart';
import 'package:hero_app/screens/dashboard/dashboard_screen.dart';
import 'package:hero_app/shared/widgets/skeleton_loader.dart';
import 'package:hero_app/widgets/dashboard/active_alerts_card.dart';
import 'package:hero_app/widgets/dashboard/dashboard_header.dart';
import 'package:hero_app/widgets/dashboard/dashboard_sidebar.dart';
import 'package:hero_app/widgets/dashboard/summary_card.dart';

void main() {
  testWidgets('Dashboard Screen renders all major cards and header/sidebar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: MockDashboardRepository())),
    );

    // Initial skeleton loading state
    expect(find.byType(SkeletonBox), findsAtLeast(1));

    // Advance time to complete async repository data loading
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // Verify Header
    expect(find.byType(DashboardHeader), findsOneWidget);

    // Verify Summary Cards
    expect(find.byType(SummaryCardsRow), findsOneWidget);
    expect(find.text('MACHINES'), findsOneWidget);
    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('BREAKDOWN'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);

    // Verify Active Alerts Card
    expect(find.byType(ActiveAlertsCard), findsOneWidget);
    expect(find.text('Active alerts'), findsOneWidget);
  });

  testWidgets('Desktop layout renders persistent sidebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: MockDashboardRepository())),
    );

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // Verify Sidebar exists in desktop layout
    expect(find.byType(DashboardSidebar), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Dashboard breakdown card opens the breakdown management route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(repository: MockDashboardRepository()),
        routes: {
          AppRoutes.breakdowns: (_) => const Scaffold(
            body: Center(child: Text('Breakdown route reached')),
          ),
        },
      ),
    );

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(SummaryCardsRow), findsOneWidget);
    await tester.ensureVisible(find.text('BREAKDOWN'));
    await tester.tap(find.text('BREAKDOWN'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Breakdown route reached'), findsOneWidget);
  });
}
