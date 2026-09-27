import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/machine.dart';
import '../../services/api/breakdown_api_service.dart';

/// Machine Card Widget matching the HERO WEB reference design exactly
class MachineCardWidget extends StatelessWidget {
  final Machine machine;
  final VoidCallback? onTap;
  final bool hasOpenIssue;
  final int openCount;
  final MachineOpenIssue? topIssue;
  final AnimationController? blinkController;

  const MachineCardWidget({
    super.key,
    required this.machine,
    this.onTap,
    this.hasOpenIssue = false,
    this.openCount = 0,
    this.topIssue,
    this.blinkController,
  });

  @override
  Widget build(BuildContext context) {
    final modelCode = machine.modelCode ?? (machine.model.isNotEmpty ? machine.model : 'A600');
    final isOnline = machine.isOnline;
    final isCommissioned = machine.isCommissioned == true;
    final fuelCardText = machine.fuelCardText;
    final runtime = machine.displayRuntime;
    final fuelPct = machine.fuelLevelPercent.clamp(0.0, 100.0);

    Widget cardContent = Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP ROW: Model Code Badge + Operational Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dark Green Model Code Badge (A600 / A800)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.headerGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  modelCode,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Operational Status Badge (• Running / • Idle / • Maintenance / • UNDER BREAKDOWN)
              _OperationalStatusBadge(
                machine: machine,
                hasOpenIssue: hasOpenIssue,
                openCount: openCount,
                blinkController: blinkController,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. MODEL NAME, CHASSIS & ONLINE STATUS ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.machineName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chassis: ${machine.chassisNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedTextGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Online / Offline Status Badge
              _OnlineBadge(isOnline: isOnline),
            ],
          ),

          if (hasOpenIssue && topIssue != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${topIssue!.isOem ? 'OEM Breakdown' : 'Ops Stop'} ${topIssue!.ttNumber ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.criticalRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Duration: ${topIssue!.displayDuration}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.criticalRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (topIssue!.reason.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            topIssue!.reason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 3. ATTRIBUTE CHIPS ROW (Commissioned, Operator, Fuel Card)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Commissioned Chip
              _AttributeChip(
                icon: Icons.shield_outlined,
                label: isCommissioned ? 'Commissioned' : 'Uncommissioned',
                textColor: isCommissioned ? AppColors.successGreen : AppColors.mutedTextGray,
                bgColor: (isCommissioned ? AppColors.successGreen : AppColors.mutedTextGray)
                    .withValues(alpha: 0.1),
              ),

              // Operator Chip
              _AttributeChip(
                icon: Icons.person_outline_rounded,
                label: machine.hasOperator ? machine.operatorName : 'Not Assigned',
                textColor: machine.hasOperator ? AppColors.movingBlue : AppColors.mutedTextGray,
                bgColor: (machine.hasOperator ? AppColors.movingBlue : AppColors.mutedTextGray)
                    .withValues(alpha: 0.1),
              ),

              // Fuel Card Chip in Grey
              if (fuelCardText != null)
                _AttributeChip(
                  icon: Icons.credit_card_outlined,
                  label: fuelCardText,
                  textColor: AppColors.mutedTextGray,
                  bgColor: AppColors.softGray,
                ),
            ],
          ),

          const SizedBox(height: 8),

          // 4. LOCATION ROW
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.movingBlue,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  machine.location,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 5. BOTTOM ROW: RUNTIME & FUEL LEVEL INDICATOR
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Runtime Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RUNTIME',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mutedTextGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.mutedTextGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        runtime,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Fuel Level Column & Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text(
                        'FUEL ',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedTextGray,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${fuelPct.toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    height: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: fuelPct / 100,
                        backgroundColor: AppColors.borderGray,
                        color: fuelPct < 30 ? AppColors.warningAmber : AppColors.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (hasOpenIssue && blinkController != null) {
      return AnimatedBuilder(
        animation: blinkController!,
        builder: (context, child) {
          final borderColor = AppColors.criticalRed
              .withValues(alpha: 0.35 + (blinkController!.value * 0.55));
          final bgColor = Color.lerp(
            AppColors.white,
            AppColors.criticalRed.withValues(alpha: 0.08),
            blinkController!.value,
          )!;

          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Opacity(
                opacity: 0.92 + (blinkController!.value * 0.08),
                child: (cardContent as Container).child,
              ),
            ),
          );
        },
      );
    } else if (hasOpenIssue) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.criticalRed.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.6), width: 1.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: (cardContent as Container).child,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: cardContent,
    );
  }
}

class _OperationalStatusBadge extends StatelessWidget {
  final Machine machine;
  final bool hasOpenIssue;
  final int openCount;
  final AnimationController? blinkController;

  const _OperationalStatusBadge({
    required this.machine,
    this.hasOpenIssue = false,
    this.openCount = 0,
    this.blinkController,
  });

  @override
  Widget build(BuildContext context) {
    if (hasOpenIssue) {
      final badgeText = openCount > 1 ? 'UNDER BREAKDOWN ($openCount)' : 'UNDER BREAKDOWN';
      final badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.criticalRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.criticalRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              badgeText,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.criticalRed,
              ),
            ),
          ],
        ),
      );

      if (blinkController != null) {
        return FadeTransition(
          opacity: blinkController!.drive(CurveTween(curve: Curves.easeInOut)),
          child: badgeWidget,
        );
      }
      return badgeWidget;
    }

    Color color = AppColors.successGreen;
    String label = 'Running';

    final statusLower = machine.status.toLowerCase();
    if (statusLower.contains('idle')) {
      color = AppColors.movingBlue;
      label = 'Idle';
    } else if (statusLower.contains('maintenance') || statusLower.contains('breakdown')) {
      color = AppColors.criticalRed;
      label = 'Maintenance';
    } else if (statusLower.contains('offline')) {
      color = AppColors.mutedTextGray;
      label = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final bool isOnline;

  const _OnlineBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.successGreen : AppColors.mutedTextGray;
    final label = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color bgColor;

  const _AttributeChip({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
