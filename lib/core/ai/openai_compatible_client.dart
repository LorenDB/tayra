import 'package:dio/dio.dart';
import 'package:tayra/core/ai/ai_client.dart';

class OpenAiCompatibleClient implements AiClient {
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool requiresApiKey;

  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.requiresApiKey = true,
  });

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        headers: {
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<AiAvailability> checkAvailability() async {
    if (baseUrl.isEmpty) return AiAvailability.notConfigured;
    if (requiresApiKey && apiKey.isEmpty) return AiAvailability.notConfigured;
    return AiAvailability.available;
  }

  @override
  Future<void> download() async {
    // Cloud providers don't require a download step.
  }

  @override
  Future<String> runInference(String prompt) async {
    final dio = _buildDio();
    final response = await dio.post('chat/completions', data: {
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': 512,
    });
    final choices = response.data['choices'] as List<dynamic>;
    final content =
        choices.first['message']['content'] as String? ?? '';
    return content.trim();
  }

  @override
  Future<String> generatePlaylistName(
    String currentName, {
    int? playlistId,
  }) async {
    final prompt =
        'Generate a creative, catchy name for a music playlist. '
        'The current name is: "$currentName". '
        'Suggest one alternative playlist name. '
        'Reply with only the playlist name, nothing else. '
        'Do not include quotation marks.';
    final result = await runInference(prompt);
    // Strip surrounding quotes the model may add
    final cleaned = result.trim();
    if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      return cleaned.substring(1, cleaned.length - 1).trim();
    }
    return cleaned;
  }
}
