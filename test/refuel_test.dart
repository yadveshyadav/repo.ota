import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/fuel/controller/refuel_controller.dart';
import 'package:hero_app/models/refuel_model.dart';
import 'package:hero_app/repositories/refuel_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RefuelModel & API Serialization Unit Tests', () {
    test('TEST 1: Safely parses live API response JSON payload for machine 28', () {
      final liveJson = {
        'id': 52,
        'machine_name': 'A600 HDD (8400)',
        'machine_code': 'MAC-8400',
        'machine_no': 'MAC-8400',
        'performed_by_name': 'Suresh dhakar',
        'quantity_liters': '75.00',
        'price_per_liter': '95.00',
        'total_cost': '7125.00',
        'meter_reading': '100.00',
        'refuel_date': '2026-09-09T03:41:53.436604Z',
        'notes': 'Field refueling at Sujangarh-SITE',
        'machine': 28,
        'performed_by': 19,
      };

      final model = RefuelModel.fromJson(liveJson);

      expect(model.id, equals('52'));
      expect(model.machineName, equals('A600 HDD (8400)'));
      expect(model.machineCode, equals('MAC-8400'));
      expect(model.performedByName, equals('Suresh dhakar'));
      expect(model.quantityLiters, equals(75.0));
      expect(model.pricePerLiter, equals(95.0));
      expect(model.totalCost, equals(7125.0));
      expect(model.formattedAmount, equals('+75 L'));
      expect(model.formattedCost, equals('₹7125.00'));
      expect(model.formattedMeterReading, equals('100.00h'));
      expect(model.machineId, equals('28'));
      expect(model.performedById, equals('19'));
    });

    test('TEST 2: Calculates total cost automatically if omitted in JSON', () {
      final json = {
        'id': '51',
        'machine_name': 'A600 HDD',
        'quantity_liters': '100.00',
        'price_per_liter': '95.00',
        'performed_by_name': 'MUKESH KUMAR',
        'refuel_date': '2026-09-02T02:41:53Z',
      };

      final model = RefuelModel.fromJson(json);

      expect(model.quantityLiters, equals(100.0));
      expect(model.pricePerLiter, equals(95.0));
      expect(model.totalCost, equals(9500.0));
      expect(model.formattedCost, equals('₹9500.00'));
    });
  });

  group('RefuelController State & Summary Calculations', () {
    test('TEST 3: Controller correctly aggregates live refuel summary metrics', () async {
      final mockRepo = _MockRefuelRepository();
      final controller = RefuelController(repository: mockRepo, machineId: '28');

      await controller.fetchRefuelLogs();

      expect(controller.isLoading, isFalse);
      expect(controller.totalRefuels, equals(2));
      expect(controller.totalFuelAdded, equals(175.0)); // 75 + 100
      expect(controller.avgFuelPerRefuel, equals(87.5)); // 175 / 2
      expect(controller.totalCost, equals(16625.0)); // 7125 + 9500
    });
  });
}

class _MockRefuelRepository implements RefuelRepository {
  @override
  Future<List<RefuelModel>> getRefuelLogs({
    String? machineId,
    String? searchQuery,
  }) async {
    return [
      RefuelModel.fromJson({
        'id': 52,
        'machine_name': 'A600 HDD (8400)',
        'machine_code': 'MAC-8400',
        'performed_by_name': 'Suresh dhakar',
        'quantity_liters': '75.00',
        'price_per_liter': '95.00',
        'total_cost': '7125.00',
        'meter_reading': '100.00',
        'refuel_date': '2026-09-09T03:41:53.436604Z',
        'machine': 28,
        'performed_by': 19,
      }),
      RefuelModel.fromJson({
        'id': 51,
        'machine_name': 'A600 HDD (8400)',
        'machine_code': 'MAC-8400',
        'performed_by_name': 'MUKESH KUMAR',
        'quantity_liters': '100.00',
        'price_per_liter': '95.00',
        'total_cost': '9500.00',
        'meter_reading': '100.00',
        'refuel_date': '2026-09-02T02:41:53.436604Z',
        'machine': 28,
        'performed_by': 267,
      }),
    ];
  }

  @override
  Future<RefuelModel> createRefuelEntry(Map<String, dynamic> body) async {
    return RefuelModel.fromJson(body);
  }
}
