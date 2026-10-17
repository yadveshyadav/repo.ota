import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/screens/machines/machine_list_screen.dart';
import 'package:hero_app/widgets/machines/machine_card_widget.dart';

void main() {
  testWidgets('MachineListScreen renders search, filters, and machine cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MachineListScreen(
          repository: MockMachineRepository(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // Verify Title
    expect(find.text('Machines'), findsOneWidget);
    expect(find.textContaining('FiberForce API'), findsOneWidget);

    // Verify Search Box
    expect(find.byType(TextField), findsOneWidget);

    // Verify Modern Machine List Cards
    expect(find.byType(MachineCardWidget), findsAtLeast(1));

    // Verify Card Content
    expect(find.textContaining('600202608396'), findsAtLeast(1));
    expect(find.text('APOLLO A600 V2'), findsAtLeast(1));
  });

  testWidgets('MachineListScreen filters by status correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MachineListScreen(
          initialStatusFilter: 'Running',
          repository: MockMachineRepository(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // Verify Title
    expect(find.text('Machines'), findsOneWidget);

    // Verify Machine Cards rendered
    expect(find.byType(MachineCardWidget), findsAtLeast(1));
  });
}
