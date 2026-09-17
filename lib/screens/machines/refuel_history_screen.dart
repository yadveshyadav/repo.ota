import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/fuel/controller/refuel_controller.dart';
import '../../models/refuel_model.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'refuel_details_screen.dart';

/// Live API-integrated Refuel History Screen for Machine / Fleet Refuel Logging
class RefuelHistoryScreen extends StatefulWidget {
  final String? machineId;
  final String machineName;

  const RefuelHistoryScreen({
    super.key,
    this.machineId,
    this.machineName = 'Fleet Machines',
  });

  @override
  State<RefuelHistoryScreen> createState() => _RefuelHistoryScreenState();
}

class _RefuelHistoryScreenState extends State<RefuelHistoryScreen> {
  late final RefuelController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RefuelController(machineId: widget.machineId);
    _controller.fetchRefuelLogs();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
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
                const Text(
                  'Refuel History',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.machineName,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: () => _controller.refresh(),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            color: AppColors.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Top Summary Stats Card
                  PremiumCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryMetric(
                            'Total Refuels',
                            '${_controller.totalRefuels}',
                          ),
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderGray),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Total Fuel',
                            '${_controller.totalFuelAdded.toStringAsFixed(0)} L',
                          ),
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderGray),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Avg / Refuel',
                            '${_controller.avgFuelPerRefuel.toStringAsFixed(1)} L',
                          ),
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderGray),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Total Cost',
                            '₹${_controller.totalCost.toStringAsFixed(0)}',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Loading / Empty / Content View
                  if (_controller.isLoading)
                    Column(
                      children: List.generate(
                        4,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12.0),
                          child: SkeletonBox(
                            width: double.infinity,
                            height: 80,
                            borderRadius: 12,
                          ),
                        ),
                      ),
                    )
                  else if (_controller.errorMessage != null)
                    _buildErrorView(_controller.errorMessage!)
                  else if (_controller.refuelLogs.isEmpty)
                    _buildEmptyView()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _controller.refuelLogs.length,
                      itemBuilder: (context, index) {
                        final item = _controller.refuelLogs[index];
                        final isLast = index == _controller.refuelLogs.length - 1;

                        return _buildTimelineTile(item, isLast);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTile(RefuelModel item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Green Timeline Dotted Indicator Column
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Refuel Event Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RefuelDetailsScreen(
                        refuel: item,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.formattedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ),
                          Text(
                            item.formattedAmount,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Refueled By', style: AppTextStyles.caption),
                          Text(
                            item.performedByName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Meter Reading', style: AppTextStyles.caption),
                          Text(
                            item.formattedMeterReading,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                      if (item.totalCost > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Cost', style: AppTextStyles.caption),
                            Text(
                              item.formattedCost,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.local_gas_station_outlined, size: 54, color: AppColors.mutedTextGray),
          SizedBox(height: 12),
          Text(
            'No Refuel Records Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
          ),
          SizedBox(height: 6),
          Text(
            'No fuel entries recorded for this machine or fleet timeline.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.criticalRed),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.criticalRed),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _controller.refresh(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
