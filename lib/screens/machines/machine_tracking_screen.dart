import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine.dart';

/// Live GPS Tracking & Route Screen matching Screen 4 reference design
class MachineTrackingScreen extends StatefulWidget {
  final Machine machine;

  const MachineTrackingScreen({
    super.key,
    required this.machine,
  });

  @override
  State<MachineTrackingScreen> createState() => _MachineTrackingScreenState();
}

class _MachineTrackingScreenState extends State<MachineTrackingScreen> {
  late final MapController _mapController;

  LatLng get _currentPoint {
    if (widget.machine.latitude != 0.0 && widget.machine.longitude != 0.0) {
      return LatLng(widget.machine.latitude, widget.machine.longitude);
    }
    return const LatLng(27.714985, 74.647016);
  }

  LatLng get _startPoint {
    return LatLng(
      _currentPoint.latitude - 0.008,
      _currentPoint.longitude - 0.006,
    );
  }

  List<LatLng> get _routePoints => [
        _startPoint,
        LatLng(_startPoint.latitude + 0.002, _startPoint.longitude + 0.001),
        LatLng(_startPoint.latitude + 0.004, _startPoint.longitude + 0.003),
        LatLng(_startPoint.latitude + 0.006, _startPoint.longitude + 0.004),
        _currentPoint,
      ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    _mapController.move(_currentPoint, 14.5);
  }

  @override
  Widget build(BuildContext context) {
    final titleName = widget.machine.machineName.isNotEmpty
        ? widget.machine.machineName
        : 'A600 HDD';

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$titleName-Tracking',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.white),
            onPressed: () {},
            tooltip: 'Map Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Live Status Banner Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.successGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Last updated: 2 min ago',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedTextGray,
                  ),
                ),
              ],
            ),
          ),

          // Interactive Map View with Route Polyline and Markers
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPoint,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.infocrats.hero_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Start Point Marker
                        Marker(
                          point: _startPoint,
                          width: 24,
                          height: 24,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.successGreen,
                            size: 24,
                          ),
                        ),
                        // Current Live Location Pin
                        Marker(
                          point: _currentPoint,
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Floating Recenter Map Button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'recenterMapFab',
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.deepNavy,
                    elevation: 3,
                    onPressed: _recenterMap,
                    child: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Location Telemetry & Summary Panel
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.infoBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.infoBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.machine.location.isNotEmpty
                                ? widget.machine.location
                                : 'Sujangarh-SITE, HR',
                            style: AppTextStyles.headingSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${_currentPoint.latitude.toStringAsFixed(6)}° N, Long: ${_currentPoint.longitude.toStringAsFixed(6)}° E',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderGray),
                const SizedBox(height: 14),

                // Speed / Direction / Total Distance Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTrackingMetric(
                        label: 'SPEED',
                        value:
                            '${widget.machine.speed > 0 ? widget.machine.speed.toInt() : 18} km/h',
                      ),
                    ),
                    Container(
                        width: 1, height: 32, color: AppColors.borderGray),
                    Expanded(
                      child: _buildTrackingMetric(
                        label: 'DIRECTION',
                        value: 'NE',
                      ),
                    ),
                    Container(
                        width: 1, height: 32, color: AppColors.borderGray),
                    Expanded(
                      child: _buildTrackingMetric(
                        label: 'TOTAL DISTANCE',
                        value: '24.6 km',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderGray),
                const SizedBox(height: 12),

                // Today's Summary Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Summary",
                      style: AppTextStyles.headingSmall,
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 4 Summary Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Distance', '24.6 km'),
                    _buildSummaryItem('Moving Time', '2h 35m'),
                    _buildSummaryItem('Avg Speed', '18 km/h'),
                    _buildSummaryItem('Idle Time', '45m'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingMetric({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedTextGray,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
