import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/download_queue_service.dart';

/// Toggle manual-download for a parent collection (album or playlist) and all
/// of its tracks. When enabling, enqueues [enqueueTrackIds] for background
/// download.
///
/// Returns the new manual state (`true` if now marked for download).
///
/// Callers handle snackbars / analytics so UI copy stays in the feature layer.
Future<bool> toggleCollectionManualDownload({
  required WidgetRef ref,
  required CacheType parentType,
  required int parentId,
  required List<int> trackIds,
  required List<int> enqueueTrackIds,
  required bool currentlyManual,
}) async {
  if (parentType != CacheType.album && parentType != CacheType.playlist) {
    throw ArgumentError.value(
      parentType,
      'parentType',
      'Only album and playlist collections are supported',
    );
  }

  final mgr = ref.read(cacheManagerProvider);
  final enable = !currentlyManual;

  await mgr.setManualDownloaded(parentType, parentId, enable);

  for (final id in trackIds) {
    try {
      await mgr.setManualDownloaded(CacheType.track, id, enable);
    } catch (_) {}
  }

  final parentNotifier = _parentManualNotifier(ref, parentType);
  if (enable) {
    parentNotifier.add(parentId);
    ref.read(manualTrackIdsProvider.notifier).addAll(trackIds);
  } else {
    parentNotifier.remove(parentId);
    ref.read(manualTrackIdsProvider.notifier).removeAll(trackIds);
  }

  await mgr.bulkSetFilesProtectedForParent(parentType, parentId, enable);

  if (enable && enqueueTrackIds.isNotEmpty) {
    final queue = ref.read(downloadQueueServiceProvider);
    unawaited(queue.enqueue(enqueueTrackIds, ref));
  }

  return enable;
}

IntIdSetNotifier _parentManualNotifier(WidgetRef ref, CacheType parentType) {
  return switch (parentType) {
    CacheType.album => ref.read(manualAlbumIdsProvider.notifier),
    CacheType.playlist => ref.read(manualPlaylistIdsProvider.notifier),
    _ => throw ArgumentError.value(parentType, 'parentType'),
  };
}
