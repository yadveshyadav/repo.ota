import 'package:http/http.dart' as http;
import '../../../services/api/api_client.dart';
import '../models/expense_models.dart';

/// REST API Service handling all Expense operations via ApiClient
class ExpenseApiService {
  final ApiClient apiClient;

  ExpenseApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch Expense Categories from GET /api/v1/expenses/categories/
  Future<List<ExpenseCategory>> fetchCategories({String search = ''}) async {
    final ep = search.trim().isNotEmpty
        ? '/api/v1/expenses/categories/?search=${Uri.encodeComponent(search.trim())}'
        : '/api/v1/expenses/categories/';

    final response = await apiClient.get(ep);
    List<dynamic> list = [];
    if (response is List) {
      list = response;
    } else if (response is Map<String, dynamic>) {
      if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      } else if (response['data'] is List) {
        list = response['data'] as List<dynamic>;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => ExpenseCategory.fromJson(j))
        .toList();
  }

  /// Fetch Subcategories for Category from GET /api/v1/expenses/subcategories/?category_id={id}
  Future<List<ExpenseSubcategory>> fetchSubcategories(String categoryId) async {
    final ep = '/api/v1/expenses/subcategories/?category_id=$categoryId';
    final response = await apiClient.get(ep);
    List<dynamic> list = [];
    if (response is List) {
      list = response;
    } else if (response is Map<String, dynamic>) {
      if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      } else if (response['data'] is List) {
        list = response['data'] as List<dynamic>;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => ExpenseSubcategory.fromJson(j))
        .toList();
  }

  /// Fetch Dashboard Statistics from GET /api/v1/expenses/dashboard_stats/
  Future<ExpenseDashboardStats> fetchDashboardStats() async {
    const ep = '/api/v1/expenses/dashboard_stats/';
    final response = await apiClient.get(ep);
    return ExpenseDashboardStats.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Fetch Paginated Expense List from GET /api/v1/expenses/
  Future<ExpenseListResponse> fetchExpenses({
    int page = 1,
    int size = 20,
    String? status,
    String? category,
    String? dateFrom,
    String? dateTo,
    String search = '',
  }) async {
    final queryParams = StringBuffer('page=$page&size=$size');

    if (status != null && status.isNotEmpty && status != 'ALL') {
      queryParams.write('&status=${Uri.encodeComponent(status.toUpperCase())}');
    }
    if (category != null && category.isNotEmpty && category != 'ALL') {
      queryParams.write('&category=${Uri.encodeComponent(category)}');
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams.write('&date_from=${Uri.encodeComponent(dateFrom)}');
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams.write('&date_to=${Uri.encodeComponent(dateTo)}');
    }
    if (search.trim().isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search.trim())}');
    }

    final ep = '/api/v1/expenses/?${queryParams.toString()}';
    final response = await apiClient.get(ep);
    return ExpenseListResponse.fromJson(response, requestPage: page, requestSize: size);
  }

  /// Fetch Detailed Expense Record from GET /api/v1/expenses/{id}/
  Future<Expense> fetchExpenseDetail(String id) async {
    final ep = '/api/v1/expenses/$id/';
    final response = await apiClient.get(ep);
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Create Expense (or Draft) via POST /api/v1/expenses/ with multipart attachment
  Future<Expense> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  }) async {
    const ep = '/api/v1/expenses/';
    final response = await apiClient.postMultipart(
      ep,
      fields: fields,
      file: attachmentFile,
    );
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Submit existing Draft via POST /api/v1/expenses/{id}/submit/
  Future<Expense> submitDraft(String id) async {
    final ep = '/api/v1/expenses/$id/submit/';
    final response = await apiClient.post(ep, body: {});
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Approve Expense via POST /api/v1/expenses/{id}/approve/
  Future<Expense> approveExpense(String id) async {
    final ep = '/api/v1/expenses/$id/approve/';
    final response = await apiClient.post(ep, body: {});
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Reject Expense via POST /api/v1/expenses/{id}/reject/
  Future<Expense> rejectExpense(String id, String reason) async {
    final ep = '/api/v1/expenses/$id/reject/';
    final response = await apiClient.post(ep, body: {'reason': reason});
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }

  /// Mark Expense as Paid via POST /api/v1/expenses/{id}/pay/
  Future<Expense> payExpense(String id, String paymentMode, String paymentReference) async {
    final ep = '/api/v1/expenses/$id/pay/';
    final response = await apiClient.post(ep, body: {
      'payment_mode': paymentMode,
      'payment_reference': paymentReference,
    });
    return Expense.fromJson(response is Map<String, dynamic> ? response : {});
  }
}
