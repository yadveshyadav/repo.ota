import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/expenses/controller/expense_controller.dart';
import 'package:hero_app/features/expenses/models/expense_models.dart';
import 'package:hero_app/features/expenses/repositories/expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Model & JSON Parsing Tests', () {
    test('Parses full Expense JSON safely', () {
      final json = {
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
      };

      final expense = Expense.fromJson(json);

      expect(expense.id, equals('EXP-2026-0104'));
      expect(expense.title, equals('Engine Oil Replacement'));
      expect(expense.amount, equals(5310.0));
      expect(expense.categoryName, equals('Machine Maintenance & Repairs'));
      expect(expense.isSubmitted, isTrue);
      expect(expense.displayPaymentMode, equals('UPI Payment'));
      expect(expense.formattedAmount, contains('5,310'));
    });

    test('Parses ExpenseCategory & ExpenseDashboardStats correctly', () {
      final catJson = {
        'id': '1',
        'name': 'Machine Maintenance',
        'code': 'MAINT',
        'uom': 'Hours',
        'requires_proof': true,
        'subcategories': [
          {'id': '101', 'name': 'Oil Filter'}
        ],
      };

      final category = ExpenseCategory.fromJson(catJson);
      expect(category.id, equals('1'));
      expect(category.name, equals('Machine Maintenance'));
      expect(category.requiresProof, isTrue);
      expect(category.subcategories.length, equals(1));
      expect(category.subcategories.first.name, equals('Oil Filter'));

      final statsJson = {
        'data': {
          'total_count': 28,
          'total_amount': 142500.0,
          'month_amount': 68400.0,
          'submitted_count': 4,
          'submitted_amount': 18200.0,
          'approved_count': 19,
          'approved_amount': 105000.0,
          'rejected_count': 2,
          'paid_count': 15,
          'by_category': [
            {'category': 'Machine Maintenance', 'amount': 82000.0, 'count': 12}
          ]
        }
      };

      final stats = ExpenseDashboardStats.fromJson(statsJson);
      expect(stats.totalCount, equals(28));
      expect(stats.totalAmount, equals(142500.0));
      expect(stats.submittedCount, equals(4));
      expect(stats.byCategory.length, equals(1));
    });
  });

  group('ExpenseController Unit & Filter Tests', () {
    late MockExpenseRepository repository;
    late ExpenseController controller;

    setUp(() {
      repository = MockExpenseRepository();
      controller = ExpenseController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial dashboard stats and expenses load successfully', () async {
      await controller.fetchDashboardStats();
      await controller.fetchExpenses(page: 1);

      expect(controller.dashboardStats, isNotNull);
      expect(controller.dashboardStats!.totalCount, equals(2));
      expect(controller.expenses.length, equals(2));
    });

    test('Filters expenses by status SUBMITTED and APPROVED', () async {
      await controller.fetchExpenses(page: 1);

      await controller.applyFilters(status: 'SUBMITTED');
      expect(controller.expenses.length, equals(1));
      expect(controller.expenses.first.isSubmitted, isTrue);

      await controller.applyFilters(status: 'APPROVED');
      expect(controller.expenses.length, equals(1));
      expect(controller.expenses.first.isApproved, isTrue);
    });

    test('Approve, Reject and Pay actions update local expense state', () async {
      final expense = await repository.getExpenseDetail('EXP-2026-0104');
      expect(expense.isSubmitted, isTrue);

      final approved = await controller.approveExpense('EXP-2026-0104');
      expect(approved, isTrue);

      final paid = await controller.payExpense('EXP-2026-0104', 'UPI', 'UTR-99182');
      expect(paid, isTrue);
    });
  });
}
