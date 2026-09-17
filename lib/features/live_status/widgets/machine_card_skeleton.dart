import 'package:flutter/material.dart';
import '../../../shared/widgets/skeleton_loader.dart';

/// Loading skeleton loader card for Machine Grid items
class MachineCardSkeleton extends StatelessWidget {
  const MachineCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 80, height: 14),
              SkeletonBox(width: 60, height: 14),
            ],
          ),
          SizedBox(height: 8),
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 50, height: 20),
              SizedBox(width: 6),
              SkeletonBox(width: 70, height: 20),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 14),
          SizedBox(height: 6),
          SkeletonBox(width: 100, height: 12),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 70, height: 14),
              SkeletonBox(width: 70, height: 14),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 32),
        ],
      ),
    );
  }
}
