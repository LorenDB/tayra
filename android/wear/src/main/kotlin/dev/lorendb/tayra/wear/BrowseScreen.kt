package dev.lorendb.tayra.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.automirrored.filled.PlaylistPlay
import androidx.compose.material.icons.filled.Radio
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition

private val Background = Color(0xFF000000)
private val Surface = Color(0xFF1A1A1A)
private val OnSurface = Color.White
private val OnSurfaceMuted = Color(0xFFAAAAAA)
private val SectionHeader = Color(0xFF888888)
private val Primary = Color(0xFF0992F2)

@Composable
fun BrowseScreen(
    state: WearBrowseState,
    onStartPlaylist: (Int, String) -> Unit,
    onStartRadio: (Int, String) -> Unit,
    onRefresh: () -> Unit,
    onNavigateToPlayer: () -> Unit,
) {
    val listState = rememberScalingLazyListState()

    Scaffold(
        timeText = { TimeText() },
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        if (state.isLoading && state.playlists.isEmpty() && state.radios.isEmpty()) {
            // Full-screen loading
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Background),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(
                    indicatorColor = Primary,
                    modifier = Modifier.size(24.dp),
                )
            }
        } else {
            ScalingLazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .background(Background),
            ) {
                // Header
                item {
                    Text(
                        text = "Browse",
                        style = MaterialTheme.typography.title2,
                        color = OnSurface,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 4.dp),
                    )
                }

                // Now Playing shortcut
                item {
                    Chip(
                        onClick = onNavigateToPlayer,
                        label = {
                            Text(
                                text = "Now Playing",
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        icon = {
                            Icon(
                                imageVector = Icons.Default.MusicNote,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                        },
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Primary.copy(alpha = 0.2f),
                            contentColor = OnSurface,
                            iconColor = Primary,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                // ── Instance Radios ─────────────────────────────────────

                item {
                    Text(
                        text = "Quick Start",
                        style = MaterialTheme.typography.caption1,
                        color = SectionHeader,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp, bottom = 2.dp),
                        textAlign = TextAlign.Center,
                    )
                }

                items(state.instanceRadios.size) { index ->
                    val radio = state.instanceRadios[index]
                    BrowseChip(
                        label = radio.name,
                        secondaryLabel = radio.description,
                        icon = Icons.Default.Radio,
                        onClick = { onStartRadio(radio.id, radio.name) },
                    )
                }

                // ── Playlists ───────────────────────────────────────────

                if (state.playlists.isNotEmpty()) {
                    item {
                        Text(
                            text = "Playlists",
                            style = MaterialTheme.typography.caption1,
                            color = SectionHeader,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp, bottom = 2.dp),
                            textAlign = TextAlign.Center,
                        )
                    }

                    items(state.playlists.size) { index ->
                        val playlist = state.playlists[index]
                        BrowseChip(
                            label = playlist.name,
                            secondaryLabel = "${playlist.tracksCount} tracks",
                            icon = Icons.AutoMirrored.Filled.PlaylistPlay,
                            onClick = { onStartPlaylist(playlist.id, playlist.name) },
                        )
                    }
                }

                // ── User Radios ─────────────────────────────────────────

                if (state.radios.isNotEmpty()) {
                    item {
                        Text(
                            text = "Radios",
                            style = MaterialTheme.typography.caption1,
                            color = SectionHeader,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp, bottom = 2.dp),
                            textAlign = TextAlign.Center,
                        )
                    }

                    items(state.radios.size) { index ->
                        val radio = state.radios[index]
                        BrowseChip(
                            label = radio.name,
                            secondaryLabel = radio.description.ifEmpty { null },
                            icon = Icons.Default.Radio,
                            onClick = { onStartRadio(radio.id, radio.name) },
                        )
                    }
                }

                // Refresh button at the bottom
                item {
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        Button(
                            onClick = onRefresh,
                            modifier = Modifier.size(36.dp),
                            colors = ButtonDefaults.buttonColors(backgroundColor = Surface),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = "Refresh",
                                tint = OnSurface,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BrowseChip(
    label: String,
    secondaryLabel: String?,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
) {
    Chip(
        onClick = onClick,
        label = {
            Text(
                text = label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        },
        secondaryLabel = if (secondaryLabel != null) {
            {
                Text(
                    text = secondaryLabel,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        } else null,
        icon = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        },
        colors = ChipDefaults.chipColors(
            backgroundColor = Surface,
            contentColor = OnSurface,
            secondaryContentColor = OnSurfaceMuted,
            iconColor = Primary,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

// ── Play-action submenu ─────────────────────────────────────────────────────

/**
 * Submenu shown after the user taps a playlist or radio on the browse screen.
 * Presents two options: Play (in order) and Shuffle, then navigates to the player.
 *
 * @param label   The name of the playlist or radio being acted upon.
 * @param onPlay      Called when the user chooses "Play".
 * @param onShuffle   Called when the user chooses "Shuffle".
 */
@Composable
fun PlayActionScreen(
    label: String,
    onPlay: () -> Unit,
    onShuffle: (() -> Unit)? = null,
    showShuffle: Boolean = true,
) {
    val listState = rememberScalingLazyListState()

    Scaffold(
        timeText = { TimeText() },
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .background(Background),
        ) {
            // Title showing which item was selected
            item {
                Text(
                    text = label,
                    style = MaterialTheme.typography.title3,
                    color = OnSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 4.dp),
                )
            }

            // Play chip
            item {
                Chip(
                    onClick = onPlay,
                    label = {
                        Text(
                            text = "Play",
                            maxLines = 1,
                        )
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = Primary.copy(alpha = 0.2f),
                        contentColor = OnSurface,
                        iconColor = Primary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Shuffle chip (optional for radios)
            if (showShuffle && onShuffle != null) {
                item {
                    Chip(
                        onClick = onShuffle,
                        label = {
                            Text(
                                text = "Shuffle",
                                maxLines = 1,
                            )
                        },
                        icon = {
                            Icon(
                                imageVector = Icons.Default.Shuffle,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                        },
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Surface,
                            contentColor = OnSurface,
                            iconColor = Primary,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}
