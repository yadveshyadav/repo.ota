import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/machine_transfer/controller/machine_transfer_controller.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/models/machine_response.dart';
import 'package:hero_app/models/vendor_response.dart';
import 'package:hero_app/models/machine_movement.dart';
import 'package:hero_app/repositories/machine_movement_repository.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/repositories/vendor_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMachineMovementRepository movementRepo;
  late MachineRepository machineRepo;
  late VendorRepository vendorRepo;
  late MachineTransferController controller;

  setUp(() {
    movementRepo = MockMachineMovementRepository();
    machineRepo = _MachineTransferTestMachineRepository();
    vendorRepo = _MachineTransferTestVendorRepository();

    controller = MachineTransferController(
      movementRepository: movementRepo,
      machineRepository: machineRepo,
      vendorRepository: vendorRepo,
    );
  });

  group('MachineMovement Official Spec Domain Models & Status Lifecycle', () {
    test('MovementStatus mapping according to backend specification', () {
      expect(MovementStatus.fromString('PENDING_SHIFTING').apiValue, 'PENDING_SHIFTING');
      expect(MovementStatus.fromString('APPROVED_BY_SCM').apiValue, 'APPROVED_BY_SCM');
      expect(MovementStatus.fromString('IN_PROGRESS').apiValue, 'IN_PROGRESS');
      expect(MovementStatus.fromString('SHIFTED').apiValue, 'SHIFTED');
      expect(MovementStatus.fromString('CONFIRMED').apiValue, 'CONFIRMED');
      expect(MovementStatus.fromString('CANCELLED').apiValue, 'CANCELLED');

      expect(MovementStatus.fromString('IN_PROGRESS').isInProgress, isTrue);
      expect(MovementStatus.fromString('SHIFTED').isCompleted, isTrue);
      expect(MovementStatus.fromString('CONFIRMED').isLocked, isTrue);
    });

    test('MachineShiftRequest JSON parsing matching backend response schema', () {
      final json = {
        'id': 5,
        'request_id': 'MSR-20260925-0005',
        'status': 'APPROVED_BY_SCM',
        'vendor': {'id': 3, 'name': 'Primelink Infratel Enterprise', 'code': 'VND'},
        'machine': {'id': 8, 'name': 'Drill Rig Alpha', 'code': 'MCH-001', 'machine_chassis_no': '600202608397'},
        'a_point_name': 'Ring 3 Crossing, Jaipur',
        'a_point_latitude': 26.9124,
        'a_point_longitude': 75.7873,
        'b_point_name': 'Block C Feeder, Alwar',
        'b_point_latitude': 27.5530,
        'b_point_longitude': 76.6346,
        'required_date': '2026-09-26',
        'mode_of_shifting': 'OWN_HDD',
        'shifting_status': 'PENDING',
        'created_at': '2026-09-25T14:30:00Z',
      };

      final request = MachineMovement.fromJson(json);
      expect(request.id, '5');
      expect(request.requestId, 'MSR-20260925-0005');
      expect(request.isApprovedByScm, isTrue);
      expect(request.aPointName, 'Ring 3 Crossing, Jaipur');
      expect(request.bPointName, 'Block C Feeder, Alwar');
      expect(request.requiredDate, '2026-09-26');
      expect(request.modeOfShifting, 'OWN_HDD');
    });

    test('MachineShiftReason DTO parsing', () {
      final json = {
        'id': 1,
        'name': 'New Task',
        'code': 'NEW_TASK',
        'description': 'Shift required for new task execution',
        'is_active': true,
      };

      final reason = MachineShiftReason.fromJson(json);
      expect(reason.id, 1);
      expect(reason.name, 'New Task');
      expect(reason.code, 'NEW_TASK');
    });
  });

  group('One-Pager Form Validation Rules', () {
    test('Validation fails if Point A equals Point B', () async {
      await controller.initOnePagerForm();
      expect(controller.availableVendors, isNotEmpty);
      expect(controller.availableReasons, isNotEmpty);
      controller.setSelectedVendor(controller.availableVendors.first);
      expect(controller.availableMachines, isNotEmpty);
      controller.selectMachine(controller.availableMachines.first);
      controller.setSelectedReason(controller.availableReasons.first);

      controller.setAPoint('Jaipur Site');
      controller.setBPoint('Jaipur Site');

      expect(controller.validateOnePagerForm(), contains('Destination Point B must be different'));

      controller.setBPoint('Alwar Feeder Site');
      expect(controller.validateOnePagerForm(), isNull);
    });
  });

  group('Full Field Shifter Lifecycle & Actions', () {
    test('Start shifting, shifter updates, and mark shifted with photo', () async {
      await controller.initOnePagerForm();
      expect(controller.availableVendors, isNotEmpty);
      expect(controller.availableReasons, isNotEmpty);
      controller.setSelectedVendor(controller.availableVendors.first);
      expect(controller.availableMachines, isNotEmpty);
      controller.selectMachine(controller.availableMachines.first);
      controller.setSelectedReason(controller.availableReasons.first);

      controller.setAPoint('Point A Site');
      controller.setBPoint('Point B Destination');

      // Submit One-Pager Request
      final request = await controller.submitOnePagerShiftRequest();
      expect(request, isNotNull);
      expect(request!.isPendingShifting, isTrue);

      // Start Shifting -> IN_PROGRESS
      final startResult = await controller.startShifting(request.id);
      expect(startResult, isTrue);
      expect(controller.activeTransfer?.isInProgress, isTrue);

      // Mark Shifted with mandatory photo -> SHIFTED
      final mockPhotoBytes = [1, 2, 3, 4, 5];
      final shiftedResult = await controller.markShifted(
        requestId: request.id,
        shiftingDate: '2026-09-27',
        shiftingMode: 'OWN_HDD',
        shiftingContactPerson: 'Ramesh Kumar (+91 9876543210)',
        shiftingExpenseAmount: '15000.00',
        photoBytes: mockPhotoBytes,
        remarks: 'Rig reached destination Point B safely.',
      );

      expect(shiftedResult, isTrue);
      expect(controller.activeTransfer?.isShifted, isTrue);
      expect(controller.activeTransfer?.machinePictureUrl, contains('rig_photo'));
    });
  });
}


class _MachineTransferTestMachineRepository implements MachineRepository {
  static const _machine = Machine(
    id: '412',
    machineChassisNo: '600202608412',
    modelName: 'A600 HDD',
    siteName: 'Sujangarh-SITE',
    vendorName: 'Test Vendor',
  );

  @override
  Future<MachineResponse> getMachines() async => const MachineResponse(
        success: true,
        machines: [_machine],
        total: 1,
      );

  @override
  Future<List<Machine>> getAllMachines() async => const [_machine];

  @override
  Future<List<Machine>> getFilteredMachines({
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? locationFilter,
  }) async => const [_machine];
}

class _MachineTransferTestVendorRepository implements VendorRepository {
  static const _vendor = Vendor(
    id: 'test-vendor',
    vendorName: 'Test Vendor',
    contactPerson: 'Test Contact',
    assignedMachines: [
      {'machine_chassis_no': '600202608412'},
    ],
  );

  @override
  Future<VendorResponse> getVendors({
    int page = 0,
    int size = 10,
    String search = '',
    bool allowMockFallback = true,
  }) async =>
      VendorResponse(
        vendors: const [_vendor],
        totalCount: 1,
        totalPages: 1,
        currentPage: page,
        pageSize: size,
        hasNext: false,
        hasPrevious: page > 0,
      );
}
