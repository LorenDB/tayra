import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

// ── Audio Tagger ────────────────────────────────────────────────────────
//
// Pure-Dart metadata writer for MP3 (ID3v2.4), FLAC, and OGG Vorbis/Opus
// files. Writes standard tags plus MusicBrainz custom fields and cover
// art directly into the audio file bytes.

/// Metadata to embed into an audio file.
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? musicBrainzRecordingId;
  final String? musicBrainzReleaseId;
  final Uint8List? coverArt;
  final String? coverArtMime;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.musicBrainzRecordingId,
    this.musicBrainzReleaseId,
    this.coverArt,
    this.coverArtMime,
  });
}

/// Tags an audio file with the given metadata. Returns tagged bytes or
/// `null` when the format is not supported.
Future<Uint8List?> tagAudioFile(String filePath, AudioMetadata meta) async {
  final bytes = await File(filePath).readAsBytes();
  return _tagByExtension(bytes, _extensionOf(filePath), meta);
}

/// Tags raw audio [bytes] with the given metadata. Returns tagged bytes or
/// `null` when the format is not supported.
///
/// Web-safe: does not touch dart:io.
Uint8List? tagAudioFileBytes(
  Uint8List bytes,
  String fileName,
  AudioMetadata meta,
) {
  return _tagByExtension(bytes, _extensionOf(fileName), meta);
}

