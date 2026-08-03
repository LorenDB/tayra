import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Settings hub. Groups link to focused subpages; admin tools are isolated
/// from personal library actions.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateProvider);
    final meAsync = ref.watch(meUserProvider);
    final dntEnv = AppPlatform.doNotTrackEnv?.trim().toLowerCase();
    final showAnalyticsToggle = !(dntEnv == '1' || dntEnv == 'true');

    final canManageLibrary = meAsync.maybeWhen(
      data: (me) => me.canManageLibrary,
      orElse: () => false,
    );
    final canManageSettings = meAsync.maybeWhen(
      data: (me) => me.canManageSettings,
      orElse: () => false,
    );
    final canManageUsers = meAsync.maybeWhen(
      data: (me) => me.canManageUsers,
      orElse: () => false,
    );
    final showAdministration =
        canManageLibrary || canManageSettings || canManageUsers;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account ───────────────────────────────────────────────────
          const SettingsSectionHeader(title: 'Account'),
          if (authState.serverUrl != null)
            SettingsInfoTile(
              icon: Icons.dns_outlined,
              title: 'Server',
              subtitle: authState.serverUrl!,
            ),
          SettingsActionTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Account settings',
            subtitle: 'Profile, security, and account deactivation',
            onTap: () => context.push('/settings/account'),
          ),
          SettingsActionTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: 'Sign out and return to the login screen',
            iconColor: AppTheme.error,
            onTap: () => _confirmLogout(context, ref),
          ),

          // ── Your library (personal, not admin) ────────────────────────
          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'Your library'),
          SettingsActionTile(
            icon: Icons.upload_rounded,
            title: 'Upload music',
            subtitle: 'Upload audio files to your own libraries',
            onTap: () => context.push('/upload'),
          ),

          // ── Administration (instance-wide; permission-gated) ──────────
          if (showAdministration) ...[
            const SizedBox(height: 8),
            const SettingsSectionHeader(title: 'Administration'),
            if (canManageLibrary)
              SettingsActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Library admin',
                subtitle:
                    'Manage all instance libraries, uploads, tags, and channels',
                onTap: () => context.push('/manage/library'),
              ),
            if (canManageSettings)
              SettingsActionTile(
                icon: Icons.tune_rounded,
                title: 'Instance settings',
                subtitle: 'Edit pod-wide Funkwhale preferences',
                onTap: () => context.push('/manage/settings'),
              ),
            if (canManageUsers)
              SettingsActionTile(
                icon: Icons.group_outlined,
                title: 'User management',
                subtitle: 'Manage local users and invitations',
                onTap: () => context.push('/manage/users'),
              ),
          ],

          // ── App preferences (subpages) ────────────────────────────────
          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'App'),
          SettingsActionTile(
            icon: Icons.play_circle_outline_rounded,
            title: 'Playback',
            subtitle: 'Gapless playback and audio options',
            onTap: () => context.push('/settings/playback'),
          ),
          SettingsActionTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, album display, and navigation bar',
            onTap: () => context.push('/settings/appearance'),
          ),
          if (AppPlatform.supportsOfflineCache)
            SettingsActionTile(
              icon: Icons.storage_rounded,
              title: 'Downloads & storage',
              subtitle: 'Offline mode, downloads, and cache',
              onTap: () => context.push('/settings/storage'),
            ),
          SettingsActionTile(
            icon: Icons.auto_graph_rounded,
            title: 'Year in Review',
            subtitle: 'Listening recap and year-end prompts',
            onTap: () => context.push('/settings/year-review-settings'),
          ),

          // ── About ─────────────────────────────────────────────────────
          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'About'),
          const _AboutTile(),
          if (showAnalyticsToggle)
            SettingsSwitchTile(
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              subtitle: 'Allow anonymous usage analytics',
              value: settings.analyticsEnabled,
              onChanged: (value) async {
                try {
                  if (!value) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setAnalyticsEnabled(false);
                    await Analytics.setEnabled(false);
                  } else {
                    await ref
                        .read(settingsProvider.notifier)
                        .setAnalyticsEnabled(true);
                    await Analytics.setEnabled(true);
                    Analytics.track('analytics_enabled');
                  }
                } catch (_) {}
              },
            ),
          const _DonationTile(),
          SettingsActionTile(
            icon: Icons.balance_outlined,
            title: 'Licenses',
            subtitle: 'View open-source licenses',
            onTap: () => showLicensePage(context: context),
          ),

          if (settings.developerModeUnlocked) ...[
            const SizedBox(height: 8),
            const SettingsSectionHeader(title: 'Developer'),
            SettingsActionTile(
              icon: Icons.code_rounded,
              title: 'Developer settings',
              subtitle: 'Tools for testing and development',
              onTap: () => context.push('/settings/developer'),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Log out?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: const Text(
              'You will need to log in again to access your library.',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Log out'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

// ── About tile (long-press easter egg) ──────────────────────────────────

/// Long-pressing the About tile 3 times unlocks Developer mode.
class _AboutTile extends ConsumerStatefulWidget {
  const _AboutTile();

  @override
  ConsumerState<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends ConsumerState<_AboutTile> {
  int _tapCount = 0;
  static const int _tapsRequired = 3;

  void _onLongPress() {
    final alreadyUnlocked = ref.read(settingsProvider).developerModeUnlocked;
    if (alreadyUnlocked) return;
    setState(() => _tapCount++);
    if (_tapCount >= _tapsRequired) {
      _tapCount = 0;
      ref.read(settingsProvider.notifier).setDeveloperModeUnlocked(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode enabled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: _onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.onBackgroundSubtle,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tayra',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Copyright Loren Burkholder | Licensed MIT',
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
        ),
      ),
    );
  }
}

// ── Donation buttons tile ───────────────────────────────────────────────

class _DonationTile extends StatelessWidget {
  static const _liberapayUrl = 'https://liberapay.com/LorenDB/donate';
  static const _paypalUrl =
      'https://www.paypal.com/donate/?business=LSTPU6GJTKCQE&no_recurring=0&item_name=Thank+you+for+supporting+continued+development+of+Tayra.&currency_code=USD';

  const _DonationTile();

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: AppTheme.onBackgroundSubtle,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tayra is free and open-source. If you enjoy using it, '
                  'consider supporting its development!',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DonationButton(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Liberapay',
                        onTap: () {
                          Analytics.track('donation_link_tapped', {
                            'platform': 'liberapay',
                          });
                          _openUrl(_liberapayUrl);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DonationButton(
                        icon: Icons.payments_outlined,
                        label: 'PayPal',
                        onTap: () {
                          Analytics.track('donation_link_tapped', {
                            'platform': 'paypal',
                          });
                          _openUrl(_paypalUrl);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DonationButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
