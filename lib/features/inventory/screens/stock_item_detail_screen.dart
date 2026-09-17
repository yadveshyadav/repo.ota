import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_parser_utils.dart';
import '../../../models/stock_item_model.dart';

/// Stock Item Detail Inspection Screen
class StockItemDetailScreen extends StatelessWidget {
  final StockItemModel item;

  const StockItemDetailScreen({
    super.key,
    required this.item,
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
              item.serialNo != null && item.serialNo!.isNotEmpty
                  ? item.serialNo!
                  : 'Stock Item Details',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Issue Ref: ${item.issueNumber ?? "Unissued"}',
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
                          Expanded(
                            child: Text(
                              item.materialDescription ?? 'Unspecified Material',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ),
                          _buildStatusChip(item.itemStatus ?? item.status ?? 'AVAILABLE'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Material ID: ${item.materialId ?? item.matId ?? "N/A"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Material Telemetry & Quantity Metrics Card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.straighten_rounded, color: AppColors.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text('Quantity & Length Telemetry', style: AppTextStyles.headingSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderGray),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        'Issued Quantity',
                        item.quantity != null
                            ? '${item.quantity!.toStringAsFixed(1)} ${item.unitOfMeasurement ?? "Meters"}'
                            : 'Not available',
                        '',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Unit Length Range',
                        'Start: ${item.unitStartLength ?? "0.0"} m • End: ${item.unitEndLength ?? "2000.0"} m',
                        'Total Count: ${item.unitCount ?? "2000.0"} m',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Current Length Telemetry',
                        'Start: ${item.currentStartLength ?? "0.0"} m • End: ${item.currentEndLength ?? "2000.0"} m',
                        'Current Count: ${item.currentCount ?? "2000.0"} m',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Warehouse & Assignment Card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warehouse_outlined, color: AppColors.infoBlue, size: 20),
                          SizedBox(width: 8),
                          Text('Warehouse & Assignment', style: AppTextStyles.headingSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderGray),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        'Warehouse Name',
                        item.fromWarehouseName ?? item.fromWarehouseCode ?? 'Central Store',
                        'Code: ${item.fromWarehouseCode ?? "N/A"}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Issued Vendor / Partner',
                        item.issueeName ?? 'Unassigned Vendor',
                        'Issuee Type: ${item.issueeType ?? "VENDOR"}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Assigned Supervisor',
                        item.assignedTo ?? 'Unassigned Supervisor',
                        '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Consumption & Status Lifecycle
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history_toggle_off_rounded, color: AppColors.warningAmber, size: 20),
                          SizedBox(width: 8),
                          Text('Consumption & Reservation', style: AppTextStyles.headingSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderGray),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        'Reserved Quantity',
                        item.reservedQuantity != null ? '${item.reservedQuantity!.toStringAsFixed(1)} m' : '0.0 m',
                        'Reserved From: ${DateParserUtils.formatDisplay(item.reservedFrom)}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Consumed Quantity',
                        item.consumedQuantity != null ? '${item.consumedQuantity!.toStringAsFixed(1)} m' : '0.0 m',
                        'Consumed From: ${DateParserUtils.formatDisplay(item.consumedFrom)}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Returned Quantity',
                        item.returnedQuantity != null ? '${item.returnedQuantity!.toStringAsFixed(1)} m' : '0.0 m',
                        '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Audit Metadata
                Center(
                  child: Text(
                    'Created: ${DateParserUtils.formatDisplay(item.createdAt)} • By ${item.createdBy ?? "System"}',
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
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
      ),
    );
  }
}
