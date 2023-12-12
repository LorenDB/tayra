import type { Module } from 'vuex'
import type { RootState } from '~/store/index'

import axios from 'axios'
import { merge } from 'lodash-es'
import useLogger from '~/composables/useLogger'
import { useQueue } from '~/composables/audio/queue'

export interface State {
  frontSettings: FrontendSettings
  instanceUrl?: string
  knownInstances: string[]
  nodeinfo: NodeInfo | null
  settings: Settings
}

type TotalCount = {
  total: number
}

export interface NodeInfo {
  version: string;
  software: {
    name: string;
    version: string;
  }
  protocols: any[];
  services?: {
    inbound?: string[];
    outbound?: string[];
  }
  openRegistrations: boolean;
  usage: {
    users: {
      total: number;
      activeHalfyear: number;
      activeMonth: number;
    }
  }
  metadata: {
    actorId: string
    'private': boolean
    shortDescription: string
    longDescription: string
    rules: string
    contactEmail: string
    terms: string
    nodeName: string
    banner: string
    defaultUploadQuota: number
    library: {
      federationEnabled: boolean
      anonymousCanListen: boolean
      tracks?: TotalCount
      artists?: TotalCount
      albums?: TotalCount
      music?: { hours: number }
    }
    supportedUploadExtensions: string[]
    allowList: {
      enabled: boolean
      domains: string[]
    }
    reportTypes: {
      'type': string
      label: string
      anonymous: boolean
    }[]
    funkwhaleSupportMessageEnabled: boolean
    instanceSupportMessage: string
    endpoints: {
      knownNodes?: string
      channels?: string
      libraries?: string
    }
    usage: {
      favorites: { tracks: TotalCount }
      listenings: TotalCount
      downloads: TotalCount
    }
  }
}

interface FrontendSettings {
  defaultServerUrl: string
  additionalStylesheets: string[]
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

interface UISettings {
  custom_css: { value: string }
}

interface Settings {
  instance: InstanceSettings
  users: UsersSettings
  moderation: ModerationSettings
  subsonic: SubsonicSettings
  ui: UISettings
}

const logger = useLogger()

// We have several way to guess the API server url. By order of precedence:
// 1. use the url provided in settings.json, if any
// 2. use the url specified when building via VUE_APP_INSTANCE_URL
// 3. use the current url
let DEFAULT_INSTANCE_URL = `${location.origin}/`
try {
  DEFAULT_INSTANCE_URL = new URL(import.meta.env.VUE_APP_INSTANCE_URL as string).href
} catch (e) {
  logger.warn('Invalid VUE_APP_INSTANCE_URL, falling back to current url', e)
}

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    frontSettings: {
      defaultServerUrl: DEFAULT_INSTANCE_URL,
      additionalStylesheets: []
    },
    instanceUrl: DEFAULT_INSTANCE_URL,
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
      },
      ui: {
        custom_css: {
          value: ''
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
      try {
        const { href } = new URL(value)
        state.instanceUrl = href
        axios.defaults.baseURL = `${href}api/v1/`

        // append the URL to the list (and remove existing one if needed)
        const index = state.knownInstances.indexOf(href)
        if (index > -1) state.knownInstances.splice(index, 1)
        state.knownInstances.unshift(href)
      } catch (e) {
        logger.error('Invalid instance URL', e)
        axios.defaults.baseURL = undefined
      }
    }
  },
  getters: {
    absoluteUrl: (_state, getters) => (relativeUrl: string) => {
      if (relativeUrl.startsWith('http')) return relativeUrl
      return relativeUrl.startsWith('/')
        ? `${getters.url.href}${relativeUrl.slice(1)}`
        : `${getters.url.href}${relativeUrl}`
    },
    url: (state) => new URL(state.instanceUrl ?? DEFAULT_INSTANCE_URL),
    domain: (_state, getters) => getters.url.hostname,
    defaultInstance: () => DEFAULT_INSTANCE_URL
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

      const { clear } = useQueue()
      return clear()
    },
    async fetchSettings ({ commit }) {
      const response = await axios.get('instance/settings/')
        .catch(err => logger.error('Error while fetching settings', err.response.data))

      if (!response?.data || !Array.isArray(response?.data)) return

      logger.info('Successfully fetched instance settings')

      type SettingsSection = { section: string, name: string }
      const sections = response.data.reduce((map: Record<string, Record<string, SettingsSection>>, entry: SettingsSection) => {
        map[entry.section] ??= {}
        map[entry.section][entry.name] = entry
        return map
      }, {})

      commit('settings', sections)
    },
    async fetchFrontSettings ({ state }) {
      const response = await axios.get(`${import.meta.env.BASE_URL}settings.json`)
        .catch(() => logger.error('Error when fetching front-end configuration (or no customization available)'))

      if (!response) return

      for (const [key, value] of Object.entries(response.data as FrontendSettings)) {
        if (key === 'defaultServerUrl' && !value) {
          state.frontSettings.defaultServerUrl = DEFAULT_INSTANCE_URL
          continue
        }

        state.frontSettings[key as keyof FrontendSettings] = value
      }
    }
  }
}

export default store
