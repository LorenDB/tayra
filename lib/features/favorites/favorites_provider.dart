import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/cached_api_repository.dart';

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

  const FavoriteButton({super.key, required this.trackId, this.size = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteTrackIdsProvider).contains(trackId);

    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? const Color(0xFFFF6B9D) : Colors.white54,
        size: size,
      ),
      onPressed: () async {
        try {
          await ref.read(favoriteTrackIdsProvider.notifier).toggle(trackId);
        } catch (e) {
          // Show user-facing error and let the notifier already reverted state
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update favorite')),
            );
          }
        }
      },
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
    );
  }
}
