import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/authorization_service.dart';
import '../../../shared/widgets/safe_image_widget.dart';
import '../controller/expense_controller.dart';
import '../models/expense_models.dart';
import '../widgets/receipt_viewer_dialog.dart';

/// Detailed inspection screen for Expense records with Bill preview, Approve, Reject & Pay actions
class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;
  final ExpenseController? controller;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    this.controller,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late Expense _expense;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    if (widget.controller != null) {
      widget.controller!.fetchExpenseDetail(_expense.id);
    }
  }

  Color get _statusColor {
    switch (_expense.status.toUpperCase()) {
      case 'DRAFT':
        return AppColors.mutedTextGray;
      case 'SUBMITTED':
        return AppColors.movingBlue;
      case 'APPROVED':
        return AppColors.successGreen;
      case 'REJECTED':
        return AppColors.criticalRed;
      case 'PAID':
        return const Color(0xFF059669);
      default:
        return AppColors.deepNavy;
    }
  }

  Future<void> _handleApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Expense'),
        content: Text('Are you sure you want to approve "${_expense.title}" (${_expense.formattedAmount})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.controller != null) {
      final success = await widget.controller!.approveExpense(_expense.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense approved successfully' : 'Failed to approve expense'),
            backgroundColor: success ? AppColors.successGreen : AppColors.criticalRed,
          ),
        );
        if (success) {
          setState(() {
            _expense = _expense.copyWith();
          });
        }
      }
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason for rejecting "${_expense.title}":'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.criticalRed),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject Expense'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.controller != null) {
      final success = await widget.controller!.rejectExpense(_expense.id, reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense rejected' : 'Failed to reject expense'),
            backgroundColor: success ? AppColors.infoBlue : AppColors.criticalRed,
          ),
        );
      }
    }
  }

  Future<void> _handlePay() async {
    String paymentMode = 'UPI';
    final refController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mark Expense as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI Payment')),
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card / POS')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => paymentMode = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: 'Payment Reference / Transaction ID',
                  hintText: 'e.g. UTR-9981201',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && widget.controller != null) {
      final success = await widget.controller!.payExpense(_expense.id, paymentMode, refController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense marked as Paid' : 'Failed to mark as paid'),
            backgroundColor: success ? AppColors.successGreen : AppColors.criticalRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = AuthorizationService.instance.can('attendance.approve') ||
        AuthorizationService.instance.can('expenses.approve') ||
        AuthorizationService.instance.currentUser?.isAdmin == true;

    final formattedExpenseDate = DateFormat('dd MMMM yyyy').format(_expense.expenseDate);

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Text('Expense Details', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _expense.id,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _expense.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _expense.displayStatus,
                      style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Expense Summary Box
            _buildDetailSection(
              title: 'EXPENSE SUMMARY',
              icon: Icons.receipt_long_outlined,
              children: [
                _buildRow('Category', _expense.categoryName ?? 'General'),
                if (_expense.subcategoryName != null) ...[
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildRow('Subcategory', _expense.subcategoryName!),
                ],
                const Divider(height: 16, color: AppColors.borderGray),
                _buildRow('Expense Date', formattedExpenseDate),
                if (_expense.createdBy != null) ...[
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildRow('Created By', _expense.createdBy!),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Amount Breakdown Box
            _buildDetailSection(
              title: 'AMOUNT BREAKDOWN',
              icon: Icons.calculate_outlined,
              children: [
                _buildRow('Quantity', '${_expense.quantity} ${_expense.unit ?? ""}'),
                const Divider(height: 16, color: AppColors.borderGray),
                _buildRow('Rate', formatInr(_expense.rate)),
                if (_expense.discount > 0) ...[
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildRow('Discount', formatInr(_expense.discount)),
                ],
                if (_expense.gstApplicable) ...[
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildRow('GST Percentage', '${_expense.gstPercentage}%'),
                ],
                const Divider(height: 16, color: AppColors.primaryGreen),
                _buildRow('Total Amount', _expense.formattedAmount, isBold: true, valueColor: AppColors.primaryGreen),
              ],
            ),
            const SizedBox(height: 16),

            // Supplier & Context Box
            if (_expense.supplierName != null || _expense.invoiceNumber != null || _expense.machine != null || _expense.site != null) ...[
              _buildDetailSection(
                title: 'SUPPLIER & WORK CONTEXT',
                icon: Icons.storefront_outlined,
                children: [
                  if (_expense.supplierName != null)
                    _buildRow('Supplier Name', _expense.supplierName!),
                  if (_expense.invoiceNumber != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildRow('Invoice Number', _expense.invoiceNumber!),
                  ],
                  if (_expense.site != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildRow('Site', _expense.site!),
                  ],
                  if (_expense.machine != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildRow(
                      'Machine',
                      _expense.machine!,
                      valueWidget: InkWell(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.machineDetail,
                            arguments: _expense.machine,
                          );
                        },
                        child: Text(
                          _expense.machine!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Payment Box
            _buildDetailSection(
              title: 'PAYMENT DETAILS',
              icon: Icons.payments_outlined,
              children: [
                _buildRow('Payment Mode', _expense.displayPaymentMode),
                if (_expense.paymentReference != null) ...[
                  const Divider(height: 16, color: AppColors.borderGray),
                  _buildRow('Payment Reference', _expense.paymentReference!),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Bill / Receipt Attachment Box
            if (_expense.attachmentUrl != null && _expense.attachmentUrl!.isNotEmpty) ...[
              _buildDetailSection(
                title: 'BILL / RECEIPT ATTACHMENT',
                icon: Icons.attach_file_rounded,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppImageWidget(
                      photoPath: _expense.attachmentUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ReceiptViewerDialog.show(
                          context,
                          attachmentUrl: _expense.attachmentUrl!,
                          title: '${_expense.title} (${_expense.id})',
                        );
                      },
                      icon: const Icon(Icons.fullscreen_rounded, size: 18),
                      label: const Text('View Full Receipt'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Approval & Rejection Notes
            if (_expense.rejectionReason != null && _expense.rejectionReason!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.criticalRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REJECTION REASON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.criticalRed)),
                    const SizedBox(height: 4),
                    Text(_expense.rejectionReason!, style: const TextStyle(fontSize: 13, color: AppColors.criticalRed, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (_expense.isSubmitted && canApprove) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleReject,
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.criticalRed),
                      label: const Text('Reject', style: TextStyle(color: AppColors.criticalRed, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.criticalRed), padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleApprove,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
            ] else if (_expense.isApproved && canApprove) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handlePay,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ] else if (_expense.isDraft && widget.controller != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => widget.controller!.submitDraft(_expense.id),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Draft', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderGray),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        valueWidget ??
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? AppColors.deepNavy,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
      ],
    );
  }
}
