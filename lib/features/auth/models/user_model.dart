import '../../../services/authorization_service.dart';

/// Strongly-typed model for logged-in user profile & Team Member entity from HERO Users API
class UserModel {
  final String id;
  final String? externalUserId;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String name;
  final String role;
  final List<String> roles;
  final List<String> permissions;
  final dynamic vendor;
  final List<Map<String, dynamic>> vendors;
  final Map<String, dynamic>? vendorDetails;
  final String? vendorName;
  final String? phoneNumber;
  final String? employeeId;
  final String? reportingManagerId;
  final String? reportingManagerName;
  final bool isActive;
  final String? avatar;
  final DateTime? dateJoined;
  final String? machineChassis;

  const UserModel({
    required this.id,
    this.externalUserId,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.name = '',
    this.role = 'ADMIN',
    this.roles = const ['ADMIN'],
    this.permissions = const [],
    this.vendor,
    this.vendors = const [],
    this.vendorDetails,
    this.vendorName,
    this.phoneNumber,
    this.employeeId,
    this.reportingManagerId,
    this.reportingManagerName,
    this.isActive = true,
    this.avatar,
    this.dateJoined,
    this.machineChassis,
  });

  String? get vendorId {
    if (vendor is Map) {
      return (vendor['id'] ?? vendor['vendorId'] ?? vendor['vendor_id'])?.toString();
    }
    if (vendorDetails != null) {
      return (vendorDetails!['id'] ?? vendorDetails!['vendorId'] ?? vendorDetails!['vendor_id'])?.toString();
    }
    if (vendor != null && vendor is! Map) {
      return vendor.toString();
    }
    return null;
  }

  String get displayName {
    // 1. First + Last name if non-numeric
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty && !RegExp(r'^\d+$').hasMatch(combined)) {
      return combined;
    }

