import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/audio_tagger.dart';
import 'package:tayra/core/api/models.dart';

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

// ── Cover art state ──────────────────────────────────────────────────────

/// Describes the state of cover-art fetching from the Cover Art Archive.
enum CoverArtStatus { none, loading, loaded, error }

// ── Upload status ────────────────────────────────────────────────────────

enum UploadStatus {
  idle,
  embedding,
  uploading,
  pollingImport,
  finished,
  errored,
}

// ── Upload state ─────────────────────────────────────────────────────────

class UploadState {
  // Libraries
  final List<Library> libraries;
  final bool loadingLibraries;
  final String? libraryError;
  final String? selectedLibraryUuid;

  // Selected file
  final String? filePath;
  final String? fileName;
  final int? fileSize;

  // MusicBrainz
  final bool useMusicBrainz;
  final String mbRecordingId;
  final MbRecording? selectedMbRecording;
  final bool mbSearching;
  final List<MbRecording> mbResults;
  final String? mbSearchError;

  // Cover art
  final CoverArtStatus coverArtStatus;
  final Uint8List? coverArtBytes;
  final String? coverArtMime;
  final String? coverArtUrl;
  final bool embedCoverArt;

  // Upload state
  final UploadStatus uploadStatus;
  final double uploadProgress;
  final String? uploadedUuid;
  final String? importStatus;
  final String? importErrorDetail;
  final String? uploadError;

  const UploadState({
    this.libraries = const [],
    this.loadingLibraries = false,
    this.libraryError,
    this.selectedLibraryUuid,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.useMusicBrainz = false,
    this.mbRecordingId = '',
    this.selectedMbRecording,
    this.mbSearching = false,
    this.mbResults = const [],
    this.mbSearchError,
    this.coverArtStatus = CoverArtStatus.none,
    this.coverArtBytes,
    this.coverArtMime,
    this.coverArtUrl,
    this.embedCoverArt = true,
    this.uploadStatus = UploadStatus.idle,
    this.uploadProgress = 0.0,
    this.uploadedUuid,
    this.importStatus,
    this.importErrorDetail,
    this.uploadError,
  });

  bool get hasFile => filePath != null && fileName != null;
  bool get canUpload =>
      hasFile &&
      selectedLibraryUuid != null &&
      uploadStatus == UploadStatus.idle;

