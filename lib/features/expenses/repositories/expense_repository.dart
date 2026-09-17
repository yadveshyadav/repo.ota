import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/api/api_client.dart';
import '../models/expense_models.dart';
import '../services/expense_api_service.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseCategory>> getCategories({String search = ''});
  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId);
  Future<ExpenseDashboardStats> getDashboardStats();
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
  Future<Expense> payExpense(String id, String paymentMode, String paymentReference);
}

class ApiExpenseRepository implements ExpenseRepository {
  final ExpenseApiService apiService;

  static final List<ExpenseCategory> _fallbackCategories = [
    const ExpenseCategory(
      id: '1',
      name: 'Machine Maintenance & Repairs',
      code: 'MAINT',
      paymentType: 'DIRECT',
      uom: 'Hours',
      defaultQuantity: 1,
      defaultRate: 5000,
      requiresProof: true,
      subcategories: [
        ExpenseSubcategory(id: '101', name: 'Engine Oil Replacement', categoryId: '1'),
        ExpenseSubcategory(id: '102', name: 'Hydraulic Hose Fitting', categoryId: '1'),
      ],
    ),
    const ExpenseCategory(
      id: '2',
      name: 'Fuel & Petroleum',
      code: 'FUEL',
      paymentType: 'DIRECT',
      uom: 'Liters',
      defaultQuantity: 100,
      defaultRate: 95,
      requiresProof: true,
      subcategories: [
        ExpenseSubcategory(id: '201', name: 'High-Speed Diesel (HSD)', categoryId: '2'),
      ],
    ),
    const ExpenseCategory(
      id: '3',
      name: 'Site Operations & Logistics',
      code: 'SITE',
      paymentType: 'REIMBURSEMENT',
      uom: 'Days',
      defaultQuantity: 1,
      defaultRate: 1500,
      requiresProof: false,
      subcategories: [
        ExpenseSubcategory(id: '301', name: 'Staff Travel & Mess', categoryId: '3'),
      ],
    ),
    const ExpenseCategory(
      id: '4',
      name: 'Spare Parts & Tools',
      code: 'SPARES',
      paymentType: 'DIRECT',
      uom: 'Units',
      defaultQuantity: 1,
      defaultRate: 2000,
      requiresProof: true,
      subcategories: [
        ExpenseSubcategory(id: '401', name: 'Drill Bit Replacement', categoryId: '4'),
      ],
    ),
    const ExpenseCategory(
      id: '5',
      name: 'General & Administrative',
      code: 'GENERAL',
      paymentType: 'REIMBURSEMENT',
      uom: 'Items',
      defaultQuantity: 1,
      defaultRate: 500,
      requiresProof: false,
      subcategories: [
        ExpenseSubcategory(id: '501', name: 'Office Supplies', categoryId: '5'),
      ],
    ),
  ];

  ApiExpenseRepository({ApiClient? apiClient, ExpenseApiService? apiService})
      : apiService = apiService ?? ExpenseApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<List<ExpenseCategory>> getCategories({String search = ''}) async {
    try {
      final categories = await apiService.fetchCategories(search: search);
      if (categories.isNotEmpty) {
        return categories;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] getCategories error: $e');
      }
    }
    if (search.trim().isEmpty) return _fallbackCategories;
    final q = search.trim().toLowerCase();
    return _fallbackCategories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId) async {
    try {
      return await apiService.fetchSubcategories(categoryId);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] getSubcategories error: $e');
      }
      return const [];
    }
  }

  @override
  Future<ExpenseDashboardStats> getDashboardStats() async {
    try {
      return await apiService.fetchDashboardStats();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] getDashboardStats error: $e');
      }
      rethrow;
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
        print('[ApiExpenseRepository] getExpenses error: $e');
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
        print('[ApiExpenseRepository] getExpenseDetail error: $e');
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
        print('[ApiExpenseRepository] createExpense error: $e');
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
        print('[ApiExpenseRepository] submitDraft error: $e');
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
        print('[ApiExpenseRepository] approveExpense error: $e');
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
        print('[ApiExpenseRepository] rejectExpense error: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Expense> payExpense(String id, String paymentMode, String paymentReference) async {
    try {
      return await apiService.payExpense(id, paymentMode, paymentReference);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiExpenseRepository] payExpense error: $e');
      }
      rethrow;
    }
  }
}

class MockExpenseRepository implements ExpenseRepository {
  static final List<ExpenseCategory> _categories = [
    ExpenseCategory(
      id: '1',
      name: 'Machine Maintenance & Repairs',
      code: 'MAINT',
      paymentType: 'DIRECT',
      uom: 'Hours',
      defaultQuantity: 1,
      defaultRate: 5000,
      requiresProof: true,
      subcategories: const [
        ExpenseSubcategory(id: '101', name: 'Engine Oil Replacement', categoryId: '1'),
        ExpenseSubcategory(id: '102', name: 'Hydraulic Hose Fitting', categoryId: '1'),
      ],
    ),
    ExpenseCategory(
      id: '2',
      name: 'Fuel & Petroleum',
      code: 'FUEL',
      paymentType: 'DIRECT',
      uom: 'Liters',
      defaultQuantity: 100,
      defaultRate: 95,
      requiresProof: true,
      subcategories: const [
        ExpenseSubcategory(id: '201', name: 'High-Speed Diesel (HSD)', categoryId: '2'),
      ],
    ),
    ExpenseCategory(
      id: '3',
      name: 'Site Operations & Logistics',
      code: 'SITE',
      paymentType: 'REIMBURSEMENT',
      uom: 'Days',
      defaultQuantity: 1,
      defaultRate: 1500,
      requiresProof: false,
      subcategories: const [
        ExpenseSubcategory(id: '301', name: 'Staff Travel & Mess', categoryId: '3'),
      ],
    ),
  ];

