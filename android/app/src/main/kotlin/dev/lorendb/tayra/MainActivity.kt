package dev.lorendb.tayra

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GenaiPromptPlugin.CHANNEL,
        ).setMethodCallHandler(GenaiPromptPlugin(this))

        // Wear OS browse data channel: receives playlists/radios JSON from Flutter
        // and pushes it to the watch via the Wearable Data Layer.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.lorendb.tayra/wear_browse",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pushBrowseData" -> {
                    val playlistsJson = call.argument<String>("playlists") ?: "[]"
                    val radiosJson = call.argument<String>("radios") ?: "[]"
                    WearOSBridgeService.pushBrowseDataToWatch(this, playlistsJson, radiosJson)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
