import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/instance_settings/instance_settings_provider.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Instance settings (`/manage/settings`).
///
/// Lists and edits Funkwhale global preferences for users with
/// `me.permissions.settings` (or superuser). File and complex JSON prefs
/// are read-only with an admin escape-hatch note.
class InstanceSettingsScreen extends ConsumerStatefulWidget {
  const InstanceSettingsScreen({super.key});

  @override
  ConsumerState<InstanceSettingsScreen> createState() =>
      _InstanceSettingsScreenState();
}

class _InstanceSettingsScreenState
    extends ConsumerState<InstanceSettingsScreen> {
  /// Local working copy for optimistic updates after first load.
  List<GlobalPreference>? _prefs;

  /// Identifiers currently being saved (disable interaction).
  final Set<String> _saving = {};

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageSettingsProvider);
    final settingsAsync = ref.watch(adminSettingsProvider);

    // Sync provider data into local working copy when not dirty-saving.
    ref.listen<AsyncValue<List<GlobalPreference>>>(adminSettingsProvider, (
      _,
      next,
    ) {
      next.whenData((list) {
        if (_saving.isEmpty) {
          setState(() => _prefs = List<GlobalPreference>.from(list));
        }
      });
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Instance settings'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: canManage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _DeniedBody(
              message: 'Could not verify settings permissions.\n$error',
              onRetry: () => ref.invalidate(meUserProvider),
            ),
        data: (allowed) {
          if (!allowed) {
            return const _DeniedBody(
              message:
                  'You do not have permission to manage instance settings. '
                  'Ask an administrator to grant the settings permission.',
            );
          }
          return settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => _ErrorBody(
                  message: _friendlyError(error),
                  onRetry: () => ref.invalidate(adminSettingsProvider),
                ),
            data: (fromApi) {
              final prefs = _prefs ?? fromApi;
              return AppRefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminSettingsProvider);
                  await ref.read(adminSettingsProvider.future);
                },
                child: _PrefsList(
                  prefs: prefs,
                  saving: _saving,
                  onToggleBoolean: _toggleBoolean,
                  onEditString: _editString,
                  onEditInteger: _editInteger,
                  onEditChoice: _editChoice,
                  onEditMultiChoice: _editMultiChoice,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Mutations ─────────────────────────────────────────────────────────

  Future<void> _toggleBoolean(GlobalPreference pref, bool next) async {
    if (_saving.contains(pref.identifier)) return;
    final previous = pref.value;
    _applyLocal(pref.identifier, next);
    setState(() => _saving.add(pref.identifier));
    try {
      final updated = await ref
          .read(funkwhaleApiProvider)
          .bulkUpdateAdminSettings({pref.identifier: next});
      _mergeUpdated(updated);
    } catch (e) {
      _applyLocal(pref.identifier, previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(pref.identifier));
    }
  }

  Future<void> _editString(GlobalPreference pref) async {
    final controller = TextEditingController(text: pref.stringValue);
    final isLong =
        pref.helpText.toLowerCase().contains('markdown') ||
        pref.stringValue.length > 80 ||
        pref.name.contains('description') ||
        pref.name.contains('terms') ||
        pref.name.contains('rules') ||
        pref.name.contains('css') ||
        pref.name.contains('message');

    final saved = await showShellDialog<String?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              pref.displayName,
              style: const TextStyle(color: AppTheme.onBackground),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pref.helpText.isNotEmpty) ...[
                    Text(
                      pref.helpText,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: isLong ? 8 : 1,
                    minLines: isLong ? 3 : 1,
                    style: const TextStyle(color: AppTheme.onBackground),
                    decoration: InputDecoration(
                      labelText: pref.name,
                      labelStyle: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await _persist(pref, saved);
  }

  Future<void> _editInteger(GlobalPreference pref) async {
    final controller = TextEditingController(
      text: pref.intValue?.toString() ?? pref.stringValue,
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showShellDialog<int?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              pref.displayName,
              style: const TextStyle(color: AppTheme.onBackground),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pref.helpText.isNotEmpty) ...[
                    Text(
                      pref.helpText,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                    ],
                    style: const TextStyle(color: AppTheme.onBackground),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      labelStyle: TextStyle(color: AppTheme.onBackgroundMuted),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v.trim()) == null) {
                        return 'Enter a whole number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.of(ctx).pop(int.parse(controller.text.trim()));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await _persist(pref, saved);
  }

  Future<void> _editChoice(GlobalPreference pref) async {
    if (pref.choices.isEmpty) {
      // Fall back to free-text when choices missing.
      await _editString(pref);
      return;
    }
    final current = pref.value?.toString() ?? '';
    var selected = current;

    final saved = await showShellDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                pref.displayName,
                style: const TextStyle(color: AppTheme.onBackground),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pref.helpText.isNotEmpty) ...[
                        Text(
                          pref.helpText,
                          style: const TextStyle(
                            color: AppTheme.onBackgroundMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final c in pref.choices)
                        RadioListTile<String>(
                          value: c.value,
                          // ignore: deprecated_member_use
                          groupValue: selected,
                          activeColor: AppTheme.primary,
                          title: Text(
                            c.label,
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                              fontSize: 14,
                            ),
                          ),
                          subtitle:
                              c.label != c.value
                                  ? Text(
                                    c.value,
                                    style: const TextStyle(
                                      color: AppTheme.onBackgroundMuted,
                                      fontSize: 11,
                                    ),
                                  )
                                  : null,
                          // ignore: deprecated_member_use
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selected = v);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == null || !mounted) return;
    await _persist(pref, saved);
  }

  Future<void> _editMultiChoice(GlobalPreference pref) async {
    if (pref.choices.isEmpty) {
      await _editString(pref);
      return;
    }
    final selected = pref.multiValues.toSet();

    final saved = await showShellDialog<List<String>?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                pref.displayName,
                style: const TextStyle(color: AppTheme.onBackground),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pref.helpText.isNotEmpty) ...[
                        Text(
                          pref.helpText,
                          style: const TextStyle(
                            color: AppTheme.onBackgroundMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final c in pref.choices)
                        CheckboxListTile(
                          value: selected.contains(c.value),
                          activeColor: AppTheme.primary,
                          title: Text(
                            c.label,
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                              fontSize: 14,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selected.add(c.value);
                              } else {
                                selected.remove(c.value);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(ctx).pop(selected.toList()..sort()),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == null || !mounted) return;
    await _persist(pref, saved);
  }

  Future<void> _persist(GlobalPreference pref, dynamic nextValue) async {
    if (_saving.contains(pref.identifier)) return;
    final previous = pref.value;
    _applyLocal(pref.identifier, nextValue);
    setState(() => _saving.add(pref.identifier));
    try {
      final updated = await ref
          .read(funkwhaleApiProvider)
          .bulkUpdateAdminSettings({pref.identifier: nextValue});
      _mergeUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      _applyLocal(pref.identifier, previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(pref.identifier));
    }
  }

  List<GlobalPreference> _workingCopy() {
    if (_prefs != null) return _prefs!;
    final fromApi = ref
        .read(adminSettingsProvider)
        .maybeWhen(data: (d) => d, orElse: () => null);
    return fromApi != null
        ? List<GlobalPreference>.from(fromApi)
        : <GlobalPreference>[];
  }

  void _applyLocal(String identifier, dynamic value) {
    final list = _workingCopy();
    if (list.isEmpty) return;
    setState(() {
      _prefs =
          list
              .map(
                (p) =>
                    p.identifier == identifier
                        ? p.copyWith(value: value, clearValue: value == null)
                        : p,
              )
              .toList();
    });
  }

  void _mergeUpdated(List<GlobalPreference> updated) {
    if (updated.isEmpty) return;
    final list = _workingCopy();
    if (list.isEmpty) return;
    final byId = {for (final p in updated) p.identifier: p};
    setState(() {
      _prefs =
          list
              .map(
                (p) => byId.containsKey(p.identifier) ? byId[p.identifier]! : p,
              )
              .toList();
    });
  }
}

// ── Prefs list ──────────────────────────────────────────────────────────

class _PrefsList extends StatelessWidget {
  final List<GlobalPreference> prefs;
  final Set<String> saving;
  final Future<void> Function(GlobalPreference pref, bool next) onToggleBoolean;
  final Future<void> Function(GlobalPreference pref) onEditString;
  final Future<void> Function(GlobalPreference pref) onEditInteger;
  final Future<void> Function(GlobalPreference pref) onEditChoice;
  final Future<void> Function(GlobalPreference pref) onEditMultiChoice;

  const _PrefsList({
    required this.prefs,
    required this.saving,
    required this.onToggleBoolean,
    required this.onEditString,
    required this.onEditInteger,
    required this.onEditChoice,
    required this.onEditMultiChoice,
  });

  @override
  Widget build(BuildContext context) {
    if (prefs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'No preferences found',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
          ),
        ],
      );
    }

    // Group by section, preserve section order of first appearance.
    final sections = <String, List<GlobalPreference>>{};
    for (final p in prefs) {
      final key = p.section.isEmpty ? 'general' : p.section;
      (sections[key] ??= []).add(p);
    }

    final children = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(
          'Global Funkwhale preferences. Changes apply to this pod immediately. '
          'File uploads and some advanced values remain server-side '
          '(Django admin / env vars).',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
        ),
      ),
    ];

    for (final entry in sections.entries) {
      children.add(SettingsSectionHeader(title: _sectionTitle(entry.key)));
      for (final pref in entry.value) {
        children.add(
          _PrefTile(
            pref: pref,
            busy: saving.contains(pref.identifier),
            onToggleBoolean: onToggleBoolean,
            onEditString: onEditString,
            onEditInteger: onEditInteger,
            onEditChoice: onEditChoice,
            onEditMultiChoice: onEditMultiChoice,
          ),
        );
      }
    }
    children.add(const SizedBox(height: 32));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: children,
    );
  }

  static String _sectionTitle(String section) {
    if (section.isEmpty) return 'General';
    // "instance" → "Instance", "ui" → "UI"
    if (section.length <= 2) return section.toUpperCase();
    return section[0].toUpperCase() + section.substring(1);
  }
}

