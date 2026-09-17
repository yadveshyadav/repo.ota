import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/models/dashboard_summary.dart';
import 'package:hero_app/screens/dashboard/controllers/machine_dashboard_controller.dart';
import 'package:hero_app/shared/widgets/live_status_pulse.dart';

/// Single Row of 4 Top Dashboard Cards:
/// 1. Machines (Flipping Card showing Machine Totals on Front & Shot In Progress against Machine on Back)
/// 2. Attendance (Combined Member Attendance & Machine Attendance stats)
/// 3. Breakdown (Breakdown machines / pending issues count)
/// 4. Alerts (Real-time active alerts count)
class SummaryCardsRow extends StatelessWidget {
  final DashboardSummary summary;
  final MachineDashboardState? machineState;
  final int? alertsCount;
  final bool isMobile;
  final ValueChanged<String>? onCardTap;

  const SummaryCardsRow({
    super.key,
    required this.summary,
    this.machineState,
    this.alertsCount,
    this.isMobile = false,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileLayout = isMobile || constraints.maxWidth <= 900;
        final spacing = useMobileLayout ? 6.0 : 12.0;

        final isLoaded = machineState != null && !machineState!.isLoading;

        final totalCount = isLoaded
            ? machineState!.totalMachines
            : summary.totalMachines;

        final onlineCount = isLoaded
            ? machineState!.runningMachines
            : summary.onlineMachines;

        final offlineCount = isLoaded
            ? (machineState!.offlineMachines + machineState!.idleMachines)
            : summary.offlineMachines;

        final maintenanceCount = isLoaded
            ? machineState!.maintenanceMachines
            : summary.maintenanceMachines;

        // Member / Team Attendance stats (Present / Total)
        final memberPresent = summary.quickStats?['member_present'] as int? ??
            summary.quickStats?['present_members'] as int? ??
            summary.quickStats?['team_present'] as int? ??
            12;
        final memberTotal = summary.quickStats?['total_members'] as int? ??
            summary.quickStats?['team_total'] as int? ??
            15;

        // Machine Attendance stats (Present / Total)
        final machinePresent = summary.quickStats?['machine_present'] as int? ??
            summary.quickStats?['present_machines'] as int? ??
            summary.quickStats?['machine_attendance'] as int? ??
            onlineCount;
        final machineTotal = summary.quickStats?['total_machines'] as int? ??
            totalCount;

        // Breakdown count
        final breakdownCount = summary.quickStats?['breakdown_count'] ??
            summary.quickStats?['breakdowns'] ??
            maintenanceCount;

        // Active alerts count
        final alertsVal = alertsCount?.toString() ??
            summary.quickStats?['alerts_count']?.toString() ??
            '12';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card 1: Combined Machine Status with 3D Flip to Shot in Progress
              Expanded(
                child: _FlippingMachineTopCard(
                  total: totalCount,
                  online: onlineCount,
                  offline: offlineCount,
                  maintenance: maintenanceCount,
                  isCompact: useMobileLayout,
                  quickStats: summary.quickStats,
                  machineStatusWidget: summary.machineStatusWidget,
                  onTap: (filter) => onCardTap?.call(filter),
                ),
              ),
              SizedBox(width: spacing),

              // Card 2: Attendance (Member Attendance & Machine Attendance)
              Expanded(
                child: _AttendanceCombinedCard(
                  memberPresent: memberPresent,
                  memberTotal: memberTotal,
                  machinePresent: machinePresent,
                  machineTotal: machineTotal,
                  isCompact: useMobileLayout,
                  onTap: () => onCardTap?.call('Attendance'),
                ),
              ),
              SizedBox(width: spacing),

              // Card 3: Breakdown
              Expanded(
                child: _SingleKpiCard(
                  title: 'BREAKDOWN',
                  value: '$breakdownCount',
                  subtitle: 'Breakdown',
                  icon: Icons.handyman_outlined,
                  iconBgColor: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  isCompact: useMobileLayout,
                  onTap: () => onCardTap?.call('Breakdown'),
                ),
              ),
              SizedBox(width: spacing),

              // Card 4: Alerts
              Expanded(
                child: _SingleKpiCard(
                  title: 'ALERTS',
                  value: alertsVal,
                  subtitle: 'Alert',
                  icon: Icons.notifications_none_rounded,
                  iconBgColor: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  isLive: true,
                  isCompact: useMobileLayout,
                  onTap: () => onCardTap?.call('Alerts'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Flipping Top Card 1: Shows Machine Totals (Front) & Shot In Progress against Machine (Back)
class _FlippingMachineTopCard extends StatefulWidget {
  final int total;
  final int online;
  final int offline;
  final int maintenance;
  final bool isCompact;
  final ValueChanged<String>? onTap;
  final Map<String, dynamic>? quickStats;
  final Map<String, dynamic>? machineStatusWidget;

  const _FlippingMachineTopCard({
    required this.total,
    required this.online,
    required this.offline,
    required this.maintenance,
    this.isCompact = false,
    this.onTap,
    this.quickStats,
    this.machineStatusWidget,
  });

  @override
  State<_FlippingMachineTopCard> createState() => _FlippingMachineTopCardState();
}

class _FlippingMachineTopCardState extends State<_FlippingMachineTopCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _timer;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = Tween<double>(begin: 0.0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Auto flip every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _toggleFlip();
    });
  }

  void _toggleFlip() {
    if (!mounted) return;
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Front Face: Machine Total Stats Card
    final frontCard = _MachineCombinedCard(
      total: widget.total,
      online: widget.online,
      offline: widget.offline,
      maintenance: widget.maintenance,
      isCompact: widget.isCompact,
      onTap: widget.onTap,
    );

    // Dynamic Shot in Progress parsing against machine
    final shotData = widget.machineStatusWidget?['shot_details'] as Map<String, dynamic>?;
    final String? taskName = shotData?['task_name']?.toString() ??
        widget.machineStatusWidget?['task_name']?.toString() ??
        widget.machineStatusWidget?['shot_task_name']?.toString();

    final String? shotNo = shotData?['shot_number']?.toString() ??
        widget.machineStatusWidget?['shot_number']?.toString() ??
        (shotData?['number'] != null ? 'Shot #${shotData!['number']}' : null);

    final String? shotLength = shotData?['length']?.toString() ??
        widget.machineStatusWidget?['shot_length']?.toString();

    final bool isShotInProgress = (widget.machineStatusWidget?['shot_in_progress'] as bool? ?? false) ||
        (widget.machineStatusWidget?['has_shot'] as bool? ?? false) ||
        (shotData != null && taskName != null && taskName.isNotEmpty);

    final activeShotsCount = isShotInProgress ? 1 : 0;

    // Back Face: Shot In Progress against Machine
    final backCard = Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isShotInProgress ? AppColors.warningAmber : AppColors.borderGray,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => widget.onTap?.call('My Tasks'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 4 : 8,
            vertical: widget.isCompact ? 6 : 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Row: Icon & Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(widget.isCompact ? 3 : 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7), // Amber tint
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sensors_rounded,
                      color: const Color(0xFFD97706),
                      size: widget.isCompact ? 13 : 15,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'SHOT IN PROGRESS',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 7.5 : 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedTextGray,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Badges for Active Shot info against machine
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCompact ? 2 : 4,
                      vertical: widget.isCompact ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: isShotInProgress
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isShotInProgress ? (taskName ?? 'Active Shot') : 'Shot Status',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 8 : 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedTextGray,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isShotInProgress ? (shotNo ?? 'In Progress') : 'No Shot',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 8 : 9,
                              fontWeight: FontWeight.w800,
                              color: isShotInProgress
                                  ? const Color(0xFFD97706)
                                  : AppColors.mutedTextGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCompact ? 2 : 4,
                      vertical: widget.isCompact ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: isShotInProgress
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Active Shots',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 8 : 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedTextGray,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isShotInProgress
                                ? '$activeShotsCount Active (${shotLength ?? '0m'})'
                                : '0 Active',
                            style: TextStyle(
                              fontSize: widget.isCompact ? 8 : 9,
                              fontWeight: FontWeight.w800,
                              color: isShotInProgress
                                  ? AppColors.successGreen
                                  : AppColors.mutedTextGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value;
        final isFrontVisible = angle < (pi / 2);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFrontVisible
              ? frontCard
              : Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: backCard,
                ),
        );
      },
    );
  }
}

class _AttendanceCombinedCard extends StatelessWidget {
  final int memberPresent;
  final int memberTotal;
  final int machinePresent;
  final int machineTotal;
  final bool isCompact;
  final VoidCallback? onTap;

