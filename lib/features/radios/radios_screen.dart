import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/features/player/player_provider.dart';

class RadiosScreen extends ConsumerStatefulWidget {
  const RadiosScreen({super.key});

  @override
  ConsumerState<RadiosScreen> createState() => _RadiosScreenState();
}

class _RadiosScreenState extends ConsumerState<RadiosScreen> {
  final List<models.Radio> _userRadios = [];
  final List<models.Radio> _builtinRadios = [];
  // Static instance (built-in) radios similar to the official Android client.
  final List<Map<String, String>> _instanceRadios = [
    {
      'type': 'actor-content',
      'name': 'Your content',
      'description': 'Tracks you uploaded or contributed',
    },
    {
      'type': 'random',
      'name': 'Random',
      'description': 'A completely random selection of tracks',
    },
    {
      'type': 'favorites',
      'name': 'Favorites',
      'description': 'Tracks you favorited',
    },
    {
      'type': 'less-listened',
      'name': 'Less listened',
      'description': 'Tracks you listened to less often',
    },
  ];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _error;
  StreamSubscription<String>? _cacheSub;

  @override
  void initState() {
    super.initState();
    _loadRadios();
    _cacheSub = ref
        .read(cached_api.cachedFunkwhaleApiProvider)
        .metadataUpdates
        .listen((key) {
          if (key.startsWith('radios_p')) {
            unawaited(_loadRadios());
          }
        });
  }

