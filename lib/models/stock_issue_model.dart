import '../core/utils/date_parser_utils.dart';
import 'stock_item_model.dart';

/// Strongly typed Stock Issue Model
/// Represents a stock issue event containing 1-to-N stock issue items.
class StockIssueModel {
  final String? id;
  final String? issueNumber;
  final String? stockTransferNumber;

  final String? fromWarehouseCode;
  final String? fromWarehouseName;

  final String? issueeType;
  final String? issueeId;
  final String? issueeName;
  final String? issueeCode;

  final String? status;
  final String? remarks;

  final List<StockItemModel> items;

  final DateTime? issuedAt;
  final String? issuedBy;
  final String? createdBy;
  final DateTime? createdAt;

  const StockIssueModel({
    this.id,
    this.issueNumber,
    this.stockTransferNumber,
    this.fromWarehouseCode,
    this.fromWarehouseName,
    this.issueeType,
    this.issueeId,
    this.issueeName,
    this.issueeCode,
    this.status,
    this.remarks,
    this.items = const [],
    this.issuedAt,
    this.issuedBy,
    this.createdBy,
    this.createdAt,
  });

  /// Stable deduplication key (prefers id, then issueNumber)
  String get stableKey => id ?? issueNumber ?? 'issue_${identityHashCode(this)}';

  factory StockIssueModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const StockIssueModel();
    }

    final rawItems = json['items'];
    List<StockItemModel> parsedItems = const [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => StockItemModel.fromJson(item))
          .toList();
    }

    return StockIssueModel(
      id: json['id']?.toString(),
      issueNumber: json['issueNumber']?.toString() ?? json['issue_number']?.toString(),
      stockTransferNumber: json['stockTransferNumber']?.toString() ?? json['stock_transfer_number']?.toString(),
      fromWarehouseCode: json['fromWarehouseCode']?.toString() ?? json['from_warehouse_code']?.toString(),
      fromWarehouseName: json['fromWarehouseName']?.toString() ?? json['from_warehouse_name']?.toString(),
      issueeType: json['issueeType']?.toString() ?? json['issuee_type']?.toString(),
      issueeId: json['issueeId']?.toString() ?? json['issuee_id']?.toString(),
      issueeName: json['issueeName']?.toString() ?? json['issuee_name']?.toString(),
      issueeCode: json['issueeCode']?.toString() ?? json['issuee_code']?.toString(),
      status: json['status']?.toString(),
      remarks: json['remarks']?.toString(),
      items: parsedItems,
      issuedAt: DateParserUtils.parse(json['issuedAt'] ?? json['issued_at']),
      issuedBy: json['issuedBy']?.toString() ?? json['issued_by']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      createdAt: DateParserUtils.parse(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (issueNumber != null) 'issueNumber': issueNumber,
        if (stockTransferNumber != null) 'stockTransferNumber': stockTransferNumber,
        if (fromWarehouseCode != null) 'fromWarehouseCode': fromWarehouseCode,
        if (fromWarehouseName != null) 'fromWarehouseName': fromWarehouseName,
        if (issueeType != null) 'issueeType': issueeType,
        if (issueeId != null) 'issueeId': issueeId,
        if (issueeName != null) 'issueeName': issueeName,
        if (issueeCode != null) 'issueeCode': issueeCode,
        if (status != null) 'status': status,
        if (remarks != null) 'remarks': remarks,
        'items': items.map((i) => i.toJson()).toList(),
        if (issuedAt != null) 'issuedAt': issuedAt!.toIso8601String(),
        if (issuedBy != null) 'issuedBy': issuedBy,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

/// Paginated Response Wrapper for Stock Issues Endpoint
/// Safely unwraps the verified double-wrapper structure:
/// outer -> data -> data -> pagination object
class StockIssueResponse {
  final List<StockIssueModel> issues;
  final int currentPage;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const StockIssueResponse({
    required this.issues,
    required this.currentPage,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    this.first = true,
    this.last = true,
  });

  bool get hasNext => currentPage + 1 < totalPages;
  bool get hasPrevious => currentPage > 0;

  factory StockIssueResponse.fromJson(dynamic json, {int requestPage = 0, int requestSize = 20}) {
    if (json == null || json is! Map<String, dynamic>) {
      return StockIssueResponse(
        issues: const [],
        currentPage: requestPage,
        pageSize: requestSize,
        totalElements: 0,
        totalPages: 1,
      );
    }

    // Step 1: Un-wrap outer 'data'
    dynamic target = json;
    if (target is Map<String, dynamic> && target.containsKey('data')) {
      target = target['data'];
    }

    // Step 2: Un-wrap inner 'data' if double-wrapped
    if (target is Map<String, dynamic> && target.containsKey('data')) {
      target = target['data'];
    }

    List<StockIssueModel> issueList = [];
    int curPage = requestPage;
    int pSize = requestSize;
    int totElements = 0;
    int totPages = 1;
    bool isFirst = true;
    bool isLast = true;

    if (target is Map<String, dynamic>) {
      curPage = (target['currentPage'] as int?) ?? (target['number'] as int?) ?? requestPage;
      pSize = (target['pageSize'] as int?) ?? (target['size'] as int?) ?? requestSize;
      totElements = (target['totalElements'] as int?) ?? (target['total'] as int?) ?? 0;
      totPages = (target['totalPages'] as int?) ?? (totElements > 0 ? (totElements / pSize).ceil() : 1);
      isFirst = target['first'] as bool? ?? (curPage == 0);
      isLast = target['last'] as bool? ?? (curPage + 1 >= totPages);

      dynamic contentList = target['content'] ?? target['items'] ?? target['results'];
      if (contentList is List) {
        issueList = contentList
            .whereType<Map<String, dynamic>>()
            .map((issue) => StockIssueModel.fromJson(issue))
            .toList();
      }
    } else if (target is List) {
      issueList = target
          .whereType<Map<String, dynamic>>()
          .map((issue) => StockIssueModel.fromJson(issue))
          .toList();
      totElements = issueList.length;
    }

    return StockIssueResponse(
      issues: issueList,
      currentPage: curPage,
      pageSize: pSize,
      totalElements: totElements,
      totalPages: totPages == 0 ? 1 : totPages,
      first: isFirst,
      last: isLast,
    );
  }
}
