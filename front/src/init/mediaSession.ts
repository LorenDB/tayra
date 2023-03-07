import type { InitModule } from '~/types'

import { whenever } from '@vueuse/core'
import { useQueue } from '~/composables/audio/queue'
import { usePlayer } from '~/composables/audio/player'

export const install: InitModule = ({ app }) => {
  const { currentTrack, playNext, playPrevious } = useQueue()
  const { isPlaying, seekBy, pauseReason, PauseReason } = usePlayer()

  // Add controls for notification drawer
  if ('mediaSession' in navigator) {
    navigator.mediaSession.setActionHandler('play', () => (isPlaying.value = true))
    navigator.mediaSession.setActionHandler('pause', () => {
      isPlaying.value = false
      pauseReason.value = PauseReason.MediaSession
    })
    navigator.mediaSession.setActionHandler('seekforward', () => seekBy(5))
    navigator.mediaSession.setActionHandler('seekbackward', () => seekBy(-5))
    navigator.mediaSession.setActionHandler('nexttrack', () => playNext())
    navigator.mediaSession.setActionHandler('previoustrack', () => playPrevious())

    // If the session is playing as a PWA, populate the notification
    // with details from the track
    whenever(currentTrack, (track) => {
      if (!track) {
        navigator.mediaSession.metadata = null
        return
      }

      const { title, artistName, albumTitle, coverUrl, albumId } = track

      const metadata: MediaMetadataInit = {
        title,
        artist: artistName
      }

      if (albumId !== -1) {
        metadata.album = albumTitle
        metadata.artwork = [
          { src: coverUrl, sizes: '96x96', type: 'image/png' },
          { src: coverUrl, sizes: '128x128', type: 'image/png' },
          { src: coverUrl, sizes: '192x192', type: 'image/png' },
          { src: coverUrl, sizes: '256x256', type: 'image/png' },
          { src: coverUrl, sizes: '384x384', type: 'image/png' },
          { src: coverUrl, sizes: '512x512', type: 'image/png' }
        ]
      }

      navigator.mediaSession.metadata = new window.MediaMetadata(metadata)
    }, { immediate: true })
  }
}
