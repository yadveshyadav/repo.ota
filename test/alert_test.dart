import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/alerts/controller/alert_controller.dart';
import 'package:hero_app/models/alert.dart';
import 'package:hero_app/repositories/alert_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alert Model & Response JSON Parsing Tests', () {
    test('Parses full alert JSON safely with all fields', () {
      final json = {
        'id': 41,
        'machine_code': 'A800 HDD (8595)',
        'vendor_name': 'HARPAL INFRA DEVELOPMENT',
        'severity': 'CRITICAL',
        'timestamp': '18m ago',
        'alert_type': 'ENGINE_OVERHEAT',
        'title': 'Engine Overheat Warning - A800 HDD (8595)',
        'message': 'Coolant temperature reached 98°C during operation.',
        'time_ago_str': '18m ago',
        'alert_severity': 'CRITICAL',
        'is_read': false,
        'created_at': '2026-09-08T12:17:30.844654Z',
        'vendor': 8,
        'machine': 63,
      };

      final alert = Alert.fromJson(json);

      expect(alert.id, equals('41'));
      expect(alert.chassisNumber, equals('A800 HDD (8595)'));
      expect(alert.vendorName, equals('HARPAL INFRA DEVELOPMENT'));
      expect(alert.isCritical, isTrue);
      expect(alert.alertType, equals('ENGINE_OVERHEAT'));
      expect(alert.title, equals('Engine Overheat Warning - A800 HDD (8595)'));
      expect(alert.relativeTime, equals('18m ago'));
      expect(alert.isRead, isFalse);
      expect(alert.vendorId, equals(8));
      expect(alert.machineId, equals(63));
    });

    test('Handles missing/null fields safely without crashing', () {
      final json = <String, dynamic>{};
      final alert = Alert.fromJson(json);

      expect(alert.id, equals(''));
      expect(alert.chassisNumber, equals('N/A'));
      expect(alert.isWarning, isTrue);
      expect(alert.title, equals('Fleet Alert'));
      expect(alert.relativeTime, equals('Recently'));
      expect(alert.isRead, isFalse);
    });

    test('Parses AlertResponse paginated structure correctly', () {
      final json = {
        'success': true,
        'message': 'Data retrieved successfully',
        'data': [
          {
            'id': 41,
            'machine_code': 'A800 HDD (8595)',
            'severity': 'CRITICAL',
            'title': 'Engine Overheat Warning',
            'message': 'Coolant temperature high',
            'is_read': false,
          }
        ],
        'meta': {
          'count': 24,
          'total_pages': 2,
          'current_page': 1,
          'page_size': 20,
        }
      };

      final response = AlertResponse.fromJson(json);

      expect(response.alerts.length, equals(1));
      expect(response.totalCount, equals(24));
      expect(response.totalPages, equals(2));
      expect(response.currentPage, equals(1));
      expect(response.alerts.first.id, equals('41'));
    });
  });

  group('AlertController Unit & Deduplication Tests', () {
    late MockAlertRepository repository;
    late AlertController controller;

    setUp(() {
      repository = MockAlertRepository();
      controller = AlertController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial fetch populates alerts and establishes baseline without popups', () async {
      expect(controller.isLoading, isTrue);

      await controller.fetchAlerts(page: 1);

      expect(controller.isLoading, isFalse);
      expect(controller.rawAlerts.length, equals(3));
      expect(controller.totalCount, equals(3));
      expect(controller.criticalCount, equals(1));
      expect(controller.warningCount, equals(1));
      expect(controller.infoCount, equals(1));
    });

    test('Filtering by severity modifies active alerts list correctly', () async {
      await controller.fetchAlerts(page: 1);

      controller.setSeverityFilter('CRITICAL');
      expect(controller.selectedSeverity, equals('CRITICAL'));
      expect(controller.alerts.length, equals(1));
      expect(controller.alerts.first.isCritical, isTrue);

      controller.setSeverityFilter('WARNING');
      expect(controller.alerts.length, equals(1));
      expect(controller.alerts.first.isWarning, isTrue);

      controller.setSeverityFilter('ALL');
      expect(controller.alerts.length, equals(3));
    });

    test('Marking alert as read updates local state', () async {
      await controller.fetchAlerts(page: 1);

      final criticalAlert = controller.rawAlerts.firstWhere((a) => a.isCritical);
      expect(criticalAlert.isRead, isFalse);

      final success = await controller.markAsRead(criticalAlert.id);

      expect(success, isTrue);
      final updated = controller.rawAlerts.firstWhere((a) => a.id == criticalAlert.id);
      expect(updated.isRead, isTrue);
    });
  });
}
