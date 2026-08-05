/// Data models for the Funkwhale API.
///
/// These are intentionally kept simple and use factory constructors
/// for JSON deserialization rather than code generation, keeping
/// the project lean.
library;

// Helper utilities for defensive JSON parsing. Many Funkwhale instances
// return inconsistent shapes (int, map, list) for the same field. These
// helpers normalize common cases to reduce `as Map` cast failures.
Map<String, dynamic> _toMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  // Some JSON decoders / transformers yield Map with non-String keys or a
  // plain Map; coerce rather than silently dropping nested objects.
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

// ── Cover / Attachment ──────────────────────────────────────────────────

class CoverUrls {
  final String? original;
  final String? mediumSquareCrop;
  final String? smallSquareCrop;
  final String? largeSquareCrop;

  const CoverUrls({
    this.original,
    this.mediumSquareCrop,
    this.smallSquareCrop,
    this.largeSquareCrop,
  });

  factory CoverUrls.fromJson(Map<String, dynamic> json) {
    return CoverUrls(
      original: json['original'] as String?,
      mediumSquareCrop: json['medium_square_crop'] as String?,
      smallSquareCrop: json['small_square_crop'] as String?,
      largeSquareCrop: json['large_square_crop'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'medium_square_crop': mediumSquareCrop,
      'small_square_crop': smallSquareCrop,
      'large_square_crop': largeSquareCrop,
    };
  }

  /// Returns the best available URL, preferring medium crop.
  String? get best => mediumSquareCrop ?? largeSquareCrop ?? original;
  String? get large => largeSquareCrop ?? original ?? mediumSquareCrop;

  /// Smallest useful crop for list/grid thumbnails (decode-cheap).
  String? get thumb =>
      smallSquareCrop ?? mediumSquareCrop ?? largeSquareCrop ?? original;
}

class Cover {
  final String uuid;
  final CoverUrls urls;

  const Cover({required this.uuid, required this.urls});

