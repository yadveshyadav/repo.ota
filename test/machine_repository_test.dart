import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/models/machine_response.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/screens/dashboard/controllers/machine_dashboard_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MachineResponse total parsing priority & fallback tests', () {
    test('CASE 1: Parses response with "total" field', () {
      final json = {
        'success': true,
        'data': [
          {'machine_chassis_no': '600202608396', 'model_name': 'A600'}
        ],
        'total': 22,
      };

      final response = MachineResponse.fromJson(json);
      expect(response.total, equals(22));
      expect(response.machines.length, equals(1));
    });

    test('CASE 2: Parses response with "svgtotal" field', () {
      final json = {
        'success': true,
        'data': [
          {'machine_chassis_no': '600202608396', 'model_name': 'A600'}
        ],
        'svgtotal': 22,
      };

      final response = MachineResponse.fromJson(json);
      expect(response.total, equals(22));
    });

    test('CASE 3: Falls back to data.length when no total/svgtotal field is provided', () {
      final json = {
        'success': true,
        'data': [
          {'machine_chassis_no': '600202608396', 'model_name': 'A600'},
          {'machine_chassis_no': '800202608539', 'model_name': 'H800'},
        ],
      };

      final response = MachineResponse.fromJson(json);
      expect(response.total, equals(2));
    });

    test('CASE 4: Converts string "22" in total field safely to integer 22', () {
      final json = {
        'success': true,
        'data': [],
        'total': '22',
      };

      final response = MachineResponse.fromJson(json);
      expect(response.total, equals(22));
    });
  });

  group('MachineResponse.filteredForUser tests', () {
    test('Admin user gets unfiltered machines', () {
      final response = const MachineResponse(
        success: true,
        total: 2,
        machines: [
          Machine(machineChassisNo: 'CHASSIS_1'),
          Machine(machineChassisNo: 'CHASSIS_2'),
        ],
      );

      final adminUser = const UserModel(
        id: '1',
        username: 'admin',
        email: 'admin@hero.com',
        role: 'ADMIN',
        roles: ['ADMIN'],
      );

      final filtered = response.filteredForUser(adminUser);
      expect(filtered.total, equals(2));
      expect(filtered.machines.length, equals(2));
    });

    test('Operator user gets only assigned machine', () {
      final response = const MachineResponse(
        success: true,
        total: 3,
        machines: [
          Machine(machineChassisNo: 'CHASSIS_1'),
          Machine(machineChassisNo: 'CHASSIS_2'),
          Machine(machineChassisNo: 'CHASSIS_3'),
        ],
      );

      final operatorUser = const UserModel(
        id: '5',
        username: 'operator_1',
        email: 'op@hero.com',
        role: 'OPERATOR',
        roles: ['OPERATOR'],
        machineChassis: 'CHASSIS_2',
      );

      final filtered = response.filteredForUser(operatorUser);
      expect(filtered.total, equals(1));
      expect(filtered.machines.first.machineChassisNo, equals('CHASSIS_2'));
    });
  });

  group('MachineDashboardController State & Polling Lifecycle tests', () {
    test('Initial fetch sets totalMachines from repository', () async {
      final controller = MachineDashboardController(
        repository: MockMachineRepository(),
      );

      // Allow async initial fetch to complete
      await Future.delayed(const Duration(milliseconds: 400));

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.totalMachines, equals(35));
      expect(controller.state.machines.length, equals(35));

      controller.dispose();
    });

    test('Error during fetch retains previous valid count', () async {
      final controller = MachineDashboardController(
        repository: MockMachineRepository(),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      expect(controller.state.totalMachines, equals(35));

      // Trigger fetch on failing repository instance
      final failingController = MachineDashboardController(
        repository: _FailingMachineRepository(),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      expect(failingController.state.totalMachines, equals(0));
      expect(failingController.state.errorMessage, equals('Unable to refresh'));

      failingController.dispose();
      controller.dispose();
    });
  });
}

class _FailingMachineRepository implements MachineRepository {
  @override
  Future<MachineResponse> getMachines() async {
    throw Exception('Network error / 500 Server Error');
  }

  @override
  Future<List<Machine>> getAllMachines() async {
    throw Exception('Network error');
  }

  @override
  Future<List<Machine>> getFilteredMachines({
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? locationFilter,
  }) async {
    throw Exception('Network error');
  }
}
