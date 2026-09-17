import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Machine Status & Fuel Status Cards displaying side-by-side as two columns in a single row.
class MachineAndFuelStatusRow extends StatelessWidget {
  final VoidCallback? onViewAllMachines;
  final Map<String, dynamic>? machineStatusWidget;
  final Map<String, dynamic>? fuelStatusWidget;

  const MachineAndFuelStatusRow({
    super.key,
    this.onViewAllMachines,
    this.machineStatusWidget,
    this.fuelStatusWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Parse Machine Status Widget from API
    final mName = machineStatusWidget?['name']?.toString() ??
        machineStatusWidget?['machine_name']?.toString() ??
        'A600 HDD (8396)';
    final mStatus = machineStatusWidget?['status']?.toString() ?? 'Online';
    final isOnline = machineStatusWidget?['is_online'] as bool? ?? true;
    final runtime = machineStatusWidget?['runtime']?.toString() ?? '09h 48m';
    final currentFuel = machineStatusWidget?['current_fuel_level']?.toString() ?? '47.00 L';
    final todayConsumption = machineStatusWidget?['today_consumption']?.toString() ?? '22.00 L';

    // Parse Fuel Status Widget from API
    final fuelPctNum = (fuelStatusWidget?['percentage'] as num?)?.toDouble() ?? 68.0;
    final fuelPctStr = '${fuelPctNum.toInt()}%';
    final fuelVal = fuelStatusWidget?['current_fuel']?.toString() ?? '340 L';
    final tankCap = fuelStatusWidget?['tank_capacity']?.toString() ?? '500 L';
    final filledQty = fuelStatusWidget?['filled_quantity']?.toString() ?? '220 L';
    final rawFilledBy = fuelStatusWidget?['filled_by']?.toString();
    final filledBy = (rawFilledBy != null &&
            rawFilledBy.trim().isNotEmpty &&
            rawFilledBy.trim() != 'Ravi Kumar' &&
            rawFilledBy.trim() != 'Unassigned' &&
            rawFilledBy.trim() != 'None')
        ? rawFilledBy.trim()
        : 'Not Assigned';

    final machineStatusCard = Container(
      padding: const EdgeInsets.all(10),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Machine Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              InkWell(
                onTap: onViewAllMachines,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Static Machine Details Card (No Flip) - Tapping redirects to Machine Page
          InkWell(
            onTap: onViewAllMachines,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderGray, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: isOnline
                                ? AppColors.successGreen
                                : AppColors.mutedTextGray,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isOnline ? 'Online' : '• $mStatus',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isOnline
                                  ? AppColors.successGreen
                                  : AppColors.mutedTextGray,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildRowItem('Run Time', runtime),
                  const SizedBox(height: 2),
                  _buildRowItem('Current Fuel Level', currentFuel),
                  const SizedBox(height: 2),
                  _buildRowItem("Today's Consumption", todayConsumption),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final fuelStatusCard = Container(
      padding: const EdgeInsets.all(10),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Fuel Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
          const SizedBox(height: 6),
          Row(
            children: [
              // Gauge
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (fuelPctNum / 100).clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor: AppColors.borderGray,
                      color: fuelPctNum < 30
                          ? AppColors.warningAmber
                          : AppColors.successGreen,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(fuelPctStr,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy)),
                        const Text('Fuel Level',
                            style: TextStyle(
                                fontSize: 6.5,
                                color: AppColors.mutedTextGray)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station_outlined,
                            size: 12, color: AppColors.primaryGreen),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Fuel',
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: AppColors.mutedTextGray)),
                              Text(fuelVal,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepNavy)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.markunread_mailbox_outlined,
                            size: 12, color: AppColors.infoBlue),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tank Capacity',
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: AppColors.mutedTextGray)),
                              Text(tankCap,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepNavy)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filled Quantity',
                        style: TextStyle(
                            fontSize: 8.5, color: AppColors.mutedTextGray)),
                    Text(filledQty,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Filled By',
                        style: TextStyle(
                            fontSize: 8.5, color: AppColors.mutedTextGray)),
                    Text(filledBy,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Render as 2 columns in a single row across all mobile & desktop screens
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: machineStatusCard),
          const SizedBox(width: 8),
          Expanded(child: fuelStatusCard),
        ],
      ),
    );
  }

  Widget _buildRowItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.mutedTextGray),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
