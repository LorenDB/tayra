import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Permission ──────────────────────────────────────────────────────────

/// Whether the signed-in user may access user / invitation manage endpoints.
///
/// Uses `me.permissions.settings` (superuser-derived grants included).
final canManageUsersProvider = Provider.autoDispose<AsyncValue<bool>>((ref) {
  final me = ref.watch(meUserProvider);
  return me.whenData((user) => user.canManageUsers);
});
