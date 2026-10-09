import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hero_app/core/theme/app_colors.dart';

class HindranceRoutePreview extends StatelessWidget {
  const HindranceRoutePreview({
    super.key,
    required this.points,
    this.title = 'Offline route preview',
    this.height = 260,
  });

  final List<Map<String, dynamic>> points;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final coordinates = points
        .map((point) {
          final latitude = (point['latitude'] as num?)?.toDouble();
          final longitude = (point['longitude'] as num?)?.toDouble();
          if (latitude == null ||
              longitude == null ||
              !latitude.isFinite ||
              !longitude.isFinite ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            return null;
          }
          return LatLng(latitude, longitude);
        })
        .whereType<LatLng>()
        .toList();
    if (coordinates.length < 2) return const SizedBox.shrink();
    final bounds = LatLngBounds.fromPoints(coordinates);
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final hasArea = bounds.north != bounds.south || bounds.east != bounds.west;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${coordinates.length} GPS points',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: hasArea ? 15 : 17,
                initialCameraFit: hasArea
                    ? CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(36),
                      )
                    : null,
                backgroundColor: const Color(0xFFEAF1ED),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.infocrats.hero',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: coordinates,
                      strokeWidth: 5,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coordinates.first,
                      width: 42,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                    Marker(
                      point: coordinates.last,
                      width: 42,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.flag_circle,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text(
              'The route and KML stay available offline. Satellite map tiles need an internet connection.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
