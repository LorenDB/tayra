import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// A centered wrap of read-only tag chips.
///
/// Used in album and artist detail screens to display genre/tag pills.
class TagChipList extends StatelessWidget {
  final List<String> tags;

  const TagChipList({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children:
          tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
    );
  }
}
