import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Shimmering loading placeholder for lists.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool showCircular;

  const ShimmerList({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 64,
    this.showCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceContainerHigh,
      highlightColor: AppTheme.surfaceContainerHighest,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder:
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: itemHeight - 8,
                    height: itemHeight - 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        showCircular ? (itemHeight - 8) / 2 : 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// Shimmering loading placeholder for horizontal grids.
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final double itemSize;

  const ShimmerGrid({super.key, this.itemCount = 6, this.itemSize = 150});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceContainerHigh,
      highlightColor: AppTheme.surfaceContainerHighest,
      child: SizedBox(
        height: itemSize + 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itemCount,
          itemBuilder:
              (context, index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: itemSize,
                      height: itemSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: itemSize * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: itemSize * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
