import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_parser_utils.dart';
import '../../../models/stock_issue_model.dart';

/// Mobile-first Stock Issue Log Card Component for Inventory Workspace
class StockIssueCard extends StatelessWidget {
  final StockIssueModel issue;
  final VoidCallback onTap;

  const StockIssueCard({
    super.key,
    required this.issue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(issue.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Issue Number & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: AppColors.infoBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        issue.issueNumber ?? 'Issue #${issue.id ?? "N/A"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(issue.status ?? 'DISPATCHED', statusColor),
                ],
              ),
              const SizedBox(height: 8),

              // Stock Transfer Number if present
              if (issue.stockTransferNumber != null && issue.stockTransferNumber!.isNotEmpty) ...[
                Text(
                  'Transfer Ref: ${issue.stockTransferNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTextGray,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Divider(height: 1, color: AppColors.borderGray),
              const SizedBox(height: 10),

              // From Warehouse -> Issued To Vendor
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'From Warehouse',
                      issue.fromWarehouseName ?? issue.fromWarehouseCode ?? 'Central Store',
                    ),
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      'Issued To Vendor',
                      issue.issueeName ?? 'Unassigned Vendor',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Items Count & Issue Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${issue.items.length} ${issue.items.length == 1 ? "Item" : "Items"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.infoBlue,
                      ),
                    ),
                  ),
                  Text(
                    'Date: ${DateParserUtils.formatDisplay(issue.issuedAt ?? issue.createdAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedTextGray,
                    ),
                  ),
                ],
              ),

              if (issue.remarks != null && issue.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Remarks: ${issue.remarks}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.mutedTextGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return AppColors.infoBlue;
    final s = status.toUpperCase();
    if (s == 'DELIVERED' || s == 'COMPLETED' || s == 'APPROVED') {
      return AppColors.primaryGreen;
    } else if (s == 'DISPATCHED' || s == 'ISSUED') {
      return AppColors.infoBlue;
    } else if (s == 'PENDING' || s == 'IN_TRANSIT') {
      return AppColors.warningAmber;
    } else if (s == 'CANCELLED' || s == 'REJECTED') {
      return AppColors.criticalRed;
    }
    return AppColors.infoBlue;
  }
}
