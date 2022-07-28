import type { InitModule } from '~/types'

import { whenever } from '@vueuse/core'
import useQueue from '~/composables/audio/useQueue'
import useWebAudioPlayer from '~/composables/audio/useWebAudioPlayer'

export const install: InitModule = ({ app }) => {
  const { currentTrack } = useQueue()
  const { play, pause, seek, next, previous } = useWebAudioPlayer()

  // Add controls for notification drawer
  if ('mediaSession' in navigator) {
    navigator.mediaSession.setActionHandler('play', play)
    navigator.mediaSession.setActionHandler('pause', pause)
    navigator.mediaSession.setActionHandler('seekforward', () => seek(5))
    navigator.mediaSession.setActionHandler('seekbackward', () => seek(-5))
    navigator.mediaSession.setActionHandler('nexttrack', next)
    navigator.mediaSession.setActionHandler('previoustrack', previous)

    // TODO (wvffle): set metadata to null when we don't have currentTrack?
    // If the session is playing as a PWA, populate the notification
    // with details from the track
    whenever(currentTrack, () => {
      const { title, artist, album } = currentTrack.value

      const metadata: MediaMetadataInit = {
        title,
        // TODO (wvffle): translate
        artist: artist?.name ?? 'Unknown artist'
      }

      if (album?.cover) {
        metadata.album = album.title
        metadata.artwork = [
          { src: album.cover.urls.original, sizes: '96x96', type: 'image/png' },
          { src: album.cover.urls.original, sizes: '128x128', type: 'image/png' },
          { src: album.cover.urls.original, sizes: '192x192', type: 'image/png' },
          { src: album.cover.urls.original, sizes: '256x256', type: 'image/png' },
          { src: album.cover.urls.original, sizes: '384x384', type: 'image/png' },
          { src: album.cover.urls.original, sizes: '512x512', type: 'image/png' }
        ]
      }

      navigator.mediaSession.metadata = new window.MediaMetadata(metadata)
    }, { immediate: true })
  }
}
