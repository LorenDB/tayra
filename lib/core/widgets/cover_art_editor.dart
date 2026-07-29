import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';

/// Result of a cover art edit session before the parent persists metadata.
class CoverArtSelection {
  /// Newly uploaded attachment, when the user picked a replacement image.
  final Cover? uploaded;

  /// True when the user explicitly cleared custom art (send `cover: null`).
  final bool cleared;

  const CoverArtSelection({this.uploaded, this.cleared = false});

  bool get hasChange => uploaded != null || cleared;
}

/// Human-readable message for cover upload failures (API validation, network).
String describeCoverUploadError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? detail;
    if (data is Map) {
      // DRF shapes: {"file": ["…"]}, {"detail": "…"}, {"file": [{"detail":…}]}
      final fileErr = data['file'];
      if (fileErr is List && fileErr.isNotEmpty) {
        final first = fileErr.first;
        if (first is String) {
          detail = first;
        } else if (first is Map && first['detail'] != null) {
          detail = first['detail'].toString();
        } else {
          detail = first.toString();
        }
      } else if (data['detail'] != null) {
        detail = data['detail'].toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      detail = data.trim();
    }
    if (detail != null && detail.isNotEmpty) {
      return status != null ? 'Upload failed ($status): $detail' : detail;
    }
    if (status == 401 || status == 403) {
      return 'Upload failed: not authorized to upload images.';
    }
    if (status == 413) {
      return 'Upload failed: image is too large (max 5 MB).';
    }
    if (status != null) {
      return 'Upload failed (HTTP $status).';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Upload failed: could not reach the server.';
    }
  }
  return 'Failed to upload cover art';
}

/// Tap-to-change cover art tile used on playlist/radio edit screens.
///
/// Shows [currentCover] when set, otherwise [fallbackUrl] (e.g. first album
/// mosaic tile). Tapping opens the system image picker, uploads via
/// `/api/v1/attachments/`, and reports the new [Cover] through [onChanged].
class CoverArtEditor extends ConsumerStatefulWidget {
  final Cover? currentCover;
  final String? fallbackUrl;
  final double size;
  final IconData placeholderIcon;
  final ValueChanged<CoverArtSelection> onChanged;
  final CoverArtSelection? selection;

  const CoverArtEditor({
    super.key,
    this.currentCover,
    this.fallbackUrl,
    this.size = 96,
    this.placeholderIcon = Icons.image_rounded,
    required this.onChanged,
    this.selection,
  });

  @override
  ConsumerState<CoverArtEditor> createState() => _CoverArtEditorState();
}

class _CoverArtEditorState extends ConsumerState<CoverArtEditor> {
  bool _isUploading = false;

  String? get _displayUrl {
    final selection = widget.selection;
    if (selection?.uploaded != null) {
      return selection!.uploaded!.urls.best;
    }
    if (selection?.cleared == true) {
      return widget.fallbackUrl;
    }
    return widget.currentCover?.urls.best ?? widget.fallbackUrl;
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;

    // Prefer [pickFiles] over [pickFile]: the single-file helper forces
    // `withData: false`, which leaves web without in-memory bytes and makes
    // [PlatformFile.readAsBytes] throw (no fetchable blob path).
    // ignore: deprecated_member_use — required for web; pickFile omits bytes.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      // ignore: deprecated_member_use
      allowMultiple: false,
      // ignore: deprecated_member_use — withData must be true on web.
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await _readPlatformFileBytes(file);
      if (bytes.isEmpty) {
        throw StateError('Selected file is empty');
      }
      final api = ref.read(cachedFunkwhaleApiProvider);
      final cover = await api.createAttachment(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      widget.onChanged(CoverArtSelection(uploaded: cover));
    } catch (e, st) {
      debugPrint('Cover upload failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeCoverUploadError(e))));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Load bytes for a picked image on every platform (including web).
  Future<List<int>> _readPlatformFileBytes(PlatformFile file) async {
    // ignore: deprecated_member_use — still populated when withData: true
    final embedded = file.bytes;
    if (embedded != null && embedded.isNotEmpty) {
      return embedded;
    }
    try {
      return await file.readAsBytes();
    } catch (_) {
      // Web / some desktop backends: stream the blob when eager bytes
      // were not attached to the [PlatformFile].
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
  }

  void _clear() {
    widget.onChanged(const CoverArtSelection(cleared: true));
  }

  bool get _canClear {
    final selection = widget.selection;
    if (selection?.uploaded != null) return true;
    if (selection?.cleared == true) return false;
    return widget.currentCover != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover art',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: _isUploading ? null : _pickAndUpload,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CoverArtWidget(
                    imageUrl: _displayUrl,
                    size: widget.size,
                    borderRadius: 10,
                    placeholderIcon: widget.placeholderIcon,
                  ),
                  if (_isUploading)
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh.withValues(
                            alpha: 0.9,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: AppTheme.onBackground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _isUploading ? null : _pickAndUpload,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      widget.currentCover != null ||
                              widget.selection?.uploaded != null
                          ? 'Change image'
                          : 'Upload image',
                    ),
                  ),
                  if (_canClear)
                    TextButton.icon(
                      onPressed: _isUploading ? null : _clear,
                      icon: const Icon(
                        Icons.hide_image_outlined,
                        size: 18,
                        color: AppTheme.onBackgroundMuted,
                      ),
                      label: const Text(
                        'Remove custom art',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'PNG, JPEG, or WebP · at least 50×50 px · max 5 MB',
                    style: TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
