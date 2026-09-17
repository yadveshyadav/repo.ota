import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/vendors/controller/vendor_controller.dart';
import 'package:hero_app/features/vendors/screens/vendors_screen.dart';
import 'package:hero_app/features/vendors/widgets/vendor_card.dart';
import 'package:hero_app/models/vendor.dart';
import 'package:hero_app/models/vendor_response.dart';
import 'package:hero_app/repositories/vendor_repository.dart';

void main() {
  group('VendorController Unit Tests', () {
    late MockVendorRepository mockRepo;
    late VendorController controller;

    setUp(() {
      mockRepo = MockVendorRepository();
      controller = VendorController(repository: mockRepo, pageSize: 2);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial fetch populates vendors and paginates starting at page 0', () async {
      expect(controller.isLoading, isTrue);

      await controller.fetchVendors();

      expect(controller.isLoading, isFalse);
      expect(controller.currentPage, equals(0));
      expect(controller.displayPageNumber, equals(1));
      expect(controller.totalCount, equals(18));
      expect(controller.totalPages, equals(9));
      expect(controller.vendors.length, equals(2));
      expect(controller.hasNext, isTrue);
      expect(controller.hasPrevious, isFalse);
    });

    test('nextPage and previousPage update zero-based page index and fetch data', () async {
      await controller.fetchVendors();

      // Go to Page 2 (API page 1)
      await controller.nextPage();
      expect(controller.currentPage, equals(1));
      expect(controller.displayPageNumber, equals(2));
      expect(controller.hasNext, isTrue);
      expect(controller.hasPrevious, isTrue);

      // Go back to Page 1 (API page 0)
      await controller.previousPage();
      expect(controller.currentPage, equals(0));
      expect(controller.displayPageNumber, equals(1));
    });

    test('Search query filter debounces and resets page to 0', () async {
      await controller.fetchVendors();
      controller.nextPage(); // Page 1
      expect(controller.currentPage, equals(1));

      // Search
      controller.setSearchQuery('Premium');
      await Future.delayed(const Duration(milliseconds: 800));

      expect(controller.currentPage, equals(0));
      expect(controller.searchQuery, equals('Premium'));
      expect(controller.vendors.length, equals(1));
      expect(controller.vendors.first.vendorName, contains('Premium'));

      // Clear search
      controller.clearSearch();
      await Future.delayed(const Duration(milliseconds: 400));
      expect(controller.searchQuery, isEmpty);
      expect(controller.totalCount, equals(18));
    });
  });

  group('VendorResponse & Vendor Model Parser Unit Tests', () {
    test('Parses DRF/Spring paginated JSON object correctly', () {
      final json = {
        'content': [
          {
            'id': 101,
            'company_name': 'Test Vendor Corp',
            'type': 'COMPANY',
            'contact_person': 'John Doe',
            'email': 'john@test.com',
            'phone': '1234567890',
            'location': 'New Delhi',
            'status': 'ACTIVE',
            'machine_count': 3,
            'member_count': 5,
            'vendor_code': 'VND-101',
          }
        ],
        'totalElements': 15,
        'totalPages': 2,
        'number': 0,
        'size': 10,
        'hasNext': true,
        'hasPrevious': false,
      };

      final response = VendorResponse.fromJson(json, requestPage: 0, requestSize: 10);

      expect(response.totalCount, equals(15));
      expect(response.totalPages, equals(2));
      expect(response.currentPage, equals(0));
      expect(response.vendors.length, equals(1));

      final vendor = response.vendors.first;
      expect(vendor.id, equals('101'));
      expect(vendor.vendorName, equals('Test Vendor Corp'));
      expect(vendor.vendorType, equals('COMPANY'));
      expect(vendor.contactPerson, equals('John Doe'));
      expect(vendor.email, equals('john@test.com'));
      expect(vendor.phone, equals('1234567890'));
      expect(vendor.location, equals('New Delhi'));
      expect(vendor.status, equals('ACTIVE'));
      expect(vendor.machineCount, equals(3));
      expect(vendor.memberCount, equals(5));
      expect(vendor.vendorCode, equals('VND-101'));
    });

    test('Handles missing/null fields safely without crashing', () {
      final json = {
        'id': null,
        'company_name': null,
        'email': null,
        'phone': null,
        'location': null,
      };

      final vendor = Vendor.fromJson(json);

      expect(vendor.id, equals(''));
      expect(vendor.vendorName, equals('Unnamed Vendor'));
      expect(vendor.email, isNull);
      expect(vendor.phone, isNull);
      expect(vendor.location, equals('Location not available'));
      expect(vendor.machineCount, equals(0));
      expect(vendor.memberCount, equals(0));
    });
  });

  group('VendorsScreen Widget Tests', () {
    testWidgets('Renders VendorsScreen header, search, vendor cards, and pagination',
        (WidgetTester tester) async {
      final mockRepo = MockVendorRepository();
      final controller = VendorController(repository: mockRepo, pageSize: 2);
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: VendorsScreen(
            repository: mockRepo,
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header Title & Subtitle
      expect(find.text('Vendor & Partner Management'), findsOneWidget);
      expect(find.text('Manage vendors and partners connected to the platform.'), findsOneWidget);
      expect(find.text('Refresh Vendors'), findsOneWidget);

      // Search placeholder
      expect(find.text('Search vendors by name, vendor code, contact person, or email...'), findsOneWidget);

      // Vendor Cards
      expect(find.byType(VendorCard), findsNWidgets(2));
      expect(find.text('Premium infra solutions'), findsOneWidget);

      // Pagination
      expect(find.text('Showing Page 1 of 9'), findsOneWidget);
      expect(find.text('18 Total Vendors'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
    });
  });
}
