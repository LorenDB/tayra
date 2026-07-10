import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Icon + label row used inside [PopupMenuItem] / [showMenu] entries.
///
/// Centralizes the repeated menu-row layout so overflow menus stay consistent
/// across track tiles, album/artist/playlist details, queue, and favorites.
class PopupMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;
  final bool destructive;
  final double iconSize;

  const PopupMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.muted = false,
    this.destructive = false,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive
            ? AppTheme.error
            : muted
            ? AppTheme.onBackgroundMuted
            : AppTheme.onBackground;
    return Row(
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
