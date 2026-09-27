import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/machine_transfer/controller/machine_transfer_controller.dart';
import '../../models/machine_movement.dart';
import '../../shared/widgets/premium_card.dart';
import 'machine_transfer_detail_screen.dart';
import 'machine_transfer_flow_screen.dart';

/// Screen listing active and historical Machine Transfers
class MachineTransfersListScreen extends StatefulWidget {
  final MachineTransferController? controller;

  const MachineTransfersListScreen({
    super.key,
    this.controller,
  });

  @override
  State<MachineTransfersListScreen> createState() => _MachineTransfersListScreenState();
}

class _MachineTransfersListScreenState extends State<MachineTransfersListScreen> {
  late final MachineTransferController _controller;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MachineTransferController();
    _fetchList();
  }

  Future<void> _fetchList() async {
    await _controller.fetchTransfersList(statusFilter: _selectedFilter);
  }

  void _navigateToDetail(MachineMovement movement) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineTransferDetailScreen(transferId: movement.id),
      ),
    );
  }

  void _navigateToCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MachineTransferFlowScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;
        final list = _controller.transfersList;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            foregroundColor: AppColors.white,
            title: const Text('Machine Shifting', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _navigateToCreate,
                tooltip: 'New Transfer',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchList,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Bar
              _buildFilterBar(),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                    : RefreshIndicator(
                        onRefresh: _fetchList,
                        color: AppColors.primaryGreen,
                        child: list.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  final movement = list[index];
                                  return _buildTransferCard(movement);
                                },
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Active', 'In_Transit', 'Completed'];

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter.toLowerCase() == f.toLowerCase();
            final label = f.replaceAll('_', ' ');

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppColors.deepNavy,
                backgroundColor: AppColors.softGray,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.deepNavy,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFilter = f);
                    _fetchList();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTransferCard(MachineMovement movement) {
    Color statusColor = AppColors.warningAmber;
    if (movement.isApprovedByScm) {
      statusColor = AppColors.infoBlue;
    } else if (movement.isInProgress) {
      statusColor = AppColors.warningAmber;
    } else if (movement.isShifted) {
      statusColor = AppColors.successGreen;
    } else if (movement.isConfirmed) {
      statusColor = AppColors.headerGreen;
    } else if (movement.isCancelled) {
      statusColor = AppColors.criticalRed;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: () => _navigateToDetail(movement),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    movement.transferNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '• ${movement.statusDisplay}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${movement.machineName} (${movement.machineChassisNo})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
              Text('Reason: ${movement.reasonName}', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.mutedTextGray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${movement.aPointName} → ${movement.bPointName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.alt_route_rounded, size: 48, color: AppColors.mutedTextGray),
          const SizedBox(height: 12),
          const Text('No machine shifting requests found', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          const Text('Tap "+" to initiate a machine shifting request.', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
