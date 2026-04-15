package dev.lorendb.tayra.wear

import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

class MainActivity : ComponentActivity() {

    private val viewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // removed debug logging (WearPerf)
        setContent {
            val browseState by viewModel.browseState.collectAsStateWithLifecycle()
            val navController = rememberSwipeDismissableNavController()
            val hasLoadedBrowse = remember { mutableStateOf(false) }

            // Keep the navigation host subscribed only to browse state. Player state updates
            // every second while playback advances, and collecting it here causes the entire
            // nav tree to recompose even when the player screen is not visible.
            val onStartPlaylist = remember(navController) {
                { id: Int, label: String ->
                    navController.navigate("playAction/playlist/$id/${Uri.encode(label)}")
                }
            }
            val onStartRadio = remember(navController) {
                { id: Int, label: String ->
                    navController.navigate("playAction/radio/$id/${Uri.encode(label)}")
                }
            }
            val onNavigateToPlayer = remember(navController) {
                { navController.navigate("player") }
            }

            // Browse is always the root screen. Tapping a playlist or radio navigates
            // to the play-action submenu. The player is reached after confirming
            // play or shuffle. Swipe-to-dismiss at each level returns to the previous.
            SwipeDismissableNavHost(
                navController = navController,
                startDestination = "browse",
            ) {
                composable("browse") {
                    LaunchedEffect(Unit) {
                        if (!hasLoadedBrowse.value) {
                            hasLoadedBrowse.value = true
                            // Defer browse loading until after the first frame so initial
                            // screen composition can finish before any cache/network work.
                            withFrameNanos { }
                            viewModel.loadBrowseDataIfNeeded()
                        }
                    }
                    BrowseScreen(
                        state = browseState,
                        onStartPlaylist = onStartPlaylist,
                        onStartRadio = onStartRadio,
                        onRefresh = { viewModel.requestBrowseData() },
                        onNavigateToPlayer = onNavigateToPlayer,
                    )
                }

                composable("playAction/{itemType}/{itemId}/{itemLabel}") { backStackEntry ->
                    val itemType = backStackEntry.arguments?.getString("itemType") ?: ""
                    val itemId = backStackEntry.arguments?.getString("itemId")?.toIntOrNull() ?: return@composable
                    val itemLabel = Uri.decode(backStackEntry.arguments?.getString("itemLabel") ?: "")

                    PlayActionScreen(
                        label = itemLabel,
                        onPlay = {
                            when (itemType) {
                                "playlist" -> viewModel.startPlaylist(itemId)
                                "radio" -> viewModel.startRadio(itemId)
                            }
                            navController.navigate("player")
                        },
                        onShuffle = if (itemType == "playlist") {
                            {
                                viewModel.startPlaylistShuffled(itemId)
                                navController.navigate("player")
                            }
                        } else null,
                        showShuffle = itemType == "playlist",
                    )
                }

                composable("player") {
                    LaunchedEffect(Unit) {
                        viewModel.requestState()
                    }
                    val playerState by viewModel.playerState.collectAsStateWithLifecycle()
                    PlayerScreen(
                        state = playerState,
                        onPlayPause = { viewModel.sendPlayPause() },
                        onSkipNext = { viewModel.sendSkipNext() },
                        onSkipPrev = { viewModel.sendSkipPrev() },
                        onSeek = { posMs -> viewModel.sendSeek(posMs) },
                    )
                }
            }
        }
    }

    // no companion debug TAG
}
