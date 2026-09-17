import 'package:flutter/material.dart';
import '../../../shared/widgets/skeleton_loader.dart';

/// Skeleton loader widget matching Vendor Card dimensions
class VendorCardSkeleton extends StatelessWidget {
  const VendorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 70, height: 16),
              SkeletonBox(width: 50, height: 14),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: 180, height: 20),
          SizedBox(height: 14),
          SkeletonBox(width: 140, height: 14),
          SizedBox(height: 6),
          SkeletonBox(width: 160, height: 14),
          SizedBox(height: 6),
          SkeletonBox(width: 120, height: 14),
          Spacer(),
          Divider(height: 1, color: Color(0xFFE2E8F0)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 100, height: 14),
              SkeletonBox(width: 80, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}
