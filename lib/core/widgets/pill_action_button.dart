import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Shared pill-shaped action button used for Play All / Shuffle / etc.
///
/// Keeps detail screens (album, artist, playlist, favorites, podcasts)
/// visually consistent: 44px height, 22px radius, Inter 14/w600.
///
/// Primary buttons can optionally use [useGradient] for the
/// [AppTheme.primaryGradient] fill (playlist Play All, favorites Shuffle All).
class PillActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  /// Fill / accent color for the solid primary variant.
  /// Defaults to [AppTheme.primary]. Ignored when [useGradient] is true.
  final Color? color;

  /// When true (primary only), fills with [AppTheme.primaryGradient] instead
  /// of a solid [color]. Disabled state uses a muted surface fill.
  final bool useGradient;

  /// Foreground color for the outline variant.
  /// Defaults to [AppTheme.onBackground] when enabled.
  final Color? outlineColor;

  /// Border color for the outline variant. Defaults to [outlineColor], then
  /// [AppTheme.onBackground] when enabled.
  final Color? borderColor;

  /// Optional custom icon widget (e.g. a small loading spinner).
  final Widget? iconWidget;

  /// Icon size. Defaults to 22 for primary, 20 for outline.
  final double? iconSize;

  const PillActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.color,
    this.useGradient = false,
    this.outlineColor,
    this.borderColor,
    this.iconWidget,
    this.iconSize,
  });

  static const double height = 44;
  static const double radius = 22;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final primaryColor = color ?? AppTheme.primary;

    if (isPrimary) {
      final button = ElevatedButton.icon(
        onPressed: onPressed,
        icon: iconWidget ?? Icon(icon, size: iconSize ?? 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: useGradient ? Colors.transparent : primaryColor,
          shadowColor: useGradient ? Colors.transparent : null,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              useGradient
                  ? Colors.transparent
                  : primaryColor.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      if (!useGradient) {
        return SizedBox(height: height, child: button);
      }

      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.primaryGradient : null,
          color: enabled ? null : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: button,
      );
    }

    final fg =
        outlineColor ??
        (enabled
            ? AppTheme.onBackground
            : AppTheme.onBackgroundSubtle.withValues(alpha: 0.4));
    final border =
        borderColor ??
        outlineColor ??
        (enabled
            ? AppTheme.onBackground
            : AppTheme.onBackgroundSubtle.withValues(alpha: 0.3));

    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget ?? Icon(icon, size: iconSize ?? 20, color: fg),
        label: Text(label, style: TextStyle(color: fg)),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: AppTheme.onBackgroundSubtle.withValues(
            alpha: 0.4,
          ),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
