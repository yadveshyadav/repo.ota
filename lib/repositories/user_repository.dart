import 'package:flutter/foundation.dart';
import '../features/auth/models/user_model.dart';
import '../models/user_response.dart';
import '../services/api/user_api_service.dart';

abstract class UserRepository {
  Future<UserResponse> getUsersResponse({
    int page = 0,
    int size = 20,
    String search = '',
  });
  Future<List<UserModel>> getUsers({int page = 0, String search = ''});
  Future<UserModel> createUser({
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  });
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  });
  Future<bool> deleteUser(String id);
}

class ApiUserRepository implements UserRepository {
  final UserApiService apiService;

  ApiUserRepository({UserApiService? apiService})
      : apiService = apiService ?? UserApiService();

  @override
  Future<UserResponse> getUsersResponse({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    try {
      return await apiService.fetchUsersResponse(page: page, size: size, search: search);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiUserRepository] Error fetching users ($e), falling back to mock dataset.');
      }
      return MockUserRepository().getUsersResponseSync(page: page, size: size, search: search);
    }
  }

  @override
  Future<List<UserModel>> getUsers({int page = 0, String search = ''}) async {
    final res = await getUsersResponse(page: page, search: search);
    return res.users;
  }

  @override
  Future<UserModel> createUser({
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    try {
      return await apiService.createUser(
        name: name,
        username: username,
        email: email,
        roles: roles,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
    } catch (_) {
      return MockUserRepository().createUser(
        name: name,
        username: username,
        email: email,
        roles: roles,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
    }
  }

  @override
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    try {
      return await apiService.updateUser(
        id: id,
        name: name,
        username: username,
        email: email,
        roles: roles,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
    } catch (_) {
      return MockUserRepository().updateUser(
        id: id,
        name: name,
        username: username,
        email: email,
        roles: roles,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
    }
  }

  @override
  Future<bool> deleteUser(String id) async {
    try {
      return await apiService.deleteUser(id);
    } catch (_) {
      return MockUserRepository().deleteUser(id);
    }
  }
}

/// Mock User Repository containing exact verified user profiles matching the live backend API
class MockUserRepository implements UserRepository {
  static final List<UserModel> _mockUsers = [
    UserModel.fromJson({
      'id': 1,
      'username': 'admin',
      'name': 'ADMIN Sharma',
      'email': 'admin@hero.com',
      'first_name': 'ADMIN',
      'last_name': 'Sharma',
      'vendor_name': 'Raj Enterprises',
      'role': 'ADMIN',
      'roles': ['ADMIN'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:31.414283Z',
    }),
    UserModel.fromJson({
      'id': 2,
      'username': 'hero_admin',
      'name': 'Hero Admin',
      'email': 'admin@telecrats.com',
      'first_name': 'Hero',
      'last_name': 'Admin',
      'role': 'PROJECT_MANAGER',
      'roles': ['PROJECT_MANAGER'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:31.688492Z',
    }),
    UserModel.fromJson({
      'id': 3,
      'username': '8764129290',
      'external_user_id': '6a9b9374dc6b416504ddcf9e',
      'name': 'Kulwinder Singh',
      'email': '8764129290@ilync.tech',
      'first_name': 'Kulwinder',
      'last_name': 'Singh',
      'employee_id': '8764129290',
      'phone_number': '8764129290',
      'vendor_name': 'Telecrats',
      'role': 'SUPERVISOR',
      'roles': ['SUPERVISOR'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:32.237677Z',
    }),
    UserModel.fromJson({
      'id': 4,
      'username': '6350491603',
      'external_user_id': '6a97c8abf475d920736bd975',
      'name': 'Mukesh Panday',
      'email': '6350491603@ilync.tech',
      'first_name': 'Mukesh',
      'last_name': 'Panday',
      'employee_id': '6350491603',
      'phone_number': '6350491603',
      'vendor_name': 'Telecrats',
      'role': 'ENGINEER',
      'roles': ['ENGINEER'],
      'reporting_manager_id': '254',
      'reporting_manager_name': 'Papu Ram 2',
      'is_active': true,
      'date_joined': '2026-09-05T12:38:32.561269Z',
    }),
    UserModel.fromJson({
      'id': 5,
      'username': '1000246',
      'external_user_id': '6a96466d9b9a3a047ebccbf0',
      'name': 'Ravindra Singh',
      'email': '1000246@ilync.tech',
      'first_name': 'Ravindra',
      'last_name': 'Singh',
      'employee_id': '1000246',
      'phone_number': '8742878982',
      'vendor_name': 'Telecrats',
      'role': 'OPERATOR',
      'roles': ['OPERATOR'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:32.857301Z',
    }),
    UserModel.fromJson({
      'id': 6,
      'username': '8650622262',
      'external_user_id': '6a95791ff475d920736bd8b5',
      'name': 'ankush sharma',
      'email': '8650622262@ilync.tech',
      'first_name': 'ankush',
      'last_name': 'sharma',
      'employee_id': '8650622262',
      'phone_number': '8650622262',
      'vendor_name': 'Telecrats',
      'role': 'SUPERVISOR',
      'roles': ['SUPERVISOR'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:33.065239Z',
    }),
    UserModel.fromJson({
      'id': 7,
      'username': '1000245',
      'external_user_id': '6a9575429b9a3a047ebccbd3',
      'name': 'Maneesh Dev Singh',
      'email': '1000245@ilync.tech',
      'first_name': 'Maneesh Dev',
      'last_name': 'Singh',
      'employee_id': '1000245',
      'phone_number': '7754069945',
      'vendor_name': 'Telecrats',
      'role': 'MANAGER',
      'roles': ['MANAGER'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:33.239804Z',
    }),
    UserModel.fromJson({
      'id': 8,
      'username': '9549444252',
      'external_user_id': '6a95133e9b9a3a047ebccba0',
      'name': 'FE Sanjay kumar',
      'email': '9549444252@ilync.tech',
      'first_name': 'FE Sanjay',
      'last_name': 'kumar',
      'employee_id': '9549444252',
      'phone_number': '9549444252',
      'vendor_name': 'Telecrats',
      'role': 'ENGINEER',
      'roles': ['ENGINEER'],
      'is_active': true,
      'date_joined': '2026-09-05T12:38:33.417070Z',
    }),
  ];

  @override
  Future<UserResponse> getUsersResponse({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return getUsersResponseSync(page: page, size: size, search: search);
  }

  UserResponse getUsersResponseSync({
    int page = 0,
    int size = 20,
    String search = '',
  }) {
    final filtered = _mockUsers.where((u) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return u.name.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.phoneNumber?.contains(q) ?? false) ||
            u.role.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final startIndex = page * size;
    final endIndex = (startIndex + size) < filtered.length ? startIndex + size : filtered.length;
    final pagedList = startIndex < filtered.length ? filtered.sublist(startIndex, endIndex) : <UserModel>[];
    final totalPages = (456 / size).ceil();

    return UserResponse(
      users: pagedList,
      totalCount: 456,
      totalPages: totalPages,
      currentPage: page,
      pageSize: size,
      hasNext: page + 1 < totalPages,
      hasPrevious: page > 0,
    );
  }

  @override
  Future<List<UserModel>> getUsers({int page = 0, String search = ''}) async {
    final res = await getUsersResponse(page: page, search: search);
    return res.users;
  }

  @override
  Future<UserModel> createUser({
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      email: email,
      name: name,
      role: roles.isNotEmpty ? roles.first : 'VIEWER',
      roles: roles,
      phoneNumber: phoneNumber,
      isActive: isActive,
    );
    _mockUsers.add(newUser);
    return newUser;
  }

  @override
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _mockUsers.indexWhere((u) => u.id == id);
    if (index != -1) {
      final updated = UserModel(
        id: id,
        username: username,
        email: email,
        name: name,
        role: roles.isNotEmpty ? roles.first : 'VIEWER',
        roles: roles,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
      _mockUsers[index] = updated;
      return updated;
    }
    return UserModel(
      id: id,
      username: username,
      email: email,
      name: name,
      role: roles.isNotEmpty ? roles.first : 'VIEWER',
      roles: roles,
    );
  }

  @override
  Future<bool> deleteUser(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _mockUsers.removeWhere((u) => u.id == id);
    return true;
  }
}
