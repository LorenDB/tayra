import type { State as ModerationState } from './moderation'
import type { State as PlaylistsState } from './playlists'
import type { State as FavoritesState } from './favorites'
import type { State as LibrariesState } from './libraries'
import type { State as ChannelsState } from './channels'
import type { State as InstanceState } from './instance'
import type { State as RadiosState } from './radios'
import type { State as AuthState } from './auth'
import type { State as UiState } from './ui'
import type { InjectionKey } from 'vue'

import { createStore, Store, useStore as baseUseStore } from 'vuex'

import createPersistedState from 'vuex-persistedstate'
import moderation from './moderation'
import playlists from './playlists'
import favorites from './favorites'
import libraries from './libraries'
import channels from './channels'
import instance from './instance'
import radios from './radios'
import auth from './auth'
import ui from './ui'

export interface RootState {
  moderation: ModerationState
  playlists: PlaylistsState
  favorites: FavoritesState
  libraries: LibrariesState
  channels: ChannelsState
  instance: InstanceState
  radios: RadiosState
  auth: AuthState
  ui: UiState
}

export const key: InjectionKey<Store<RootState>> = Symbol('vuex state injection key')
export default createStore<RootState>({
  modules: {
    moderation,
    playlists,
    favorites,
    libraries,
    channels,
    instance,
    radios,
    auth,
    ui
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
      paths: [
        'radios.current',
        'radios.running'
      ],
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
    })
  ]
})

export const useStore = () => {
  return baseUseStore(key)
}
