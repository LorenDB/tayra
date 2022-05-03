import { createStore, Store, useStore as baseUseStore } from 'vuex'
import createPersistedState from 'vuex-persistedstate'

import favorites, { State as FavoritesState } from './favorites'
import channels, { State as ChannelsState } from './channels'
import libraries, { State as LibrariesState } from './libraries'
import auth, { State as AuthState } from './auth'
import instance, { State as InstanceState } from './instance'
import moderation, { State as ModerationState } from './moderation'
import queue, { State as QueueState } from './queue'
import radios, { State as RadiosState } from './radios'
import player, { State as PlayerState } from './player'
import playlists, { State as PlaylistsState } from './playlists'
import ui, { State as UiState } from './ui'
import { InjectionKey } from 'vue'

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

export const key: InjectionKey<Store<RootState>> = Symbol('vuex state injection key')
export default createStore<RootState>({
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
            tracks: state.queue.tracks.map((track: any) => {
              // we keep only valuable fields to make the cache lighter and avoid
              // cyclic value serialization errors
              const artist = {
                id: track.artist.id,
                mbid: track.artist.mbid,
                name: track.artist.name
              }
              const data = {
                id: track.id,
                title: track.title,
                mbid: track.mbid,
                uploads: track.uploads,
                listen_url: track.listen_url,
                artist: artist,
                album: {}
              }
              if (track.album) {
                data.album = {
                  id: track.album.id,
                  title: track.album.title,
                  mbid: track.album.mbid,
                  cover: track.album.cover,
                  artist: artist
                }
              }
              return data
            })
          }
        }
      }
    })
  ]
})

export const useStore = () => {
  return baseUseStore(key)
}
