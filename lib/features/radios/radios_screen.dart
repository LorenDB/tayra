import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRadios();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRadios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final response = await api.getRadios(page: 1, pageSize: 50);
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
      // Surface the error message to help debugging (will show in UI).
      final msg = e is Exception ? e.toString() : 'Unknown error';
      setState(() {
        _error = 'Failed to load radios: $msg';
        _isLoading = false;
      });
      // Also print to console for developer visibility
      // ignore: avoid_print
      print('Radios load failed: $e\n$st');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Radios',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    if (_error != null)
      return InlineErrorState(message: _error!, onRetry: _loadRadios);
    if (_userRadios.isEmpty && _builtinRadios.isEmpty) {
      return const EmptyState(
        icon: Icons.radio,
        title: 'No radios found',
        subtitle:
            'Create one on your Funkwhale instance or try a different server',
      );
    }

    final children = <Widget>[];

    // Instance radios (client-side static options + server-provided built-ins)
    if (_instanceRadios.isNotEmpty || _builtinRadios.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Instance radios',
            style: TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      // Static instance radios first (client-side presets)
      for (var i = 0; i < _instanceRadios.length; i++) {
        final item = _instanceRadios[i];
        final sentinelId = -100 - i; // unique negative id for loading state
        final isLoadingRadio =
            ref.watch(playerProvider).loadingRadioId == sentinelId;
        children.add(
          ListTile(
            title: Text(
              item['name']!,
              style: const TextStyle(color: AppTheme.onBackground),
            ),
            subtitle:
                item['description'] != null
                    ? Text(
                      item['description']!,
                      style: const TextStyle(color: AppTheme.onBackgroundMuted),
                    )
                    : null,
            leading: const Icon(
              Icons.radio_outlined,
              color: AppTheme.onBackgroundSubtle,
            ),
            trailing:
                isLoadingRadio
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                    : IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed:
                          () => _playInstanceRadio(item['type']!, sentinelId),
                    ),
          ),
        );
      }

      // Server-provided built-in radios (those without a user)
      for (final radio in _builtinRadios) {
        final isLoadingRadio =
            ref.watch(playerProvider).loadingRadioId == radio.id;
        children.add(
          ListTile(
            title: Text(
              radio.name,
              style: const TextStyle(color: AppTheme.onBackground),
            ),
            subtitle:
                radio.description != null
                    ? Text(
                      radio.description!,
                      style: const TextStyle(color: AppTheme.onBackgroundMuted),
                    )
                    : null,
            leading: const Icon(
              Icons.radio_outlined,
              color: AppTheme.onBackgroundSubtle,
            ),
            trailing:
                isLoadingRadio
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                    : IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed: () => _playRadio(radio),
                    ),
          ),
        );
      }
    }

    // User-defined radios (separate section below)
    if (_userRadios.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Your radios',
            style: TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      for (final radio in _userRadios) {
        final playerState = ref.watch(playerProvider);
        final isLoadingRadio = playerState.loadingRadioId == radio.id;
        children.add(
          ListTile(
            title: Text(
              radio.name,
              style: const TextStyle(color: AppTheme.onBackground),
            ),
            subtitle:
                radio.description != null
                    ? Text(
                      radio.description!,
                      style: const TextStyle(color: AppTheme.onBackgroundMuted),
                    )
                    : null,
            leading: const Icon(
              Icons.radio_outlined,
              color: AppTheme.onBackgroundSubtle,
            ),
            trailing:
                isLoadingRadio
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                    : IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primary,
                      ),
                      onPressed: () => _playRadio(radio),
                    ),
          ),
        );
      }
    }

    return ListView(controller: _scrollController, children: children);
  }
}
