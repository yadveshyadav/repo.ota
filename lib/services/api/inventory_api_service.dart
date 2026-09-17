import 'package:flutter/foundation.dart';
import '../../models/stock_issue_model.dart';
import '../../models/stock_item_model.dart';
import 'api_client.dart';

/// Dedicated Inventory API Service contacting verified Hero backend endpoints
class InventoryApiService {
  final ApiClient apiClient;

  InventoryApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch stock issue items search results from
  /// GET /api/v1/integrations/inventory/stock-issue-items/search/
  Future<StockItemResponse> fetchStockIssueItems({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    final queryParams = StringBuffer('page=$page&size=$size');
    if (search.trim().isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search.trim())}');
    }

    final queryString = queryParams.toString();
    final primaryEndpoint = '/api/v1/integrations/inventory/stock-issue-items/search/?$queryString';
    final fallbackEndpoint = '/api/v1/integrations/inventory/stock-issue-items/search?$queryString';

    if (kDebugMode) {
      print('[InventoryApiService] GET $primaryEndpoint');
    }

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        print('[InventoryApiService] Primary stock issue items endpoint failed ($e), trying fallback...');
      }
      response = await apiClient.get(fallbackEndpoint).timeout(const Duration(seconds: 10));
    }

    final itemResponse = StockItemResponse.fromJson(
      response,
      requestPage: page,
      requestSize: size,
    );

    if (kDebugMode) {
      print(
          '[InventoryApiService] Received ${itemResponse.items.length} stock items (Total: ${itemResponse.totalElements}, Page: ${itemResponse.currentPage}/${itemResponse.totalPages})');
    }

    return itemResponse;
  }

  /// Fetch stock issues list from
  /// GET /api/v1/integrations/inventory/stock-issues/
  Future<StockIssueResponse> fetchStockIssues({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    final queryParams = StringBuffer('page=$page&size=$size');
    if (search.trim().isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search.trim())}');
    }

    final queryString = queryParams.toString();
    final primaryEndpoint = '/api/v1/integrations/inventory/stock-issues/?$queryString';
    final fallbackEndpoint = '/api/v1/integrations/inventory/stock-issues?$queryString';

    if (kDebugMode) {
      print('[InventoryApiService] GET $primaryEndpoint');
    }

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        print('[InventoryApiService] Primary stock issues endpoint failed ($e), trying fallback...');
      }
      response = await apiClient.get(fallbackEndpoint).timeout(const Duration(seconds: 10));
    }

    final issueResponse = StockIssueResponse.fromJson(
      response,
      requestPage: page,
      requestSize: size,
    );

    if (kDebugMode) {
      print(
          '[InventoryApiService] Received ${issueResponse.issues.length} stock issues (Total: ${issueResponse.totalElements}, Page: ${issueResponse.currentPage}/${issueResponse.totalPages})');
    }

    return issueResponse;
  }
}
