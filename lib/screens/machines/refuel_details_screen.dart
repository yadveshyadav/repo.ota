import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/refuel_model.dart';
import '../../shared/widgets/premium_card.dart';

/// Refuel Details Screen rendering live refuel transaction details
class RefuelDetailsScreen extends StatelessWidget {
  final RefuelModel? refuel;
  final Map<String, dynamic>? refuelItem;

  const RefuelDetailsScreen({
    super.key,
    this.refuel,
    this.refuelItem,
  });

  @override
  Widget build(BuildContext context) {
    late final RefuelModel model;
    if (refuel != null) {
      model = refuel!;
    } else if (refuelItem != null) {
      model = RefuelModel.fromJson(refuelItem!);
    } else {
      model = RefuelModel.fromJson(const {});
    }

    final dateTimeStr = model.formattedDate;
    final amountText = model.formattedAmount;
    final refueledBy = model.performedByName;
    final meterReading = model.formattedMeterReading;
    final machineName = model.machineName.isNotEmpty ? model.machineName : 'Machine';
    final machineCode = model.machineCode.isNotEmpty ? model.machineCode : model.machineNo;
    final costStr = model.formattedCost;
    final priceStr = model.pricePerLiter > 0 ? '₹${model.pricePerLiter.toStringAsFixed(2)} / L' : 'N/A';
    final notes = model.notes.isNotEmpty ? model.notes : 'Field refueling log';

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Refuel Details',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Header Banner
            PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      color: AppColors.successGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateTimeStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedTextGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amountText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.successGreen,
                          ),
                        ),
                        if (machineName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            machineCode.isNotEmpty ? '$machineName ($machineCode)' : machineName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Refuel Information Card
            PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Refuel Transaction Info',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Performed By', refueledBy),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow('Quantity Added', model.formattedAmount.replaceAll('+', '')),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow('Total Cost', costStr),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow('Price / Liter', priceStr),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow('Meter / Engine Reading', meterReading),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow('Notes / Location', notes),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
