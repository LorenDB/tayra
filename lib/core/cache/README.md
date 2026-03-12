# Funkwhale Cache Implementation

This document describes the local cache system implemented for the Funkwhale Flutter app.

## Overview

The cache system provides offline access to music metadata, album art, and audio files with configurable storage limits and intelligent LRU (Least Recently Used) eviction.

## Architecture

### Components

1. **CacheDatabase** (`lib/core/cache/cache_database.dart`)
   - SQLite database schema with three tables:
     - `cache_metadata`: JSON metadata for albums, artists, tracks, playlists
     - `cache_files`: Downloaded audio files and cover art
     - `cache_favorites`: Favorite track IDs

2. **CacheManager** (`lib/core/cache/cache_manager.dart`)
   - Core caching logic with LRU eviction
   - Configurable size limits (default: 500 MB total)
   - Automatic eviction when limits are reached
   - Prioritizes keeping metadata over audio for offline browsing

3. **CachedFunkwhaleApi** (`lib/core/api/cached_api_repository.dart`)
   - Wraps the existing API with transparent caching
   - Caches all GET requests (albums, artists, tracks, playlists, search)
   - Configurable TTL (time-to-live) for different data types
   - Force refresh option to bypass cache

4. **AudioCacheService** (`lib/core/cache/audio_cache_service.dart`)
   - Audio file caching with download progress tracking
   - Cover art caching
   - Pre-caching capability for albums

5. **Settings Integration** (`lib/features/settings/`)
   - UI for cache management
   - Configurable cache size limit (100 MB - 2 GB)
   - Cache statistics display (storage breakdown)
   - Clear cache options (audio only or all)

## Cache Behavior

### Data Types and TTL

- **Albums, Artists, Tracks**: 1 hour
- **Album/Artist Lists**: 5 minutes
- **Search Results**: 2 minutes
- **Playlists**: 2 minutes (can be modified)
- **Favorites**: Persistent (no expiration)

### Eviction Priority

When cache reaches its limit, items are evicted in this order:

1. **First**: Audio files (by LRU)
2. **Second**: Cover art images (by LRU)
3. **Last**: Metadata (JSON data)

This ensures users can still browse their library offline even when storage is limited.

### Storage Allocation

- **60%** allocated to audio files
- **40%** allocated to metadata and images

Example: 500 MB limit = 300 MB audio + 200 MB metadata/images

## Usage

### Using Cached API

Replace `funkwhaleApiProvider` with `cachedFunkwhaleApiProvider` in your providers:

```dart
final albumProvider = FutureProvider.family<Album, int>((ref, id) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  return await api.getAlbum(id); // Automatically cached
});
```

### Force Refresh

Bypass cache when needed:

```dart
final response = await api.getAlbums(forceRefresh: true);
```

### Audio Caching

Check for cached audio before playing:

```dart
final audioCache = ref.read(audioCacheServiceProvider);
final cachedFile = await audioCache.getCachedAudio(track);

if (cachedFile != null) {
  // Play from cache
  audioUrl = cachedFile.path;
} else {
  // Stream from server
  audioUrl = api.getStreamUrl(track.listenUrl!);
}
```

### Pre-caching Albums

Download an entire album for offline listening:

```dart
final audioCache = ref.read(audioCacheServiceProvider);
await audioCache.preCacheAlbum(
  albumTracks,
  api.getStreamUrl,
  api.authHeaders,
);
```

## Settings UI

Users can manage cache from Settings > Cache:

- **Storage Used**: Visual breakdown of cache usage
- **Cache Size Limit**: Slider to adjust max storage (100 MB - 2 GB)
- **Clear Audio Cache**: Remove audio files only
- **Clear All Cache**: Remove all cached data

## Database Schema

### cache_metadata

| Column | Type | Description |
|--------|------|-------------|
| cache_key | TEXT | Primary key (e.g., "album_123") |
| cache_type | TEXT | Type enum (album, artist, track, etc.) |
| data | TEXT | JSON serialized data |
| size_bytes | INTEGER | Size of JSON string |
| created_at | INTEGER | Timestamp |
| last_accessed | INTEGER | Timestamp for LRU |
| expires_at | INTEGER | Optional expiration timestamp |

### cache_files

| Column | Type | Description |
|--------|------|-------------|
| cache_key | TEXT | Primary key |
| file_type | TEXT | "audio" or "coverArt" |
| file_path | TEXT | Absolute file path |
| size_bytes | INTEGER | File size |
| created_at | INTEGER | Timestamp |
| last_accessed | INTEGER | Timestamp for LRU |
| resource_id | INTEGER | Optional track/album ID |

### cache_favorites

| Column | Type | Description |
|--------|------|-------------|
| track_id | INTEGER | Primary key |
| added_at | INTEGER | Timestamp |

## Performance Considerations

1. **Automatic Cache Updates**: Last accessed timestamps update on every read
2. **Background Eviction**: Runs after every write operation
3. **Optimistic Reads**: Cache is checked first, API only called on miss
4. **Silent Failures**: Cache errors don't disrupt user experience

## Future Enhancements

Potential improvements for future releases:

- [ ] Smart pre-caching based on listening history
- [ ] WiFi-only download option
- [ ] Download queue with priority
- [ ] Offline mode indicator
- [ ] Selective album/playlist download UI
- [ ] Export/import cache for backup
- [ ] Cache warming on login

## Testing

The cache system includes:

- Database schema migrations (for future updates)
- LRU eviction stress testing
- Cache statistics accuracy
- Concurrent access handling

To test manually:

1. Enable cache in Settings
2. Browse albums/artists (check metadata caching)
3. Play tracks (check audio caching)
4. Monitor storage usage in Settings
5. Test cache clearing functions

## Dependencies

- `sqflite: ^2.4.1` - SQLite database
- `path_provider: ^2.1.5` - File system paths
- `path: ^1.9.0` - Path manipulation
