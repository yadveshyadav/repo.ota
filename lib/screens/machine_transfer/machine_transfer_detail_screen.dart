import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/machine_transfer/controller/machine_transfer_controller.dart';
import '../../models/machine_movement.dart';
import '../../shared/widgets/premium_card.dart';
import 'mark_shifted_dialog.dart';

/// Screen displaying complete Machine Shift Request details, Point A -> Point B route, field actions, and audit trail
class MachineTransferDetailScreen extends StatefulWidget {
  final dynamic transferId;
  final MachineTransferController? controller;

  const MachineTransferDetailScreen({
    super.key,
    required this.transferId,
    this.controller,
  });

  @override
  State<MachineTransferDetailScreen> createState() => _MachineTransferDetailScreenState();
}

class _MachineTransferDetailScreenState extends State<MachineTransferDetailScreen> {
  late final MachineTransferController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MachineTransferController();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    await _controller.fetchTransferDetail(widget.transferId);
  }

  Future<void> _handleStartShifting(MachineMovement movement) async {
    final success = await _controller.startShifting(movement.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shifting marked as In Progress.'), backgroundColor: AppColors.successGreen),
      );
      _loadDetail();
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.errorMessage!), backgroundColor: AppColors.criticalRed),
      );
    }
  }

  void _openMarkShiftedDialog(MachineMovement movement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MarkShiftedDialog(
        movement: movement,
        controller: _controller,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Machine marked as SHIFTED successfully!'), backgroundColor: AppColors.successGreen),
          );
          _loadDetail();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;
        final movement = _controller.activeTransfer;

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            foregroundColor: AppColors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement != null ? movement.requestId : 'Shift Detail',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (movement != null)
                  Text(
                    '${movement.machineName} (${movement.machineChassisNo})',
                    style: const TextStyle(fontSize: 11, color: AppColors.white),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadDetail,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : movement == null
                  ? _buildNotFoundView()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Status Banner
                          _buildStatusCard(movement),

                          const SizedBox(height: 16),

                          // 2. Field Action Box (Start Shifting / Mark Shifted)
                          if (movement.isApprovedByScm || movement.isInProgress) ...[
                            _buildActionBox(movement),
                            const SizedBox(height: 16),
                          ],

                          // 3. Point A -> Point B Route Card
                          _buildRouteCard(movement),

                          const SizedBox(height: 16),

                          // 4. Shifter Details & Expense Summary (If present)
                          if (movement.shiftingDate != null || movement.shiftingExpenseAmount != null) ...[
                            _buildShifterSummaryCard(movement),
                            const SizedBox(height: 16),
                          ],

                          // 5. Machine Destination Picture Card (If present)
                          if (movement.machinePictureUrl != null && movement.machinePictureUrl!.isNotEmpty) ...[
                            _buildMachinePhotoCard(movement),
                            const SizedBox(height: 16),
                          ],

                          // 6. Audit Trail Timeline
                          _buildAuditTrailCard(movement),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildStatusCard(MachineMovement movement) {
    Color color = AppColors.warningAmber;
    IconData icon = Icons.hourglass_top_rounded;

    if (movement.isApprovedByScm) {
      color = AppColors.infoBlue;
      icon = Icons.verified_user_rounded;
    } else if (movement.isInProgress) {
      color = AppColors.warningAmber;
      icon = Icons.local_shipping_rounded;
    } else if (movement.isShifted) {
      color = AppColors.successGreen;
      icon = Icons.check_circle_rounded;
    } else if (movement.isConfirmed) {
      color = AppColors.headerGreen;
      icon = Icons.lock_rounded;
    } else if (movement.isCancelled) {
      color = AppColors.criticalRed;
      icon = Icons.cancel_rounded;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '• ${movement.statusDisplay.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  movement.requestId,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  movement.isPendingShifting
                      ? 'Request submitted and pending SCM approval.'
                      : movement.isApprovedByScm
                          ? 'Approved by SCM. Ready for field team to start shifting.'
                          : movement.isInProgress
                              ? 'Shifting in progress. Field team relocating rig to Point B.'
                              : movement.isShifted
                                  ? 'Rig shifted to Point B. Pending final SCM confirmation.'
                                  : movement.isConfirmed
                                      ? 'Request confirmed and locked by SCM.'
                                      : 'Shift request cancelled.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBox(MachineMovement movement) {
    if (movement.isApprovedByScm) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Field Shifter Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy)),
            const SizedBox(height: 4),
            const Text('Tap below when field team begins relocating the rig to Point B.', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _controller.isSubmitting ? null : () => _handleStartShifting(movement),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('START SHIFTING', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (movement.isInProgress) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arrival Completion Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepNavy)),
            const SizedBox(height: 4),
            const Text('Capture mandatory destination machine picture to mark request as SHIFTED.', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openMarkShiftedDialog(movement),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('MARK AS SHIFTED', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRouteCard(MachineMovement movement) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Route & Machine Summary', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          _buildRow('Machine Name', movement.machineName),
          _buildRow('Chassis Number', movement.machineChassisNo),
          _buildRow('Operating Vendor', movement.vendorName),
          _buildRow('Shifting Reason', movement.reasonName),
          _buildRow('Mode of Shifting', movement.modeOfShifting),
          _buildRow('Required Date', movement.requiredDate),
          const Divider(height: 20, color: AppColors.borderGray),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, color: AppColors.movingBlue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORIGIN (POINT A)', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    Text(movement.aPointName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.criticalRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DESTINATION (POINT B)', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
                    Text(movement.bPointName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShifterSummaryCard(MachineMovement movement) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shifter Details & Expenses', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          if (movement.shiftingDate != null) _buildRow('Shifting Date', movement.shiftingDate!),
          if (movement.shiftingMode != null) _buildRow('Shifting Vehicle Mode', movement.shiftingMode!),
          if (movement.shiftingContactPerson != null) _buildRow('Contact Person', movement.shiftingContactPerson!),
          if (movement.shiftingExpenseAmount != null) _buildRow('Expense Amount', '₹ ${movement.shiftingExpenseAmount!}'),
          if (movement.remarks != null && movement.remarks!.isNotEmpty) _buildRow('Remarks', movement.remarks!),
        ],
      ),
    );
  }

  Widget _buildMachinePhotoCard(MachineMovement movement) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destination Machine Photo', style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              movement.machinePictureUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: AppColors.softGray,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, color: AppColors.mutedTextGray, size: 32),
                      SizedBox(height: 6),
                      Text('Destination photo captured by shifter', style: AppTextStyles.caption),
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

  Widget _buildAuditTrailCard(MachineMovement movement) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audit Trail', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          if (movement.auditTrail.isEmpty)
            const Text('No audit events recorded yet.', style: AppTextStyles.caption)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: movement.auditTrail.length,
              itemBuilder: (context, index) {
                final item = movement.auditTrail[index];
                final isLast = index == movement.auditTrail.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast) Container(width: 2, height: 32, color: AppColors.borderGray),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.action.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                            Text('By ${item.performedByName} • ${_formatTime(item.createdAt)}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.mutedTextGray),
            SizedBox(height: 12),
            Text('Shift request record not found.'),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
