import 'package:flutter/material.dart';

import 'shimmer.dart';

/// Generic card-list skeleton: [count] rows of title + subtitle + trailing pill.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4, this.rowHeight = 84});

  final int count;
  final double rowHeight;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Card(
        child: SizedBox(
          height: rowHeight,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Bone(width: 170, height: 16),
                      SizedBox(height: 8),
                      Bone(width: 120, height: 12),
                    ],
                  ),
                ),
                Bone(width: 72, height: 26, radius: 13),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
