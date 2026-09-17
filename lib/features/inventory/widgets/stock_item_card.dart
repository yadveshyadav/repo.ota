import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_parser_utils.dart';
import '../../../models/stock_item_model.dart';

/// Mobile-first Stock Item / Drum Card Component for Inventory Workspace
class StockItemCard extends StatelessWidget {
  final StockItemModel item;
  final VoidCallback onTap;

  const StockItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.itemStatus ?? item.status);

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
              // Header: Serial No / Drum No & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.serialNo != null && item.serialNo!.isNotEmpty
                                ? item.serialNo!
                                : 'Stock Item ${item.id ?? "N/A"}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(item.itemStatus ?? item.status ?? 'AVAILABLE', statusColor),
                ],
              ),
              const SizedBox(height: 8),

              // Material Description
              Text(
                item.materialDescription ?? 'Unspecified Material',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepNavy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.borderGray),
              const SizedBox(height: 10),

              // Metrics Row: Quantity, Issue #, Warehouse
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Quantity',
                      item.quantity != null
                          ? '${item.quantity!.toStringAsFixed(1)} ${item.unitOfMeasurement ?? "Meters"}'
                          : 'Not recorded',
                    ),
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      'Issue #',
                      item.issueNumber ?? 'Unissued',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location & Vendor Row
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          size: 14,
                          color: AppColors.mutedTextGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.fromWarehouseName ?? item.fromWarehouseCode ?? 'Central Store',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedTextGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: AppColors.mutedTextGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.issueeName ?? item.assignedTo ?? 'Unassigned Vendor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedTextGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (item.issuedAt != null || item.createdAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Issued: ${DateParserUtils.formatDisplay(item.issuedAt ?? item.createdAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedTextGray,
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Item',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ],
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
    if (status == null) return AppColors.mutedTextGray;
    final s = status.toUpperCase();
    if (s == 'ISSUED' || s == 'DISPATCHED' || s == 'ACTIVE') {
      return AppColors.primaryGreen;
    } else if (s == 'RESERVED' || s == 'PENDING') {
      return AppColors.warningAmber;
    } else if (s == 'CONSUMED' || s == 'DELIVERED') {
      return AppColors.infoBlue;
    } else if (s == 'RETURNED' || s == 'CANCELLED') {
      return AppColors.criticalRed;
    }
    return AppColors.primaryGreen;
  }
}
