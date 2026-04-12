import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
// Optional: set a minimum window size on desktop platforms to avoid
// rendering issues at very small sizes.
import 'package:window_size/window_size.dart' as window_size;
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const maxWidth = 450.0;
  const maxHeight = 650.0;

  // Configure a minimum window size on desktop platforms.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      // On some window managers this call can throw or be a no-op; ignore
      // errors to avoid crashing the startup path.
      window_size.setWindowMinSize(const Size(maxWidth, maxHeight));
      // Also set an initial window size if the current size is smaller.
      final current = window_size.getWindowInfo();
      current
          .then((info) {
            final frame = info.frame;
            if (frame != null && frame.width < maxWidth) {
              window_size.setWindowFrame(
                Rect.fromLTWH(
                  frame.left,
                  frame.top,
                  maxWidth,
                  math.max(maxHeight, frame.height),
                ),
              );
            }
          })
          .catchError((_) {});
    } catch (_) {
      // Ignore if the platform doesn't support this or the call fails.
    }
  }

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

  // Ensure the listen history table exists before the cache manager starts,
  // because cache eviction queries listen_history to score tracks.
  await ListenHistoryService.ensureTable();

  // Initialize the cache manager
  await CacheManager.instance.initialize();

  // Register MPRIS platform interface for Linux system media controls
  if (Platform.isLinux) {
    AudioServiceMpris.registerWith();
  }

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
  audioHandler.androidAutoEnabled =
      container.read(settingsProvider).androidAutoEnabled;

  // Listen for settings changes to update browse mode and recommendations dynamically.
  container.listen<SettingsState>(settingsProvider, (previous, next) {
    audioHandler.browseMode = next.browseMode;
    audioHandler.androidAutoEnabled = next.androidAutoEnabled;
  });

  // Eagerly initialize the PlayerNotifier to wire up the onPlayTracks callback.
  // This ensures Android Auto can start playback even when launched in the background.
  container.read(playerProvider);

  // Initialize and resume any persisted download queue using the main
  // provider container so the service can read providers it needs.
  try {
    final queueSvc = container.read(downloadQueueServiceProvider);
    await queueSvc.init(container);
  } catch (_) {}

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
