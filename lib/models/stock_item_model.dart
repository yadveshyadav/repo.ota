import '../core/utils/date_parser_utils.dart';

/// Strongly typed Stock Item / Stock Issue Item Model
/// Preserves exact verified API field structure and nullability without fake defaults.
class StockItemModel {
  final String? id;
  final String? issueId;
  final String? issueNumber;
  final String? fromWarehouseCode;
  final String? fromWarehouseName;
  final String? issueeType;
  final String? issueeId;
  final String? issueeName;
  final String? assignedTo;

  final String? matId;
  final String? materialId;
  final String? materialDescription;
  final String? unitOfMeasurement;
  final double? quantity;
  final String? serialNo;

  final double? unitStartLength;
  final double? unitEndLength;
  final double? unitCount;

  final String? itemStatus;

  final DateTime? reservedFrom;
  final DateTime? reservedTo;
  final double? reservedQuantity;

  final DateTime? consumedFrom;
  final DateTime? consumedTo;
  final double? consumedQuantity;

  final double? returnedQuantity;

  final double? currentStartLength;
  final double? currentEndLength;
  final double? currentCount;

  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? issuedAt;
  final String? status;

  const StockItemModel({
    this.id,
    this.issueId,
    this.issueNumber,
    this.fromWarehouseCode,
    this.fromWarehouseName,
    this.issueeType,
    this.issueeId,
    this.issueeName,
    this.assignedTo,
    this.matId,
    this.materialId,
    this.materialDescription,
    this.unitOfMeasurement,
    this.quantity,
    this.serialNo,
    this.unitStartLength,
    this.unitEndLength,
    this.unitCount,
    this.itemStatus,
    this.reservedFrom,
    this.reservedTo,
    this.reservedQuantity,
    this.consumedFrom,
    this.consumedTo,
    this.consumedQuantity,
    this.returnedQuantity,
    this.currentStartLength,
    this.currentEndLength,
    this.currentCount,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.issuedAt,
    this.status,
  });

  /// Unique stable key for deduplication (prefers id, then issueId + serialNo)
  String get stableKey {
    if (id != null && id!.isNotEmpty) return id!;
    if (issueId != null && serialNo != null) return '${issueId}_$serialNo';
    if (issueNumber != null && serialNo != null) return '${issueNumber}_$serialNo';
    if (serialNo != null && serialNo!.isNotEmpty) return serialNo!;
    return 'item_${identityHashCode(this)}';
  }

