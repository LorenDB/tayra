import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/features/upload/upload_provider.dart';

// ── Upload Screen ────────────────────────────────────────────────────────

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final isDone =
        state.uploadStatus == UploadStatus.finished ||
        state.uploadStatus == UploadStatus.errored;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Upload Music'),
        backgroundColor: AppTheme.background,
        actions: [
          if (isDone)
            TextButton(
              onPressed: () => ref.read(uploadProvider.notifier).reset(),
              child: const Text('Upload Another'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DisclaimerBanner(),
            const SizedBox(height: 16),
            _FileCard(),
            const SizedBox(height: 12),
            _LibraryCard(),
            const SizedBox(height: 12),
            _MusicBrainzCard(),
            const SizedBox(height: 20),
            _UploadSection(),
          ],
        ),
      ),
    );
  }
}

// ── Disclaimer banner ────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.onBackgroundSubtle.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.onBackgroundSubtle,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This uploader is designed for single tracks. For bulk imports, '
              'use the Funkwhale web interface together with a tool like '
              'MusicBrainz Picard to tag your files first.',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── File selection card ──────────────────────────────────────────────────

class _FileCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final isLocked = _isLocked(state);

    return _SectionCard(
      child: Row(
        children: [
          // Icon + label column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.audio_file_outlined,
                  title: 'Audio File',
                ),
                const SizedBox(height: 8),
                if (state.hasFile) ...[
                  Text(
                    state.fileName!,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.fileSize != null)
                    Text(
                      _formatFileSize(state.fileSize!),
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
                    ),
                ] else
                  const Text(
                    'No file selected',
                    style: TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed:
                isLocked
                    ? null
                    : () => ref.read(uploadProvider.notifier).pickFile(),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(state.hasFile ? 'Change' : 'Select'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceContainerHigh,
              foregroundColor: AppTheme.onBackground,
              disabledBackgroundColor: AppTheme.surfaceContainer,
              disabledForegroundColor: AppTheme.onBackgroundSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

// ── Library card ─────────────────────────────────────────────────────────

class _LibraryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final notifier = ref.read(uploadProvider.notifier);
    final isLocked = _isLocked(state);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _CardTitle(
                  icon: Icons.library_music_outlined,
                  title: 'Library',
                ),
              ),
              if (!isLocked)
                TextButton.icon(
                  onPressed: () => _showCreateLibraryDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.loadingLibraries)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else if (state.libraryError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.libraryError!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: notifier.loadLibraries,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (state.libraries.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No libraries yet.',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateLibraryDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          else
            ...state.libraries.map(
              (lib) => _LibraryTile(
                library: lib,
                isSelected: state.selectedLibraryUuid == lib.uuid,
                onTap: isLocked ? null : () => notifier.selectLibrary(lib.uuid),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateLibraryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showShellDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _CreateLibraryDialog(),
    );
    if (result != null) {
      await ref
          .read(uploadProvider.notifier)
          .createLibrary(
            name: result['name']!,
            privacyLevel: result['privacy_level']!,
          );
    }
  }
}

class _LibraryTile extends StatelessWidget {
  final Library library;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LibraryTile({
    required this.library,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    isSelected ? AppTheme.primary : AppTheme.onBackgroundSubtle,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: TextStyle(
                        color:
                            isSelected
                                ? AppTheme.onBackground
                                : AppTheme.onBackgroundMuted,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${library.uploadsCount} tracks · ${library.privacyLevelLabel}',
                      style: const TextStyle(
                        color: AppTheme.onBackgroundSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── MusicBrainz card ─────────────────────────────────────────────────────

class _MusicBrainzCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final notifier = ref.read(uploadProvider.notifier);
    final isLocked = _isLocked(state);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _CardTitle(
                  icon: Icons.tag_rounded,
                  title: 'MusicBrainz Metadata',
                ),
              ),
              Switch(
                value: state.useMusicBrainz,
                onChanged:
                    isLocked ? null : (v) => notifier.setUseMusicBrainz(v),
                activeThumbColor: AppTheme.primary,
                activeTrackColor: AppTheme.primary.withAlpha(100),
              ),
            ],
          ),
          if (!state.useMusicBrainz)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Look up and embed track metadata before uploading.',
                style: TextStyle(
                  color: AppTheme.onBackgroundSubtle,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    isLocked ? null : () => _showMbSearchSheet(context, ref),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  state.mbRecordingId.isEmpty
                      ? 'Search MusicBrainz'
                      : 'Change Recording',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (state.mbRecordingId.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MbRecordingSummary(state: state),
            ],
            if (state.coverArtStatus != CoverArtStatus.none) ...[
              const SizedBox(height: 12),
              _CoverArtSection(isLocked: isLocked),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showMbSearchSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MbSearchSheet(parentRef: ref),
    );
  }
}

// ── MusicBrainz search sheet ─────────────────────────────────────────────

class _MbSearchSheet extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _MbSearchSheet({required this.parentRef});

  @override
  ConsumerState<_MbSearchSheet> createState() => _MbSearchSheetState();
}

class _MbSearchSheetState extends ConsumerState<_MbSearchSheet> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);
    final notifier = ref.read(uploadProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onBackgroundSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search MusicBrainz',
                    style: TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Track title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: AppTheme.onBackground),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _artistController,
                    decoration: const InputDecoration(
                      labelText: 'Artist (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(color: AppTheme.onBackground),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(notifier),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          state.mbSearching ? null : () => _search(notifier),
                      icon:
                          state.mbSearching
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.onBackground,
                                ),
                              )
                              : const Icon(Icons.search_rounded),
                      label: Text(state.mbSearching ? 'Searching…' : 'Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppTheme.surfaceContainerHigh),
            Expanded(child: _buildResults(context, state, scrollController)),
          ],
        );
      },
    );
  }

  Widget _buildResults(
    BuildContext context,
    UploadState state,
    ScrollController scrollController,
  ) {
    if (state.mbSearchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.mbSearchError!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.mbResults.isEmpty && !state.mbSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Enter a title above and tap Search to find recordings.',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: state.mbResults.length,
      itemBuilder: (context, index) {
        final rec = state.mbResults[index];
        return ListTile(
          title: Text(
            rec.title,
            style: const TextStyle(color: AppTheme.onBackground),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rec.artistName != null)
                Text(
                  rec.artistName!,
                  style: const TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              if (rec.albumTitle != null)
                Text(
                  rec.albumTitle!,
                  style: const TextStyle(color: AppTheme.onBackgroundSubtle),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (rec.durationLabel.isNotEmpty)
                Text(
                  rec.durationLabel,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundSubtle,
                    fontSize: 12,
                  ),
                ),
              if (rec.releaseDate != null)
                Text(
                  rec.releaseDate!.substring(
                    0,
                    rec.releaseDate!.length.clamp(0, 4),
                  ),
                  style: const TextStyle(
                    color: AppTheme.onBackgroundSubtle,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          onTap: () {
            ref.read(uploadProvider.notifier).selectMbRecording(rec);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _search(UploadNotifier notifier) {
    notifier.searchMusicBrainz(_titleController.text, _artistController.text);
  }
}

// ── MusicBrainz recording summary ────────────────────────────────────────

class _MbRecordingSummary extends StatelessWidget {
  final UploadState state;
  const _MbRecordingSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final rec = state.selectedMbRecording;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                rec != null
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.title,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (rec.artistName != null)
                          Text(
                            rec.artistName!,
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 12,
                            ),
                          ),
                        if (rec.albumTitle != null)
                          Text(
                            [
                              rec.albumTitle!,
                              if (rec.year != null) '(${rec.year})',
                              if (rec.discNumber != null && rec.discNumber! > 1)
                                'Disc ${rec.discNumber}',
                              if (rec.trackNumber != null)
                                'Track ${rec.trackNumber}',
                              if (rec.durationLabel.isNotEmpty)
                                rec.durationLabel,
                            ].join(' \u00b7 '),
                            style: const TextStyle(
                              color: AppTheme.onBackgroundSubtle,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    )
                    : Text(
                      state.mbRecordingId,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ── Cover art section ────────────────────────────────────────────────────

class _CoverArtSection extends ConsumerWidget {
  final bool isLocked;
  const _CoverArtSection({required this.isLocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppTheme.surfaceContainerHigh, height: 1),
        const SizedBox(height: 10),
        if (state.coverArtStatus == CoverArtStatus.loading)
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Fetching cover art…',
                style: TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                ),
              ),
            ],
          )
        else if (state.coverArtStatus == CoverArtStatus.error)
          const Text(
            'No cover art found for this release.',
            style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 12),
          )
        else if (state.coverArtStatus == CoverArtStatus.loaded &&
            state.coverArtBytes != null)
          _CoverArtPreview(
            imageBytes: state.coverArtBytes!,
            embed: state.embedCoverArt,
            isLocked: isLocked,
          ),
      ],
    );
  }
}

class _CoverArtPreview extends ConsumerWidget {
  final Uint8List imageBytes;
  final bool embed;
  final bool isLocked;

  const _CoverArtPreview({
    required this.imageBytes,
    required this.embed,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            imageBytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  width: 56,
                  height: 56,
                  color: AppTheme.surfaceContainerHigh,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.onBackgroundSubtle,
                  ),
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cover art · ${(imageBytes.length / 1024).toStringAsFixed(0)} KB',
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap:
                    isLocked
                        ? null
                        : () => ref
                            .read(uploadProvider.notifier)
                            .setEmbedCoverArt(!embed),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: embed,
                        onChanged:
                            isLocked
                                ? null
                                : (v) => ref
                                    .read(uploadProvider.notifier)
                                    .setEmbedCoverArt(v ?? true),
                        activeColor: AppTheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Embed in file',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Upload section (button + status) ────────────────────────────────────

class _UploadSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);

    final isDone =
        state.uploadStatus == UploadStatus.finished ||
        state.uploadStatus == UploadStatus.errored;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error banner
        if (state.uploadError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.error.withAlpha(80)),
            ),
            child: Text(
              state.uploadError!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],

        // Status card (finished / errored / in-progress)
        if (state.uploadStatus != UploadStatus.idle) ...[
          _StatusCard(state: state),
          const SizedBox(height: 12),
        ],

        // Upload button — hidden after success/error (use appbar action instead)
        if (!isDone) _UploadButton(state: state, ref: ref),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final UploadState state;
  final WidgetRef ref;

  const _UploadButton({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isUploading = state.uploadStatus == UploadStatus.uploading;
    final isPolling = state.uploadStatus == UploadStatus.pollingImport;
    final isEmbedding = state.uploadStatus == UploadStatus.embedding;
    final isBusy = isUploading || isPolling || isEmbedding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isUploading) ...[
          LinearProgressIndicator(
            value: state.uploadProgress,
            backgroundColor: AppTheme.surfaceContainerHigh,
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            '${(state.uploadProgress * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed:
              state.canUpload
                  ? () => ref.read(uploadProvider.notifier).upload()
                  : null,
          icon:
              isBusy
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.cloud_upload_rounded),
          label: Text(
            isPolling
                ? 'Processing…'
                : isUploading
                ? 'Uploading…'
                : isEmbedding
                ? 'Embedding tags…'
                : 'Upload',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.surfaceContainerHigh,
            disabledForegroundColor: AppTheme.onBackgroundSubtle,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Status card ──────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final UploadState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, body) = switch (state.uploadStatus) {
      UploadStatus.finished => (
        AppTheme.secondary,
        Icons.check_circle_outline_rounded,
        'Import Complete',
        'Your track has been successfully imported into your library.',
      ),
      UploadStatus.errored => (
        AppTheme.error,
        Icons.error_outline_rounded,
        'Import Failed',
        state.importErrorDetail ?? 'The server could not process this file.',
      ),
      UploadStatus.pollingImport => (
        AppTheme.primary,
        Icons.sync_rounded,
        'Processing',
        'Waiting for the server to import the track '
            '(status: ${state.importStatus ?? 'pending'})…',
      ),
      UploadStatus.embedding => (
        AppTheme.primary,
        Icons.label_rounded,
        'Embedding Metadata',
        'Writing MusicBrainz tags into the audio file…',
      ),
      UploadStatus.uploading => (
        AppTheme.primary,
        Icons.upload_rounded,
        'Uploading',
        'Transfer in progress…',
      ),
      _ => (AppTheme.primary, Icons.upload_rounded, 'Working', 'Please wait…'),
    };

    final showSpinner =
        state.uploadStatus == UploadStatus.pollingImport ||
        state.uploadStatus == UploadStatus.embedding ||
        state.uploadStatus == UploadStatus.uploading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          showSpinner
              ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
              : Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create library dialog ─────────────────────────────────────────────────

class _CreateLibraryDialog extends StatefulWidget {
  const _CreateLibraryDialog();

  @override
  State<_CreateLibraryDialog> createState() => _CreateLibraryDialogState();
}

class _CreateLibraryDialogState extends State<_CreateLibraryDialog> {
  final _nameController = TextEditingController();
  String _privacyLevel = 'me';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Create Library',
        style: TextStyle(color: AppTheme.onBackground),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Library name',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: AppTheme.onBackground),
          ),
          const SizedBox(height: 16),
          const Text(
            'Visibility',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _PrivacyRadio(
            value: 'me',
            label: 'Private',
            subtitle: 'Only you',
            groupValue: _privacyLevel,
            onChanged: (v) => setState(() => _privacyLevel = v!),
          ),
          _PrivacyRadio(
            value: 'instance',
            label: 'Instance',
            subtitle: 'Everyone on your server',
            groupValue: _privacyLevel,
            onChanged: (v) => setState(() => _privacyLevel = v!),
          ),
          _PrivacyRadio(
            value: 'everyone',
            label: 'Public',
            subtitle: 'Everyone, including other instances',
            groupValue: _privacyLevel,
            onChanged: (v) => setState(() => _privacyLevel = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              () => Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'privacy_level': _privacyLevel,
              }),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PrivacyRadio extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _PrivacyRadio({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  isSelected ? AppTheme.primary : AppTheme.onBackgroundSubtle,
              size: 20,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared section widgets ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.onBackgroundSubtle, size: 18),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

bool _isLocked(UploadState state) =>
    state.uploadStatus == UploadStatus.uploading ||
    state.uploadStatus == UploadStatus.pollingImport ||
    state.uploadStatus == UploadStatus.embedding;
