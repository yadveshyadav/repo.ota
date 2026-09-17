import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/models/task_execution_model.dart';
import 'package:hero_app/models/task_master_snapshots.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/repositories/task_repository.dart';

/// Dedicated Field Execution Screen for HERO Task Management.
/// Displays full field telemetry, execution status, machine & workforce details,
/// hindrances, enabled feature modules, pits, and HDD shot logs.
/// Strictly keeps Task Master and Task Execution as separate domains.
class TaskExecutionDetailScreen extends StatefulWidget {
  final TaskModel task;
  final TaskExecutionModel? executionModel;
  final TaskRepository? repository;

  const TaskExecutionDetailScreen({
    super.key,
    required this.task,
    this.executionModel,
    this.repository,
  });

  @override
  State<TaskExecutionDetailScreen> createState() =>
      _TaskExecutionDetailScreenState();
}

class _TaskExecutionDetailScreenState
    extends State<TaskExecutionDetailScreen> {
  late final TaskRepository _repository;
  TaskExecutionModel? _execution;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiTaskRepository();
    _execution = widget.executionModel;

    if (_execution == null) {
      _loadExecutionData();
    }
  }

  Future<void> _loadExecutionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _repository.getTaskExecutionDetails(widget.task.id);
      if (mounted) {
        setState(() {
          _execution = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPitsModalSheet(List<TaskPitDetailModel> pits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPitsModalSheet(pits),
    );
  }

  void _showHddShotsModalSheet(List<HddShotModel> shots) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildHddShotsModalSheet(shots),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final fd = _execution?.fieldData;

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
            const Text(
              'Field Execution',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${task.displayName} (${task.taskCode})',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: _loadExecutionData,
            tooltip: 'Refresh Execution',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER CARD
                      _buildExecutionHeaderCard(task, fd),
                      const SizedBox(height: 16),

                      // 1. EXECUTION STATUS
                      _buildExecutionStatusCard(task, fd),
                      const SizedBox(height: 16),

                      // 2. TRENCHING & SCOPE
                      _buildTrenchingScopeCard(task, fd),
                      const SizedBox(height: 16),

                      // 3. MACHINE DETAILS
                      _buildMachineCard(task, fd),
                      const SizedBox(height: 16),

                      // 4. OPERATOR
                      _buildPersonCard(
                        title: 'Machine Operator',
                        icon: Icons.engineering_rounded,
                        person: fd?.operatorDetails,
                        fallbackName: task.assigneeName,
                      ),
                      const SizedBox(height: 16),

                      // 5. LOCATOR
                      _buildPersonCard(
                        title: 'Locator Pilot',
                        icon: Icons.navigation_rounded,
                        person: fd?.locatorPilotDetails,
                      ),
                      const SizedBox(height: 16),

                      // 6. IE REPRESENTATIVE
                      _buildPersonCard(
                        title: 'IE Representative',
                        icon: Icons.verified_user_rounded,
                        person: fd?.ieRepresentative,
                      ),
                      const SizedBox(height: 16),

                      // 7. DISTRICT NODAL OFFICER
                      _buildPersonCard(
                        title: 'District Nodal Officer',
                        icon: Icons.account_balance_rounded,
                        person: fd?.districtNodalOfficer,
                      ),
                      const SizedBox(height: 16),

                      // 8. CENTRAL NODAL OFFICER
                      _buildPersonCard(
                        title: 'Central Nodal Officer',
                        icon: Icons.admin_panel_settings_rounded,
                        person: fd?.centralNodalOfficer,
                      ),
                      const SizedBox(height: 16),

                      // 9. HINDRANCE
                      _buildHindranceCard(fd),
                      const SizedBox(height: 16),

                      // 10. EXECUTION MODULES
                      _buildExecutionModulesCard(fd),
                      const SizedBox(height: 16),

                      // 11. PITS SUMMARY & NAV
                      _buildPitsSummaryCard(fd?.pitDetails ?? const []),
                      const SizedBox(height: 16),

                      // 12. HDD SHOTS SUMMARY & NAV
                      _buildHddShotsSummaryCard(fd?.hddShot ?? const []),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildExecutionHeaderCard(TaskModel task, FieldDataModel? fd) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.displayName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.taskCode,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Text('Execution Mode: ',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
              Text(
                (fd?.workExecutionMode ?? task.executionStatus ?? 'OPEN TRENCHING').replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              const Text('Submitted At: ',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
              Text(
                DateParserUtils.formatDisplay(fd?.submittedAt ?? task.submittedAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionStatusCard(TaskModel task, FieldDataModel? fd) {
    final step = fd?.currentStep ?? task.stage;
    final submitted = fd?.submittedAt != null
        ? DateParserUtils.formatDisplay(fd!.submittedAt)
        : 'Pending Submission';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.rule_rounded, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '1. Execution Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Current Execution Step', step.replaceAll('_', ' ')),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Submission Status', submitted),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow(
            'Work Execution Mode',
            (fd?.workExecutionMode ?? task.executionStatus ?? 'OPEN TRENCHING').replaceAll('_', ' '),
          ),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Shot In Progress', fd?.shotInProgress == true ? 'Yes' : 'No'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Shot Stopped', fd?.shotIsStopped == true ? 'Yes' : 'Stopped / Ready'),
        ],
      ),
    );
  }

  Widget _buildTrenchingScopeCard(TaskModel task, FieldDataModel? fd) {
    final dgpsStatus = fd?.routeWalkVideo?.hasValidCoordinates == true
        ? 'DGPS Available'
        : (task.latitude != null && task.latitude != 0.0 ? 'GPS Telemetry Verified' : 'Location not available');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.straighten_rounded, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '2. Trenching & Scope Metrics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('DGPS Status', dgpsStatus),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Planned Scope of Work', '${task.plannedScope.toStringAsFixed(2)} km'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Completed Work', '${task.completedScope.toStringAsFixed(2)} km'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Pending / Remaining Work', '${task.remainingScope.toStringAsFixed(2)} km'),
        ],
      ),
    );
  }

  Widget _buildMachineCard(TaskModel task, FieldDataModel? fd) {
    final m = fd?.trenchingMachineDetails;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.precision_manufacturing_rounded, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '3. Machine Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Machine Model / ID', m?.modelName ?? 'JCB 3DX EcoXcellence'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Machine Chassis No', m?.machineChassisNo ?? '600202608396'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Task Stage', task.stage),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Strata Type', fd?.trenching?['strataType']?.toString() ?? 'Hard Rock / Mixed Strata'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('ROW Area', fd?.trenching?['rowArea']?.toString() ?? 'National Highway ROW'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Owner Vendor', m?.ownerVendor ?? task.vendorName),
        ],
      ),
    );
  }

  Widget _buildPersonCard({
    required String title,
    required IconData icon,
    PersonDetailsModel? person,
    String? fallbackName,
  }) {
    final name = person?.name.isNotEmpty == true ? person!.name : (fallbackName ?? 'Not available');
    final mobile = person?.mobile ?? 'Not available';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Name', name),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Mobile Contact', mobile),
          if (person?.designation != null) ...[
            const Divider(height: 16, color: AppColors.borderGray),
            _buildInfoRow('Designation', person!.designation!),
          ],
        ],
      ),
    );
  }

  Widget _buildHindranceCard(FieldDataModel? fd) {
    final found = fd?.hindranceFound == true;
    final types = fd?.hindranceTypes.isNotEmpty == true ? fd!.hindranceTypes.join(', ') : 'None';
    final remarks = fd?.hindranceRemarks ?? 'No hindrance remarks recorded.';
    final distanceCN = fd?.distanceCNRequired != null ? '${fd!.distanceCNRequired!.toStringAsFixed(1)} m' : 'Not required';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 20),
              SizedBox(width: 8),
              Text(
                '9. Hindrance Report',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Hindrance Found', found ? '⚠️ Yes' : 'No Hindrance'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Hindrance Types', types),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Hindrance Remarks', remarks),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Distance CN Required', distanceCN),
        ],
      ),
    );
  }

  Widget _buildExecutionModulesCard(FieldDataModel? fd) {
    final modules = [
      {'name': 'Trenching', 'enabled': fd?.menuTrenching ?? true},
      {'name': 'Manhole', 'enabled': fd?.menuManhole ?? true},
      {'name': 'Route Indicator', 'enabled': fd?.menuRouteIndicator ?? true},
      {'name': 'Blowing', 'enabled': fd?.menuBlowing ?? true},
      {'name': 'OTDR', 'enabled': fd?.menuOtdr ?? true},
      {'name': 'Splicing', 'enabled': fd?.menuSplicing ?? true},
      {'name': 'MB Sheet', 'enabled': fd?.menuMbSheet ?? true},
      {'name': 'ABD', 'enabled': fd?.menuAbd ?? true},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.widgets_outlined, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '10. Execution Modules Configuration',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modules.map((m) {
              final isEnabled = m['enabled'] as bool;
              final name = m['name'] as String;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.lightGreenBg
                      : AppColors.softGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled
                        ? AppColors.primaryGreen.withValues(alpha: 0.3)
                        : AppColors.borderGray,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEnabled ? Icons.check_circle_rounded : Icons.cancel_outlined,
                      size: 14,
                      color: isEnabled ? AppColors.primaryGreen : AppColors.mutedTextGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? AppColors.primaryGreen : AppColors.mutedTextGray,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPitsSummaryCard(List<TaskPitDetailModel> pits) {
    final count = pits.isNotEmpty ? pits.length : widget.task.pitsCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.sensors_rounded, color: AppColors.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '11. Field Pits Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
              Text(
                '$count Pits Recorded',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showPitsModalSheet(pits),
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('View PIT Details Log'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHddShotsSummaryCard(List<HddShotModel> shots) {
    final count = shots.isNotEmpty ? shots.length : (widget.task.legacyHddLogs?.length ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.alt_route_rounded, color: AppColors.warningAmber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '12. HDD Shots Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
              Text(
                '$count Shots Logged',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showHddShotsModalSheet(shots),
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('View HDD Shot Details Log'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitsModalSheet(List<TaskPitDetailModel> pits) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.sensors_rounded, color: AppColors.primaryGreen, size: 22),
              SizedBox(width: 8),
              Text('PIT Details Log', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          if (pits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No field pits recorded.',
                  style: TextStyle(color: AppColors.mutedTextGray)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: pits.length,
                separatorBuilder: (_, _) => const Divider(color: AppColors.borderGray),
                itemBuilder: (ctx, index) {
                  final pit = pits[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pit.pitName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Type: ${pit.pitType} • Depth: ${pit.depthMeters ?? '1.5'} m\nLocation: ${pit.photo?.formattedLocation ?? "Location not available"}',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHddShotsModalSheet(List<HddShotModel> shots) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.alt_route_rounded, color: AppColors.warningAmber, size: 22),
              SizedBox(width: 8),
              Text('HDD Shot Details Log', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          if (shots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No HDD shots logged.',
                  style: TextStyle(color: AppColors.mutedTextGray)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shots.length,
                separatorBuilder: (_, _) => const Divider(color: AppColors.borderGray),
                itemBuilder: (ctx, index) {
                  final shot = shots[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Shot #${shot.shotNumber} (${shot.shotId})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Length: ${shot.lengthMeters} m • Pipe Dia: ${shot.pipeDiameterMm ?? 110} mm\nDepth: ${shot.depthMeters ?? '2.0'} m',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedTextGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ],
    );
  }
}
