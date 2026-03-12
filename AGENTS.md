# Tayra - Agent Guidelines

This file provides coding guidelines for AI agents working on this Flutter/Dart codebase.

## Project Overview

A Flutter-based music player client for Funkwhale servers, targeting Android with OAuth authentication, audio playback (just_audio + audio_service), and AMOLED dark theme with dynamic gradients.

**Package name:** `tayra`  
**Target:** Android only (device ID: `4859701e`, Android 16, CPH2655)

## Build & Deploy Commands

### Standard Development
```bash
# Build debug APK
flutter build apk --debug

# Install on device
adb -s 4859701e install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch app
adb -s 4859701e shell am start -n dev.lorendb.tayra/.MainActivity

# Combined build + deploy (use for efficiency)
flutter build apk --debug && \
  adb -s 4859701e install -r build/app/outputs/flutter-apk/app-debug.apk && \
  adb -s 4859701e shell am start -n dev.lorendb.tayra/.MainActivity
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart

# Run single test by name
flutter test test/path/to/test_file.dart --name "test name"
```

**Note:** Currently minimal test coverage (placeholder tests only). Add tests for new features.

### Linting & Analysis
```bash
# Analyze code
flutter analyze

# Format code
dart format lib/ test/
```

## Code Style Guidelines

### File & Directory Structure

#### Organization Pattern
```
lib/
├── core/                     # Shared infrastructure
│   ├── api/                 # API client, models, dio setup
│   ├── auth/                # Authentication providers
│   ├── router/              # go_router configuration
│   ├── theme/               # AppTheme constants, colors
│   └── widgets/             # Reusable UI components
└── features/                # Feature modules (feature-first)
    ├── auth/presentation/   # Login screen
    ├── browse/              # Albums, artists, detail screens
    ├── home/                # Home screen
    ├── player/              # Player UI & business logic
    ├── settings/            # Settings screen & provider
    └── [feature_name]/      # Other features
```

#### File Naming
- **snake_case** for all file names: `album_detail_screen.dart`, `player_provider.dart`
- **Descriptive suffixes:**
  - `*_screen.dart` - Full-screen widgets
  - `*_provider.dart` - Riverpod state providers/notifiers
  - `*_widget.dart` - Reusable UI components
  - No suffix for simple widgets: `mini_player.dart`

### Import Conventions

#### Always Use Package Imports (Never Relative)
```dart
// ✅ CORRECT - Use package imports exclusively
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/player/player_provider.dart';

// ❌ WRONG - Never use relative imports
import '../../core/api/models.dart';
```

#### Import Order
1. Flutter SDK imports
2. Third-party packages (Riverpod, dio, go_router, etc.)
3. Local package imports (`package:tayra/...`)

### Naming Conventions

#### Classes & Types
- **PascalCase** for public classes: `AlbumDetailScreen`, `PlayerNotifier`, `FunkwhaleApi`
- **Leading underscore** for private classes: `_AlbumHeader`, `_ErrorCard`, `_ArtistGrid`

#### Variables & Functions
- **camelCase**: `albumId`, `tracksAsync`, `playerState`, `getAlbums()`
- **Leading underscore** for private members: `_dio`, `_scrollController`, `_loadAndPlay()`

#### Constants
- **lowerCamelCase** with `static const`:
```dart
static const _keyServerUrl = 'server_url';
static const _redirectUri = 'urn:ietf:wg:oauth:2.0:oob';
```

### Code Organization

#### Section Comments
Use decorative section dividers for logical grouping:
```dart
// ── Providers ───────────────────────────────────────────────────────

final albumProvider = FutureProvider.family<Album, int>((ref, id) { ... });

// ── Screen ──────────────────────────────────────────────────────────

class AlbumDetailScreen extends ConsumerWidget { ... }

// ── Private widgets ─────────────────────────────────────────────────

class _AlbumHeader extends StatelessWidget { ... }
```

### State Management (Riverpod)

