import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/task_model.dart';

/// Expandable Block Route Hierarchy Widget for Task Detail Screen
class TaskRouteHierarchyWidget extends StatelessWidget {
  final String blockName;
  final List<TaskRouteModel> routes;

  const TaskRouteHierarchyWidget({
    super.key,
    required this.blockName,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
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
          // Section Title & Parent Block Header
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Block Route Hierarchy',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BLOCK: $blockName',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (routes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No route hierarchy configured for this task.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final route = routes[index];
                return _buildRouteExpansionCard(route);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRouteExpansionCard(TaskRouteModel route) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray, width: 1),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alt_route_rounded,
                color: AppColors.infoBlue, size: 18),
          ),
          title: Row(
            children: [
              Text(
                route.routeCode,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${route.distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${route.segmentsCount} segments',
            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.borderGray),
                  const SizedBox(height: 6),

                  // Start and Target Nodes
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('START NODE',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.mutedTextGray)),
                            const SizedBox(height: 2),
                            Text(
                              route.startNode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.mutedTextGray),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TARGET NODE',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.mutedTextGray)),
                            const SizedBox(height: 2),
                            Text(
                              route.targetNode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (route.segments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Segments',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...route.segments.map((segment) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    segment.segmentCode,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                  Text(
                                    '${segment.startNode} → ${segment.targetNode}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.mutedTextGray,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${segment.distanceKm.toStringAsFixed(2)} km',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
