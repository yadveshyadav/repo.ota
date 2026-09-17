import 'package:intl/intl.dart';
import '../../../core/utils/date_parser_utils.dart';

/// Indian Rupee Currency Formatter
String formatInr(num? amount) {
  if (amount == null) return '₹0';
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: amount is int || amount == amount.roundToDouble() ? 0 : 2,
  );
  return formatter.format(amount);
}

/// Expense Category Model
class ExpenseCategory {
  final String id;
  final String name;
  final String? code;
  final String? paymentType;
  final String? paymentTypeDisplay;
  final String? uom;
  final double defaultQuantity;
  final double defaultRate;
  final double? monthlyCost;
  final bool requiresProof;
  final bool isActive;
  final List<ExpenseSubcategory> subcategories;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.code,
    this.paymentType,
    this.paymentTypeDisplay,
    this.uom,
    this.defaultQuantity = 1.0,
    this.defaultRate = 0.0,
    this.monthlyCost,
    this.requiresProof = false,
    this.isActive = true,
    this.subcategories = const [],
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['pk'] ?? json['code'] ?? '';
    final subList = (json['subcategories'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((s) => ExpenseSubcategory.fromJson(s))
            .toList() ??
        const [];

    return ExpenseCategory(
      id: rawId.toString(),
      name: json['name']?.toString() ?? 'General Category',
      code: json['code']?.toString(),
      paymentType: json['payment_type']?.toString() ?? json['paymentType']?.toString(),
      paymentTypeDisplay: json['payment_type_display']?.toString() ?? json['paymentTypeDisplay']?.toString(),
      uom: json['uom']?.toString() ?? json['unit']?.toString(),
      defaultQuantity: (json['default_quantity'] as num?)?.toDouble() ?? (json['defaultQuantity'] as num?)?.toDouble() ?? 1.0,
      defaultRate: (json['default_rate'] as num?)?.toDouble() ?? (json['defaultRate'] as num?)?.toDouble() ?? 0.0,
      monthlyCost: (json['monthly_cost'] as num?)?.toDouble() ?? (json['monthlyCost'] as num?)?.toDouble(),
      requiresProof: json['requires_proof'] as bool? ?? json['requiresProof'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      subcategories: subList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (code != null) 'code': code,
        if (paymentType != null) 'payment_type': paymentType,
        if (uom != null) 'uom': uom,
        'default_quantity': defaultQuantity,
        'default_rate': defaultRate,
        'requires_proof': requiresProof,
        'is_active': isActive,
        'subcategories': subcategories.map((s) => s.toJson()).toList(),
      };
}

/// Expense Subcategory Model
class ExpenseSubcategory {
  final String id;
  final String name;
  final String? categoryId;
  final bool isActive;

  const ExpenseSubcategory({
    required this.id,
    required this.name,
    this.categoryId,
    this.isActive = true,
  });

  factory ExpenseSubcategory.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['pk'] ?? json['code'] ?? '';
    return ExpenseSubcategory(
      id: rawId.toString(),
      name: json['name']?.toString() ?? 'General Subcategory',
      categoryId: json['category']?.toString() ?? json['category_id']?.toString(),
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (categoryId != null) 'category': categoryId,
        'is_active': isActive,
      };
}

/// Main Production Expense Model
class Expense {
  final String id;
  final String title;
  final DateTime expenseDate;
  final double amount;
  final String? categoryRef;
  final String? categoryName;
  final String? subcategoryRef;
  final String? subcategoryName;
  final String? paymentType;
  final double quantity;
  final String? unit;
  final double rate;
  final double discount;
  final bool gstApplicable;
  final double gstPercentage;
  final String? supplierName;
  final String? invoiceNumber;
  final String? site;
  final String? machine;
  final String? task;
  final String paymentMode; // 'CASH', 'UPI', 'BANK_TRANSFER', 'CARD'
  final String? attachmentUrl;
  final String status; // 'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'PAID'
  final String? createdBy;
  final String? approvedBy;
  final String? rejectionReason;
  final String? paymentReference;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.expenseDate,
    required this.amount,
    this.categoryRef,
    this.categoryName,
    this.subcategoryRef,
    this.subcategoryName,
    this.paymentType,
    this.quantity = 1.0,
    this.unit,
    this.rate = 0.0,
    this.discount = 0.0,
    this.gstApplicable = false,
    this.gstPercentage = 0.0,
    this.supplierName,
    this.invoiceNumber,
    this.site,
    this.machine,
    this.task,
    this.paymentMode = 'CASH',
    this.attachmentUrl,
    this.status = 'SUBMITTED',
    this.createdBy,
    this.approvedBy,
    this.rejectionReason,
    this.paymentReference,
    this.createdAt,
  });

  Expense copyWith({
    String? status,
    String? approvedBy,
    String? rejectionReason,
    String? paymentReference,
  }) {
    return Expense(
      id: id,
      title: title,
      expenseDate: expenseDate,
      amount: amount,
      categoryRef: categoryRef,
      categoryName: categoryName,
      subcategoryRef: subcategoryRef,
      subcategoryName: subcategoryName,
      paymentType: paymentType,
      quantity: quantity,
      unit: unit,
      rate: rate,
      discount: discount,
      gstApplicable: gstApplicable,
      gstPercentage: gstPercentage,
      supplierName: supplierName,
      invoiceNumber: invoiceNumber,
      site: site,
      machine: machine,
      task: task,
      paymentMode: paymentMode,
      attachmentUrl: attachmentUrl,
      status: status ?? this.status,
      createdBy: createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentReference: paymentReference ?? this.paymentReference,
      createdAt: createdAt,
    );
  }

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isSubmitted => status.toUpperCase() == 'SUBMITTED';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isPaid => status.toUpperCase() == 'PAID';


  String get displayStatus => status.toUpperCase();
  String get formattedAmount => formatInr(amount);

  String get displayPaymentMode {
    switch (paymentMode.toUpperCase()) {
      case 'UPI':
        return 'UPI Payment';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CARD':
        return 'Card / POS';
      default:
        return 'Cash';
    }
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final rawId = source['id'] ?? source['expense_id'] ?? source['code'] ?? 'EXP-NEW';
    final titleStr = source['title']?.toString() ?? source['expense_title']?.toString() ?? 'Expense';

    // Parse category & subcategory (could be String ID or nested object)
    String? catName;
    String? catRef;
    if (source['category'] is Map<String, dynamic>) {
      catName = source['category']['name']?.toString();
      catRef = source['category']['id']?.toString() ?? source['category']['code']?.toString();
    } else {
      catName = source['category_name']?.toString() ?? source['category']?.toString();
      catRef = source['category_ref']?.toString() ?? source['category']?.toString();
    }

    String? subCatName;
    String? subCatRef;
    if (source['subcategory'] is Map<String, dynamic>) {
      subCatName = source['subcategory']['name']?.toString();
      subCatRef = source['subcategory']['id']?.toString() ?? source['subcategory']['code']?.toString();
    } else {
      subCatName = source['subcategory_name']?.toString() ?? source['subcategory']?.toString();
      subCatRef = source['subcategory_ref']?.toString() ?? source['subcategory']?.toString();
    }

    final rawAmount = (source['amount'] as num?)?.toDouble() ??
        (source['total_amount'] as num?)?.toDouble() ??
        0.0;

    return Expense(
      id: rawId.toString(),
      title: titleStr,
      expenseDate: DateParserUtils.parse(source['expense_date'] ?? source['date'] ?? source['created_at']) ?? DateTime.now(),
      amount: rawAmount,
      categoryRef: catRef,
      categoryName: catName ?? 'General',
      subcategoryRef: subCatRef,
      subcategoryName: subCatName,
      paymentType: source['payment_type']?.toString(),
      quantity: (source['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: source['unit']?.toString() ?? source['uom']?.toString(),
      rate: (source['rate'] as num?)?.toDouble() ?? 0.0,
      discount: (source['discount'] as num?)?.toDouble() ?? 0.0,
      gstApplicable: source['gst_applicable'] as bool? ?? source['gstApplicable'] as bool? ?? false,
      gstPercentage: (source['gst_percentage'] as num?)?.toDouble() ?? (source['gstPercentage'] as num?)?.toDouble() ?? 0.0,
      supplierName: source['supplier_name']?.toString() ?? source['supplierName']?.toString() ?? source['vendor_name']?.toString(),
      invoiceNumber: source['invoice_number']?.toString() ?? source['invoiceNumber']?.toString(),
      site: source['site']?.toString() ?? source['site_name']?.toString(),
      machine: source['machine']?.toString() ?? source['machine_code']?.toString(),
      task: source['task']?.toString() ?? source['task_code']?.toString(),
      paymentMode: (source['payment_mode'] ?? source['paymentMode'] ?? 'CASH').toString().toUpperCase(),
      attachmentUrl: source['attachment']?.toString() ?? source['attachment_url']?.toString() ?? source['bill_url']?.toString(),
      status: (source['status'] ?? 'SUBMITTED').toString().toUpperCase(),
      createdBy: source['created_by_name']?.toString() ?? source['created_by']?.toString() ?? source['creator']?.toString(),
      approvedBy: source['approved_by_name']?.toString() ?? source['approved_by']?.toString(),
      rejectionReason: source['rejection_reason']?.toString() ?? source['reason']?.toString(),
      paymentReference: source['payment_reference']?.toString() ?? source['paymentRef']?.toString(),
      createdAt: DateParserUtils.parse(source['created_at'] ?? source['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'expense_date': expenseDate.toIso8601String().split('T').first,
        'amount': amount,
        if (categoryRef != null) 'category_ref': categoryRef,
        if (categoryName != null) 'category_name': categoryName,
        if (subcategoryRef != null) 'subcategory_ref': subcategoryRef,
        if (subcategoryName != null) 'subcategory_name': subcategoryName,
        'quantity': quantity,
        if (unit != null) 'unit': unit,
        'rate': rate,
        'discount': discount,
        'gst_applicable': gstApplicable,
        'gst_percentage': gstPercentage,
        if (supplierName != null) 'supplier_name': supplierName,
        if (invoiceNumber != null) 'invoice_number': invoiceNumber,
        if (site != null) 'site': site,
        if (machine != null) 'machine': machine,
        if (task != null) 'task': task,
        'payment_mode': paymentMode,
        if (attachmentUrl != null) 'attachment': attachmentUrl,
        'status': status,
        if (createdBy != null) 'created_by': createdBy,
        if (approvedBy != null) 'approved_by': approvedBy,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (paymentReference != null) 'payment_reference': paymentReference,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

/// Expense Dashboard Statistics DTO
class ExpenseDashboardStats {
  final int totalCount;
  final double totalAmount;
  final double todayAmount;
  final double monthAmount;
  final int submittedCount;
  final double submittedAmount;
  final int approvedCount;
  final double approvedAmount;
  final int rejectedCount;
  final int paidCount;
  final List<ExpenseCategorySummary> byCategory;

  const ExpenseDashboardStats({
    this.totalCount = 0,
    this.totalAmount = 0.0,
    this.todayAmount = 0.0,
    this.monthAmount = 0.0,
    this.submittedCount = 0,
    this.submittedAmount = 0.0,
    this.approvedCount = 0,
    this.approvedAmount = 0.0,
    this.rejectedCount = 0,
    this.paidCount = 0,
    this.byCategory = const [],
  });

  factory ExpenseDashboardStats.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final catList = (source['by_category'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((c) => ExpenseCategorySummary.fromJson(c))
            .toList() ??
        const [];

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return ExpenseDashboardStats(
      totalCount: parseInt(source['total_count'] ?? source['totalCount']),
      totalAmount: parseDouble(source['total_amount'] ?? source['totalAmount']),
      todayAmount: parseDouble(source['today_amount'] ?? source['todayAmount']),
      monthAmount: parseDouble(source['month_amount'] ?? source['monthAmount']),
      submittedCount: parseInt(source['submitted_count'] ?? source['submittedCount']),
      submittedAmount: parseDouble(source['submitted_amount'] ?? source['submittedAmount']),
      approvedCount: parseInt(source['approved_count'] ?? source['approvedCount']),
      approvedAmount: parseDouble(source['approved_amount'] ?? source['approvedAmount']),
      rejectedCount: parseInt(source['rejected_count'] ?? source['rejectedCount']),
      paidCount: parseInt(source['paid_count'] ?? source['paidCount']),
      byCategory: catList,
    );
  }
}

/// Category Summary DTO
class ExpenseCategorySummary {
  final String category;
  final double amount;
  final int count;

  const ExpenseCategorySummary({
    required this.category,
    required this.amount,
    required this.count,
  });

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExpenseCategorySummary(
      category: json['category']?.toString() ?? json['category_name']?.toString() ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paginated Expense List Response DTO
class ExpenseListResponse {
  final List<Expense> results;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final String? nextUrl;
  final String? previousUrl;

  const ExpenseListResponse({
    required this.results,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    this.nextUrl,
    this.previousUrl,
  });

  bool get hasNext => nextUrl != null || currentPage < totalPages;

  factory ExpenseListResponse.fromJson(dynamic json, {int requestPage = 1, int requestSize = 20}) {
    if (json == null) {
      return ExpenseListResponse(
        results: const [],
        totalCount: 0,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
      );
    }

    if (json is List) {
      final list = json
          .whereType<Map<String, dynamic>>()
          .map((item) => Expense.fromJson(item))
          .toList();
      return ExpenseListResponse(
        results: list,
        totalCount: list.length,
        totalPages: 1,
        currentPage: requestPage,
        pageSize: requestSize,
      );
    }

    if (json is Map<String, dynamic>) {
      dynamic data = json['results'] ?? json['data'] ?? json['content'] ?? json;
      List<dynamic> rawList = [];

      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          rawList = data['results'] as List<dynamic>;
        } else if (data['data'] is List) {
          rawList = data['data'] as List<dynamic>;
        }
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => Expense.fromJson(item))
          .toList();

      Map<String, dynamic> meta = {};
      if (json['meta'] is Map<String, dynamic>) {
        meta = json['meta'] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        meta = data;
      }

      int parseNum(dynamic val, [int fallback = 0]) {
        if (val == null) return fallback;
        if (val is int) return val;
        if (val is num) return val.toInt();
        if (val is String) return int.tryParse(val.trim()) ?? fallback;
        return fallback;
      }

      final count = parseNum(meta['count'] ?? meta['total'] ?? json['count'] ?? json['total'], list.length);
      final size = parseNum(meta['page_size'] ?? meta['pageSize'] ?? json['page_size'] ?? json['pageSize'], requestSize);
      final effSize = size > 0 ? size : 20;
      final pages = parseNum(meta['total_pages'] ?? meta['totalPages'] ?? json['total_pages'] ?? json['totalPages'], (count / effSize).ceil());
      final page = parseNum(meta['current_page'] ?? meta['currentPage'] ?? json['current_page'] ?? json['currentPage'], requestPage);

      final next = meta['next']?.toString() ?? json['next']?.toString();
      final prev = meta['previous']?.toString() ?? json['previous']?.toString();

      return ExpenseListResponse(
        results: list,
        totalCount: count,
        totalPages: pages > 0 ? pages : 1,
        currentPage: page > 0 ? page : 1,
        pageSize: effSize,
        nextUrl: next,
        previousUrl: prev,
      );
    }

    return ExpenseListResponse(
      results: const [],
      totalCount: 0,
      totalPages: 1,
      currentPage: requestPage,
      pageSize: requestSize,
    );
  }
}
