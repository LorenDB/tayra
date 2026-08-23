import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/audio_tagger.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/api/http_client_factory.dart';

// ── MusicBrainz models ───────────────────────────────────────────────────

class MbRecording {
  final String id;
  final String title;
  final String? artistName;
  final String? albumTitle;
  // Release MBID — needed to fetch cover art from the Cover Art Archive.
  final String? releaseMbid;
  final String? releaseDate;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final int? lengthMs;

  const MbRecording({
    required this.id,
    required this.title,
    this.artistName,
    this.albumTitle,
    this.releaseMbid,
    this.releaseDate,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.lengthMs,
  });

  String get durationLabel {
    if (lengthMs == null) return '';
    final total = lengthMs! ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// A MusicBrainz release (album) result, optionally with its track list.
class MbRelease {
  final String id;
  final String title;
  final String? artistName;
  final String? date;
  final int? trackCount;
  final int? year;
  final List<MbRecording> tracks;

  const MbRelease({
    required this.id,
    required this.title,
    this.artistName,
    this.date,
    this.trackCount,
    this.year,
    this.tracks = const [],
  });

  MbRelease copyWith({List<MbRecording>? tracks, int? trackCount}) {
    return MbRelease(
      id: id,
      title: title,
      artistName: artistName,
      date: date,
      trackCount: trackCount ?? this.trackCount,
      year: year,
      tracks: tracks ?? this.tracks,
    );
  }
}

// ── Cover art state ──────────────────────────────────────────────────────

/// Describes the state of cover-art fetching from the Cover Art Archive.
enum CoverArtStatus { none, loading, loaded, error }

// ── Per-file upload status ───────────────────────────────────────────────

enum UploadItemStatus {
  pending,
  embedding,
  uploading,
  pollingImport,
  finished,
  errored,
}

// ── Overall batch status ─────────────────────────────────────────────────

enum UploadStatus {
  idle,
  embedding,
  uploading,
  pollingImport,
  finished,
  partial,
  errored,
}

// ── Single file in the upload batch ──────────────────────────────────────

class UploadItem {
  final String localId;
  final String? filePath;

  /// Raw file contents, used on web where no local filesystem path exists.
  final Uint8List? bytes;
  final String fileName;
  final int fileSize;

  // Existing tags read from the file (best-effort).
  final String? existingTitle;
  final String? existingArtist;
  final String? existingAlbum;
  final int? existingTrackNumber;
  final int? existingDiscNumber;
  final int? existingYear;

  // MusicBrainz assignment for this file.
  final String? mbRecordingId;
  final MbRecording? selectedMbRecording;

  // Upload / import state.
  final UploadItemStatus status;
  final double progress;
  final String? uploadedUuid;
  final String? importReference;
  final String? importStatus;
  final String? errorDetail;

  const UploadItem({
    required this.localId,
    this.filePath,
    this.bytes,
    required this.fileName,
    required this.fileSize,
    this.existingTitle,
    this.existingArtist,
    this.existingAlbum,
    this.existingTrackNumber,
    this.existingDiscNumber,
    this.existingYear,
    this.mbRecordingId,
    this.selectedMbRecording,
    this.status = UploadItemStatus.pending,
    this.progress = 0.0,
    this.uploadedUuid,
    this.importReference,
    this.importStatus,
    this.errorDetail,
  });

  bool get hasPath => filePath != null && filePath!.isNotEmpty;

  /// True when raw file contents are held in memory (web picks).
  bool get hasData => bytes != null && bytes!.isNotEmpty;

  /// True when the file can be uploaded (path on native, bytes on web).
  bool get isUploadable => hasPath || hasData;
  bool get isBusy =>
      status == UploadItemStatus.embedding ||
      status == UploadItemStatus.uploading ||
      status == UploadItemStatus.pollingImport;
  bool get isTerminal =>
      status == UploadItemStatus.finished || status == UploadItemStatus.errored;

  /// Best title for display / search prefill.
  String get displayTitle =>
      selectedMbRecording?.title ??
      existingTitle ??
      _titleFromFileName(fileName);

  String get displayArtist =>
      selectedMbRecording?.artistName ?? existingArtist ?? '';

  UploadItem copyWith({
    String? localId,
    Object? filePath = _sentinel,
    Object? bytes = _sentinel,
    String? fileName,
    int? fileSize,
    Object? existingTitle = _sentinel,
    Object? existingArtist = _sentinel,
    Object? existingAlbum = _sentinel,
    Object? existingTrackNumber = _sentinel,
    Object? existingDiscNumber = _sentinel,
    Object? existingYear = _sentinel,
    Object? mbRecordingId = _sentinel,
    Object? selectedMbRecording = _sentinel,
    UploadItemStatus? status,
    double? progress,
    Object? uploadedUuid = _sentinel,
    Object? importReference = _sentinel,
    Object? importStatus = _sentinel,
    Object? errorDetail = _sentinel,
  }) {
    return UploadItem(
      localId: localId ?? this.localId,
      filePath: filePath == _sentinel ? this.filePath : filePath as String?,
      bytes: bytes == _sentinel ? this.bytes : bytes as Uint8List?,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      existingTitle:
          existingTitle == _sentinel
              ? this.existingTitle
              : existingTitle as String?,
      existingArtist:
          existingArtist == _sentinel
              ? this.existingArtist
              : existingArtist as String?,
      existingAlbum:
          existingAlbum == _sentinel
              ? this.existingAlbum
              : existingAlbum as String?,
      existingTrackNumber:
          existingTrackNumber == _sentinel
              ? this.existingTrackNumber
              : existingTrackNumber as int?,
      existingDiscNumber:
          existingDiscNumber == _sentinel
              ? this.existingDiscNumber
              : existingDiscNumber as int?,
      existingYear:
          existingYear == _sentinel ? this.existingYear : existingYear as int?,
      mbRecordingId:
          mbRecordingId == _sentinel
              ? this.mbRecordingId
              : mbRecordingId as String?,
      selectedMbRecording:
          selectedMbRecording == _sentinel
              ? this.selectedMbRecording
              : selectedMbRecording as MbRecording?,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      uploadedUuid:
          uploadedUuid == _sentinel
              ? this.uploadedUuid
              : uploadedUuid as String?,
      importReference:
          importReference == _sentinel
              ? this.importReference
              : importReference as String?,
      importStatus:
          importStatus == _sentinel
              ? this.importStatus
              : importStatus as String?,
      errorDetail:
          errorDetail == _sentinel ? this.errorDetail : errorDetail as String?,
    );
  }
}

String _titleFromFileName(String name) {
  final base = p.basenameWithoutExtension(name);
  // Strip common "01 - Title" / "01. Title" prefixes.
  final stripped = base.replaceFirst(RegExp(r'^\d{1,3}[\s.\-_]+'), '');
  return stripped.isNotEmpty ? stripped : base;
}

// ── Upload state ─────────────────────────────────────────────────────────

class UploadState {
  // Libraries
  final List<Library> libraries;
  final bool loadingLibraries;
  final String? libraryError;
  final String? selectedLibraryUuid;

  // Selected files
  final List<UploadItem> items;
  final bool readingTags;

  // MusicBrainz
  final bool useMusicBrainz;
  // Recording search (single-file / per-track)
  final bool mbSearching;
  final List<MbRecording> mbResults;
  // Release / album search (multi-file)
  final List<MbRelease> mbReleaseResults;
  final MbRelease? selectedMbRelease;
  final String? mbSearchError;
  // Which file a per-track search is targeting (null = album mode / global).
  final String? mbTargetItemId;

  // Cover art (shared for album selection)
  final CoverArtStatus coverArtStatus;
  final Uint8List? coverArtBytes;
  final String? coverArtMime;
  final String? coverArtUrl;
  final bool embedCoverArt;

  // Batch upload state
  final UploadStatus uploadStatus;
  final String? uploadError;

  const UploadState({
    this.libraries = const [],
    this.loadingLibraries = false,
    this.libraryError,
    this.selectedLibraryUuid,
    this.items = const [],
    this.readingTags = false,
    this.useMusicBrainz = false,
    this.mbSearching = false,
    this.mbResults = const [],
    this.mbReleaseResults = const [],
    this.selectedMbRelease,
    this.mbSearchError,
    this.mbTargetItemId,
    this.coverArtStatus = CoverArtStatus.none,
    this.coverArtBytes,
    this.coverArtMime,
    this.coverArtUrl,
    this.embedCoverArt = true,
    this.uploadStatus = UploadStatus.idle,
    this.uploadError,
  });

  bool get hasFiles => items.isNotEmpty;
  int get fileCount => items.length;
  bool get isSingleFile => items.length == 1;

  int get finishedCount =>
      items.where((i) => i.status == UploadItemStatus.finished).length;
  int get erroredCount =>
      items.where((i) => i.status == UploadItemStatus.errored).length;
  int get matchedMbCount =>
      items.where((i) => i.selectedMbRecording != null).length;

  double get batchProgress {
    if (items.isEmpty) return 0;
    final sum = items.fold<double>(0, (a, i) {
      if (i.status == UploadItemStatus.finished) return a + 1;
      if (i.status == UploadItemStatus.errored) return a + 1;
      if (i.status == UploadItemStatus.pollingImport) return a + 0.95;
      if (i.status == UploadItemStatus.uploading) return a + (i.progress * 0.9);
      if (i.status == UploadItemStatus.embedding) return a + 0.05;
      return a;
    });
    return (sum / items.length).clamp(0.0, 1.0);
  }

  bool get canUpload =>
      hasFiles &&
      selectedLibraryUuid != null &&
      uploadStatus == UploadStatus.idle &&
      items.every((i) => i.isUploadable);

  bool get isLocked =>
      uploadStatus == UploadStatus.uploading ||
      uploadStatus == UploadStatus.pollingImport ||
      uploadStatus == UploadStatus.embedding;

  bool get isDone =>
      uploadStatus == UploadStatus.finished ||
      uploadStatus == UploadStatus.partial ||
      uploadStatus == UploadStatus.errored;

  /// Prefill values derived from selected file tags.
  String get suggestedTitle {
    if (items.isEmpty) return '';
    return items.first.existingTitle ??
        _titleFromFileName(items.first.fileName);
  }

  String get suggestedArtist {
    if (items.isEmpty) return '';
    // Prefer a common artist across all files.
    final artists =
        items
            .map((i) => i.existingArtist?.trim())
            .whereType<String>()
            .where((a) => a.isNotEmpty)
            .toSet();
    if (artists.length == 1) return artists.first;
    return items.first.existingArtist ?? '';
  }

  String get suggestedAlbum {
    if (items.isEmpty) return '';
    final albums =
        items
            .map((i) => i.existingAlbum?.trim())
            .whereType<String>()
            .where((a) => a.isNotEmpty)
            .toSet();
    if (albums.length == 1) return albums.first;
    return items.first.existingAlbum ?? '';
  }

  UploadState copyWith({
    List<Library>? libraries,
    bool? loadingLibraries,
    Object? libraryError = _sentinel,
    Object? selectedLibraryUuid = _sentinel,
    List<UploadItem>? items,
    bool? readingTags,
    bool? useMusicBrainz,
    bool? mbSearching,
    List<MbRecording>? mbResults,
    List<MbRelease>? mbReleaseResults,
    Object? selectedMbRelease = _sentinel,
    Object? mbSearchError = _sentinel,
    Object? mbTargetItemId = _sentinel,
    CoverArtStatus? coverArtStatus,
    Object? coverArtBytes = _sentinel,
    Object? coverArtMime = _sentinel,
    Object? coverArtUrl = _sentinel,
    bool? embedCoverArt,
    UploadStatus? uploadStatus,
    Object? uploadError = _sentinel,
  }) {
    return UploadState(
      libraries: libraries ?? this.libraries,
      loadingLibraries: loadingLibraries ?? this.loadingLibraries,
      libraryError:
          libraryError == _sentinel
              ? this.libraryError
              : libraryError as String?,
      selectedLibraryUuid:
          selectedLibraryUuid == _sentinel
              ? this.selectedLibraryUuid
              : selectedLibraryUuid as String?,
      items: items ?? this.items,
      readingTags: readingTags ?? this.readingTags,
      useMusicBrainz: useMusicBrainz ?? this.useMusicBrainz,
      mbSearching: mbSearching ?? this.mbSearching,
      mbResults: mbResults ?? this.mbResults,
      mbReleaseResults: mbReleaseResults ?? this.mbReleaseResults,
      selectedMbRelease:
          selectedMbRelease == _sentinel
              ? this.selectedMbRelease
              : selectedMbRelease as MbRelease?,
      mbSearchError:
          mbSearchError == _sentinel
              ? this.mbSearchError
              : mbSearchError as String?,
      mbTargetItemId:
          mbTargetItemId == _sentinel
              ? this.mbTargetItemId
              : mbTargetItemId as String?,
      coverArtStatus: coverArtStatus ?? this.coverArtStatus,
      coverArtBytes:
          coverArtBytes == _sentinel
              ? this.coverArtBytes
              : coverArtBytes as Uint8List?,
      coverArtMime:
          coverArtMime == _sentinel
              ? this.coverArtMime
              : coverArtMime as String?,
      coverArtUrl:
          coverArtUrl == _sentinel ? this.coverArtUrl : coverArtUrl as String?,
      embedCoverArt: embedCoverArt ?? this.embedCoverArt,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError:
          uploadError == _sentinel ? this.uploadError : uploadError as String?,
    );
  }
}

const Object _sentinel = Object();

// ── Preference keys ──────────────────────────────────────────────────────

const _keyUseMusicBrainz = 'upload_use_musicbrainz';

// ── File extensions that the audio tagger supports ──────────────────────

const _taggableExtensions = {'mp3', 'flac', 'ogg', 'oga', 'opus'};

const _audioExtensions = [
  'mp3',
  'flac',
  'ogg',
  'opus',
  'aac',
  'wav',
  'm4a',
  'wma',
  'aiff',
  'aif',
  'ape',
  'wv',
  'mka',
  'oga',
];

// ── Polling constants ────────────────────────────────────────────────────

/// How often to poll the server for import status.
const _pollInterval = Duration(seconds: 3);

/// Stop polling after this many attempts (~5 minutes at 3 s intervals).
const _maxPollAttempts = 100;

/// Stop polling after this many consecutive network/server errors.
const _maxConsecutivePollErrors = 5;

/// Stop polling an item after this many successful polls that still cannot
/// find the upload (avoids a silent 5-minute wait on a bad reference).
const _maxPollMisses = 10;

// ── Upload notifier ──────────────────────────────────────────────────────

class UploadNotifier extends Notifier<UploadState> {
  late final Dio _mbDio;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;
  final Map<String, int> _pollMisses = {};

  /// Incremented on every reset/new upload so in-flight _pollOnce calls can
  /// detect they belong to a stale session and discard their results.
  int _pollGeneration = 0;

  /// Temporary tagged files to clean up after upload.
  final List<File> _tempTaggedFiles = [];

  int _idCounter = 0;

  @override
  UploadState build() {
    _mbDio =
        createDio()
          ..options.headers['User-Agent'] =
              'Tayra/1.0 (https://github.com/loren/tayra)'
          ..options.connectTimeout = const Duration(seconds: 10)
          ..options.receiveTimeout = const Duration(seconds: 20);

    ref.onDispose(() {
      _pollingTimer?.cancel();
      _cleanupTempFiles();
    });

    Future.microtask(_init);
    return const UploadState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      useMusicBrainz: prefs.getBool(_keyUseMusicBrainz) ?? false,
    );
    await loadLibraries();
  }

  FunkwhaleApi get _api => ref.read(funkwhaleApiProvider);

  void _cleanupTempFiles() {
    for (final f in _tempTaggedFiles) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    _tempTaggedFiles.clear();
  }

  String _nextId() => 'f${++_idCounter}';

  void _updateItem(String id, UploadItem Function(UploadItem) update) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.localId == id) update(item) else item,
      ],
    );
  }

  // ── Libraries ─────────────────────────────────────────────────────────

  Future<void> loadLibraries() async {
    state = state.copyWith(loadingLibraries: true, libraryError: null);
    try {
      // Uncached: the picker must not reuse browse/admin library lists.
      final result = await _api.getLibraries(scope: 'me', pageSize: 200);
      final selected =
          result.results.isNotEmpty
              ? result.results.first.uuid
              : state.selectedLibraryUuid;
      state = state.copyWith(
        libraries: result.results,
        loadingLibraries: false,
        selectedLibraryUuid: selected,
      );
    } catch (e) {
      state = state.copyWith(
        loadingLibraries: false,
        libraryError: 'Failed to load libraries: ${_errorMessage(e)}',
      );
    }
  }

  Future<Library?> createLibrary({
    required String name,
    String privacyLevel = 'me',
  }) async {
    try {
      final library = await _api.createLibrary(
        name: name,
        privacyLevel: privacyLevel,
      );
      final updated = [...state.libraries, library];
      state = state.copyWith(
        libraries: updated,
        selectedLibraryUuid: library.uuid,
      );
      return library;
    } catch (_) {
      return null;
    }
  }

  void selectLibrary(String uuid) {
    state = state.copyWith(selectedLibraryUuid: uuid);
  }

  // ── File picking ───────────────────────────────────────────────────────

  Future<void> pickFiles() async {
    String? initialDirectory;
    if (!kIsWeb) {
      try {
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          final musicDir = p.join(home, 'Music');
          if (await Directory(musicDir).exists()) initialDirectory = musicDir;
        }
      } catch (_) {
        // ignore and allow file picker to fallback to its default
      }
    }

    // pickFiles allows multiple selection by default in file_picker ≥12.
    // On web, files have no filesystem path (only a blob URL); bytes are
    // read lazily per file below for tag reading and the multipart upload.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      initialDirectory: initialDirectory,
      allowedExtensions: _audioExtensions,
    );
    if (result == null || result.files.isEmpty) return;

    state = state.copyWith(
      readingTags: true,
      uploadStatus: UploadStatus.idle,
      uploadError: null,
      selectedMbRelease: null,
      mbResults: [],
      mbReleaseResults: [],
      coverArtStatus: CoverArtStatus.none,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
    );

    final items = <UploadItem>[];
    for (final file in result.files) {
      final hasLocalPath =
          !kIsWeb && file.path != null && file.path!.isNotEmpty;
      Uint8List? bytes;
      if (!hasLocalPath) {
        try {
          bytes = await file.readAsBytes();
        } catch (e) {
          // Neither a usable path nor readable in-memory data — skip.
          developer.log(
            'Skipping unreadable file ${file.name}: $e',
            name: 'tayra.upload',
          );
          continue;
        }
      }

      AudioMetadata? tags;
      try {
        tags =
            hasLocalPath
                ? await readAudioMetadata(file.path!)
                : await readAudioMetadataBytes(bytes!, file.name);
      } catch (_) {
        tags = null;
      }

      items.add(
        UploadItem(
          localId: _nextId(),
          filePath: hasLocalPath ? file.path : null,
          bytes: bytes,
          fileName: file.name,
          fileSize: file.size,
          existingTitle: tags?.title,
          existingArtist: tags?.artist,
          existingAlbum: tags?.album,
          existingTrackNumber: tags?.trackNumber,
          existingDiscNumber: tags?.discNumber,
          existingYear: tags?.year,
          mbRecordingId: tags?.musicBrainzRecordingId,
          selectedMbRecording:
              tags?.musicBrainzRecordingId != null
                  ? MbRecording(
                    id: tags!.musicBrainzRecordingId!,
                    title: tags.title ?? _titleFromFileName(file.name),
                    artistName: tags.artist,
                    albumTitle: tags.album,
                    releaseMbid: tags.musicBrainzReleaseId,
                    trackNumber: tags.trackNumber,
                    discNumber: tags.discNumber,
                    year: tags.year,
                  )
                  : null,
        ),
      );
    }

    // Sort by disc / track number / name for a sensible album order.
    items.sort((a, b) {
      final discCmp = (a.existingDiscNumber ?? 1).compareTo(
        b.existingDiscNumber ?? 1,
      );
      if (discCmp != 0) return discCmp;
      final trackCmp = (a.existingTrackNumber ?? 9999).compareTo(
        b.existingTrackNumber ?? 9999,
      );
      if (trackCmp != 0) return trackCmp;
      return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    });

    state = state.copyWith(items: items, readingTags: false);

    // Auto-enable MusicBrainz toggle if any file already has an MBID.
    if (items.any((i) => i.mbRecordingId != null) && !state.useMusicBrainz) {
      // Leave user preference alone; just note tags were found.
    }
  }

  /// Back-compat alias used by older call sites.
  Future<void> pickFile() => pickFiles();

  void removeItem(String localId) {
    if (state.isLocked) return;
    final remaining = state.items
        .where((i) => i.localId != localId)
        .toList(growable: false);
    state = state.copyWith(
      items: remaining,
      selectedMbRelease: remaining.isEmpty ? null : state.selectedMbRelease,
      coverArtStatus:
          remaining.isEmpty ? CoverArtStatus.none : state.coverArtStatus,
      coverArtBytes: remaining.isEmpty ? null : state.coverArtBytes,
    );
  }

  void clearFiles() {
    if (state.isLocked) return;
    state = state.copyWith(
      items: [],
      selectedMbRelease: null,
      mbResults: [],
      mbReleaseResults: [],
      coverArtStatus: CoverArtStatus.none,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
      uploadStatus: UploadStatus.idle,
      uploadError: null,
    );
  }

  // ── MusicBrainz toggle ────────────────────────────────────────────────

  Future<void> setUseMusicBrainz(bool value) async {
    state = state.copyWith(
      useMusicBrainz: value,
      selectedMbRelease: null,
      mbResults: [],
      mbReleaseResults: [],
      coverArtStatus: CoverArtStatus.none,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
    );
    // Clear per-file MB assignments when turning off.
    if (!value) {
      state = state.copyWith(
        items: [
          for (final item in state.items)
            item.copyWith(mbRecordingId: null, selectedMbRecording: null),
        ],
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseMusicBrainz, value);
  }

  void setEmbedCoverArt(bool value) {
    state = state.copyWith(embedCoverArt: value);
  }

  void setMbTargetItem(String? itemId) {
    state = state.copyWith(
      mbTargetItemId: itemId,
      mbResults: [],
      mbReleaseResults: [],
      mbSearchError: null,
    );
  }

  // ── MusicBrainz recording search (single track) ───────────────────────

  Future<void> searchMusicBrainz(String title, String artist) async {
    if (title.trim().isEmpty) return;

    state = state.copyWith(
      mbSearching: true,
      mbResults: [],
      mbReleaseResults: [],
      mbSearchError: null,
    );

    try {
      var query = 'recording:"${title.trim()}"';
      if (artist.trim().isNotEmpty) {
        query += ' AND artist:"${artist.trim()}"';
      }

      final response = await _mbDio.get(
        'https://musicbrainz.org/ws/2/recording/',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 15},
      );

      final recordings =
          (response.data['recordings'] as List<dynamic>? ?? [])
              .map(_parseMbRecordingSearchHit)
              .toList();

      state = state.copyWith(mbSearching: false, mbResults: recordings);
    } catch (e) {
      state = state.copyWith(
        mbSearching: false,
        mbSearchError: 'MusicBrainz search failed: ${_errorMessage(e)}',
      );
    }
  }

  // ── MusicBrainz release / album search ────────────────────────────────

  Future<void> searchMusicBrainzAlbum(String album, String artist) async {
    if (album.trim().isEmpty && artist.trim().isEmpty) return;

    state = state.copyWith(
      mbSearching: true,
      mbResults: [],
      mbReleaseResults: [],
      mbSearchError: null,
    );

    try {
      final parts = <String>[];
      if (album.trim().isNotEmpty) {
        parts.add('release:"${album.trim()}"');
      }
      if (artist.trim().isNotEmpty) {
        parts.add('artist:"${artist.trim()}"');
      }
      // Prefer releases whose track count is close to our file count.
      if (state.items.length > 1) {
        parts.add('tracks:${state.items.length}');
      }
      final query = parts.join(' AND ');

      final response = await _mbDio.get(
        'https://musicbrainz.org/ws/2/release/',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 15},
      );

      final releases =
          (response.data['releases'] as List<dynamic>? ?? []).map((r) {
            final map = r as Map<String, dynamic>;
            final credits = map['artist-credit'] as List<dynamic>? ?? [];
            String? artistName;
            if (credits.isNotEmpty) {
              final credit = credits.first as Map<String, dynamic>?;
              artistName =
                  (credit?['artist'] as Map<String, dynamic>?)?['name']
                      as String?;
            }
            final date = map['date'] as String?;
            int? year;
            if (date != null && date.length >= 4) {
              year = int.tryParse(date.substring(0, 4));
            }
            final media = map['media'] as List<dynamic>? ?? [];
            int trackCount = 0;
            for (final m in media) {
              final medium = m as Map<String, dynamic>;
              trackCount += (medium['track-count'] as int?) ?? 0;
            }
            return MbRelease(
              id: map['id'] as String,
              title: map['title'] as String? ?? 'Unknown',
              artistName: artistName,
              date: date,
              trackCount: trackCount > 0 ? trackCount : null,
              year: year,
            );
          }).toList();

      state = state.copyWith(mbSearching: false, mbReleaseResults: releases);
    } catch (e) {
      state = state.copyWith(
        mbSearching: false,
        mbSearchError: 'MusicBrainz album search failed: ${_errorMessage(e)}',
      );
    }
  }

  MbRecording _parseMbRecordingSearchHit(dynamic r) {
    final map = r as Map<String, dynamic>;
    final credits = map['artist-credit'] as List<dynamic>? ?? [];
    String? artistName;
    if (credits.isNotEmpty) {
      final credit = credits.first as Map<String, dynamic>?;
      artistName =
          (credit?['artist'] as Map<String, dynamic>?)?['name'] as String?;
    }
    final releases = map['releases'] as List<dynamic>? ?? [];
    String? albumTitle;
    String? releaseMbid;
    String? releaseDate;
    int? year;
    if (releases.isNotEmpty) {
      final rel = releases.first as Map<String, dynamic>;
      albumTitle = rel['title'] as String?;
      releaseMbid = rel['id'] as String?;
      releaseDate = rel['date'] as String?;
      if (releaseDate != null && releaseDate.length >= 4) {
        year = int.tryParse(releaseDate.substring(0, 4));
      }
    }
    return MbRecording(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Unknown',
      artistName: artistName,
      albumTitle: albumTitle,
      releaseMbid: releaseMbid,
      releaseDate: releaseDate,
      year: year,
      lengthMs: map['length'] as int?,
    );
  }

  /// Select a recording for a single file (or the only file).
  void selectMbRecording(MbRecording recording, {String? itemId}) {
    final targetId =
        itemId ?? state.mbTargetItemId ?? state.items.firstOrNull?.localId;
    if (targetId == null) return;

    _updateItem(
      targetId,
      (item) => item.copyWith(
        mbRecordingId: recording.id,
        selectedMbRecording: recording,
      ),
    );

    // Fetch cover art when a release is known.
    if (recording.releaseMbid != null) {
      _fetchCoverArt(recording.releaseMbid!);
    }
  }

  /// Select an album release, fetch its track list, and match files.
  Future<void> selectMbRelease(MbRelease release) async {
    state = state.copyWith(
      mbSearching: true,
      mbSearchError: null,
      selectedMbRelease: release,
    );

    try {
      final full = await _fetchMbRelease(release.id);
      if (full == null) {
        state = state.copyWith(
          mbSearching: false,
          mbSearchError: 'Could not load track list for this release.',
        );
        return;
      }

      final matched = _matchFilesToRelease(state.items, full.tracks);
      state = state.copyWith(
        mbSearching: false,
        selectedMbRelease: full,
        items: matched,
      );

      await _fetchCoverArt(full.id);
    } catch (e) {
      state = state.copyWith(
        mbSearching: false,
        mbSearchError: 'Failed to load release: ${_errorMessage(e)}',
      );
    }
  }

  Future<MbRelease?> _fetchMbRelease(String mbid) async {
    try {
      final response = await _mbDio.get(
        'https://musicbrainz.org/ws/2/release/$mbid',
        queryParameters: {'inc': 'recordings+artist-credits', 'fmt': 'json'},
      );
      final map = response.data as Map<String, dynamic>;

      final credits = map['artist-credit'] as List<dynamic>? ?? [];
      String? artistName;
      if (credits.isNotEmpty) {
        final credit = credits.first as Map<String, dynamic>?;
        artistName =
            (credit?['artist'] as Map<String, dynamic>?)?['name'] as String?;
      }

      final date = map['date'] as String?;
      int? year;
      if (date != null && date.length >= 4) {
        year = int.tryParse(date.substring(0, 4));
      }

      final tracks = <MbRecording>[];
      final media = map['media'] as List<dynamic>? ?? [];
      for (final medium in media) {
        final mediumMap = medium as Map<String, dynamic>;
        final discNumber = mediumMap['position'] as int? ?? 1;
        final trackList = mediumMap['tracks'] as List<dynamic>? ?? [];
        for (final t in trackList) {
          final trackMap = t as Map<String, dynamic>;
          final recording =
              trackMap['recording'] as Map<String, dynamic>? ?? {};
          final recCredits =
              recording['artist-credit'] as List<dynamic>? ??
              trackMap['artist-credit'] as List<dynamic>? ??
              credits;
          String? trackArtist;
          if (recCredits.isNotEmpty) {
            final credit = recCredits.first as Map<String, dynamic>?;
            trackArtist =
                (credit?['artist'] as Map<String, dynamic>?)?['name']
                    as String?;
          }
          final length =
              trackMap['length'] as int? ?? recording['length'] as int?;
          tracks.add(
            MbRecording(
              id: recording['id'] as String? ?? trackMap['id'] as String? ?? '',
              title:
                  recording['title'] as String? ??
                  trackMap['title'] as String? ??
                  'Unknown',
              artistName: trackArtist ?? artistName,
              albumTitle: map['title'] as String?,
              releaseMbid: mbid,
              releaseDate: date,
              trackNumber: trackMap['position'] as int?,
              discNumber: discNumber,
              year: year,
              lengthMs: length,
            ),
          );
        }
      }

      return MbRelease(
        id: mbid,
        title: map['title'] as String? ?? 'Unknown',
        artistName: artistName,
        date: date,
        trackCount: tracks.length,
        year: year,
        tracks: tracks.where((t) => t.id.isNotEmpty).toList(),
      );
    } catch (e, st) {
      developer.log(
        'Failed to fetch MusicBrainz release $mbid: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Match selected files to release tracks by track number, then title.
  List<UploadItem> _matchFilesToRelease(
    List<UploadItem> files,
    List<MbRecording> tracks,
  ) {
    if (tracks.isEmpty) return files;

    final remainingTracks = List<MbRecording>.from(tracks);
    final result = <UploadItem>[];
    final usedTrackIds = <String>{};

    // Pass 1: exact disc+track number match.
    for (final file in files) {
      MbRecording? match;
      if (file.existingTrackNumber != null) {
        final disc = file.existingDiscNumber ?? 1;
        for (final t in remainingTracks) {
          if (usedTrackIds.contains(t.id)) continue;
          if (t.trackNumber == file.existingTrackNumber &&
              (t.discNumber ?? 1) == disc) {
            match = t;
            break;
          }
        }
      }
      if (match != null) {
        usedTrackIds.add(match.id);
        result.add(
          file.copyWith(mbRecordingId: match.id, selectedMbRecording: match),
        );
      } else {
        result.add(file);
      }
    }

    // Pass 2: normalized title match for unmatched files.
    for (int i = 0; i < result.length; i++) {
      final file = result[i];
      if (file.selectedMbRecording != null) continue;
      final fileTitle = _normalizeTitle(
        file.existingTitle ?? _titleFromFileName(file.fileName),
      );
      if (fileTitle.isEmpty) continue;

      MbRecording? best;
      double bestScore = 0;
      for (final t in remainingTracks) {
        if (usedTrackIds.contains(t.id)) continue;
        final score = _titleSimilarity(fileTitle, _normalizeTitle(t.title));
        if (score > bestScore) {
          bestScore = score;
          best = t;
        }
      }
      if (best != null && bestScore >= 0.6) {
        usedTrackIds.add(best.id);
        result[i] = file.copyWith(
          mbRecordingId: best.id,
          selectedMbRecording: best,
        );
      }
    }

    // Pass 3: assign remaining by position order.
    final unmatchedTracks =
        remainingTracks.where((t) => !usedTrackIds.contains(t.id)).toList();
    int ti = 0;
    for (int i = 0; i < result.length; i++) {
      if (result[i].selectedMbRecording != null) continue;
      if (ti >= unmatchedTracks.length) break;
      final t = unmatchedTracks[ti++];
      result[i] = result[i].copyWith(
        mbRecordingId: t.id,
        selectedMbRecording: t,
      );
    }

    return result;
  }

  String _normalizeTitle(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _titleSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.contains(b) || b.contains(a)) {
      return math.min(a.length, b.length) / math.max(a.length, b.length);
    }
    // Simple token Jaccard.
    final ta = a.split(' ').toSet();
    final tb = b.split(' ').toSet();
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    return union == 0 ? 0.0 : inter / union;
  }

  // ── MB record fetching ─────────────────────────────────────────────────

  /// Fetches a full recording by MBID, including track/disc position and year.
  Future<MbRecording?> _fetchMbRecording(String mbid) async {
    try {
      final response = await _mbDio.get(
        'https://musicbrainz.org/ws/2/recording/$mbid',
        queryParameters: {'inc': 'artists+releases', 'fmt': 'json'},
      );
      final map = response.data as Map<String, dynamic>;

      final credits = map['artist-credit'] as List<dynamic>? ?? [];
      String? artistName;
      if (credits.isNotEmpty) {
        final credit = credits.first as Map<String, dynamic>?;
        artistName =
            (credit?['artist'] as Map<String, dynamic>?)?['name'] as String?;
      }

      final releases = map['releases'] as List<dynamic>? ?? [];
      String? albumTitle;
      String? releaseMbid;
      int? trackNumber;
      int? discNumber;
      int? year;

      if (releases.isNotEmpty) {
        final rel = releases.first as Map<String, dynamic>;
        albumTitle = rel['title'] as String?;
        releaseMbid = rel['id'] as String?;

        final dateStr = rel['date'] as String?;
        if (dateStr != null && dateStr.length >= 4) {
          year = int.tryParse(dateStr.substring(0, 4));
        }

        // Walk the media to find this recording's position.
        final media = rel['media'] as List<dynamic>? ?? [];
        outer:
        for (final medium in media) {
          final mediumMap = medium as Map<String, dynamic>;
          final tracks = mediumMap['tracks'] as List<dynamic>? ?? [];
          for (final track in tracks) {
            final trackMap = track as Map<String, dynamic>;
            final rec = trackMap['recording'] as Map<String, dynamic>?;
            if (rec != null && rec['id'] == mbid) {
              trackNumber = trackMap['position'] as int?;
              discNumber = mediumMap['position'] as int? ?? 1;
              break outer;
            }
          }
          // Fallback: first track if media didn't include recording ids.
          if (tracks.isNotEmpty && trackNumber == null) {
            final trackMap = tracks.first as Map<String, dynamic>;
            trackNumber = trackMap['position'] as int?;
            discNumber = mediumMap['position'] as int? ?? 1;
          }
        }
      }

      return MbRecording(
        id: map['id'] as String,
        title: map['title'] as String,
        artistName: artistName,
        albumTitle: albumTitle,
        releaseMbid: releaseMbid,
        trackNumber: trackNumber,
        discNumber: discNumber,
        year: year,
        lengthMs: map['length'] as int?,
      );
    } catch (e, st) {
      developer.log(
        'Failed to fetch MusicBrainz recording $mbid: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ── Cover Art Archive ──────────────────────────────────────────────────

  /// Fetches cover art for a release from the Cover Art Archive.
  Future<void> _fetchCoverArt(String releaseMbid) async {
    state = state.copyWith(
      coverArtStatus: CoverArtStatus.loading,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
    );

    try {
      final url = 'https://coverartarchive.org/release/$releaseMbid/front';
      final imageResponse = await _mbDio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (imageResponse.statusCode == 200 && imageResponse.data != null) {
        final bytes = Uint8List.fromList(imageResponse.data!);
        final contentType =
            imageResponse.headers.value('content-type') ?? 'image/jpeg';
        final mime =
            contentType.startsWith('image/') ? contentType : 'image/jpeg';

        state = state.copyWith(
          coverArtStatus: CoverArtStatus.loaded,
          coverArtBytes: bytes,
          coverArtMime: mime,
          coverArtUrl: url,
        );
      } else {
        state = state.copyWith(coverArtStatus: CoverArtStatus.error);
      }
    } catch (_) {
      state = state.copyWith(coverArtStatus: CoverArtStatus.error);
    }
  }

  // ── Metadata embedding ─────────────────────────────────────────────────

  bool _canEmbedTags(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    return _taggableExtensions.contains(ext);
  }

  /// Creates a temporary copy of the audio file with MusicBrainz metadata
  /// (and optionally cover art) embedded directly into its tags.
  Future<String?> _embedMetadata(UploadItem item, MbRecording recording) async {
    if (!_canEmbedTags(item.fileName) || item.filePath == null) {
      developer.log(
        'Tag embedding skipped: unsupported format (${item.fileName})',
        name: 'tayra.upload',
      );
      return null;
    }

    final originalPath = item.filePath!;
    final originalName = item.fileName;
    developer.log(
      'Embedding tags into temp copy of "$originalName"',
      name: 'tayra.upload',
    );

    try {
      final meta = _mbMetadataFor(recording);

      final taggedBytes = await tagAudioFile(originalPath, meta);
      if (taggedBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        p.join(tempDir.path, 'tayra_upload_${item.localId}_$originalName'),
      );
      await tempFile.writeAsBytes(taggedBytes, flush: true);

      _tempTaggedFiles.add(tempFile);
      return tempFile.path;
    } catch (e, st) {
      developer.log(
        'Tag embedding failed, falling back to original file: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Web variant of [_embedMetadata]: tags the in-memory copy of the file
  /// instead of writing a temp file (dart:io is unavailable on web).
  Uint8List? _embedMetadataBytes(UploadItem item, MbRecording recording) {
    if (!_canEmbedTags(item.fileName) || item.bytes == null) {
      developer.log(
        'Tag embedding skipped: unsupported format (${item.fileName})',
        name: 'tayra.upload',
      );
      return null;
    }

    try {
      final tagged = tagAudioFileBytes(
        item.bytes!,
        item.fileName,
        _mbMetadataFor(recording),
      );
      if (tagged == null) {
        developer.log(
          'Tag embedding skipped for ${item.fileName}',
          name: 'tayra.upload',
        );
        return null;
      }
      developer.log(
        'Embedded tags into in-memory copy of "${item.fileName}"',
        name: 'tayra.upload',
      );
      return tagged;
    } catch (e, st) {
      developer.log(
        'Tag embedding failed, falling back to original file: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Builds tag payload from a MusicBrainz recording, including cover art
  /// when enabled and loaded.
  AudioMetadata _mbMetadataFor(MbRecording recording) {
    final useCover =
        state.embedCoverArt &&
        state.coverArtStatus == CoverArtStatus.loaded &&
        state.coverArtBytes != null;
    return AudioMetadata(
      title: recording.title,
      artist: recording.artistName,
      album: recording.albumTitle,
      trackNumber: recording.trackNumber,
      discNumber: recording.discNumber,
      year: recording.year,
      musicBrainzRecordingId: recording.id,
      musicBrainzReleaseId: recording.releaseMbid,
      coverArt: useCover ? state.coverArtBytes : null,
      coverArtMime: useCover ? state.coverArtMime : null,
    );
  }

  // ── Upload ─────────────────────────────────────────────────────────────

  Future<void> upload() async {
    final libraryUuid = state.selectedLibraryUuid;
    if (libraryUuid == null || state.items.isEmpty) return;
    if (state.items.any((i) => !i.isUploadable)) {
      state = state.copyWith(
        uploadError:
            'One or more files could not be read and cannot be uploaded.',
      );
      return;
    }

    developer.log(
      'Starting batch upload: ${state.items.length} file(s) → library $libraryUuid',
      name: 'tayra.upload',
    );

    state = state.copyWith(
      uploadStatus: UploadStatus.uploading,
      uploadError: null,
    );

    Analytics.track('upload_started', {
      'use_musicbrainz': state.useMusicBrainz,
      'file_count': state.items.length,
      'matched_mb': state.matchedMbCount,
    });

    final pendingRefs = <String, String>{}; // localId -> importReference

    try {
      for (final item in List<UploadItem>.from(state.items)) {
        // Skip already terminal items (re-run safety).
        if (item.isTerminal) continue;

        try {
          await _uploadOne(item, libraryUuid, pendingRefs);
        } catch (e, st) {
          developer.log(
            'Upload failed for ${item.fileName}: $e',
            name: 'tayra.upload',
            error: e,
            stackTrace: st,
          );
          _updateItem(
            item.localId,
            (i) => i.copyWith(
              status: UploadItemStatus.errored,
              errorDetail: 'Upload failed: ${_errorMessage(e)}',
            ),
          );
        }
      }

      _cleanupTempFiles();

      // Start polling for any pending imports.
      if (pendingRefs.isNotEmpty) {
        state = state.copyWith(uploadStatus: UploadStatus.pollingImport);
        _startPolling();
      } else {
        _finalizeBatchStatus();
      }

      Analytics.track('upload_completed', {
        'file_count': state.items.length,
        'pending_imports': pendingRefs.length,
      });
    } catch (e, st) {
      _cleanupTempFiles();
      developer.log(
        'Batch upload error: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        uploadStatus: UploadStatus.errored,
        uploadError: 'Upload failed: ${_errorMessage(e)}',
      );
      Analytics.track('upload_failed', {'had_error': true});
    }
  }

  Future<void> _uploadOne(
    UploadItem item,
    String libraryUuid,
    Map<String, String> pendingRefs,
  ) async {
    developer.log('Uploading "${item.fileName}"', name: 'tayra.upload');

    // Resolve MusicBrainz recording if enabled.
    MbRecording? recording;
    if (state.useMusicBrainz) {
      recording = item.selectedMbRecording;
      final mbid = item.mbRecordingId ?? recording?.id;
      if (mbid != null && mbid.isNotEmpty) {
        if (recording == null || recording.id != mbid) {
          recording = await _fetchMbRecording(mbid);
        }
        if (recording == null) {
          _updateItem(
            item.localId,
            (i) => i.copyWith(
              status: UploadItemStatus.errored,
              errorDetail:
                  'Could not find MusicBrainz recording for ID $mbid. '
                  'Search again or disable MusicBrainz metadata.',
            ),
          );
          return;
        }
        _updateItem(
          item.localId,
          (i) => i.copyWith(
            mbRecordingId: recording!.id,
            selectedMbRecording: recording,
          ),
        );
      }
    }

    // Embed tags.
    String? uploadPath = item.hasPath ? item.filePath : null;
    Uint8List? uploadBytes = item.bytes;
    if (recording != null) {
      _updateItem(
        item.localId,
        (i) => i.copyWith(status: UploadItemStatus.embedding),
      );
      state = state.copyWith(uploadStatus: UploadStatus.embedding);

      if (uploadPath != null) {
        final taggedPath = await _embedMetadata(item, recording);
        if (taggedPath != null) uploadPath = taggedPath;
      } else if (uploadBytes != null) {
        // Web: tag in-memory bytes directly (no dart:io temp files).
        uploadBytes = _embedMetadataBytes(item, recording);
      }
    }

    _updateItem(
      item.localId,
      (i) => i.copyWith(status: UploadItemStatus.uploading, progress: 0),
    );
    state = state.copyWith(uploadStatus: UploadStatus.uploading);

    Map<String, dynamic>? importMetadata;
    if (recording != null) {
      importMetadata = {
        'title': recording.title,
        'mbid': recording.id,
        if (recording.trackNumber != null) 'position': recording.trackNumber,
        if (recording.discNumber != null) 'disc_number': recording.discNumber,
        if (recording.albumTitle != null && recording.albumTitle!.isNotEmpty)
          'album_title': recording.albumTitle,
        if (recording.releaseMbid != null && recording.releaseMbid!.isNotEmpty)
          'album_mbid': recording.releaseMbid,
        if (recording.artistName != null && recording.artistName!.isNotEmpty)
          'artist_name': recording.artistName,
      };
    } else if (item.existingTitle != null && item.existingTitle!.trim().isNotEmpty) {
      importMetadata = {
        'title': item.existingTitle,
        if (item.existingTrackNumber != null) 'position': item.existingTrackNumber,
        if (item.existingDiscNumber != null) 'disc_number': item.existingDiscNumber,
        if (item.existingAlbum != null && item.existingAlbum!.isNotEmpty)
          'album_title': item.existingAlbum,
        if (item.existingArtist != null && item.existingArtist!.isNotEmpty)
          'artist_name': item.existingArtist,
      };
    }

    final upload = await _api.createUpload(
      libraryUuid: libraryUuid,
      filePath: uploadPath,
      fileBytes: uploadBytes,
      fileName: item.fileName,
      importMetadata: importMetadata,
      onSendProgress: (sent, total) {
        if (total > 0) {
          _updateItem(item.localId, (i) => i.copyWith(progress: sent / total));
        }
      },
    );

    developer.log(
      'Upload accepted: uuid=${upload.uuid}, '
      'importStatus=${upload.importStatus}',
      name: 'tayra.upload',
    );

    _updateItem(
      item.localId,
      (i) => i.copyWith(
        status: UploadItemStatus.pollingImport,
        progress: 1.0,
        uploadedUuid: upload.uuid,
        importReference: upload.importReference,
        importStatus: upload.importStatus,
      ),
    );

    if (upload.importReference != null) {
      pendingRefs[item.localId] = upload.importReference!;
    } else if (upload.importStatus == 'finished') {
      _updateItem(
        item.localId,
        (i) => i.copyWith(status: UploadItemStatus.finished),
      );
    } else {
      _updateItem(
        item.localId,
        (i) => i.copyWith(
          status: UploadItemStatus.errored,
          errorDetail:
              'Upload succeeded but no import reference was returned by the server.',
        ),
      );
    }
  }

  // ── Polling import status ──────────────────────────────────────────────

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    _consecutivePollErrors = 0;
    _pollMisses.clear();
    _pollGeneration++;
    final generation = _pollGeneration;
    developer.log(
      'Starting REST polling for ${state.items.where((i) => i.status == UploadItemStatus.pollingImport).length} upload(s) '
      '(max $_maxPollAttempts attempts, every ${_pollInterval.inSeconds}s)',
      name: 'tayra.upload',
    );
    // Poll immediately, then on interval.
    unawaited(_pollOnce(generation));
    _pollingTimer = Timer.periodic(_pollInterval, (_) async {
      await _pollOnce(generation);
    });
  }

  Future<void> _pollOnce(int generation) async {
    if (generation != _pollGeneration) return;
    _pollAttempts++;

    final pending =
        state.items
            .where((i) => i.status == UploadItemStatus.pollingImport)
            .toList();

    if (pending.isEmpty) {
      _pollingTimer?.cancel();
      if (generation != _pollGeneration) return;
      _finalizeBatchStatus();
      return;
    }

    if (_pollAttempts > _maxPollAttempts) {
      _pollingTimer?.cancel();
      if (generation != _pollGeneration) return;
      final elapsed = _pollInterval.inSeconds * _maxPollAttempts;
      for (final item in pending) {
        _updateItem(
          item.localId,
          (i) => i.copyWith(
            status: UploadItemStatus.errored,
            errorDetail:
                'Import timed out after ${elapsed ~/ 60} min '
                '(last status: ${item.importStatus ?? 'unknown'}). '
                'The file reached the server but processing never completed. '
                'Check Manage → Library → Uploads, or server celery logs for '
                'this upload${item.uploadedUuid != null ? ' (${item.uploadedUuid})' : ''}.',
          ),
        );
      }
      _finalizeBatchStatus();
      return;
    }

    try {
      var anySuccess = false;
      for (final item in pending) {
        UploadForOwner? upload;
        if (item.uploadedUuid != null && item.uploadedUuid!.isNotEmpty) {
          upload = await _api.getUploadByUuid(item.uploadedUuid!);
        }
        if (upload == null && item.importReference != null) {
          upload = await _api.getUploadByReference(item.importReference!);
        }
        if (generation != _pollGeneration) return;

        if (upload == null) {
          final misses = (_pollMisses[item.localId] ?? 0) + 1;
          _pollMisses[item.localId] = misses;
          developer.log(
            'Poll #$_pollAttempts: ${item.fileName} not found '
            '(miss $misses/$_maxPollMisses, uuid=${item.uploadedUuid}, '
            'ref=${item.importReference})',
            name: 'tayra.upload',
          );
          if (misses >= _maxPollMisses) {
            _updateItem(
              item.localId,
              (i) => i.copyWith(
                status: UploadItemStatus.errored,
                errorDetail:
                    'Upload was accepted but the server never returned it '
                    'while checking import status. Check Manage → Library → '
                    'Uploads for ${item.fileName}.',
              ),
            );
          }
          continue;
        }

        _pollMisses.remove(item.localId);
        anySuccess = true;
        developer.log(
          'Poll #$_pollAttempts: ${item.fileName} '
          'importStatus=${upload.importStatus} details=${upload.importDetails}',
          name: 'tayra.upload',
        );
        _applyImportStatus(
          item.localId,
          upload.importStatus,
          upload.importDetails,
        );
      }

      if (anySuccess) {
        _consecutivePollErrors = 0;
      }

      // Check if all done.
      if (!state.items.any((i) => i.status == UploadItemStatus.pollingImport)) {
        _pollingTimer?.cancel();
        if (generation != _pollGeneration) return;
        _finalizeBatchStatus();
      }
    } catch (e, st) {
      _consecutivePollErrors++;
      developer.log(
        'Poll #$_pollAttempts error ($_consecutivePollErrors consecutive): $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );

      if (_consecutivePollErrors >= _maxConsecutivePollErrors) {
        _pollingTimer?.cancel();
        if (generation != _pollGeneration) return;
        for (final item in state.items.where(
          (i) => i.status == UploadItemStatus.pollingImport,
        )) {
          _updateItem(
            item.localId,
            (i) => i.copyWith(
              status: UploadItemStatus.errored,
              errorDetail:
                  'Lost contact with server while checking import status '
                  '($_consecutivePollErrors consecutive errors). '
                  'Last error: ${_errorMessage(e)}',
            ),
          );
        }
        _finalizeBatchStatus();
      }
    }
  }

  void _applyImportStatus(
    String localId,
    String status,
    Map<String, dynamic> details,
  ) {
    switch (status) {
      case 'finished':
        _updateItem(
          localId,
          (i) => i.copyWith(
            status: UploadItemStatus.finished,
            importStatus: status,
            errorDetail: null,
          ),
        );
        Analytics.track('upload_import_finished');
        unawaited(
          ref.read(cachedFunkwhaleApiProvider).invalidateTrackAndAlbumCaches(),
        );

      case 'errored':
        final errorMsg = _extractImportError(details);
        _updateItem(
          localId,
          (i) => i.copyWith(
            status: UploadItemStatus.errored,
            importStatus: status,
            errorDetail: errorMsg,
          ),
        );
        Analytics.track('upload_import_errored', {'had_error': true});

      case 'skipped':
        final reason = _extractImportError(details);
        _updateItem(
          localId,
          (i) => i.copyWith(
            status: UploadItemStatus.errored,
            importStatus: status,
            errorDetail: 'Import was skipped by the server: $reason',
          ),
        );
        Analytics.track('upload_import_errored', {
          'had_error': true,
          'skipped': true,
        });

      default:
        _updateItem(localId, (i) => i.copyWith(importStatus: status));
    }
  }

  void _finalizeBatchStatus() {
    final finished = state.finishedCount;
    final errored = state.erroredCount;
    final total = state.items.length;

    if (errored == 0 && finished == total) {
      state = state.copyWith(uploadStatus: UploadStatus.finished);
    } else if (finished == 0 && errored > 0) {
      state = state.copyWith(
        uploadStatus: UploadStatus.errored,
        uploadError:
            errored == 1
                ? (state.items
                        .where((i) => i.status == UploadItemStatus.errored)
                        .firstOrNull
                        ?.errorDetail ??
                    'Import failed.')
                : '$errored of $total files failed to import.',
      );
    } else if (errored > 0) {
      state = state.copyWith(
        uploadStatus: UploadStatus.partial,
        uploadError: '$finished imported, $errored failed.',
      );
    } else {
      state = state.copyWith(uploadStatus: UploadStatus.finished);
    }
  }

  /// Extracts a human-readable error message from Funkwhale's import_details.
  ///
  /// Errored imports use `{"error_code": "...", "detail": ...}`.
  /// Skipped imports use `{"code": "already_imported_in_owned_libraries",
  ///                       "duplicates": "[uuid]"}`.
  String _extractImportError(Map<String, dynamic> details) {
    if (details.isEmpty) return 'No details provided.';

    // Skipped — duplicate track.
    final skipCode = details['code'] as String?;
    if (skipCode == 'already_imported_in_owned_libraries') {
      final dup = details['duplicates'];
      return 'This track is already in your library '
          '(duplicate upload: $dup).';
    }

    // Errored — structured error.
    final errorCode = details['error_code'] as String?;
    if (errorCode != null) {
      final detail = details['detail'];
      final suffix = _formatDetail(detail);

      return switch (errorCode) {
        'invalid_metadata' => _formatInvalidMetadata(detail, suffix),
        'missing_musicbrainz_id' =>
          suffix.isNotEmpty
              ? suffix
              : 'Only content tagged with a MusicBrainz ID is permitted on '
                  'this pod. Tag your files with MusicBrainz Picard, or use '
                  'the MusicBrainz lookup before uploading.',
        // Legacy servers put the full sentence in error_code.
        final c when c.toLowerCase().contains('musicbrainz') =>
          suffix.isNotEmpty ? '$c $suffix' : c,
        'track_uuid_not_found' =>
          'The specified MusicBrainz track was not found on the server.',
        'import_timeout' =>
          suffix.isNotEmpty
              ? suffix
              : 'Import exceeded the server time limit. The file was received; '
                  'relaunch it from Manage → Library → Uploads.',
        'unknown_error' =>
          suffix.isNotEmpty
              ? 'Server error during import: $suffix'
              : 'An unknown server error occurred during import.',
        _ => suffix.isNotEmpty ? '$errorCode: $suffix' : errorCode,
      };
    }

    return details.toString();
  }

  String _formatInvalidMetadata(dynamic detail, String suffix) {
    final combined = '$detail $suffix'.toLowerCase();
    if (combined.contains('cannot parse metadata') ||
        combined.contains('no tags found') ||
        combined.contains('unsupported format')) {
      return 'Could not read tags from this file. Tag it with MusicBrainz '
          'Picard or use MusicBrainz lookup before uploading.';
    }

    final fields = <String>[];
    if (detail is Map) {
      for (final key in detail.keys) {
        fields.add(_friendlyFieldName(key.toString()));
      }
    }
    if (fields.isEmpty) {
      return suffix.isNotEmpty
          ? 'Invalid or missing metadata: $suffix'
          : 'Invalid or missing metadata. Tag your files (e.g. with '
              'MusicBrainz Picard) or use MusicBrainz lookup before uploading.';
    }
    final fieldList = fields.join(', ');
    return 'Missing or invalid metadata ($fieldList). '
        'Tag your files (e.g. with MusicBrainz Picard) or use the MusicBrainz '
        'lookup before uploading.${suffix.isNotEmpty ? ' Details: $suffix' : ''}';
  }

  String _friendlyFieldName(String key) {
    return switch (key) {
      'title' => 'title',
      'artists' || 'artist' => 'artist',
      'album' => 'album',
      'mbid' => 'MusicBrainz ID',
      'position' => 'track number',
      _ => key,
    };
  }

  /// Recursively flattens a DRF serializer error dict into a readable string.
  String _formatDetail(dynamic detail) {
    if (detail == null) return '';
    if (detail is String) return detail;
    if (detail is List) return detail.map(_formatDetail).join(', ');
    if (detail is Map) {
      return detail.entries
          .map(
            (e) =>
                '${_friendlyFieldName(e.key.toString())}: ${_formatDetail(e.value)}',
          )
          .join('; ');
    }
    return detail.toString();
  }

  void reset() {
    _pollingTimer?.cancel();
    _pollGeneration++;
    _pollAttempts = 0;
    _consecutivePollErrors = 0;
    _cleanupTempFiles();
    state = const UploadState();
    Future.microtask(_init);
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        // Prefer structured API error bodies.
        final detail =
            data['detail'] ?? data['error'] ?? data['non_field_errors'];
        if (detail != null) {
          final formatted = _formatDetail(detail);
          if (formatted.isNotEmpty && formatted.length < 400) return formatted;
        }
      }
      final msg = data?.toString();
      if (msg != null && msg.isNotEmpty && msg.length < 200) return msg;
      return e.message ?? e.type.name;
    }
    return e.toString();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────

final uploadProvider =
    NotifierProvider.autoDispose<UploadNotifier, UploadState>(
      UploadNotifier.new,
    );
