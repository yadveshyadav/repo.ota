import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/inventory/controller/inventory_controller.dart';
import 'package:hero_app/models/circle_stock_summary_model.dart';
import 'package:hero_app/models/inventory_summary_model.dart';
import 'package:hero_app/models/stock_issue_model.dart';
import 'package:hero_app/models/stock_item_model.dart';
import 'package:hero_app/repositories/inventory_repository.dart';

void main() {
  group('Verified Stock Issue Item Model Parsing Tests', () {
    test('Parses full verified stock issue item JSON accurately', () {
      final json = {
        'id': 'item_501',
        'issueId': 'issue_0034',
        'issueNumber': 'ISS-0034',
        'fromWarehouseCode': 'WH-NAG-01',
        'fromWarehouseName': 'Nagaur Central Store',
        'issueeType': 'VENDOR',
        'issueeId': 'v_881',
        'issueeName': 'Hero Fibre Networks Ltd',
        'assignedTo': 'Devesh Dubey',
        'matId': 'mat_401',
        'materialId': 'M-OFC-48F',
        'materialDescription': '48F Armoured Optical Fiber Cable',
        'unitOfMeasurement': 'Meters',
        'quantity': 2000.0,
        'serialNo': 'DRUM1010379',
        'unitStartLength': 0.0,
        'unitEndLength': 2000.0,
        'unitCount': 2000.0,
        'itemStatus': 'ISSUED',
        'reservedQuantity': 500.0,
        'consumedQuantity': 1500.0,
        'returnedQuantity': 0.0,
        'createdBy': 'Badre Alam',
        'createdAt': '2026-09-12T11:29:35.437Z',
        'issuedAt': '2026-09-12T11:29:35.437Z',
        'status': 'ACTIVE',
      };

      final item = StockItemModel.fromJson(json);

      expect(item.id, 'item_501');
      expect(item.issueNumber, 'ISS-0034');
      expect(item.fromWarehouseName, 'Nagaur Central Store');
      expect(item.materialDescription, '48F Armoured Optical Fiber Cable');
      expect(item.quantity, 2000.0);
      expect(item.serialNo, 'DRUM1010379');
      expect(item.itemStatus, 'ISSUED');
      expect(item.createdAt, isNotNull);
      expect(item.createdAt!.year, 2026);
      expect(item.createdAt!.month, 9);
      expect(item.createdAt!.day, 12);
    });

    test('Preserves null values without replacing with fake defaults', () {
      final json = {
        'id': null,
        'issueNumber': null,
        'quantity': null,
        'serialNo': null,
        'reservedFrom': null,
        'createdAt': null,
      };

      final item = StockItemModel.fromJson(json);

      expect(item.id, isNull);
      expect(item.issueNumber, isNull);
      expect(item.quantity, isNull);
      expect(item.serialNo, isNull);
      expect(item.reservedFrom, isNull);
      expect(item.createdAt, isNull);
    });

    test('Parses numeric integers, doubles, and numeric strings safely', () {
      final jsonInt = {'quantity': 1000, 'unitCount': 500};
      final itemInt = StockItemModel.fromJson(jsonInt);
      expect(itemInt.quantity, 1000.0);
      expect(itemInt.unitCount, 500.0);

      final jsonString = {'quantity': '1500.75', 'unitCount': '300.25'};
      final itemString = StockItemModel.fromJson(jsonString);
      expect(itemString.quantity, 1500.75);
      expect(itemString.unitCount, 300.25);
    });
  });

  group('Verified Stock Issues Model & Double-Wrapper Parsing Tests', () {
    test('Parses nested stock issues double data wrapper accurately', () {
      final jsonDoubleWrapper = {
        'success': true,
        'message': 'Stock issues fetched successfully',
        'data': {
          'success': true,
          'statusCode': 200,
          'message': 'Fetched.',
          'data': {
            'currentPage': 0,
            'pageSize': 20,
            'totalElements': 2,
            'totalPages': 1,
            'first': true,
            'last': true,
            'content': [
              {
                'id': 'issue_0034',
                'issueNumber': 'ISS-0034',
                'stockTransferNumber': 'STN-2026-88',
                'fromWarehouseName': 'Nagaur Central Store',
                'issueeName': 'Hero Fibre Networks Ltd',
                'status': 'DISPATCHED',
                'items': [
                  {
                    'id': 'item_101',
                    'serialNo': 'DRUM1010379',
                    'materialDescription': '48F Cable',
                    'quantity': 2000.0,
                  },
                  {
                    'id': 'item_102',
                    'serialNo': 'DRUM1010368',
                    'materialDescription': '48F Cable',
                    'quantity': 2000.0,
                  }
                ]
              }
            ]
          }
        }
      };

      final response = StockIssueResponse.fromJson(jsonDoubleWrapper);

      expect(response.currentPage, 0);
      expect(response.pageSize, 20);
      expect(response.totalElements, 2);
      expect(response.totalPages, 1);
      expect(response.issues.length, 1);

      final issue = response.issues.first;
      expect(issue.id, 'issue_0034');
      expect(issue.issueNumber, 'ISS-0034');
      expect(issue.status, 'DISPATCHED');
      expect(issue.items.length, 2);
      expect(issue.items[0].serialNo, 'DRUM1010379');
      expect(issue.items[1].serialNo, 'DRUM1010368');
    });

    test('Supports multiple stock items under one issue without collapsing into duplicate cards', () {
      final jsonIssue = {
        'id': 'issue_0034',
        'issueNumber': 'ISS-0034',
        'items': [
          {'serialNo': 'DRUM-A', 'quantity': 1000.0},
          {'serialNo': 'DRUM-B', 'quantity': 1500.0},
          {'serialNo': 'DRUM-C', 'quantity': 2000.0},
        ]
      };

      final issue = StockIssueModel.fromJson(jsonIssue);
      expect(issue.items.length, 3);
      expect(issue.items[0].serialNo, 'DRUM-A');
      expect(issue.items[1].serialNo, 'DRUM-B');
      expect(issue.items[2].serialNo, 'DRUM-C');
    });

    test('Preserves separate stock items sharing the same issue number', () {
      final itemA = StockItemModel.fromJson({'id': 'i1', 'issueId': 'iss_34', 'serialNo': 'DRUM-A'});
      final itemB = StockItemModel.fromJson({'id': 'i2', 'issueId': 'iss_34', 'serialNo': 'DRUM-B'});

      expect(itemA.stableKey != itemB.stableKey, isTrue);
      expect(itemA.stableKey, 'i1');
      expect(itemB.stableKey, 'i2');
    });
  });

  group('Summary & Circle Models Parsing Tests', () {
    test('InventorySummaryModel parses null and numeric fields cleanly', () {
      final summary = InventorySummaryModel.fromJson({
        'totalIssuedMaterial': 47008.5,
        'drumsInventoryCount': 47,
        'reservedQuantity': 1200.0,
        'activeCirclesCount': 5,
      });

      expect(summary.totalIssuedMaterial, 47008.5);
      expect(summary.drumsInventoryCount, 47);
      expect(summary.reservedQuantity, 1200.0);
      expect(summary.activeCirclesCount, 5);
    });

    test('CircleStockSummaryModel parses circle summary fields cleanly', () {
      final circle = CircleStockSummaryModel.fromJson({
        'warehouseCode': 'WH-NAG-01',
        'circleName': 'NAGAUR CIRCLE',
        'totalMaterial': 15400.0,
        'drumCount': 18,
        'reservedQuantity': 300.0,
        'vendorsIssued': 4,
      });

      expect(circle.warehouseCode, 'WH-NAG-01');
      expect(circle.circleName, 'NAGAUR CIRCLE');
      expect(circle.totalMaterial, 15400.0);
      expect(circle.drumCount, 18);
      expect(circle.vendorsIssued, 4);
    });
  });

  group('InventoryController State & Pagination Lifecycle Tests', () {
    test('Initial fetch populates stock items and stock issues', () async {
      final repo = MockInventoryRepository();
      final controller = InventoryController(repository: repo);

      expect(controller.isItemsLoading, isTrue);
      expect(controller.isIssuesLoading, isTrue);

      await controller.fetchItems();
      await controller.fetchIssues();

      expect(controller.isItemsLoading, isFalse);
      expect(controller.items.isNotEmpty, isTrue);
      expect(controller.isIssuesLoading, isFalse);
      expect(controller.issues.isNotEmpty, isTrue);
    });

    test('Refresh updates inventory dataset', () async {
      final repo = MockInventoryRepository();
      final controller = InventoryController(repository: repo);

      await controller.refreshAll();

      expect(controller.isItemsLoading, isFalse);
      expect(controller.isIssuesLoading, isFalse);
      expect(controller.items.length, 3);
      expect(controller.issues.length, 2);
    });

    test('Deduplication strategy retains unique stock items and issues', () async {
      final repo = MockInventoryRepository();
      final controller = InventoryController(repository: repo);

      await controller.fetchItems();
      final countBefore = controller.items.length;

      // Re-fetch same page
      await controller.fetchItems(forceRefresh: true);
      final countAfter = controller.items.length;

      expect(countBefore, countAfter);
    });
  });
}
