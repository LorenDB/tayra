import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Permission ──────────────────────────────────────────────────────────

/// Whether the signed-in user may access instance admin settings.
///
/// Uses `me.permissions.settings` (superuser-derived grants included).
final canManageSettingsProvider = Provider.autoDispose<AsyncValue<bool>>((ref) {
  final me = ref.watch(meUserProvider);
  return me.whenData((user) => user.canManageSettings);
});

// ── Preferences list ────────────────────────────────────────────────────

/// All global preferences from `GET /api/v1/instance/admin/settings/`.
final adminSettingsProvider =
    FutureProvider.autoDispose<List<GlobalPreference>>((ref) async {
      return ref.watch(funkwhaleApiProvider).getAdminSettings();
    });
