import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/http_client_factory.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/ai_summary_provider.dart';

// ── Model data class ──────────────────────────────────────────────────────

class AiModel {
  final String id;
  final String name;
  final String? description;

  const AiModel({required this.id, required this.name, this.description});
}

// ── Model fetching helpers ────────────────────────────────────────────────

Future<List<AiModel>> _fetchGroqModels(String apiKey) async {
  final dio = createDio(
    BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1/',
      headers: {'Authorization': 'Bearer $apiKey'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final response = await dio.get('models');
  final data = response.data['data'] as List<dynamic>;
  final models =
      data
          .map((m) => AiModel(id: m['id'] as String, name: m['id'] as String))
          .toList();
  models.sort((a, b) => a.id.compareTo(b.id));
  return models;
}

Future<List<AiModel>> _fetchOpenRouterModels() async {
  final dio = createDio(
    BaseOptions(
      baseUrl: 'https://openrouter.ai/api/v1/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final response = await dio.get('models');
  final data = response.data['data'] as List<dynamic>;
  final models =
      data
          .map(
            (m) => AiModel(
              id: m['id'] as String,
              name: (m['name'] as String?) ?? (m['id'] as String),
              description: m['description'] as String?,
            ),
          )
          .toList();
  models.sort((a, b) => a.name.compareTo(b.name));
  return models;
}

Future<List<AiModel>> _fetchCustomModels(String baseUrl, String apiKey) async {
  final normalised = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  final dio = createDio(
    BaseOptions(
      baseUrl: normalised,
      headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final response = await dio.get('models');
  final raw = response.data;
  final List<dynamic> data =
      raw is Map ? (raw['data'] as List<dynamic>? ?? []) : raw as List<dynamic>;
  final models =
      data.map((m) {
        final id = m['id'] as String? ?? m.toString();
        return AiModel(id: id, name: id);
      }).toList();
  models.sort((a, b) => a.id.compareTo(b.id));
  return models;
}

// ── Screen ────────────────────────────────────────────────────────────────

class AiProviderSettingsScreen extends ConsumerStatefulWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  ConsumerState<AiProviderSettingsScreen> createState() =>
      _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState
    extends ConsumerState<AiProviderSettingsScreen> {
  late TextEditingController _groqKeyCtrl;
  late TextEditingController _openRouterKeyCtrl;
  late TextEditingController _customUrlCtrl;
  late TextEditingController _customKeyCtrl;
  late TextEditingController _customModelCtrl;

  bool _groqKeyObscured = true;
  bool _openRouterKeyObscured = true;
  bool _customKeyObscured = true;

  bool _groqModelsLoading = false;
  bool _openRouterModelsLoading = false;
  bool _customModelsLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _groqKeyCtrl = TextEditingController(text: settings.groqApiKey)
      ..addListener(_saveGroqKey);
    _openRouterKeyCtrl = TextEditingController(text: settings.openRouterApiKey)
      ..addListener(_saveOpenRouterKey);
    _customUrlCtrl = TextEditingController(text: settings.customEndpointUrl)
      ..addListener(_saveCustomUrl);
    _customKeyCtrl = TextEditingController(text: settings.customEndpointApiKey)
      ..addListener(_saveCustomKey);
    _customModelCtrl = TextEditingController(
      text:
          settings.customModelName.isNotEmpty
              ? settings.customModelName
              : 'gpt-4o-mini',
    )..addListener(_saveCustomModel);
  }

  @override
  void dispose() {
    _groqKeyCtrl
      ..removeListener(_saveGroqKey)
      ..dispose();
    _openRouterKeyCtrl
      ..removeListener(_saveOpenRouterKey)
      ..dispose();
    _customUrlCtrl
      ..removeListener(_saveCustomUrl)
      ..dispose();
    _customKeyCtrl
      ..removeListener(_saveCustomKey)
      ..dispose();
    _customModelCtrl
      ..removeListener(_saveCustomModel)
      ..dispose();
    super.dispose();
  }

  void _saveGroqKey() => ref
      .read(settingsProvider.notifier)
      .setGroqApiKey(_groqKeyCtrl.text.trim());

  void _saveOpenRouterKey() => ref
      .read(settingsProvider.notifier)
      .setOpenRouterApiKey(_openRouterKeyCtrl.text.trim());

  void _saveCustomUrl() => ref
      .read(settingsProvider.notifier)
      .setCustomEndpointUrl(_customUrlCtrl.text.trim());

  void _saveCustomKey() => ref
      .read(settingsProvider.notifier)
      .setCustomEndpointApiKey(_customKeyCtrl.text.trim());

  void _saveCustomModel() => ref
      .read(settingsProvider.notifier)
      .setCustomModelName(_customModelCtrl.text.trim());

  // ── Model picker ────────────────────────────────────────────────────────

  Future<void> _openGroqModelPicker() async {
    _saveGroqKey();
    final apiKey = _groqKeyCtrl.text.trim();
    if (apiKey.isEmpty) return;

    setState(() => _groqModelsLoading = true);
    try {
      final models = await _fetchGroqModels(apiKey);
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      await _showModelPicker(
        models: models,
        currentModelId: settings.groqModel,
        onSelected:
            (m) => ref.read(settingsProvider.notifier).setGroqModel(m.id),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load Groq models: $e')));
    } finally {
      if (mounted) setState(() => _groqModelsLoading = false);
    }
  }

  Future<void> _openOpenRouterModelPicker() async {
    setState(() => _openRouterModelsLoading = true);
    try {
      final models = await _fetchOpenRouterModels();
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      await _showModelPicker(
        models: models,
        currentModelId: settings.openRouterModel,
        onSelected:
            (m) => ref.read(settingsProvider.notifier).setOpenRouterModel(m.id),
        searchable: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load OpenRouter models: $e')),
      );
    } finally {
      if (mounted) setState(() => _openRouterModelsLoading = false);
    }
  }

  Future<void> _openCustomModelPicker() async {
    _saveCustomUrl();
    _saveCustomKey();
    final url = _customUrlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() => _customModelsLoading = true);
    try {
      final models = await _fetchCustomModels(url, _customKeyCtrl.text.trim());
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      await _showModelPicker(
        models: models,
        currentModelId: settings.customModelName,
        onSelected: (m) {
          ref.read(settingsProvider.notifier).setCustomModelName(m.id);
          _customModelCtrl.text = m.id;
        },
        searchable: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load models from endpoint: $e')),
      );
    } finally {
      if (mounted) setState(() => _customModelsLoading = false);
    }
  }

  Future<void> _showModelPicker({
    required List<AiModel> models,
    required String currentModelId,
    required ValueChanged<AiModel> onSelected,
    bool searchable = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => _ModelPickerSheet(
            models: models,
            currentModelId: currentModelId,
            searchable: searchable,
            onSelected: (m) {
              Navigator.pop(ctx);
              onSelected(m);
            },
          ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selected = settings.aiProviderType;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Provider'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsSectionHeader(title: 'Provider'),

          // ── Gemini Nano (Android only) ──────────────────────────────────
          if (defaultTargetPlatform == TargetPlatform.android)
            _ProviderTile(
              title: 'Gemini Nano',
              subtitle:
                  'On-device inference — private, free, no internet needed',
              icon: Icons.memory_rounded,
              selected: selected == AiProviderType.geminiNano,
              onTap:
                  () => ref
                      .read(settingsProvider.notifier)
                      .setAiProviderType(AiProviderType.geminiNano),
              child: _GeminiNanoStatus(),
            ),

          // ── Groq ───────────────────────────────────────────────────────
          _ProviderTile(
            title: 'Groq',
            subtitle: 'Fast cloud inference — free tier available',
            icon: Icons.bolt_rounded,
            selected: selected == AiProviderType.groq,
            onTap:
                () => ref
                    .read(settingsProvider.notifier)
                    .setAiProviderType(AiProviderType.groq),
            child:
                selected == AiProviderType.groq
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ApiKeyField(
                          label: 'Groq API key',
                          hint: 'gsk_...',
                          controller: _groqKeyCtrl,
                          obscured: _groqKeyObscured,
                          onToggleObscure:
                              () => setState(
                                () => _groqKeyObscured = !_groqKeyObscured,
                              ),
                          onSubmitted: (_) => _saveGroqKey(),
                          onEditingComplete: _saveGroqKey,
                          helpText: 'Get a free API key at console.groq.com',
                        ),
                        if (_groqKeyCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ModelSelectorRow(
                            label: 'Model',
                            currentValue: settings.groqModel,
                            loading: _groqModelsLoading,
                            onTap: _openGroqModelPicker,
                          ),
                        ],
                      ],
                    )
                    : null,
          ),

          // ── OpenRouter ─────────────────────────────────────────────────
          _ProviderTile(
            title: 'OpenRouter',
            subtitle: 'Access hundreds of AI models via one API',
            icon: Icons.route_rounded,
            selected: selected == AiProviderType.openRouter,
            onTap:
                () => ref
                    .read(settingsProvider.notifier)
                    .setAiProviderType(AiProviderType.openRouter),
            child:
                selected == AiProviderType.openRouter
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ApiKeyField(
                          label: 'OpenRouter API key',
                          hint: 'sk-or-...',
                          controller: _openRouterKeyCtrl,
                          obscured: _openRouterKeyObscured,
                          onToggleObscure:
                              () => setState(
                                () =>
                                    _openRouterKeyObscured =
                                        !_openRouterKeyObscured,
                              ),
                          onSubmitted: (_) => _saveOpenRouterKey(),
                          onEditingComplete: _saveOpenRouterKey,
                          helpText: 'Get a free API key at openrouter.ai',
                        ),
                        const SizedBox(height: 10),
                        _ModelSelectorRow(
                          label: 'Model',
                          currentValue: settings.openRouterModel,
                          loading: _openRouterModelsLoading,
                          onTap: _openOpenRouterModelPicker,
                        ),
                      ],
                    )
                    : null,
          ),

          // ── Custom endpoint ─────────────────────────────────────────────
          _ProviderTile(
            title: 'Custom endpoint',
            subtitle: 'Any OpenAI-compatible API (e.g. Ollama, LM Studio)',
            icon: Icons.dns_outlined,
            selected: selected == AiProviderType.custom,
            onTap:
                () => ref
                    .read(settingsProvider.notifier)
                    .setAiProviderType(AiProviderType.custom),
            child:
                selected == AiProviderType.custom
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PlainTextField(
                          label: 'Base URL',
                          hint: 'http://localhost:11434/v1',
                          controller: _customUrlCtrl,
                          onSubmitted: (_) => _saveCustomUrl(),
                          onEditingComplete: _saveCustomUrl,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 10),
                        _ObscurableField(
                          label: 'API key (optional)',
                          hint: 'Leave blank if not required',
                          controller: _customKeyCtrl,
                          obscured: _customKeyObscured,
                          onToggleObscure:
                              () => setState(
                                () => _customKeyObscured = !_customKeyObscured,
                              ),
                          onSubmitted: (_) => _saveCustomKey(),
                          onEditingComplete: _saveCustomKey,
                        ),
                        const SizedBox(height: 10),
                        _PlainTextField(
                          label: 'Model name',
                          hint: 'gpt-4o-mini',
                          controller: _customModelCtrl,
                          onSubmitted: (_) => _saveCustomModel(),
                          onEditingComplete: _saveCustomModel,
                        ),
                        if (_customUrlCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon:
                                _customModelsLoading
                                    ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                    : const Icon(Icons.list_rounded, size: 16),
                            label: const Text(
                              'Load available models',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed:
                                _customModelsLoading
                                    ? null
                                    : _openCustomModelPicker,
                          ),
                        ],
                      ],
                    )
                    : null,
          ),
        ],
      ),
    );
  }
}

