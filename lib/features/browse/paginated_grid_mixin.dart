import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_client.dart';

/// Mixin that provides infinite-scroll pagination logic for grid screens.
///
/// Usage: mix into a [ConsumerState] subclass and implement [fetchPage] and
/// [invalidatePage].  Use [items], [hasMore], [isLoadingMore], and
/// [scrollController] to drive the UI, and call [seedIfEmpty] and [refresh]
/// from [build].
///
/// Example:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with PaginatedGridMixin<MyItem, MyScreen> {
///   @override
///   Future<PaginatedResponse<MyItem>> fetchPage(int page) =>
///       ref.read(myPageProvider(page).future);
///
///   @override
///   void invalidatePage(int page) => ref.invalidate(myPageProvider(page));
/// }
/// ```
mixin PaginatedGridMixin<T, W extends ConsumerStatefulWidget>
    on ConsumerState<W> {
  final ScrollController scrollController = ScrollController();
  final List<T> items = [];
  int _currentPage = 1;
  bool hasMore = true;
  bool isLoadingMore = false;

  /// Fetch the given page from the API / provider cache.
  Future<PaginatedResponse<T>> fetchPage(int page);

  /// Invalidate the provider for [page] so Riverpod refetches it.
  void invalidatePage(int page);

  /// Override to bypass the metadata cache for [page] during pull-to-refresh.
  ///
  /// Called by [refresh] before [invalidatePage] + [fetchPage] so that fresh
  /// data is written to the cache before the provider re-runs.  The default
  /// implementation is a no-op; subclasses that use a cached API should
  /// override this.
  Future<void> forceRefreshPage(int page) async {}

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 300 &&
        !isLoadingMore &&
        hasMore) {
      _loadNextPage();
    }
  }

  /// After updating the list, check if the content fills the viewport. If
  /// the first page fits entirely on screen (no scrollable overflow), the
  /// scroll listener never fires, so we proactively load the next page.
  void _loadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoadingMore || !hasMore) return;
      if (!scrollController.hasClients) return;
      final pos = scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 300) {
        _loadNextPage();
      }
    });
  }

  Future<void> _loadNextPage() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    final nextPage = _currentPage + 1;
    try {
      final result = await fetchPage(nextPage);

      if (mounted) {
        setState(() {
          items.addAll(result.results);
          _currentPage = nextPage;
          hasMore = result.next != null;
          isLoadingMore = false;
        });
        _loadMoreIfNeeded();
      }
    } catch (_) {
      // Reset the gate so a later scroll (or pull-to-refresh) can retry.
      if (mounted) {
        setState(() => isLoadingMore = false);
      }
    }
  }

  /// Reset pagination state without fetching. Call when filters change so the
  /// next build re-seeds from the newly-invalidated provider.
  void resetPagination() {
    setState(() {
      items.clear();
      _currentPage = 1;
      hasMore = true;
      isLoadingMore = false;
    });
  }

  /// Pull-to-refresh: re-fetch the first page and reset state.
  Future<void> refresh() async {
    try {
      await forceRefreshPage(1);
    } catch (_) {
      // Network failure — invalidate anyway so the provider serves stale
      // cached data rather than hanging.
    }
    invalidatePage(1);
    final result = await fetchPage(1);
    if (mounted) {
      setState(() {
        items
          ..clear()
          ..addAll(result.results);
        _currentPage = 1;
        hasMore = result.next != null;
        isLoadingMore = false;
      });
    }
  }

  /// Seed [items] from [response] when the list is empty (first load).
  /// Must be called from [build] when the first-page data arrives.
  void seedIfEmpty(PaginatedResponse<T> response) {
    seedOrUpdateFirstPage(response, idOf: null);
  }

  /// Apply first-page [response] for initial seed *and* background
  /// revalidation updates.
  ///
  /// When only page 1 is loaded (`_currentPage == 1`), replaces [items] so
  /// inserts/removes from a stale-while-revalidate refresh appear immediately.
  /// When the user has scrolled further, leaves deeper pages alone (pull to
  /// refresh still resets via [refresh]).
  ///
  /// If [idOf] is provided, skips [setState] when the id sequence is unchanged
  /// to avoid scroll jank on no-op revalidations that still rebuild the
  /// provider.
  void seedOrUpdateFirstPage(
    PaginatedResponse<T> response, {
    int Function(T item)? idOf,
  }) {
    if (response.results.isEmpty && items.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Don't clobber multi-page scroll state on a silent page-1 refresh.
      if (_currentPage > 1) {
        if (items.isEmpty && response.results.isNotEmpty) {
          setState(() {
            items.addAll(response.results);
            hasMore = response.next != null;
          });
          _loadMoreIfNeeded();
        }
        return;
      }

      if (idOf != null && items.isNotEmpty) {
        final oldIds = items.map(idOf).toList(growable: false);
        final newIds = response.results.map(idOf).toList(growable: false);
        if (oldIds.length == newIds.length) {
          var same = true;
          for (var i = 0; i < oldIds.length; i++) {
            if (oldIds[i] != newIds[i]) {
              same = false;
              break;
            }
          }
          if (same) {
            // IDs match — still refresh item objects (titles/covers may change)
            // but only if the list reference would look different. For simplicity
            // replace when result count or next-link differs; otherwise skip.
            final nextChanged = hasMore != (response.next != null);
            if (!nextChanged) return;
          }
        }
      }

      setState(() {
        items
          ..clear()
          ..addAll(response.results);
        hasMore = response.next != null;
      });
      _loadMoreIfNeeded();
    });
  }
}
