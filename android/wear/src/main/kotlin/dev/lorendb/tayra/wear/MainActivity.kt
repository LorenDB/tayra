package dev.lorendb.tayra.wear

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

class MainActivity : ComponentActivity() {

    private val viewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val playerState by viewModel.playerState.collectAsStateWithLifecycle()
            val browseState by viewModel.browseState.collectAsStateWithLifecycle()
            val navController = rememberSwipeDismissableNavController()

            // Browse is always the root screen. Tapping a playlist or radio navigates
            // to the play-action submenu. The player is reached after confirming
            // play or shuffle. Swipe-to-dismiss at each level returns to the previous.
            SwipeDismissableNavHost(
                navController = navController,
                startDestination = "browse",
            ) {
                composable("browse") {
                    BrowseScreen(
                        state = browseState,
                        onStartPlaylist = { id, label ->
                            navController.navigate(
                                "playAction/playlist/$id/${Uri.encode(label)}"
                            )
                        },
                        onStartRadio = { id, label ->
                            navController.navigate(
                                "playAction/radio/$id/${Uri.encode(label)}"
                            )
                        },
                        onRefresh = { viewModel.requestBrowseData() },
                        onNavigateToPlayer = { navController.navigate("player") },
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

    override fun onResume() {
        super.onResume()
        // Request a fresh state push from the phone whenever the watch app comes to foreground
        viewModel.requestState()
    }
}
