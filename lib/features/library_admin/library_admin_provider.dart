import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Permission ──────────────────────────────────────────────────────────

/// Whether the signed-in user may access library manage endpoints.
///
/// Uses `me.permissions.library` (superuser-derived grants included).
final canManageLibraryProvider = Provider.autoDispose<AsyncValue<bool>>((ref) {
  final me = ref.watch(meUserProvider);
  return me.whenData((user) => user.canManageLibrary);
});
