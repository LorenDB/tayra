import type { Track } from '~/types'
import type { InjectionKey } from 'vue'
import type { State as FavoritesState } from './favorites'
import type { State as ChannelsState } from './channels'
import type { State as LibrariesState } from './libraries'
import type { State as AuthState } from './auth'
import type { State as InstanceState } from './instance'
import type { State as ModerationState } from './moderation'
import type { State as QueueState } from './queue'
import type { State as RadiosState } from './radios'
import type { State as PlayerState } from './player'
import type { State as PlaylistsState } from './playlists'
import type { State as UiState } from './ui'

import { createStore, Store, useStore as baseUseStore } from 'vuex'
import createPersistedState from 'vuex-persistedstate'
import favorites from './favorites'
import channels from './channels'
import libraries from './libraries'
import auth from './auth'
import instance from './instance'
import moderation from './moderation'
import queue from './queue'
import radios from './radios'
import player from './player'
import playlists from './playlists'
import ui from './ui'

export interface RootState {
  ui: UiState
  auth: AuthState
  channels: ChannelsState
  libraries: LibrariesState
  favorites: FavoritesState
  instance: InstanceState
  moderation: ModerationState
  queue: QueueState
  radios: RadiosState
  playlists: PlaylistsState
  player: PlayerState
}

// we keep only valuable fields to make the cache lighter and avoid
// cyclic value serialization errors
const trackReducer = (track: Track) => {
  const artist = track.artist
    ? {
        id: track.artist.id,
        mbid: track.artist.mbid,
        name: track.artist.name
      }
    : {}

  return {
    id: track.id,
    title: track.title,
    mbid: track.mbid,
    uploads: track.uploads,
    listen_url: track.listen_url,
    artist,
    album: track.album
      ? {
          id: track.album.id,
          title: track.album.title,
          mbid: track.album.mbid,
          cover: track.album.cover,
          artist
        }
      : {}
  }
}

export const key: InjectionKey<Store<RootState>> = Symbol('vuex state injection key')
export default createStore<RootState>({
  // TODO (wvffle): Use strict mode
  modules: {
    ui,
    auth,
    channels,
    libraries,
    favorites,
    instance,
    moderation,
    queue,
    radios,
    playlists,
    player
  },
  plugins: [
    createPersistedState({
      key: 'auth',
      paths: ['auth'],
      filter: (mutation) => {
        return mutation.type.startsWith('auth/')
      }
    }),
    createPersistedState({
      key: 'instance',
      paths: ['instance.instanceUrl', 'instance.knownInstances']
    }),
    createPersistedState({
      key: 'ui',
      paths: ['ui.currentLanguage', 'ui.selectedLanguage', 'ui.momentLocale', 'ui.routePreferences']
    }),
    createPersistedState({
      key: 'radios',
      paths: ['radios'],
      filter: (mutation) => {
        return mutation.type.startsWith('radios/')
      }
    }),
    createPersistedState({
      key: 'player',
      paths: [
        'player.looping',
        'player.volume',
        'player.duration'],
      filter: (mutation) => {
        return mutation.type.startsWith('player/') && mutation.type !== 'player/currentTime'
      }
    }),
    createPersistedState({
      key: 'queue',
      filter: (mutation) => {
        return mutation.type.startsWith('queue/')
      },
      reducer: (state) => {
        return {
          queue: {
            currentIndex: state.queue.currentIndex,
            shuffleAbortController: state.queue.shuffleAbortController && null,
            tracks: state.queue.tracks.map(trackReducer),
            unshuffled: state.queue.unshuffled.map(trackReducer)
          }
        }
      },
      rehydrated: async (store) => {
        if (store.state.queue.shuffleAbortController === null) {
          await store.dispatch('queue/unshuffle', true)
        }
      }
    })
  ]
})

export const useStore = () => {
  return baseUseStore(key)
}
