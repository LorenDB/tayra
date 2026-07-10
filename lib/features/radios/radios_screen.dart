import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
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

  Future<void> _loadRadios({bool forceRefresh = false}) async {
    setState(() {
      if (!forceRefresh || (_userRadios.isEmpty && _builtinRadios.isEmpty)) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
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
    if (_userRadios.isEmpty && _builtinRadios.isEmpty) {
      return const EmptyState(
        icon: Icons.radio,
        title: 'No radios found',
        subtitle:
            'Create one on your Funkwhale instance or try a different server',
      );
    }

    final loadingRadioId = ref.watch(
      playerProvider.select((s) => s.loadingRadioId),
    );

    // Flatten sections into a single model list for ListView.builder.
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
              isLoading: loadingRadioId == radio.id,
              onPlay: () => _playRadio(radio),
            ),
          };
        },
      ),
    );
  }

  Widget _radioTile({
    required String title,
    required String? subtitle,
    required bool isLoading,
    required VoidCallback onPlay,
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
      leading: const Icon(
        Icons.radio_outlined,
        color: AppTheme.onBackgroundSubtle,
      ),
      trailing:
          isLoading
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
                onPressed: onPlay,
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
