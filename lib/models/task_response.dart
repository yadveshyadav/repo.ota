import 'task_model.dart';

/// Paginated response DTO for Tasks API endpoint
class TaskResponse {
  final List<TaskModel> tasks;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  // Category counts from API summary
  final Map<String, int> summaryCounts;

  const TaskResponse({
    required this.tasks,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
    this.summaryCounts = const {},
  });

  factory TaskResponse.fromJson(
    dynamic json, {
    int requestPage = 0,
    int requestSize = 10,
  }) {
    if (json == null) {
      return TaskResponse(
        tasks: const [],
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
          .map((item) => TaskModel.fromJson(item))
          .toList();
      return TaskResponse(
        tasks: list,
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
      List<dynamic> rawList = [];

      if (json['data'] is List) {
        rawList = json['data'] as List<dynamic>;
      } else {
        if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
          source = json['data'] as Map<String, dynamic>;
        }

        dynamic extractList(Map<String, dynamic> map) {
          return map['content'] ??
              map['results'] ??
              map['items'] ??
              map['data'] ??
              map['tasks'] ??
              map['records'] ??
              map['rows'] ??
              map['list'] ??
              map['payload'];
        }

        final extracted = extractList(source) ?? extractList(json);
        if (extracted is List) {
          rawList = extracted;
        }
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => TaskModel.fromJson(item))
          .toList();

      int parseNumInt(dynamic val, [int fallback = 0]) {
        if (val == null) return fallback;
        if (val is int) return val;
        if (val is num) return val.toInt();
        if (val is String) return int.tryParse(val.trim()) ?? fallback;
        return fallback;
      }

      final size = parseNumInt(
        source['size'] ??
            source['page_size'] ??
            source['pageSize'] ??
            source['limit'] ??
            json['size'] ??
            json['page_size'],
        requestSize > 0 ? requestSize : 20,
      );

      final total = parseNumInt(
        source['totalElements'] ??
            source['total'] ??
            source['count'] ??
            source['total_count'] ??
            source['totalCount'] ??
            source['total_elements'] ??
            source['recordsTotal'] ??
            source['totalRecords'] ??
            json['totalElements'] ??
            json['total'] ??
            json['count'] ??
            json['total_count'] ??
            json['totalCount'] ??
            json['recordsTotal'],
        list.length,
      );

      final effectiveSize = size > 0 ? size : 20;
      final computedPages = (total > 0 && effectiveSize > 0) ? (total / effectiveSize).ceil() : 1;
      final rawPages = parseNumInt(
        source['totalPages'] ??
            source['pages'] ??
            source['total_pages'] ??
            json['totalPages'] ??
            json['pages'],
        computedPages,
      );
      final pages = (computedPages > rawPages) ? computedPages : (rawPages > 0 ? rawPages : 1);

      final page = parseNumInt(
        source['currentPage'] ??
            source['page'] ??
            source['number'] ??
            source['current_page'] ??
            json['page'] ??
            json['currentPage'],
        requestPage,
      );

      final bool hasNextVal = (page + 1 < pages) || (list.length >= effectiveSize && (page + 1) * effectiveSize < total);

      final hasPrevVal = page > 0;

      Map<String, int> counts = {};
      if (source['summary'] is Map<String, dynamic>) {
        final sumMap = source['summary'] as Map<String, dynamic>;
        sumMap.forEach((key, val) {
          counts[key] = parseNumInt(val);
        });
      } else if (json['summary'] is Map<String, dynamic>) {
        final sumMap = json['summary'] as Map<String, dynamic>;
        sumMap.forEach((key, val) {
          counts[key] = parseNumInt(val);
        });
      }

      return TaskResponse(
        tasks: list,
        totalCount: total,
        totalPages: pages == 0 ? 1 : pages,
        currentPage: page,
        pageSize: size,
        hasNext: hasNextVal,
        hasPrevious: hasPrevVal,
        summaryCounts: counts,
      );
    }

    return TaskResponse(
      tasks: const [],
      totalCount: 0,
      totalPages: 1,
      currentPage: requestPage,
      pageSize: requestSize,
      hasNext: false,
      hasPrevious: false,
    );
  }
}
