package dev.lorendb.tayra

import android.content.Context
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * In-app MethodChannel plugin that exposes Gemini Nano (ML Kit GenAI Prompt API)
 * to the Flutter layer.
 *
 * Channel name: "dev.lorendb.tayra/genai_prompt"
 *
 * Methods:
 *   checkFeatureStatus() -> int  (0=unavailable, 1=downloadable, 2=downloading, 3=available)
 *   downloadFeature()    -> void
 *   runInference(prompt: String) -> String
 */
class GenaiPromptPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "dev.lorendb.tayra/genai_prompt"

        private const val METHOD_CHECK_STATUS = "checkFeatureStatus"
        private const val METHOD_DOWNLOAD = "downloadFeature"
        private const val METHOD_RUN_INFERENCE = "runInference"
        private const val METHOD_GENERATE_PLAYLIST_NAME = "generatePlaylistName"

        // Mirror of com.google.mlkit.genai.common.FeatureStatus int constants.
        private const val STATUS_UNAVAILABLE = 0
        private const val STATUS_DOWNLOADABLE = 1
        private const val STATUS_DOWNLOADING = 2
        private const val STATUS_AVAILABLE = 3
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val model: GenerativeModel by lazy { Generation.getClient() }
    private val modelFutures: GenerativeModelFutures by lazy {
        GenerativeModelFutures.from(model)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_CHECK_STATUS -> checkFeatureStatus(result)
            METHOD_DOWNLOAD -> downloadFeature(result)
            METHOD_RUN_INFERENCE -> {
                val prompt = call.argument<String>("prompt")
                if (prompt == null) {
                    result.error("INVALID_ARGS", "Missing 'prompt' argument", null)
                    return
                }
                runInference(prompt, result)
            }
            METHOD_GENERATE_PLAYLIST_NAME -> {
                val currentName = call.argument<String>("current_name")
                // playlist_id is optional here, we don't need it for generation
                if (currentName == null) {
                    result.error("INVALID_ARGS", "Missing 'current_name' argument", null)
                    return
                }
                generatePlaylistName(currentName, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun checkFeatureStatus(result: MethodChannel.Result) {
        scope.launch {
            try {
                val status: Int = modelFutures.checkStatus().get()
                val statusInt = when (status) {
                    FeatureStatus.AVAILABLE -> STATUS_AVAILABLE
                    FeatureStatus.DOWNLOADABLE -> STATUS_DOWNLOADABLE
                    FeatureStatus.DOWNLOADING -> STATUS_DOWNLOADING
                    else -> STATUS_UNAVAILABLE
                }
                result.success(statusInt)
            } catch (e: Exception) {
                result.error("GENAI_ERROR", "checkFeatureStatus failed: ${e.message}", null)
            }
        }
    }

    private fun downloadFeature(result: MethodChannel.Result) {
        try {
            modelFutures.download(object : DownloadCallback {
                override fun onDownloadStarted(bytesToDownload: Long) {}
                override fun onDownloadProgress(totalBytesDownloaded: Long) {}
                override fun onDownloadCompleted() {
                    result.success(null)
                }
                override fun onDownloadFailed(e: GenAiException) {
                    result.error("DOWNLOAD_ERROR", "Download failed: ${e.message}", null)
                }
            })
        } catch (e: Exception) {
            result.error("GENAI_ERROR", "downloadFeature failed: ${e.message}", null)
        }
    }

    private fun runInference(prompt: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                val response = modelFutures.generateContent(prompt).get()
                val text = response.candidates
                    .mapNotNull { it.text }
                    .joinToString("")
                result.success(text)
            } catch (e: Exception) {
                result.error("INFERENCE_ERROR", "runInference failed: ${e.message}", null)
            }
        }
    }

    private fun generatePlaylistName(currentName: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Create a constrained prompt that instructs the model to return
                // exactly one short playlist name (1-6 words) and nothing else.
                val prompt = buildString {
                    append("You are a helpful assistant. Output exactly one short playlist name (1-6 words) and nothing else. ")
                    append("Do not add commentary, punctuation, quotes, or explanation.\n")
                    append("Based on: '")
                    append(currentName)
                    append("'")
                }

                val response = modelFutures.generateContent(prompt).get()
                // Take first candidate and sanitize: prefer the first non-empty line,
                // strip surrounding quotes and trailing punctuation.
                val raw = response.candidates.firstOrNull()?.text ?: ""
                val candidate = raw
                    .lineSequence()
                    .map { it.trim() }
                    .firstOrNull { it.isNotEmpty() }
                    ?.let {
                        var s = it
                        // Remove surrounding quotes
                        if ((s.startsWith("\"") && s.endsWith("\"")) || (s.startsWith("'") && s.endsWith("'"))) {
                            s = s.substring(1, s.length - 1)
                        }
                        // Remove trailing punctuation that might be accidental
                        s = s.trim().trimEnd { ch -> ch == '.' || ch == '!' || ch == '?' }
                        // Collapse multiple spaces
                        s = s.replace(Regex("\\s+"), " ")
                        s.trim()
                    }
                if (candidate.isNullOrEmpty()) {
                    result.error("NO_SUGGESTION", "Model returned empty suggestion", null)
                } else {
                    result.success(candidate)
                }
            } catch (e: Exception) {
                result.error("GENERATION_ERROR", "generatePlaylistName failed: ${e.message}", null)
            }
        }
    }
}
