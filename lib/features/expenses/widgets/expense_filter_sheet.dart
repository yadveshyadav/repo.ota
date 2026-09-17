import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../models/expense_models.dart';

/// Mobile Bottom Sheet for filtering Expenses by Status, Category, and Date Range
class ExpenseFilterSheet extends StatefulWidget {
  final String initialStatus;
  final String initialCategory;
  final String? initialDateFrom;
  final String? initialDateTo;
  final List<ExpenseCategory> categories;
  final Function(String status, String category, String? dateFrom, String? dateTo) onApply;

  const ExpenseFilterSheet({
    super.key,
    required this.initialStatus,
    required this.initialCategory,
    this.initialDateFrom,
    this.initialDateTo,
    required this.categories,
    required this.onApply,
  });

  static void show({
    required BuildContext context,
    required String initialStatus,
    required String initialCategory,
    String? initialDateFrom,
    String? initialDateTo,
    required List<ExpenseCategory> categories,
    required Function(String status, String category, String? dateFrom, String? dateTo) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ExpenseFilterSheet(
        initialStatus: initialStatus,
        initialCategory: initialCategory,
        initialDateFrom: initialDateFrom,
        initialDateTo: initialDateTo,
        categories: categories,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends State<ExpenseFilterSheet> {
  late String _status;
  late String _category;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _category = widget.initialCategory;
    if (widget.initialDateFrom != null && widget.initialDateFrom!.isNotEmpty) {
      _dateFrom = DateTime.tryParse(widget.initialDateFrom!);
    }
    if (widget.initialDateTo != null && widget.initialDateTo!.isNotEmpty) {
      _dateTo = DateTime.tryParse(widget.initialDateTo!);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedTextGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),

          // Status Filter Chips
          const Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('ALL', 'All Statuses'),
                _buildStatusChip('DRAFT', 'Draft'),
                _buildStatusChip('SUBMITTED', 'Submitted'),
                _buildStatusChip('APPROVED', 'Approved'),
                _buildStatusChip('PAID', 'Paid'),
                _buildStatusChip('REJECTED', 'Rejected'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          const Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                  for (final cat in widget.categories)
                    DropdownMenuItem(value: cat.id, child: Text(cat.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _category = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Range
          const Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : 'From Date',
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : 'To Date',
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _status = 'ALL';
                      _category = 'ALL';
                      _dateFrom = null;
                      _dateTo = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepNavy,
                    side: const BorderSide(color: AppColors.borderGray),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final fromStr = _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null;
                    final toStr = _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null;
                    widget.onApply(_status, _category, fromStr, toStr);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => setState(() => _status = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : AppColors.softGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.white : AppColors.deepNavy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.deepNavy)),
            const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.mutedTextGray),
          ],
        ),
      ),
    );
  }
}