// ── Single preference tile ──────────────────────────────────────────────

class _PrefTile extends StatelessWidget {
  final GlobalPreference pref;
  final bool busy;
  final Future<void> Function(GlobalPreference pref, bool next) onToggleBoolean;
  final Future<void> Function(GlobalPreference pref) onEditString;
  final Future<void> Function(GlobalPreference pref) onEditInteger;
  final Future<void> Function(GlobalPreference pref) onEditChoice;
  final Future<void> Function(GlobalPreference pref) onEditMultiChoice;

  const _PrefTile({
    required this.pref,
    required this.busy,
    required this.onToggleBoolean,
    required this.onEditString,
    required this.onEditInteger,
    required this.onEditChoice,
    required this.onEditMultiChoice,
  });

  @override
  Widget build(BuildContext context) {
    switch (pref.fieldKind) {
      case GlobalPreferenceFieldKind.boolean:
        return SettingsSwitchTile(
          icon: Icons.toggle_on_outlined,
          title: pref.displayName,
          subtitle: _subtitle(),
          value: pref.boolValue,
          onChanged: busy ? (_) {} : (v) => onToggleBoolean(pref, v),
        );
      case GlobalPreferenceFieldKind.string:
        return SettingsActionTile(
          icon: Icons.short_text_rounded,
          title: pref.displayName,
          subtitle: _valuePreview(pref.stringValue),
          onTap: busy ? () {} : () => onEditString(pref),
        );
      case GlobalPreferenceFieldKind.integer:
        return SettingsActionTile(
          icon: Icons.numbers_rounded,
          title: pref.displayName,
          subtitle: _valuePreview(pref.stringValue),
          onTap: busy ? () {} : () => onEditInteger(pref),
        );
      case GlobalPreferenceFieldKind.choice:
        final label =
            pref.value == null
                ? 'Not set'
                : pref.labelForChoice(pref.value.toString());
        return SettingsActionTile(
          icon: Icons.list_rounded,
          title: pref.displayName,
          subtitle: _valuePreview(label),
          onTap: busy ? () {} : () => onEditChoice(pref),
        );
      case GlobalPreferenceFieldKind.multiChoice:
        final labels =
            pref.multiValues.map(pref.labelForChoice).toList()..sort();
        final preview = labels.isEmpty ? 'None selected' : labels.join(', ');
        return SettingsActionTile(
          icon: Icons.checklist_rounded,
          title: pref.displayName,
          subtitle: _valuePreview(preview),
          onTap: busy ? () {} : () => onEditMultiChoice(pref),
        );
      case GlobalPreferenceFieldKind.file:
        final url = pref.value?.toString();
        return SettingsInfoTile(
          icon: Icons.image_outlined,
          title: pref.displayName,
          subtitle: _fileSubtitle(url),
        );
      case GlobalPreferenceFieldKind.complex:
        return SettingsInfoTile(
          icon: Icons.data_object_rounded,
          title: pref.displayName,
          subtitle: _complexSubtitle(),
        );
    }
  }

