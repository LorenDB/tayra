import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/features/player/mini_player.dart';
import 'package:tayra/features/player/player_provider.dart';
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
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Favorites',
    ),
    (
      icon: Icons.queue_music_rounded,
      activeIcon: Icons.queue_music_rounded,
      label: 'Playlists',
    ),
  ];

  static const _paths = ['/', '/browse', '/radios', '/favorites', '/playlists'];
  static const _names = ['home', 'browse', 'radios', 'favorites', 'playlists'];

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
    final useSideNav = Responsive.useSideNavigation(context);

    if (useSideNav) {
      return _buildDesktopLayout(context, ref, currentIndex, hasTrack);
    }
    return _buildMobileLayout(context, ref, currentIndex, hasTrack);
  }

  // ── Desktop / tablet layout with NavigationRail ───────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool hasTrack,
  ) {
    final isExpanded = Responsive.isExpanded(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ── Navigation Rail ──
          _DesktopNavRail(
            currentIndex: currentIndex,
            extended: isExpanded,
            onDestinationSelected: (i) {
              // Navigate by path to avoid relying on named routes.
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
          Expanded(child: child),

          // ── Now Playing side panel (desktop only, when a track is loaded) ──
          if (hasTrack && isExpanded) ...[
            const VerticalDivider(
              width: 1,
              thickness: 0.5,
              color: AppTheme.divider,
            ),
            const SizedBox(width: 340, child: SidePanel()),
          ],
        ],
      ),

      // Show mini-player at bottom on medium (tablet) sizes
      bottomNavigationBar: hasTrack && !isExpanded ? const MiniPlayer() : null,
    );
  }

  // ── Mobile layout with bottom navigation ──────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool hasTrack,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = i == currentIndex;
                    return Expanded(
                      child: InkWell(
                        onTap: () => context.go(_paths[i]),
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
            const SizedBox(height: 16),
            // Header
            extended
                ? Row(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tayra',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
                : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),

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
