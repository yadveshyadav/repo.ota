import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controller/expense_controller.dart';
import '../models/expense_models.dart';
import '../repositories/expense_repository.dart';

/// Clean multi-section mobile form for Creating Expenses / Saving Drafts with attachment upload & amount preview
class AddExpenseScreen extends StatefulWidget {
  final ExpenseRepository? repository;
  final ExpenseController? controller;

  const AddExpenseScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late final ExpenseController _controller;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _rateController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _gstPercentageController = TextEditingController(text: '18');
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _siteController = TextEditingController();
  final _machineController = TextEditingController();
  final _taskController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  ExpenseCategory? _selectedCategory;
  ExpenseSubcategory? _selectedSubcategory;
  bool _gstApplicable = false;
  String _paymentMode = 'CASH';

  XFile? _attachmentFile;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        ExpenseController(
          repository: widget.repository ?? ApiExpenseRepository(),
        );

    _controller.addListener(_onControllerStateChanged);
    _controller.fetchCategories();
    _restoreOfflineDraft();
  }

  void _onControllerStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreOfflineDraft() async {
    final draft = await _controller.loadOfflineDraft();
    if (draft != null && mounted) {
      setState(() {
        if (draft['title'] != null) _titleController.text = draft['title']!;
        if (draft['quantity'] != null) _quantityController.text = draft['quantity']!;
        if (draft['rate'] != null) _rateController.text = draft['rate']!;
        if (draft['supplier_name'] != null) _supplierController.text = draft['supplier_name']!;
        if (draft['invoice_number'] != null) _invoiceController.text = draft['invoice_number']!;
      });
    }
  }

  void _onCategoryChanged(ExpenseCategory? cat) {
    if (cat == null) return;
    setState(() {
      _selectedCategory = cat;
      _selectedSubcategory = null;
      if (cat.uom != null && cat.uom!.isNotEmpty) {
        _unitController.text = cat.uom!;
      }
      if (cat.defaultQuantity > 0) {
        _quantityController.text = cat.defaultQuantity.toStringAsFixed(cat.defaultQuantity == cat.defaultQuantity.toInt() ? 0 : 2);
      }
      if (cat.defaultRate > 0) {
        _rateController.text = cat.defaultRate.toStringAsFixed(cat.defaultRate == cat.defaultRate.toInt() ? 0 : 2);
      }
    });

    _controller.fetchSubcategories(cat.id);
  }

  double get _calculatedBasicAmount {
    final q = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final r = double.tryParse(_rateController.text.trim()) ?? 0.0;
    return q * r;
  }

  double get _calculatedTotalAmount {
    final basic = _calculatedBasicAmount;
    final disc = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final afterDisc = (basic - disc).clamp(0.0, double.infinity);

    if (_gstApplicable) {
      final gstPct = double.tryParse(_gstPercentageController.text.trim()) ?? 0.0;
      final gstVal = afterDisc * (gstPct / 100.0);
      return afterDisc + gstVal;
    }
    return afterDisc;
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _attachmentFile = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick attachment: $e'), backgroundColor: AppColors.criticalRed),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
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
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _submitForm({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Expense Category.'), backgroundColor: AppColors.criticalRed),
      );
      return;
    }

    if (_selectedCategory!.requiresProof && _attachmentFile == null && !isDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "${_selectedCategory!.name}" requires a bill/receipt attachment.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    final fields = <String, String>{
      'title': _titleController.text.trim(),
      'expense_date': DateFormat('yyyy-MM-dd').format(_expenseDate),
      'amount': _calculatedTotalAmount.toStringAsFixed(2),
      'category_ref': _selectedCategory!.id,
      'category_name': _selectedCategory!.name,
      if (_selectedSubcategory != null) 'subcategory_ref': _selectedSubcategory!.id,
      if (_selectedSubcategory != null) 'subcategory_name': _selectedSubcategory!.name,
      'quantity': _quantityController.text.trim(),
      'unit': _unitController.text.trim(),
      'rate': _rateController.text.trim(),
      'discount': _discountController.text.trim(),
      'gst_applicable': _gstApplicable.toString(),
      'gst_percentage': _gstPercentageController.text.trim(),
      'supplier_name': _supplierController.text.trim(),
      'invoice_number': _invoiceController.text.trim(),
      'site': _siteController.text.trim(),
      'machine': _machineController.text.trim(),
      'task': _taskController.text.trim(),
      'payment_mode': _paymentMode,
      'status': isDraft ? 'DRAFT' : 'SUBMITTED',
    };

    // Save offline draft locally if needed
    _controller.saveOfflineDraft(fields);

    http.MultipartFile? filePart;
    if (_attachmentFile != null) {
      final bytes = await _attachmentFile!.readAsBytes();
      filePart = http.MultipartFile.fromBytes(
        'attachment',
        bytes,
        filename: _attachmentFile!.name,
      );
    }

    final created = await _controller.createExpense(
      fields: fields,
      attachmentFile: filePart,
    );

    if (!mounted) return;

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDraft ? 'Expense saved as draft (${created.id})' : 'Expense submitted successfully (${created.id})'),
          backgroundColor: isDraft ? AppColors.infoBlue : AppColors.primaryGreen,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.formError ?? 'Failed to submit expense. Form data preserved locally.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _titleController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _rateController.dispose();
    _discountController.dispose();
    _gstPercentageController.dispose();
    _supplierController.dispose();
    _invoiceController.dispose();
    _siteController.dispose();
    _machineController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Text('Add Expense', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Banner
              if (_controller.formError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.criticalRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.criticalRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_controller.formError!, style: const TextStyle(color: AppColors.criticalRed, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // SECTION A: EXPENSE DETAILS
              _buildFormSection(
                title: 'A. EXPENSE DETAILS',
                icon: Icons.edit_note_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: AppTextStyles.bodyMedium,
                      decoration: _buildInputDecoration('Expense Title *', 'e.g. Engine Oil Replacement'),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
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
                            Text(
                              'Expense Date: ${DateFormat('dd MMM yyyy').format(_expenseDate)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                            ),
                            const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION B: CATEGORY & SUBCATEGORY
              _buildFormSection(
                title: 'B. CATEGORY',
                icon: Icons.category_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ExpenseCategory>(
                      initialValue: _selectedCategory,
                      decoration: _buildInputDecoration('Category *', 'Select Category'),
                      items: _controller.categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.name, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: _onCategoryChanged,
                      validator: (val) => val == null ? 'Category is required' : null,
                    ),
                    if (_controller.currentSubcategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ExpenseSubcategory>(
                        initialValue: _selectedSubcategory,
                        decoration: _buildInputDecoration('Subcategory', 'Select Subcategory'),
                        items: _controller.currentSubcategories
                            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedSubcategory = val),
                      ),
                    ],
                    if (_selectedCategory != null && _selectedCategory!.requiresProof) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.warningAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: const [
                            Icon(Icons.shield_outlined, size: 14, color: AppColors.warningAmber),
                            SizedBox(width: 6),
                            Text('Bill / Receipt attachment is mandatory for this category', style: TextStyle(fontSize: 11, color: AppColors.warningAmber, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION C: QUANTITY, RATE & AMOUNT PREVIEW
              _buildFormSection(
                title: 'C. AMOUNT CALCULATION',
                icon: Icons.calculate_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Quantity *', '1'),
                            validator: (val) {
                              final num = double.tryParse(val ?? '');
                              return (num == null || num <= 0) ? 'Invalid qty' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _unitController,
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Unit (UOM)', 'Liters / Hours'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rateController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Rate (₹) *', '0.00'),
                            validator: (val) {
                              final num = double.tryParse(val ?? '');
                              return (num == null || num < 0) ? 'Invalid rate' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Discount (₹)', '0.00'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Amount Calculation Live Preview Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                         ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Basic Amount:', style: TextStyle(fontSize: 12, color: AppColors.deepNavy)),
                              Flexible(
                                child: Text(
                                  formatInr(_calculatedBasicAmount),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (_gstApplicable) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('GST (${_gstPercentageController.text}%):', style: const TextStyle(fontSize: 12, color: AppColors.deepNavy)),
                                Flexible(
                                  child: Text(
                                    formatInr(_calculatedTotalAmount - (_calculatedBasicAmount - (double.tryParse(_discountController.text) ?? 0))),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16, color: AppColors.primaryGreen),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                              Flexible(
                                child: Text(
                                  formatInr(_calculatedTotalAmount),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION D: TAX & GST
              _buildFormSection(
                title: 'D. TAX',
                icon: Icons.receipt_outlined,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GST Applicable?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                        Switch(
                          value: _gstApplicable,
                          activeThumbColor: AppColors.primaryGreen,
                          onChanged: (val) => setState(() => _gstApplicable = val),
                        ),
                      ],
                    ),
                    if (_gstApplicable) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _gstPercentageController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.bodyMedium,
                        decoration: _buildInputDecoration('GST Percentage (%)', '18'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION E: SUPPLIER & INVOICE
              _buildFormSection(
                title: 'E. SUPPLIER & INVOICE',
                icon: Icons.storefront_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _supplierController,
                      style: AppTextStyles.bodyMedium,
                      decoration: _buildInputDecoration('Supplier / Vendor Name', 'e.g. Indian Oil / Apollos Spares'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _invoiceController,
                      style: AppTextStyles.bodyMedium,
                      decoration: _buildInputDecoration('Invoice / Bill Number', 'e.g. INV-2026-9901'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION F: WORK CONTEXT & PAYMENT MODE
              _buildFormSection(
                title: 'F. CONTEXT & PAYMENT',
                icon: Icons.work_outline_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _siteController,
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Site', 'e.g. Sujangarh-SITE'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _machineController,
                            style: AppTextStyles.bodyMedium,
                            decoration: _buildInputDecoration('Machine Code', 'e.g. 800202608593'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMode,
                      decoration: _buildInputDecoration('Payment Mode *', 'Select Mode'),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI Payment')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'CARD', child: Text('Card / POS')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMode = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION G: BILL / RECEIPT ATTACHMENT
              _buildFormSection(
                title: 'G. BILL / RECEIPT PROOF',
                icon: Icons.attach_file_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_attachmentFile != null) ...[
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryGreen, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_attachmentFile!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Retake Photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _attachmentFile = null),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.criticalRed),
                              label: const Text('Remove', style: TextStyle(color: AppColors.criticalRed)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.softGray,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.mutedTextGray),
                            SizedBox(height: 6),
                            Text('No bill / receipt attached', style: TextStyle(color: AppColors.mutedTextGray, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (_controller.isSubmitting)
                const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _submitForm(isDraft: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.deepNavy,
                          side: const BorderSide(color: AppColors.borderGray),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save Draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _submitForm(isDraft: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Submit Expense'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderGray)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
