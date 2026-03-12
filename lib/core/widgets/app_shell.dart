import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/features/player/mini_player.dart';
import 'package:funkwhale/features/player/player_provider.dart';

/// The main app shell with bottom navigation and persistent mini-player.
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
    (
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      label: 'Search',
    ),
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
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  static const _paths = [
    '/',
    '/browse',
    '/search',
    '/favorites',
    '/playlists',
    '/settings',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _paths.length; i++) {
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
                        onTap: () {
                          if (i != currentIndex) {
                            context.go(_paths[i]);
                          }
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
