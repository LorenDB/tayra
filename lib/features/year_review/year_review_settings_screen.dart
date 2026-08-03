import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Year in Review entry and year-end prompt preferences.
class YearReviewSettingsScreen extends ConsumerWidget {
  const YearReviewSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Year in Review'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SettingsSectionHeader(title: 'Recap'),
          const _YearReviewTile(),
          SettingsSwitchTile(
            icon: Icons.event,
            title: 'Show year-end prompts',
            subtitle: 'Show the Year in Review banner and prompts at year end',
            value: settings.showYearEndPrompts,
            onChanged:
                (v) => ref
                    .read(settingsProvider.notifier)
                    .setShowYearEndPrompts(v),
          ),
        ],
      ),
    );
  }
}

// ── Year in Review entry tile ───────────────────────────────────────────

class _YearReviewTile extends ConsumerWidget {
  const _YearReviewTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listenCountAsync = ref.watch(totalListenCountProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/year-review'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open Year in Review',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      listenCountAsync.when(
                        loading:
                            () => const Text(
                              'Loading...',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                        error:
                            (error, stack) => const Text(
                              'See your listening recap',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                        data:
                            (count) => Text(
                              count > 0
                                  ? '$count total listens tracked'
                                  : 'Start listening to build your recap',
                              style: const TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
