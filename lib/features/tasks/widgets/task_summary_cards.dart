import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TaskSummaryCardData {
  final String title;
  final String taskType;
  final int count;
  final IconData icon;
  final Color accentColor;

  const TaskSummaryCardData({
    required this.title,
    required this.taskType,
    required this.count,
    required this.icon,
    required this.accentColor,
  });
}

/// Horizontally scrollable Summary Cards section for mobile Task Management
class TaskSummaryCardsBar extends StatelessWidget {
  final String activeTaskType;
  final Map<String, int> summaryCounts;
  final int totalCount;
  final ValueChanged<String> onSelectTaskType;

  const TaskSummaryCardsBar({
    super.key,
    required this.activeTaskType,
    required this.summaryCounts,
    this.totalCount = 0,
    required this.onSelectTaskType,
  });

  List<TaskSummaryCardData> _getCards() {
    final allCount = summaryCounts['ALL'] ?? (totalCount > 0 ? totalCount : 0);

    return [
      TaskSummaryCardData(
        title: 'All Tasks',
        taskType: 'ALL',
        count: allCount,
        icon: Icons.assignment_rounded,
        accentColor: AppColors.primaryGreen,
      ),
      TaskSummaryCardData(
        title: 'GP Survey',
        taskType: 'GP_SURVEY',
        count: summaryCounts['GP_SURVEY'] ?? 0,
        icon: Icons.explore_outlined,
        accentColor: AppColors.infoBlue,
      ),
      TaskSummaryCardData(
        title: 'OTDR Survey',
        taskType: 'OTDR_SURVEY',
        count: summaryCounts['OTDR_SURVEY'] ?? 0,
        icon: Icons.sensors_rounded,
        accentColor: const Color(0xFF8B5CF6),
      ),
      TaskSummaryCardData(
        title: 'Fiber Survey',
        taskType: 'FIBER_SURVEY',
        count: summaryCounts['FIBER_SURVEY'] ?? 0,
        icon: Icons.hub_outlined,
        accentColor: AppColors.warningAmber,
      ),
      TaskSummaryCardData(
        title: 'Trenching / Ducting',
        taskType: 'FIBER_TRENCHING_DUCTING_TASK',
        count: summaryCounts['FIBER_TRENCHING_DUCTING_TASK'] ?? 0,
        icon: Icons.alt_route_rounded,
        accentColor: const Color(0xFFEC4899),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _getCards();

    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = activeTaskType == card.taskType;

          return InkWell(
            onTap: () => onSelectTaskType(card.taskType),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 155,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? card.accentColor.withValues(alpha: 0.08)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? card.accentColor : AppColors.borderGray,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: card.accentColor.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: card.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(card.icon, size: 20, color: card.accentColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? card.accentColor : AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${card.count}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? card.accentColor : AppColors.deepNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