  static final List<Expense> _expenses = [
    Expense(
      id: 'EXP-2026-0104',
      title: 'Engine Oil Replacement',
      expenseDate: DateTime.now().subtract(const Duration(days: 1)),
      amount: 5310.0,
      categoryRef: '1',
      categoryName: 'Machine Maintenance & Repairs',
      subcategoryName: 'Engine Oil Replacement',
      quantity: 1,
      unit: 'Hours',
      rate: 4500,
      discount: 0,
      gstApplicable: true,
      gstPercentage: 18,
      supplierName: 'Apollos Spares Sujangarh',
      invoiceNumber: 'INV-88912',
      site: 'Sujangarh-SITE',
      machine: 'A800 HDD (8595)',
      paymentMode: 'UPI',
      status: 'SUBMITTED',
      createdBy: 'ADMIN Sharma',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Expense(
      id: 'EXP-2026-0103',
      title: 'Diesel Top-up HDD Rig 600',
      expenseDate: DateTime.now().subtract(const Duration(days: 3)),
      amount: 9500.0,
      categoryRef: '2',
      categoryName: 'Fuel & Petroleum',
      subcategoryName: 'High-Speed Diesel (HSD)',
      quantity: 100,
      unit: 'Liters',
      rate: 95,
      supplierName: 'Indian Oil Retailer',
      invoiceNumber: 'IOC-7712',
      site: 'Sujangarh-SITE',
      machine: 'A600 HDD (8396)',
      paymentMode: 'CARD',
      status: 'APPROVED',
      createdBy: 'Ramesh Sharma',
      approvedBy: 'Papu Ram 2',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<List<ExpenseCategory>> getCategories({String search = ''}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (search.trim().isEmpty) return _categories;
    final q = search.trim().toLowerCase();
    return _categories.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<ExpenseSubcategory>> getSubcategories(String categoryId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final matchedCat = _categories.firstWhere((c) => c.id == categoryId, orElse: () => _categories.first);
    return matchedCat.subcategories;
  }

  @override
  Future<ExpenseDashboardStats> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return ExpenseDashboardStats(
      totalCount: _expenses.length,
      totalAmount: _expenses.fold(0.0, (sum, e) => sum + e.amount),
      todayAmount: 5310.0,
      monthAmount: 14810.0,
      submittedCount: _expenses.where((e) => e.isSubmitted).length,
      submittedAmount: 5310.0,
      approvedCount: _expenses.where((e) => e.isApproved).length,
      approvedAmount: 9500.0,
      rejectedCount: 0,
      paidCount: 0,
      byCategory: const [
        ExpenseCategorySummary(category: 'Machine Maintenance & Repairs', amount: 5310.0, count: 1),
        ExpenseCategorySummary(category: 'Fuel & Petroleum', amount: 9500.0, count: 1),
      ],
    );
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
    await Future.delayed(const Duration(milliseconds: 150));
    final filtered = _expenses.where((e) {
      if (status != null && status.isNotEmpty && status != 'ALL') {
        if (e.status.toUpperCase() != status.toUpperCase()) return false;
      }
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return e.title.toLowerCase().contains(q) ||
            e.id.toLowerCase().contains(q) ||
            (e.supplierName?.toLowerCase().contains(q) ?? false) ||
            (e.categoryName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return ExpenseListResponse(
      results: filtered,
      totalCount: filtered.length,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<Expense> getExpenseDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _expenses.firstWhere((e) => e.id == id, orElse: () => _expenses.first);
  }

  @override
  Future<Expense> createExpense({
    required Map<String, String> fields,
    http.MultipartFile? attachmentFile,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newId = 'EXP-2026-${100 + _expenses.length + 1}';
    final amountNum = double.tryParse(fields['amount'] ?? '0') ?? 0.0;

    final newExpense = Expense(
      id: newId,
      title: fields['title'] ?? 'New Expense',
      expenseDate: DateTime.now(),
      amount: amountNum,
      categoryName: fields['category_name'] ?? 'General',
      status: fields['status'] ?? 'SUBMITTED',
      createdAt: DateTime.now(),
    );

    _expenses.insert(0, newExpense);
    return newExpense;
  }

  @override
  Future<Expense> submitDraft(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = Expense.fromJson({..._expenses[idx].toJson(), 'status': 'SUBMITTED'});
      return _expenses[idx];
    }
    throw Exception('Expense not found');
  }

  @override
  Future<Expense> approveExpense(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = Expense.fromJson({..._expenses[idx].toJson(), 'status': 'APPROVED'});
      return _expenses[idx];
    }
    throw Exception('Expense not found');
  }

  @override
  Future<Expense> rejectExpense(String id, String reason) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = Expense.fromJson({..._expenses[idx].toJson(), 'status': 'REJECTED', 'rejection_reason': reason});
      return _expenses[idx];
    }
    throw Exception('Expense not found');
  }

  @override
  Future<Expense> payExpense(String id, String paymentMode, String paymentReference) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = Expense.fromJson({..._expenses[idx].toJson(), 'status': 'PAID', 'payment_mode': paymentMode, 'payment_reference': paymentReference});
      return _expenses[idx];
    }
    throw Exception('Expense not found');
  }
}
