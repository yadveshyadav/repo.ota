import 'vendor.dart';

/// Paginated response DTO for Vendors API endpoint
class VendorResponse {
  final List<Vendor> vendors;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  const VendorResponse({
    required this.vendors,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory VendorResponse.fromJson(dynamic json, {int requestPage = 0, int requestSize = 10}) {
    if (json == null) {
      return VendorResponse(
        vendors: const [],
        totalCount: 0,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
        hasNext: false,
        hasPrevious: false,
      );
    }

    if (json is List) {
      final list = json
          .whereType<Map<String, dynamic>>()
          .map((item) => Vendor.fromJson(item))
          .toList();
      return VendorResponse(
        vendors: list,
        totalCount: list.length,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
        hasNext: false,
        hasPrevious: false,
      );
    }

    if (json is Map<String, dynamic>) {
      Map<String, dynamic> source = json;
      if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
        source = json['data'] as Map<String, dynamic>;
      }

      final rawList = (source['content'] ??
              source['results'] ??
              source['items'] ??
              source['data'] ??
              source['vendors'] ??
              []) as List<dynamic>? ??
          [];

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => Vendor.fromJson(item))
          .toList();

      final total = (source['totalElements'] ??
              source['total'] ??
              source['count'] ??
              source['total_count'] ??
              source['totalCount'] ??
              list.length) as int? ??
          int.tryParse('${source['totalElements'] ?? source['total'] ?? source['count'] ?? ''}') ??
          list.length;

      final size = (source['size'] ??
              source['page_size'] ??
              source['pageSize'] ??
              requestSize) as int? ??
          requestSize;

      final pages = (source['totalPages'] ??
              source['pages'] ??
              source['total_pages'] ??
              source['total_pages'] ??
              (size > 0 ? (total / size).ceil() : 1)) as int? ??
          (size > 0 ? (total / size).ceil() : 1);

      final page = (source['page'] ??
              source['number'] ??
              source['current_page'] ??
              requestPage) as int? ??
          requestPage;

      final hasNextVal = source['hasNext'] as bool? ??
          source['has_next'] as bool? ??
          (page + 1 < (pages == 0 ? 1 : pages));

      final hasPrevVal = source['hasPrevious'] as bool? ??
          source['has_previous'] as bool? ??
          (page > 0);

      return VendorResponse(
        vendors: list,
        totalCount: total,
        totalPages: pages == 0 ? 1 : pages,
        currentPage: page,
        pageSize: size,
        hasNext: hasNextVal,
        hasPrevious: hasPrevVal,
      );
    }

    return VendorResponse(
      vendors: const [],
      totalCount: 0,
      totalPages: 1,
      currentPage: requestPage,
      pageSize: requestSize,
      hasNext: false,
      hasPrevious: false,
    );
  }
}
