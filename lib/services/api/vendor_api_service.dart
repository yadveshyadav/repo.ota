import 'package:flutter/foundation.dart';
import '../../models/vendor_response.dart';
import 'api_client.dart';

/// Dedicated Vendor API Service contacting backend REST endpoints
class VendorApiService {
  final ApiClient apiClient;

  VendorApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch paginated vendor list from GET /api/v1/integrations/vendors/
  Future<VendorResponse> fetchVendors({
    int page = 0,
    int size = 10,
    String search = '',
  }) async {
    final queryParams = 'page=$page&size=$size&search=${Uri.encodeComponent(search)}';
    final primaryEndpoint = '/api/v1/integrations/vendors/?$queryParams';
    final fallbackEndpoint = '/api/v1/integrations/vendors?$queryParams';

    if (kDebugMode) {
      print('[VendorApiService] GET $primaryEndpoint');
    }

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint);
    } catch (e) {
      if (kDebugMode) {
        print('[VendorApiService] Primary vendor endpoint failed ($e), trying fallback...');
      }
      response = await apiClient.get(fallbackEndpoint);
    }

    final vendorResponse = VendorResponse.fromJson(
      response,
      requestPage: page,
      requestSize: size,
    );

    if (kDebugMode) {
      print('[VendorApiService] Received ${vendorResponse.vendors.length} vendors (Total: ${vendorResponse.totalCount})');
    }

    return vendorResponse;
  }

  /// Fetch vendor detail by vendor ID from GET /api/v1/integrations/vendors/{vendorId}/
  Future<Map<String, dynamic>?> fetchVendorDetail(String vendorId) async {
    final primaryEndpoint = '/api/v1/integrations/vendors/$vendorId/';
    final fallbackEndpoint = '/api/v1/integrations/vendors/$vendorId';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
          final dataMap = response['data'] as Map<String, dynamic>;
          if (dataMap.containsKey('data') && dataMap['data'] is Map<String, dynamic>) {
            return dataMap['data'] as Map<String, dynamic>;
          }
          return dataMap;
        }
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VendorApiService] Fetch vendor detail failed ($e), trying fallback...');
      }
      try {
        final response = await apiClient.get(fallbackEndpoint);
        if (response is Map<String, dynamic>) {
          return response;
        }
      } catch (_) {}
    }
    return null;
  }
}
