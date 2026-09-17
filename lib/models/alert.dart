import '../core/utils/date_parser_utils.dart';

/// Strongly-typed production data model for Fleet Alerts from HERO REST API
class Alert {
  final String id;
  final String? machineCode;
  final String? vendorName;
  final String severity; // 'CRITICAL', 'WARNING', 'INFO'
  final String? timestamp;
  final String? alertType;
  final String title;
  final String message;
  final String? timeAgoStr;
  final String? alertSeverity;
  final bool isRead;
  final DateTime? createdAt;
  final dynamic vendorId;
  final dynamic machineId;

  const Alert({
    required this.id,
    String? machineCode,
    String? machineName,
    String? chassisNumber,
    this.vendorName,
    this.severity = 'WARNING',
    this.timestamp,
    this.alertType,
    required this.title,
    this.message = '',
    this.timeAgoStr,
    this.alertSeverity,
    this.isRead = false,
    this.createdAt,
    this.vendorId,
    this.machineId,
  }) : machineCode = machineCode ?? chassisNumber ?? machineName;

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isWarning => severity.toUpperCase() == 'WARNING';
  bool get isInfo => severity.toUpperCase() == 'INFO';

  String get displaySeverity => severity.toUpperCase();

  String get chassisNumber {
    if (machineCode != null && machineCode!.trim().isNotEmpty) {
      return machineCode!.trim();
    }
    if (machineId != null) {
      return machineId.toString();
    }
    return 'N/A';
  }

  String get machineName => chassisNumber;

  String get relativeTime {
    if (timeAgoStr != null && timeAgoStr!.trim().isNotEmpty) {
      return timeAgoStr!.trim();
    }
    if (timestamp != null && timestamp!.trim().isNotEmpty) {
      return timestamp!.trim();
    }
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt!);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return DateParserUtils.formatDisplay(createdAt);
    }
    return 'Recently';
  }

  Alert copyWith({
    bool? isRead,
  }) {
    return Alert(
      id: id,
      machineCode: machineCode,
      vendorName: vendorName,
      severity: severity,
      timestamp: timestamp,
      alertType: alertType,
      title: title,
      message: message,
      timeAgoStr: timeAgoStr,
      alertSeverity: alertSeverity,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      vendorId: vendorId,
      machineId: machineId,
    );
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final rawId = source['id'] ?? source['alert_id'] ?? source['alertId'] ?? source['pk'] ?? '';
    final mCode = source['machine_code']?.toString() ??
        source['machineCode']?.toString() ??
        source['chassisNumber']?.toString() ??
        source['machine_name']?.toString() ??
        source['machineName']?.toString();

    final vName = source['vendor_name']?.toString() ?? source['vendorName']?.toString();
    final rawSeverity = (source['severity'] ?? source['alert_severity'] ?? source['alertSeverity'] ?? 'WARNING')
        .toString()
        .toUpperCase();

    final rawTitle = source['title']?.toString() ?? source['alert_type']?.toString() ?? 'Fleet Alert';
    final rawMessage = source['message']?.toString() ?? source['body']?.toString() ?? rawTitle;

    final readStatus = source['is_read'] as bool? ?? source['isRead'] as bool? ?? source['read'] as bool? ?? false;

    return Alert(
      id: rawId.toString(),
      machineCode: mCode,
      vendorName: vName,
      severity: rawSeverity,
      timestamp: source['timestamp']?.toString(),
      alertType: source['alert_type']?.toString() ?? source['alertType']?.toString(),
      title: rawTitle,
      message: rawMessage,
      timeAgoStr: source['time_ago_str']?.toString() ?? source['timeAgoStr']?.toString(),
      alertSeverity: source['alert_severity']?.toString() ?? source['alertSeverity']?.toString(),
      isRead: readStatus,
      createdAt: DateParserUtils.parse(source['created_at'] ?? source['createdAt'] ?? source['timestamp']),
      vendorId: source['vendor'] ?? source['vendor_id'] ?? source['vendorId'],
      machineId: source['machine'] ?? source['machine_id'] ?? source['machineId'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (machineCode != null) 'machine_code': machineCode,
        if (vendorName != null) 'vendor_name': vendorName,
        'severity': severity,
        if (timestamp != null) 'timestamp': timestamp,
        if (alertType != null) 'alert_type': alertType,
        'title': title,
        'message': message,
        if (timeAgoStr != null) 'time_ago_str': timeAgoStr,
        if (alertSeverity != null) 'alert_severity': alertSeverity,
        'is_read': isRead,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (vendorId != null) 'vendor': vendorId,
        if (machineId != null) 'machine': machineId,
      };
}

/// Paginated Alert Response DTO for GET /api/v1/integrations/alerts/
class AlertResponse {
  final List<Alert> alerts;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final String? nextUrl;
  final String? previousUrl;

  const AlertResponse({
    required this.alerts,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    this.nextUrl,
    this.previousUrl,
  });

  bool get hasNext => nextUrl != null || currentPage < totalPages;

  factory AlertResponse.fromJson(dynamic json, {int requestPage = 1, int requestSize = 20}) {
    if (json == null) {
      return AlertResponse(
        alerts: const [],
        totalCount: 0,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
      );
    }

    if (json is List) {
      final list = json
          .whereType<Map<String, dynamic>>()
          .map((item) => Alert.fromJson(item))
          .toList();
      return AlertResponse(
        alerts: list,
        totalCount: list.length,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
      );
    }

    if (json is Map<String, dynamic>) {
      dynamic data = json['data'] ?? json['results'] ?? json['content'] ?? json;
      List<dynamic> rawList = [];

      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          rawList = data['results'] as List<dynamic>;
        } else if (data['content'] is List) {
          rawList = data['content'] as List<dynamic>;
        } else if (data['data'] is List) {
          rawList = data['data'] as List<dynamic>;
        }
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => Alert.fromJson(item))
          .toList();

      Map<String, dynamic> meta = {};
      if (json['meta'] is Map<String, dynamic>) {
        meta = json['meta'] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        meta = data;
      }

      int parseNum(dynamic val, [int fallback = 0]) {
        if (val == null) return fallback;
        if (val is int) return val;
        if (val is num) return val.toInt();
        if (val is String) return int.tryParse(val.trim()) ?? fallback;
        return fallback;
      }

      final count = parseNum(meta['count'] ?? meta['total'] ?? json['count'] ?? json['total'], list.length);
      final size = parseNum(meta['page_size'] ?? meta['pageSize'] ?? json['page_size'] ?? json['pageSize'], requestSize);
      final effSize = size > 0 ? size : 20;
      final pages = parseNum(meta['total_pages'] ?? meta['totalPages'] ?? json['total_pages'] ?? json['totalPages'], (count / effSize).ceil());
      final page = parseNum(meta['current_page'] ?? meta['currentPage'] ?? json['current_page'] ?? json['currentPage'], requestPage);

      final next = meta['next']?.toString() ?? json['next']?.toString();
      final prev = meta['previous']?.toString() ?? json['previous']?.toString();

      return AlertResponse(
        alerts: list,
        totalCount: count,
        totalPages: pages > 0 ? pages : 1,
        currentPage: page > 0 ? page : 1,
        pageSize: effSize,
        nextUrl: next,
        previousUrl: prev,
      );
    }

    return AlertResponse(
      alerts: const [],
      totalCount: 0,
      totalPages: 1,
      currentPage: requestPage,
      pageSize: requestSize,
    );
  }
}