// ── Provider tile ─────────────────────────────────────────────────────────

class _ProviderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  const _ProviderTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border:
            selected
                ? Border.all(color: AppTheme.primary.withAlpha(120), width: 1.5)
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color:
                          selected
                              ? AppTheme.primary
                              : AppTheme.onBackgroundSubtle,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color:
                                  selected
                                      ? AppTheme.primary
                                      : AppTheme.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                  ],
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    color: AppTheme.surfaceContainerHigh,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gemini Nano status ────────────────────────────────────────────────────

class _GeminiNanoStatus extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(genaiModelStatusProvider);

    return statusAsync.when(
      loading:
          () => const _StatusRow(
            icon: Icons.hourglass_empty_rounded,
            label: 'Checking status…',
          ),
      error:
          (err, stack) => const _StatusRow(
            icon: Icons.error_outline,
            label: 'Status unavailable',
            color: AppTheme.error,
          ),
      data: (status) {
        const statusAvailable = 3;
        const statusDownloading = 2;
        const statusDownloadable = 1;

        switch (status) {
          case statusAvailable:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _StatusRow(
                  icon: Icons.check_circle_rounded,
                  label: 'Model downloaded — runs entirely on your device',
                  color: AppTheme.secondary,
                ),
              ],
            );
          case statusDownloading:
            return const _StatusRow(
              icon: Icons.download_rounded,
              label: 'Downloading model…',
            );
          case statusDownloadable:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _StatusRow(
                  icon: Icons.download_for_offline_rounded,
                  label: 'Model not yet downloaded',
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    'Download model',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    ref
                        .read(aiSummaryProvider(0).notifier)
                        .downloadAndGenerate();
                    ref.invalidate(genaiModelStatusProvider);
                  },
                ),
              ],
            );
          default:
            return const _StatusRow(
              icon: Icons.block_rounded,
              label: 'Not supported on this device',
              color: AppTheme.onBackgroundSubtle,
            );
        }
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatusRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.onBackgroundMuted;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(color: c, fontSize: 12))),
      ],
    );
  }
}

