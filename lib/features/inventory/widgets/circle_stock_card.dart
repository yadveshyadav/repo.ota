import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/circle_stock_summary_model.dart';

/// Circle-wise Stock Summary Card for Inventory Overview Header
class CircleStockCard extends StatelessWidget {
  final CircleStockSummaryModel circle;
  final VoidCallback? onTap;

  const CircleStockCard({
    super.key,
    required this.circle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      margin: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      circle.circleName ?? 'Circle Store',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.store_outlined,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'WH Code: ${circle.warehouseCode ?? "WH-01"}',
                style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.borderGray),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Drums', '${circle.drumCount ?? 0}'),
                  _buildMiniStat('Vendors', '${circle.vendorsIssued ?? 0}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.mutedTextGray)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
      ],
    );
  }
}
