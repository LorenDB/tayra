import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tayra/core/ai/ai_client.dart';

const _channel = MethodChannel('dev.lorendb.tayra/genai_prompt');

const _statusUnavailable = 0;
const _statusDownloadable = 1;
const _statusDownloading = 2;
const _statusAvailable = 3;

class GeminiNanoClient implements AiClient {
  @override
  Future<AiAvailability> checkAvailability() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AiAvailability.deviceUnsupported;
    }
    try {
      final status =
          await _channel.invokeMethod<int>('checkFeatureStatus') ??
          _statusUnavailable;
      switch (status) {
        case _statusAvailable:
          return AiAvailability.available;
        case _statusDownloadable:
          return AiAvailability.downloadRequired;
        case _statusDownloading:
          return AiAvailability.downloading;
        default:
          return AiAvailability.deviceUnsupported;
      }
    } catch (_) {
      return AiAvailability.deviceUnsupported;
    }
  }

  @override
  Future<void> download() async {
    await _channel.invokeMethod<void>('downloadFeature');
  }

  @override
  Future<String> runInference(String prompt) async {
    final response = await _channel.invokeMethod<String>('runInference', {
      'prompt': prompt,
    });
    return response ?? '';
  }

  @override
  Future<String> generatePlaylistName(
    String currentName, {
    int? playlistId,
  }) async {
    final name = await _channel.invokeMethod<String>('generatePlaylistName', {
      if (playlistId != null) 'playlist_id': playlistId,
      'current_name': currentName,
    });
    return name ?? '';
  }
}

/// Returns the raw Gemini Nano feature status int for the settings screen.
/// Only meaningful on Android; returns [_statusUnavailable] on other platforms.
Future<int> checkGeminiNanoStatus() async {
  if (defaultTargetPlatform != TargetPlatform.android) return _statusUnavailable;
  try {
    return await _channel.invokeMethod<int>('checkFeatureStatus') ??
        _statusUnavailable;
  } catch (_) {
    return _statusUnavailable;
  }
}
