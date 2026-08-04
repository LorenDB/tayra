import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/client_data_service.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/cache/auto_offline_coordinator.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// Desktop-only plugins — imported only on non-web via conditional stubs would
// be ideal; guarded at call sites with [AppPlatform.isDesktop] / isLinux.
import 'package:audio_service_mpris/audio_service_mpris.dart'
    if (dart.library.html) 'package:tayra/core/platform/desktop_stubs.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart'
    if (dart.library.html) 'package:tayra/core/platform/desktop_stubs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    if (dart.library.html) 'package:tayra/core/platform/desktop_stubs.dart';
import 'package:window_size/window_size.dart'
    if (dart.library.html) 'package:tayra/core/platform/desktop_stubs.dart'
    as window_size;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Path URLs so nginx try_files + deep links work as the primary pod UI.
  if (kIsWeb) {
    usePathUrlStrategy();
    // Detail navigation uses context.push (albums, artists, settings, …).
    // By default go_router keeps those off the browser URL bar; enable so
    // every page has a shareable, refreshable location.
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  const maxWidth = 450.0;
  const maxHeight = 650.0;

  // Configure a minimum window size on desktop platforms.
  if (AppPlatform.isDesktop) {
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

  // Initialize sqflite for desktop platforms (not available / needed on web).
  if (AppPlatform.isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize just_audio_media_kit for desktop platforms.
  if (AppPlatform.isDesktop) {
    JustAudioMediaKit.ensureInitialized();
  }

  // Register MPRIS platform interface for Linux system media controls.
  if (AppPlatform.isLinux) {
    AudioServiceMpris.registerWith();
  }

  // Run independent startup operations concurrently.
  // On web, offline DB/cache paths are no-ops or light prefs only.
  late final FunkwhaleAudioHandler audioHandler;
  await Future.wait([
    if (AppPlatform.supportsOfflineCache) ListenHistoryService.ensureTable(),
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

  // After remote prefs pull, reload SettingsNotifier from SharedPreferences.
  container.read(clientDataServiceProvider).onPreferencesApplied = () async {
    await container.read(settingsProvider.notifier).reloadFromPrefs();
  };

  // Register ClientDevice + sync progress/prefs when client-data API is available.
  container.read(clientDataBootstrapProvider);

  // When connectivity returns, push pending local listens (bulk) and purge
  // synced rows past retention. Avoids importing connectivity into
  // client_data_service (settings ↔ client_data cycle).
  if (AppPlatform.supportsOfflineCache) {
    container.listen<OfflineState>(offlineStateProvider, (previous, next) {
      final cameOnline =
          previous != null && previous.isOffline && !next.isOffline;
      if (!cameOnline) return;
      if (!container.read(authStateProvider).isAuthenticated) return;
      unawaited(
        container.read(clientDataServiceProvider).syncProgressAndPreferences(),
      );
    });
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const TayraApp()),
  );

  // Offline/download/backup paths are native-only (web is online-only).
  if (AppPlatform.supportsOfflineCache) {
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
    unawaited(CacheManager.instance.backgroundInitialize());
  }
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
    if (!AppPlatform.isAndroid) return;
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
      // Desktop: mouse side-button / OS browser-back → pop route (web uses
      // browser history for this already).
      builder: (context, child) {
        return DesktopBackGestureHandler(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
