import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';

/// Paginated response DTO for Users API endpoint
class UserResponse {
  final List<UserModel> users;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  const UserResponse({
    required this.users,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory UserResponse.fromJson(
    dynamic json, {
    int requestPage = 0,
    int requestSize = 20,
  }) {
    if (json == null) {
      return UserResponse(
        users: const [],
        totalCount: 0,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
        hasNext: false,
        hasPrevious: false,
      );
    }

    List<UserModel> parsedUsers = [];
    int total = 0;
    int size = requestSize;
    int page = requestPage;
    int pages = 1;

    try {
      Map<String, dynamic> map = {};
      if (json is Map) {
        map = Map<String, dynamic>.from(json);
      }

      dynamic source = map['data'] ?? map;
      Map<String, dynamic> dataMap = {};
      if (source is Map) {
        dataMap = Map<String, dynamic>.from(source);
      }

      List<dynamic> rawList = [];
      if (dataMap.containsKey('results') && dataMap['results'] is List) {
        rawList = dataMap['results'] as List<dynamic>;
      } else if (dataMap.containsKey('users') && dataMap['users'] is List) {
        rawList = dataMap['users'] as List<dynamic>;
      } else if (dataMap.containsKey('content') && dataMap['content'] is List) {
        rawList = dataMap['content'] as List<dynamic>;
      } else if (source is List) {
        rawList = source;
      } else if (map.containsKey('results') && map['results'] is List) {
        rawList = map['results'] as List<dynamic>;
      }

      parsedUsers = rawList
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final rawTotal = dataMap['count'] ?? dataMap['total'] ?? map['count'] ?? map['total'] ?? parsedUsers.length;
      total = rawTotal is num ? rawTotal.toInt() : (int.tryParse(rawTotal.toString()) ?? parsedUsers.length);

      final rawSize = dataMap['size'] ?? dataMap['page_size'] ?? dataMap['pageSize'] ?? requestSize;
      size = rawSize is num ? rawSize.toInt() : (int.tryParse(rawSize.toString()) ?? requestSize);

      final rawPage = dataMap['page'] ?? dataMap['current_page'] ?? requestPage;
      page = rawPage is num ? rawPage.toInt() : (int.tryParse(rawPage.toString()) ?? requestPage);

      final rawPages = dataMap['total_pages'] ?? dataMap['totalPages'] ?? (size > 0 ? (total / size).ceil() : 1);
      pages = rawPages is num ? rawPages.toInt() : (int.tryParse(rawPages.toString()) ?? (size > 0 ? (total / size).ceil() : 1));
      if (pages <= 0) pages = 1;
    } catch (e, stack) {
      if (kDebugMode) {
        print('[UserResponse.fromJson] Error parsing users response: $e\n$stack');
      }
    }

    return UserResponse(
      users: parsedUsers,
      totalCount: total > 0 ? total : parsedUsers.length,
      totalPages: pages,
      currentPage: page,
      pageSize: size,
      hasNext: page + 1 < pages,
      hasPrevious: page > 0,
    );
  }
}