  UploadState copyWith({
    List<Library>? libraries,
    bool? loadingLibraries,
    Object? libraryError = _sentinel,
    Object? selectedLibraryUuid = _sentinel,
    Object? filePath = _sentinel,
    Object? fileName = _sentinel,
    Object? fileSize = _sentinel,
    bool? useMusicBrainz,
    String? mbRecordingId,
    Object? selectedMbRecording = _sentinel,
    bool? mbSearching,
    List<MbRecording>? mbResults,
    Object? mbSearchError = _sentinel,
    CoverArtStatus? coverArtStatus,
    Object? coverArtBytes = _sentinel,
    Object? coverArtMime = _sentinel,
    Object? coverArtUrl = _sentinel,
    bool? embedCoverArt,
    UploadStatus? uploadStatus,
    double? uploadProgress,
    Object? uploadedUuid = _sentinel,
    Object? importStatus = _sentinel,
    Object? importErrorDetail = _sentinel,
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
      filePath: filePath == _sentinel ? this.filePath : filePath as String?,
      fileName: fileName == _sentinel ? this.fileName : fileName as String?,
      fileSize: fileSize == _sentinel ? this.fileSize : fileSize as int?,
      useMusicBrainz: useMusicBrainz ?? this.useMusicBrainz,
      mbRecordingId: mbRecordingId ?? this.mbRecordingId,
      selectedMbRecording:
          selectedMbRecording == _sentinel
              ? this.selectedMbRecording
              : selectedMbRecording as MbRecording?,
      mbSearching: mbSearching ?? this.mbSearching,
      mbResults: mbResults ?? this.mbResults,
      mbSearchError:
          mbSearchError == _sentinel
              ? this.mbSearchError
              : mbSearchError as String?,
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
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadedUuid:
          uploadedUuid == _sentinel
              ? this.uploadedUuid
              : uploadedUuid as String?,
      importStatus:
          importStatus == _sentinel
              ? this.importStatus
              : importStatus as String?,
      importErrorDetail:
          importErrorDetail == _sentinel
              ? this.importErrorDetail
              : importErrorDetail as String?,
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

// ── Polling constants ────────────────────────────────────────────────────

/// How often to poll the server for import status.
const _pollInterval = Duration(seconds: 3);

/// Stop polling after this many attempts (~5 minutes at 3 s intervals).
const _maxPollAttempts = 100;

/// Stop polling after this many consecutive network/server errors.
const _maxConsecutivePollErrors = 5;

// ── Upload notifier ──────────────────────────────────────────────────────

class UploadNotifier extends Notifier<UploadState> {
  late final Dio _mbDio;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;

  /// Temporary tagged file to clean up after upload.
  File? _tempTaggedFile;

  @override
  UploadState build() {
    _mbDio =
        Dio()
          ..options.headers['User-Agent'] =
              'Tayra/1.0 (https://github.com/loren/tayra)'
          ..options.connectTimeout = const Duration(seconds: 10)
          ..options.receiveTimeout = const Duration(seconds: 20);

    ref.onDispose(() {
      _pollingTimer?.cancel();
      _cleanupTempFile();
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

  void _cleanupTempFile() {
    _tempTaggedFile?.deleteSync();
    _tempTaggedFile = null;
  }

  // ── Libraries ─────────────────────────────────────────────────────────

  Future<void> loadLibraries() async {
    state = state.copyWith(loadingLibraries: true, libraryError: null);
    try {
      final result = await _api.getLibraries(scope: 'me');
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

  Future<void> pickFile() async {
    String? initialDirectory;
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      initialDirectory: initialDirectory,
      allowedExtensions: [
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
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    state = state.copyWith(
      filePath: file.path,
      fileName: file.name,
      fileSize: file.size,
      uploadStatus: UploadStatus.idle,
      uploadProgress: 0.0,
      uploadedUuid: null,
      importStatus: null,
      importErrorDetail: null,
      uploadError: null,
    );
  }

  // ── MusicBrainz toggle ────────────────────────────────────────────────

  Future<void> setUseMusicBrainz(bool value) async {
    state = state.copyWith(
      useMusicBrainz: value,
      selectedMbRecording: null,
      coverArtStatus: CoverArtStatus.none,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseMusicBrainz, value);
  }

  void setMbRecordingId(String value) {
    // Typing manually invalidates any previously resolved recording.
    state = state.copyWith(
      mbRecordingId: value,
      selectedMbRecording: null,
      coverArtStatus: CoverArtStatus.none,
      coverArtBytes: null,
      coverArtMime: null,
      coverArtUrl: null,
    );
  }

  void selectMbRecording(MbRecording recording) {
    state = state.copyWith(
      mbRecordingId: recording.id,
      selectedMbRecording: recording,
    );
    // Automatically fetch cover art when a recording is selected.
    if (recording.releaseMbid != null) {
      _fetchCoverArt(recording.releaseMbid!);
    } else {
      state = state.copyWith(coverArtStatus: CoverArtStatus.none);
    }
  }

  void setEmbedCoverArt(bool value) {
    state = state.copyWith(embedCoverArt: value);
  }

  // ── MusicBrainz search ─────────────────────────────────────────────────

  Future<void> searchMusicBrainz(String title, String artist) async {
    if (title.trim().isEmpty) return;

    state = state.copyWith(
      mbSearching: true,
      mbResults: [],
      mbSearchError: null,
    );

    try {
      var query = 'recording:"${title.trim()}"';
      if (artist.trim().isNotEmpty) {
        query += ' AND artist:"${artist.trim()}"';
      }

      final response = await _mbDio.get(
        'https://musicbrainz.org/ws/2/recording/',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 10},
      );

      final recordings =
          (response.data['recordings'] as List<dynamic>? ?? []).map((r) {
            final map = r as Map<String, dynamic>;
            final credits = map['artist-credit'] as List<dynamic>? ?? [];
            String? artistName;
            if (credits.isNotEmpty) {
              final credit = credits.first as Map<String, dynamic>?;
              artistName =
                  (credit?['artist'] as Map<String, dynamic>?)?['name']
                      as String?;
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
              title: map['title'] as String,
              artistName: artistName,
              albumTitle: albumTitle,
              releaseMbid: releaseMbid,
              releaseDate: releaseDate,
              year: year,
              lengthMs: map['length'] as int?,
            );
          }).toList();

      state = state.copyWith(mbSearching: false, mbResults: recordings);
    } catch (e) {
      state = state.copyWith(
        mbSearching: false,
        mbSearchError: 'MusicBrainz search failed: ${_errorMessage(e)}',
      );
    }
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
            trackNumber = trackMap['position'] as int?;
            discNumber = mediumMap['position'] as int? ?? 1;
            break outer;
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
      // The Cover Art Archive redirects to the actual image hosted on
      // archive.org. Dio follows redirects automatically.
      final url = 'https://coverartarchive.org/release/$releaseMbid/front';

      // First, check that cover art exists (HEAD-like GET with small range).
      final imageResponse = await _mbDio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (imageResponse.statusCode == 200 && imageResponse.data != null) {
        final bytes = Uint8List.fromList(imageResponse.data!);
        // Determine MIME type from response headers or magic bytes.
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
      // Cover art not available — not an error the user needs to act on.
      state = state.copyWith(coverArtStatus: CoverArtStatus.error);
    }
  }

  // ── Metadata embedding ─────────────────────────────────────────────────

  /// Returns `true` when the selected file's extension is supported by
  /// the audio tagger for tag writing.
  bool get _canEmbedTags {
    final name = state.fileName;
    if (name == null) return false;
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    return _taggableExtensions.contains(ext);
  }

  /// Creates a temporary copy of the audio file with MusicBrainz metadata
  /// (and optionally cover art) embedded directly into its tags.
  ///
  /// Returns the path to the tagged temp file, or `null` if embedding was
  /// skipped or failed (falls back to uploading the original file).
  Future<String?> _embedMetadata(MbRecording recording) async {
    if (!_canEmbedTags) {
      developer.log(
        'Tag embedding skipped: unsupported format (${state.fileName})',
        name: 'tayra.upload',
      );
      return null;
    }

    final originalPath = state.filePath!;
    final originalName = state.fileName!;
    developer.log(
      'Embedding tags into temp copy of "$originalName"',
      name: 'tayra.upload',
    );

    try {
      // Build metadata from the MusicBrainz recording.
      final meta = AudioMetadata(
        title: recording.title,
        artist: recording.artistName,
        album: recording.albumTitle,
        trackNumber: recording.trackNumber,
        discNumber: recording.discNumber,
        year: recording.year,
        musicBrainzRecordingId: recording.id,
        musicBrainzReleaseId: recording.releaseMbid,
        coverArt:
            (state.embedCoverArt &&
                    state.coverArtStatus == CoverArtStatus.loaded &&
                    state.coverArtBytes != null)
                ? state.coverArtBytes
                : null,
        coverArtMime:
            (state.embedCoverArt &&
                    state.coverArtStatus == CoverArtStatus.loaded &&
                    state.coverArtBytes != null)
                ? state.coverArtMime
                : null,
      );

      if (meta.coverArt != null) {
        developer.log(
          'Embedding cover art (${meta.coverArt!.length} bytes, '
          '${meta.coverArtMime})',
          name: 'tayra.upload',
        );
      }

      // Tag the audio file using the pure-Dart tagger.
      final taggedBytes = await tagAudioFile(originalPath, meta);

      if (taggedBytes == null) {
        developer.log(
          'Tag embedding returned null (unsupported format?)',
          name: 'tayra.upload',
        );
        return null;
      }

      // Write to a temp file.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'tayra_upload_$originalName'));
      await tempFile.writeAsBytes(taggedBytes, flush: true);

      developer.log(
        'Tag embedding complete: ${tempFile.path} '
        '(${taggedBytes.length} bytes)',
        name: 'tayra.upload',
      );

      _tempTaggedFile = tempFile;
      return tempFile.path;
    } catch (e, st) {
      // If tagging fails for any reason, fall back to uploading the
      // original file as-is. The server-side import_metadata will still
      // carry the MusicBrainz data.
      developer.log(
        'Tag embedding failed, falling back to original file: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ── Upload ─────────────────────────────────────────────────────────────

  Future<void> upload() async {
    final path = state.filePath;
    final name = state.fileName;
    final libraryUuid = state.selectedLibraryUuid;

    if (path == null || name == null || libraryUuid == null) return;

    developer.log(
      'Starting upload: "$name" → library $libraryUuid',
      name: 'tayra.upload',
    );

    state = state.copyWith(
      uploadStatus: UploadStatus.uploading,
      uploadProgress: 0.0,
      uploadError: null,
    );

    try {
      // ── Resolve MusicBrainz recording ──────────────────────────────────
      MbRecording? recording;
      if (state.useMusicBrainz && state.mbRecordingId.isNotEmpty) {
        recording = state.selectedMbRecording;
        if (recording == null || recording.id != state.mbRecordingId) {
          developer.log(
            'Fetching MusicBrainz recording ${state.mbRecordingId}',
            name: 'tayra.upload',
          );
          recording = await _fetchMbRecording(state.mbRecordingId);
        }
        if (recording == null) {
          developer.log(
            'MusicBrainz recording not found: ${state.mbRecordingId}',
            name: 'tayra.upload',
          );
          state = state.copyWith(
            uploadStatus: UploadStatus.idle,
            uploadError:
                'Could not find MusicBrainz recording for the given ID. '
                'Please check the ID or search again.',
          );
          return;
        }
        developer.log(
          'MusicBrainz recording resolved: "${recording.title}" '
          'by ${recording.artistName} '
          '(album: ${recording.albumTitle}, '
          'track: ${recording.trackNumber}, disc: ${recording.discNumber}, '
          'year: ${recording.year})',
          name: 'tayra.upload',
        );
      }

      // ── Embed tags into a temp copy ────────────────────────────────────
      String uploadPath = path;
      if (recording != null) {
        state = state.copyWith(uploadStatus: UploadStatus.embedding);

        final taggedPath = await _embedMetadata(recording);
        if (taggedPath != null) {
          uploadPath = taggedPath;
          developer.log(
            'Using tagged temp file: $uploadPath',
            name: 'tayra.upload',
          );
        } else {
          developer.log(
            'Using original file (embedding skipped or failed): $uploadPath',
            name: 'tayra.upload',
          );
        }

        state = state.copyWith(
          uploadStatus: UploadStatus.uploading,
          uploadProgress: 0.0,
        );
      }

      // ── Build import_metadata for Funkwhale ────────────────────────────
      // Sent as a sidecar in addition to the embedded tags. Funkwhale's
      // ImportMetadataSerializer validates this object. Valid fields:
      //   title (string, required), mbid (uuid), position (int ≥ 1),
      //   description, copyright, tags (list<string>), license (code),
      //   cover (attachment uuid), album (integer PK of existing Album).
      //
      // We do NOT send `album` here because the server expects an existing
      // Album database PK (integer), which we don't have. Album/artist
      // info is embedded in the audio file tags and Funkwhale extracts it
      // from there during import processing.
      Map<String, dynamic>? importMetadata;
      if (recording != null) {
        importMetadata = {
          'title': recording.title,
          'mbid': recording.id,
          if (recording.trackNumber != null) 'position': recording.trackNumber,
        };
        developer.log('import_metadata: $importMetadata', name: 'tayra.upload');
      }

      // ── Upload ─────────────────────────────────────────────────────────
      developer.log('Sending upload request…', name: 'tayra.upload');
      final upload = await _api.createUpload(
        libraryUuid: libraryUuid,
        filePath: uploadPath,
        fileName: name,
        importMetadata: importMetadata,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );

      // Clean up the temp file now that the upload completed.
      _cleanupTempFile();

      developer.log(
        'Upload accepted: uuid=${upload.uuid}, '
        'importStatus=${upload.importStatus}',
        name: 'tayra.upload',
      );

      state = state.copyWith(
        uploadStatus: UploadStatus.pollingImport,
        uploadProgress: 1.0,
        uploadedUuid: upload.uuid,
        importStatus: upload.importStatus,
      );

      _startPolling(upload.importReference);
    } catch (e, st) {
      _cleanupTempFile();
      developer.log(
        'Upload error: $e',
        name: 'tayra.upload',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        uploadStatus: UploadStatus.idle,
        uploadError: 'Upload failed: ${_errorMessage(e)}',
      );
    }
  }

  // ── Polling import status tracking ────────────────────────────────────
  void _handleImportStatus(String status, Map<String, dynamic> details) {
    switch (status) {
      case 'finished':
        _pollingTimer?.cancel();
        developer.log(
          'Import finished (via status handler)',
          name: 'tayra.upload',
        );
        state = state.copyWith(
          uploadStatus: UploadStatus.finished,
          importStatus: status,
        );

      case 'errored':
        _pollingTimer?.cancel();
        final errorMsg = _extractImportError(details);
        developer.log(
          'Import errored: $errorMsg (details=$details)',
          name: 'tayra.upload',
        );
        state = state.copyWith(
          uploadStatus: UploadStatus.errored,
          importStatus: status,
          importErrorDetail: errorMsg,
        );

      case 'skipped':
        _pollingTimer?.cancel();
        final reason = _extractImportError(details);
        developer.log(
          'Import skipped: $reason (details=$details)',
          name: 'tayra.upload',
        );
        state = state.copyWith(
          uploadStatus: UploadStatus.errored,
          importStatus: status,
          importErrorDetail: 'Import was skipped by the server: $reason',
        );

      default:
        // Still pending/draft — update the displayed status.
        state = state.copyWith(importStatus: status);
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
        'invalid_metadata' => 'Invalid metadata: $suffix',
        'track_uuid_not_found' =>
          'The specified MusicBrainz track was not found on the server.',
        'unknown_error' => 'An unknown server error occurred. $suffix',
        _ => '$errorCode. $suffix',
      };
    }

    return details.toString();
  }

  /// Recursively flattens a DRF serializer error dict into a readable string,
  /// matching how ImportStatusModal.vue's getErrors() works.
  String _formatDetail(dynamic detail) {
    if (detail == null) return '';
    if (detail is String) return detail;
    if (detail is List) return detail.map(_formatDetail).join(', ');
    if (detail is Map) {
      return detail.entries
          .map((e) => '${e.key}: ${_formatDetail(e.value)}')
          .join('; ');
    }
    return detail.toString();
  }

  void _startPolling(String? importReference) {
    if (importReference == null) {
      developer.log(
        'No import_reference available — cannot poll',
        name: 'tayra.upload',
      );
      state = state.copyWith(
        uploadStatus: UploadStatus.errored,
        importErrorDetail:
            'Upload succeeded but no import reference was returned by the server.',
      );
      return;
    }
    _pollingTimer?.cancel();
    developer.log(
      'Starting REST polling for importReference=$importReference '
      '(max $_maxPollAttempts attempts, every ${_pollInterval.inSeconds}s)',
      name: 'tayra.upload',
    );
    _pollingTimer = Timer.periodic(_pollInterval, (_) async {
      await _pollOnce(importReference);
    });
  }

  Future<void> _pollOnce(String importReference) async {
    _pollAttempts++;

    // Hard timeout: give up after _maxPollAttempts.
    if (_pollAttempts > _maxPollAttempts) {
      _pollingTimer?.cancel();
      final elapsed = _pollInterval.inSeconds * _maxPollAttempts;
      developer.log(
        'Import polling timed out after $elapsed s '
        '(importReference=$importReference)',
        name: 'tayra.upload',
      );
      state = state.copyWith(
        uploadStatus: UploadStatus.errored,
        importErrorDetail:
            'Import timed out after ${elapsed ~/ 60} min. '
            'The file was uploaded but the server did not finish processing it. '
            'Check your Funkwhale library manually.',
      );
      return;
    }

    try {
      final upload = await _api.getUploadByReference(importReference);

      // null means the upload isn't visible yet (still pending in the queue)
      // — treat as "still pending" and keep polling.
      if (upload == null) {
        developer.log(
          'Poll #$_pollAttempts: upload not found yet for '
          'importReference=$importReference (still pending)',
          name: 'tayra.upload',
        );
        _consecutivePollErrors = 0;
        return;
      }

      _consecutivePollErrors = 0;

      developer.log(
        'Poll #$_pollAttempts: importStatus=${upload.importStatus} '
        '(importReference=$importReference, details=${upload.importDetails})',
        name: 'tayra.upload',
      );

      _handleImportStatus(upload.importStatus, upload.importDetails);
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
        developer.log(
          'Stopping polling after $_maxConsecutivePollErrors consecutive errors',
          name: 'tayra.upload',
        );
        state = state.copyWith(
          uploadStatus: UploadStatus.errored,
          importErrorDetail:
              'Lost contact with server while checking import status '
              '($_consecutivePollErrors consecutive errors). '
              'Last error: ${_errorMessage(e)}',
        );
      }
      // Otherwise keep trying — transient network glitch.
    }
  }

  void reset() {
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    _consecutivePollErrors = 0;
    _cleanupTempFile();
    state = const UploadState();
    Future.microtask(_init);
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?.toString();
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
