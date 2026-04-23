import 'package:tayra/core/analytics/analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/ai/ai_client.dart';
import 'package:tayra/core/ai/gemini_nano_client.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── State ────────────────────────────────────────────────────────────────

/// All possible states for the AI summary feature.
abstract class AiSummaryState {
  const AiSummaryState();
}

/// The current platform / configuration doesn't support AI (disabled or no provider configured).
class AiSummaryUnsupported extends AiSummaryState {
  const AiSummaryUnsupported();
}

/// The AI provider is not available on this specific device (e.g. Gemini Nano on unsupported hardware).
class AiSummaryDeviceUnsupported extends AiSummaryState {
  const AiSummaryDeviceUnsupported();
}

/// The model needs to be downloaded before inference can run (Gemini Nano only).
class AiSummaryDownloadRequired extends AiSummaryState {
  const AiSummaryDownloadRequired();
}

/// The model is currently being downloaded (Gemini Nano only).
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
    Future.microtask(_init);
    return const AiSummaryUnsupported();
  }

  Future<void> _init() async {
    final settings = ref.read(settingsProvider);
    if (!settings.aiEnabled) {
      debugPrint('AiSummary: AI disabled by user setting');
      state = const AiSummaryUnsupported();
      return;
    }

    final client = ref.read(aiClientProvider);

    try {
      final availability = await client.checkAvailability();
      debugPrint(
        'AiSummary: availability for year=$_year -> $availability',
      );
      try {
        Analytics.track('year_review_ai_feature_status', {
          'year': _year,
          'status': availability.name,
          'provider': settings.aiProviderType.name,
        });
      } catch (_) {}

      switch (availability) {
        case AiAvailability.available:
          debugPrint('AiSummary: provider available, starting generation');
          state = const AiSummaryGenerating();
          await _generate();
        case AiAvailability.downloadRequired:
          debugPrint('AiSummary: model download required');
          state = const AiSummaryDownloadRequired();
        case AiAvailability.downloading:
          debugPrint('AiSummary: model is currently downloading');
          state = const AiSummaryDownloading();
        case AiAvailability.notConfigured:
          debugPrint('AiSummary: provider not configured');
          state = const AiSummaryUnsupported();
        case AiAvailability.deviceUnsupported:
          debugPrint('AiSummary: provider unavailable on this device');
          state = const AiSummaryDeviceUnsupported();
      }
    } catch (e) {
      debugPrint('AiSummary: error checking availability: $e');
      try {
        Analytics.track('year_review_ai_feature_check_failed', {
          'year': _year,
          'had_error': true,
          'error_type': e.runtimeType.toString(),
        });
      } catch (_) {}
      state = const AiSummaryDeviceUnsupported();
    }
  }

  /// Trigger model download, then generate the summary once ready.
  Future<void> downloadAndGenerate() async {
    debugPrint('AiSummary: download requested for year=$_year');
    try {
      Analytics.track('year_review_ai_download_requested', {'year': _year});
    } catch (_) {}

    state = const AiSummaryDownloading();

    try {
      final client = ref.read(aiClientProvider);
      await client.download();
      debugPrint('AiSummary: download completed for year=$_year');
      try {
        Analytics.track('year_review_ai_download_completed', {'year': _year});
      } catch (_) {}
      state = const AiSummaryGenerating();
      await _generate();
    } catch (e) {
      debugPrint('AiSummary: download failed: $e');
      try {
        Analytics.track('year_review_ai_download_failed', {
          'year': _year,
          'had_error': true,
          'error_type': e.runtimeType.toString(),
        });
      } catch (_) {}
      state = const AiSummaryError('Download failed');
    }
  }

  /// Retry summary generation after an error.
  Future<void> retry() async {
    state = const AiSummaryGenerating();
    await _generate();
  }

  Future<void> _generate() async {
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
              Analytics.track('year_review_ai_summary_cached', {
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
        Analytics.track('year_review_ai_inference_started', {
          'year': _year,
          'prompt_length': promptText.length,
        });
      } catch (_) {}

      final client = ref.read(aiClientProvider);
      final text = await client.runInference(promptText);

      debugPrint(
        'AiSummary: inference completed for year=$_year; '
        'response length=${text.length}',
      );
      try {
        Analytics.track('year_review_ai_summary_generated', {
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
        // changes.
        final now = DateTime.now();
        if (now.year > _year) {
          await prefs.setString('ai_summary_${_year}_final', trimmed);
          try {
            Analytics.track('year_review_ai_summary_final_saved', {
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
        Analytics.track('year_review_ai_inference_failed', {
          'year': _year,
          'had_error': true,
          'error_type': e.runtimeType.toString(),
        });
      } catch (_) {}
      state = AiSummaryError('Inference failed: ${e.runtimeType}');
    }
  }

  /// Pregenerate the summary for use by the Year-in-Review banner.
  /// Runs silently in the background and caches results when available.
  Future<void> ensureGeneratedForBanner() async {
    final settings = ref.read(settingsProvider);
    if (!settings.aiEnabled) return;

    try {
      final client = ref.read(aiClientProvider);
      final availability = await client.checkAvailability();
      switch (availability) {
        case AiAvailability.available:
          await _generate();
        case AiAvailability.downloadRequired:
          await downloadAndGenerate();
        default:
          break;
      }
    } catch (e) {
      debugPrint('AiSummary: banner pregeneration failed: $e');
    }
  }

  /// Ensure a final, immutable summary copy exists for the reviewed year.
  Future<void> ensureFinalSaved() async {
    try {
      final now = DateTime.now();
      if (now.year <= _year) return;

      final prefs = await SharedPreferences.getInstance();
      final finalKey = 'ai_summary_${_year}_final';
      final draftKey = 'ai_summary_${_year}_text';
      final already = prefs.getString(finalKey);
      if (already != null && already.isNotEmpty) return;
      final draft = prefs.getString(draftKey);
      if (draft != null && draft.isNotEmpty) {
        await prefs.setString(finalKey, draft);
        try {
          Analytics.track('year_review_ai_summary_final_saved_auto', {
            'year': _year,
            'length': draft.length,
          });
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

/// Returns the raw Gemini Nano feature status int for the settings screen.
/// Only meaningful when Gemini Nano is the selected provider.
final genaiModelStatusProvider = FutureProvider<int>((ref) async {
  return checkGeminiNanoStatus();
});

// ── Provider ──────────────────────────────────────────────────────────────

final aiSummaryProvider = NotifierProvider.autoDispose
    .family<AiSummaryNotifier, AiSummaryState, int>(
      (year) => AiSummaryNotifier(year),
    );
