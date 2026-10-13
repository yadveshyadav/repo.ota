import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hero_app/core/theme/app_colors.dart';

class HindranceRoutePreview extends StatelessWidget {
  const HindranceRoutePreview({
    super.key,
    this.points = const [],
    this.existingPoints = const [],
    this.proposedPoints = const [],
    this.proposedRouteApproved = false,
    this.title = 'Offline route preview',
    this.height = 260,
  });

  final List<Map<String, dynamic>> points;
  final List<Map<String, dynamic>> existingPoints;
  final List<Map<String, dynamic>> proposedPoints;
  final bool proposedRouteApproved;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    List<LatLng> coordinatesFor(List<Map<String, dynamic>> source) => source
        .map((point) {
          final latitude = _coordinate(point['latitude']);
          final longitude = _coordinate(point['longitude']);
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
    final legacyCoordinates = coordinatesFor(points);
    final existing = coordinatesFor(existingPoints);
    final proposed = coordinatesFor(proposedPoints);
    final fallback = legacyCoordinates;
    final allCoordinates = [...existing, ...proposed, ...fallback];
    if (allCoordinates.length < 2) return const SizedBox.shrink();
    final bounds = LatLngBounds.fromPoints(allCoordinates);
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final hasArea = bounds.north != bounds.south || bounds.east != bounds.west;
    final hasTwoRoutes = existing.length > 1 && proposed.length > 1;
    final routePoints = proposed.length > 1 ? proposed : fallback;
    final existingColor = proposedRouteApproved
        ? const Color(0xFF929AA3)
        : const Color(0xFF198754);
    final proposedColor = proposedRouteApproved
        ? const Color(0xFF198754)
        : const Color(0xFF929AA3);

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
                  '${allCoordinates.length} GPS points',
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
                    if (existing.length > 1)
                      Polyline(
                        points: existing,
                        strokeWidth: 5,
                        color: existingColor,
                      ),
                    if (proposed.length > 1)
                      Polyline(
                        points: proposed,
                        strokeWidth: 5,
                        color: proposedColor,
                        pattern: proposedRouteApproved
                            ? StrokePattern.solid()
                            : StrokePattern.dotted(),
                      ),
                    if (!hasTwoRoutes && fallback.length > 1)
                      Polyline(
                        points: fallback,
                        strokeWidth: 5,
                        color: AppColors.primaryGreen,
                      ),
                  ],
                ),
                if (routePoints.length > 1)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: routePoints.first,
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
                        point: routePoints.last,
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
          if (hasTwoRoutes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _LegendDot(
                    color: existingColor,
                    label: proposedRouteApproved
                        ? 'Existing route'
                        : 'Approved route',
                  ),
                  _LegendDot(
                    color: proposedColor,
                    label: proposedRouteApproved
                        ? 'Approved proposal'
                        : 'Proposed route · pending',
                  ),
                ],
              ),
            )
          else
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

  static double? _coordinate(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
