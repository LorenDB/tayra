import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Channel constants ─────────────────────────────────────────────────────

const _channel = MethodChannel('dev.lorendb.tayra/genai_prompt');

/// Feature status values returned by the native plugin.
/// Must stay in sync with GenaiPromptPlugin.kt.
const _statusUnavailable = 0;
const _statusDownloadable = 1;
const _statusDownloading = 2;
const _statusAvailable = 3;

// ── State ────────────────────────────────────────────────────────────────

/// All possible states for the AI summary feature.
abstract class AiSummaryState {
  const AiSummaryState();
}

/// The current platform doesn't support on-device AI (e.g. iOS / desktop).
class AiSummaryUnsupported extends AiSummaryState {
  const AiSummaryUnsupported();
}

/// Gemini Nano is not available on this specific Android device.
class AiSummaryDeviceUnsupported extends AiSummaryState {
  const AiSummaryDeviceUnsupported();
}

/// The model needs to be downloaded before inference can run.
class AiSummaryDownloadRequired extends AiSummaryState {
  const AiSummaryDownloadRequired();
}

/// The model is currently being downloaded.
class AiSummaryDownloading extends AiSummaryState {
  const AiSummaryDownloading();
}

/// Inference is in progress.
class AiSummaryGenerating extends AiSummaryState {
  const AiSummaryGenerating();
}

/// Summary successfully generated.
class AiSummaryReady extends AiSummaryState {
  final String text;
  const AiSummaryReady(this.text);
}

/// An error occurred during generation.
class AiSummaryError extends AiSummaryState {
  final String message;
  const AiSummaryError(this.message);
}

// ── Notifier ─────────────────────────────────────────────────────────────

class AiSummaryNotifier extends Notifier<AiSummaryState> {
  final int _year;

  AiSummaryNotifier(this._year);

  @override
  AiSummaryState build() {
    // Kick off async initialisation; return the initial state synchronously.
    Future.microtask(_init);
    return const AiSummaryUnsupported();
  }

  Future<void> _init() async {
    // ML Kit GenAI is Android-only.
    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('AiSummary: platform unsupported: $defaultTargetPlatform');
      try {
        Aptabase.instance.trackEvent('year_review_ai_platform_unsupported', {
          'platform': defaultTargetPlatform.toString(),
          'year': _year,
        });
      } catch (_) {}
      state = const AiSummaryUnsupported();
      return;
    }

    // Respect the global AI toggle.
    final settings = ref.read(settingsProvider);
    if (!settings.aiEnabled) {
      debugPrint('AiSummary: AI disabled by user setting');
      state = const AiSummaryUnsupported();
      return;
    }

