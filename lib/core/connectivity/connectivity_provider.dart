import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Raw connectivity stream ──────────────────────────────────────────────

/// Tracks the current list of connectivity results from the OS.
final connectivityResultProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

// ── Network reachability ──────────────────────────────────────────────────

/// Whether the device has no network connectivity at all, based solely on
/// the OS-reported connectivity results (does NOT include forced offline).
///
/// Note: having a network interface (wifi/mobile) does NOT guarantee actual
/// internet access – but it's the best lightweight signal available without
/// hitting a real endpoint. We use the OS signal for snappy UI updates and
/// verify actual reachability lazily.
final hasNetworkProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityResultProvider);
  return connectivity.when(
    data:
        (results) => results.any(
          (r) =>
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.ethernet ||
              r == ConnectivityResult.vpn,
        ),
    loading: () => true, // Optimistic until we know otherwise
    error: (_, e) => true,
  );
});

// ── Offline state (combined) ─────────────────────────────────────────────

/// Notifier that tracks whether the app should behave as if it is offline.
///
/// This combines two signals:
///  1. The OS-level connectivity status (no network interface).
///  2. The user's "force offline mode" setting.
///
/// The notifier also exposes a method to prompt the user to switch to
/// offline-only content when connectivity is lost.
class OfflineStateNotifier extends Notifier<OfflineState> {
  @override
  OfflineState build() {
    final hasNetwork = ref.watch(hasNetworkProvider);
    final forcedOffline = ref.watch(settingsProvider).forceOfflineMode;

    // When network is lost, we go offline automatically.
    // When network returns, we go back online UNLESS forced offline is still on.
    final isOffline = forcedOffline || !hasNetwork;

    // If we just transitioned to offline (network loss only, not forced), show
    // the suggestion banner. We track it in the state so the UI can dismiss it.
    // On the very first build, `state` is not yet initialised — guard against
    // the resulting StateError by falling back to a default OfflineState.
    OfflineState previous;
    try {
      previous = state;
    } catch (_) {
      previous = const OfflineState();
    }

    final becameOfflineDueToNetwork =
        !previous.isOffline && !hasNetwork && !forcedOffline;

    return previous.copyWith(
      isOffline: isOffline,
      showOfflineSuggestion:
          becameOfflineDueToNetwork || previous.showOfflineSuggestion,
    );
  }

  void dismissSuggestion() {
    state = state.copyWith(showOfflineSuggestion: false);
  }

  void enableOfflineFilter() {
    state = state.copyWith(
      offlineFilterEnabled: true,
      showOfflineSuggestion: false,
    );
  }

  void disableOfflineFilter() {
    state = state.copyWith(offlineFilterEnabled: false);
  }
}

class OfflineState {
  /// True when the app should behave as if offline (no network + forced).
  final bool isOffline;

  /// True when a network-loss event just occurred and we should prompt the
  /// user to switch to offline-only content.
  final bool showOfflineSuggestion;

  /// True when the user has chosen to show only cached/offline content.
  final bool offlineFilterEnabled;

  const OfflineState({
    this.isOffline = false,
    this.showOfflineSuggestion = false,
    this.offlineFilterEnabled = false,
  });

  OfflineState copyWith({
    bool? isOffline,
    bool? showOfflineSuggestion,
    bool? offlineFilterEnabled,
  }) {
    return OfflineState(
      isOffline: isOffline ?? this.isOffline,
      showOfflineSuggestion:
          showOfflineSuggestion ?? this.showOfflineSuggestion,
      offlineFilterEnabled: offlineFilterEnabled ?? this.offlineFilterEnabled,
    );
  }
}

final offlineStateProvider =
    NotifierProvider<OfflineStateNotifier, OfflineState>(
      OfflineStateNotifier.new,
    );

/// Convenience provider: true when offline content filter is active.
/// This is true when either:
///  - the offline filter was explicitly enabled, or
///  - forced offline mode is enabled.
///
/// We intentionally do not auto-enable the filter for transient network loss;
/// that path still uses the suggestion banner so the user can choose.
final offlineFilterActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(offlineStateProvider);
  final forcedOffline = ref.watch(
    settingsProvider.select((settings) => settings.forceOfflineMode),
  );
  return state.offlineFilterEnabled || forcedOffline;
});

/// Verify that we can actually reach the configured Funkwhale server.
/// Returns true if the server is reachable, false otherwise.
/// Uses a lightweight TCP connection attempt rather than an HTTP call
/// to minimise side-effects.
Future<bool> checkServerReachability(String serverUrl) async {
  try {
    final uri = Uri.parse(serverUrl);
    final host = uri.host;
    final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
