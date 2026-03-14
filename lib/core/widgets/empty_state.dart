import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Generic empty-state widget: centered icon, title, subtitle, optional action.
///
/// Covers queue-empty, no-playlists, no-favorites, no-search-results, and
/// empty-playlist states.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional widget displayed below the subtitle (e.g. a create button).
  final Widget? action;

  /// Size of the icon. Defaults to 64.
  final double iconSize;

  /// Font size for the [title] text. Defaults to 16.
  final double titleFontSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconSize = 64,
    this.titleFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
            size: iconSize,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: titleFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: 13,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
