import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine.dart';
import '../../repositories/machine_repository.dart';
import '../../services/authorization_service.dart';
import '../../shared/widgets/premium_card.dart';
import 'machine_tracking_screen.dart';
import 'refuel_history_screen.dart';
import '../machine_transfer/machine_transfer_flow_screen.dart';

/// Machine Details Screen matching reference design exactly
class MachineDetailScreen extends StatefulWidget {
  final String chassisNo;
  final MachineRepository? repository;

  const MachineDetailScreen({
    super.key,
    required this.chassisNo,
    this.repository,
  });

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late final MachineRepository _repository;
  Machine? _machine;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMachineRepository();
    _loadMachineDetails();
  }

  Future<void> _loadMachineDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final machines = await _repository.getAllMachines();
      final match = machines.firstWhere(
        (m) => m.machineChassisNo == widget.chassisNo,
        orElse: () => Machine(
          machineChassisNo: widget.chassisNo,
          modelName: 'A600 HDD (8396)',
          siteName: 'Sujangarh-SITE',
        ),
      );

      if (!mounted) return;
      setState(() {
        _machine = match;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load details for ${widget.chassisNo}: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToTracking(Machine machine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineTrackingScreen(machine: machine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final machine = _machine;
    final titleName = machine?.machineName.isNotEmpty == true
        ? machine!.machineName
        : 'A600 HDD (8396)';

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
            Text(
              titleName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (machine != null)
              Text(
                'APOLLO ${machine.model} • Chassis: ${machine.chassisNumber}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route_rounded, color: AppColors.white),
            onPressed: () {
              if (machine != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MachineTransferFlowScreen(preSelectedMachine: machine),
                  ),
                );
              }
            },
            tooltip: 'Shift Machine',
          ),
          IconButton(
            icon: const Icon(Icons.navigation_rounded, color: AppColors.white),
            onPressed: () {
              if (machine != null) _navigateToTracking(machine);
            },
            tooltip: 'Live Tracking',
          ),
          if (AuthorizationService.instance.can('machines.update'))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Machine dialog opened')),
                );
              },
              tooltip: 'Edit Machine',
            ),
          if (AuthorizationService.instance.can('machines.delete'))
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete Machine dialog opened')),
                );
              },
              tooltip: 'Delete Machine',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : machine == null
                  ? const Center(child: Text('Machine not found.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Top Machine Header Banner
                          _buildTopHeaderCard(machine),

                          const SizedBox(height: 16),

                          // 2. Overview Metrics Quadrants
                          _buildOverviewSection(machine),

                          const SizedBox(height: 16),

                          // 3. Live GPS Location Map Card
                          _buildLiveLocationSection(machine),

                          const SizedBox(height: 16),

                          // 4. Fuel Status Section
                          _buildFuelStatusSection(machine),

                          const SizedBox(height: 16),

                          // 5. Active Machine Alerts Section
                          _buildActiveAlertsSection(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildTopHeaderCard(Machine machine) {
    final statusColor = machine.isOnline ? AppColors.successGreen : AppColors.mutedTextGray;
    final opName = machine.operatorName;
    final vName = (machine.vendorName != null && machine.vendorName!.isNotEmpty)
        ? machine.vendorName!
        : 'Hero Infra Vendors';

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Green Graphic Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.precision_manufacturing_rounded,
                color: AppColors.primaryGreen,
                size: 32,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '• ${machine.operationalState.label}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '• ${machine.connectivity.label}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.mutedTextGray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        machine.location.isNotEmpty
                            ? machine.location
                            : 'Sujangarh-SITE, HR',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Operator: $opName • Vendor: $vName',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MachineTransferFlowScreen(preSelectedMachine: machine),
                        ),
                      );
                    },
                    icon: const Icon(Icons.alt_route_rounded, size: 14),
                    label: const Text('SHIFT MACHINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  Widget _buildOverviewSection(Machine machine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Overview Metrics', style: AppTextStyles.headingSmall),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Live',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PremiumCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildMetricBox(
                          machine.displayRuntime, 'Runtime Today')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildMetricBox(
                          '${machine.engineHours?.toInt() ?? 1000}h',
                          'Engine Hours')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildMetricBox('50.00 L', 'Fuel Used')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildMetricBox(
                          '${machine.fuelLevelPercent.toInt()}%',
                          'Fuel Level')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.deepNavy,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationSection(Machine machine) {
    final latLng = (machine.latitude != 0.0 && machine.longitude != 0.0)
        ? LatLng(machine.latitude, machine.longitude)
        : const LatLng(27.714985, 74.647016);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Live GPS Location', style: AppTextStyles.headingSmall),
            InkWell(
              onTap: () => _navigateToTracking(machine),
              child: const Text(
                'Full Route →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.infoBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _navigateToTracking(machine),
          child: PremiumCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: latLng,
                        initialZoom: 13.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'com.infocrats.hero_app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latLng,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.infoBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: AppColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle,
                                size: 6, color: AppColors.successGreen),
                            SizedBox(width: 4),
                            Text(
                              'Location • Live',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFuelStatusSection(Machine machine) {
    final titleName = machine.machineName.isNotEmpty
        ? machine.machineName
        : 'A600 HDD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fuel Status', style: AppTextStyles.headingSmall),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RefuelHistoryScreen(
                      machineId: machine.id.isNotEmpty ? machine.id : machine.machineChassisNo,
                      machineName: titleName,
                    ),
                  ),
                );
              },
              child: const Text('Refuel History →',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.infoBlue)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Fuel Status Card
        PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${machine.fuelLevelPercent.toInt()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '290.00 L / 500.00 L',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Last refuel: 24 Aug • 30 L',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),

              // Circular Gauge Ring with Fuel Icon
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      value: 0.58,
                      strokeWidth: 5,
                      backgroundColor: AppColors.borderGray,
                      color: AppColors.successGreen,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.lightGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        color: AppColors.successGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Machine Alerts', style: AppTextStyles.headingSmall),
            InkWell(
              onTap: () {},
              child: const Text('View Alert Center →',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.infoBlue)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Column(
          children: [
            _buildAlertBanner(
              icon: Icons.error_outline_rounded,
              bgColor: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFCA5A5),
              iconColor: AppColors.criticalRed,
              title: 'Low Fuel Warning',
              subtitle: 'Fuel level reached 20%. Please schedule refuel.',
              time: '18m ago',
            ),
            const SizedBox(height: 8),
            _buildAlertBanner(
              icon: Icons.build_rounded,
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              iconColor: AppColors.warningAmber,
              title: 'PM Maintenance Due Soon',
              subtitle: 'Scheduled 500-hour service inspection due in 25 engine hours.',
              time: '2h ago',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.criticalRed),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Unable to load details'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMachineDetails,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
