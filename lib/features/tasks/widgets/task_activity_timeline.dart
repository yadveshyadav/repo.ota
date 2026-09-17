import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/models/task_execution_model.dart';
import 'package:hero_app/models/task_model.dart';

/// Strongly typed Activity Timeline Event Model
class TaskActivityEvent {
  final DateTime timestamp;
  final String title;
  final String? description;
  final String eventType; // TASK_CREATED, EXECUTION_SUBMITTED, PIT_ACTIVITY, HDD_ACTIVITY, APPROVAL_COMPLETED, TASK_UPDATED
  final String? actorName;
  final bool isDerived;

  const TaskActivityEvent({
    required this.timestamp,
    required this.title,
    this.description,
    required this.eventType,
    this.actorName,
    this.isDerived = true,
  });
}

/// Helper builder deriving real events strictly from API timestamps without inventing fake events
class TaskActivityBuilder {
  static List<TaskActivityEvent> buildEvents(
      TaskModel task, TaskExecutionModel? execution) {
    final List<TaskActivityEvent> events = [];

    // 1. Task Created Event
    if (task.createdAt != null) {
      events.add(
        TaskActivityEvent(
          timestamp: task.createdAt!,
          title: 'Task Created',
          description: 'Task master code ${task.taskCode} created in stage ${task.stage}',
          eventType: 'TASK_CREATED',
          actorName: task.creatorName.isNotEmpty ? task.creatorName : null,
          isDerived: true,
        ),
      );
    }

    // 2. Execution Initialized Event
    if (execution?.createdAt != null) {
      events.add(
        TaskActivityEvent(
          timestamp: execution!.createdAt!,
          title: 'Execution Initialized',
          description:
              'Field execution mode ${execution.fieldData?.workExecutionMode ?? task.executionStatus ?? 'OPEN TRENCHING'} initialized',
          eventType: 'EXECUTION_CREATED',
          actorName: task.assigneeName.isNotEmpty ? task.assigneeName : null,
          isDerived: true,
        ),
      );
    }

    // 3. Field Pits Activity Events
    if (execution?.fieldData?.pitDetails != null) {
      for (final pit in execution!.fieldData!.pitDetails) {
        if (pit.photo?.capturedAt != null) {
          events.add(
            TaskActivityEvent(
              timestamp: pit.photo!.capturedAt!,
              title: '${pit.pitName} Evidence Logged',
              description:
                  'Depth ${pit.depthMeters ?? 1.5} m recorded at ${pit.photo!.formattedLocation}',
              eventType: 'PIT_ACTIVITY',
              actorName: task.assigneeName.isNotEmpty ? task.assigneeName : null,
              isDerived: true,
            ),
          );
        }
      }
    }

    // 4. HDD Shots Activity Events
    if (execution?.fieldData?.hddShot != null) {
      for (final shot in execution!.fieldData!.hddShot) {
        if (shot.photo?.capturedAt != null) {
          events.add(
            TaskActivityEvent(
              timestamp: shot.photo!.capturedAt!,
              title: 'Shot #${shot.shotNumber} Logged',
              description:
                  'Length ${shot.lengthMeters} m, Pipe Dia ${shot.pipeDiameterMm ?? 110} mm',
              eventType: 'HDD_ACTIVITY',
              actorName: task.assigneeName.isNotEmpty ? task.assigneeName : null,
              isDerived: true,
            ),
          );
        }
      }
    }

    // 5. Execution Submitted Event
    final submittedTime = execution?.fieldData?.submittedAt ?? task.submittedAt;
    if (submittedTime != null) {
      events.add(
        TaskActivityEvent(
          timestamp: submittedTime,
          title: 'Execution Submitted',
          description:
              'Current step: ${execution?.fieldData?.currentStep ?? task.stage}',
          eventType: 'EXECUTION_SUBMITTED',
          actorName: task.assigneeName.isNotEmpty ? task.assigneeName : null,
          isDerived: true,
        ),
      );
    }

    // 6. Approvals (from approverSnapshots)
    for (final app in task.approverSnapshots) {
      if (app.actionAt != null) {
        events.add(
          TaskActivityEvent(
            timestamp: app.actionAt!,
            title: 'Approval Step #${app.stepIndex + 1} (${app.status})',
            description: app.rejectionReason != null
                ? 'Reason: ${app.rejectionReason}'
                : 'Role: ${app.role}',
            eventType: app.status == 'APPROVED' ? 'APPROVAL_COMPLETED' : 'APPROVAL_REJECTED',
            actorName: app.name.isNotEmpty ? app.name : null,
            isDerived: true,
          ),
        );
      }
    }

    // 7. Task Completed Event
    if (task.completedAt != null) {
      events.add(
        TaskActivityEvent(
          timestamp: task.completedAt!,
          title: 'Task Completed',
          description: 'Task ${task.taskCode} marked as COMPLETED',
          eventType: 'APPROVAL_COMPLETED',
          actorName: task.approverName.isNotEmpty ? task.approverName : null,
          isDerived: true,
        ),
      );
    } else if (task.updatedAt != null && task.updatedAt != task.createdAt) {
      // 8. Task Updated Event
      events.add(
        TaskActivityEvent(
          timestamp: task.updatedAt!,
          title: 'Task State Synced',
          description: 'Status: ${task.status} • Approval: ${task.approvalStatus}',
          eventType: 'TASK_UPDATED',
          actorName: null,
          isDerived: true,
        ),
      );
    }

    // Reverse chronological order (newest first)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }
}

/// Reusable Task Activity Timeline UI Component
class TaskActivityTimelineWidget extends StatelessWidget {
  final List<TaskActivityEvent> events;

  const TaskActivityTimelineWidget({
    super.key,
    required this.events,
  });

  IconData _getIconForType(String type) {
    switch (type) {
      case 'TASK_CREATED':
        return Icons.add_circle_outline_rounded;
      case 'EXECUTION_CREATED':
        return Icons.precision_manufacturing_outlined;
      case 'EXECUTION_SUBMITTED':
        return Icons.send_rounded;
      case 'PIT_ACTIVITY':
        return Icons.sensors_rounded;
      case 'HDD_ACTIVITY':
        return Icons.alt_route_rounded;
      case 'APPROVAL_COMPLETED':
        return Icons.check_circle_outline_rounded;
      case 'APPROVAL_REJECTED':
        return Icons.cancel_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'TASK_CREATED':
        return AppColors.infoBlue;
      case 'EXECUTION_SUBMITTED':
        return AppColors.headerGreen;
      case 'PIT_ACTIVITY':
        return const Color(0xFF8B5CF6);
      case 'HDD_ACTIVITY':
        return AppColors.warningAmber;
      case 'APPROVAL_COMPLETED':
        return AppColors.primaryGreen;
      case 'APPROVAL_REJECTED':
        return AppColors.criticalRed;
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'No activity timeline events recorded.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;
        final color = _getColorForType(event.eventType);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Dot & Line
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(_getIconForType(event.eventType),
                      size: 12, color: color),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 48,
                    color: AppColors.borderGray,
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Event Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ),
                        Text(
                          DateParserUtils.formatDisplay(event.timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedTextGray,
                          ),
                        ),
                      ],
                    ),
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                    if (event.actorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'By ${event.actorName!}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
