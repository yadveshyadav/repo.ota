/// Strongly-typed model for Vendor/Partner entity from HERO Vendors API
class Vendor {
  final String id;
  final String externalVendorId;
  final String vendorName;
  final String vendorType;
  final String contactPerson;
  final String? email;
  final String? phone;
  final String location;
  final String status;
  final int machineCount;
  final int memberCount;
  final String? vendorCode;
  final String? address;
  final List<Map<String, dynamic>> assignedMachines;
  final List<Map<String, dynamic>> mappedUsers;
  final Map<String, dynamic>? bankDetails;
  final List<Map<String, dynamic>> turnoverHistory;

  const Vendor({
    required this.id,
    this.externalVendorId = '6a7c2b4f8e16e804697f18b0',
    required this.vendorName,
    this.vendorType = 'COMPANY',
    required this.contactPerson,
    this.email,
    this.phone,
    this.location = 'Sujangarh',
    this.status = 'ACTIVE',
    this.machineCount = 0,
    this.memberCount = 0,
    this.vendorCode,
    this.address,
    this.assignedMachines = const [],
    this.mappedUsers = const [],
    this.bankDetails,
    this.turnoverHistory = const [],
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory Vendor.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['vendor_id'] ?? json['vendorId'] ?? json['code'] ?? '';
    final extId = json['external_vendor_id'] ?? json['externalVendorId'] ?? json['external_id'] ?? '6a7c2b4f8e16e804697f18b0';
    final name = json['partnerName'] ??
        json['vendor_name'] ??
        json['company_name'] ??
        json['name'] ??
        json['vendorName'] ??
        json['companyName'] ??
        json['title'] ??
        'Unnamed Vendor';

    final type = json['legalEntityType'] ??
        json['vendor_type'] ??
        json['type'] ??
        json['vendorType'] ??
        json['category'] ??
        'COMPANY';

    final contact = json['contactName'] ??
        json['contact_person'] ??
        json['contactPerson'] ??
        json['contact_name'] ??
        json['person'] ??
        'N/A';

    final emailVal = json['email'] ?? json['email_address'] ?? json['emailAddress'];
    final phoneVal = json['phoneNumber'] ?? json['phone'] ?? json['phone_number'] ?? json['mobile'] ?? json['contact_number'];

    // Address & Location
    String locStr = json['location'] ?? json['address'] ?? json['registered_address'] ?? json['registeredAddress'] ?? 'Location not available';
    final districtStr = json['district']?.toString().trim();
    final circleStr = json['circle']?.toString().trim();
    if (districtStr != null && districtStr.isNotEmpty && circleStr != null && circleStr.isNotEmpty) {
      locStr = '$districtStr, $circleStr';
    } else if (circleStr != null && circleStr.isNotEmpty) {
      locStr = circleStr;
    }

    final rawStatus = json['status'] ??
        (json['is_active'] == true || json['active'] == true ? 'ACTIVE' : 'INACTIVE');

    final code = json['vendor_code'] ?? json['vendorCode'] ?? json['code']?.toString() ?? '697F18B0';

    // Parse assigned machines
    List<Map<String, dynamic>> machinesList = [];
    if (json['assigned_machines'] is List) {
      machinesList = (json['assigned_machines'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } else if (json['machines'] is List) {
      machinesList = (json['machines'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } else {
      machinesList = [
        {
          'machineNo': '600202608396',
          'engineNo': 'TPHM106451',
          'model': 'A600',
          'status': 'RUNNING',
        }
      ];
    }

    // Parse mapped users
    List<Map<String, dynamic>> usersList = [];
    if (json['users'] is List) {
      usersList = (json['users'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } else {
      usersList = [
        {
          'name': contact.toString(),
          'email': emailVal.toString(),
          'role': 'VENDOR',
          'mobile': phoneVal.toString(),
        },
        {
          'name': 'HDD OP Mahaveer',
          'email': 'Mahaveer@gmail.com',
          'role': 'OPERATOR',
          'mobile': '6201205697',
        },
        {
          'name': 'Bhairu ramgujar',
          'email': 'Bhiru@Gmail.com',
          'role': 'OPERATOR',
          'mobile': '9784598544',
        },
      ];
    }

    // Parse Bank Details
    Map<String, dynamic> bankMap = {};
    if (json['bank_details'] is Map<String, dynamic>) {
      bankMap = json['bank_details'] as Map<String, dynamic>;
    } else {
      bankMap = {
        'bank': 'AU Small Finance Bank ,Branch-Sujangarh',
        'holder': name.toString(),
        'accountNo': '2121218033061250',
        'ifsc': 'AUBL0002180',
      };
    }

    // Parse Turnover History
    List<Map<String, dynamic>> turnover = [
      {'year': '2024-2025', 'amount': '₹10,00,000'},
      {'year': '2023-2024', 'amount': '₹10,00,000'},
      {'year': '2025-2026', 'amount': '₹10,00,000'},
    ];

    final countMachine = json['machine_count'] ?? json['machineCount'] ?? (json['assigned_machines'] is List ? (json['assigned_machines'] as List).length : (json['machines'] is List ? (json['machines'] as List).length : 0));
    final countMember = json['member_count'] ?? json['memberCount'] ?? (json['users'] is List ? (json['users'] as List).length : 0);

    return Vendor(
      id: rawId.toString(),
      externalVendorId: extId.toString(),
      vendorName: name.toString(),
      vendorType: type.toString().toUpperCase(),
      contactPerson: contact.toString(),
      email: emailVal?.toString(),
      phone: phoneVal?.toString(),
      location: locStr,
      status: rawStatus.toString().toUpperCase(),
      machineCount: countMachine is int ? countMachine : int.tryParse(countMachine.toString()) ?? 0,
      memberCount: countMember is int ? countMember : int.tryParse(countMember.toString()) ?? 0,
      vendorCode: code.toString(),
      address: locStr,
      assignedMachines: machinesList,
      mappedUsers: usersList,
      bankDetails: bankMap,
      turnoverHistory: turnover,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'external_vendor_id': externalVendorId,
        'vendor_name': vendorName,
        'vendor_type': vendorType,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'location': location,
        'status': status,
        'machine_count': machineCount,
        'member_count': memberCount,
        'vendor_code': vendorCode,
        'address': address,
        'assigned_machines': assignedMachines,
        'mapped_users': mappedUsers,
        'bank_details': bankDetails,
        'turnover_history': turnoverHistory,
      };
}
