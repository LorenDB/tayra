import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';

/// Show owner UI to create, copy, and revoke share links for an album/playlist.
Future<void> showShareLinkSheet(
  BuildContext context, {
  required String objectType,
  required int objectId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder:
        (context) => _ShareLinkSheet(
          objectType: objectType,
          objectId: objectId,
          title: title,
        ),
  );
}

class _ShareLinkSheet extends ConsumerStatefulWidget {
  final String objectType;
  final int objectId;
  final String title;

  const _ShareLinkSheet({
    required this.objectType,
    required this.objectId,
    required this.title,
  });

  @override
  ConsumerState<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<_ShareLinkSheet> {
  List<ShareLink> _links = [];
  bool _loading = true;
  bool _creating = false;
  int? _expiresInDays; // null = never

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(funkwhaleApiProvider)
          .getShareLinks(
            objectType: widget.objectType,
            objectId: widget.objectId,
          );
      if (!mounted) return;
      setState(() {
        _links = res.results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load share links: $e')));
    }
  }

  String _visitorUrl(ShareLink link) {
    // Prefer SPA-facing URL on web (same origin); fall back to API-reported URL.
    if (AppPlatform.isWeb) {
      final origin = Uri.base.origin;
      return '$origin/share/${link.token}';
    }
    if (link.url.isNotEmpty) return link.url;
    final base = AppPlatform.hardcodedPodUrl;
    if (base != null) return '$base/share/${link.token}';
    return '/share/${link.token}';
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final created = await ref
          .read(funkwhaleApiProvider)
          .createShareLink(
            objectType: widget.objectType,
            objectId: widget.objectId,
            expiresInDays: _expiresInDays,
          );
      if (!mounted) return;
      final url = _visitorUrl(created);
      await Clipboard.setData(ClipboardData(text: url));
      Analytics.track('share_link_created', {'object_type': widget.objectType});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share link created and copied')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create link: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copy(ShareLink link) async {
    final url = _visitorUrl(link);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _revoke(ShareLink link) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Revoke share link?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: const Text(
              'Anyone with this link will immediately lose access.',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Revoke'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(funkwhaleApiProvider).deleteShareLink(link.uuid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Share link revoked')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not revoke: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share “${widget.title}”',
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Anyone with the secret link can listen to this item only. '
                'They cannot browse the rest of your library.',
                style: TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Expires',
                    style: TextStyle(color: AppTheme.onBackgroundMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _expiresInDays,
                      dropdownColor: AppTheme.surfaceContainerHigh,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.onBackground),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Never')),
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                        DropdownMenuItem(value: 90, child: Text('90 days')),
                      ],
                      onChanged: (v) => setState(() => _expiresInDays = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon:
                    _creating
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.link_rounded),
                label: Text(_creating ? 'Creating…' : 'Create link & copy'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Existing links',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_links.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No share links yet.',
                    style: TextStyle(color: AppTheme.onBackgroundMuted),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _links.length,
                    separatorBuilder:
                        (context, index) =>
                            const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, i) {
                      final link = _links[i];
                      final exp = link.expirationDate;
                      final expLabel =
                          exp == null
                              ? 'Never expires'
                              : (link.isExpired
                                  ? 'Expired'
                                  : 'Expires ${exp.toLocal().toString().split('.').first}');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          link.label.isNotEmpty
                              ? link.label
                              : 'Link · ${link.token.substring(0, 8)}…',
                          style: const TextStyle(
                            color: AppTheme.onBackground,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          expLabel,
                          style: TextStyle(
                            color:
                                link.isExpired
                                    ? AppTheme.error
                                    : AppTheme.onBackgroundMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Copy',
                              onPressed: () => _copy(link),
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: AppTheme.onBackground,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Revoke',
                              onPressed: () => _revoke(link),
                              icon: const Icon(
                                Icons.link_off_rounded,
                                color: AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
