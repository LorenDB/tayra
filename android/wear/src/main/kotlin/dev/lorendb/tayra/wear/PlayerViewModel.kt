package dev.lorendb.tayra.wear

import android.app.Application
import android.net.Uri
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray

// ── State data classes ──────────────────────────────────────────────────

data class WearPlayerState(
    val title: String = "",
    val artist: String = "",
    val album: String = "",
    val artUrl: String = "",
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val accentColor: Color = Color(0xFF0992F2),
)

data class BrowsePlaylist(
    val id: Int,
    val name: String,
    val tracksCount: Int,
)

data class BrowseRadio(
    val id: Int,
    val name: String,
    val description: String,
)

data class WearBrowseState(
    val playlists: List<BrowsePlaylist> = emptyList(),
    val radios: List<BrowseRadio> = emptyList(),
    val instanceRadios: List<BrowseRadio> = listOf(
        BrowseRadio(-100, "Your content", "Tracks you uploaded"),
        BrowseRadio(-101, "Random", "Random selection of tracks"),
        BrowseRadio(-102, "Favorites", "Tracks you favorited"),
        BrowseRadio(-103, "Less listened", "Tracks you listened to less"),
    ),
    val isLoading: Boolean = true,
)

// ── Message paths ───────────────────────────────────────────────────────

private const val PATH_PLAYER_STATE = "/tayra/player-state"
private const val PATH_PLAY_PAUSE = "/tayra/play-pause"
private const val PATH_SKIP_NEXT = "/tayra/skip-next"
private const val PATH_SKIP_PREV = "/tayra/skip-prev"
private const val PATH_SEEK = "/tayra/seek"
private const val PATH_GET_STATE = "/tayra/get-state"
private const val PATH_START_PLAYLIST = "/tayra/start-playlist"
private const val PATH_START_PLAYLIST_SHUFFLED = "/tayra/start-playlist-shuffled"
private const val PATH_START_RADIO = "/tayra/start-radio"
private const val PATH_START_RADIO_SHUFFLED = "/tayra/start-radio-shuffled"
private const val PATH_START_INSTANCE_RADIO = "/tayra/start-instance-radio"
private const val PATH_START_INSTANCE_RADIO_SHUFFLED = "/tayra/start-instance-radio-shuffled"
private const val PATH_BROWSE_DATA = "/tayra/browse-data"
private const val PATH_REQUEST_BROWSE = "/tayra/request-browse"
private const val PATH_TOGGLE_FAVORITE = "/tayra/toggle-favorite"

// ── Instance radio type mapping ─────────────────────────────────────────

private val instanceRadioTypes = mapOf(
    -100 to "actor-content",
    -101 to "random",
    -102 to "favorites",
    -103 to "less-listened",
)

// ── ViewModel ───────────────────────────────────────────────────────────