    // 2. Name if non-numeric
    final cleanName = name.trim();
    if (cleanName.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cleanName)) {
      return cleanName;
    }

    // 3. Vendor Name if available
    final v = vendorName ??
        (vendorDetails != null ? vendorDetails!['name']?.toString() : null) ??
        (vendors.isNotEmpty ? vendors.first['name']?.toString() : null);

    if (v != null && v.trim().isNotEmpty && v != 'Unassigned Vendor') {
      return v.trim();
    }

    // 4. Username if non-numeric
    final cleanUsername = username.trim();
    if (cleanUsername.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cleanUsername)) {
      return cleanUsername;
    }

    // 5. Fallback to vendor name or non-empty string
    if (v != null && v.trim().isNotEmpty && v != 'Unassigned Vendor') return v.trim();
    if (cleanName.isNotEmpty && cleanName != 'Employee' && cleanName != 'User') return cleanName;

    return 'HERO User';
  }

  String get fullName => displayName;

  String get displayEmployeeId => (employeeId != null && employeeId!.isNotEmpty) ? employeeId! : username;

  String get displayVendor => vendorName ?? (vendorDetails != null ? vendorDetails!['name']?.toString() : null) ?? 'Unassigned Vendor';

  String get initials {
    final clean = displayName.trim();
    if (clean.isEmpty) return 'U';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  // Permission Checks based on Authorization Service & Permission code evaluation
  bool hasPermission(String perm) {
    if (perm.isEmpty) return true;

    // Use Centralized Authorization Service if effective permissions exist
    final auth = AuthorizationService.instance;
    if (auth.effectivePermissions.isNotEmpty) {
      return auth.can(perm);
    }

    // Direct permissions list check
    if (permissions.contains(perm)) return true;

    // Hierarchy check: module.manage grants module.action
    if (perm.contains('.')) {
      final module = perm.split('.').first;
      if (permissions.contains('$module.manage')) return true;
    }

    // Default fallback check
    if (permissions.isNotEmpty) {
      return permissions.contains(perm);
    }

    return true;
  }

  bool get canViewDashboard => hasPermission('dashboard.view');
  bool get canViewMachines => hasPermission('machines.view');
  bool get canManageMachines => hasPermission('machines.manage');
  bool get canViewTracking => hasPermission('tracking.view');
  bool get canViewTasks => hasPermission('tasks.view');
  bool get canCreateTasks => hasPermission('tasks.create');
  bool get canViewVendors => hasPermission('vendors.view');
  bool get canManageVendors => hasPermission('vendors.manage');
  bool get canViewTeam => hasPermission('team.view');

  // Role Checks
  bool get isAdmin =>
      role.toUpperCase() == 'ADMIN' || roles.contains('ADMIN');
  bool get isProjectManager =>
      role.toUpperCase() == 'PROJECT_MANAGER' ||
      roles.contains('PROJECT_MANAGER');
  bool get isSupervisor =>
      role.toUpperCase() == 'SUPERVISOR' || roles.contains('SUPERVISOR');
  bool get isEngineer =>
      role.toUpperCase() == 'ENGINEER' || roles.contains('ENGINEER');
  bool get isOperator =>
      role.toUpperCase() == 'OPERATOR' || roles.contains('OPERATOR');
  bool get isVendorUser =>
      role.toUpperCase() == 'VENDOR' ||
      roles.contains('VENDOR') ||
      vendorDetails != null;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['pk'] ?? json['user_id'] ?? json['userId'] ?? '';
    final extId = json['external_user_id'] ?? json['externalUserId'] ?? json['external_id']?.toString();
    final rawFirst = json['first_name'] ?? json['firstName'] ?? '';
    final rawLast = json['last_name'] ?? json['lastName'] ?? '';
    final rawName = json['user_name'] ?? json['name'] ?? '$rawFirst $rawLast'.trim();
    final rawUsername =
        json['username'] ?? json['email']?.toString().split('@').first ?? (rawName.toString().isNotEmpty ? rawName.toString() : 'user');
    final rawEmail = json['email'] ?? '';
    final rawRole = json['role'] ?? json['user_type'] ?? 'OPERATOR';

    final rolesList = (json['roles'] is List)
        ? (json['roles'] as List<dynamic>).map((e) => e.toString()).toList()
        : [rawRole.toString()];

    final permissionsList = (json['permissions'] is List)
        ? (json['permissions'] as List<dynamic>).map((e) => e.toString()).toList()
        : <String>[];

    final vendorsList = (json['vendors'] is List)
        ? (json['vendors'] as List<dynamic>)
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    Map<String, dynamic>? vDetails;
    if (json['vendor_details'] is Map) {
      vDetails = Map<String, dynamic>.from(json['vendor_details'] as Map);
    }

    final vendorObj = json['vendor'] is Map<String, dynamic> ? json['vendor'] as Map<String, dynamic> : null;
    final vendorStr = json['vendor'] is String ? json['vendor'] as String : null;

    final vName = json['vendor_name']?.toString() ??
        (vendorObj != null ? vendorObj['name']?.toString() : null) ??
        (vendorStr != null && vendorStr.trim().isNotEmpty ? vendorStr.trim() : null) ??
        (vDetails != null ? vDetails['name']?.toString() : null) ??
        (vendorsList.isNotEmpty ? vendorsList.first['name']?.toString() : null);

    final managerObj = json['reporting_manager'] is Map<String, dynamic>
        ? json['reporting_manager'] as Map<String, dynamic>
        : null;

    final managerId = json['reporting_manager_id']?.toString() ??
        json['reportingManagerId']?.toString() ??
        managerObj?['id']?.toString();

    final managerName = json['reporting_manager_name']?.toString() ??
        json['reportingManagerName']?.toString() ??
        managerObj?['name']?.toString() ??
        managerObj?['username']?.toString();

    DateTime? parsedJoined;
    if (json['date_joined'] != null) {
      parsedJoined = DateTime.tryParse(json['date_joined'].toString());
    } else if (json['createdAt'] != null) {
      parsedJoined = DateTime.tryParse(json['createdAt'].toString());
    }

    final rawMachine = json['machine']?.toString() ??
        json['machine_chassis_no']?.toString() ??
        json['machine_id']?.toString() ??
        json['machineChassis']?.toString();

    return UserModel(
      id: rawId.toString(),
      externalUserId: extId,
      username: rawUsername.toString(),
      email: rawEmail.toString(),
      firstName: rawFirst.toString(),
      lastName: rawLast.toString(),
      name: rawName.toString(),
      role: rawRole.toString(),
      roles: rolesList,
      permissions: permissionsList,
      vendor: json['vendor'],
      vendors: vendorsList,
      vendorDetails: vDetails,
      vendorName: vName,
      phoneNumber: json['phone_number']?.toString() ?? json['phone']?.toString(),
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString(),
      reportingManagerId: managerId,
      reportingManagerName: managerName,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      avatar: json['avatar']?.toString(),
      dateJoined: parsedJoined,
      machineChassis: (rawMachine != null && rawMachine.isNotEmpty && rawMachine != 'null') ? rawMachine : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (externalUserId != null) 'external_user_id': externalUserId,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'name': name,
        'role': role,
        'roles': roles,
        'permissions': permissions,
        if (vendor != null) 'vendor': vendor,
        'vendors': vendors,
        'vendor_details': vendorDetails,
        if (vendorName != null) 'vendor_name': vendorName,
        'phone_number': phoneNumber,
        'employee_id': employeeId,
        if (reportingManagerId != null) 'reporting_manager_id': reportingManagerId,
        if (reportingManagerName != null) 'reporting_manager_name': reportingManagerName,
        'is_active': isActive,
        'avatar': avatar,
        if (dateJoined != null) 'date_joined': dateJoined!.toIso8601String(),
      };
}