  factory StockItemModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const StockItemModel();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return StockItemModel(
      id: json['id']?.toString(),
      issueId: json['issueId']?.toString() ?? json['issue_id']?.toString(),
      issueNumber: json['issueNumber']?.toString() ?? json['issue_number']?.toString(),
      fromWarehouseCode: json['fromWarehouseCode']?.toString() ?? json['from_warehouse_code']?.toString(),
      fromWarehouseName: json['fromWarehouseName']?.toString() ?? json['from_warehouse_name']?.toString(),
      issueeType: json['issueeType']?.toString() ?? json['issuee_type']?.toString(),
      issueeId: json['issueeId']?.toString() ?? json['issuee_id']?.toString(),
      issueeName: json['issueeName']?.toString() ?? json['issuee_name']?.toString(),
      assignedTo: json['assignedTo']?.toString() ?? json['assigned_to']?.toString(),
      matId: json['matId']?.toString() ?? json['mat_id']?.toString(),
      materialId: json['materialId']?.toString() ?? json['material_id']?.toString(),
      materialDescription: json['materialDescription']?.toString() ?? json['material_description']?.toString(),
      unitOfMeasurement: json['unitOfMeasurement']?.toString() ?? json['unit_of_measurement']?.toString(),
      quantity: parseDouble(json['quantity']),
      serialNo: json['serialNo']?.toString() ?? json['serial_no']?.toString(),
      unitStartLength: parseDouble(json['unitStartLength'] ?? json['unit_start_length']),
      unitEndLength: parseDouble(json['unitEndLength'] ?? json['unit_end_length']),
      unitCount: parseDouble(json['unitCount'] ?? json['unit_count']),
      itemStatus: json['itemStatus']?.toString() ?? json['item_status']?.toString(),
      reservedFrom: DateParserUtils.parse(json['reservedFrom'] ?? json['reserved_from']),
      reservedTo: DateParserUtils.parse(json['reservedTo'] ?? json['reserved_to']),
      reservedQuantity: parseDouble(json['reservedQuantity'] ?? json['reserved_quantity']),
      consumedFrom: DateParserUtils.parse(json['consumedFrom'] ?? json['consumed_from']),
      consumedTo: DateParserUtils.parse(json['consumedTo'] ?? json['consumed_to']),
      consumedQuantity: parseDouble(json['consumedQuantity'] ?? json['consumed_quantity']),
      returnedQuantity: parseDouble(json['returnedQuantity'] ?? json['returned_quantity']),
      currentStartLength: parseDouble(json['currentStartLength'] ?? json['current_start_length']),
      currentEndLength: parseDouble(json['currentEndLength'] ?? json['current_end_length']),
      currentCount: parseDouble(json['currentCount'] ?? json['current_count']),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      updatedBy: json['updatedBy']?.toString() ?? json['updated_by']?.toString(),
      createdAt: DateParserUtils.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateParserUtils.parse(json['updatedAt'] ?? json['updated_at']),
      issuedAt: DateParserUtils.parse(json['issuedAt'] ?? json['issued_at']),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (issueId != null) 'issueId': issueId,
        if (issueNumber != null) 'issueNumber': issueNumber,
        if (fromWarehouseCode != null) 'fromWarehouseCode': fromWarehouseCode,
        if (fromWarehouseName != null) 'fromWarehouseName': fromWarehouseName,
        if (issueeType != null) 'issueeType': issueeType,
        if (issueeId != null) 'issueeId': issueeId,
        if (issueeName != null) 'issueeName': issueeName,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (matId != null) 'matId': matId,
        if (materialId != null) 'materialId': materialId,
        if (materialDescription != null) 'materialDescription': materialDescription,
        if (unitOfMeasurement != null) 'unitOfMeasurement': unitOfMeasurement,
        if (quantity != null) 'quantity': quantity,
        if (serialNo != null) 'serialNo': serialNo,
        if (unitStartLength != null) 'unitStartLength': unitStartLength,
        if (unitEndLength != null) 'unitEndLength': unitEndLength,
        if (unitCount != null) 'unitCount': unitCount,
        if (itemStatus != null) 'itemStatus': itemStatus,
        if (reservedFrom != null) 'reservedFrom': reservedFrom!.toIso8601String(),
        if (reservedTo != null) 'reservedTo': reservedTo!.toIso8601String(),
        if (reservedQuantity != null) 'reservedQuantity': reservedQuantity,
        if (consumedFrom != null) 'consumedFrom': consumedFrom!.toIso8601String(),
        if (consumedTo != null) 'consumedTo': consumedTo!.toIso8601String(),
        if (consumedQuantity != null) 'consumedQuantity': consumedQuantity,
        if (returnedQuantity != null) 'returnedQuantity': returnedQuantity,
        if (currentStartLength != null) 'currentStartLength': currentStartLength,
        if (currentEndLength != null) 'currentEndLength': currentEndLength,
        if (currentCount != null) 'currentCount': currentCount,
        if (createdBy != null) 'createdBy': createdBy,
        if (updatedBy != null) 'updatedBy': updatedBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt!.toIso8601String(),
        if (status != null) 'status': status,
      };
}

/// Paginated Response Wrapper for Stock Item Search
class StockItemResponse {
  final List<StockItemModel> items;
  final int currentPage;
  final int pageSize;
  final int totalElements;
  final int totalPages;

  const StockItemResponse({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
  });

  bool get hasNext => currentPage + 1 < totalPages;
  bool get hasPrevious => currentPage > 0;

  factory StockItemResponse.fromJson(dynamic json, {int requestPage = 0, int requestSize = 20}) {
    if (json == null || json is! Map<String, dynamic>) {
      return StockItemResponse(
        items: const [],
        currentPage: requestPage,
        pageSize: requestSize,
        totalElements: 0,
        totalPages: 1,
      );
    }

    dynamic dataObj = json['data'] ?? json;
    if (dataObj is Map<String, dynamic> && dataObj.containsKey('data')) {
      dataObj = dataObj['data'];
    }

    List<StockItemModel> itemList = [];
    int curPage = requestPage;
    int pSize = requestSize;
    int totElements = 0;
    int totPages = 1;

    if (dataObj is Map<String, dynamic>) {
      curPage = (dataObj['currentPage'] as int?) ?? (dataObj['number'] as int?) ?? requestPage;
      pSize = (dataObj['pageSize'] as int?) ?? (dataObj['size'] as int?) ?? requestSize;
      totElements = (dataObj['totalElements'] as int?) ?? (dataObj['total'] as int?) ?? 0;
      totPages = (dataObj['totalPages'] as int?) ?? (totElements > 0 ? (totElements / pSize).ceil() : 1);

      dynamic contentList = dataObj['content'] ?? dataObj['items'] ?? dataObj['results'];
      if (contentList is List) {
        itemList = contentList
            .whereType<Map<String, dynamic>>()
            .map((item) => StockItemModel.fromJson(item))
            .toList();
      }
    } else if (dataObj is List) {
      itemList = dataObj
          .whereType<Map<String, dynamic>>()
          .map((item) => StockItemModel.fromJson(item))
          .toList();
      totElements = itemList.length;
    }

    return StockItemResponse(
      items: itemList,
      currentPage: curPage,
      pageSize: pSize,
      totalElements: totElements,
      totalPages: totPages == 0 ? 1 : totPages,
    );
  }
}
