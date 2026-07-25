import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/ai/gemini_nano_client.dart';
import 'package:tayra/core/ai/openai_compatible_client.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Availability enum ─────────────────────────────────────────────────────

enum AiAvailability {
  available,
  notConfigured,
  downloadRequired,
  downloading,
  deviceUnsupported,
}

// ── Abstract client ───────────────────────────────────────────────────────

abstract class AiClient {
  Future<AiAvailability> checkAvailability();
  Future<void> download();
  Future<String> runInference(String prompt);
  Future<String> generatePlaylistName(String currentName, {int? playlistId});
}

// ── Provider ──────────────────────────────────────────────────────────────

final aiClientProvider = Provider<AiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.aiProviderType) {
    case AiProviderType.geminiNano:
      return GeminiNanoClient();
    case AiProviderType.groq:
      return OpenAiCompatibleClient(
        baseUrl: 'https://api.groq.com/openai/v1',
        apiKey: settings.groqApiKey,
        model: settings.groqModel,
        requiresApiKey: true,
      );
    case AiProviderType.openRouter:
      return OpenAiCompatibleClient(
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: settings.openRouterApiKey,
        model: settings.openRouterModel,
        requiresApiKey: true,
      );
    case AiProviderType.custom:
      return OpenAiCompatibleClient(
        baseUrl: settings.customEndpointUrl,
        apiKey: settings.customEndpointApiKey,
        model: settings.customModelName.isNotEmpty
            ? settings.customModelName
            : 'gpt-4o-mini',
        requiresApiKey: false,
      );
  }
});
