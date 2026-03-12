import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funkwhale/core/router/app_router.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/features/player/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the audio handler before starting the app
  final audioHandler = await initAudioHandler();

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const FunkwhaleApp(),
    ),
  );
}

class FunkwhaleApp extends ConsumerWidget {
  const FunkwhaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Funkwhale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
