import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/core/widgets/offline_banner.dart';
import 'package:tayra/features/player/mini_player.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/player/queue_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/core/widgets/side_panel.dart';

/// The main app shell with adaptive navigation:
/// - Compact (< 600px):  bottom navigation bar + mini-player
/// - Medium/Expanded (>= 600px): side NavigationRail + now-playing panel
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const tabs = [
    (icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Artists',
    ),
    (
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music,
      label: 'Albums',
    ),
    (icon: Icons.radio_outlined, activeIcon: Icons.radio, label: 'Radios'),
    (
      icon: Icons.podcasts_rounded,
      activeIcon: Icons.podcasts_rounded,
      label: 'Podcasts',
    ),
    (
      icon: Icons.queue_music_rounded,
      activeIcon: Icons.queue_music_rounded,
      label: 'Playlists',
    ),
    (
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Favorites',
    ),
  ];

  static const paths = [
    '/',
    '/artists',
    '/browse',
    '/radios',
    '/podcasts',
    '/playlists',
    '/favorites',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 1; i < paths.length; i++) {
      if (location == paths[i] || location.startsWith('${paths[i]}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );
    final queueCompleted = ref.watch(
      playerProvider.select((s) => s.queueCompleted),
    );
    final stashCount =
        ref.watch(stashedQueuesProvider).asData?.value.length ?? 0;
    final useSideNav = Responsive.useSideNavigation(context);
    final pinnedIndices = ref.watch(
      settingsProvider.select((s) => s.mobilePinnedTabIndices),
    );

    // All tab routes are nested under "/" (home) so navigating to a tab via
    // context.go pushes the tab page on top of home rather than replacing it.
    // The system back button pops naturally back to home (with its state
    // preserved), so no PopScope redirect logic is needed.
    if (useSideNav) {
      return _buildDesktopLayout(
        context,
        ref,
        currentIndex,
        hasTrack,
        queueCompleted,
        stashCount,
      );
    }
    return _buildMobileLayout(
      context,
      ref,
      currentIndex,
      hasTrack,
      queueCompleted,
      stashCount,
      pinnedIndices,
    );
  }

  // ── Desktop / tablet layout with NavigationRail ───────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool hasTrack,
    bool queueCompleted,
    int stashCount,
  ) {
    final isExpanded = Responsive.isExpanded(context);
    final showPanel = isExpanded && (hasTrack || stashCount > 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ── Navigation Rail ──
          _DesktopNavRail(
            currentIndex: currentIndex,
            extended: isExpanded,
            onDestinationSelected: (i) {
              // Dismiss popup routes attached to both the shell and root
              // navigators before changing tabs so they don't remain.
              final nested = shellNavigatorKey.currentState;
              if (nested != null) {
                nested.popUntil((route) => route is! PopupRoute);
              }
              try {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).popUntil((route) => route is! PopupRoute);
              } catch (_) {}
              context.go(paths[i]);
            },
          ),

          // ── Divider ──
          const VerticalDivider(
            width: 1,
            thickness: 0.5,
            color: AppTheme.divider,
          ),

          // ── Main content area ──
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [const OfflineStatusBar(), Expanded(child: child)],
              ),
            ),
          ),

          // ── Side panel: now-playing when a track is loaded, or stash inbox ──
          if (showPanel) ...[
            const VerticalDivider(
              width: 1,
              thickness: 0.5,
              color: AppTheme.divider,
            ),
            const SizedBox(width: 340, child: SidePanel()),
          ],
        ],
      ),

      // Show mini-player or stash bar at bottom on medium (tablet) sizes
      bottomNavigationBar:
          !isExpanded && (hasTrack || stashCount > 0)
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((!hasTrack || queueCompleted) && stashCount > 0)
                    _StashAccessBar(stashCount: stashCount),
                  if (hasTrack) const MiniPlayer(),
                ],
              )
              : null,
    );
  }

  // ── Mobile layout with bottom navigation ──────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool hasTrack,
    bool queueCompleted,
    int stashCount,
    Set<int> pinnedIndices,
  ) {
    final primaryIndices = [
      0,
      ...pinnedIndices.where((i) => i >= 1 && i < tabs.length).toList()..sort(),
    ];
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [const OfflineStatusBar(), Expanded(child: child)],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((!hasTrack || queueCompleted) && stashCount > 0)
            _StashAccessBar(stashCount: stashCount),
          if (hasTrack) const MiniPlayer(),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: AppTheme.divider, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children:
                      primaryIndices.map((i) {
                        final isSelected = i == currentIndex;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: tabs[i].label,
                            child: InkWell(
                              onTap: () {
                                final nested = shellNavigatorKey.currentState;
                                if (nested != null) {
                                  nested.popUntil(
                                    (route) => route is! PopupRoute,
                                  );
                                }
                                try {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).popUntil((route) => route is! PopupRoute);
                                } catch (_) {}
                                context.go(paths[i]);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSelected
                                        ? tabs[i].activeIcon
                                        : tabs[i].icon,
                                    color:
                                        isSelected
                                            ? AppTheme.primary
                                            : AppTheme.onBackgroundSubtle,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tabs[i].label,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? AppTheme.primary
                                              : AppTheme.onBackgroundSubtle,
                                      fontSize: 10,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stash Access Bar ────────────────────────────────────────────────────

/// Compact bar shown above the bottom nav on mobile when nothing is playing
/// but there are stashed queues. Tapping it opens the stash sheet.
class _StashAccessBar extends ConsumerWidget {
  final int stashCount;

  const _StashAccessBar({required this.stashCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.surfaceContainer,
      child: InkWell(
        onTap: () => showStashedQueuesSheet(context, ref),
        child: Container(
          height: 48,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.divider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(
                Icons.inbox_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                '$stashCount stashed queue${stashCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.onBackgroundSubtle,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Desktop Navigation Rail ─────────────────────────────────────────────

class _DesktopNavRail extends StatelessWidget {
  final int currentIndex;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;

  const _DesktopNavRail({
    required this.currentIndex,
    required this.extended,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 200 : 64,
      color: AppTheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 8),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Destinations - make this area scrollable so the sidebar doesn't
            // overflow on very short windows (e.g. landscape phones).
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(AppShell.tabs.length, (i) {
                    final tab = AppShell.tabs[i];
                    final isSelected = i == currentIndex;
                    final indicatorColor = AppTheme.primary.withValues(
                      alpha: 0.15,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onDestinationSelected(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: extended ? 12 : 8,
                              vertical: 10,
                            ),
                            decoration:
                                isSelected
                                    ? BoxDecoration(
                                      color: indicatorColor,
                                      borderRadius: BorderRadius.circular(12),
                                    )
                                    : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment:
                                  extended
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? tab.activeIcon : tab.icon,
                                  color:
                                      isSelected
                                          ? AppTheme.primary
                                          : AppTheme.onBackgroundSubtle,
                                  size: 24,
                                ),
                                if (extended) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    tab.label,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? AppTheme.primary
                                              : AppTheme.onBackgroundSubtle,
                                      fontSize: 13,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // trailing search + settings full-width buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => SearchScreen.show(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 12 : 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          extended
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppTheme.onBackgroundSubtle,
                          size: 24,
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Search',
                            style: TextStyle(
                              color: AppTheme.onBackgroundSubtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/settings'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 12 : 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          extended
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: AppTheme.onBackgroundSubtle,
                          size: 24,
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Settings',
                            style: TextStyle(
                              color: AppTheme.onBackgroundSubtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
