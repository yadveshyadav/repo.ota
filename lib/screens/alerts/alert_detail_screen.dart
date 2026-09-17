import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/alerts/controller/alert_controller.dart';
import 'package:hero_app/models/alert.dart';
import 'package:intl/intl.dart';

/// Inspection screen displaying full details of a specific fleet alert
class AlertDetailScreen extends StatefulWidget {
  final Alert alert;
  final AlertController? controller;

  const AlertDetailScreen({
    super.key,
    required this.alert,
    this.controller,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late Alert _alert;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
    if (!_alert.isRead && widget.controller != null) {
      widget.controller!.markAsRead(_alert.id);
      _alert = _alert.copyWith(isRead: true);
    }
  }

  void _navigateToMachine() {
    final chassis = _alert.chassisNumber;
    if (chassis.isNotEmpty && chassis != 'N/A') {
      Navigator.of(context).pushNamed(
        AppRoutes.machineDetail,
        arguments: chassis,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    IconData severityIcon;

    if (_alert.isCritical) {
      severityColor = AppColors.criticalRed;
      severityIcon = Icons.error_outline_rounded;
    } else if (_alert.isWarning) {
      severityColor = AppColors.warningAmber;
      severityIcon = Icons.warning_amber_rounded;
    } else {
      severityColor = AppColors.infoBlue;
      severityIcon = Icons.info_outline_rounded;
    }

    final formattedDate = _alert.createdAt != null
        ? DateFormat('dd MMMM yyyy, hh:mm:ss a').format(_alert.createdAt!.toLocal())
        : _alert.relativeTime;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Text('Alert Details', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Severity Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: severityColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: severityColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _alert.displaySeverity,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_alert.alertType != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _alert.alertType!.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _alert.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Alert Message Body Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ALERT DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                  const SizedBox(height: 8),
                  Text(
                    _alert.message,
                    style: const TextStyle(fontSize: 14, color: AppColors.deepNavy, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Machine & Operations Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MACHINE & OPERATIONAL DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.precision_manufacturing_rounded,
                    label: 'Machine / Chassis',
                    valueWidget: InkWell(
                      onTap: _navigateToMachine,
                      child: Text(
                        _alert.chassisNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow(
                    icon: Icons.store_rounded,
                    label: 'Vendor / Partner',
                    value: _alert.vendorName ?? 'Fleet Partner',
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Occurred At',
                    value: formattedDate,
                  ),
                  const Divider(height: 20, color: AppColors.borderGray),
                  _buildDetailRow(
                    icon: Icons.mark_email_read_rounded,
                    label: 'Status',
                    value: _alert.isRead ? 'Read' : 'Unread',
                    valueColor: _alert.isRead ? AppColors.successGreen : AppColors.warningAmber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Technical Metadata Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TECHNICAL METADATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.tag_rounded,
                    label: 'Alert ID',
                    value: _alert.id,
                  ),
                  if (_alert.machineId != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Machine ID',
                      value: _alert.machineId.toString(),
                    ),
                  ],
                  if (_alert.vendorId != null) ...[
                    const Divider(height: 16, color: AppColors.borderGray),
                    _buildDetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Vendor ID',
                      value: _alert.vendorId.toString(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (_alert.chassisNumber != 'N/A') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToMachine,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('View Machine', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mutedTextGray),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
          ],
        ),
        valueWidget ??
            Text(
              value ?? 'N/A',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.deepNavy,
              ),
            ),
      ],
    );
  }
}
