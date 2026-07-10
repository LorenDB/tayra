import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';

// ── Favorites state provider ────────────────────────────────────────────

final favoriteTrackIdsProvider =
    NotifierProvider<FavoriteTrackIdsNotifier, Set<int>>(
      FavoriteTrackIdsNotifier.new,
    );

class FavoriteTrackIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    // When connectivity returns, flush any favorite mutations queued offline.
    ref.listen<OfflineState>(offlineStateProvider, (previous, next) {
      final wasOffline = previous?.isOffline ?? false;
      if (wasOffline && !next.isOffline) {
        unawaited(_syncPending());
      }
    });
    Future.microtask(() => _load());
    return {};
  }

  CachedFunkwhaleApi get _api => ref.read(cachedFunkwhaleApiProvider);

  Future<void> _load() async {
    try {
      // Seed with cached IDs immediately so heart icons appear while loading
      final cached = await _api.getCachedFavoriteTrackIds();
      if (cached.isNotEmpty) state = cached;
      // Then overwrite with fresh data from the network (or keep cache offline)
      final ids = await _api.getAllFavoriteTrackIds();
      state = ids;
      // Best-effort: flush any ops that were pending before this session.
      if (!_api.isOffline) {
        unawaited(_syncPending());
      }
    } catch (_) {}
  }

  Future<void> _syncPending() async {
    try {
      final synced = await _api.syncPendingFavorites();
      if (synced > 0) {
        // Refresh local set from cache (already updated during sync).
        final cached = await _api.getCachedFavoriteTrackIds();
        state = cached;
      }
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
      // Offline / network-failure paths queue the mutation and do not throw,
      // so the optimistic state is kept and synced later.
      Analytics.track('favorite_toggled', {'added': !isFav});
    } catch (_) {
      // Hard failure (e.g. 4xx) — revert and surface the error.
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
