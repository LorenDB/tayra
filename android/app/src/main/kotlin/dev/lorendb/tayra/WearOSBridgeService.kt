package dev.lorendb.tayra

import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.graphics.drawable.toBitmap
import androidx.palette.graphics.Palette
import coil.ImageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Bridges the phone's MediaSession (from audio_service) to the Wear OS companion app.
 *
 * Phone -> Watch: Subscribes to MediaController.Callback and pushes state to the Wearable
 *   Data Layer at [PATH_PLAYER_STATE]. Extracts album art accent color via AndroidX Palette
 *   and includes it in the state push so the watch can theme its UI accordingly.
 *
 * Watch -> Phone: Receives control commands (play/pause, skip, seek, start-playlist,
 *   start-radio) as Wearable messages and forwards them to the MediaController's
 *   transport controls or Flutter via MediaBrowser custom actions.
 */
class WearOSBridgeService : WearableListenerService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var mediaBrowser: MediaBrowserCompat? = null
    private var mediaController: MediaControllerCompat? = null
    private var lastArtUrl: String? = null
    private var lastAccentColor: Int = Color.parseColor("#0992F2") // AppTheme.primary default

    private val connectionCallback = object : MediaBrowserCompat.ConnectionCallback() {
        override fun onConnected() {
            val token = mediaBrowser?.sessionToken ?: return
            mediaController = MediaControllerCompat(this@WearOSBridgeService, token)
            mediaController?.registerCallback(mediaControllerCallback)
            pushStateToWatch()
        }

        override fun onConnectionSuspended() {
            mediaController?.unregisterCallback(mediaControllerCallback)
            mediaController = null
        }

        override fun onConnectionFailed() {
            // AudioService not running -- push empty state so watch shows idle UI
            pushEmptyState()
        }
    }

    private val mediaControllerCallback = object : MediaControllerCompat.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadataCompat?) {
            pushStateToWatch()
        }

        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) {
            pushStateToWatch()
        }
    }

    override fun onCreate() {
        super.onCreate()
        connectToMediaBrowser()
    }

    override fun onDestroy() {
        mediaController?.unregisterCallback(mediaControllerCallback)
        mediaBrowser?.disconnect()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            PATH_GET_STATE -> {
                if (mediaBrowser?.isConnected == true) {
                    pushStateToWatch()
                } else {
                    connectToMediaBrowser()
                }
            }
            PATH_PLAY_PAUSE -> {
                val controller = mediaController ?: return
                if (controller.playbackState?.state == PlaybackStateCompat.STATE_PLAYING) {
                    controller.transportControls.pause()
                } else {
                    controller.transportControls.play()
                }
            }
            PATH_SKIP_NEXT -> mediaController?.transportControls?.skipToNext()
            PATH_SKIP_PREV -> mediaController?.transportControls?.skipToPrevious()
            PATH_SEEK -> {
                val posMs = String(messageEvent.data).toLongOrNull() ?: return
                mediaController?.transportControls?.seekTo(posMs)
            }
            PATH_START_PLAYLIST -> {
                val playlistId = String(messageEvent.data).toIntOrNull() ?: return
                // Use MediaBrowser custom action to tell Flutter to start a playlist
                mediaController?.transportControls?.sendCustomAction(
                    "startPlaylist", android.os.Bundle().apply {
                        putInt("playlistId", playlistId)
                    }
                )
            }
            PATH_START_PLAYLIST_SHUFFLED -> {
                val playlistId = String(messageEvent.data).toIntOrNull() ?: return
                mediaController?.transportControls?.sendCustomAction(
                    "startPlaylistShuffled", android.os.Bundle().apply {
                        putInt("playlistId", playlistId)
                    }
                )
            }
            PATH_START_RADIO -> {
                val radioId = String(messageEvent.data).toIntOrNull() ?: return
                mediaController?.transportControls?.sendCustomAction(
                    "startRadio", android.os.Bundle().apply {
                        putInt("radioId", radioId)
                    }
                )
            }
            PATH_START_RADIO_SHUFFLED -> {
                val radioId = String(messageEvent.data).toIntOrNull() ?: return
                mediaController?.transportControls?.sendCustomAction(
                    "startRadioShuffled", android.os.Bundle().apply {
                        putInt("radioId", radioId)
                    }
                )
            }
            PATH_START_INSTANCE_RADIO -> {
                val radioType = String(messageEvent.data)
                mediaController?.transportControls?.sendCustomAction(
                    "startInstanceRadio", android.os.Bundle().apply {
                        putString("radioType", radioType)
                    }
                )
            }
            PATH_START_INSTANCE_RADIO_SHUFFLED -> {
                val radioType = String(messageEvent.data)
                mediaController?.transportControls?.sendCustomAction(
                    "startInstanceRadioShuffled", android.os.Bundle().apply {
                        putString("radioType", radioType)
                    }
                )
            }
            PATH_REQUEST_BROWSE -> {
                // Watch is requesting the playlists/radios list.
                // Forward to Flutter via custom action; Flutter will push data back
                // through the MethodChannel -> pushBrowseDataToWatch().
                mediaController?.transportControls?.sendCustomAction(
                    "requestBrowseData", null
                )
            }
            PATH_TOGGLE_FAVORITE -> {
                mediaController?.transportControls?.sendCustomAction(
                    "toggleFavorite", null
                )
            }
        }
    }

    private fun connectToMediaBrowser() {
        mediaBrowser?.disconnect()
        val componentName = ComponentName(this, "com.ryanheise.audioservice.AudioService")
        mediaBrowser = MediaBrowserCompat(this, componentName, connectionCallback, null)
        mediaBrowser?.connect()
    }

    private fun pushStateToWatch() {
        val metadata = mediaController?.metadata
        val state = mediaController?.playbackState
        val isPlaying = state?.state == PlaybackStateCompat.STATE_PLAYING

        // PlaybackStateCompat.position is a stale seed; lastPositionUpdateTime is in
        // elapsedRealtime(). Add elapsed time to get the accurate current position.
        val rawPosition = state?.position ?: 0L
        val lastUpdateElapsed = state?.lastPositionUpdateTime ?: 0L
        val currentPosition = if (isPlaying && lastUpdateElapsed > 0L) {
            rawPosition + (SystemClock.elapsedRealtime() - lastUpdateElapsed)
        } else {
            rawPosition
        }

        val artUrl = metadata?.getString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI) ?: ""

        // Check if we need to extract a new accent color
        if (artUrl.isNotEmpty() && artUrl != lastArtUrl) {
            lastArtUrl = artUrl
            extractAccentColor(artUrl)
        } else if (artUrl.isEmpty()) {
            lastArtUrl = null
            lastAccentColor = Color.parseColor("#0992F2")
        }

        val request = PutDataMapRequest.create(PATH_PLAYER_STATE).apply {
            dataMap.putString("title", metadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE) ?: "")
            dataMap.putString("artist", metadata?.getString(MediaMetadataCompat.METADATA_KEY_ARTIST) ?: "")
            dataMap.putString("album", metadata?.getString(MediaMetadataCompat.METADATA_KEY_ALBUM) ?: "")
            // audio_service stores art URI under DISPLAY_ICON_URI
            dataMap.putString("artUrl", artUrl)
            dataMap.putBoolean("isPlaying", isPlaying)
            dataMap.putLong("position", currentPosition)
            dataMap.putLong("duration", metadata?.getLong(MediaMetadataCompat.METADATA_KEY_DURATION) ?: 0L)
            dataMap.putInt("accentColor", lastAccentColor)
            // Force a Data Layer update even when only position changed
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }

        Wearable.getDataClient(this)
            .putDataItem(request.asPutDataRequest().setUrgent())
    }

    private fun pushEmptyState() {
        val request = PutDataMapRequest.create(PATH_PLAYER_STATE).apply {
            dataMap.putString("title", "")
            dataMap.putString("artist", "")
            dataMap.putString("album", "")
            dataMap.putString("artUrl", "")
            dataMap.putBoolean("isPlaying", false)
            dataMap.putLong("position", 0L)
            dataMap.putLong("duration", 0L)
            dataMap.putInt("accentColor", Color.parseColor("#0992F2"))
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }
        Wearable.getDataClient(this)
            .putDataItem(request.asPutDataRequest().setUrgent())
    }

    /**
     * Extract the dominant accent color from album art using AndroidX Palette.
     * Runs asynchronously; when complete, pushes an updated state to the watch.
     */
    private fun extractAccentColor(artUrl: String) {
        serviceScope.launch {
            try {
                val loader = ImageLoader(this@WearOSBridgeService)
                val request = ImageRequest.Builder(this@WearOSBridgeService)
                    .data(artUrl)
                    .size(100, 100)
                    .allowHardware(false) // Palette needs software bitmap
                    .build()
                val result = loader.execute(request)
                if (result is SuccessResult) {
                    val bitmap = result.drawable.toBitmap()
                    val palette = Palette.from(bitmap).maximumColorCount(24).generate()
                    val color = extractBestColor(palette)
                    lastAccentColor = color
                    // Push updated state with the new accent color
                    pushStateToWatch()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to extract accent color from $artUrl", e)
            }
        }
    }

    /**
     * Extract the best accent color from a palette, matching the Flutter app's
     * algorithm in palette_provider.dart. Prefers vibrant colors, ensures
     * contrast against black background.
     */
    private fun extractBestColor(palette: Palette): Int {
        val candidates = listOfNotNull(
            palette.vibrantSwatch,
            palette.lightVibrantSwatch,
            palette.darkVibrantSwatch,
            palette.mutedSwatch,
            palette.lightMutedSwatch,
            palette.dominantSwatch,
        ).sortedByDescending { it.population }

        for (swatch in candidates) {
            val adjusted = ensureContrast(swatch.rgb, minimumContrast = 2.5)
            if (adjusted != null) return adjusted
        }

        return Color.parseColor("#0992F2") // AppTheme.primary fallback
    }

    /**
     * Ensure a color has sufficient contrast against a black background.
     * Mirrors the _ensureContrast function from palette_provider.dart.
     */
    private fun ensureContrast(color: Int, minimumContrast: Double = 2.5): Int? {
        val minSaturation = 0.25f
        val lightnessStep = 0.02f
        val maxLightness = (1.05 / minimumContrast - 0.05).toFloat()

        val hsl = FloatArray(3)
        androidx.core.graphics.ColorUtils.colorToHSL(color, hsl)

        if (hsl[1] < minSaturation) hsl[1] = minSaturation
        if (hsl[2] > maxLightness) hsl[2] = maxLightness

        while (contrastOnBlack(hsl) < minimumContrast && hsl[2] < maxLightness) {
            hsl[2] = (hsl[2] + lightnessStep).coerceAtMost(maxLightness)
        }

        if (contrastOnBlack(hsl) < minimumContrast) return null
        return androidx.core.graphics.ColorUtils.HSLToColor(hsl)
    }

    private fun contrastOnBlack(hsl: FloatArray): Double {
        val color = androidx.core.graphics.ColorUtils.HSLToColor(hsl)
        val luminance = androidx.core.graphics.ColorUtils.calculateLuminance(color)
        return (luminance + 0.05) / 0.05
    }

    companion object {
        private const val TAG = "WearOSBridge"

        const val PATH_PLAYER_STATE = "/tayra/player-state"
        const val PATH_PLAY_PAUSE = "/tayra/play-pause"
        const val PATH_SKIP_NEXT = "/tayra/skip-next"
        const val PATH_SKIP_PREV = "/tayra/skip-prev"
        const val PATH_SEEK = "/tayra/seek"
        const val PATH_GET_STATE = "/tayra/get-state"
        const val PATH_START_PLAYLIST = "/tayra/start-playlist"
        const val PATH_START_PLAYLIST_SHUFFLED = "/tayra/start-playlist-shuffled"
        const val PATH_START_RADIO = "/tayra/start-radio"
        const val PATH_START_RADIO_SHUFFLED = "/tayra/start-radio-shuffled"
        const val PATH_START_INSTANCE_RADIO = "/tayra/start-instance-radio"
        const val PATH_START_INSTANCE_RADIO_SHUFFLED = "/tayra/start-instance-radio-shuffled"
        const val PATH_BROWSE_DATA = "/tayra/browse-data"
        const val PATH_REQUEST_BROWSE = "/tayra/request-browse"
        const val PATH_TOGGLE_FAVORITE = "/tayra/toggle-favorite"

        /**
         * Push playlists and radios data to the watch via the Wearable Data Layer.
         * Static so it can be called from Flutter's MethodChannel handler in MainActivity.
         *
         * @param context Android context for accessing DataClient
         * @param playlistsJson JSON array string of playlists [{id, name, tracksCount}, ...]
         * @param radiosJson JSON array string of radios [{id, name, description}, ...]
         */
        fun pushBrowseDataToWatch(context: android.content.Context, playlistsJson: String, radiosJson: String) {
            val request = PutDataMapRequest.create(PATH_BROWSE_DATA).apply {
                dataMap.putString("playlists", playlistsJson)
                dataMap.putString("radios", radiosJson)
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }
            Wearable.getDataClient(context)
                .putDataItem(request.asPutDataRequest().setUrgent())
        }
    }
}
