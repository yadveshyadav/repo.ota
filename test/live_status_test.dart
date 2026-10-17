import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/live_status/controller/live_status_controller.dart';
import 'package:hero_app/features/live_status/screens/live_status_screen.dart';
import 'package:hero_app/features/live_status/widgets/live_machine_card.dart';
import 'package:hero_app/features/live_status/widgets/live_status_filter_bar.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/repositories/machine_repository.dart';


void main() {
  group('LiveStatusController Unit Tests', () {
    late LiveStatusController controller;
    late MachineRepository repository;


    setUp(() {
      repository = MockMachineRepository();
      controller = LiveStatusController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial fetch populates fleet and calculates statistics dynamically', () async {
      expect(controller.isLoading, isTrue);

      await controller.fetchMachines();

      final allMachines = controller.allMachines;
      expect(controller.isLoading, isFalse);
      expect(controller.totalCount, equals(allMachines.length));
      expect(controller.liveCount, equals(allMachines.where((m) => m.isLive).length));
      expect(controller.offlineCount, equals(allMachines.where((m) => m.isOffline).length));
      expect(controller.machines.length, equals(allMachines.length));
    });

    test('Filter by status correctly modifies displayed machine list', () async {
      await controller.fetchMachines();
      final allMachines = List<Machine>.from(controller.allMachines);

      // Filter by "Offline"
      controller.setFilter('Offline');
      expect(controller.selectedFilter, equals('Offline'));
      expect(controller.machines.length, equals(allMachines.where((m) => m.isOffline).length));
      expect(controller.machines.every((m) => m.isOffline), isTrue);

      // Filter by "Working"
      controller.setFilter('Working');
      expect(controller.machines.length, equals(allMachines.where((m) => m.isWorking).length));
      expect(controller.machines.every((m) => m.isWorking), isTrue);

      // Filter by "Idle"
      controller.setFilter('Idle');
      expect(controller.machines.every((m) => m.isIdle), isTrue);

      // Reset to "All"
      controller.setFilter('All');
      expect(controller.machines.length, equals(allMachines.length));
    });

    test('Search query filters by chassis, model, name, or site', () async {
      await controller.fetchMachines();
      final allMachines = List<Machine>.from(controller.allMachines);

      // Search by chassis
      controller.setSearchQuery('600202608396');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(controller.machines.length, equals(1));
      expect(controller.machines.first.chassisNumber, equals('600202608396'));

      // Search by site
      controller.setSearchQuery('Sujangarh');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(controller.machines.length, equals(allMachines.where((m) => m.site.toLowerCase().contains('sujangarh')).length));

      // Reset search
      controller.setSearchQuery('');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(controller.machines.length, equals(allMachines.length));
    });

    test('updateSingleMachine modifies telemetry without reloading whole list', () async {
      await controller.fetchMachines();

      final original = controller.machines.first;
      final updated = Machine(
        machineChassisNo: original.machineChassisNo,
        modelCode: original.modelCode,
        modelName: original.modelName,
        siteName: original.siteName,
        status: 'Moving',
        speed: 22.0,
        rpm: 2150.0,
        fuelLevelPercent: 55.0,
        operationalState: OperationalState.moving,
        connectivity: ConnectivityState.live,
      );

      controller.updateSingleMachine(updated);

      final fetchedUpdated = controller.machines.firstWhere(
        (m) => m.machineChassisNo == original.machineChassisNo,
      );

      expect(fetchedUpdated.speed, equals(22.0));
      expect(fetchedUpdated.rpm, equals(2150.0));
      expect(fetchedUpdated.operationalState, equals(OperationalState.moving));
    });
  });

  group('LiveStatusScreen Widget Tests', () {
    testWidgets('Renders Live Status header, filter chips, and machine cards',
        (WidgetTester tester) async {
      final mockRepo = MockMachineRepository();
      final allMachines = await mockRepo.getAllMachines();
      final controller = LiveStatusController(
        repository: mockRepo,
        refreshInterval: const Duration(days: 1),
      );
      addTearDown(() {
        controller.stopAutoRefresh();
        controller.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LiveStatusScreen(
            repository: mockRepo,
            controller: controller,
          ),
        ),
      );

      // Initial loading state shows skeletons or header
      expect(find.text('Live Status'), findsOneWidget);

      await tester.pumpAndSettle();

      // Check title and dynamic statistics
      expect(find.text('Live Status'), findsOneWidget);
      expect(find.text('${allMachines.length} machines'), findsOneWidget);
      expect(find.text('${allMachines.where((m) => m.isLive).length} live'), findsOneWidget);
      expect(find.text('${allMachines.where((m) => m.isOffline).length} offline'), findsOneWidget);

      // Check search input hint
      expect(find.text('Find chassis, model, or site...'), findsOneWidget);

      // Check status filter chips in LiveStatusFilterBar
      final filterBarFinder = find.byType(LiveStatusFilterBar);
      expect(find.descendant(of: filterBarFinder, matching: find.text('All')), findsOneWidget);
      expect(find.descendant(of: filterBarFinder, matching: find.text('Online')), findsOneWidget);
      expect(find.descendant(of: filterBarFinder, matching: find.text('Offline')), findsOneWidget);
      expect(find.descendant(of: filterBarFinder, matching: find.text('Working')), findsOneWidget);

      // Check presence of LiveMachineCards
      expect(find.byType(LiveMachineCard), findsWidgets);
      expect(find.text('View on map'), findsWidgets);
    });

    testWidgets('Tapping status filter chip updates displayed cards',
        (WidgetTester tester) async {
      final mockRepo = MockMachineRepository();
      final allMachines = await mockRepo.getAllMachines();
      final controller = LiveStatusController(
        repository: mockRepo,
        refreshInterval: const Duration(days: 1),
      );
      addTearDown(() {
        controller.stopAutoRefresh();
        controller.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LiveStatusScreen(
            repository: mockRepo,
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Working' filter chip inside LiveStatusFilterBar
      final workingChip = find.descendant(
        of: find.byType(LiveStatusFilterBar),
        matching: find.text('Working'),
      );
      await tester.tap(workingChip);
      await tester.pumpAndSettle();

      expect(controller.selectedFilter, equals('Working'));
      expect(controller.machines.length, equals(allMachines.where((m) => m.isWorking).length));
    });
  });
}
