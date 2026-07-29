import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/cover_art_editor.dart';
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

  /// Edit cover art for a user-owned (custom) radio only.
  Future<void> _editCustomRadioCover(models.Radio radio) async {
    if (!radio.isCustom) return;

    CoverArtSelection? selection;
    final saved = await showShellDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Cover art · ${radio.name}',
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: CoverArtEditor(
                currentCover: radio.cover,
                placeholderIcon: Icons.radio_rounded,
                selection: selection,
                onChanged: (sel) {
                  setDialogState(() => selection = sel);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.onBackgroundMuted),
                  ),
                ),
                TextButton(
                  onPressed:
                      selection == null || !selection!.hasChange
                          ? null
                          : () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || selection == null || !selection!.hasChange) return;

    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final updated = await api.patchRadio(radio.id, {
        'cover': selection!.uploaded?.uuid,
      });
      if (!mounted) return;
      setState(() {
        final idx = _userRadios.indexWhere((r) => r.id == radio.id);
        if (idx >= 0) {
          _userRadios[idx] = updated;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cover art updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update cover art')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Radios'),
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
    if (_userRadios.isNotEmpty) {
      items.add(const _RadioListHeader('Your radios'));
      for (final radio in _userRadios) {
        items.add(_RadioListServer(radio));
      }
    }

    // Only truly empty when we have nothing at all (should not happen online
    // while instance radios exist, but keep a safe empty state).
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.radio,
        title: 'No radios found',
        subtitle:
            'Create one on your Funkwhale instance or try a different server',
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => _loadRadios(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
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
              // Pre-programmed / system radios (no user) cannot set custom art.
              onEditCover:
                  radio.isCustom ? () => _editCustomRadioCover(radio) : null,
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
    VoidCallback? onEditCover,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppTheme.onBackground)),
      subtitle:
          subtitle != null
              ? Text(
                subtitle,
                style: const TextStyle(color: AppTheme.onBackgroundMuted),
              )
              : null,
      leading: CoverArtWidget(
        imageUrl: coverUrl,
        size: 44,
        borderRadius: 8,
        placeholderIcon: Icons.radio_rounded,
      ),
      onLongPress: onEditCover,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEditCover != null)
            IconButton(
              tooltip: 'Edit cover art',
              icon: const Icon(
                Icons.image_outlined,
                color: AppTheme.onBackgroundSubtle,
                size: 20,
              ),
              onPressed: onEditCover,
            ),
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.primary,
              ),
              onPressed: onPlay,
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
