import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine_location.dart';
import '../../shared/widgets/premium_card.dart';

/// Live Location Card displaying interactive OpenStreetMap with machine markers
class LiveLocationCard extends StatelessWidget {
  final List<MachineLocation> locations;

  const LiveLocationCard({
    super.key,
    required this.locations,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      title: 'Live Location',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${locations.length} active',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20.5937, 78.9629), // Center on India
              initialZoom: 4.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.infocrats.vehicleiq',
              ),
              MarkerLayer(
                markers: locations.map((loc) {
                  Color statusColor;
                  switch (loc.status.toLowerCase()) {
                    case 'working':
                    case 'online':
                      statusColor = AppColors.successGreen;
                      break;
                    case 'idle':
                    case 'warning':
                      statusColor = AppColors.warningAmber;
                      break;
                    default:
                      statusColor = AppColors.criticalRed;
                  }

                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showMachineDetailBottomSheet(context, loc),
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_rounded,
                          color: AppColors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMachineDetailBottomSheet(
      BuildContext context, MachineLocation loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.machineName,
                    style: AppTextStyles.headingMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loc.status,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Chassis ID: ${loc.chassisNumber}',
                  style: AppTextStyles.bodyMedium),
              const Divider(height: 24),
              _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: loc.address),
              const SizedBox(height: 12),
              _DetailRow(
                  icon: Icons.speed_rounded,
                  label: 'Speed',
                  value: '${loc.speed} km/h'),
              const SizedBox(height: 12),
              _DetailRow(
                  icon: Icons.explore_outlined,
                  label: 'Course',
                  value: '${loc.course}°'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.bodyMedium),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.deepNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