  const _AttendanceCombinedCard({
    required this.memberPresent,
    required this.memberTotal,
    required this.machinePresent,
    required this.machineTotal,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Row: Icon, Label & Live Pulse
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 3 : 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people_outline_rounded,
                      color: const Color(0xFF2563EB),
                      size: isCompact ? 13 : 15,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            'ATTENDANCE',
                            style: TextStyle(
                              fontSize: isCompact ? 7.5 : 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedTextGray,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const LiveStatusPulse(
                          label: '',
                          color: AppColors.successGreen,
                          isCompact: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Badges for Member & Machine Attendance
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Member Attendance Badge
                  _buildAttendanceBadge(
                    label: 'Member',
                    present: memberPresent,
                    total: memberTotal,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    isCompact: isCompact,
                  ),
                  const SizedBox(height: 2),
                  // Machine Attendance Badge
                  _buildAttendanceBadge(
                    label: 'Machine',
                    present: machinePresent,
                    total: machineTotal,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    isCompact: isCompact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceBadge({
    required String label,
    required int present,
    required int total,
    required Color color,
    required Color bgColor,
    required bool isCompact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 2 : 4,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 8 : 9,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedTextGray,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$present/$total',
              style: TextStyle(
                fontSize: isCompact ? 8.5 : 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineCombinedCard extends StatelessWidget {
  final int total;
  final int online;
  final int offline;
  final int maintenance;
  final bool isCompact;
  final ValueChanged<String>? onTap;

  const _MachineCombinedCard({
    required this.total,
    required this.online,
    required this.offline,
    required this.maintenance,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: () => onTap?.call('All'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Row: Icon & Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 3 : 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.precision_manufacturing_outlined,
                      color: const Color(0xFF059669),
                      size: isCompact ? 13 : 15,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'MACHINES',
                      style: TextStyle(
                        fontSize: isCompact ? 8 : 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedTextGray,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 2x2 Grid of Status Badges
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildBadge(
                          label: 'Tot',
                          value: '$total',
                          color: AppColors.deepNavy,
                          isCompact: isCompact,
                          onTap: () => onTap?.call('All'),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: _buildBadge(
                          label: 'On',
                          value: '$online',
                          color: AppColors.successGreen,
                          dotColor: AppColors.successGreen,
                          isCompact: isCompact,
                          onTap: () => onTap?.call('Online'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBadge(
                          label: 'Off',
                          value: '$offline',
                          color: AppColors.mutedTextGray,
                          dotColor: AppColors.mutedTextGray,
                          isCompact: isCompact,
                          onTap: () => onTap?.call('Offline'),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: _buildBadge(
                          label: 'Maint',
                          value: '$maintenance',
                          color: maintenance > 0
                              ? AppColors.warningAmber
                              : AppColors.mutedTextGray,
                          dotColor: maintenance > 0
                              ? AppColors.warningAmber
                              : Colors.transparent,
                          isCompact: isCompact,
                          onTap: () => onTap?.call('Maintenance'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required String value,
    required Color color,
    Color? dotColor,
    required bool isCompact,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 1 : 3,
          vertical: isCompact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null && dotColor != Colors.transparent) ...[
              Container(
                width: isCompact ? 4 : 5,
                height: isCompact ? 4 : 5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$label:$value',
                  style: TextStyle(
                    fontSize: isCompact ? 8 : 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final bool isLive;
  final bool isCompact;
  final VoidCallback? onTap;

  const _SingleKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.isLive = false,
    this.isCompact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Header
              Container(
                padding: EdgeInsets.all(isCompact ? 4 : 5),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: isCompact ? 13 : 15),
              ),
              SizedBox(height: isCompact ? 3 : 4),

              // Main Number / Percentage
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 1 : 2),

              // Subtitle & Live Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isCompact ? 8 : 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedTextGray,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(width: 3),
                    const LiveStatusPulse(
                      label: '',
                      color: AppColors.successGreen,
                      isCompact: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
