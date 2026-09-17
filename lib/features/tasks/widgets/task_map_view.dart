import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/task_model.dart';

/// Task Map View Widget displaying actual API coordinates or fallback card
class TaskMapViewWidget extends StatelessWidget {
  final TaskModel task;

  const TaskMapViewWidget({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    // Check if task or route segments have valid GPS coordinates
    final bool hasTaskCoords = task.latitude != null && task.longitude != null;

    final List<Marker> markers = [];
    final List<Polyline> polylines = [];

    if (hasTaskCoords) {
      markers.add(
        Marker(
          point: LatLng(task.latitude!, task.longitude!),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.criticalRed,
            size: 36,
          ),
        ),
      );
    }

    // Collect coordinates from route segments
    final List<LatLng> polylinePoints = [];
    for (final route in task.routes) {
      for (final segment in route.segments) {
        if (segment.startLat != null && segment.startLng != null) {
          final pt = LatLng(segment.startLat!, segment.startLng!);
          polylinePoints.add(pt);
          markers.add(
            Marker(
              point: pt,
              width: 30,
              height: 30,
              child: const Icon(
                Icons.fiber_manual_record_rounded,
                color: AppColors.infoBlue,
                size: 20,
              ),
            ),
          );
        }
        if (segment.targetLat != null && segment.targetLng != null) {
          final pt = LatLng(segment.targetLat!, segment.targetLng!);
          polylinePoints.add(pt);
          markers.add(
            Marker(
              point: pt,
              width: 30,
              height: 30,
              child: const Icon(
                Icons.location_city_rounded,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
          );
        }
      }
    }

    if (polylinePoints.length >= 2) {
      polylines.add(
        Polyline(
          points: polylinePoints,
          strokeWidth: 4.0,
          color: AppColors.primaryGreen,
        ),
      );
    }

    final bool hasValidMapData = markers.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.map_outlined, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Task Route & Node Map',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasValidMapData)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.location_off_outlined,
                      size: 36, color: AppColors.mutedTextGray),
                  SizedBox(height: 8),
                  Text(
                    'Location data unavailable',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'GPS coordinates have not been assigned to this task.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedTextGray,
                    ),
                  ),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: markers.first.point,
                    initialZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.infocrats.hero',
                    ),
                    if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
