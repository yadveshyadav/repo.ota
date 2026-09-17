import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_parser_utils.dart';
import '../../../models/stock_issue_model.dart';
import '../widgets/stock_item_card.dart';
import 'stock_item_detail_screen.dart';

/// Stock Issue Log Detail Inspection Screen
class StockIssueDetailScreen extends StatelessWidget {
  final StockIssueModel issue;

  const StockIssueDetailScreen({
    super.key,
    required this.issue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.issueNumber ?? 'Stock Issue ${issue.id ?? "N/A"}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Transfer Ref: ${issue.stockTransferNumber ?? "Direct Issue"}',
              style: const TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Identity Card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined, color: AppColors.infoBlue, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                issue.issueNumber ?? 'Issue #${issue.id ?? "N/A"}',
                                style: AppTextStyles.headingSmall,
                              ),
                            ],
                          ),
                          _buildStatusChip(issue.status ?? 'DISPATCHED'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stock Transfer #: ${issue.stockTransferNumber ?? "STN-N/A"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Warehouse & Issuee Details
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warehouse_outlined, color: AppColors.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text('Warehouse & Recipient', style: AppTextStyles.headingSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderGray),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        'From Warehouse',
                        issue.fromWarehouseName ?? issue.fromWarehouseCode ?? 'Central Store',
                        'Code: ${issue.fromWarehouseCode ?? "WH-01"}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Issued To Vendor',
                        issue.issueeName ?? 'Unassigned Vendor',
                        'Issuee Code: ${issue.issueeCode ?? issue.issueeId ?? "N/A"}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Issued By',
                        issue.issuedBy ?? issue.createdBy ?? 'Store Officer',
                        'Issue Date: ${DateParserUtils.formatDisplay(issue.issuedAt ?? issue.createdAt)}',
                      ),
                      if (issue.remarks != null && issue.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Remarks', issue.remarks!, ''),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Attached Stock Items List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attached Material Items (${issue.items.length})',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Attached Items
                if (issue.items.isEmpty)
                  _buildCard(
                    child: const Center(
                      child: Text(
                        'No detailed items attached to this issue transaction.',
                        style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: issue.items.length,
                    itemBuilder: (context, index) {
                      final item = issue.items[index];
                      return StockItemCard(
                        item: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockItemDetailScreen(item: item),
                            ),
                          );
                        },
                      );
                    },
                  ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Created: ${DateParserUtils.formatDisplay(issue.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value, String subValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
        if (subValue.isNotEmpty)
          Text(subValue, style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray)),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.infoBlue),
      ),
    );
  }
}
