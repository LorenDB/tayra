import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/layout/responsive.dart';
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

  static const _tabs = [
    (icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music,
      label: 'Browse',
    ),
    (icon: Icons.radio_outlined, activeIcon: Icons.radio, label: 'Radios'),
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

  static const _paths = ['/', '/browse', '/radios', '/playlists', '/favorites'];
  static const _names = ['home', 'browse', 'radios', 'playlists', 'favorites'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // Check non-root tabs first so that paths like `/album/123` are treated
    // as belonging to the Home tab (index 0).
    for (var i = 1; i < _paths.length; i++) {
      if (location == _paths[i] || location.startsWith('${_paths[i]}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final hasTrack = ref.watch(playerProvider).currentTrack != null;
    final stashCount =
        ref.watch(stashedQueuesProvider).asData?.value.length ?? 0;
    final useSideNav = Responsive.useSideNavigation(context);

    final scaffold =
        useSideNav
            ? _buildDesktopLayout(
              context,
              ref,
              currentIndex,
              hasTrack,
              stashCount,
            )
            : _buildMobileLayout(
              context,
              ref,
              currentIndex,
              hasTrack,
              stashCount,
            );

    // On non-home tabs, block the default back-to-exit behaviour and
    // navigate to Home instead.  PopScope sits above the Scaffold and
    // intercepts the system back gesture / button before the navigator
    // can act on it, regardless of the go_router shell structure.
    if (currentIndex != 0) {
      // Let the nested shell navigator always receive the system back
      // gesture first (so dialogs / sheets can close).  After the nested
      // navigator attempts to pop we'll be notified via `didPop` and can
      // navigate to the Home tab only when nothing was popped.
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            // Ensure any popup routes attached to either the shell navigator
            // or the root navigator are dismissed so they don't remain after
            // we navigate the shell to Home.
            try {
              shellNavigatorKey.currentState?.popUntil(
                (route) => route is! PopupRoute,
              );
            } catch (_) {}
            try {
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route is! PopupRoute);
            } catch (_) {}

            context.go(_paths[0]);
          }
        },
        child: scaffold,
      );
    }
    return scaffold;
  }

  // ── Desktop / tablet layout with NavigationRail ───────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool hasTrack,
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
              if (nested != null)
                nested.popUntil((route) => route is! PopupRoute);
              try {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).popUntil((route) => route is! PopupRoute);
              } catch (_) {}
              context.go(_paths[i]);
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
                  if (hasTrack) const MiniPlayer(),
                  if (!hasTrack && stashCount > 0)
                    _StashAccessBar(stashCount: stashCount),
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
    int stashCount,
  ) {
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
          if (hasTrack) const MiniPlayer(),
          if (!hasTrack && stashCount > 0)
            _StashAccessBar(stashCount: stashCount),
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
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = i == currentIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          final nested = shellNavigatorKey.currentState;
                          if (nested != null)
                            nested.popUntil((route) => route is! PopupRoute);
                          try {
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).popUntil((route) => route is! PopupRoute);
                          } catch (_) {}
                          context.go(_paths[i]);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? _tabs[i].activeIcon : _tabs[i].icon,
                              color:
                                  isSelected
                                      ? AppTheme.primary
                                      : AppTheme.onBackgroundSubtle,
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tabs[i].label,
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
                    );
                  }),
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
                  children: List.generate(AppShell._tabs.length, (i) {
                    final tab = AppShell._tabs[i];
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
