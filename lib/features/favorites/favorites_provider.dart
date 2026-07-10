import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';

// ── Favorites state provider ────────────────────────────────────────────

final favoriteTrackIdsProvider =
    NotifierProvider<FavoriteTrackIdsNotifier, Set<int>>(
      FavoriteTrackIdsNotifier.new,
    );

class FavoriteTrackIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    Future.microtask(() => _load());
    return {};
  }

  CachedFunkwhaleApi get _api => ref.read(cachedFunkwhaleApiProvider);

  Future<void> _load() async {
    try {
      // Seed with cached IDs immediately so heart icons appear while loading
      final cached = await _api.getCachedFavoriteTrackIds();
      if (cached.isNotEmpty) state = cached;
      // Then overwrite with fresh data from the network
      final ids = await _api.getAllFavoriteTrackIds();
      state = ids;
    } catch (_) {}
  }

  Future<void> toggle(int trackId) async {
    final isFav = state.contains(trackId);
    // Optimistic update
    if (isFav) {
      state = Set<int>.from(state)..remove(trackId);
    } else {
      state = Set<int>.from(state)..add(trackId);
    }

    try {
      if (isFav) {
        await _api.removeFavorite(trackId);
      } else {
        await _api.addFavorite(trackId);
      }
      try {
        Analytics.track('favorite_toggled', {'added': !isFav});
      } catch (_) {}
    } catch (_) {
      // Revert on error and rethrow so callers can surface an error
      if (isFav) {
        state = Set<int>.from(state)..add(trackId);
      } else {
        state = Set<int>.from(state)..remove(trackId);
      }
      rethrow;
    }
  }

  Future<void> refresh() => _load();
}

// ── Favorite button widget ──────────────────────────────────────────────

class FavoriteButton extends ConsumerWidget {
  final int trackId;
  final double size;

  /// When non-null, skips watching [favoriteTrackIdsProvider] and uses this
  /// value. Favorites screen passes `true` so every row does not register a
  /// provider listener (huge win for long lists).
  final bool? isFavoriteOverride;

  const FavoriteButton({
    super.key,
    required this.trackId,
    this.size = 24,
    this.isFavoriteOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFav;
    final override = isFavoriteOverride;
    if (override != null) {
      isFav = override;
    } else {
      isFav = ref.watch(
        favoriteTrackIdsProvider.select((ids) => ids.contains(trackId)),
      );
    }

    // GestureDetector (not Material/InkWell): splash machinery per list row
    // was a measurable scroll cost on Favorites.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          await ref.read(favoriteTrackIdsProvider.notifier).toggle(trackId);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update favorite')),
            );
          }
        }
      },
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? AppTheme.favorite : AppTheme.onBackgroundMuted,
          size: size,
        ),
      ),
    );
  }
}
