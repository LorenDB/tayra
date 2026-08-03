import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_shell.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Visual and navigation-bar preferences.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Appearance'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SettingsSectionHeader(title: 'Theme'),
          SettingsSwitchTile(
            icon: Icons.format_paint_outlined,
            title: 'Album accent colors',
            subtitle: 'Use album cover art to tint UI accents',
            value: settings.useDynamicAlbumAccent,
            onChanged: (value) {
              Analytics.track('dynamic_album_accent_toggled', {
                'enabled': value,
              });
              ref
                  .read(settingsProvider.notifier)
                  .setUseDynamicAlbumAccent(value);
            },
          ),

          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'Album display'),
          SettingsSwitchTile(
            icon: Icons.album_outlined,
            title: 'Continuous disc numbering',
            subtitle:
                'Number tracks across all discs in one unbroken sequence; '
                'otherwise disc labels are shown between sections',
            value:
                settings.multiDiscDisplayMode ==
                MultiDiscDisplayMode.continuousNumbers,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setMultiDiscDisplayMode(
                    value
                        ? MultiDiscDisplayMode.continuousNumbers
                        : MultiDiscDisplayMode.discSections,
                  );
            },
          ),

          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'Navigation'),
          _NavBarSettingsTile(pinnedIndices: settings.mobilePinnedTabIndices),
        ],
      ),
    );
  }
}

// ── Navigation bar pin picker ───────────────────────────────────────────

class _NavBarSettingsTile extends ConsumerWidget {
  final Set<int> pinnedIndices;

  const _NavBarSettingsTile({required this.pinnedIndices});

  // Non-home tab indices (1–6 in AppShell.tabs).
  static const _configurableIndices = [1, 2, 3, 4, 5, 6];

  String get _subtitle {
    final names =
        _configurableIndices
            .where((i) => pinnedIndices.contains(i))
            .map((i) => AppShell.tabs[i].label)
            .toList();
    return names.isEmpty ? 'None' : names.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsActionTile(
      icon: Icons.tune_rounded,
      title: 'Navigation bar items',
      subtitle: _subtitle,
      onTap: () => _showSheet(context, ref),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => _NavBarSheet(
            initialPinned: pinnedIndices,
            onChanged:
                (updated) => ref
                    .read(settingsProvider.notifier)
                    .setMobilePinnedTabIndices(updated),
          ),
    );
  }
}

class _NavBarSheet extends StatefulWidget {
  final Set<int> initialPinned;
  final ValueChanged<Set<int>> onChanged;

  const _NavBarSheet({required this.initialPinned, required this.onChanged});

  @override
  State<_NavBarSheet> createState() => _NavBarSheetState();
}

class _NavBarSheetState extends State<_NavBarSheet> {
  late Set<int> _pinned;

  static const _configurableIndices = [1, 2, 3, 4, 5, 6];
  static const _maxPinned = 4;

  @override
  void initState() {
    super.initState();
    _pinned = Set.from(widget.initialPinned);
  }

  void _toggle(int index, bool value) {
    if (value && _pinned.length >= _maxPinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpin another item first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      if (value) {
        _pinned.add(index);
      } else {
        _pinned.remove(index);
      }
    });
    widget.onChanged(Set.from(_pinned));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onBackgroundMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Navigation bar items',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Choose up to 4 items to pin to the bottom nav bar when the '
              'narrow layout is active. Unpinned items appear on the home screen.',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 13),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ..._configurableIndices.map((i) {
            final tab = AppShell.tabs[i];
            final isPinned = _pinned.contains(i);
            return SwitchListTile(
              secondary: Icon(tab.icon, color: AppTheme.onBackgroundSubtle),
              title: Text(
                tab.label,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 15,
                ),
              ),
              value: isPinned,
              onChanged: (v) => _toggle(i, v),
              activeThumbColor: AppTheme.primary,
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
