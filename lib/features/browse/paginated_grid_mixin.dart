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
    if (items.isEmpty && response.results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && items.isEmpty) {
          setState(() {
            items.addAll(response.results);
            hasMore = response.next != null;
          });
          _loadMoreIfNeeded();
        }
      });
    }
  }
}
