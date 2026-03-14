import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/api/models.dart';

// ── Pagination helpers ───────────────────────────────────────────────────

/// Fetches every page of a paginated endpoint and returns all results.
///
/// [fetcher] is called with the current page number (1-indexed) and must
/// return a [PaginatedResponse]. Iteration stops when [PaginatedResponse.next]
/// is `null`.
///
/// Example:
/// ```dart
/// final tracks = await fetchAllPages(
///   (page) => api.getTracks(album: albumId, page: page, pageSize: 100),
/// );
/// ```
Future<List<T>> fetchAllPages<T>(
  Future<PaginatedResponse<T>> Function(int page) fetcher,
) async {
  final all = <T>[];
  int page = 1;
  while (true) {
    final response = await fetcher(page);
    all.addAll(response.results);
    if (response.next == null) break;
    page++;
  }
  return all;
}

// ── Duration formatting ──────────────────────────────────────────────────

/// Formats [seconds] as `m:ss` (e.g. `3:07`).
///
/// Used for individual track durations in track rows and the seek bar.
String formatTrackDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Formats [totalSeconds] as a human-readable total duration.
///
/// Returns `'Xh Ym'` when hours ≥ 1, otherwise `'Y min'`.
/// Used for album/playlist total duration labels.
String formatTotalDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '$minutes min';
}

// ── Track sorting ────────────────────────────────────────────────────────

/// Sorts [tracks] in-place by disc number then track position.
void sortTracksByDiscAndPosition(List<Track> tracks) {
  tracks.sort((a, b) {
    final discA = a.discNumber ?? 1;
    final discB = b.discNumber ?? 1;
    if (discA != discB) return discA.compareTo(discB);
    final posA = a.position ?? 0;
    final posB = b.position ?? 0;
    return posA.compareTo(posB);
  });
}
