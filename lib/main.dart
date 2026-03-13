import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Aptabase.init(
    "A-SH-1447414969",
    InitOptions(host: "https://aptabase.lorendb.dev"),
  );
  Aptabase.instance.trackEvent("startup");

  // Initialize sqflite for desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize just_audio_media_kit for desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    JustAudioMediaKit.ensureInitialized();
  }

  // Initialize the cache manager
  await CacheManager.instance.initialize();

  // Initialize the audio handler before starting the app
  final audioHandler = await initAudioHandler();

  // Create a provider container to access providers before runApp.
  // This allows us to inject the API client into the audio handler
  // so Android Auto works even when the app is launched in the background.
  final container = ProviderContainer(
    overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
  );

  // Inject dependencies into the audio handler for Android Auto.
  // This ensures the handler can serve browse tree requests even if
  // the UI hasn't been opened yet.
  audioHandler.api = container.read(cachedFunkwhaleApiProvider);
  audioHandler.browseMode = container.read(settingsProvider).browseMode;

  // Listen for settings changes to update browse mode dynamically.
  container.listen<SettingsState>(settingsProvider, (previous, next) {
    audioHandler.browseMode = next.browseMode;
  });

  // Eagerly initialize the PlayerNotifier to wire up the onPlayTracks callback.
  // This ensures Android Auto can start playback even when launched in the background.
  container.read(playerProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const TayraApp()),
  );
}

class TayraApp extends ConsumerStatefulWidget {
  const TayraApp({super.key});

  @override
  ConsumerState<TayraApp> createState() => _TayraAppState();
}

class _TayraAppState extends ConsumerState<TayraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      Aptabase.instance.trackEvent('app_close');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Tayra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
