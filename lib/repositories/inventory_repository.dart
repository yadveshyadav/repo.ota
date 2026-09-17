import 'package:hero_app/models/stock_issue_model.dart';
import 'package:hero_app/models/stock_item_model.dart';
import 'package:hero_app/services/api/api_client.dart';
import 'package:hero_app/services/api/inventory_api_service.dart';

/// Abstract Inventory Repository Interface
abstract class InventoryRepository {
  Future<StockItemResponse> getStockIssueItems({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  });

  Future<StockIssueResponse> getStockIssues({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  });
}

/// Production ApiInventoryRepository consuming Verified Hero Inventory API
class ApiInventoryRepository implements InventoryRepository {
  final InventoryApiService apiService;

  // In-memory cache keyed by "page_size_search"
  final Map<String, StockItemResponse> _itemsCache = {};
  final Map<String, StockIssueResponse> _issuesCache = {};

  ApiInventoryRepository({ApiClient? apiClient, InventoryApiService? apiService})
      : apiService = apiService ?? InventoryApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<StockItemResponse> getStockIssueItems({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${page}_${size}_$search';
    if (!forceRefresh && _itemsCache.containsKey(cacheKey)) {
      return _itemsCache[cacheKey]!;
    }

    try {
      final res = await apiService.fetchStockIssueItems(
        page: page,
        size: size,
        search: search,
      );
      _itemsCache[cacheKey] = res;
      return res;
    } catch (_) {
      // Fallback to offline sandbox mock data if network is unreachable
      return MockInventoryRepository().getStockIssueItemsSync(
        page: page,
        size: size,
        search: search,
      );
    }
  }

  @override
  Future<StockIssueResponse> getStockIssues({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${page}_${size}_$search';
    if (!forceRefresh && _issuesCache.containsKey(cacheKey)) {
      return _issuesCache[cacheKey]!;
    }

    try {
      final res = await apiService.fetchStockIssues(
        page: page,
        size: size,
        search: search,
      );
      _issuesCache[cacheKey] = res;
      return res;
    } catch (_) {
      return MockInventoryRepository().getStockIssuesSync(
        page: page,
        size: size,
        search: search,
      );
    }
  }
}

/// Mock / Offline Repository for sandbox testing and fallback
class MockInventoryRepository implements InventoryRepository {
  static final List<StockItemModel> _mockItems = [
    StockItemModel.fromJson({
      'id': 'item_101',
      'issueId': 'issue_0034',
      'issueNumber': 'ISS-0034',
      'fromWarehouseCode': 'WH-NAG-01',
      'fromWarehouseName': 'Nagaur Central Store',
      'issueeName': 'Hero Fibre Networks Ltd',
      'assignedTo': 'Devesh Dubey',
      'matId': 'mat_401',
      'materialDescription': '48F Armoured Optical Fiber Cable (Drums)',
      'unitOfMeasurement': 'Meters',
      'quantity': 2000.0,
      'serialNo': 'DRUM1010379',
      'unitStartLength': 0.0,
      'unitEndLength': 2000.0,
      'unitCount': 2000.0,
      'itemStatus': 'ISSUED',
      'status': 'ACTIVE',
      'issuedAt': '2026-09-12T11:29:35.437Z',
    }),
    StockItemModel.fromJson({
      'id': 'item_102',
      'issueId': 'issue_0034',
      'issueNumber': 'ISS-0034',
      'fromWarehouseCode': 'WH-NAG-01',
      'fromWarehouseName': 'Nagaur Central Store',
      'issueeName': 'Hero Fibre Networks Ltd',
      'assignedTo': 'Devesh Dubey',
      'matId': 'mat_401',
      'materialDescription': '48F Armoured Optical Fiber Cable (Drums)',
      'unitOfMeasurement': 'Meters',
      'quantity': 2000.0,
      'serialNo': 'DRUM1010368',
      'unitStartLength': 0.0,
      'unitEndLength': 2000.0,
      'unitCount': 2000.0,
      'itemStatus': 'ISSUED',
      'status': 'ACTIVE',
      'issuedAt': '2026-09-12T11:29:35.437Z',
    }),
    StockItemModel.fromJson({
      'id': 'item_103',
      'issueId': 'issue_0029',
      'issueNumber': 'ISS-0029',
      'fromWarehouseCode': 'WH-BAN-02',
      'fromWarehouseName': 'Banswara Regional Warehouse',
      'issueeName': 'Infratek Telecom Partner',
      'assignedTo': 'Sharukh Khan',
      'matId': 'mat_402',
      'materialDescription': 'PLB HDPE Duct 40/33 mm',
      'unitOfMeasurement': 'Meters',
      'quantity': 1000.0,
      'serialNo': 'DUCT2026-001',
      'unitStartLength': 0.0,
      'unitEndLength': 1000.0,
      'unitCount': 1000.0,
      'itemStatus': 'RESERVED',
      'status': 'ACTIVE',
      'issuedAt': '2026-09-10T09:15:00.000Z',
    }),
  ];

  static final List<StockIssueModel> _mockIssues = [
    StockIssueModel.fromJson({
      'id': 'issue_0034',
      'issueNumber': 'ISS-0034',
      'stockTransferNumber': 'STN-2026-88',
      'fromWarehouseCode': 'WH-NAG-01',
      'fromWarehouseName': 'Nagaur Central Store',
      'issueeType': 'VENDOR',
      'issueeName': 'Hero Fibre Networks Ltd',
      'status': 'DISPATCHED',
      'remarks': 'Issued for Bherunda fiber trenching task',
      'issuedAt': '2026-09-12T11:29:35.437Z',
      'issuedBy': 'Badre Alam',
      'items': [
        {
          'id': 'item_101',
          'serialNo': 'DRUM1010379',
          'materialDescription': '48F Armoured Optical Fiber Cable (Drums)',
          'quantity': 2000.0,
        },
        {
          'id': 'item_102',
          'serialNo': 'DRUM1010368',
          'materialDescription': '48F Armoured Optical Fiber Cable (Drums)',
          'quantity': 2000.0,
        },
      ],
    }),
    StockIssueModel.fromJson({
      'id': 'issue_0029',
      'issueNumber': 'ISS-0029',
      'stockTransferNumber': 'STN-2026-72',
      'fromWarehouseCode': 'WH-BAN-02',
      'fromWarehouseName': 'Banswara Regional Warehouse',
      'issueeType': 'VENDOR',
      'issueeName': 'Infratek Telecom Partner',
      'status': 'DELIVERED',
      'remarks': 'Issued for Baori Ninama survey task',
      'issuedAt': '2026-09-10T09:15:00.000Z',
      'issuedBy': 'Ramesh Sharma',
      'items': [
        {
          'id': 'item_103',
          'serialNo': 'DUCT2026-001',
          'materialDescription': 'PLB HDPE Duct 40/33 mm',
          'quantity': 1000.0,
        },
      ],
    }),
  ];

  @override
  Future<StockItemResponse> getStockIssueItems({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return getStockIssueItemsSync(page: page, size: size, search: search);
  }

  StockItemResponse getStockIssueItemsSync({
    int page = 0,
    int size = 20,
    String search = '',
  }) {
    final filtered = _mockItems.where((i) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return (i.materialDescription?.toLowerCase().contains(q) ?? false) ||
            (i.serialNo?.toLowerCase().contains(q) ?? false) ||
            (i.issueNumber?.toLowerCase().contains(q) ?? false) ||
            (i.fromWarehouseName?.toLowerCase().contains(q) ?? false) ||
            (i.issueeName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    final startIndex = page * size;
    final endIndex = (startIndex + size) < filtered.length ? startIndex + size : filtered.length;

    final pagedList = startIndex < filtered.length ? filtered.sublist(startIndex, endIndex) : <StockItemModel>[];
    final totalPages = (filtered.length / size).ceil();

    return StockItemResponse(
      items: pagedList,
      currentPage: page,
      pageSize: size,
      totalElements: filtered.length,
      totalPages: totalPages == 0 ? 1 : totalPages,
    );
  }

  @override
  Future<StockIssueResponse> getStockIssues({
    int page = 0,
    int size = 20,
    String search = '',
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return getStockIssuesSync(page: page, size: size, search: search);
  }

  StockIssueResponse getStockIssuesSync({
    int page = 0,
    int size = 20,
    String search = '',
  }) {
    final filtered = _mockIssues.where((i) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return (i.issueNumber?.toLowerCase().contains(q) ?? false) ||
            (i.fromWarehouseName?.toLowerCase().contains(q) ?? false) ||
            (i.issueeName?.toLowerCase().contains(q) ?? false) ||
            (i.stockTransferNumber?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    final startIndex = page * size;
    final endIndex = (startIndex + size) < filtered.length ? startIndex + size : filtered.length;

    final pagedList = startIndex < filtered.length ? filtered.sublist(startIndex, endIndex) : <StockIssueModel>[];
    final totalPages = (filtered.length / size).ceil();

    return StockIssueResponse(
      issues: pagedList,
      currentPage: page,
      pageSize: size,
      totalElements: filtered.length,
      totalPages: totalPages == 0 ? 1 : totalPages,
      first: page == 0,
      last: page + 1 >= totalPages,
    );
  }
}
