import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/features/tasks/controller/task_controller.dart';
import 'package:hero_app/features/tasks/screens/task_detail_screen.dart';
import 'package:hero_app/models/task_model.dart';

import 'package:hero_app/repositories/task_repository.dart';
import 'package:hero_app/services/authorization_service.dart';

/// Dynamic "My Task (Today)" section driven by Task Repository API & Assignment Permissions
class MyTasksCard extends StatefulWidget {
  final TaskRepository? repository;

  const MyTasksCard({
    super.key,
    this.repository,
  });

  @override
  State<MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends State<MyTasksCard> {
  late final TaskController _taskController;
  String _selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    _taskController = TaskController(
      repository: widget.repository ?? ApiTaskRepository(),
    );
    _taskController.addListener(_onTasksChanged);
    _taskController.fetchTasks(page: 0);
  }

  void _onTasksChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _taskController.removeListener(_onTasksChanged);
    _taskController.dispose();
    super.dispose();
  }

  List<TaskModel> get _assignedTasks {
    final user = AuthStorageService().currentUser;
    final bool isAdmin = user == null ||
        user.isAdmin ||
        user.role.toUpperCase().contains('ADMIN') ||
        AuthorizationService.instance.can('tasks.manage');

    final allTasks = _taskController.tasks;

    if (isAdmin) {
      return allTasks;
    }

    // Filter assigned tasks for non-admin user
    final name = (user.displayName.isNotEmpty ? user.displayName : user.username).toLowerCase();
    final empId = (user.employeeId ?? '').toLowerCase();

    final assigned = allTasks.where((task) {
      final ass = task.assigneeName.toLowerCase();
      final sup = task.supervisorName.toLowerCase();
      final pm = task.projectManagerName.toLowerCase();

      return ass.contains(name) ||
          sup.contains(name) ||
          pm.contains(name) ||
          (empId.isNotEmpty && (ass.contains(empId) || sup.contains(empId)));
    }).toList();

    return assigned.isNotEmpty ? assigned : allTasks;
  }

  List<TaskModel> get _displayedTasks {
    final list = _assignedTasks;

    if (_selectedTab == 'All') return list;

    if (_selectedTab == 'Survey') {
      return list.where((t) => t.taskType.contains('SURVEY')).toList();
    }

    if (_selectedTab == 'Trenching') {
      return list.where((t) => t.taskType.contains('TRENCHING')).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _taskController.isLoading;
    final tasksList = _displayedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Text(
                  'My Task ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                Text(
                  '(Today)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedTextGray,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.tasks);
              },
              child: const Text(
                'View All Tasks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Container(
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
            children: [
              // Filter Tabs
              Row(
                children: ['All', 'Survey', 'Trenching'].map((tab) {
                  final isSelected = tab == _selectedTab;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? const Border(
                                  bottom: BorderSide(
                                      color: AppColors.infoBlue, width: 2),
                                )
                              : null,
                        ),
                        child: Text(
                          tab,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.infoBlue
                                : AppColors.mutedTextGray,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),

              // Table Headers
              Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text('Task Name / Type',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedTextGray)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('Progress',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedTextGray)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Status / Date',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedTextGray)),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Dynamic Task List Area
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (tasksList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 32,
                        color: AppColors.mutedTextGray,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'No tasks assigned for today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasksList.length > 4 ? 4 : tasksList.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 16, color: AppColors.borderGray),
                  itemBuilder: (context, index) {
                    final task = tasksList[index];
                    return _buildDynamicTaskItem(task);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicTaskItem(TaskModel task) {
    IconData icon = Icons.hub_outlined;
    Color iconColor = AppColors.infoBlue;
    Color iconBgColor = const Color(0xFFDBEAFE);

    if (task.taskType.contains('TRENCHING')) {
      icon = Icons.alt_route_rounded;
      iconColor = const Color(0xFFEC4899);
      iconBgColor = const Color(0xFFFCE7F3);
    } else if (task.taskType.contains('GP')) {
      icon = Icons.explore_outlined;
      iconColor = AppColors.primaryGreen;
      iconBgColor = const Color(0xFFD1FAE5);
    } else if (task.taskType.contains('OTDR')) {
      icon = Icons.sensors_rounded;
      iconColor = const Color(0xFF8B5CF6);
      iconBgColor = const Color(0xFFEDE9FE);
    }

    final double progressVal = (task.progress / 100.0).clamp(0.0, 1.0);
    final String scopeText = task.plannedScope > 0
        ? '${task.completedScope.toStringAsFixed(1)} / ${task.plannedScope.toStringAsFixed(1)} km'
        : 'Scope: 100%';

    final String formattedDate = DateParserUtils.formatDisplay(task.createdAt);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: task),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Task Type & Name
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          task.taskCode,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.mutedTextGray,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scopeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 5,
                            backgroundColor: AppColors.softGray,
                            color: task.isApproved
                                ? AppColors.successGreen
                                : iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${task.progress.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedTextGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Date / Details Action
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          task.status.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: task.isApproved
                                ? AppColors.primaryGreen
                                : AppColors.warningAmber,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.mutedTextGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: AppColors.mutedTextGray,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's Performance & Shift Card widgets matching bottom of reference mockup
class PerformanceAndShiftRow extends StatelessWidget {
  const PerformanceAndShiftRow({super.key});

  @override
  Widget build(BuildContext context) {
    final performanceCard = Container(
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
          const Text("Today's Performance",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Achievement',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.mutedTextGray)),
                  SizedBox(height: 2),
                  Text('640m',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('Target',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.mutedTextGray)),
                  SizedBox(height: 2),
                  Text('1,000m',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
              value: 0.64,
              minHeight: 5,
              backgroundColor: AppColors.softGray,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('64% achieved',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mutedTextGray)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "You're on track! Keep it up.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
    );

    final shiftCard = Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Shift',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Present',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildShiftRow('Check-in', '08:42 AM'),
          const SizedBox(height: 4),
          _buildShiftRow('Working Duration', '5h 28m'),
          const SizedBox(height: 4),
          _buildShiftRow('Shift Time', '08:00AM - 06:00 PM'),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.attendance);
            },
            child: Row(
              children: const [
                Text('View Attendance',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: AppColors.primaryGreen),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              performanceCard,
              const SizedBox(height: 12),
              shiftCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: performanceCard),
            const SizedBox(width: 8),
            Expanded(child: shiftCard),
          ],
        );
      },
    );
  }

  Widget _buildShiftRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: AppColors.mutedTextGray)),
        Text(value,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy)),
      ],
    );
  }
}
