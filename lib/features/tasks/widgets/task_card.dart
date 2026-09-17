import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_parser_utils.dart';
import '../../../models/task_model.dart';
import 'task_status_badge.dart';

/// Modern mobile-first Task Preview Card component adhering to Phase 3 guidelines.
/// Employs progressive disclosure, clear visual hierarchy, fast scanning, and enterprise VehicleIQ styling.
class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onInspect;
  final VoidCallback? onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onInspect,
    this.onComplete,
  });

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Updated recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    if (diff.inDays < 30) return 'Updated ${diff.inDays}d ago';
    return 'Updated ${DateParserUtils.formatDisplay(dt)}';
  }

  String _formatRouteString() {
    if (task.routeSnapshot != null) {
      final start = task.routeSnapshot!.startNode?.name ?? task.routeSnapshot!.routeName;
      final target = task.routeSnapshot!.targetNode?.name;
      if (target != null && target.isNotEmpty) {
        return '$start → $target';
      }
      return start;
    }
    if (task.routes.isNotEmpty) {
      final r = task.routes.first;
      return '${r.startNode} → ${r.targetNode}';
    }
    return '${task.blockName} Line';
  }

  Widget _buildProgressSection(double fallbackProgressVal) {
    final progress = task.calculatedProgress;
    final total = task.calculatedTotalLength;

    if (progress == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${task.completedScope.toStringAsFixed(2)} km covered',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedTextGray,
            ),
          ),
          const Text(
            'Progress unavailable',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedTextGray,
            ),
          ),
        ],
      );
    }

    final val = (progress / 100.0).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${task.completedScope.toStringAsFixed(2)} / ${total!.toStringAsFixed(2)} km',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedTextGray,
              ),
            ),
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 6,
            backgroundColor: AppColors.softGray,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }

  String _formatExecutionMetrics() {
    final mode = task.executionStatus ?? task.taskType.replaceAll('_', ' ');
    final modeClean = mode.replaceAll('_TASK', '').replaceAll('_', ' ');
    final pits = task.pitsCount > 0 ? '${task.pitsCount} Pits' : null;

    final parts = <String>[
      modeClean,
      ?pits,
      '${task.plannedScope.toStringAsFixed(1)} km Scope',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final progressVal = (task.progress / 100.0).clamp(0.0, 1.0);
    final updatedText = _formatRelativeTime(task.updatedAt ?? task.createdAt);

    return InkWell(
      onTap: onInspect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER: Title, Task Code & Status Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.displayName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.headerGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.taskCode,
                          style: const TextStyle(
                            color: AppColors.headerGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Chips
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TaskStatusBadge(status: task.status),
                    const SizedBox(height: 4),
                    _buildApprovalChip(),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 2. TASK TYPE & LOCATION
            Text(
              task.taskType.replaceAll('_', ' '),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.infoBlue,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.mutedTextGray,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${task.locationName}, ${task.district} • ${task.circle}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.deepNavy.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 3. ROUTE TRAVERSAL
            Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  size: 14,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatRouteString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 4. PROGRESS BAR & SCOPE NUMBERS
            _buildProgressSection(progressVal),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderGray),
            const SizedBox(height: 8),

            // 5. KEY FIELD METRICS SUMMARY
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppColors.warningAmber,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatExecutionMetrics(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.deepNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderGray),
            const SizedBox(height: 8),

            // 6. FOOTER: Assignee & Timestamp & Overflow Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppColors.mutedTextGray,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          task.assigneeName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      updatedText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedTextGray,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.mutedTextGray,
                      ),
                      onSelected: (value) {
                        if (value == 'inspect') {
                          onInspect();
                        } else if (value == 'complete' && onComplete != null) {
                          onComplete!();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'inspect',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 16, color: AppColors.primaryGreen),
                              SizedBox(width: 8),
                              Text('Inspect Task 360',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (task.isEligibleForCompletion && onComplete != null)
                          const PopupMenuItem(
                            value: 'complete',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 16, color: AppColors.primaryGreen),
                                SizedBox(width: 8),
                                Text('Mark Completed',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalChip() {
    final status = task.approvalStatus.toUpperCase();
    Color bg = AppColors.softGray;
    Color fg = AppColors.deepNavy;

    if (status == 'APPROVED') {
      bg = AppColors.lightGreenBg;
      fg = AppColors.primaryGreen;
    } else if (status == 'REJECTED') {
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