#### Provider Types
```dart
// 1. StateNotifierProvider - Mutable state with business logic
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

// 2. FutureProvider - Async data loading
final recentAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final api = ref.watch(funkwhaleApiProvider);
  return await api.getAlbums(ordering: '-creation_date');
});

// 3. FutureProvider.family - Parameterized data
final albumDetailProvider = FutureProvider.family<Album, int>((ref, id) {
  return ref.watch(funkwhaleApiProvider).getAlbum(id);
});

// 4. Provider - Services/singletons (dependency injection)
final funkwhaleApiProvider = Provider<FunkwhaleApi>((ref) {
  return FunkwhaleApi(ref.watch(dioProvider), ref);
});
```

#### Immutable State Classes
```dart
class PlayerState {
  final List<Track> queue;
  final bool isPlaying;
  
  const PlayerState({this.queue = const [], this.isPlaying = false});
  
  PlayerState copyWith({List<Track>? queue, bool? isPlaying}) {
    return PlayerState(
      queue: queue ?? this.queue,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
```

### Error Handling

#### UI Error Handling (AsyncValue Pattern)
```dart
// Use AsyncValue.when() for declarative error handling
return albumAsync.when(
  loading: () => const ShimmerLoading(),
  error: (error, stack) => _ErrorCard(
    message: error.toString(),
    onRetry: () => ref.invalidate(albumProvider),
  ),
  data: (album) => _AlbumContent(album: album),
);
```

#### Optimistic Updates with Rollback
```dart
Future<void> toggleFavorite(int trackId) async {
  final isFav = state.contains(trackId);
  // Optimistic update
  state = isFav ? (Set<int>.from(state)..remove(trackId)) 
                : (Set<int>.from(state)..add(trackId));
  try {
    await _api.toggleFavorite(trackId);
  } catch (_) {
    // Revert on error
    state = isFav ? (Set<int>.from(state)..add(trackId)) 
                  : (Set<int>.from(state)..remove(trackId));
  }
}
```

#### Silent Failures for Non-Critical Operations
```dart
// Don't disrupt user experience for non-critical failures
try {
  await _api.recordListening(track.id);
} catch (_) {
  // Silently fail - this is non-critical telemetry
}
```

### Widget Patterns

#### Screen Structure
```dart
// 1. Providers at top
final dataProvider = FutureProvider<Data>((ref) { ... });

// 2. Public screen widget
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(...);
  }
}

// 3. Private component widgets (prefix with _)
class _Header extends StatelessWidget { ... }
class _ContentSection extends ConsumerWidget { ... }
```

#### Reusable Components
Place reusable widgets in `core/widgets/`:
- `TrackListTile` - Track rows with context menu
- `CoverArtWidget` - Image loading with placeholders
- `ShimmerList/ShimmerGrid` - Loading skeletons

## Key Technologies

- **State Management:** flutter_riverpod ^2.6.1
- **Navigation:** go_router ^14.8.1
- **HTTP:** dio ^5.7.0
- **Audio:** just_audio ^0.9.42, audio_service ^0.18.15
- **Storage:** flutter_secure_storage ^9.2.3, shared_preferences ^2.3.4
- **UI:** cached_network_image ^3.4.1, shimmer ^3.0.0, palette_generator ^0.3.3+4

## Android Configuration Notes

- **MainActivity extends AudioServiceActivity** (required for audio_service)
- **Network security config** allows cleartext HTTP for localhost (development)
- **Permissions:** INTERNET, WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK

## Common Patterns to Follow

1. **Always use `ConsumerWidget`** or `ConsumerStatefulWidget` for widgets that read providers
2. **Use `ref.watch()`** for reactive updates, `ref.read()` for one-time access
3. **Use `ref.invalidate()`** for pull-to-refresh patterns
4. **Prefix private widgets** with `_` (scoped to file)
5. **Use `const` constructors** wherever possible for performance
6. **Null safety:** Use `?` and `??` extensively; avoid force unwrapping (`!`)
7. **Theme constants:** Use `AppTheme.*` constants instead of hardcoded colors

## Testing Guidelines

When adding tests:
- Place test files in `test/` mirroring `lib/` structure
- Name test files: `*_test.dart`
- Use `flutter_test` and `mockito` for mocking
- Add widget tests for new screens, unit tests for business logic

---

**For questions or clarifications, refer to existing code patterns in the codebase.**
