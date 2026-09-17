import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/live_status_colors.dart';
import '../../../models/machine.dart';
import '../../../screens/machines/machine_tracking_screen.dart';

/// Reusable production-quality Machine Card widget for Live Status grid.
class LiveMachineCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback? onViewOnMap;

  const LiveMachineCard({
    super.key,
    required this.machine,
    this.onViewOnMap,
  });

  String _formatTimestamp(String raw) {
    if (raw.trim().isEmpty) return 'N/A';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return DateFormat('dd MMM HH:mm:ss').format(dt.toLocal());
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = LiveStatusColors.getOperationalStateColor(
      machine.operationalState.label,
    );

    final formattedPacket = _formatTimestamp(machine.lastPacketAt);
    final formattedLoc = _formatTimestamp(machine.lastLocationAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HEADER (Heading arrow + Course, Model, Chassis No, Connectivity icon)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Course Heading Icon & Angle
                    Row(
                      children: [
                        Transform.rotate(
                          angle: machine.course * math.pi / 180,
                          child: const Icon(
                            Icons.navigation_rounded,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Course ${machine.course.toInt()}°',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedTextGray,
                          ),
                        ),
                      ],
                    ),

                    // Model & Connectivity Icon
                    Row(
                      children: [
                        Text(
                          machine.model,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ConnectivityDot(connectivity: machine.connectivity),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                // Chassis Number
                Text(
                  machine.chassisNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTextGray,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 6),

                // 2. STATUS BADGES (Connectivity + Operational State)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _StatusBadge(
                      label: machine.connectivity == ConnectivityState.live
                          ? 'Live'
                          : 'Offline',
                      color: machine.connectivity == ConnectivityState.live
                          ? AppColors.successGreen
                          : AppColors.criticalRed,
                    ),
                    _StatusBadge(
                      label: machine.operationalState.label,
                      color: statusColor,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 3. LOCATION & SITE
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.mutedTextGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        machine.location,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.deepNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    'Site: ${machine.site}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedTextGray,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderGray),

          // 4. METRICS (RPM, Fuel, Coolant, Oil)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricItem(
                      label: 'RPM',
                      value: machine.rpm > 0 ? '${machine.rpm.toInt()}' : '0',
                    ),
                    _MetricItem(
                      label: 'Fuel',
                      value: '${machine.fuelLevel.toInt()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricItem(
                      label: 'Coolant',
                      value: '${machine.coolantTemperature.toInt()}°',
                    ),
                    _MetricItem(
                      label: 'Oil',
                      value: '${machine.oilLevel}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderGray),

          // 5. FOOTER & ACTION BUTTON
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timestamps
                Text(
                  'Packet $formattedPacket · Loc $formattedLoc',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.mutedTextGray,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // View on map button
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: onViewOnMap ?? () => _defaultViewOnMap(context),
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                    label: const Text(
                      'View on map',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _defaultViewOnMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineTrackingScreen(machine: machine),
      ),
    );
  }
}

class _ConnectivityDot extends StatelessWidget {
  final ConnectivityState connectivity;

  const _ConnectivityDot({required this.connectivity});

  @override
  Widget build(BuildContext context) {
    final color = connectivity == ConnectivityState.live
        ? AppColors.successGreen
        : connectivity == ConnectivityState.weak
            ? AppColors.warningAmber
            : AppColors.criticalRed;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: connectivity == ConnectivityState.live
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mutedTextGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