class PlayerViewModel(application: Application) : AndroidViewModel(application),
    DataClient.OnDataChangedListener {

    private val _playerState = MutableStateFlow(WearPlayerState())
    val playerState: StateFlow<WearPlayerState> = _playerState.asStateFlow()

    private val _browseState = MutableStateFlow(WearBrowseState())
    val browseState: StateFlow<WearBrowseState> = _browseState.asStateFlow()

    // Last accurate position received from the phone, plus the wall-clock time we got it.
    // Used to interpolate positionMs locally so the progress bar moves every second.
    private var basePositionMs: Long = 0L
    private var baseTimeMs: Long = 0L
    private var tickJob: Job? = null

    private val dataClient = Wearable.getDataClient(application)
    private val messageClient = Wearable.getMessageClient(application)
    private val nodeClient = Wearable.getNodeClient(application)

    init {
        dataClient.addListener(this)
        loadCurrentState()
        loadBrowseData()
    }

    override fun onCleared() {
        tickJob?.cancel()
        dataClient.removeListener(this)
        super.onCleared()
    }

    // ── DataClient.OnDataChangedListener ────────────────────────────────

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                when (event.dataItem.uri.path) {
                    PATH_PLAYER_STATE -> {
                        applyState(DataMapItem.fromDataItem(event.dataItem).dataMap.toWearState())
                    }
                    PATH_BROWSE_DATA -> {
                        applyBrowseData(DataMapItem.fromDataItem(event.dataItem).dataMap)
                    }
                }
            }
        }
    }

    // ── Public API ──────────────────────────────────────────────────────

    fun requestState() = sendMessage(PATH_GET_STATE, ByteArray(0))
    fun sendPlayPause() = sendMessage(PATH_PLAY_PAUSE, ByteArray(0))
    fun sendSkipNext() = sendMessage(PATH_SKIP_NEXT, ByteArray(0))
    fun sendSkipPrev() = sendMessage(PATH_SKIP_PREV, ByteArray(0))
    fun sendSeek(positionMs: Long) = sendMessage(PATH_SEEK, positionMs.toString().toByteArray())
    fun sendToggleFavorite() = sendMessage(PATH_TOGGLE_FAVORITE, ByteArray(0))

    fun startPlaylist(playlistId: Int) {
        sendMessage(PATH_START_PLAYLIST, playlistId.toString().toByteArray())
    }

    fun startPlaylistShuffled(playlistId: Int) {
        sendMessage(PATH_START_PLAYLIST_SHUFFLED, playlistId.toString().toByteArray())
    }

    fun startRadio(radioId: Int) {
        // Check if this is an instance radio (negative sentinel id)
        val radioType = instanceRadioTypes[radioId]
        if (radioType != null) {
            sendMessage(PATH_START_INSTANCE_RADIO, radioType.toByteArray())
        } else {
            sendMessage(PATH_START_RADIO, radioId.toString().toByteArray())
        }
    }

    fun startRadioShuffled(radioId: Int) {
        val radioType = instanceRadioTypes[radioId]
        if (radioType != null) {
            sendMessage(PATH_START_INSTANCE_RADIO_SHUFFLED, radioType.toByteArray())
        } else {
            sendMessage(PATH_START_RADIO_SHUFFLED, radioId.toString().toByteArray())
        }
    }

    fun requestBrowseData() {
        _browseState.value = _browseState.value.copy(isLoading = true)
        sendMessage(PATH_REQUEST_BROWSE, ByteArray(0))
    }

    // ── Private helpers ─────────────────────────────────────────────────

    /**
     * Apply a state update from the phone. Resets the interpolation baseline so the local
     * tick starts counting forward from the freshly received position.
     */
    private fun applyState(newState: WearPlayerState) {
        basePositionMs = newState.positionMs
        baseTimeMs = System.currentTimeMillis()
        _playerState.value = newState
        if (newState.isPlaying) startTick() else stopTick()
    }

    /**
     * Coroutine that advances positionMs by 1 s every second while playing.
     * The phone still pushes real position updates on play/pause/seek/skip events
     * which call [applyState] and reset the baseline, preventing drift accumulation.
     */
    private fun startTick() {
        stopTick()
        tickJob = viewModelScope.launch {
            while (true) {
                delay(1_000)
                val elapsed = System.currentTimeMillis() - baseTimeMs
                val capped = (basePositionMs + elapsed)
                    .coerceAtMost(_playerState.value.durationMs.coerceAtLeast(0L))
                _playerState.value = _playerState.value.copy(positionMs = capped)
            }
        }
    }

    private fun stopTick() {
        tickJob?.cancel()
        tickJob = null
    }

    /** Read the current DataItem on startup so we don't show a blank screen. */
    private fun loadCurrentState() {
        viewModelScope.launch {
            try {
                val items = dataClient.getDataItems(
                    Uri.parse("wear://*$PATH_PLAYER_STATE")
                ).await()
                for (i in 0 until items.count) {
                    if (items[i].uri.path == PATH_PLAYER_STATE) {
                        applyState(DataMapItem.fromDataItem(items[i]).dataMap.toWearState())
                        break
                    }
                }
                items.release()
            } catch (_: Exception) {
                // No cached state available; will update when phone pushes
            }
        }
    }

    /** Read cached browse data on startup. */
    private fun loadBrowseData() {
        viewModelScope.launch {
            try {
                val items = dataClient.getDataItems(
                    Uri.parse("wear://*$PATH_BROWSE_DATA")
                ).await()
                for (i in 0 until items.count) {
                    if (items[i].uri.path == PATH_BROWSE_DATA) {
                        applyBrowseData(DataMapItem.fromDataItem(items[i]).dataMap)
                        break
                    }
                }
                items.release()
            } catch (_: Exception) {
                // No cached browse data; request from phone
            }
            // Always request fresh browse data from the phone
            requestBrowseData()
        }
    }

    private fun applyBrowseData(dataMap: com.google.android.gms.wearable.DataMap) {
        try {
            val playlistsJson = dataMap.getString("playlists") ?: "[]"
            val radiosJson = dataMap.getString("radios") ?: "[]"

            val playlists = mutableListOf<BrowsePlaylist>()
            val playlistsArray = JSONArray(playlistsJson)
            for (i in 0 until playlistsArray.length()) {
                val obj = playlistsArray.getJSONObject(i)
                playlists.add(
                    BrowsePlaylist(
                        id = obj.getInt("id"),
                        name = obj.getString("name"),
                        tracksCount = obj.optInt("tracksCount", 0),
                    )
                )
            }

            val radios = mutableListOf<BrowseRadio>()
            val radiosArray = JSONArray(radiosJson)
            for (i in 0 until radiosArray.length()) {
                val obj = radiosArray.getJSONObject(i)
                radios.add(
                    BrowseRadio(
                        id = obj.getInt("id"),
                        name = obj.getString("name"),
                        description = obj.optString("description", ""),
                    )
                )
            }

            _browseState.value = _browseState.value.copy(
                playlists = playlists,
                radios = radios,
                isLoading = false,
            )
        } catch (e: Exception) {
            _browseState.value = _browseState.value.copy(isLoading = false)
        }
    }

    private fun sendMessage(path: String, data: ByteArray) {
        viewModelScope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                for (node in nodes) {
                    messageClient.sendMessage(node.id, path, data).await()
                }
            } catch (_: Exception) {
                // Watch not connected or phone app not running
            }
        }
    }
}

private fun com.google.android.gms.wearable.DataMap.toWearState(): WearPlayerState {
    val colorInt = getInt("accentColor")
    val accent = if (colorInt != 0) {
        Color(
            red = android.graphics.Color.red(colorInt) / 255f,
            green = android.graphics.Color.green(colorInt) / 255f,
            blue = android.graphics.Color.blue(colorInt) / 255f,
            alpha = 1f,
        )
    } else {
        Color(0xFF0992F2)
    }

    return WearPlayerState(
        title = getString("title") ?: "",
        artist = getString("artist") ?: "",
        album = getString("album") ?: "",
        artUrl = getString("artUrl") ?: "",
        isPlaying = getBoolean("isPlaying"),
        positionMs = getLong("position"),
        durationMs = getLong("duration"),
        accentColor = accent,
    )
}