  @override
  void dispose() {
    _cacheSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRadios({bool forceRefresh = false}) async {
    setState(() {
      // Only full-screen shimmer when we have nothing to show yet.
      if (_userRadios.isEmpty && _builtinRadios.isEmpty) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      // Cache-first: returns immediately when metadata is cached, then the
      // repository revalidates in the background and metadataUpdates fires.
      final response = await api.getRadios(
        page: 1,
        pageSize: 50,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _userRadios
          ..clear()
          ..addAll(response.results.where((r) => r.user != null));
        _builtinRadios
          ..clear()
          ..addAll(response.results.where((r) => r.user == null));
        _isLoading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      final msg = e is Exception ? e.toString() : 'Unknown error';
      setState(() {
        if (_userRadios.isEmpty && _builtinRadios.isEmpty) {
          _error = 'Failed to load radios: $msg';
        }
        _isLoading = false;
      });
      debugPrint('Radios load failed: $e\n$st');
    }
  }

  void _playRadio(models.Radio radio) {
    ref.read(playerProvider.notifier).pause();
    ref.read(playerProvider.notifier).startRadio(radio.id);
  }

  void _playInstanceRadio(
    String radioType,
    int loadingId, {
    String? relatedObjectId,
  }) {
    ref.read(playerProvider.notifier).pause();
    ref
        .read(playerProvider.notifier)
        .startInstanceRadio(
          radioType,
          loadingId,
          relatedObjectId: relatedObjectId,
        );
  }

  /// Apply a radio returned from create/edit into local list state, then
  /// revalidate from cache/network. Nested `/radios/...` routes dispose this
  /// State while the builder is open, so the push Future often completes with
  /// `!mounted` — create/edit still warm the radios list cache so the remount
  /// path in [initState] sees the new item without a manual pull-to-refresh.
  void _mergeUserRadio(models.Radio radio) {
    final idx = _userRadios.indexWhere((r) => r.id == radio.id);
    if (idx >= 0) {
      _userRadios[idx] = radio;
    } else {
      _userRadios.insert(0, radio);
    }
  }

  Future<void> _openCreateRadio() async {
    final result = await context.push<Object?>('/radios/new');
    if (!mounted) return;
    if (result is models.Radio) {
      setState(() => _mergeUserRadio(result));
    }
    // Force network so we still refresh when the push result was only `true`
    // or null (older callers) or when cache warm raced with this remount.
    await _loadRadios(forceRefresh: true);
  }

  Future<void> _openEditRadio(models.Radio radio) async {
    if (!radio.isCustom) return;
    final result = await context.push<Object?>(
      '/radios/${radio.id}/edit',
      extra: radio,
    );
    if (!mounted) return;
    if (result is models.Radio) {
      setState(() => _mergeUserRadio(result));
    } else if (result == true) {
      // Deleted from the edit screen — drop local row if still present.
      setState(() => _userRadios.removeWhere((r) => r.id == radio.id));
    }
    await _loadRadios(forceRefresh: true);
  }

  Future<void> _deleteCustomRadio(models.Radio radio) async {
    if (!radio.isCustom) return;

    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete radio?',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Delete “${radio.name}”? Anyone with access will lose it. '
              'This cannot be undone.',
              style: const TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete radio',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(cached_api.cachedFunkwhaleApiProvider)
          .deleteRadio(radio.id);
      if (!mounted) return;
      setState(() {
        _userRadios.removeWhere((r) => r.id == radio.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Radio deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete radio')));
    }
  }

  void _showCustomRadioMenu(models.Radio radio) {
    showShellModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onBackgroundSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.primary,
                ),
                title: const Text(
                  'Play',
                  style: TextStyle(color: AppTheme.onBackground),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _playRadio(radio);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppTheme.onBackground,
                ),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: AppTheme.onBackground),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_openEditRadio(radio));
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_deleteCustomRadio(radio));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Radios'),
        actions: [
          if (!offlineFilterActive)
            IconButton(
              tooltip: 'Create radio',
              icon: const Icon(Icons.add_rounded, color: AppTheme.onBackground),
              onPressed: _openCreateRadio,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Radios are server-side only — not available offline.
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    if (offlineFilterActive) {
      return const EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Radios unavailable offline',
        subtitle: 'Radios require a server connection to stream',
      );
    }

    if (_isLoading) return const ShimmerList(itemCount: 10);
    if (_error != null) {
      return InlineErrorState(message: _error!, onRetry: _loadRadios);
    }

    final loadingRadioId = ref.watch(
      playerProvider.select((s) => s.loadingRadioId),
    );

    // Flatten sections into a single model list for ListView.builder.
    // Instance radios are client-defined and always available online — do not
    // gate them behind an empty API response.
    final items = <_RadioListItem>[];
    if (_instanceRadios.isNotEmpty || _builtinRadios.isNotEmpty) {
      items.add(const _RadioListHeader('Instance radios'));
      for (var i = 0; i < _instanceRadios.length; i++) {
        final item = _instanceRadios[i];
        items.add(
          _RadioListInstance(
            name: item['name']!,
            description: item['description'],
            type: item['type']!,
            sentinelId: -100 - i,
          ),
        );
      }
      for (final radio in _builtinRadios) {
        items.add(_RadioListServer(radio));
      }
    }

    // Always show the "Your radios" section online so users can create one
    // even when the list is empty.
    items.add(const _RadioListHeader('Your radios'));
    if (_userRadios.isEmpty) {
      items.add(const _RadioListCreatePrompt());
    } else {
      for (final radio in _userRadios) {
        items.add(_RadioListServer(radio));
      }
    }

    return AppRefreshIndicator(
      onRefresh: () => _loadRadios(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return switch (item) {
            _RadioListHeader(:final title) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _RadioListCreatePrompt() => Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _openCreateRadio,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create your own radio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            _RadioListInstance(
              :final name,
              :final description,
              :final type,
              :final sentinelId,
            ) =>
              _radioTile(
                title: name,
                subtitle: description,
                isLoading: loadingRadioId == sentinelId,
                onPlay: () => _playInstanceRadio(type, sentinelId),
              ),
            _RadioListServer(:final radio) => _radioTile(
              title: radio.name,
              subtitle: radio.description,
              coverUrl: radio.coverUrl,
              isLoading: loadingRadioId == radio.id,
              onPlay: () => _playRadio(radio),
              // Pre-programmed / system radios (no user) cannot be edited.
              onEdit: radio.isCustom ? () => _openEditRadio(radio) : null,
              onMore: radio.isCustom ? () => _showCustomRadioMenu(radio) : null,
              onLongPress:
                  radio.isCustom ? () => _showCustomRadioMenu(radio) : null,
            ),
          };
        },
      ),
    );
  }

  Widget _radioTile({
    required String title,
    required String? subtitle,
    String? coverUrl,
    required bool isLoading,
    required VoidCallback onPlay,
    VoidCallback? onEdit,
    VoidCallback? onMore,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppTheme.onBackground)),
      subtitle:
          subtitle != null && subtitle.isNotEmpty
              ? Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.onBackgroundMuted),
              )
              : null,
      leading: CoverArtWidget(
        // Rebuild when art changes after an in-app upload.
        key: ValueKey(coverUrl ?? 'radio-placeholder'),
        imageUrl: coverUrl,
        size: 44,
        borderRadius: 8,
        placeholderIcon: Icons.radio_rounded,
      ),
      onTap: onEdit,
      onLongPress: onLongPress,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onMore != null)
            IconButton(
              tooltip: 'More',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppTheme.onBackgroundSubtle,
                size: 20,
              ),
              onPressed: onMore,
            ),
          // Fixed 48×48 slot (default IconButton hit target) so swapping
          // play ↔ spinner never shifts the more menu.
          SizedBox(
            width: 48,
            height: 48,
            child:
                isLoading
                    ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                    : IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed: onPlay,
                    ),
          ),
        ],
      ),
    );
  }
}

sealed class _RadioListItem {
  const _RadioListItem();
}

class _RadioListHeader extends _RadioListItem {
  final String title;
  const _RadioListHeader(this.title);
}

/// Placeholder row when the user has no custom radios yet.
class _RadioListCreatePrompt extends _RadioListItem {
  const _RadioListCreatePrompt();
}

class _RadioListInstance extends _RadioListItem {
  final String name;
  final String? description;
  final String type;
  final int sentinelId;
  const _RadioListInstance({
    required this.name,
    required this.description,
    required this.type,
    required this.sentinelId,
  });
}

class _RadioListServer extends _RadioListItem {
  final models.Radio radio;
  const _RadioListServer(this.radio);
}