/// Reads basic tags from an audio file. Returns `null` when the format is
/// unsupported or no tags can be parsed. Failures are non-fatal.
Future<AudioMetadata?> readAudioMetadata(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    return await _readByExtension(bytes, _extensionOf(filePath));
  } catch (e, st) {
    developer.log(
      'AudioTagger: failed to read metadata from $filePath: $e',
      name: 'tayra.tagger',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// Reads basic tags from raw audio [bytes]. Returns `null` when the format
/// is unsupported or no tags can be parsed. Failures are non-fatal.
///
/// Web-safe: does not touch dart:io.
Future<AudioMetadata?> readAudioMetadataBytes(
  Uint8List bytes,
  String fileName,
) async {
  try {
    return await _readByExtension(bytes, _extensionOf(fileName));
  } catch (e, st) {
    developer.log(
      'AudioTagger: failed to read metadata from $fileName: $e',
      name: 'tayra.tagger',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

String _extensionOf(String fileNameOrPath) {
  return fileNameOrPath.split('.').last.toLowerCase();
}

Uint8List? _tagByExtension(Uint8List bytes, String ext, AudioMetadata meta) {
  switch (ext) {
    case 'mp3':
      return _tagMp3(bytes, meta);
    case 'flac':
      return _tagFlac(bytes, meta);
    case 'ogg':
    case 'oga':
      return _tagOggVorbis(bytes, meta);
    case 'opus':
      return _tagOggOpus(bytes, meta);
    default:
      developer.log(
        'AudioTagger: unsupported format .$ext',
        name: 'tayra.tagger',
      );
      return null;
  }
}

Future<AudioMetadata?> _readByExtension(Uint8List bytes, String ext) async {
  switch (ext) {
    case 'mp3':
      return _readMp3(bytes);
    case 'flac':
      return _readFlac(bytes);
    case 'ogg':
    case 'oga':
      return _readOgg(bytes, _OggCodec.vorbis);
    case 'opus':
      return _readOgg(bytes, _OggCodec.opus);
    default:
      return null;
  }
}

// ── Metadata readers ───────────────────────────────────────────────────

AudioMetadata? _readMp3(Uint8List data) {
  if (data.length < 10 ||
      data[0] != 0x49 ||
      data[1] != 0x44 ||
      data[2] != 0x33) {
    return null;
  }

  final version = data[3]; // 2, 3, or 4
  final flags = data[5];
  final tagSize = _readSyncsafe(data, 6);
  int offset = 10;

  // Skip extended header if present.
  if ((flags & 0x40) != 0 && offset + 4 <= data.length) {
    final extSize =
        version >= 4
            ? _readSyncsafe(data, offset)
            : _readUint32BE(data, offset);
    offset += extSize;
  }

  final end = (10 + tagSize).clamp(0, data.length);
  String? title;
  String? artist;
  String? album;
  int? trackNumber;
  int? discNumber;
  int? year;
  String? mbRecordingId;
  String? mbReleaseId;

  while (offset + 10 <= end) {
    final id = ascii.decode(
      data.sublist(offset, offset + 4),
      allowInvalid: true,
    );
    if (id == '\x00\x00\x00\x00' || !RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) {
      break;
    }
    final frameSize =
        version >= 4
            ? _readSyncsafe(data, offset + 4)
            : _readUint32BE(data, offset + 4);
    if (frameSize <= 0 || offset + 10 + frameSize > end) break;

    final frameData = data.sublist(offset + 10, offset + 10 + frameSize);
    offset += 10 + frameSize;

    if (id == 'TIT2') {
      title = _decodeId3Text(frameData);
    } else if (id == 'TPE1') {
      artist = _decodeId3Text(frameData);
    } else if (id == 'TALB') {
      album = _decodeId3Text(frameData);
    } else if (id == 'TRCK') {
      trackNumber = _parseLeadingInt(_decodeId3Text(frameData));
    } else if (id == 'TPOS') {
      discNumber = _parseLeadingInt(_decodeId3Text(frameData));
    } else if (id == 'TDRC' || id == 'TYER' || id == 'TDAT') {
      year ??= _parseLeadingInt(_decodeId3Text(frameData));
    } else if (id == 'UFID' && mbRecordingId == null) {
      mbRecordingId = _decodeId3Ufid(frameData);
    } else if (id == 'TXXX') {
      final txxx = _decodeId3Txxx(frameData);
      if (txxx == null) continue;
      final desc = txxx.$1.toLowerCase().trim();
      if (desc == 'musicbrainz recording id' ||
          desc == 'musicbrainz track id') {
        mbRecordingId = txxx.$2;
      } else if (desc == 'musicbrainz album id' ||
          desc == 'musicbrainz release id') {
        mbReleaseId = txxx.$2;
      }
    }
  }

  if (title == null &&
      artist == null &&
      album == null &&
      mbRecordingId == null) {
    return null;
  }

  return AudioMetadata(
    title: title,
    artist: artist,
    album: album,
    trackNumber: trackNumber,
    discNumber: discNumber,
    year: year,
    musicBrainzRecordingId: mbRecordingId,
    musicBrainzReleaseId: mbReleaseId,
  );
}

String? _decodeId3Text(Uint8List frameData) {
  if (frameData.isEmpty) return null;
  final encoding = frameData[0];
  final body = frameData.sublist(1);
  try {
    switch (encoding) {
      case 0: // ISO-8859-1
        return _stripNulls(latin1.decode(body, allowInvalid: true)).trim();
      case 1: // UTF-16 with BOM
      case 2: // UTF-16BE
        return _stripNulls(_decodeUtf16(body, encoding == 2)).trim();
      case 3: // UTF-8
        return _stripNulls(utf8.decode(body, allowMalformed: true)).trim();
      default:
        return _stripNulls(utf8.decode(body, allowMalformed: true)).trim();
    }
  } catch (_) {
    return null;
  }
}

String? _decodeId3Ufid(Uint8List frameData) {
  // Picard stores the recording MBID as UFID with owner musicbrainz.org.
  final nul = frameData.indexOf(0);
  if (nul <= 0 || nul + 1 >= frameData.length) return null;
  final owner = latin1.decode(
    frameData.sublist(0, nul),
    allowInvalid: true,
  );
  if (!owner.toLowerCase().contains('musicbrainz.org')) return null;
  final id = utf8
      .decode(frameData.sublist(nul + 1), allowMalformed: true)
      .replaceAll(RegExp(r'\x00+$'), '')
      .trim();
  return id.isEmpty ? null : id;
}

(String, String)? _decodeId3Txxx(Uint8List frameData) {
  if (frameData.isEmpty) return null;
  final encoding = frameData[0];
  final body = frameData.sublist(1);
  try {
    if (encoding == 0 || encoding == 3) {
      final nullIdx = body.indexOf(0);
      if (nullIdx < 0) return null;
      final descBytes = body.sublist(0, nullIdx);
      final valBytes = body.sublist(nullIdx + 1);
      final description =
          encoding == 0
              ? latin1.decode(descBytes, allowInvalid: true)
              : utf8.decode(descBytes, allowMalformed: true);
      final value =
          encoding == 0
              ? latin1.decode(valBytes, allowInvalid: true)
              : utf8.decode(valBytes, allowMalformed: true);
      return (description, _stripNulls(value).trim());
    }
    // UTF-16 variants: null separator is 0x00 0x00
    for (int i = 0; i + 1 < body.length; i += 2) {
      if (body[i] == 0 && body[i + 1] == 0) {
        final desc = _decodeUtf16(body.sublist(0, i), encoding == 2);
        final value = _decodeUtf16(body.sublist(i + 2), encoding == 2);
        return (desc, _stripNulls(value).trim());
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _decodeUtf16(Uint8List data, bool forceBe) {
  if (data.isEmpty) return '';
  Endian endian = forceBe ? Endian.big : Endian.little;
  int start = 0;
  if (data.length >= 2) {
    if (data[0] == 0xFF && data[1] == 0xFE) {
      endian = Endian.little;
      start = 2;
    } else if (data[0] == 0xFE && data[1] == 0xFF) {
      endian = Endian.big;
      start = 2;
    }
  }
  final codeUnits = <int>[];
  for (int i = start; i + 1 < data.length; i += 2) {
    final unit =
        endian == Endian.little
            ? (data[i] | (data[i + 1] << 8))
            : ((data[i] << 8) | data[i + 1]);
    if (unit == 0) break;
    codeUnits.add(unit);
  }
  return String.fromCharCodes(codeUnits);
}

String _stripNulls(String s) => s.replaceAll(RegExp(r'\x00+'), '');

int? _parseLeadingInt(String? s) {
  if (s == null || s.isEmpty) return null;
  final match = RegExp(r'^(\d+)').firstMatch(s.trim());
  return match != null ? int.tryParse(match.group(1)!) : null;
}

int _readUint32BE(Uint8List data, int offset) {
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

AudioMetadata? _readFlac(Uint8List data) {
  if (data.length < 8 ||
      data[0] != 0x66 ||
      data[1] != 0x4C ||
      data[2] != 0x61 ||
      data[3] != 0x43) {
    return null;
  }

  int offset = 4;
  bool lastBlock = false;
  while (!lastBlock && offset + 4 <= data.length) {
    final header = data[offset];
    lastBlock = (header & 0x80) != 0;
    final blockType = header & 0x7F;
    final blockLen =
        (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
    if (offset + 4 + blockLen > data.length) break;
    final blockData = data.sublist(offset + 4, offset + 4 + blockLen);
    offset += 4 + blockLen;

    if (blockType == 4) {
      // Vorbis comment
      return _metadataFromVorbisComments(_parseVorbisComments(blockData));
    }
  }
  return null;
}

AudioMetadata? _readOgg(Uint8List data, _OggCodec codec) {
  final pages = _parseOggPages(data);
  for (int i = 1; i < pages.length; i++) {
    final payload = pages[i].payload;
    if (codec == _OggCodec.vorbis &&
        payload.length >= 7 &&
        payload[0] == 0x03 &&
        utf8.decode(payload.sublist(1, 7), allowMalformed: true) == 'vorbis') {
      return _metadataFromVorbisComments(
        _parseVorbisComments(payload.sublist(7)),
      );
    }
    if (codec == _OggCodec.opus &&
        payload.length >= 8 &&
        utf8.decode(payload.sublist(0, 8), allowMalformed: true) ==
            'OpusTags') {
      return _metadataFromVorbisComments(
        _parseVorbisComments(payload.sublist(8)),
      );
    }
  }
  return null;
}

Map<String, String> _parseVorbisComments(Uint8List data) {
  final result = <String, String>{};
  if (data.length < 8) return result;
  try {
    int offset = 0;
    final vendorLen = _readUint32LE(data, offset);
    offset += 4 + vendorLen;
    if (offset + 4 > data.length) return result;
    final commentCount = _readUint32LE(data, offset);
    offset += 4;
    for (int i = 0; i < commentCount && offset + 4 <= data.length; i++) {
      final len = _readUint32LE(data, offset);
      offset += 4;
      if (offset + len > data.length) break;
      final comment = utf8.decode(
        data.sublist(offset, offset + len),
        allowMalformed: true,
      );
      offset += len;
      final eq = comment.indexOf('=');
      if (eq <= 0) continue;
      final key = comment.substring(0, eq).toUpperCase();
      final value = comment.substring(eq + 1);
      // Keep first occurrence for each key.
      result.putIfAbsent(key, () => value);
    }
  } catch (_) {
    // best-effort
  }
  return result;
}

AudioMetadata? _metadataFromVorbisComments(Map<String, String> comments) {
  if (comments.isEmpty) return null;
  final title = comments['TITLE'];
  final artist = comments['ARTIST'];
  final album = comments['ALBUM'];
  final trackNumber = _parseLeadingInt(comments['TRACKNUMBER']);
  final discNumber = _parseLeadingInt(comments['DISCNUMBER']);
  final year = _parseLeadingInt(comments['DATE'] ?? comments['YEAR']);
  final mbRecordingId =
      comments['MUSICBRAINZ_TRACKID'] ?? comments['MUSICBRAINZ_RECORDINGID'];
  final mbReleaseId =
      comments['MUSICBRAINZ_ALBUMID'] ?? comments['MUSICBRAINZ_RELEASEID'];

  if (title == null &&
      artist == null &&
      album == null &&
      mbRecordingId == null) {
    return null;
  }

  return AudioMetadata(
    title: title,
    artist: artist,
    album: album,
    trackNumber: trackNumber,
    discNumber: discNumber,
    year: year,
    musicBrainzRecordingId: mbRecordingId,
    musicBrainzReleaseId: mbReleaseId,
  );
}

// ── ID3v2.4 (MP3) ──────────────────────────────────────────────────────

Uint8List _tagMp3(Uint8List original, AudioMetadata meta) {
  // Locate the audio data by stripping any existing ID3v2 header.
  int audioStart = 0;
  if (original.length >= 10 &&
      original[0] == 0x49 && // 'I'
      original[1] == 0x44 && // 'D'
      original[2] == 0x33) {
    // '3'
    final size = _readSyncsafe(original, 6);
    audioStart = 10 + size;
  }

  // Strip trailing ID3v1 tag (128 bytes starting with "TAG").
  int audioEnd = original.length;
  if (audioEnd - audioStart > 128) {
    final tagOffset = audioEnd - 128;
    if (original[tagOffset] == 0x54 && // 'T'
        original[tagOffset + 1] == 0x41 && // 'A'
        original[tagOffset + 2] == 0x47) {
      // 'G'
      audioEnd = tagOffset;
    }
  }

  final audioData = Uint8List.sublistView(original, audioStart, audioEnd);

  // Build new ID3v2.4 tag.
  final frames = BytesBuilder(copy: false);

  void addTextFrame(String id, String value) {
    final encoded = utf8.encode(value);
    final frameData = BytesBuilder(copy: false);
    frameData.addByte(0x03); // UTF-8 encoding
    frameData.add(encoded);

    final header = BytesBuilder(copy: false);
    header.add(ascii.encode(id));
    header.add(_writeSyncsafe(frameData.length));
    header.add([0x00, 0x00]); // flags
    header.add(frameData.takeBytes());
    frames.add(header.takeBytes());
  }

  void addTxxxFrame(String description, String value) {
    final descBytes = utf8.encode(description);
    final valBytes = utf8.encode(value);
    final frameData = BytesBuilder(copy: false);
    frameData.addByte(0x03); // UTF-8 encoding
    frameData.add(descBytes);
    frameData.addByte(0x00); // null separator
    frameData.add(valBytes);

    final header = BytesBuilder(copy: false);
    header.add(ascii.encode('TXXX'));
    header.add(_writeSyncsafe(frameData.length));
    header.add([0x00, 0x00]); // flags
    header.add(frameData.takeBytes());
    frames.add(header.takeBytes());
  }

  if (meta.title != null) addTextFrame('TIT2', meta.title!);
  if (meta.artist != null) addTextFrame('TPE1', meta.artist!);
  if (meta.album != null) addTextFrame('TALB', meta.album!);
  if (meta.trackNumber != null) {
    addTextFrame('TRCK', meta.trackNumber.toString());
  }
  if (meta.discNumber != null) {
    addTextFrame('TPOS', meta.discNumber.toString());
  }
  if (meta.year != null) {
    addTextFrame('TDRC', meta.year.toString());
  }

  // MusicBrainz custom tags.
  if (meta.musicBrainzRecordingId != null) {
    addTxxxFrame('MusicBrainz Recording Id', meta.musicBrainzRecordingId!);
  }
  if (meta.musicBrainzReleaseId != null) {
    addTxxxFrame('MusicBrainz Album Id', meta.musicBrainzReleaseId!);
  }

  // Cover art (APIC frame).
  if (meta.coverArt != null) {
    final mime = meta.coverArtMime ?? 'image/jpeg';
    final mimeBytes = ascii.encode(mime);
    final frameData = BytesBuilder(copy: false);
    frameData.addByte(0x00); // encoding: ISO-8859-1 for MIME type
    frameData.add(mimeBytes);
    frameData.addByte(0x00); // null terminator for MIME
    frameData.addByte(0x03); // picture type: Cover (front)
    frameData.addByte(0x00); // null terminator for description
    frameData.add(meta.coverArt!);

    final header = BytesBuilder(copy: false);
    header.add(ascii.encode('APIC'));
    header.add(_writeSyncsafe(frameData.length));
    header.add([0x00, 0x00]); // flags
    header.add(frameData.takeBytes());
    frames.add(header.takeBytes());
  }

  final framesBytes = frames.takeBytes();

  // Assemble the ID3v2.4 header.
  final result = BytesBuilder(copy: false);
  result.add(ascii.encode('ID3'));
  result.add([0x04, 0x00]); // version 2.4.0
  result.addByte(0x00); // flags
  result.add(_writeSyncsafe(framesBytes.length));
  result.add(framesBytes);
  result.add(audioData);

  return result.takeBytes();
}

int _readSyncsafe(Uint8List data, int offset) {
  return (data[offset] & 0x7F) << 21 |
      (data[offset + 1] & 0x7F) << 14 |
      (data[offset + 2] & 0x7F) << 7 |
      (data[offset + 3] & 0x7F);
}

Uint8List _writeSyncsafe(int value) {
  return Uint8List.fromList([
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ]);
}

// ── FLAC ────────────────────────────────────────────────────────────────

Uint8List _tagFlac(Uint8List original, AudioMetadata meta) {
  // FLAC format: "fLaC" (4 bytes) + metadata blocks + audio frames.
  if (original.length < 8 ||
      original[0] != 0x66 || // 'f'
      original[1] != 0x4C || // 'L'
      original[2] != 0x61 || // 'a'
      original[3] != 0x43) {
    // 'C'
    developer.log('Not a FLAC file', name: 'tayra.tagger');
    return original;
  }

  // Parse existing metadata blocks.
  final existingBlocks = <_FlacBlock>[];
  int offset = 4;
  bool lastBlock = false;

  while (!lastBlock && offset < original.length) {
    final header = original[offset];
    lastBlock = (header & 0x80) != 0;
    final blockType = header & 0x7F;
    final blockLen =
        (original[offset + 1] << 16) |
        (original[offset + 2] << 8) |
        original[offset + 3];
    final blockData = Uint8List.sublistView(
      original,
      offset + 4,
      offset + 4 + blockLen,
    );
    existingBlocks.add(_FlacBlock(blockType, blockData));
    offset += 4 + blockLen;
  }

  // Audio frames start at `offset`.
  final audioFrames = Uint8List.sublistView(original, offset);

  // Build new Vorbis Comment block (type 4).
  final vorbisComment = _buildVorbisComment(meta);

  // Build new Picture block (type 6) if cover art is provided.
  Uint8List? pictureBlock;
  if (meta.coverArt != null) {
    pictureBlock = _buildFlacPicture(
      meta.coverArt!,
      meta.coverArtMime ?? 'image/jpeg',
    );
  }

  // Reassemble metadata blocks: keep all except old comment/picture blocks.
  final result = BytesBuilder(copy: false);
  result.add(ascii.encode('fLaC'));

  final newBlocks = <_FlacBlock>[];
  for (final block in existingBlocks) {
    if (block.type == 4 || block.type == 6) continue; // skip old
    newBlocks.add(block);
  }
  newBlocks.add(_FlacBlock(4, vorbisComment));
  if (pictureBlock != null) {
    newBlocks.add(_FlacBlock(6, pictureBlock));
  }

  for (int i = 0; i < newBlocks.length; i++) {
    final block = newBlocks[i];
    final isLast = i == newBlocks.length - 1;
    final headerByte = (isLast ? 0x80 : 0x00) | (block.type & 0x7F);
    result.addByte(headerByte);
    final len = block.data.length;
    result.add([(len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    result.add(block.data);
  }

  result.add(audioFrames);
  return result.takeBytes();
}

class _FlacBlock {
  final int type;
  final Uint8List data;
  const _FlacBlock(this.type, this.data);
}

/// Builds a Vorbis Comment block (without the FLAC metadata block header).
Uint8List _buildVorbisComment(AudioMetadata meta) {
  final comments = <String>[];
  if (meta.title != null) comments.add('TITLE=${meta.title}');
  if (meta.artist != null) comments.add('ARTIST=${meta.artist}');
  if (meta.album != null) comments.add('ALBUM=${meta.album}');
  if (meta.trackNumber != null) {
    comments.add('TRACKNUMBER=${meta.trackNumber}');
  }
  if (meta.discNumber != null) {
    comments.add('DISCNUMBER=${meta.discNumber}');
  }
  if (meta.year != null) comments.add('DATE=${meta.year}');
  if (meta.musicBrainzRecordingId != null) {
    comments.add('MUSICBRAINZ_TRACKID=${meta.musicBrainzRecordingId}');
  }
  if (meta.musicBrainzReleaseId != null) {
    comments.add('MUSICBRAINZ_ALBUMID=${meta.musicBrainzReleaseId}');
  }

  final vendor = utf8.encode('Tayra');
  final buf = BytesBuilder(copy: false);
  buf.add(_uint32LE(vendor.length));
  buf.add(vendor);
  buf.add(_uint32LE(comments.length));
  for (final c in comments) {
    final encoded = utf8.encode(c);
    buf.add(_uint32LE(encoded.length));
    buf.add(encoded);
  }
  return buf.takeBytes();
}

/// Builds a FLAC PICTURE metadata block body (type 6).
Uint8List _buildFlacPicture(Uint8List imageData, String mime) {
  final mimeBytes = ascii.encode(mime);
  final buf = BytesBuilder(copy: false);
  buf.add(_uint32BE(3)); // picture type: Cover (front)
  buf.add(_uint32BE(mimeBytes.length));
  buf.add(mimeBytes);
  buf.add(_uint32BE(0)); // description length
  buf.add(_uint32BE(0)); // width (unknown)
  buf.add(_uint32BE(0)); // height (unknown)
  buf.add(_uint32BE(0)); // colour depth
  buf.add(_uint32BE(0)); // indexed colours
  buf.add(_uint32BE(imageData.length));
  buf.add(imageData);
  return buf.takeBytes();
}

// ── OGG Vorbis ──────────────────────────────────────────────────────────

Uint8List? _tagOggVorbis(Uint8List original, AudioMetadata meta) {
  // OGG Vorbis structure:
  //   Page 0: Identification header packet (\x01vorbis)
  //   Page 1+: Comment header packet (\x03vorbis) + setup header
  //   Remaining: audio data pages
  return _tagOgg(original, meta, _OggCodec.vorbis);
}

Uint8List? _tagOggOpus(Uint8List original, AudioMetadata meta) {
  // OGG Opus structure:
  //   Page 0: OpusHead identification header
  //   Page 1: OpusTags comment header
  //   Remaining: audio data pages
  return _tagOgg(original, meta, _OggCodec.opus);
}

enum _OggCodec { vorbis, opus }

Uint8List? _tagOgg(Uint8List original, AudioMetadata meta, _OggCodec codec) {
  final pages = _parseOggPages(original);
  if (pages.isEmpty) return null;

  // Find the comment header page (page with granule position 0, after the
  // first identification page). For Vorbis it starts with \x03vorbis, for
  // Opus it starts with "OpusTags".
  int commentPageIndex = -1;
  for (int i = 1; i < pages.length; i++) {
    final payload = pages[i].payload;
    if (codec == _OggCodec.vorbis &&
        payload.length >= 7 &&
        payload[0] == 0x03 &&
        utf8.decode(payload.sublist(1, 7), allowMalformed: true) == 'vorbis') {
      commentPageIndex = i;
      break;
    }
    if (codec == _OggCodec.opus &&
        payload.length >= 8 &&
        utf8.decode(payload.sublist(0, 8), allowMalformed: true) ==
            'OpusTags') {
      commentPageIndex = i;
      break;
    }
  }

  if (commentPageIndex < 0) {
    developer.log('OGG: comment header not found', name: 'tayra.tagger');
    return null;
  }

  // Build new comment header packet.
  final commentData = _buildVorbisComment(meta);
  final newPayload = BytesBuilder(copy: false);
  if (codec == _OggCodec.vorbis) {
    newPayload.addByte(0x03); // packet type: comment
    newPayload.add(utf8.encode('vorbis'));
  } else {
    newPayload.add(utf8.encode('OpusTags'));
  }
  newPayload.add(commentData);

  // For Vorbis, the comment and setup headers may be on the same page
  // (or span multiple pages). We handle the common single-page case.
  // The comment page may contain both comment + setup packets.
  final oldPage = pages[commentPageIndex];

  // Check if this page contains multiple packets by examining segment
  // table — a 0-length segment in the lacing values signals a packet
  // boundary within the page.
  final oldPackets = _splitOggPagePackets(oldPage);

  // Replace the first packet (comment) and keep any remaining (setup).
  final newPackets = <Uint8List>[newPayload.takeBytes()];
  if (oldPackets.length > 1) {
    newPackets.addAll(oldPackets.sublist(1));
  }

  // Build the replacement page.
  final newPage = _buildOggPage(
    serial: oldPage.serial,
    pageSeqNo: oldPage.pageSeqNo,
    granulePosition: oldPage.granulePosition,
    headerType: oldPage.headerType,
    packets: newPackets,
    // Mark as not-last-packet if original had continuation.
    lastPacketComplete: oldPage.lastPacketComplete,
  );

  // Reassemble the full file: pages before comment + new comment page +
  // pages after comment.
  final result = BytesBuilder(copy: false);
  for (int i = 0; i < commentPageIndex; i++) {
    result.add(pages[i].rawBytes);
  }
  result.add(newPage);
  for (int i = commentPageIndex + 1; i < pages.length; i++) {
    result.add(pages[i].rawBytes);
  }

  return result.takeBytes();
}

// ── OGG page parser ─────────────────────────────────────────────────────

class _OggPage {
  final Uint8List rawBytes;
  final int headerType;
  final int granulePosition; // simplified to int (good enough for comment hdr)
  final int serial;
  final int pageSeqNo;
  final Uint8List payload;
  final List<int> segmentTable;
  final bool lastPacketComplete;

  const _OggPage({
    required this.rawBytes,
    required this.headerType,
    required this.granulePosition,
    required this.serial,
    required this.pageSeqNo,
    required this.payload,
    required this.segmentTable,
    required this.lastPacketComplete,
  });
}

List<_OggPage> _parseOggPages(Uint8List data) {
  final pages = <_OggPage>[];
  int offset = 0;

  while (offset + 27 <= data.length) {
    // Check OggS magic.
    if (data[offset] != 0x4F ||
        data[offset + 1] != 0x67 ||
        data[offset + 2] != 0x67 ||
        data[offset + 3] != 0x53) {
      break;
    }

    final headerType = data[offset + 5];
    // Granule position is 8 bytes LE at offset 6.
    final granule = _readUint64LE(data, offset + 6);
    final serial = _readUint32LE(data, offset + 14);
    final pageSeqNo = _readUint32LE(data, offset + 18);
    // CRC at offset 22 (4 bytes) — we'll recompute when writing.
    final numSegments = data[offset + 26];

    if (offset + 27 + numSegments > data.length) break;

    final segTable = data.sublist(offset + 27, offset + 27 + numSegments);
    int payloadLen = 0;
    for (final s in segTable) {
      payloadLen += s;
    }

    final headerLen = 27 + numSegments;
    if (offset + headerLen + payloadLen > data.length) break;

    final payload = Uint8List.sublistView(
      data,
      offset + headerLen,
      offset + headerLen + payloadLen,
    );
    final rawBytes = Uint8List.sublistView(
      data,
      offset,
      offset + headerLen + payloadLen,
    );

    // Last packet is complete if the last lacing value is not 255.
    final lastComplete = numSegments == 0 || segTable.last != 255;

    pages.add(
      _OggPage(
        rawBytes: rawBytes,
        headerType: headerType,
        granulePosition: granule,
        serial: serial,
        pageSeqNo: pageSeqNo,
        payload: payload,
        segmentTable: segTable.toList(),
        lastPacketComplete: lastComplete,
      ),
    );

    offset += headerLen + payloadLen;
  }

  return pages;
}

/// Splits an OGG page's payload into individual packets based on the
/// segment table. A packet boundary occurs after any segment < 255.
List<Uint8List> _splitOggPagePackets(_OggPage page) {
  final packets = <Uint8List>[];
  int payloadOffset = 0;
  int packetStart = 0;

  for (int i = 0; i < page.segmentTable.length; i++) {
    final segLen = page.segmentTable[i];
    payloadOffset += segLen;
    if (segLen < 255) {
      // End of packet.
      packets.add(
        Uint8List.sublistView(page.payload, packetStart, payloadOffset),
      );
      packetStart = payloadOffset;
    }
  }

  // If the last segment was 255, there's a continuation (incomplete packet).
  if (payloadOffset > packetStart) {
    packets.add(
      Uint8List.sublistView(page.payload, packetStart, payloadOffset),
    );
  }

  return packets;
}

/// Builds an OGG page from packets.
Uint8List _buildOggPage({
  required int serial,
  required int pageSeqNo,
  required int granulePosition,
  required int headerType,
  required List<Uint8List> packets,
  required bool lastPacketComplete,
}) {
  // Build segment table.
  final segTable = <int>[];
  for (int i = 0; i < packets.length; i++) {
    final pkt = packets[i];
    int remaining = pkt.length;
    while (remaining >= 255) {
      segTable.add(255);
      remaining -= 255;
    }
    // Write the final segment for this packet (< 255) only if this packet
    // is complete. The last packet may be a continuation.
    final isLastPacket = i == packets.length - 1;
    if (!isLastPacket || lastPacketComplete) {
      segTable.add(remaining);
    } else if (remaining > 0) {
      segTable.add(remaining);
    }
  }

  final headerLen = 27 + segTable.length;
  int payloadLen = 0;
  for (final p in packets) {
    payloadLen += p.length;
  }

  final page = Uint8List(headerLen + payloadLen);
  final bd = ByteData.sublistView(page);

  // OggS magic.
  page[0] = 0x4F;
  page[1] = 0x67;
  page[2] = 0x67;
  page[3] = 0x53;
  page[4] = 0; // version
  page[5] = headerType;
  // Granule position (8 bytes LE).
  _writeUint64LE(bd, 6, granulePosition);
  // Serial number.
  bd.setUint32(14, serial, Endian.little);
  // Page sequence number.
  bd.setUint32(18, pageSeqNo, Endian.little);
  // CRC placeholder (offset 22, filled after).
  bd.setUint32(22, 0, Endian.little);
  // Number of segments.
  page[26] = segTable.length;
  // Segment table.
  for (int i = 0; i < segTable.length; i++) {
    page[27 + i] = segTable[i];
  }
  // Payload.
  int off = headerLen;
  for (final pkt in packets) {
    page.setAll(off, pkt);
    off += pkt.length;
  }

  // Compute CRC32.
  final crc = _oggCrc32(page);
  bd.setUint32(22, crc, Endian.little);

  return page;
}

// ── OGG CRC-32 ──────────────────────────────────────────────────────────

/// OGG uses CRC-32 with polynomial 0x04C11DB7, init 0, no final XOR,
/// and direct (non-reflected) bit ordering.
int _oggCrc32(Uint8List data) {
  int crc = 0;
  for (final b in data) {
    crc = ((crc << 8) ^ _oggCrcTable[((crc >> 24) & 0xFF) ^ b]) & 0xFFFFFFFF;
  }
  return crc;
}

final List<int> _oggCrcTable = _buildOggCrcTable();

List<int> _buildOggCrcTable() {
  final table = List<int>.filled(256, 0);
  for (int i = 0; i < 256; i++) {
    int crc = i << 24;
    for (int j = 0; j < 8; j++) {
      if ((crc & 0x80000000) != 0) {
        crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
      } else {
        crc = (crc << 1) & 0xFFFFFFFF;
      }
    }
    table[i] = crc;
  }
  return table;
}

// ── Byte helpers ────────────────────────────────────────────────────────

Uint8List _uint32LE(int value) {
  final bd = ByteData(4)..setUint32(0, value, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _uint32BE(int value) {
  final bd = ByteData(4)..setUint32(0, value, Endian.big);
  return bd.buffer.asUint8List();
}

int _readUint32LE(Uint8List data, int offset) {
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

int _readUint64LE(Uint8List data, int offset) {
  // Dart int is 64-bit; we read as signed to handle granule -1.
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24) |
      (data[offset + 4] << 32) |
      (data[offset + 5] << 40) |
      (data[offset + 6] << 48) |
      (data[offset + 7] << 56);
}

void _writeUint64LE(ByteData bd, int offset, int value) {
  bd.setUint32(offset, value & 0xFFFFFFFF, Endian.little);
  bd.setUint32(offset + 4, (value >> 32) & 0xFFFFFFFF, Endian.little);
}
