import axios from 'axios'
import { merge } from 'lodash-es'
import useLogger from '~/composables/useLogger'
import { Module } from 'vuex'
import { RootState } from '~/store/index'

export interface State {
  frontSettings: FrontendSettings
  instanceUrl?: string
  knownInstances: string[]
  nodeinfo: unknown | null // TODO (wvffle): Get nodeinfo type from swagger automatically
  settings: Settings
}

interface FrontendSettings {
  defaultServerUrl: string
  additionalStylesheets: string[] // TODO (wvffle): Ensure it's not nullable
}

interface InstanceSettings {
  name: { value: string }
  short_description: { value: string }
  long_description: { value: string }
  funkwhale_support_message_enabled: { value: boolean }
  support_message: { value: string }
}

interface UsersSettings {
  registration_enabled: { value: boolean }
  upload_quota: { value: number }
}

interface ModerationSettings {
  signup_approval_enabled: { value: boolean }
  signup_form_customization: { value: null }
}

interface SubsonicSettings {
  enabled: { value: boolean }
}

interface Settings {
  instance: InstanceSettings
  users: UsersSettings
  moderation: ModerationSettings
  subsonic: SubsonicSettings
}

const logger = useLogger()

// We have several way to guess the API server url. By order of precedence:
// 1. use the url provided in settings.json, if any
// 2. use the url specified when building via VUE_APP_INSTANCE_URL
// 3. use the current url
const instanceUrl = import.meta.env.VUE_APP_INSTANCE_URL as string || location.origin

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    frontSettings: {
      defaultServerUrl: instanceUrl,
      additionalStylesheets: []
    },
    instanceUrl,
    knownInstances: [],
    nodeinfo: null,
    settings: {
      instance: {
        name: {
          value: ''
        },
        short_description: {
          value: ''
        },
        long_description: {
          value: ''
        },
        funkwhale_support_message_enabled: {
          value: true
        },
        support_message: {
          value: ''
        }
      },
      users: {
        registration_enabled: {
          value: true
        },
        upload_quota: {
          value: 0
        }
      },
      moderation: {
        signup_approval_enabled: {
          value: false
        },
        signup_form_customization: { value: null }
      },
      subsonic: {
        enabled: {
          value: true
        }
      }
    }
  },
  mutations: {
    settings: (state, value) => {
      merge(state.settings, value)
    },
    nodeinfo: (state, value) => {
      state.nodeinfo = value
    },
    instanceUrl: (state, value) => {
      if (value && !value.endsWith('/')) {
        value = value + '/'
      }

      state.instanceUrl = value

      // append the URL to the list (and remove existing one if needed)
      if (value) {
        const index = state.knownInstances.indexOf(value)
        if (index > -1) {
          state.knownInstances.splice(index, 1)
        }
        state.knownInstances.splice(0, 0, value)
      }

      if (!value) {
        axios.defaults.baseURL = undefined
        return
      }
      const suffix = 'api/v1/'
      axios.defaults.baseURL = state.instanceUrl + suffix
    }
  },
  getters: {
    absoluteUrl: (state) => (relativeUrl: string) => {
      if (relativeUrl.startsWith('http')) return relativeUrl
      if (state.instanceUrl?.endsWith('/') && relativeUrl.startsWith('/')) {
        relativeUrl = relativeUrl.slice(1)
      }

      const instanceUrl = state.instanceUrl ?? location.origin
      return instanceUrl + relativeUrl
    },
    domain: (state) => new URL(state.instanceUrl ?? location.origin).hostname
  },
  actions: {
    setUrl ({ commit }, url) {
      commit('instanceUrl', url)
      const modules = [
        'auth',
        'favorites',
        'moderation',
        'player',
        'playlists',
        'queue',
        'radios'
      ]
      modules.forEach(m => {
        commit(`${m}/reset`, null, { root: true })
      })
    },
    // Send a request to the login URL and save the returned JWT
    async fetchSettings ({ commit }, payload) {
      const response = await axios.get('instance/settings/')
        .catch(err => logger.error('Error while fetching settings', err.response.data))

      if (!response) return

      logger.info('Successfully fetched instance settings')

      type SettingsSection = { section: string, name: string }
      const sections = response.data.reduce((map: Record<string, Record<string, SettingsSection>>, entry: SettingsSection) => {
        map[entry.section] ??= {}
        map[entry.section][entry.name] = entry
        return map
      }, {})

      commit('settings', sections)
      payload?.callback?.()
    },
    async fetchFrontSettings ({ state }) {
      const response = await axios.get('/front/settings.json')
        .catch(() => logger.error('Error when fetching front-end configuration (or no customization available)'))

      if (!response) return

      for (const [key, value] of Object.entries(response.data as FrontendSettings)) {
        if (key === 'defaultServerUrl' && !value) continue
        state.frontSettings[key as keyof FrontendSettings] = value
      }
    }
  }
}

export default store
