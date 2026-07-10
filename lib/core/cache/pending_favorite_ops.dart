import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A pending favorite mutation that could not be sent to the server
/// (offline or transient network failure) and should be flushed later.
class PendingFavoriteOp {
  final int trackId;

  /// `true` = add favorite, `false` = remove favorite.
  final bool add;
  final int createdAtMs;

  const PendingFavoriteOp({
    required this.trackId,
    required this.add,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => {
    'trackId': trackId,
    'add': add,
    'createdAtMs': createdAtMs,
  };

  factory PendingFavoriteOp.fromJson(Map<String, dynamic> json) {
    return PendingFavoriteOp(
      trackId: (json['trackId'] as num).toInt(),
      add: json['add'] as bool? ?? true,
      createdAtMs:
          (json['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Durable queue of favorite add/remove operations for offline sync.
///
/// Ops are coalesced by [trackId] so only the latest intended state for each
/// track is kept (add then remove cancels out to a single remove, etc.).
class PendingFavoriteOps {
  static const _prefsKey = 'pending_favorite_ops_v1';

  /// Enqueue (or replace) a pending op for [trackId].
  static Future<void> enqueue({required int trackId, required bool add}) async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _load(prefs);
    ops.removeWhere((o) => o.trackId == trackId);
    ops.add(
      PendingFavoriteOp(
        trackId: trackId,
        add: add,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _save(prefs, ops);
  }

  /// All pending ops, oldest first.
  static Future<List<PendingFavoriteOp>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _load(prefs);
    ops.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return ops;
  }

  /// Remove a single track's pending op after a successful server sync.
  static Future<void> remove(int trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _load(prefs);
    ops.removeWhere((o) => o.trackId == trackId);
    await _save(prefs, ops);
  }

  /// Drop all pending ops (e.g. on full logout).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<List<PendingFavoriteOp>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => PendingFavoriteOp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(
    SharedPreferences prefs,
    List<PendingFavoriteOp> ops,
  ) async {
    if (ops.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(
      _prefsKey,
      jsonEncode(ops.map((o) => o.toJson()).toList()),
    );
  }
}
