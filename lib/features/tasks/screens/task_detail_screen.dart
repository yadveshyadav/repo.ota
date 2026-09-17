import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/tasks/screens/hdd_shots_screen.dart';
import 'package:hero_app/features/tasks/screens/pit_details_screen.dart';
import 'package:hero_app/features/tasks/screens/task_execution_detail_screen.dart';
import 'package:hero_app/features/tasks/widgets/contact_details_bottom_sheet.dart';
import 'package:hero_app/features/tasks/widgets/location_details_bottom_sheet.dart';
import 'package:hero_app/features/tasks/widgets/task_activity_timeline.dart';
import 'package:hero_app/features/tasks/widgets/task_map_view.dart';
import 'package:hero_app/features/tasks/widgets/task_media_gallery.dart';
import 'package:hero_app/features/tasks/widgets/task_route_hierarchy.dart';
import 'package:hero_app/features/tasks/widgets/task_status_badge.dart';
import 'package:hero_app/models/task_execution_model.dart';
import 'package:hero_app/models/task_media_model.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/repositories/task_repository.dart';

/// Task 360 Screen — Polished primary inspection view for HERO Task Management.
/// Features Sticky Header, Tabbed Navigation (Overview, Execution, Evidence, Activity),
/// Progressive Disclosure (Levels 1–3), and Enterprise VehicleIQ styling.
class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final TaskRepository? repository;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.repository,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TaskRepository _repository;
  late final TabController _tabController;
  TaskExecutionModel? _executionModel;

  // Local UI expansion states for Level 2 Progressive Disclosure
  bool _isRouteExpanded = false;
  bool _isExecutionExpanded = false;
  bool _isAssignmentExpanded = false;
  bool _isApprovalExpanded = false;
  bool _isFieldWorkExpanded = false;
  bool _isEvidenceExpanded = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiTaskRepository();
    _tabController = TabController(length: 4, vsync: this);
    _loadTaskExecutionDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskExecutionDetails() async {
    try {
      final exec = await _repository.getTaskExecutionDetails(widget.task.id);
      if (mounted) {
        setState(() {
          _executionModel = exec;
        });
      }
    } catch (_) {}
  }

  void _navigateToExecutionDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskExecutionDetailScreen(
          task: widget.task,
          executionModel: _executionModel,
          repository: _repository,
        ),
      ),
    );
  }

  int _getPitsCount() {
    if (_executionModel?.fieldData?.pitDetails.isNotEmpty == true) {
      return _executionModel!.fieldData!.pitDetails.length;
    }
    return widget.task.pitsCount;
  }

  int _getHddShotsCount() {
    if (_executionModel?.fieldData?.hddShot.isNotEmpty == true) {
      return _executionModel!.fieldData!.hddShot.length;
    }
    return widget.task.hddLogs?.length ?? 0;
  }

  int _getPhotoCount() {
    int count = 0;
    if (_executionModel?.fieldData != null) {
      final fd = _executionModel!.fieldData!;
      if (fd.machineImage?.photoUrl != null) count++;
      count += fd.pitDetails.where((p) => p.photo?.photoUrl != null).length;
      count += fd.hddShot.where((s) => s.photo?.photoUrl != null).length;
      count += fd.hindranceList.where((h) => h.media?.photoUrl != null).length;
    }
    if (widget.task.depthPhotos != null) {
      count += widget.task.depthPhotos!.length;
    }
    return count;
  }

  int _getVideoCount() {
    if (_executionModel?.fieldData?.routeWalkVideo?.photoUrl != null) {
      return 1;
    }
    return 0;
  }

  List<TaskMediaModel> _getEvidenceMediaList() {
    final List<TaskMediaModel> media = [];
    if (_executionModel?.fieldData != null) {
      final fd = _executionModel!.fieldData!;
      if (fd.machineImage != null) media.add(fd.machineImage!);
      for (final p in fd.pitDetails) {
        if (p.photo != null) media.add(p.photo!);
      }
      for (final s in fd.hddShot) {
        if (s.photo != null) media.add(s.photo!);
      }
    }
    return media;
  }

  String _getRouteTraversalString() {
    if (widget.task.routeSnapshot != null) {
      final start = widget.task.routeSnapshot!.startNode?.name ?? widget.task.routeSnapshot!.routeName;
      final target = widget.task.routeSnapshot!.targetNode?.name;
      if (target != null && target.isNotEmpty) {
        return '$start → $target';
      }
      return start;
    }
    if (widget.task.routes.isNotEmpty) {
      final r = widget.task.routes.first;
      return '${r.startNode} → ${r.targetNode}';
    }
    return '${widget.task.blockName} Line';
  }

  String _getGpsAvailabilityString() {
    if (widget.task.latitude != null && widget.task.longitude != null && widget.task.latitude != 0.0) {
      return '${widget.task.latitude!.toStringAsFixed(6)}, ${widget.task.longitude!.toStringAsFixed(6)}';
    }
    if (_executionModel?.fieldData?.routeWalkVideo?.hasValidCoordinates == true) {
      return _executionModel!.fieldData!.routeWalkVideo!.formattedLocation;
    }
    return 'Location not available';
  }

  String _getHindranceStateString() {
    final fd = _executionModel?.fieldData;
    if (fd == null) return 'No Hindrance Reported';
    if (fd.hindranceFound) {
      final types = fd.hindranceTypes.isNotEmpty ? fd.hindranceTypes.join(', ') : 'Active Hindrance';
      return '⚠️ $types';
    }
    return 'No Hindrance Reported';
  }

  void _showLocationBottomSheet() {
    LocationDetailsBottomSheet.show(
      context,
      task: widget.task,
      onOpenMap: () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _showContactBottomSheet() {
    ContactDetailsBottomSheet.show(context, task: widget.task);
  }

  void _showPitsModalSheet() {
    final pits = _executionModel?.fieldData?.pitDetails ?? const [];
    PitDetailsScreen.show(context, pits: pits, taskCode: widget.task.taskCode);
  }

  void _showHddShotsModalSheet() {
    final shots = _executionModel?.fieldData?.hddShot ?? const [];
    HddShotsScreen.show(context, shots: shots, taskCode: widget.task.taskCode);
  }

  void _showEvidenceModalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildEvidenceModalSheet(),
    );
  }

  void _showApprovalHistoryModalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildApprovalHistoryModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

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
              task.displayName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              task.taskCode,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: _loadTaskExecutionDetails,
            tooltip: 'Refresh Task 360',
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
            onSelected: (value) {
              if (value == 'share') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task Code ${task.taskCode} copied!')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18, color: AppColors.deepNavy),
                    SizedBox(width: 8),
                    Text('Share Task Code'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Execution'),
            Tab(text: 'Evidence'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(task),
              _buildExecutionTab(task),
              _buildEvidenceTab(task),
              _buildActivityTab(task),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: OVERVIEW
  Widget _buildOverviewTab(TaskModel task) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(task),
          const SizedBox(height: 16),
          _buildHeroSummaryCard(task),
          const SizedBox(height: 16),
          _buildQuickStatsGrid(task),
          const SizedBox(height: 16),
          _buildProgressCard(task),
          const SizedBox(height: 16),
          _buildAssignmentSection(task),
          const SizedBox(height: 16),
          TaskMapViewWidget(task: task),
          const SizedBox(height: 16),
          _buildRouteSection(task),
          const SizedBox(height: 16),
          _buildLastUpdatedFooter(task),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // TAB 2: EXECUTION
  Widget _buildExecutionTab(TaskModel task) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExecutionSection(task),
          const SizedBox(height: 16),
          _buildFieldWorkSection(task),
          const SizedBox(height: 16),
          _buildLastUpdatedFooter(task),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // TAB 3: EVIDENCE
  Widget _buildEvidenceTab(TaskModel task) {
    final mediaList = _getEvidenceMediaList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEvidenceSection(task),
          const SizedBox(height: 16),

          if (mediaList.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderGray, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: TaskMediaGalleryWidget(
                title: 'Evidence Media Grid',
                mediaList: mediaList,
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildLastUpdatedFooter(task),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // TAB 4: ACTIVITY
  Widget _buildActivityTab(TaskModel task) {
    final events = TaskActivityBuilder.buildEvents(task, _executionModel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildApprovalSection(task),
          const SizedBox(height: 16),
          Container(
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
                    Icon(Icons.history_rounded, color: AppColors.primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Activity Log Stream',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TaskActivityTimelineWidget(events: events),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLastUpdatedFooter(task),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(TaskModel task) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.displayName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.taskCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mutedTextGray,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TaskStatusBadge(status: task.status),
              const SizedBox(height: 4),
              _buildApprovalBadge(task.approvalStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(TaskModel task) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.taskType.replaceAll('_', ' '),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.infoBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),

          InkWell(
            onTap: _showLocationBottomSheet,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${task.locationName}, ${task.district} • ${task.circle}, ${task.state}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.mutedTextGray),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Route: ${_getRouteTraversalString()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(TaskModel task) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            title: 'Progress',
            value: '${task.progress.toStringAsFixed(1)}%',
            icon: Icons.pie_chart_outline_rounded,
            accentColor: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Covered / Total',
            value: '${task.completedScope.toStringAsFixed(1)} / ${task.plannedScope.toStringAsFixed(1)} km',
            icon: Icons.straighten_rounded,
            accentColor: AppColors.infoBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Field Pits',
            value: '${_getPitsCount()}',
            icon: Icons.sensors_rounded,
            accentColor: const Color(0xFF8B5CF6),
            onTap: _showPitsModalSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'HDD Shots',
            value: '${_getHddShotsCount()}',
            icon: Icons.alt_route_rounded,
            accentColor: AppColors.warningAmber,
            onTap: _showHddShotsModalSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.mutedTextGray,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(TaskModel task) {
    final progressVal = (task.progress / 100.0).clamp(0.0, 1.0);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scope Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              Text(
                '${task.progress.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: AppColors.softGray,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Covered: ${task.completedScope.toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
              ),
              Text(
                'Total: ${task.plannedScope.toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Level 2 Expandable Card for Execution Summary
  Widget _buildExecutionSection(TaskModel task) {
    final fd = _executionModel?.fieldData;
    final workMode = fd?.workExecutionMode ?? task.executionStatus ?? 'OPEN TRENCHING';
    final currentStep = fd?.currentStep ?? task.stage;

    final summaryWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Work Execution Mode', workMode.replaceAll('_', ' '), ''),
        const Divider(height: 12, color: AppColors.borderGray),
        _buildInfoRow('Current Execution Step', currentStep.replaceAll('_', ' '), ''),
      ],
    );

    final expandedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('GPS Telemetry Verification', _getGpsAvailabilityString(), ''),
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Shot State', fd?.shotInProgress == true ? 'Shot in Progress' : 'Ready / Active', ''),
        if (fd?.trenchingMachineDetails != null) ...[
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow(
            'Machine Details',
            '${fd!.trenchingMachineDetails!.modelName ?? 'JCB 3DX'} (${fd.trenchingMachineDetails!.machineChassisNo ?? '600202608396'})',
            'Vendor: ${fd.trenchingMachineDetails!.ownerVendor ?? task.vendorName}',
          ),
        ],
        if (fd?.operatorDetails != null) ...[
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow(
            'Machine Operator',
            fd!.operatorDetails!.name,
            'Mobile: ${fd.operatorDetails!.mobile ?? 'N/A'}',
          ),
        ],
        if (fd?.locatorPilotDetails != null) ...[
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow(
            'Locator Pilot',
            fd!.locatorPilotDetails!.name,
            'Mobile: ${fd.locatorPilotDetails!.mobile ?? 'N/A'}',
          ),
        ],
      ],
    );

    return _buildExpandableCard(
      title: 'Field Execution',
      icon: Icons.precision_manufacturing_outlined,
      isExpanded: _isExecutionExpanded,
      onToggle: () => setState(() => _isExecutionExpanded = !_isExecutionExpanded),
      summaryChild: summaryWidget,
      expandedChild: expandedWidget,
      actionButtonText: 'View Field Execution Details',
      onActionPressed: _navigateToExecutionDetails,
    );
  }

  // Level 2 Expandable Card for Assignment & Stakeholders
  Widget _buildAssignmentSection(TaskModel task) {
    final summaryWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Assignee', task.assigneeName, '${task.designation} (${task.mobile})'),
      ],
    );

    final expandedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Vendor Firm / Partner', task.vendorName, task.partnerName),
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Supervisor', task.supervisorName, ''),
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Project Manager', task.projectManagerName, ''),
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Created By', task.creatorName, ''),
      ],
    );

    return _buildExpandableCard(
      title: 'Assignment & Stakeholders',
      icon: Icons.badge_outlined,
      isExpanded: _isAssignmentExpanded,
      onToggle: () => setState(() => _isAssignmentExpanded = !_isAssignmentExpanded),
      summaryChild: summaryWidget,
      expandedChild: expandedWidget,
      actionButtonText: 'View Contact Details',
      onActionPressed: _showContactBottomSheet,
    );
  }

  // Level 2 Expandable Card for Approval Chain
  Widget _buildApprovalSection(TaskModel task) {
    final summaryWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Approval Status', task.approvalStatus, ''),
        const SizedBox(height: 4),
        _buildInfoRow('Approver', task.approverName, ''),
      ],
    );

    final expandedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Approver Role', 'Project Supervisor', ''),
        if (task.rejectionReason != null && task.rejectionReason!.isNotEmpty) ...[
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Rejection Reason', task.rejectionReason!, ''),
        ],
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Submitted Date', DateParserUtils.formatDisplay(task.submittedAt ?? task.createdAt), ''),
      ],
    );

    return _buildExpandableCard(
      title: 'Approval Chain',
      icon: Icons.verified_user_outlined,
      isExpanded: _isApprovalExpanded,
      onToggle: () => setState(() => _isApprovalExpanded = !_isApprovalExpanded),
      summaryChild: summaryWidget,
      expandedChild: expandedWidget,
      actionButtonText: 'View Approval History',
      onActionPressed: _showApprovalHistoryModalSheet,
    );
  }

  // Level 2 Expandable Card for Field Work Summary
  Widget _buildFieldWorkSection(TaskModel task) {
    final pits = _getPitsCount();
    final shots = _getHddShotsCount();

    final summaryWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Field Pits & HDD Shots', '$pits Pits • $shots HDD Shots', ''),
      ],
    );

    final expandedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('Hindrance State', _getHindranceStateString(), ''),
        if (_executionModel?.fieldData?.hindranceRemarks != null) ...[
          const SizedBox(height: 4),
          Text(
            'Remarks: ${_executionModel!.fieldData!.hindranceRemarks}',
            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
          ),
        ],
      ],
    );

    return _buildExpandableCard(
      title: 'Field Work Summary',
      icon: Icons.engineering_outlined,
      isExpanded: _isFieldWorkExpanded,
      onToggle: () => setState(() => _isFieldWorkExpanded = !_isFieldWorkExpanded),
      summaryChild: summaryWidget,
      expandedChild: expandedWidget,
      actionButtonText: 'View All Pits',
      onActionPressed: _showPitsModalSheet,
    );
  }

  // Level 2 Expandable Card for Evidence Summary
  Widget _buildEvidenceSection(TaskModel task) {
    final photos = _getPhotoCount();
    final videos = _getVideoCount();

    final summaryWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Attached Media', '$photos Photos • $videos Video Walkthrough', ''),
      ],
    );

    final expandedWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: AppColors.borderGray),
        _buildInfoRow('GPS Telemetry State', _getGpsAvailabilityString(), ''),
      ],
    );

    return _buildExpandableCard(
      title: 'Evidence Summary',
      icon: Icons.photo_library_outlined,
      isExpanded: _isEvidenceExpanded,
      onToggle: () => setState(() => _isEvidenceExpanded = !_isEvidenceExpanded),
      summaryChild: summaryWidget,
      expandedChild: expandedWidget,
      actionButtonText: 'View Evidence',
      onActionPressed: _showEvidenceModalSheet,
    );
  }

  Widget _buildRouteSection(TaskModel task) {
    return _buildExpandableCard(
      title: 'Block Route Hierarchy',
      icon: Icons.alt_route_rounded,
      isExpanded: _isRouteExpanded,
      onToggle: () => setState(() => _isRouteExpanded = !_isRouteExpanded),
      summaryChild: Text(
        'Route: ${_getRouteTraversalString()}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.deepNavy,
        ),
      ),
      expandedChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          TaskRouteHierarchyWidget(
            blockName: task.blockName,
            routes: task.routes,
          ),
        ],
      ),
      actionButtonText: 'View Route Details',
      onActionPressed: () {
        setState(() => _isRouteExpanded = true);
      },
    );
  }

  // Reusable Animated Level 2 Expandable Card
  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget summaryChild,
    required Widget expandedChild,
    String? actionButtonText,
    VoidCallback? onActionPressed,
  }) {
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
          // Header with Expand Toggle
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.mutedTextGray,
                  size: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Level 1 Summary Always Visible
          summaryChild,

          // Level 2 Animated Inline Expansion
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            child: isExpanded ? expandedChild : const SizedBox.shrink(),
          ),

          // Level 3 Specific Meaningful Action Button
          if (actionButtonText != null && onActionPressed != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onActionPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionButtonText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceModalSheet() {
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
              Icon(Icons.photo_library_rounded, color: AppColors.infoBlue, size: 22),
              SizedBox(width: 8),
              Text('Task Evidence & Photos', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Photos Summary', '${_getPhotoCount()} Photos attached', ''),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Video Walkthrough', '${_getVideoCount()} Route Walk Video', ''),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('GPS Telemetry', _getGpsAvailabilityString(), ''),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close Evidence View'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalHistoryModalSheet() {
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
              Icon(Icons.history_rounded, color: AppColors.primaryGreen, size: 22),
              SizedBox(width: 8),
              Text('Approval History & Audit Chain', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Created Date', DateParserUtils.formatDisplay(widget.task.createdAt), 'Created By: ${widget.task.creatorName}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Current Approval Stage', widget.task.approvalStatus, 'Approver: ${widget.task.approverName}'),
          const Divider(height: 16, color: AppColors.borderGray),
          _buildInfoRow('Last Updated', DateParserUtils.formatDisplay(widget.task.updatedAt ?? widget.task.createdAt), ''),
          const SizedBox(height: 20),
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

  Widget _buildLastUpdatedFooter(TaskModel task) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Last Updated: ${DateParserUtils.formatDisplay(task.updatedAt ?? task.createdAt)}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mutedTextGray,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String subValue) {
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
        if (subValue.isNotEmpty)
          Text(
            subValue,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedTextGray,
            ),
          ),
      ],
    );
  }

  Widget _buildApprovalBadge(String status) {
    final appStatus = status.toUpperCase();
    Color bg = AppColors.softGray;
    Color fg = AppColors.deepNavy;

    if (appStatus == 'APPROVED') {
      bg = AppColors.lightGreenBg;
      fg = AppColors.primaryGreen;
    } else if (appStatus == 'REJECTED') {
      bg = AppColors.criticalRed.withValues(alpha: 0.1);
      fg = AppColors.criticalRed;
    } else {
      bg = AppColors.warningAmber.withValues(alpha: 0.12);
      fg = AppColors.warningAmber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        appStatus,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
