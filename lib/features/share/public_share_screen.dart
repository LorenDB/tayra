import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/pill_action_button.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/features/player/mini_player.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/share/share_session_provider.dart';

// ── Providers ───────────────────────────────────────────────────────────

final _publicShareProvider = FutureProvider.family<PublicShare, String>((
  ref,
  token,
) async {
  final api = ref.watch(funkwhaleApiProvider);
  return api.getPublicShare(token);
});

// ── Screen ──────────────────────────────────────────────────────────────

/// Visitor-only page for a secret album/playlist share link.
///
/// Outside the app shell: no browse, search, favorites, or library nav.
class PublicShareScreen extends ConsumerStatefulWidget {
  final String token;

  const PublicShareScreen({super.key, required this.token});

  @override
  ConsumerState<PublicShareScreen> createState() => _PublicShareScreenState();
}

class _PublicShareScreenState extends ConsumerState<PublicShareScreen> {
  bool _trackedOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shareSessionTokenProvider.notifier).setToken(widget.token);
    });
  }

  @override
  void deactivate() {
    // Clear share session when navigating away so streams stop using ?share=.
    final current = ref.read(shareSessionTokenProvider);
    if (current == widget.token) {
      ref.read(shareSessionTokenProvider.notifier).clear();
    }
    super.deactivate();
  }

  Future<void> _playAll(PublicShare share, {int startIndex = 0}) async {
    final playable = share.tracks.where((t) => t.listenUrl != null).toList();
    if (playable.isEmpty) return;
    final safe = startIndex.clamp(0, playable.length - 1);
    await ref
        .read(playerProvider.notifier)
        .playTracks(
          playable,
          startIndex: safe,
          source: 'share_${share.objectType}',
        );
    Analytics.track('share_link_play', {'object_type': share.objectType});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_publicShareProvider(widget.token));
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );
    final isAuth = ref.watch(
      authStateProvider.select((s) => s.isAuthenticated),
    );
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => InlineErrorState(
              message: 'This share link is invalid or has expired.',
              onRetry: () => ref.invalidate(_publicShareProvider(widget.token)),
            ),
        data: (share) {
          if (!_trackedOpen) {
            _trackedOpen = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Analytics.track('share_link_opened', {
                'object_type': share.objectType,
              });
            });
          }

          final coverUrl = share.coverUrl;
          final playable =
              share.tracks.where((t) => t.listenUrl != null).toList();

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          topPadding + 16,
                          20,
                          8,
                        ),
                        child: Column(
                          children: [
                            CoverArtWidget(
                              imageUrl: coverUrl,
                              size: 200,
                              borderRadius: 12,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              share.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.onBackground,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (share.subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                share.subtitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.onBackgroundMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              share.objectType == 'playlist'
                                  ? 'Shared playlist · listen only'
                                  : 'Shared album · listen only',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (playable.isNotEmpty)
                              PillActionButton(
                                icon: Icons.play_arrow_rounded,
                                label: 'Play all',
                                onPressed: () => _playAll(share),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (share.tracks.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No tracks available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.onBackgroundMuted),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final track = share.tracks[index];
                          final playableIndex = playable.indexWhere(
                            (t) => t.id == track.id,
                          );
                          return TrackListTile(
                            track: track,
                            showAlbumArt: share.objectType == 'playlist',
                            showTrackNumber: share.objectType == 'album',
                            onTap:
                                playableIndex >= 0
                                    ? () => _playAll(
                                      share,
                                      startIndex: playableIndex,
                                    )
                                    : null,
                          );
                        }, childCount: share.tracks.length),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                        child: Column(
                          children: [
                            const Text(
                              'You can only listen to this shared item. '
                              'Sign in for full library access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            if (!isAuth) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text('Sign in'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasTrack) const MiniPlayer(),
            ],
          );
        },
      ),
    );
  }
}