    try {
      final statusRaw = await _channel.invokeMethod<int>('checkFeatureStatus');
      final status = statusRaw ?? _statusUnavailable;
      debugPrint('AiSummary: feature status for year=$_year -> $status');
      try {
        Aptabase.instance.trackEvent('year_review_ai_feature_status', {
          'year': _year,
          'status': status,
        });
      } catch (_) {}

      switch (status) {
        case _statusAvailable:
          debugPrint('AiSummary: feature available, starting generation');
          state = const AiSummaryGenerating();
          await _generate();

        case _statusDownloadable:
          debugPrint('AiSummary: feature downloadable (model required)');
          state = const AiSummaryDownloadRequired();

        case _statusDownloading:
          debugPrint('AiSummary: feature is currently downloading');
          state = const AiSummaryDownloading();

        case _statusUnavailable:
        default:
          debugPrint('AiSummary: feature unavailable on this device');
          state = const AiSummaryDeviceUnsupported();
      }
    } catch (e) {
      debugPrint('AiSummary: error checking feature status: $e');
      try {
        Aptabase.instance.trackEvent('year_review_ai_feature_check_failed', {
          'year': _year,
          'error': e.toString(),
        });
      } catch (_) {}
      state = const AiSummaryDeviceUnsupported();
    }
  }

  /// Trigger model download, then generate the summary once ready.
  Future<void> downloadAndGenerate() async {
    debugPrint('AiSummary: download requested for year=$_year');
    try {
      Aptabase.instance.trackEvent('year_review_ai_download_requested', {
        'year': _year,
      });
    } catch (_) {}

    state = const AiSummaryDownloading();

    try {
      await _channel.invokeMethod<void>('downloadFeature');
      debugPrint('AiSummary: download completed for year=$_year');
      try {
        Aptabase.instance.trackEvent('year_review_ai_download_completed', {
          'year': _year,
        });
      } catch (_) {}
      state = const AiSummaryGenerating();
      await _generate();
    } catch (e) {
      debugPrint('AiSummary: download failed: $e');
      try {
        Aptabase.instance.trackEvent('year_review_ai_download_failed', {
          'year': _year,
          'error': e.toString(),
        });
      } catch (_) {}
      state = AiSummaryError('Download failed: ${e.toString()}');
    }
  }

  /// Retry summary generation after an error.
  Future<void> retry() async {
    state = const AiSummaryGenerating();
    await _generate();
  }

  Future<void> _generate() async {
    // Read the stats synchronously from the already-loaded yearReviewProvider.
    final statsAsync = ref.read(yearReviewProvider(_year));
    final stats = statsAsync.value;
    if (stats == null) {
      debugPrint(
        'AiSummary: cannot generate, stats not loaded for year=$_year',
      );
      state = const AiSummaryError('Stats not yet loaded.');
      return;
    }

    try {
      final promptText = _buildPrompt(stats);
      // Check for cached summary for this exact prompt to avoid re-running
      // inference when nothing meaningful changed.
      try {
        final prefs = await SharedPreferences.getInstance();
        final keyPrompt = 'ai_summary_${_year}_prompt';
        final keyText = 'ai_summary_${_year}_text';
        final lastPrompt = prefs.getString(keyPrompt);
        if (lastPrompt != null && lastPrompt == promptText) {
          final cached = prefs.getString(keyText);
          if (cached != null && cached.isNotEmpty) {
            debugPrint(
              'AiSummary: using cached summary for year=$_year; prompt unchanged',
            );
            state = AiSummaryReady(cached.trim());
            try {
              Aptabase.instance.trackEvent('year_review_ai_summary_cached', {
                'year': _year,
                'cached_length': cached.length,
              });
            } catch (_) {}
            return;
          }
        }
      } catch (e) {
        debugPrint('AiSummary: failed to read cache: $e');
      }
      debugPrint(
        'AiSummary: starting inference for year=$_year; '
        'prompt length=${promptText.length}',
      );
      try {
        Aptabase.instance.trackEvent('year_review_ai_inference_started', {
          'year': _year,
          'prompt_length': promptText.length,
        });
      } catch (_) {}

      final response = await _channel.invokeMethod<String>('runInference', {
        'prompt': promptText,
      });

      final text = response ?? '';
      debugPrint(
        'AiSummary: inference completed for year=$_year; '
        'response length=${text.length}',
      );
      try {
        Aptabase.instance.trackEvent('year_review_ai_summary_generated', {
          'year': _year,
          'response_length': text.length,
        });
      } catch (_) {}

      final trimmed = text.trim();
      // Persist successful summary + prompt for future caching.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ai_summary_${_year}_prompt', promptText);
        await prefs.setString('ai_summary_${_year}_text', trimmed);
        // If the calendar has moved past the reviewed year, also store a
        // permanent final copy so it won't be invalidated by later prompt
        // changes. This makes the year-end summary permanent.
        final now = DateTime.now();
        if (now.year > _year) {
          await prefs.setString('ai_summary_${_year}_final', trimmed);
          try {
            Aptabase.instance.trackEvent('year_review_ai_summary_final_saved', {
              'year': _year,
              'length': trimmed.length,
            });
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('AiSummary: failed to write cache: $e');
      }

      state = AiSummaryReady(trimmed);
    } catch (e) {
      debugPrint('AiSummary: inference failed for year=$_year: $e');
      try {
        Aptabase.instance.trackEvent('year_review_ai_inference_failed', {
          'year': _year,
          'error': e.toString(),
        });
      } catch (_) {}
      state = AiSummaryError(e.toString());
    }
  }

  /// Pregenerate the summary for use by the Year-in-Review banner. If the
  /// model needs downloading, this will attempt a download first. This runs
  /// silently in the background and caches results when available.
  Future<void> ensureGeneratedForBanner() async {
    // Platform check already handled at call sites, but double-check.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final statusRaw = await _channel.invokeMethod<int>('checkFeatureStatus');
      final status = statusRaw ?? _statusUnavailable;
      switch (status) {
        case _statusAvailable:
          await _generate();
          break;
        case _statusDownloadable:
          await downloadAndGenerate();
          break;
        case _statusDownloading:
        case _statusUnavailable:
        default:
          break;
      }
    } catch (e) {
      debugPrint('AiSummary: banner pregeneration failed: $e');
    }
  }

  /// Ensure a final, immutable summary copy exists for the reviewed year.
  /// If a final copy is not present but a cached draft is, copy it to
  /// the final key. Safe to call repeatedly.
  Future<void> ensureFinalSaved() async {
    try {
      final now = DateTime.now();
      if (now.year <= _year) return; // Only after the year is over.

      final prefs = await SharedPreferences.getInstance();
      final finalKey = 'ai_summary_${_year}_final';
      final draftKey = 'ai_summary_${_year}_text';
      final already = prefs.getString(finalKey);
      if (already != null && already.isNotEmpty) return;
      final draft = prefs.getString(draftKey);
      if (draft != null && draft.isNotEmpty) {
        await prefs.setString(finalKey, draft);
        try {
          Aptabase.instance.trackEvent(
            'year_review_ai_summary_final_saved_auto',
            {'year': _year, 'length': draft.length},
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('AiSummary: ensureFinalSaved failed: $e');
    }
  }
}

// ── Prompt builder ────────────────────────────────────────────────────────

String _buildPrompt(YearReviewStats stats) {
  final buf = StringBuffer();

  buf.writeln('Here is a summary of music listening habits for ${stats.year}:');
  buf.writeln('- Total listens: ${stats.totalListens}');
  buf.writeln('- Listening time: ${stats.formattedTotalTime}');
  buf.writeln('- Unique tracks heard: ${stats.uniqueTracks}');
  buf.writeln('- Unique artists heard: ${stats.uniqueArtists}');
  buf.writeln('- Unique albums heard: ${stats.uniqueAlbums}');

  if (stats.topTrack != null) {
    final t = stats.topTrack!;
    final artistPart = t.subtitle != null ? ' by ${t.subtitle}' : '';
    buf.writeln(
      '- Most-played track: "${t.name}"$artistPart (${t.count} plays)',
    );
  }

  if (stats.topArtist != null) {
    final a = stats.topArtist!;
    buf.writeln('- Most-played artist: ${a.name} (${a.count} plays)');
  }

  if (stats.topAlbum != null) {
    final al = stats.topAlbum!;
    buf.writeln('- Most-played album: "${al.name}"');
  }

  final peakMonthNumber = stats.peakMonth;
  if (peakMonthNumber > 0) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final peakData = stats.monthlyBreakdown.firstWhere(
      (m) => m.month == peakMonthNumber,
      orElse:
          () =>
              MonthlyListens(month: peakMonthNumber, count: 0, totalSeconds: 0),
    );
    buf.writeln(
      '- Most active month: ${monthNames[peakMonthNumber - 1]}'
      ' (${peakData.count} listens)',
    );
  }

  buf.writeln();
  buf.writeln(
    'Write a short, friendly 1-2 sentence summary of the music year, '
    'addressed directly to the listener using "you" and "your". '
    'Be specific about the highlights. Do not use bullet points or headings.',
  );

  return buf.toString();
}

// ── Standalone model status provider ─────────────────────────────────────

/// Returns the raw Gemini Nano feature status int for use by the settings
/// screen, independently of any year-specific summary.
///
/// Only meaningful on Android; returns [_statusUnavailable] on other platforms.
final genaiModelStatusProvider = FutureProvider<int>((ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return _statusUnavailable;
  }
  try {
    final status = await _channel.invokeMethod<int>('checkFeatureStatus');
    return status ?? _statusUnavailable;
  } catch (_) {
    return _statusUnavailable;
  }
});

// ── Provider ──────────────────────────────────────────────────────────────

/// Provides the AI summary state for a given review year.
///
/// Keyed by [int] year so it naturally re-creates when the user navigates
/// to a different year's review. When the year's stats are refreshed via
/// pull-to-refresh, call [ref.invalidate] on this provider to regenerate
/// the summary.
final aiSummaryProvider = NotifierProvider.autoDispose
    .family<AiSummaryNotifier, AiSummaryState, int>(
      (year) => AiSummaryNotifier(year),
    );
