import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Browse mode enum ────────────────────────────────────────────────────

enum BrowseMode { albums, artists }

// ── Settings state ──────────────────────────────────────────────────────

class SettingsState {
  final BrowseMode browseMode;

  const SettingsState({this.browseMode = BrowseMode.albums});

  SettingsState copyWith({BrowseMode? browseMode}) {
    return SettingsState(browseMode: browseMode ?? this.browseMode);
  }
}

// ── Settings notifier ───────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _keyBrowseMode = 'browse_mode';

  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyBrowseMode);
    if (modeStr == 'artists') {
      state = state.copyWith(browseMode: BrowseMode.artists);
    } else {
      // Default to albums
      state = state.copyWith(browseMode: BrowseMode.albums);
    }
  }

  Future<void> setBrowseMode(BrowseMode mode) async {
    state = state.copyWith(browseMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrowseMode, mode.name);
  }
}