// ── Model selector row ────────────────────────────────────────────────────

class _ModelSelectorRow extends StatelessWidget {
  final String label;
  final String currentValue;
  final bool loading;
  final VoidCallback onTap;

  const _ModelSelectorRow({
    required this.label,
    required this.currentValue,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentValue.isEmpty ? '—' : currentValue,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: loading ? null : onTap,
          child:
              loading
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.primary,
                    ),
                  )
                  : const Text('Select', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── API key field ─────────────────────────────────────────────────────────

class _ApiKeyField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onEditingComplete;
  final String? helpText;

  const _ApiKeyField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.onToggleObscure,
    required this.onSubmitted,
    required this.onEditingComplete,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ObscurableField(
          label: label,
          hint: hint,
          controller: controller,
          obscured: obscured,
          onToggleObscure: onToggleObscure,
          onSubmitted: onSubmitted,
          onEditingComplete: onEditingComplete,
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText!,
            style: const TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _ObscurableField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onEditingComplete;

  const _ObscurableField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.onToggleObscure,
    required this.onSubmitted,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscured,
      style: const TextStyle(color: AppTheme.onBackground, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.onBackgroundMuted,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppTheme.onBackgroundSubtle,
          fontSize: 13,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: AppTheme.onBackgroundSubtle,
            size: 18,
          ),
          onPressed: onToggleObscure,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.surfaceContainerHigh),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.surfaceContainerHigh),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}