  String _subtitle() {
    if (pref.helpText.isNotEmpty) return pref.helpText;
    return pref.identifier;
  }

  String _valuePreview(String raw) {
    final help = pref.helpText;
    final valuePart = raw.trim().isEmpty ? '(empty)' : raw.trim();
    if (help.isEmpty) return valuePart;
    // Prefer help text when value is empty; otherwise show value first.
    if (raw.trim().isEmpty) return help;
    return valuePart;
  }

  String _fileSubtitle(String? url) {
    final hasFile = url != null && url.isNotEmpty;
    final status = hasFile ? 'Set — $url' : 'Not set';
    return '$status\n'
        'File preferences cannot be uploaded here. Use Django admin '
        'or the preferences API with multipart.';
  }

  String _complexSubtitle() {
    final preview = pref.stringValue;
    final shown =
        preview.isEmpty
            ? '(empty)'
            : (preview.length > 80 ? '${preview.substring(0, 80)}…' : preview);
    return '$shown\n'
        'Complex values are read-only in Tayra. Edit via Django admin '
        'or POST /api/v1/instance/admin/settings/bulk/.';
  }
}

// ── Denied / error bodies ───────────────────────────────────────────────

class _DeniedBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _DeniedBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.error.withValues(alpha: 0.85),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Access denied',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry'))
            else
              FilledButton(
                onPressed:
                    () => popPage(context, fallbackLocation: '/settings'),
                child: const Text('Back to settings'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load settings',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      // Bulk validation errors: { "instance__name": { "value": ["…"] } }
      final parts = <String>[];
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is Map && v['value'] is List) {
          parts.add('${entry.key}: ${(v['value'] as List).join(', ')}');
        } else if (v is List) {
          parts.add('${entry.key}: ${v.join(', ')}');
        } else if (v is String) {
          parts.add('${entry.key}: $v');
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
      if (data['detail'] != null) return data['detail'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    if (error.response?.statusCode == 403) {
      return 'Permission denied (need settings permission / instance:settings scope).';
    }
    if (error.response?.statusCode == 401) {
      return 'Not authenticated. Sign in again.';
    }
    return error.message ?? error.toString();
  }
  return error.toString();
}
