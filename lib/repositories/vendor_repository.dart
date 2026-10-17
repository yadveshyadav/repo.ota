import 'package:flutter/foundation.dart';
import '../models/vendor.dart';
import '../models/vendor_response.dart';
import '../services/api/api_client.dart';
import '../services/api/vendor_api_service.dart';

/// Abstract Vendor Repository interface
abstract class VendorRepository {
  Future<VendorResponse> getVendors({
    int page = 0,
    int size = 10,
    String search = '',
    bool allowMockFallback = true,
  });
}

/// Production ApiVendorRepository consuming HERO / Vendor API endpoint
class ApiVendorRepository implements VendorRepository {
  final VendorApiService apiService;

  ApiVendorRepository({ApiClient? apiClient, VendorApiService? apiService})
    : apiService =
          apiService ?? VendorApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<VendorResponse> getVendors({
    int page = 0,
    int size = 10,
    String search = '',
    bool allowMockFallback = true,
  }) async {
    try {
      return await apiService.fetchVendors(
        page: page,
        size: size,
        search: search,
      );
    } catch (e) {
      if (!allowMockFallback) rethrow;
      if (kDebugMode) {
        print(
          '[ApiVendorRepository] Error fetching vendors ($e), falling back to mock dataset.',
        );
      }
      return MockVendorRepository().getVendors(
        page: page,
        size: size,
        search: search,
        allowMockFallback: false,
      );
    }
  }
}

/// Sample repository for unit tests or offline sandbox environments
class MockVendorRepository implements VendorRepository {
  static final List<Vendor> _mockVendors = [
    Vendor.fromJson({
      'id': '6aa540a512381cfcdf6a1ed5',
      'partnerName': 'Premium infra solutions',
      'legalEntityType': 'FIRM',
      'contactName': 'Satyanarayan Rajpurohit',
      'email': 'satyanarayan.pratapsikar@gmail.com',
      'phoneNumber': '9664115330',
      'circle': 'RAJASTHAN',
      'district': 'CHURU',
      'status': 'ACTIVE',
      'users': [
        {
          'name': 'Satyanarayan Rajpurohit',
          'mobile': '9664115330',
          'designation': 'VENDOR',
        },
        {
          'name': 'Rakesh karwasra',
          'mobile': '9116485564',
          'designation': 'OPERATOR',
        },
        {'name': 'Balaram', 'mobile': '8955011301', 'designation': 'TRACKER'},
      ],
    }),
    Vendor.fromJson({
      'id': '6aa7732712381cfcdf6a1ed6',
      'partnerName': 'APM ENTERPRISES',
      'legalEntityType': 'FIRM',
      'contactName': 'Mohit Jakhar',
      'email': 'jakharmohit@gmail.com',
      'phoneNumber': '9024065621',
      'circle': 'RAJASTHAN',
      'district': 'GANGANAGAR',
      'status': 'ACTIVE',
      'users': [
        {
          'name': 'Mohit Jakhar',
          'mobile': '9024065621',
          'designation': 'VENDOR',
        },
        {
          'name': 'Pintu Kumar',
          'mobile': '9507535074',
          'designation': 'OPERATOR',
        },
      ],
    }),
    Vendor.fromJson({
      'id': '6a7c2b4f8e16e804697f18b0',
      'partnerName': 'Gurukripa Enterprises',
      'legalEntityType': 'COMPANY',
      'contactName': 'Sh Sukhram',
      'email': 'gurukripaenterprises421@gmail.com',
      'phoneNumber': '9799506422',
      'circle': 'RAJASTHAN',
      'district': 'CHURU',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a852f2600cd99ac6337f4a9',
      'partnerName': 'HARPAL INFRA DEVELOPMENT',
      'legalEntityType': 'COMPANY',
      'contactName': 'Harpal Singh',
      'email': 'harpalgillgill33@gmail.com',
      'phoneNumber': '7296905661',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a8bdb93b8fd1ac215ebfeed',
      'partnerName': 'KHALSA TELECOM',
      'legalEntityType': 'FIRM',
      'contactName': 'Kulwant Singh',
      'email': 'Kulwant.khalsa@gmail.com',
      'phoneNumber': '9001799261',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a9550b4544bdedf53d4ec0b',
      'partnerName': 'Naveen Chouhan',
      'legalEntityType': 'INDIVIDUAL',
      'contactName': 'Naveen Chouhan',
      'email': 'Naveen@gmail.com',
      'phoneNumber': '9468018361',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a8a77d5b8fd1ac215ebfeeb',
      'partnerName': 'Naveen Telecom',
      'legalEntityType': 'FIRM',
      'contactName': 'Papu Ram',
      'email': 'prgolliya75@gmail.com',
      'phoneNumber': '9799272425',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a8badb1b8fd1ac215ebfeec',
      'partnerName': 'Naveen Telecom Network',
      'legalEntityType': 'FIRM',
      'contactName': 'Papu Ram 1',
      'email': 'prgolliya751@gmail.com',
      'phoneNumber': '9799272426',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a97b260544bdedf53d4ec0c',
      'partnerName': 'Naveen Telecom Network 1',
      'legalEntityType': 'FIRM',
      'contactName': 'Rajendra Singh',
      'email': 'rajendra9772@gmail.com',
      'phoneNumber': '8619545411',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a9d22c43fe4e1b061d189a9',
      'partnerName': 'Naveen Telecom Network 2',
      'legalEntityType': 'FIRM',
      'contactName': 'Papu Ram 2',
      'email': 'prgolliya758@gmail.com',
      'phoneNumber': '9799272429',
      'circle': 'RAJASTHAN',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a82e6f24312cab2fd6d36cd',
      'partnerName': 'Pranjal Enterprises',
      'legalEntityType': 'COMPANY',
      'contactName': 'Rajkamal bisnoi',
      'email': 'Pranjalenterprisespdp@gmail.com',
      'phoneNumber': '7062891007',
      'status': 'ACTIVE',
    }),
    Vendor.fromJson({
      'id': '6a8fc284544bdedf53d4ec09',
      'partnerName': 'Raj Enterprises',
      'legalEntityType': 'COMPANY',
      'contactName': 'Sanwar lal',
      'email': 'sanwarkalwar881@gmail.com',
      'phoneNumber': '9928396031',
      'status': 'ACTIVE',
    }),
  ];

  @override
  Future<VendorResponse> getVendors({
    int page = 0,
    int size = 10,
    String search = '',
    bool allowMockFallback = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final filtered = _mockVendors.where((v) {
      if (search.isEmpty) return true;
      final q = search.toLowerCase();
      return v.vendorName.toLowerCase().contains(q) ||
          v.contactPerson.toLowerCase().contains(q) ||
          (v.email?.toLowerCase().contains(q) ?? false) ||
          (v.vendorCode?.toLowerCase().contains(q) ?? false);
    }).toList();

    final startIndex = page * size;
    final endIndex = (startIndex + size) < filtered.length
        ? startIndex + size
        : filtered.length;

    final pagedList = startIndex < filtered.length
        ? filtered.sublist(startIndex, endIndex)
        : <Vendor>[];
    final totalPages = (18 / size).ceil();

    return VendorResponse(
      vendors: pagedList,
      totalCount: 18,
      totalPages: totalPages,
      currentPage: page,
      pageSize: size,
      hasNext: page + 1 < totalPages,
      hasPrevious: page > 0,
    );
  }
}
