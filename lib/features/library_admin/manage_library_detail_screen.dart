import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/library_admin/library_admin_provider.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Providers ───────────────────────────────────────────────────────────

final manageLibraryDetailProvider = FutureProvider.autoDispose
    .family<ManageLibrary, String>((ref, uuid) async {
      return ref.watch(funkwhaleApiProvider).getManageLibrary(uuid);
    });

final manageLibraryStatsProvider = FutureProvider.autoDispose
    .family<ManageLibraryStats, String>((ref, uuid) async {
      return ref.watch(funkwhaleApiProvider).getManageLibraryStats(uuid);
    });

// ── Screen ──────────────────────────────────────────────────────────────

class ManageLibraryDetailScreen extends ConsumerStatefulWidget {
  final String uuid;

  const ManageLibraryDetailScreen({super.key, required this.uuid});

  @override
  ConsumerState<ManageLibraryDetailScreen> createState() =>
      _ManageLibraryDetailScreenState();
}

class _ManageLibraryDetailScreenState
    extends ConsumerState<ManageLibraryDetailScreen> {
  bool _saving = false;
  bool _deleting = false;

  Future<void> _edit(ManageLibrary library) async {
    final nameCtrl = TextEditingController(text: library.name);
    final descCtrl = TextEditingController(text: library.description ?? '');
    var privacy = library.privacyLevel;
    if (!const ['me', 'instance', 'everyone'].contains(privacy)) {
      privacy = 'me';
    }

    final saved = await showShellDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit library',
                style: TextStyle(color: AppTheme.onBackground),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppTheme.onBackground),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // Controlled by dialog state; `value` is still the right API.
                      // ignore: deprecated_member_use
                      value: privacy,
                      dropdownColor: AppTheme.surfaceContainerHigh,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Privacy',
                        labelStyle: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'me', child: Text('Private')),
                        DropdownMenuItem(
                          value: 'instance',
                          child: Text('Instance'),
                        ),
                        DropdownMenuItem(
                          value: 'everyone',
                          child: Text('Public'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => privacy = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(funkwhaleApiProvider)
          .updateManageLibrary(
            widget.uuid,
            name: nameCtrl.text.trim(),
            description: descCtrl.text,
            privacyLevel: privacy,
          );
      ref.invalidate(manageLibraryDetailProvider(widget.uuid));
      ref.invalidate(manageLibraryStatsProvider(widget.uuid));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Library updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(ManageLibrary library) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete library?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Text(
              'This permanently deletes “${library.name}” and its uploads. '
              'This cannot be undone.',
              style: const TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(funkwhaleApiProvider).deleteManageLibrary(widget.uuid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Library deleted')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/manage/library/libraries');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageLibraryProvider);
    final detailAsync = ref.watch(manageLibraryDetailProvider(widget.uuid));
    final statsAsync = ref.watch(manageLibraryStatsProvider(widget.uuid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          detailAsync.maybeWhen(
            data: (l) => l.name.isEmpty ? 'Library' : l.name,
            orElse: () => 'Library',
          ),
        ),
        backgroundColor: AppTheme.background,
        actions: [
          if (detailAsync.hasValue) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed:
                  _saving || _deleting
                      ? null
                      : () => _edit(detailAsync.requireValue),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed:
                  _saving || _deleting
                      ? null
                      : () => _confirmDelete(detailAsync.requireValue),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
      body: canManage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => LibraryAdminDeniedBody(
              message: 'Could not verify library permissions.\n$error',
              onRetry: () => ref.invalidate(meUserProvider),
            ),
        data: (allowed) {
          if (!allowed) {
            return const LibraryAdminDeniedBody(
              message:
                  'You do not have permission to manage instance libraries.',
            );
          }
          return detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => InlineErrorState(
                  message: _friendlyError(error),
                  onRetry:
                      () => ref.invalidate(
                        manageLibraryDetailProvider(widget.uuid),
                      ),
                ),
            data: (library) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_saving || _deleting)
                    const LinearProgressIndicator(minHeight: 2),
                  SettingsSectionHeader(title: 'Details'),
                  SettingsInfoTile(
                    icon: Icons.library_music_rounded,
                    title: 'Name',
                    subtitle: library.name.isEmpty ? '—' : library.name,
                  ),
                  SettingsInfoTile(
                    icon: Icons.notes_rounded,
                    title: 'Description',
                    subtitle:
                        (library.description == null ||
                                library.description!.trim().isEmpty)
                            ? '—'
                            : library.description!,
                  ),
                  SettingsInfoTile(
                    icon: Icons.visibility_outlined,
                    title: 'Privacy',
                    subtitle: library.privacyLevelLabel,
                  ),
                  SettingsInfoTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Owner',
                    subtitle: library.actor?.displayLabel ?? '—',
                  ),
                  SettingsInfoTile(
                    icon: Icons.public_rounded,
                    title: 'Domain',
                    subtitle: library.domain ?? '—',
                  ),
                  SettingsInfoTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'UUID',
                    subtitle: library.uuid,
                  ),
                  const SizedBox(height: 8),
                  SettingsSectionHeader(title: 'Stats'),
                  statsAsync.when(
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Stats unavailable: ${_friendlyError(error)}',
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    data: (stats) {
                      return Column(
                        children: [
                          SettingsInfoTile(
                            icon: Icons.cloud_upload_outlined,
                            title: 'Uploads',
                            subtitle: '${stats.uploads}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.music_note_outlined,
                            title: 'Tracks',
                            subtitle: '${stats.tracks}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.album_outlined,
                            title: 'Albums',
                            subtitle: '${stats.albums}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.person_outline,
                            title: 'Artists',
                            subtitle: '${stats.artists}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.people_outline,
                            title: 'Followers',
                            subtitle: '${stats.followers}',
                          ),
                          if (stats.mediaTotalSize != null)
                            SettingsInfoTile(
                              icon: Icons.storage_outlined,
                              title: 'Media size',
                              subtitle: _formatBytes(stats.mediaTotalSize!),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed:
                          _saving || _deleting
                              ? null
                              : () => _confirmDelete(library),
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.5),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      label: const Text('Delete library'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) return 'Permission denied (403)';
    if (code == 404) return 'Library not found';
    return error.message ?? error.toString();
  }
  return error.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
