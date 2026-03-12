import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities for adaptive layouts.
///
/// - Compact:  < 600px  (phones)
/// - Medium:   600–1023px (tablets, small windows)
/// - Expanded: >= 1024px (desktops, large tablets)
class Responsive {
  Responsive._();

  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 1024;
  static const double wideBreakpoint = 1440;

  /// Whether the current width qualifies as compact (phone).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  /// Whether the current width qualifies as medium (tablet).
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactBreakpoint && width < expandedBreakpoint;
  }

  /// Whether the current width qualifies as expanded (desktop).
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expandedBreakpoint;

  /// Whether the current width qualifies as wide desktop.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  /// Whether to use a side navigation (NavigationRail) instead of bottom nav.
  static bool useSideNavigation(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= compactBreakpoint;

  /// Calculate responsive grid column count for album/artist grids.
  static int gridColumnCount(
    BuildContext context, {
    double minItemWidth = 150,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    // Subtract padding and nav rail width for wider layouts
    final availableWidth = useSideNavigation(context) ? width - 80 : width;
    final columns = (availableWidth / minItemWidth).floor();
    return columns.clamp(2, 8);
  }

  /// Maximum content width for readability on very wide screens.
  static const double maxContentWidth = 1200;
}

/// A widget that builds different layouts based on the window width.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) compact;
  final Widget Function(BuildContext context)? medium;
  final Widget Function(BuildContext context)? expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isExpanded(context) && expanded != null) {
      return expanded!(context);
    }
    if (Responsive.isMedium(context) && medium != null) {
      return medium!(context);
    }
    return compact(context);
  }
}
