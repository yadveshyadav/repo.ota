import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../models/expense_models.dart';

/// Mobile Expense Card displaying ID, Title, Category, Date, Amount (INR), and Status Chip
class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.onTap,
  });

  Color get _statusColor {
    switch (expense.status.toUpperCase()) {
      case 'DRAFT':
        return AppColors.mutedTextGray;
      case 'SUBMITTED':
        return AppColors.movingBlue;
      case 'APPROVED':
        return AppColors.successGreen;
      case 'REJECTED':
        return AppColors.criticalRed;
      case 'PAID':
        return const Color(0xFF059669); // Dark Green / Teal
      default:
        return AppColors.deepNavy;
    }
  }

  IconData get _statusIcon {
    switch (expense.status.toUpperCase()) {
      case 'DRAFT':
        return Icons.edit_note_rounded;
      case 'SUBMITTED':
        return Icons.send_rounded;
      case 'APPROVED':
        return Icons.check_circle_outline_rounded;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'PAID':
        return Icons.payments_outlined;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(expense.expenseDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP ROW: Expense Code / ID + Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    expense.id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mutedTextGray,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, size: 12, color: _statusColor),
                        const SizedBox(width: 4),
                        Text(
                          expense.displayStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. TITLE & CATEGORY
              Text(
                expense.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                expense.categoryName ?? 'General Expense',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedTextGray,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // 3. BOTTOM ROW: DATE & AMOUNT (INR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.mutedTextGray),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedTextGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        expense.formattedAmount,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
