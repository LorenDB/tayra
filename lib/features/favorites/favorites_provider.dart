import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funkwhale/core/api/cached_api_repository.dart';

// ── Favorites state provider ────────────────────────────────────────────

final favoriteTrackIdsProvider =
    StateNotifierProvider<FavoriteTrackIdsNotifier, Set<int>>((ref) {
      return FavoriteTrackIdsNotifier(ref);
    });

class FavoriteTrackIdsNotifier extends StateNotifier<Set<int>> {
  final Ref _ref;

  FavoriteTrackIdsNotifier(this._ref) : super({}) {
    _load();
  }

  CachedFunkwhaleApi get _api => _ref.read(cachedFunkwhaleApiProvider);

  Future<void> _load() async {
    try {
      final ids = await _api.getAllFavoriteTrackIds();
      if (mounted) state = ids;
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
      // Revert on error
      if (isFav) {
        state = Set<int>.from(state)..add(trackId);
      } else {
        state = Set<int>.from(state)..remove(trackId);
      }
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
      onPressed: () {
        ref.read(favoriteTrackIdsProvider.notifier).toggle(trackId);
      },
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
    );
  }
}
