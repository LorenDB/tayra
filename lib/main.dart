import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Optional: set a minimum window size on desktop platforms to avoid
// rendering issues at very small sizes.
import 'package:window_size/window_size.dart' as window_size;

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/backup/nextcloud_backup_service.dart';
import 'package:tayra/core/cache/auto_offline_coordinator.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

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
            if (frame.width < maxWidth) {
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

  // Load persisted analytics preference and initialise analytics if enabled.
  // This avoids initialising Aptabase when the user has opted out.
  await Analytics.loadEnabledFromPrefs();
  unawaited(
    Analytics.initializeIfEnabled().then((_) => Analytics.track("startup")),
  );

  // Initialize sqflite for desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize just_audio_media_kit for desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    JustAudioMediaKit.ensureInitialized();
  }

  // Register MPRIS platform interface for Linux system media controls
  if (Platform.isLinux) {
    AudioServiceMpris.registerWith();
  }

  // Run independent startup operations concurrently.
  // - ensureTable creates the listen_history table (needed before backgroundInitialize)
  // - CacheManager.initialize only reads SharedPreferences (no DB dependency)
  // - initAudioHandler initializes the audio system (no DB/prefs dependency)
  late final FunkwhaleAudioHandler audioHandler;
  await Future.wait([
    ListenHistoryService.ensureTable(),
    CacheManager.instance.initialize(),
    initAudioHandler().then((h) => audioHandler = h),
  ]);

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

  // Initialize the download queue after the UI is visible. It is not needed
  // until the user interacts with downloads, so deferring it avoids blocking
  // the splash screen on DB queries.
  unawaited(
    Future(() async {
      try {
        final queueSvc = container.read(downloadQueueServiceProvider);
        await queueSvc.init(container);
      } catch (_) {}
    }),
  );

  // Resume the download queue when connectivity becomes allowed again
  // (e.g. Wi‑Fi returns while downloadWifiOnly is on).
  container.listen(connectivityResultProvider, (previous, next) {
    next.whenData((_) {
      try {
        container.read(autoOfflineCoordinatorProvider).maybeResumeDownloads();
      } catch (_) {}
    });
  });
  container.listen(settingsProvider, (previous, next) {
    if (previous?.downloadWifiOnly == true && !next.downloadWifiOnly) {
      try {
        container.read(autoOfflineCoordinatorProvider).maybeResumeDownloads();
      } catch (_) {}
    }
    if (previous?.autoDownloadPodcastEpisodes != true &&
        next.autoDownloadPodcastEpisodes) {
      unawaited(
        container
            .read(autoOfflineCoordinatorProvider)
            .reconcileSubscribedPodcasts(),
      );
    }
  });

  // Best-effort: auto-download latest episodes for subscribed shows.
  unawaited(
    Future.delayed(const Duration(seconds: 12), () {
      try {
        final settings = container.read(settingsProvider);
        if (settings.autoDownloadPodcastEpisodes) {
          container
              .read(autoOfflineCoordinatorProvider)
              .reconcileSubscribedPodcasts();
        }
      } catch (_) {}
    }),
  );

  // Reconcile cached files with the DB and enforce size limits in the
  // background so these O(n-files) operations don't block the splash screen.
  // ListenHistoryService.ensureTable() has already run above, so the
  // listen_history table is guaranteed to exist before this touches the DB.
  unawaited(CacheManager.instance.backgroundInitialize());

  // Kick off an optional non-blocking periodic-ish backup and history
  // sync on startup for Nextcloud (if configured). The sync pulls remote
  // device listen history into the local DB so the year-review page opens
  // instantly without a network round-trip.
  void runPeriodicSync() async {
    try {
      final nc = container.read(nextcloudBackupProvider);
      if (nc.isConnected) {
        container
            .read(nextcloudBackupProvider.notifier)
            .syncNow()
            .catchError((_) => 0);
      }
    } catch (_) {}
    // Schedule the next run
    Timer(const Duration(minutes: 10), runPeriodicSync);
  }

  unawaited(
    Future.delayed(const Duration(seconds: 8), () async {
      try {
        final nc = container.read(nextcloudBackupProvider);
        if (nc.isConnected && nc.autoBackupEnabled) {
          container
              .read(nextcloudBackupProvider.notifier)
              .backupNow()
              .catchError((_) => false);
        }
      } catch (_) {}
      runPeriodicSync();
    }),
  );
}

class TayraApp extends ConsumerStatefulWidget {
  const TayraApp({super.key});

  @override
  ConsumerState<TayraApp> createState() => _TayraAppState();
}

class _TayraAppState extends ConsumerState<TayraApp>
    with WidgetsBindingObserver {
  /// Last [NavigationNotification.canHandlePop] seen by
  /// [_onNavigationNotification]. Used on resume so PopScope-blocked root
  /// routes still re-register the Android back callback correctly.
  bool _frameworkHandlesBack = false;

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
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        ref.read(playerProvider.notifier).onAppPaused();
      case AppLifecycleState.resumed:
        ref.read(playerProvider.notifier).onAppResumed();
        _resyncAndroidBackHandling();
      case AppLifecycleState.detached:
        Analytics.track('app_close');
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Re-attach Android's [OnBackInvokedCallback] after returning from the
  /// background.
  ///
  /// After the app sits in the background for a while, system back can stop
  /// popping routes and instead minimize the activity, even though in-app
  /// back buttons (which call [Navigator.pop] / [GoRouter.pop] directly)
  /// still work. Navigating to a new page "fixes" it because that triggers a
  /// fresh [SystemNavigator.setFrameworkHandlesBack] false→true edge, which
  /// is the only path [FlutterActivity] uses to re-register the native
  /// callback.
  ///
  /// Force that same edge on resume whenever the stack (or a PopScope) still
  /// wants to handle back.
  void _resyncAndroidBackHandling() {
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canPop = ref.read(appRouterProvider).canPop();
      final handlesBack = canPop || _frameworkHandlesBack;
      // Always clear first so a subsequent true forces native re-registration
      // even if FlutterActivity thought the callback was already attached.
      SystemNavigator.setFrameworkHandlesBack(false);
      if (handlesBack) {
        SystemNavigator.setFrameworkHandlesBack(true);
      }
      _frameworkHandlesBack = handlesBack;
    });
  }

  bool _onNavigationNotification(NavigationNotification notification) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    // Match WidgetsApp's default handler: skip while detached/not ready.
    if (lifecycle == null || lifecycle == AppLifecycleState.detached) {
      return true;
    }
    _frameworkHandlesBack = notification.canHandlePop;
    SystemNavigator.setFrameworkHandlesBack(notification.canHandlePop);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Tayra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      onNavigationNotification: _onNavigationNotification,
    );
  }
}
