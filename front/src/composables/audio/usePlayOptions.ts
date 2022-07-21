import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import type { ContentFilter } from '~/store/moderation'

import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'
import axios from 'axios'
import usePlayer from '~/composables/audio/usePlayer'
import useQueue from '~/composables/audio/useQueue'
import { useCurrentElement } from '@vueuse/core'

export interface PlayOptionsProps {
  isPlayable?: boolean
  tracks?: Track[]
  track?: Track | null
  artist?: Artist | null
  album?: Album | null
  playlist?: Playlist | null
  library?: Library | null
  channel?: Channel | null
  account?: Actor | null
}

export default (props: PlayOptionsProps) => {
  // TODO (wvffle): Test if we can defineProps in composable

  const store = useStore()
  const { resume, pause, playing } = usePlayer()
  const { currentTrack } = useQueue()

  const playable = computed(() => {
    if (props.isPlayable) {
      return true
    }

    if (props.track) {
      return props.track.uploads?.length > 0
    } else if (props.artist) {
      return props.artist.tracks_count > 0 ||
        props.artist.albums.some((album) => album.is_playable === true)
    } else if (props.tracks) {
      return props.tracks.some((track) => (track.uploads?.length ?? 0) > 0)
    }

    return false
  })

  const filterableArtist = computed(() => props.track?.artist ?? props.album?.artist ?? props.artist)
  const filterArtist = () => store.dispatch('moderation/hide', { type: 'artist', target: filterableArtist.value })

  const { $npgettext } = useGettext()
  const addMessage = (tracks: Track[]) => {
    if (!tracks.length) {
      return
    }

    store.commit('ui/addMessage', {
      content: $npgettext('*/Queue/Message', '%{ count } track was added to your queue', '%{ count } tracks were added to your queue', tracks.length, {
        count: tracks.length.toString()
      }),
      date: new Date()
    })
  }

  const getTracksPage = async (params: object, page = 1, tracks: Track[] = []): Promise<Track[]> => {
    if (page > 11) {
      // it's 10 * 100 tracks already, let's stop here
      return tracks
    }

    // when fetching artists/or album tracks, sometimes, we may have to fetch
    // multiple pages
    const response = await axios.get('tracks/', {
      params: {
        ...params,
        page_size: 100,
        page,
        hidden: '',
        playable: true
      }
    })

    tracks.push(...response.data.results)
    if (response.data.next) {
      return getTracksPage(params, page + 1, tracks)
    }

    return tracks
  }

  const isLoading = ref(false)
  const getPlayableTracks = async () => {
    isLoading.value = true

    const tracks: Track[] = []

    // TODO (wvffle): There is no channel?
    if (props.tracks?.length) {
      tracks.push(...props.tracks)
    } else if (props.track) {
      if (props.track.uploads?.length) {
        tracks.push(props.track)
      } else {
        // fetch uploads from api
        const response = await axios.get(`tracks/${props.track.id}/`)
        tracks.push(response.data as Track)
      }
    } else if (props.playlist) {
      const response = await axios.get(`playlists/${props.playlist.id}/tracks/`)
      const playlistTracks = (response.data.results as Array<{ track: Track }>).map(({ track }) => track as Track)

      const artistIds = store.getters['moderation/artistFilters']().map((filter: ContentFilter) => filter.target.id)
      if (artistIds.length) {
        tracks.push(...playlistTracks.filter((track) => {
          return !((artistIds.includes(track.artist?.id) || track.album) && artistIds.includes(track.album?.artist.id))
        }))
      } else {
        tracks.push(...playlistTracks)
      }
    } else if (props.artist) {
      tracks.push(...await getTracksPage({ artist: props.artist.id, include_channels: 'true', ordering: 'album__release_date,disc_number,position' }))
    } else if (props.album) {
      tracks.push(...await getTracksPage({ album: props.album.id, include_channels: 'true', ordering: 'disc_number,position' }))
    } else if (props.library) {
      tracks.push(...await getTracksPage({ library: props.library.uuid, ordering: '-creation_date' }))
    }

    // TODO (wvffle): It was behind 250ms timeout, why?
    isLoading.value = false

    return tracks.filter(track => track.uploads?.length)
  }

  const el = useCurrentElement()
  const enqueue = async () => {
    jQuery(el.value).find('.ui.dropdown').dropdown('hide')

    const tracks = await getPlayableTracks()
    store.dispatch('queue/appendMany', { tracks }).then(() => addMessage(tracks))
  }

  const enqueueNext = async (next = false) => {
    jQuery(el.value).find('.ui.dropdown').dropdown('hide')

    const tracks = await getPlayableTracks()

    const wasEmpty = store.state.queue.tracks.length === 0
    await store.dispatch('queue/appendMany', { tracks, index: store.state.queue.currentIndex + 1 })

    if (next && !wasEmpty) {
      await store.dispatch('queue/next')
      resume()
    }

    addMessage(tracks)
  }

  const replacePlay = async () => {
    store.dispatch('queue/clean')

    jQuery(el.value).find('.ui.dropdown').dropdown('hide')

    const tracks = await getPlayableTracks()
    await store.dispatch('queue/appendMany', { tracks })

    if (props.track && props.tracks?.length) {
      // set queue position to selected track
      const trackIndex = props.tracks.findIndex(track => track.id === props.track?.id && track.position === props.track?.position)
      store.dispatch('queue/currentIndex', trackIndex)
    } else {
      store.dispatch('queue/currentIndex', 0)
    }

    resume()
    addMessage(tracks)
  }

  const activateTrack = (track: Track, index: number) => {
    // TODO (wvffle): Check if position checking did not break anything
    if (track.id === currentTrack.value?.id && track.position === currentTrack.value?.position) {
      if (playing.value) {
        return pause()
      }

      return resume()
    }

    replacePlay()
  }

  return {
    playable,
    filterableArtist,
    filterArtist,
    enqueue,
    enqueueNext,
    replacePlay,
    activateTrack,
    isLoading
  }
}
