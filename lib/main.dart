import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const TayraApp(),
    ),
  );
}

class TayraApp extends ConsumerWidget {
  const TayraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Tayra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