  factory Cover.fromJson(Map<String, dynamic> json) {
    return Cover(
      uuid: json['uuid'] as String? ?? '',
      urls: CoverUrls.fromJson(_toMap(json['urls'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {'uuid': uuid, 'urls': urls.toJson()};
  }

  /// All non-null, non-empty cover URLs across all crop sizes.
  Set<String> get allUrls {
    final result = <String>{};
    if (urls.original != null && urls.original!.isNotEmpty) {
      result.add(urls.original!);
    }
    if (urls.mediumSquareCrop != null && urls.mediumSquareCrop!.isNotEmpty) {
      result.add(urls.mediumSquareCrop!);
    }
    if (urls.smallSquareCrop != null && urls.smallSquareCrop!.isNotEmpty) {
      result.add(urls.smallSquareCrop!);
    }
    if (urls.largeSquareCrop != null && urls.largeSquareCrop!.isNotEmpty) {
      result.add(urls.largeSquareCrop!);
    }
    return result;
  }
}

// ── Artist ──────────────────────────────────────────────────────────────

class Artist {
  final int id;
  final String name;
  final String? mbid;
  final String? contentCategory;
  final Cover? cover;
  final int tracksCount;
  final List<Album> albums;
  final List<String> tags;
  final DateTime? creationDate;

  const Artist({
    required this.id,
    required this.name,
    this.mbid,
    this.contentCategory,
    this.cover,
    this.tracksCount = 0,
    this.albums = const [],
    this.tags = const [],
    this.creationDate,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse cover - API returns int ID in lists, object in details
    Cover? parseCover(dynamic coverData) {
      if (coverData == null) return null;
      if (coverData is Map<String, dynamic>) {
        return Cover.fromJson(coverData);
      }
      // If it's an int (just an ID), we can't use it, return null
      return null;
    }

    return Artist(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown Artist',
      mbid: json['mbid'] as String?,
      contentCategory: json['content_category'] as String?,
      cover: parseCover(json['cover']) ?? parseCover(json['attachment_cover']),
      tracksCount: (json['tracks_count'] as num?)?.toInt() ?? 0,
      albums:
          (json['albums'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(_toMap(e)))
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mbid': mbid,
      'content_category': contentCategory,
      'cover': cover?.toJson(),
      'tracks_count': tracksCount,
      'albums': albums.map((a) => a.toJson()).toList(),
      'tags': tags,
      'creation_date': creationDate?.toIso8601String(),
    };
  }

  String? get coverUrl =>
      cover?.urls.best ?? (albums.isNotEmpty ? albums.first.coverUrl : null);

  /// Thumbnail-sized cover for dense lists/grids.
  String? get thumbCoverUrl =>
      cover?.urls.thumb ??
      (albums.isNotEmpty ? albums.first.thumbCoverUrl : null);
}

// ── Album ───────────────────────────────────────────────────────────────

class Album {
  final int id;
  final String title;
  final Artist? artist;
  final Cover? cover;
  final String? releaseDate;
  final int tracksCount;
  final int? duration;
  final bool isPlayable;
  final List<String> tags;
  final DateTime? creationDate;
  final List<Track> tracks;
  final String? mbid;

  const Album({
    required this.id,
    required this.title,
    this.artist,
    this.cover,
    this.releaseDate,
    this.tracksCount = 0,
    this.duration,
    this.isPlayable = true,
    this.tags = const [],
    this.creationDate,
    this.tracks = const [],
    this.mbid,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse cover - API returns int ID in lists, object in details
    Cover? parseCover(dynamic coverData) {
      if (coverData == null) return null;
      if (coverData is Map<String, dynamic>) {
        return Cover.fromJson(coverData);
      }
      return null;
    }

    // Helper to safely parse artist
    Artist? parseArtist(dynamic artistData) {
      if (artistData == null) return null;
      if (artistData is Map<String, dynamic>) {
        return Artist.fromJson(artistData);
      }
      return null;
    }

    return Album(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Unknown Album',
      artist: parseArtist(json['artist']),
      cover: parseCover(json['cover']),
      releaseDate: json['release_date'] as String?,
      tracksCount: (json['tracks_count'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt(),
      isPlayable: json['is_playable'] as bool? ?? true,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(_toMap(e)))
              .toList() ??
          const [],
      mbid: json['mbid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist?.toJson(),
      'cover': cover?.toJson(),
      'release_date': releaseDate,
      'tracks_count': tracksCount,
      'duration': duration,
      'is_playable': isPlayable,
      'tags': tags,
      'creation_date': creationDate?.toIso8601String(),
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'mbid': mbid,
    };
  }

  String? get coverUrl => cover?.urls.best;
  String? get largeCoverUrl => cover?.urls.large;

  /// Thumbnail-sized cover for dense lists/grids.
  String? get thumbCoverUrl => cover?.urls.thumb;

  String get releaseYear {
    if (releaseDate == null) return '';
    return releaseDate!.split('-').first;
  }

  /// Formatted duration (e.g. "45 min" or "1h 12m")
  String get formattedDuration {
    if (duration == null || duration == 0) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  /// All deduplicated, non-null, non-empty cover URLs across the album,
  /// its artist, and all associated tracks. Useful for cache invalidation.
  Set<String> get allCoverUrls {
    final urls = <String>{};
    if (cover != null) urls.addAll(cover!.allUrls);
    if (artist?.cover != null) urls.addAll(artist!.cover!.allUrls);
    for (final track in tracks) {
      if (track.cover != null) urls.addAll(track.cover!.allUrls);
      if (track.album?.cover != null) urls.addAll(track.album!.cover!.allUrls);
    }
    return urls;
  }
}

// ── Track ───────────────────────────────────────────────────────────────

class Track {
  final int id;
  final String title;
  final Artist? artist;
  final Album? album;
  final String? listenUrl;
  final int? position;
  final int? discNumber;
  final Cover? cover;
  final bool isPlayable;
  final List<String> tags;
  final List<Upload> uploads;
  final DateTime? creationDate;
  final String? mbid;

  const Track({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.listenUrl,
    this.position,
    this.discNumber,
    this.cover,
    this.isPlayable = true,
    this.tags = const [],
    this.uploads = const [],
    this.creationDate,
    this.mbid,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse cover - API returns int ID in lists, object in details
    Cover? parseCover(dynamic coverData) {
      if (coverData == null) return null;
      if (coverData is Map<String, dynamic>) {
        return Cover.fromJson(coverData);
      }
      return null;
    }

    // Helper to safely parse artist
    Artist? parseArtist(dynamic artistData) {
      if (artistData == null) return null;
      if (artistData is Map<String, dynamic>) {
        return Artist.fromJson(artistData);
      }
      return null;
    }

    // Helper to safely parse album
    Album? parseAlbum(dynamic albumData) {
      if (albumData == null) return null;
      if (albumData is Map<String, dynamic>) {
        return Album.fromJson(albumData);
      }
      return null;
    }

    return Track(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Unknown Track',
      artist: parseArtist(json['artist']),
      album: parseAlbum(json['album']),
      listenUrl: json['listen_url'] as String?,
      position: (json['position'] as num?)?.toInt(),
      discNumber: (json['disc_number'] as num?)?.toInt(),
      cover: parseCover(json['cover']),
      isPlayable: json['is_playable'] as bool? ?? true,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      uploads:
          (json['uploads'] as List<dynamic>?)
              ?.map((e) => Upload.fromJson(_toMap(e)))
              .toList() ??
          const [],
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      mbid: json['mbid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist?.toJson(),
      'album': album?.toJson(),
      'listen_url': listenUrl,
      'position': position,
      'disc_number': discNumber,
      'cover': cover?.toJson(),
      'is_playable': isPlayable,
      'tags': tags,
      'uploads': uploads.map((u) => u.toJson()).toList(),
      'creation_date': creationDate?.toIso8601String(),
      'mbid': mbid,
    };
  }

  /// Compact JSON for queue persistence — omits tags and nested album tracks
  /// so long queues can be serialized without multi-MB SharedPreferences writes.
  Map<String, dynamic> toPersistenceJson() {
    return {
      'id': id,
      'title': title,
      'listen_url': listenUrl,
      'position': position,
      'disc_number': discNumber,
      'is_playable': isPlayable,
      'mbid': mbid,
      'cover': cover?.toJson(),
      if (artist != null)
        'artist': {
          'id': artist!.id,
          'name': artist!.name,
          'content_category': artist!.contentCategory,
          'cover': artist!.cover?.toJson(),
        },
      if (album != null)
        'album': {
          'id': album!.id,
          'title': album!.title,
          'cover': album!.cover?.toJson(),
          if (album!.artist != null)
            'artist': {'id': album!.artist!.id, 'name': album!.artist!.name},
        },
      // Duration lives on the first upload; keep only that field set.
      if (uploads.isNotEmpty)
        'uploads': [
          {
            'uuid': uploads.first.uuid,
            'duration': uploads.first.duration,
            'mimetype': uploads.first.mimetype,
            'listen_url': uploads.first.listenUrl,
          },
        ],
    };
  }

  /// Best cover URL: track cover → album cover
  String? get coverUrl => cover?.urls.best ?? album?.cover?.urls.best;

  String? get largeCoverUrl => cover?.urls.large ?? album?.cover?.urls.large;

  /// Thumbnail-sized cover for dense track lists.
  String? get thumbCoverUrl =>
      cover?.urls.thumb ?? album?.cover?.urls.thumb ?? coverUrl;

  String get artistName => artist?.name ?? 'Unknown Artist';
  String get albumTitle => album?.title ?? '';

  /// Duration in seconds from the first upload, if available.
  int? get duration => uploads.isNotEmpty ? uploads.first.duration : null;

  bool get isPodcast => artist?.contentCategory == 'podcast';
}

// ── Upload ──────────────────────────────────────────────────────────────

class Upload {
  final String uuid;
  final int? duration;
  final int? bitrate;
  final int? size;
  final String? mimetype;
  final String? listenUrl;

  const Upload({
    required this.uuid,
    this.duration,
    this.bitrate,
    this.size,
    this.mimetype,
    this.listenUrl,
  });

  factory Upload.fromJson(Map<String, dynamic> json) {
    return Upload(
      uuid: json['uuid'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt(),
      bitrate: (json['bitrate'] as num?)?.toInt(),
      size: (json['size'] as num?)?.toInt(),
      mimetype: json['mimetype'] as String?,
      listenUrl: json['listen_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'duration': duration,
      'bitrate': bitrate,
      'size': size,
      'mimetype': mimetype,
      'listen_url': listenUrl,
    };
  }
}

// ── Listening ───────────────────────────────────────────────────────────

class Listening {
  final int id;
  final Track track;
  final DateTime? created;
  const Listening({required this.id, required this.track, this.created});
  factory Listening.fromJson(Map<String, dynamic> json) {
    final trackRaw = json['track'];
    if (trackRaw is! Map) {
      // Stock / incomplete payloads (or non-playable track prefetch misses)
      // used to crash Track.fromJson. Rich-only listing avoids this; still
      // fail clearly if a bad row slips through.
      throw FormatException(
        'Listening ${json['id']} missing track object',
        json,
      );
    }
    return Listening(
      id: (json['id'] as num).toInt(),
      track: Track.fromJson(_toMap(trackRaw)),
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String)
          : (json['creation_date'] != null
                ? DateTime.tryParse(json['creation_date'] as String)
                : null),
    );
  }
}

// ── Playlist ────────────────────────────────────────────────────────────

class Playlist {
  final int id;
  final String name;
  final int tracksCount;
  final int? duration;
  final bool isPlayable;
  final List<String> albumCovers;
  final Cover? cover;
  final String? privacyLevel;
  final DateTime? creationDate;
  final DateTime? modificationDate;

  const Playlist({
    required this.id,
    required this.name,
    this.tracksCount = 0,
    this.duration,
    this.isPlayable = true,
    this.albumCovers = const [],
    this.cover,
    this.privacyLevel,
    this.creationDate,
    this.modificationDate,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    Cover? parseCover(dynamic coverData) {
      if (coverData == null) return null;
      if (coverData is Map<String, dynamic>) {
        return Cover.fromJson(coverData);
      }
      if (coverData is Map) {
        return Cover.fromJson(Map<String, dynamic>.from(coverData));
      }
      return null;
    }

    return Playlist(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Untitled',
      tracksCount: (json['tracks_count'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt(),
      isPlayable: json['is_playable'] as bool? ?? true,
      albumCovers:
          (json['album_covers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      cover: parseCover(json['cover']),
      privacyLevel: json['privacy_level'] as String?,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      modificationDate: json['modification_date'] != null
          ? DateTime.tryParse(json['modification_date'] as String)
          : null,
    );
  }

  /// User-uploaded playlist cover only (no album-art fallback).
  ///
  /// Use this when deciding whether to show custom art vs a mosaic of
  /// [albumCovers].
  String? get customCoverUrl => cover?.urls.best;

  /// Custom cover first, otherwise the first derived album cover.
  String? get coverUrl =>
      customCoverUrl ?? (albumCovers.isNotEmpty ? albumCovers.first : null);

  /// Thumbnail-sized cover for dense lists.
  String? get thumbCoverUrl => cover?.urls.thumb ?? coverUrl;

  /// Formatted duration (e.g. "45 min" or "1h 12m")
  String get formattedDuration {
    if (duration == null || duration == 0) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }
}

class PlaylistTrack {
  final Track track;
  final int? index;
  final DateTime? creationDate;

  const PlaylistTrack({required this.track, this.index, this.creationDate});

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      track: Track.fromJson(_toMap(json['track'])),
      index: (json['index'] as num?)?.toInt(),
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }
}

// ── Favorite ────────────────────────────────────────────────────────────

class Favorite {
  final int id;
  final Track track;
  final DateTime? creationDate;

  const Favorite({required this.id, required this.track, this.creationDate});

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: (json['id'] as num).toInt(),
      track: Track.fromJson(_toMap(json['track'])),
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }
}

// ── Search Result ───────────────────────────────────────────────────────

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Track> tracks;
  final List<Tag> tags;

  const SearchResult({
    this.artists = const [],
    this.albums = const [],
    this.tracks = const [],
    this.tags = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      artists:
          (json['artists'] as List<dynamic>?)
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      albums:
          (json['albums'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isEmpty =>
      artists.isEmpty && albums.isEmpty && tracks.isEmpty && tags.isEmpty;
}

// ── Tag ─────────────────────────────────────────────────────────────────

class Tag {
  final String name;
  final DateTime? creationDate;

  const Tag({required this.name, this.creationDate});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      name: json['name'] as String? ?? '',
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }
}

// ── Podcast Channel ─────────────────────────────────────────────────────

class ChannelArtist {
  final int id;
  final String name;
  final String? contentCategory;
  final Cover? cover;
  final String? descriptionText;
  final int? tracksCount;
  final List<String> tags;

  const ChannelArtist({
    required this.id,
    required this.name,
    this.contentCategory,
    this.cover,
    this.descriptionText,
    this.tracksCount,
    this.tags = const [],
  });

  factory ChannelArtist.fromJson(Map<String, dynamic> json) {
    Cover? parseCover(dynamic v) {
      if (v is Map<String, dynamic>) return Cover.fromJson(v);
      return null;
    }

    String? parseDescription(dynamic v) {
      if (v is Map<String, dynamic>) return v['text'] as String?;
      if (v is String) return v;
      return null;
    }

    return ChannelArtist(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      contentCategory: json['content_category'] as String?,
      cover: parseCover(json['cover']),
      descriptionText: parseDescription(json['description']),
      tracksCount: (json['tracks_count'] as num?)?.toInt(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content_category': contentCategory,
    'cover': cover?.toJson(),
    'tracks_count': tracksCount,
    'tags': tags,
  };

  String? get coverUrl => cover?.urls.best;
}

class Channel {
  final String uuid;
  final ChannelArtist artist;
  final String? rssUrl;
  final String? url;
  final int? downloadsCount;
  final DateTime? creationDate;

  const Channel({
    required this.uuid,
    required this.artist,
    this.rssUrl,
    this.url,
    this.downloadsCount,
    this.creationDate,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      uuid: json['uuid'] as String? ?? '',
      artist: ChannelArtist.fromJson(_toMap(json['artist'])),
      rssUrl: json['rss_url'] as String?,
      url: json['url'] as String?,
      downloadsCount: (json['downloads_count'] as num?)?.toInt(),
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'artist': artist.toJson(),
    'rss_url': rssUrl,
    'url': url,
    'downloads_count': downloadsCount,
    'creation_date': creationDate?.toIso8601String(),
  };

  String get name => artist.name;
  String? get description => artist.descriptionText;
  String? get coverUrl => artist.coverUrl;
  bool get isPodcast => artist.contentCategory == 'podcast';
}

// ── Radios / Filters ───────────────────────────────────────────────────

class Filter {
  final String? type;
  final String? label;
  final String? helpText;
  final List<dynamic>? fields;

  const Filter({this.type, this.label, this.helpText, this.fields});

  factory Filter.fromJson(Map<String, dynamic> json) {
    return Filter(
      type: json['type'] as String?,
      label: json['label'] as String?,
      helpText: json['help_text'] as String?,
      fields: json['fields'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      'help_text': helpText,
      'fields': fields,
    };
  }
}

class Radio {
  final int id;
  final bool? isPublic;
  final String name;
  final DateTime? creationDate;
  final Map<String, dynamic>? user;

  /// Filter list, e.g. `[{"type":"artist","ids":[1],"names":["…"]}]`.
  /// Funkwhale stores custom-radio config as a JSON array of filters.
  final List<Map<String, dynamic>>? config;
  final String? description;
  final Cover? cover;

  const Radio({
    required this.id,
    this.isPublic,
    required this.name,
    this.creationDate,
    this.user,
    this.config,
    this.description,
    this.cover,
  });

  /// True when this radio is owned by a user (not a pre-programmed/system radio).
  bool get isCustom => user != null;

  factory Radio.fromJson(Map<String, dynamic> json) {
    // Be defensive: some servers may return `user` as an int, a map, or
    // (unexpectedly) as a list. Normalize to Map<String, dynamic> when
    // possible so consumers can read user['id'] etc.
    dynamic userRaw = json['user'];
    Map<String, dynamic>? userMap;
    if (userRaw is Map<String, dynamic>) {
      userMap = userRaw;
    } else if (userRaw is int) {
      userMap = {'id': userRaw};
    } else if (userRaw is List &&
        userRaw.isNotEmpty &&
        userRaw.first is Map<String, dynamic>) {
      userMap = userRaw.first as Map<String, dynamic>;
    } else {
      userMap = null;
    }

    // Config is a list of filter maps. Accept a single map for resilience.
    List<Map<String, dynamic>>? configList;
    final configRaw = json['config'];
    if (configRaw is List) {
      configList = configRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (configRaw is Map) {
      configList = [Map<String, dynamic>.from(configRaw)];
    }

    Cover? parseCover(dynamic coverData) {
      if (coverData == null) return null;
      if (coverData is Map<String, dynamic>) {
        return Cover.fromJson(coverData);
      }
      if (coverData is Map) {
        return Cover.fromJson(Map<String, dynamic>.from(coverData));
      }
      return null;
    }

    return Radio(
      id: (json['id'] as num).toInt(),
      isPublic: json['is_public'] as bool?,
      name: json['name'] as String? ?? '',
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      user: userMap,
      config: configList,
      description: json['description'] as String?,
      cover: parseCover(json['cover']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_public': isPublic,
      'name': name,
      'creation_date': creationDate?.toIso8601String(),
      'user': user,
      'config': config,
      'description': description,
      'cover': cover?.toJson(),
    };
  }

  String? get coverUrl => cover?.urls.best;
  String? get thumbCoverUrl => cover?.urls.thumb ?? coverUrl;
}

/// Per-filter result from `POST /api/v1/radios/radios/validate/`.
class RadioFilterValidation {
  final List<String> errors;
  final int? candidateCount;
  final List<Track> sample;

  const RadioFilterValidation({
    this.errors = const [],
    this.candidateCount,
    this.sample = const [],
  });

  bool get isValid => errors.isEmpty;

  factory RadioFilterValidation.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    int? count;
    final sample = <Track>[];
    if (candidates is Map) {
      final c = candidates['count'];
      if (c is num) count = c.toInt();
      final s = candidates['sample'];
      if (s is List) {
        for (final item in s) {
          if (item is Map) {
            sample.add(Track.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }
    final errorsRaw = json['errors'];
    final errors = <String>[];
    if (errorsRaw is List) {
      for (final e in errorsRaw) {
        if (e != null) errors.add(e.toString());
      }
    }
    return RadioFilterValidation(
      errors: errors,
      candidateCount: count,
      sample: sample,
    );
  }
}

class RadioSession {
  final int id;
  final String? radioType;
  final String?
  relatedObjectId; // server may return string or int; normalize to string
  final int? user; // sometimes a nested object, sometimes an integer id
  final DateTime? creationDate;
  final int? customRadio;
  final Map<String, dynamic>? config;

  const RadioSession({
    required this.id,
    this.radioType,
    this.relatedObjectId,
    this.user,
    this.creationDate,
    this.customRadio,
    this.config,
  });

  factory RadioSession.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: Funkwhale instances vary in types for these fields.
    String? related;
    final rel = json['related_object_id'];
    if (rel != null) {
      related = rel is String ? rel : rel.toString();
    }

    int? userId;
    final u = json['user'];
    if (u is int) {
      userId = u;
    } else if (u is Map && u.containsKey('id')) {
      userId = (u['id'] is int)
          ? u['id'] as int
          : int.tryParse(u['id'].toString());
    }

    int? custom;
    final c = json['custom_radio'];
    if (c is int) {
      custom = c;
    } else if (c is bool) {
      custom = c ? 1 : 0;
    }

    Map<String, dynamic>? cfg;
    final cfgRaw = json['config'];
    if (cfgRaw is Map<String, dynamic>) cfg = cfgRaw;

    return RadioSession(
      id: (json['id'] as num).toInt(),
      radioType: json['radio_type'] as String?,
      relatedObjectId: related,
      user: userId,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      customRadio: custom,
      config: cfg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'radio_type': radioType,
      'related_object_id': relatedObjectId,
      'user': user,
      'creation_date': creationDate?.toIso8601String(),
      'custom_radio': customRadio,
      'config': config,
    };
  }
}

class RadioSessionTrackCreate {
  final int session;
  final int? count;

  const RadioSessionTrackCreate({required this.session, this.count});

  factory RadioSessionTrackCreate.fromJson(Map<String, dynamic> json) {
    return RadioSessionTrackCreate(
      session: (json['session'] as num).toInt(),
      count: (json['count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'session': session, 'count': count};
  }
}

// ── Library ─────────────────────────────────────────────────────────────

class Library {
  final String uuid;
  final String name;
  final String? description;
  final String privacyLevel;
  final int uploadsCount;
  final int size;
  final DateTime? creationDate;

  const Library({
    required this.uuid,
    required this.name,
    this.description,
    required this.privacyLevel,
    required this.uploadsCount,
    required this.size,
    this.creationDate,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      uuid: json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      privacyLevel: json['privacy_level'] as String? ?? 'me',
      uploadsCount: (json['uploads_count'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
    );
  }

  String get privacyLevelLabel {
    switch (privacyLevel) {
      case 'everyone':
        return 'Public';
      case 'instance':
        return 'Instance';
      default:
        return 'Private';
    }
  }
}

// ── UploadForOwner ───────────────────────────────────────────────────────

class UploadForOwner {
  final String uuid;
  final String? filename;
  final DateTime? creationDate;
  final String? mimetype;
  final String? library;
  final String importStatus;
  final Map<String, dynamic> importDetails;
  final Map<String, dynamic>? importMetadata;
  final String? importReference;
  final int? duration;
  final int? bitrate;
  final int? size;
  final DateTime? importDate;

  const UploadForOwner({
    required this.uuid,
    this.filename,
    this.creationDate,
    this.mimetype,
    this.library,
    required this.importStatus,
    required this.importDetails,
    this.importMetadata,
    this.importReference,
    this.duration,
    this.bitrate,
    this.size,
    this.importDate,
  });

  factory UploadForOwner.fromJson(Map<String, dynamic> json) {
    // duration/bitrate/size come back as JSON integers, but Dart's json decoder
    // can return num (int or double) depending on the value. Coerce safely.
    int? asInt(Object? v) =>
        v == null ? null : (v is int ? v : (v as num).round());

    return UploadForOwner(
      uuid: json['uuid'] as String? ?? '',
      filename: json['filename'] as String?,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      mimetype: json['mimetype'] as String?,
      library: json['library'] is Map<String, dynamic>
          ? (json['library'] as Map<String, dynamic>)['uuid'] as String?
          : json['library'] as String?,
      importStatus: json['import_status'] as String? ?? 'pending',
      importDetails: json['import_details'] is Map<String, dynamic>
          ? json['import_details'] as Map<String, dynamic>
          : {},
      importMetadata: json['import_metadata'] is Map<String, dynamic>
          ? json['import_metadata'] as Map<String, dynamic>
          : null,
      importReference: json['import_reference'] as String?,
      duration: asInt(json['duration']),
      bitrate: asInt(json['bitrate']),
      size: asInt(json['size']),
      importDate: json['import_date'] != null
          ? DateTime.tryParse(json['import_date'] as String)
          : null,
    );
  }

  bool get isFinished => importStatus == 'finished';
  bool get isErrored => importStatus == 'errored';
  bool get isPending => importStatus == 'pending';
  bool get isDraft => importStatus == 'draft';
  bool get isSkipped => importStatus == 'skipped';
}

// ── Authenticated user (GET /api/v1/users/me/) ──────────────────────────

/// Privacy level for activity visibility on Funkwhale.
///
/// * `me` — Only me
/// * `followers` — Me and my followers
/// * `instance` — Everyone on my instance, and my followers
/// * `everyone` — Everyone, including people on other instances
enum PrivacyLevel {
  me,
  followers,
  instance,
  everyone;

  static PrivacyLevel fromString(String? value) {
    switch (value) {
      case 'followers':
        return PrivacyLevel.followers;
      case 'instance':
        return PrivacyLevel.instance;
      case 'everyone':
        return PrivacyLevel.everyone;
      default:
        return PrivacyLevel.me;
    }
  }

  String get apiValue {
    switch (this) {
      case PrivacyLevel.me:
        return 'me';
      case PrivacyLevel.followers:
        return 'followers';
      case PrivacyLevel.instance:
        return 'instance';
      case PrivacyLevel.everyone:
        return 'everyone';
    }
  }

  String get label {
    switch (this) {
      case PrivacyLevel.me:
        return 'Only me';
      case PrivacyLevel.followers:
        return 'Me and my followers';
      case PrivacyLevel.instance:
        return 'Everyone on my instance';
      case PrivacyLevel.everyone:
        return 'Everyone';
    }
  }

  String get description {
    switch (this) {
      case PrivacyLevel.me:
        return 'Only you can see your activity';
      case PrivacyLevel.followers:
        return 'You and your followers can see your activity';
      case PrivacyLevel.instance:
        return 'Everyone on your instance, and your followers';
      case PrivacyLevel.everyone:
        return 'Everyone, including people on other instances';
    }
  }
}

/// Current authenticated user as returned by `/api/v1/users/me/`.
///
/// The OpenAPI schema lists only [UserWrite] fields for this endpoint, but the
/// real Funkwhale `MeSerializer` also includes identity fields used here.
class MeUser {
  final int id;
  final String username;
  final String? fullUsername;
  final String name;
  final String? email;
  final PrivacyLevel privacyLevel;
  final Cover? avatar;
  final String? summaryText;
  final DateTime? dateJoined;
  final bool isStaff;
  final bool isSuperuser;

  /// Instance permission flags from `MeSerializer.get_permissions()`.
  ///
  /// Keys: `library`, `moderation`, `settings`. Superusers and users with the
  /// corresponding `permission_*` flag (or defaults) get `true`.
  final Map<String, bool> permissions;

  /// Scoped token for `?token=` on listen URLs (browser media auth).
  final String? listenToken;

  /// Whether TOTP 2FA is confirmed for this account.
  final bool totpEnabled;

  /// Whether the instance requires this password user to set up TOTP.
  final bool totpRequired;

  /// Whether the account has a local password (false for SSO-only users).
  final bool hasUsablePassword;

  const MeUser({
    required this.id,
    required this.username,
    this.fullUsername,
    this.name = '',
    this.email,
    this.privacyLevel = PrivacyLevel.me,
    this.avatar,
    this.summaryText,
    this.dateJoined,
    this.isStaff = false,
    this.isSuperuser = false,
    this.permissions = const {},
    this.listenToken,
    this.totpEnabled = false,
    this.totpRequired = false,
    this.hasUsablePassword = true,
  });

  factory MeUser.fromJson(Map<String, dynamic> json) {
    Cover? avatar;
    final avatarData = json['avatar'];
    if (avatarData is Map<String, dynamic>) {
      // Attachment shape: { uuid, urls: { ... } } — same as Cover
      try {
        avatar = Cover.fromJson(avatarData);
      } catch (_) {
        avatar = null;
      }
    }

    String? summaryText;
    final summary = json['summary'];
    if (summary is Map<String, dynamic>) {
      summaryText = summary['text'] as String?;
    } else if (summary is String) {
      summaryText = summary;
    }

    String? listenToken;
    final tokens = json['tokens'];
    if (tokens is Map) {
      listenToken = tokens['listen'] as String?;
    }

    final permissions = <String, bool>{};
    final rawPerms = json['permissions'];
    if (rawPerms is Map) {
      for (final entry in rawPerms.entries) {
        permissions[entry.key.toString()] = entry.value == true;
      }
    }
    // Superuser always has every instance permission (server does the same).
    if (json['is_superuser'] == true) {
      for (final key in const ['library', 'moderation', 'settings']) {
        permissions[key] = true;
      }
    }

    return MeUser(
      id: (json['id'] as num?)?.toInt() ?? (json['pk'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      fullUsername: json['full_username'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      privacyLevel: PrivacyLevel.fromString(json['privacy_level'] as String?),
      avatar: avatar,
      summaryText: summaryText,
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'] as String)
          : null,
      isStaff: json['is_staff'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      permissions: permissions,
      listenToken: listenToken,
      totpEnabled: json['totp_enabled'] == true,
      totpRequired: json['totp_required'] == true,
      hasUsablePassword: json['has_usable_password'] != false,
    );
  }

  MeUser copyWith({
    int? id,
    String? username,
    String? fullUsername,
    String? name,
    String? email,
    PrivacyLevel? privacyLevel,
    Cover? avatar,
    String? summaryText,
    DateTime? dateJoined,
    bool? isStaff,
    bool? isSuperuser,
    Map<String, bool>? permissions,
    String? listenToken,
    bool? totpEnabled,
    bool? totpRequired,
    bool? hasUsablePassword,
  }) {
    return MeUser(
      id: id ?? this.id,
      username: username ?? this.username,
      fullUsername: fullUsername ?? this.fullUsername,
      name: name ?? this.name,
      email: email ?? this.email,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      avatar: avatar ?? this.avatar,
      summaryText: summaryText ?? this.summaryText,
      dateJoined: dateJoined ?? this.dateJoined,
      isStaff: isStaff ?? this.isStaff,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      permissions: permissions ?? this.permissions,
      listenToken: listenToken ?? this.listenToken,
      totpEnabled: totpEnabled ?? this.totpEnabled,
      totpRequired: totpRequired ?? this.totpRequired,
      hasUsablePassword: hasUsablePassword ?? this.hasUsablePassword,
    );
  }

  /// Display name falling back to username when empty.
  String get displayName => name.trim().isEmpty ? username : name;

  /// True when the user may use library manage endpoints.
  ///
  /// Derived from `permissions.library` (includes superuser-derived grants).
  bool get canManageLibrary => permissions['library'] == true || isSuperuser;

  /// True when the user may edit instance-level preferences.
  ///
  /// Derived from `permissions.settings` (includes superuser-derived grants).
  bool get canManageSettings => permissions['settings'] == true || isSuperuser;

  /// True when the user may use user / invitation manage endpoints.
  ///
  /// Derived from `permissions.settings` (includes superuser-derived grants).
  /// First-party Tayra OAuth grants `instance:users` / `instance:invitations`
  /// when the user holds the settings permission.
  bool get canManageUsers => permissions['settings'] == true || isSuperuser;
}

// ── TOTP 2FA ────────────────────────────────────────────────────────────

/// Status from `GET /api/v1/users/me/2fa/`.
class TotpStatus {
  final bool enabled;
  final bool required;
  final bool force2fa;
  final bool isPasswordUser;
  final int recoveryCodesRemaining;

  const TotpStatus({
    this.enabled = false,
    this.required = false,
    this.force2fa = false,
    this.isPasswordUser = true,
    this.recoveryCodesRemaining = 0,
  });

  factory TotpStatus.fromJson(Map<String, dynamic> json) {
    return TotpStatus(
      enabled: json['enabled'] == true,
      required: json['required'] == true,
      force2fa: json['force_2fa'] == true,
      isPasswordUser: json['is_password_user'] != false,
      recoveryCodesRemaining:
          (json['recovery_codes_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Pending enrollment payload from `POST /api/v1/users/me/2fa/setup/`.
class TotpSetup {
  final String secret;
  final String otpauthUri;
  final int digits;
  final int period;

  const TotpSetup({
    required this.secret,
    required this.otpauthUri,
    this.digits = 6,
    this.period = 30,
  });

  factory TotpSetup.fromJson(Map<String, dynamic> json) {
    return TotpSetup(
      secret: json['secret'] as String? ?? '',
      otpauthUri: json['otpauth_uri'] as String? ?? '',
      digits: (json['digits'] as num?)?.toInt() ?? 6,
      period: (json['period'] as num?)?.toInt() ?? 30,
    );
  }
}

/// Result of confirming TOTP setup (includes one-time recovery codes).
class TotpConfirmResult {
  final bool enabled;
  final List<String> recoveryCodes;

  const TotpConfirmResult({required this.enabled, required this.recoveryCodes});

  factory TotpConfirmResult.fromJson(Map<String, dynamic> json) {
    final raw = json['recovery_codes'];
    final codes = <String>[];
    if (raw is List) {
      for (final c in raw) {
        if (c != null) codes.add(c.toString());
      }
    }
    return TotpConfirmResult(
      enabled: json['enabled'] != false,
      recoveryCodes: codes,
    );
  }
}

// ── Instance admin settings (global preferences) ────────────────────────

/// Field kind inferred from dynamic-preferences `field.class` for UI widgets.
enum GlobalPreferenceFieldKind {
  boolean,
  string,
  integer,
  choice,
  multiChoice,
  file,
  complex,
}

/// Choice entry from `additional_data.choices` (`[value, label]` pairs).
class GlobalPreferenceChoice {
  final String value;
  final String label;

  const GlobalPreferenceChoice({required this.value, required this.label});

  factory GlobalPreferenceChoice.fromDynamic(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final v = raw[0]?.toString() ?? '';
      final label = raw.length > 1 ? (raw[1]?.toString() ?? v) : v;
      return GlobalPreferenceChoice(value: v, label: label);
    }
    if (raw is Map) {
      final v = (raw['value'] ?? raw['id'] ?? '').toString();
      final label = (raw['label'] ?? raw['name'] ?? v).toString();
      return GlobalPreferenceChoice(value: v, label: label);
    }
    final s = raw?.toString() ?? '';
    return GlobalPreferenceChoice(value: s, label: s);
  }
}

/// Row from `GET /api/v1/instance/admin/settings/`.
///
/// Values are JSON-decoded Python values via dynamic-preferences `api_repr`
/// (bool/int/string/list/map/URL). Bulk update posts identifier → value.
class GlobalPreference {
  final String section;
  final String name;
  final String identifier;
  final dynamic defaultValue;
  final dynamic value;
  final String verboseName;
  final String helpText;
  final Map<String, dynamic> additionalData;
  final Map<String, dynamic> field;
  final GlobalPreferenceFieldKind fieldKind;
  final List<GlobalPreferenceChoice> choices;

  const GlobalPreference({
    required this.section,
    required this.name,
    required this.identifier,
    this.defaultValue,
    this.value,
    this.verboseName = '',
    this.helpText = '',
    this.additionalData = const {},
    this.field = const {},
    this.fieldKind = GlobalPreferenceFieldKind.string,
    this.choices = const [],
  });

  factory GlobalPreference.fromJson(Map<String, dynamic> json) {
    final field = _preferenceMap(json['field']);
    final additional = _preferenceMap(json['additional_data']);
    final fieldClass = (field['class'] as String?) ?? '';
    final kind = _inferPreferenceFieldKind(fieldClass, additional);
    final choices = _parsePreferenceChoices(additional['choices']);

    return GlobalPreference(
      section: json['section'] as String? ?? '',
      name: json['name'] as String? ?? '',
      identifier:
          json['identifier'] as String? ??
          _preferenceIdentifier(
            json['section'] as String?,
            json['name'] as String?,
          ),
      defaultValue: json['default'],
      value: json['value'],
      verboseName: json['verbose_name'] as String? ?? '',
      helpText: json['help_text'] as String? ?? '',
      additionalData: additional,
      field: field,
      fieldKind: kind,
      choices: choices,
    );
  }

  /// Copy with an optional new [value]. Pass [clearValue] to set value to null.
  GlobalPreference copyWith({dynamic value, bool clearValue = false}) {
    return GlobalPreference(
      section: section,
      name: name,
      identifier: identifier,
      defaultValue: defaultValue,
      value: clearValue ? null : (value ?? this.value),
      verboseName: verboseName,
      helpText: helpText,
      additionalData: additionalData,
      field: field,
      fieldKind: fieldKind,
      choices: choices,
    );
  }

  /// Human label for the tile title.
  String get displayName =>
      verboseName.trim().isEmpty ? name : verboseName.trim();

  /// Whether the preference can be edited in-app (not file/complex).
  bool get isEditable =>
      fieldKind != GlobalPreferenceFieldKind.file &&
      fieldKind != GlobalPreferenceFieldKind.complex;

  /// Boolean value (false when missing/non-bool).
  bool get boolValue => value == true;

  /// Integer value if parseable.
  int? get intValue {
    if (value is int) return value as int;
    if (value is num) return (value as num).toInt();
    if (value is String) return int.tryParse(value as String);
    return null;
  }

  /// String form of the current value for display / text editors.
  String get stringValue {
    if (value == null) return '';
    if (value is String) return value as String;
    if (value is List || value is Map) {
      try {
        // Prefer compact display for multi-select lists.
        if (value is List) {
          return (value as List).map((e) => e.toString()).join(', ');
        }
      } catch (_) {}
      return value.toString();
    }
    return value.toString();
  }

  /// Multi-choice selection as a list of string values.
  List<String> get multiValues {
    final v = value;
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    if (v is String && v.isNotEmpty) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Label for a single choice value, falling back to the raw value.
  String labelForChoice(String raw) {
    for (final c in choices) {
      if (c.value == raw) return c.label;
    }
    return raw;
  }
}

Map<String, dynamic> _preferenceMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

String _preferenceIdentifier(String? section, String? name) {
  final s = section ?? '';
  final n = name ?? '';
  if (s.isEmpty) return n;
  if (n.isEmpty) return s;
  return '${s}__$n';
}

GlobalPreferenceFieldKind _inferPreferenceFieldKind(
  String fieldClass,
  Map<String, dynamic> additional,
) {
  final c = fieldClass.toLowerCase();
  if (c.contains('boolean')) return GlobalPreferenceFieldKind.boolean;
  if (c.contains('integer') || c == 'intfield') {
    return GlobalPreferenceFieldKind.integer;
  }
  if (c.contains('multiplechoice') || c.contains('multiple_choice')) {
    return GlobalPreferenceFieldKind.multiChoice;
  }
  if (c.contains('choice') && !c.contains('file')) {
    return GlobalPreferenceFieldKind.choice;
  }
  if (c.contains('file') || c.contains('image')) {
    return GlobalPreferenceFieldKind.file;
  }
  if (c.contains('json') ||
      c.contains('duration') ||
      c.contains('date') ||
      c.contains('time') ||
      c.contains('decimal') ||
      c.contains('float') ||
      c.contains('model')) {
    return GlobalPreferenceFieldKind.complex;
  }
  // CharField / empty — promote to multi-choice if choices present and value is list.
  if (additional['choices'] != null &&
      (c.contains('char') || c.isEmpty) == false &&
      c.contains('multiple')) {
    return GlobalPreferenceFieldKind.multiChoice;
  }
  if (c.contains('char') || c.isEmpty) return GlobalPreferenceFieldKind.string;
  // Unknown field classes with choices: treat as choice.
  if (additional['choices'] is List) return GlobalPreferenceFieldKind.choice;
  return GlobalPreferenceFieldKind.complex;
}

List<GlobalPreferenceChoice> _parsePreferenceChoices(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(GlobalPreferenceChoice.fromDynamic).toList();
}

// ── Library admin (manage API) ──────────────────────────────────────────

/// Actor summary nested under manage library / upload objects.
class ManageActorRef {
  final int? id;
  final String? preferredUsername;
  final String? fullUsername;
  final String? domain;
  final bool isLocal;

  const ManageActorRef({
    this.id,
    this.preferredUsername,
    this.fullUsername,
    this.domain,
    this.isLocal = false,
  });

  factory ManageActorRef.fromJson(Map<String, dynamic> json) {
    return ManageActorRef(
      id: (json['id'] as num?)?.toInt(),
      preferredUsername: json['preferred_username'] as String?,
      fullUsername: json['full_username'] as String?,
      domain: json['domain'] as String?,
      isLocal: json['is_local'] as bool? ?? false,
    );
  }

  String get displayLabel {
    if (fullUsername != null && fullUsername!.isNotEmpty) return fullUsername!;
    if (preferredUsername != null && preferredUsername!.isNotEmpty) {
      return preferredUsername!;
    }
    return domain ?? 'Unknown';
  }
}

/// Library row from `GET /api/v1/manage/library/libraries/`.
class ManageLibrary {
  final int id;
  final String uuid;
  final String name;
  final String? description;
  final String? domain;
  final bool isLocal;
  final DateTime? creationDate;
  final String privacyLevel;
  final int uploadsCount;
  final int? followersCount;
  final ManageActorRef? actor;

  const ManageLibrary({
    required this.id,
    required this.uuid,
    required this.name,
    this.description,
    this.domain,
    this.isLocal = false,
    this.creationDate,
    required this.privacyLevel,
    this.uploadsCount = 0,
    this.followersCount,
    this.actor,
  });

  factory ManageLibrary.fromJson(Map<String, dynamic> json) {
    ManageActorRef? actor;
    final actorData = json['actor'];
    if (actorData is Map) {
      actor = ManageActorRef.fromJson(Map<String, dynamic>.from(actorData));
    }
    return ManageLibrary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      domain: json['domain'] as String?,
      isLocal: json['is_local'] as bool? ?? false,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      privacyLevel: json['privacy_level'] as String? ?? 'me',
      uploadsCount: (json['uploads_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt(),
      actor: actor,
    );
  }

  String get privacyLevelLabel {
    switch (privacyLevel) {
      case 'everyone':
        return 'Public';
      case 'instance':
        return 'Instance';
      case 'me':
        return 'Private';
      default:
        return privacyLevel;
    }
  }
}

/// Stats payload from `GET /api/v1/manage/library/libraries/{uuid}/stats/`.
class ManageLibraryStats {
  final int uploads;
  final int followers;
  final int tracks;
  final int albums;
  final int artists;
  final int reports;
  final int? mediaTotalSize;
  final int? mediaSize;

  const ManageLibraryStats({
    this.uploads = 0,
    this.followers = 0,
    this.tracks = 0,
    this.albums = 0,
    this.artists = 0,
    this.reports = 0,
    this.mediaTotalSize,
    this.mediaSize,
  });

  factory ManageLibraryStats.fromJson(Map<String, dynamic> json) {
    return ManageLibraryStats(
      uploads: (json['uploads'] as num?)?.toInt() ?? 0,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      tracks: (json['tracks'] as num?)?.toInt() ?? 0,
      albums: (json['albums'] as num?)?.toInt() ?? 0,
      artists: (json['artists'] as num?)?.toInt() ?? 0,
      reports: (json['reports'] as num?)?.toInt() ?? 0,
      mediaTotalSize: (json['media_total_size'] as num?)?.toInt(),
      mediaSize: (json['media_size'] as num?)?.toInt(),
    );
  }
}

/// Upload row from `GET /api/v1/manage/library/uploads/`.
class ManageUpload {
  final int id;
  final String uuid;
  final String? filename;
  final String? mimetype;
  final String importStatus;
  final String? source;
  final int? duration;
  final int? bitrate;
  final int? size;
  final DateTime? creationDate;
  final String? trackTitle;
  final String? artistName;
  final String? albumTitle;
  final String? libraryName;
  final String? libraryUuid;
  final String? domain;
  final bool isLocal;

  const ManageUpload({
    required this.id,
    required this.uuid,
    this.filename,
    this.mimetype,
    required this.importStatus,
    this.source,
    this.duration,
    this.bitrate,
    this.size,
    this.creationDate,
    this.trackTitle,
    this.artistName,
    this.albumTitle,
    this.libraryName,
    this.libraryUuid,
    this.domain,
    this.isLocal = false,
  });

  factory ManageUpload.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) =>
        v == null ? null : (v is int ? v : (v as num).round());

    String? trackTitle;
    String? artistName;
    String? albumTitle;
    final track = json['track'];
    if (track is Map) {
      trackTitle = track['title'] as String?;
      final artist = track['artist'];
      if (artist is Map) {
        artistName = artist['name'] as String?;
      }
      final album = track['album'];
      if (album is Map) {
        albumTitle = album['title'] as String?;
        if (artistName == null) {
          final albumArtist = album['artist'];
          if (albumArtist is Map) {
            artistName = albumArtist['name'] as String?;
          }
        }
      }
    }

    String? libraryName;
    String? libraryUuid;
    final library = json['library'];
    if (library is Map) {
      libraryName = library['name'] as String?;
      libraryUuid = library['uuid'] as String?;
    }

    return ManageUpload(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: json['uuid'] as String? ?? '',
      filename: json['filename'] as String?,
      mimetype: json['mimetype'] as String?,
      importStatus: json['import_status'] as String? ?? 'pending',
      source: json['source'] as String?,
      duration: asInt(json['duration']),
      bitrate: asInt(json['bitrate']),
      size: asInt(json['size']),
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      trackTitle: trackTitle,
      artistName: artistName,
      albumTitle: albumTitle,
      libraryName: libraryName,
      libraryUuid: libraryUuid,
      domain: json['domain'] as String?,
      isLocal: json['is_local'] as bool? ?? false,
    );
  }

  String get displayTitle {
    if (trackTitle != null && trackTitle!.isNotEmpty) return trackTitle!;
    if (filename != null && filename!.isNotEmpty) return filename!;
    return uuid;
  }
}

/// Tag row from `GET /api/v1/manage/tags/`.
class ManageTag {
  final int id;
  final String name;
  final DateTime? creationDate;
  final int tracksCount;
  final int albumsCount;
  final int artistsCount;

  const ManageTag({
    required this.id,
    required this.name,
    this.creationDate,
    this.tracksCount = 0,
    this.albumsCount = 0,
    this.artistsCount = 0,
  });

  factory ManageTag.fromJson(Map<String, dynamic> json) {
    return ManageTag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      tracksCount: (json['tracks_count'] as num?)?.toInt() ?? 0,
      albumsCount: (json['albums_count'] as num?)?.toInt() ?? 0,
      artistsCount: (json['artists_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Channel row from `GET /api/v1/manage/channels/`.
///
/// Nested artist supplies display name and content category; actor / attributed_to
/// provide owner identity. Lookup path uses [uuid] (also accepts username on the API).
class ManageChannel {
  final int id;
  final String uuid;
  final DateTime? creationDate;
  final String name;
  final String? contentCategory;
  final int? tracksCount;
  final int? albumsCount;
  final String? domain;
  final bool isLocal;
  final String? rssUrl;
  final ManageActorRef? actor;
  final ManageActorRef? attributedTo;
  final Map<String, dynamic>? metadata;

  const ManageChannel({
    required this.id,
    required this.uuid,
    this.creationDate,
    required this.name,
    this.contentCategory,
    this.tracksCount,
    this.albumsCount,
    this.domain,
    this.isLocal = false,
    this.rssUrl,
    this.actor,
    this.attributedTo,
    this.metadata,
  });

  factory ManageChannel.fromJson(Map<String, dynamic> json) {
    ManageActorRef? parseActor(Object? raw) {
      if (raw is Map) {
        return ManageActorRef.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    String name = '';
    String? contentCategory;
    int? tracksCount;
    int? albumsCount;
    String? domain;
    bool isLocal = false;

    final artist = json['artist'];
    if (artist is Map) {
      final a = Map<String, dynamic>.from(artist);
      name = a['name'] as String? ?? '';
      contentCategory = a['content_category'] as String?;
      tracksCount = (a['tracks_count'] as num?)?.toInt();
      albumsCount = (a['albums_count'] as num?)?.toInt();
      domain = a['domain'] as String?;
      isLocal = a['is_local'] as bool? ?? false;
    }

    final actor = parseActor(json['actor']);
    final attributedTo = parseActor(json['attributed_to']);

    domain ??= actor?.domain ?? attributedTo?.domain;
    if (!isLocal) {
      isLocal = actor?.isLocal ?? attributedTo?.isLocal ?? false;
    }

    Map<String, dynamic>? metadata;
    final metaRaw = json['metadata'];
    if (metaRaw is Map) {
      metadata = Map<String, dynamic>.from(metaRaw);
    }

    return ManageChannel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: json['uuid'] as String? ?? '',
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      name: name,
      contentCategory: contentCategory,
      tracksCount: tracksCount,
      albumsCount: albumsCount,
      domain: domain,
      isLocal: isLocal,
      rssUrl: json['rss_url'] as String?,
      actor: actor,
      attributedTo: attributedTo,
      metadata: metadata,
    );
  }

  String get categoryLabel {
    switch (contentCategory) {
      case 'podcast':
        return 'Podcast';
      case 'music':
        return 'Music';
      case null:
      case '':
        return '—';
      default:
        return contentCategory!;
    }
  }

  String get ownerLabel =>
      actor?.displayLabel ?? attributedTo?.displayLabel ?? '—';
}

/// Stats from `GET /api/v1/manage/channels/{uuid}/stats/`.
class ManageChannelStats {
  final int listenings;
  final int mutations;
  final int playlists;
  final int trackFavorites;
  final int uploads;
  final int reports;
  final int follows;
  final int? mediaTotalSize;
  final int? mediaDownloadedSize;

  const ManageChannelStats({
    this.listenings = 0,
    this.mutations = 0,
    this.playlists = 0,
    this.trackFavorites = 0,
    this.uploads = 0,
    this.reports = 0,
    this.follows = 0,
    this.mediaTotalSize,
    this.mediaDownloadedSize,
  });

  factory ManageChannelStats.fromJson(Map<String, dynamic> json) {
    return ManageChannelStats(
      listenings: (json['listenings'] as num?)?.toInt() ?? 0,
      mutations: (json['mutations'] as num?)?.toInt() ?? 0,
      playlists: (json['playlists'] as num?)?.toInt() ?? 0,
      trackFavorites: (json['track_favorites'] as num?)?.toInt() ?? 0,
      uploads: (json['uploads'] as num?)?.toInt() ?? 0,
      reports: (json['reports'] as num?)?.toInt() ?? 0,
      follows: (json['follows'] as num?)?.toInt() ?? 0,
      mediaTotalSize: (json['media_total_size'] as num?)?.toInt(),
      mediaDownloadedSize: (json['media_downloaded_size'] as num?)?.toInt(),
    );
  }
}

// ── User admin (manage API) ─────────────────────────────────────────────

/// Local user row from `GET /api/v1/manage/users/users/`.
///
/// Writable via PATCH: [name], [isActive], [isStaff], [isSuperuser],
/// [uploadQuota], and [permissions] (`library` | `moderation` | `settings`).
/// Permanent removal via DELETE (admin cannot delete themselves).
class ManageUser {
  final int id;
  final String username;
  final String? fullUsername;
  final String email;
  final String name;
  final bool isActive;
  final bool isStaff;
  final bool isSuperuser;
  final DateTime? dateJoined;
  final DateTime? lastActivity;
  final String privacyLevel;
  final int? uploadQuota;
  final Map<String, bool> permissions;
  final ManageActorRef? actor;

  const ManageUser({
    required this.id,
    required this.username,
    this.fullUsername,
    this.email = '',
    this.name = '',
    this.isActive = true,
    this.isStaff = false,
    this.isSuperuser = false,
    this.dateJoined,
    this.lastActivity,
    this.privacyLevel = 'me',
    this.uploadQuota,
    this.permissions = const {},
    this.actor,
  });

  factory ManageUser.fromJson(Map<String, dynamic> json) {
    final permissions = <String, bool>{};
    final rawPerms = json['permissions'];
    if (rawPerms is Map) {
      for (final entry in rawPerms.entries) {
        permissions[entry.key.toString()] = entry.value == true;
      }
    }
    if (json['is_superuser'] == true) {
      for (final key in const ['library', 'moderation', 'settings']) {
        permissions.putIfAbsent(key, () => true);
      }
    }

    ManageActorRef? actor;
    final actorRaw = json['actor'];
    if (actorRaw is Map) {
      actor = ManageActorRef.fromJson(Map<String, dynamic>.from(actorRaw));
    }

    return ManageUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      fullUsername: json['full_username'] as String?,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isStaff: json['is_staff'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'] as String)
          : null,
      lastActivity: json['last_activity'] != null
          ? DateTime.tryParse(json['last_activity'] as String)
          : null,
      privacyLevel: json['privacy_level'] as String? ?? 'me',
      uploadQuota: (json['upload_quota'] as num?)?.toInt(),
      permissions: permissions,
      actor: actor,
    );
  }

  String get displayName => name.trim().isEmpty ? username : name;

  bool get permissionLibrary => permissions['library'] == true;
  bool get permissionModeration => permissions['moderation'] == true;
  bool get permissionSettings => permissions['settings'] == true;

  String get statusLabel {
    final parts = <String>[];
    if (!isActive) parts.add('Inactive');
    if (isSuperuser) {
      parts.add('Superuser');
    } else if (isStaff) {
      parts.add('Staff');
    }
    if (parts.isEmpty) parts.add('Active');
    return parts.join(' · ');
  }
}

/// Invitation from `GET/POST /api/v1/manage/users/invitations/`.
class ManageInvitation {
  final int id;
  final String? code;
  final DateTime? creationDate;
  final DateTime? expirationDate;
  final String? ownerUsername;
  final String? invitedUsername;
  final int usersCount;

  const ManageInvitation({
    required this.id,
    this.code,
    this.creationDate,
    this.expirationDate,
    this.ownerUsername,
    this.invitedUsername,
    this.usersCount = 0,
  });

  factory ManageInvitation.fromJson(Map<String, dynamic> json) {
    String? ownerUsername;
    final owner = json['owner'];
    if (owner is Map) {
      ownerUsername = owner['username'] as String?;
    }

    String? invitedUsername;
    final invited = json['invited_user'];
    if (invited is Map) {
      invitedUsername = invited['username'] as String?;
    }

    var usersCount = 0;
    final users = json['users'];
    if (users is List) usersCount = users.length;

    return ManageInvitation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String?,
      creationDate: json['creation_date'] != null
          ? DateTime.tryParse(json['creation_date'] as String)
          : null,
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'] as String)
          : null,
      ownerUsername: ownerUsername,
      invitedUsername: invitedUsername,
      usersCount: usersCount,
    );
  }

  /// Open when unused and not past expiration (matches server `qs.open()`).
  bool get isOpen {
    if (usersCount > 0 || invitedUsername != null) return false;
    final exp = expirationDate;
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }
}
