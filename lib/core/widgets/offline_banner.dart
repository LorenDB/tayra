import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Offline status bar ───────────────────────────────────────────────────

/// A persistent bar shown at the top of the app when the device is offline
/// (or forced offline mode is enabled). It shows the current status and,
/// when a network-loss suggestion is pending, offers to switch to showing
/// only locally cached content.
class OfflineStatusBar extends ConsumerWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineStateProvider);

    if (!offlineState.isOffline && !offlineState.offlineFilterEnabled) {
      return const SizedBox.shrink();
    }

    // Show a suggestion banner if the device just went offline and the filter
    // isn't yet enabled.
    if (offlineState.isOffline &&
        offlineState.showOfflineSuggestion &&
        !offlineState.offlineFilterEnabled) {
      return _OfflineSuggestionBanner(offlineState: offlineState);
    }

    // Show a compact status bar when offline or filter is active.
    return _OfflineStatusChip(offlineState: offlineState);
  }
}

// ── Suggestion banner (shown once on network loss) ───────────────────────

class _OfflineSuggestionBanner extends ConsumerWidget {
  final OfflineState offlineState;

  const _OfflineSuggestionBanner({required this.offlineState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.surfaceContainerHigh,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.onBackgroundMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You\'re offline. Show only downloaded content?',
                style: TextStyle(color: AppTheme.onBackground, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                ref.read(offlineStateProvider.notifier).enableOfflineFilter();
              },
              child: const Text(
                'Show offline',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap:
                  () =>
                      ref
                          .read(offlineStateProvider.notifier)
                          .dismissSuggestion(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact status chip ───────────────────────────────────────────────────

class _OfflineStatusChip extends ConsumerWidget {
  final OfflineState offlineState;

  const _OfflineStatusChip({required this.offlineState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterEnabled = offlineState.offlineFilterEnabled;
    final isOffline = offlineState.isOffline;
    final forcedOffline = ref.watch(
      settingsProvider.select((s) => s.forceOfflineMode),
    );

    String label;
    IconData icon;
    Color color;

    if (forcedOffline) {
      label = 'Forced offline mode';
      icon = Icons.cloud_off_rounded;
      color = AppTheme.primary;
    } else if (filterEnabled) {
      label = 'Showing offline content';
      icon = Icons.cloud_off_rounded;
      color = AppTheme.primary;
    } else {
      label = 'No internet connection';
      icon = Icons.wifi_off_rounded;
      color = AppTheme.onBackgroundMuted;
    }

    return Material(
      color: AppTheme.surfaceContainerHigh,
      child: InkWell(
        onTap:
            (filterEnabled || forcedOffline)
                ? () => _showOfflineOptions(context, ref, offlineState)
                : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.divider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // When forced offline: show an "Exit" button inline.
              if (forcedOffline) ...[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    // Clear forced offline mode and also disable the offline
                    // content filter so the UI returns to normal online
                    // behavior immediately.
                    ref
                        .read(settingsProvider.notifier)
                        .setForceOfflineMode(false);
                    ref
                        .read(offlineStateProvider.notifier)
                        .disableOfflineFilter();
                  },
                  child: const Text(
                    'Exit',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ] else if (!filterEnabled && isOffline) ...[
                // When offline but filter not yet active: offer to enable it.
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref
                        .read(offlineStateProvider.notifier)
                        .enableOfflineFilter();
                  },
                  child: const Text(
                    'Show offline',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ] else if (filterEnabled) ...[
                const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showOfflineOptions(
    BuildContext context,
    WidgetRef ref,
    OfflineState offlineState,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _OfflineOptionsSheet(offlineState: offlineState),
    );
  }
}

// ── Options bottom sheet ──────────────────────────────────────────────────

class _OfflineOptionsSheet extends ConsumerWidget {
  final OfflineState offlineState;

  const _OfflineOptionsSheet({required this.offlineState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterEnabled = offlineState.offlineFilterEnabled;
    final forcedOffline = ref.watch(
      settingsProvider.select((s) => s.forceOfflineMode),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.onBackgroundSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Offline content filter',
                    style: TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (forcedOffline)
              _SheetOption(
                icon: Icons.public_rounded,
                label: 'Exit forced offline mode',
                subtitle: 'Re-enable network access in the app',
                onTap: () {
                  // Mirror the inline Exit action: clear forced offline and
                  // also disable the offline filter so screens refresh to
                  // show online content immediately.
                  ref
                      .read(settingsProvider.notifier)
                      .setForceOfflineMode(false);
                  ref
                      .read(offlineStateProvider.notifier)
                      .disableOfflineFilter();
                  Navigator.of(context).pop();
                },
              ),
            if (!forcedOffline && filterEnabled)
              _SheetOption(
                icon: Icons.library_music_rounded,
                label: 'Show all content',
                subtitle: 'Include tracks not available offline',
                onTap: () {
                  ref
                      .read(offlineStateProvider.notifier)
                      .disableOfflineFilter();
                  Navigator.of(context).pop();
                },
              )
            else if (!forcedOffline)
              _SheetOption(
                icon: Icons.cloud_off_rounded,
                label: 'Show only offline content',
                subtitle: 'Only display tracks available without internet',
                onTap: () {
                  ref.read(offlineStateProvider.notifier).enableOfflineFilter();
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
      ),
    );
  }
}
