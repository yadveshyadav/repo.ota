import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api/api_client.dart';
import '../models/expense_models.dart';
import '../services/expense_api_service.dart';

/// Abstract Expense Repository Contract
abstract class ExpenseRepository {
  Future<ExpenseDashboardStats> getDashboardStats();

  Future<List<ExpenseCategory>> getCategories({String search = ''});

  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId);

  Future<ExpenseListResponse> getExpenses({
    int page = 1,
    int size = 20,
    String? status,
    String? category,
    String? dateFrom,
    String? dateTo,
    String search = '',
  });

  Future<Expense> getExpenseDetail(String id);

  Future<Expense> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  });

  Future<Expense> submitDraft(String id);

  Future<Expense> approveExpense(String id);

  Future<Expense> rejectExpense(String id, String reason);

  Future<Expense> payExpense(
    String id,
    String paymentMode,
    String paymentReference,
  );
}

/// Production API Expense Repository consuming ExpenseApiService
class ApiExpenseRepository implements ExpenseRepository {
  final ExpenseApiService apiService;

  ApiExpenseRepository({ApiClient? apiClient, ExpenseApiService? apiService})
      : apiService = apiService ??
            ExpenseApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<ExpenseDashboardStats> getDashboardStats() async {
    try {
      return await apiService.fetchDashboardStats();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error fetching dashboard stats: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<ExpenseCategory>> getCategories({String search = ''}) async {
    try {
      return await apiService.fetchCategories(search: search);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error fetching categories: $e');
      }
      return [];
    }
  }

  @override
  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId) async {
    try {
      return await apiService.fetchSubcategories(categoryId);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error fetching subcategories: $e');
      }
      return [];
    }
  }

  @override
  Future<ExpenseListResponse> getExpenses({
    int page = 1,
    int size = 20,
    String? status,
    String? category,
    String? dateFrom,
    String? dateTo,
    String search = '',
  }) async {
    try {
      return await apiService.fetchExpenses(
        page: page,
        size: size,
        status: status,
        category: category,
        dateFrom: dateFrom,
        dateTo: dateTo,
        search: search,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error fetching expenses: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> getExpenseDetail(String id) async {
    try {
      return await apiService.fetchExpenseDetail(id);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error fetching expense detail: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  }) async {
    try {
      return await apiService.createExpense(
        fields: fields,
        attachmentFile: attachmentFile,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error creating expense: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> submitDraft(String id) async {
    try {
      return await apiService.submitDraft(id);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error submitting draft: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> approveExpense(String id) async {
    try {
      return await apiService.approveExpense(id);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error approving expense: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> rejectExpense(String id, String reason) async {
    try {
      return await apiService.rejectExpense(id, reason);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error rejecting expense: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> payExpense(
    String id,
    String paymentMode,
    String paymentReference,
  ) async {
    try {
      return await apiService.payExpense(id, paymentMode, paymentReference);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] Error marking expense as paid: $e');
      }
      rethrow;
    }
  }
}

/// Mock Expense Repository for testing and offline development
class MockExpenseRepository implements ExpenseRepository {
  static final List<ExpenseCategory> _mockCategories = [
    const ExpenseCategory(
      id: '1',
      name: 'Machine Maintenance & Repairs',
      code: 'MAINT',
      uom: 'Hours',
      requiresProof: true,
      subcategories: [
        ExpenseSubcategory(id: '101', name: 'Engine Oil Replacement', categoryId: '1'),
        ExpenseSubcategory(id: '102', name: 'Hydraulic Filter Replacement', categoryId: '1'),
      ],
    ),
    const ExpenseCategory(
      id: '2',
      name: 'Fuel & Lubricants',
      code: 'FUEL',
      uom: 'Liters',
      requiresProof: true,
      subcategories: [
        ExpenseSubcategory(id: '201', name: 'High Speed Diesel', categoryId: '2'),
        ExpenseSubcategory(id: '202', name: 'Grease & Lubricants', categoryId: '2'),
      ],
    ),
    const ExpenseCategory(
      id: '3',
      name: 'Raw Materials & Drilling Mud',
      code: 'RAW',
      uom: 'Bags',
      requiresProof: false,
      subcategories: [
        ExpenseSubcategory(id: '301', name: 'Bentonite Powder', categoryId: '3'),
      ],
    ),
  ];

  static final List<Expense> _mockExpenses = [
    Expense.fromJson({
      'id': 'EXP-2026-0104',
      'title': 'Engine Oil Replacement',
      'expense_date': '2026-09-16',
      'amount': 5310.0,
      'category_name': 'Machine Maintenance & Repairs',
      'subcategory_name': 'Engine Oil Replacement',
      'quantity': 1,
      'unit': 'Hours',
      'rate': 4500,
      'discount': 0,
      'gst_applicable': true,
      'gst_percentage': 18,
      'supplier_name': 'Apollos Spares Sujangarh',
      'invoice_number': 'INV-88912',
      'site': 'Sujangarh-SITE',
      'machine': 'A800 HDD (8595)',
      'payment_mode': 'UPI',
      'status': 'SUBMITTED',
      'created_by_name': 'Ramesh Kumar',
    }),
    Expense.fromJson({
      'id': 'EXP-2026-0102',
      'title': 'Diesel Fuel Refill',
      'expense_date': '2026-09-15',
      'amount': 12500.0,
      'category_name': 'Fuel & Lubricants',
      'subcategory_name': 'High Speed Diesel',
      'quantity': 131.5,
      'unit': 'Liters',
      'rate': 95,
      'discount': 0,
      'gst_applicable': false,
      'supplier_name': 'Indian Oil Banswara',
      'invoice_number': 'INV-77210',
      'site': 'Banswara-SITE',
      'machine': 'A600 HDD (8400)',
      'payment_mode': 'CASH',
      'status': 'APPROVED',
      'created_by_name': 'Suresh Sharma',
    }),
    Expense.fromJson({
      'id': 'EXP-2026-0101',
      'title': 'Bentonite Chemical Powder',
      'expense_date': '2026-09-14',
      'amount': 24000.0,
      'category_name': 'Raw Materials & Drilling Mud',
      'subcategory_name': 'Bentonite Powder',
      'quantity': 30,
      'unit': 'Bags',
      'rate': 800,
      'discount': 0,
      'gst_applicable': false,
      'supplier_name': 'Raj Mineral Corp',
      'invoice_number': 'INV-66102',
      'site': 'Nagaur-SITE',
      'machine': 'A600 HDD (8396)',
      'payment_mode': 'BANK_TRANSFER',
      'status': 'PAID',
      'payment_reference': 'UTR-99182',
      'created_by_name': 'Vikram Singh',
    }),
  ];

  @override
  Future<ExpenseDashboardStats> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final double totalAmount = _mockExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final int submittedCount = _mockExpenses.where((e) => e.isSubmitted).length;
    final double submittedAmount = _mockExpenses.where((e) => e.isSubmitted).fold(0.0, (sum, e) => sum + e.amount);
    final int approvedCount = _mockExpenses.where((e) => e.isApproved).length;
    final double approvedAmount = _mockExpenses.where((e) => e.isApproved).fold(0.0, (sum, e) => sum + e.amount);

    return ExpenseDashboardStats(
      totalCount: _mockExpenses.length,
      totalAmount: totalAmount,
      todayAmount: 5310.0,
      monthAmount: totalAmount,
      submittedCount: submittedCount,
      submittedAmount: submittedAmount,
      approvedCount: approvedCount,
      approvedAmount: approvedAmount,
      rejectedCount: _mockExpenses.where((e) => e.isRejected).length,
      paidCount: _mockExpenses.where((e) => e.isPaid).length,
      byCategory: [
        ExpenseCategorySummary(
          category: 'Machine Maintenance & Repairs',
          amount: 5310.0,
          count: 1,
        ),
        ExpenseCategorySummary(
          category: 'Fuel & Lubricants',
          amount: 12500.0,
          count: 1,
        ),
        ExpenseCategorySummary(
          category: 'Raw Materials & Drilling Mud',
          amount: 24000.0,
          count: 1,
        ),
      ],
    );
  }

  @override
  Future<List<ExpenseCategory>> getCategories({String search = ''}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (search.trim().isEmpty) return List.from(_mockCategories);
    final q = search.trim().toLowerCase();
    return _mockCategories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final cat = _mockCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const ExpenseCategory(id: '', name: ''),
    );
    return cat.subcategories;
  }

  @override
  Future<ExpenseListResponse> getExpenses({
    int page = 1,
    int size = 20,
    String? status,
    String? category,
    String? dateFrom,
    String? dateTo,
    String search = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));

    final filtered = _mockExpenses.where((e) {
      if (status != null && status.isNotEmpty && status != 'ALL') {
        if (e.status.toUpperCase() != status.toUpperCase()) return false;
      }
      if (category != null && category.isNotEmpty && category != 'ALL') {
        if (e.categoryRef != category && e.categoryName != category) return false;
      }
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchId = e.id.toLowerCase().contains(q);
        final matchSupplier = e.supplierName?.toLowerCase().contains(q) ?? false;
        final matchMachine = e.machine?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchId && !matchSupplier && !matchMachine) return false;
      }
      return true;
    }).toList();

    final startIndex = (page - 1) * size;
    final endIndex = (startIndex + size) < filtered.length ? startIndex + size : filtered.length;
    final pagedList = startIndex < filtered.length ? filtered.sublist(startIndex, endIndex) : <Expense>[];
    final totalPages = (filtered.length / size).ceil();

    return ExpenseListResponse(
      results: pagedList,
      totalCount: filtered.length,
      totalPages: totalPages == 0 ? 1 : totalPages,
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<Expense> getExpenseDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final found = _mockExpenses.firstWhere(
      (e) => e.id == id,
      orElse: () => _mockExpenses.first,
    );
    return found;
  }

  @override
  Future<Expense> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final newExpense = Expense.fromJson({
      'id': 'EXP-2026-${_mockExpenses.length + 100}',
      'title': fields['title'] ?? 'New Expense',
      'expense_date': fields['expense_date'] ?? DateTime.now().toIso8601String().split('T').first,
      'amount': double.tryParse(fields['amount'] ?? '0') ?? 0.0,
      'category_name': fields['category'] ?? 'General',
      'subcategory_name': fields['subcategory'],
      'quantity': double.tryParse(fields['quantity'] ?? '1') ?? 1.0,
      'unit': fields['unit'],
      'rate': double.tryParse(fields['rate'] ?? '0') ?? 0.0,
      'supplier_name': fields['supplier_name'],
      'invoice_number': fields['invoice_number'],
      'site': fields['site'],
      'machine': fields['machine'],
      'payment_mode': fields['payment_mode'] ?? 'CASH',
      'status': fields['is_draft'] == 'true' ? 'DRAFT' : 'SUBMITTED',
      'created_by_name': 'Current User',
    });

    _mockExpenses.insert(0, newExpense);
    return newExpense;
  }

  @override
  Future<Expense> submitDraft(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _mockExpenses[index] = _mockExpenses[index].copyWith(status: 'SUBMITTED');
      return _mockExpenses[index];
    }
    throw Exception('Expense $id not found');
  }

  @override
  Future<Expense> approveExpense(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _mockExpenses[index] = _mockExpenses[index].copyWith(
        status: 'APPROVED',
        approvedBy: 'Admin User',
      );
      return _mockExpenses[index];
    }
    throw Exception('Expense $id not found');
  }

  @override
  Future<Expense> rejectExpense(String id, String reason) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _mockExpenses[index] = _mockExpenses[index].copyWith(
        status: 'REJECTED',
        rejectionReason: reason,
      );
      return _mockExpenses[index];
    }
    throw Exception('Expense $id not found');
  }

  @override
  Future<Expense> payExpense(
    String id,
    String paymentMode,
    String paymentReference,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _mockExpenses[index] = _mockExpenses[index].copyWith(
        status: 'PAID',
        paymentReference: paymentReference,
      );
      return _mockExpenses[index];
    }
    throw Exception('Expense $id not found');
  }
}
