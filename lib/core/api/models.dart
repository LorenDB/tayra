/// Data models for the Funkwhale API.
///
/// These are intentionally kept simple and use factory constructors
/// for JSON deserialization rather than code generation, keeping
/// the project lean.
library;

// ── Cover / Attachment ──────────────────────────────────────────────────

class CoverUrls {
  final String? original;
  final String? mediumSquareCrop;
  final String? smallSquareCrop;
  final String? largSquareCrop;

  const CoverUrls({
    this.original,
    this.mediumSquareCrop,
    this.smallSquareCrop,
    this.largSquareCrop,
  });

  factory CoverUrls.fromJson(Map<String, dynamic> json) {
    return CoverUrls(
      original: json['original'] as String?,
      mediumSquareCrop: json['medium_square_crop'] as String?,
      smallSquareCrop: json['small_square_crop'] as String?,
      largSquareCrop: json['large_square_crop'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'medium_square_crop': mediumSquareCrop,
      'small_square_crop': smallSquareCrop,
      'large_square_crop': largSquareCrop,
    };
  }

  /// Returns the best available URL, preferring medium crop.
  String? get best => mediumSquareCrop ?? largSquareCrop ?? original;
  String? get large => largSquareCrop ?? original ?? mediumSquareCrop;
}

class Cover {
  final String uuid;
  final CoverUrls urls;

  const Cover({required this.uuid, required this.urls});

  factory Cover.fromJson(Map<String, dynamic> json) {
    return Cover(
      uuid: json['uuid'] as String? ?? '',
      urls: CoverUrls.fromJson(
        json['urls'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'uuid': uuid, 'urls': urls.toJson()};
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
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Artist',
      mbid: json['mbid'] as String?,
      contentCategory: json['content_category'] as String?,
      cover: parseCover(json['cover']) ?? parseCover(json['attachment_cover']),
      tracksCount: json['tracks_count'] as int? ?? 0,
      albums:
          (json['albums'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      creationDate:
          json['creation_date'] != null
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

  String? get coverUrl => cover?.urls.best;
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
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Unknown Album',
      artist: parseArtist(json['artist']),
      cover: parseCover(json['cover']),
      releaseDate: json['release_date'] as String?,
      tracksCount: json['tracks_count'] as int? ?? 0,
      duration: json['duration'] as int?,
      isPlayable: json['is_playable'] as bool? ?? true,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      creationDate:
          json['creation_date'] != null
              ? DateTime.tryParse(json['creation_date'] as String)
              : null,
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
    };
  }

  String? get coverUrl => cover?.urls.best;
  String? get largeCoverUrl => cover?.urls.large;

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
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Unknown Track',
      artist: parseArtist(json['artist']),
      album: parseAlbum(json['album']),
      listenUrl: json['listen_url'] as String?,
      position: json['position'] as int?,
      discNumber: json['disc_number'] as int?,
      cover: parseCover(json['cover']),
      isPlayable: json['is_playable'] as bool? ?? true,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      uploads:
          (json['uploads'] as List<dynamic>?)
              ?.map((e) => Upload.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      creationDate:
          json['creation_date'] != null
              ? DateTime.tryParse(json['creation_date'] as String)
              : null,
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
    };
  }

  /// Best cover URL: track cover → album cover
  String? get coverUrl => cover?.urls.best ?? album?.cover?.urls.best;

  String? get largeCoverUrl => cover?.urls.large ?? album?.cover?.urls.large;

  String get artistName => artist?.name ?? 'Unknown Artist';
  String get albumTitle => album?.title ?? '';

  /// Duration in seconds from the first upload, if available.
  int? get duration => uploads.isNotEmpty ? uploads.first.duration : null;
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
      duration: json['duration'] as int?,
      bitrate: json['bitrate'] as int?,
      size: json['size'] as int?,
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
    return Listening(
      id: json['id'] as int,
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      created:
          json['created'] != null
              ? DateTime.tryParse(json['created'] as String)
              : null,
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
    this.privacyLevel,
    this.creationDate,
    this.modificationDate,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Untitled',
      tracksCount: json['tracks_count'] as int? ?? 0,
      duration: json['duration'] as int?,
      isPlayable: json['is_playable'] as bool? ?? true,
      albumCovers:
          (json['album_covers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      privacyLevel: json['privacy_level'] as String?,
      creationDate:
          json['creation_date'] != null
              ? DateTime.tryParse(json['creation_date'] as String)
              : null,
      modificationDate:
          json['modification_date'] != null
              ? DateTime.tryParse(json['modification_date'] as String)
              : null,
    );
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
}

class PlaylistTrack {
  final Track track;
  final int? index;
  final DateTime? creationDate;

  const PlaylistTrack({required this.track, this.index, this.creationDate});

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      index: json['index'] as int?,
      creationDate:
          json['creation_date'] != null
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
      id: json['id'] as int,
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      creationDate:
          json['creation_date'] != null
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
      creationDate:
          json['creation_date'] != null
              ? DateTime.tryParse(json['creation_date'] as String)
              : null,
    );
  }
}