class _PlainTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onEditingComplete;
  final TextInputType? keyboardType;

  const _PlainTextField({
    required this.label,
    this.hint,
    required this.controller,
    required this.onSubmitted,
    required this.onEditingComplete,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.onBackground, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.onBackgroundMuted,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppTheme.onBackgroundSubtle,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.surfaceContainerHigh),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.surfaceContainerHigh),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}

// ── Model picker sheet ────────────────────────────────────────────────────

class _ModelPickerSheet extends StatefulWidget {
  final List<AiModel> models;
  final String currentModelId;
  final bool searchable;
  final ValueChanged<AiModel> onSelected;

  const _ModelPickerSheet({
    required this.models,
    required this.currentModelId,
    required this.searchable,
    required this.onSelected,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  late TextEditingController _searchCtrl;
  late List<AiModel> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = widget.models;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? widget.models
              : widget.models
                  .where(
                    (m) =>
                        m.id.toLowerCase().contains(q) ||
                        m.name.toLowerCase().contains(q),
                  )
                  .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Select model',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filtered.length} models',
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search models…',
                  hintStyle: const TextStyle(
                    color: AppTheme.onBackgroundSubtle,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.onBackgroundSubtle,
                    size: 20,
                  ),
                  suffixIcon:
                      _searchCtrl.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppTheme.onBackgroundSubtle,
                              size: 18,
                            ),
                            onPressed: () => _searchCtrl.clear(),
                          )
                          : null,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          const Divider(color: AppTheme.surfaceContainerHigh, height: 1),
          // Model list
          Expanded(
            child:
                _filtered.isEmpty
                    ? const Center(
                      child: Text(
                        'No models match your search',
                        style: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final model = _filtered[i];
                        final isSelected = model.id == widget.currentModelId;
                        return InkWell(
                          onTap: () => widget.onSelected(model),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model.name,
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? AppTheme.primary
                                                  : AppTheme.onBackground,
                                          fontSize: 13,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                      if (model.name != model.id) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          model.id,
                                          style: const TextStyle(
                                            color: AppTheme.onBackgroundSubtle,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: AppTheme.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
