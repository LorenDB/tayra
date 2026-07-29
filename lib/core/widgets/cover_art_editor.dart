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

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final api = ref.read(cachedFunkwhaleApiProvider);
      final cover = await api.createAttachment(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      widget.onChanged(CoverArtSelection(uploaded: cover));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload cover art')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                    'PNG or JPEG, at least 50×50 px.',
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
