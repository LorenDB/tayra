import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/core/api/models.dart' show Track;
import 'package:tayra/features/player/player_provider.dart';

class RadiosScreen extends ConsumerStatefulWidget {
  const RadiosScreen({super.key});

  @override
  ConsumerState<RadiosScreen> createState() => _RadiosScreenState();
}

class _RadiosScreenState extends ConsumerState<RadiosScreen> {
  final List<models.Radio> _radios = [];
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
        _radios
          ..clear()
          ..addAll(response.results);
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
    // For now, create a session and then request the next track and play it.
    // This is a minimal implementation — a fuller player integration would
    // manage radio sessions and continuous playback.
    final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
    ref.read(playerProvider.notifier).pause();
    // Use radio sessions for playback: create a session, then repeatedly
    // request the next track and enqueue it. We'll load the first track and
    // start playback.
    // Delegate radio playback to the PlayerNotifier which handles sessions
    // and background fetching.
    ref.read(playerProvider.notifier).startRadio(radio.id);
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
    if (_isLoading) return const ShimmerList(itemCount: 10);
    if (_error != null)
      return InlineErrorState(message: _error!, onRetry: _loadRadios);
    if (_radios.isEmpty) {
      return const EmptyState(
        icon: Icons.radio,
        title: 'No radios found',
        subtitle:
            'Create one on your Funkwhale instance or try a different server',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _radios.length,
      itemBuilder: (context, index) {
        final radio = _radios[index];
        // Radios don't map exactly to tracks; show a simple tile and a play
        // action that triggers a radio session.
        return ListTile(
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
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.primary),
            onPressed: () => _playRadio(radio),
          ),
        );
      },
    );
  }
}
