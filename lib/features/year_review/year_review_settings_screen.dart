import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';

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
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SettingsSectionHeader(title: 'Settings'),
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
