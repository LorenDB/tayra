import axios from 'axios'
import useLogger from '~/composables/useLogger'
import { Module } from 'vuex'
import { RootState } from '~/store/index'
import useFormData from '~/composables/useFormData'

export type Permission = 'settings' | 'library' | 'moderation' | 'admin'
export interface State {
  authenticated: boolean
  username: string
  fullUsername: string
  availablePermissions: Record<Permission, boolean>,
  profile: null | Profile
  oauth: OAuthTokens
  scopedTokens: ScopedTokens
}

interface Profile {
  id: string
  avatar?: string
  username: string
  full_username: string
  instance_support_message_display_date: string
  funkwhale_support_message_display_date: string
}

interface ScopedTokens {
  listen: null | string
}

interface OAuthTokens {
  clientId: null | string
  clientSecret: null | string
  accessToken: null | string
  refreshToken: null | string
}

const NEEDED_SCOPES = 'read write'

const logger = useLogger()

function getDefaultScopedTokens (): ScopedTokens {
  return {
    listen: null
  }
}

function getDefaultOauth (): OAuthTokens {
  return {
    clientId: null,
    clientSecret: null,
    accessToken: null,
    refreshToken: null
  }
}

async function createOauthApp () {
  const payload = {
    name: `Funkwhale web client at ${window.location.hostname}`,
    website: location.origin,
    scopes: NEEDED_SCOPES,
    redirect_uris: `${location.origin}/auth/callback`
  }
  return (await axios.post('oauth/apps/', payload)).data
}

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    authenticated: false,
    username: '',
    fullUsername: '',
    availablePermissions: {
      settings: false,
      library: false,
      moderation: false,
      admin: false
    },
    profile: null,
    oauth: getDefaultOauth(),
    scopedTokens: getDefaultScopedTokens()
  },
  getters: {
    header: state => {
      if (state.oauth.accessToken) {
        return 'Bearer ' + state.oauth.accessToken
      }
    }
  },
  mutations: {
    reset (state) {
      state.authenticated = false
      state.profile = null
      state.username = ''
      state.fullUsername = ''
      state.scopedTokens = getDefaultScopedTokens()
      state.oauth = getDefaultOauth()
      state.availablePermissions = {
        settings: false,
        library: false,
        moderation: false,
        admin: false
      }
    },
    profile: (state, value) => {
      state.profile = value
    },
    authenticated: (state, value) => {
      state.authenticated = value
      if (value === false) {
        state.username = ''
        state.fullUsername = ''
        state.profile = null
        state.scopedTokens = getDefaultScopedTokens()
        state.availablePermissions = {
          settings: false,
          library: false,
          moderation: false,
          admin: false
        }
      }
    },
    username: (state, value) => {
      state.username = value
    },
    fullUsername: (state, value) => {
      state.fullUsername = value
    },
    avatar: (state, value) => {
      if (state.profile) {
        state.profile.avatar = value
      }
    },
    scopedTokens: (state, value) => {
      state.scopedTokens = { ...value }
    },
    permission: (state, { key, status }: { key: Permission, status: boolean }) => {
      state.availablePermissions[key] = status
    },
    profilePartialUpdate: (state, payload: Profile) => {
      if (!state.profile) {
        state.profile = {} as Profile
      }

      for (const [key, value] of Object.entries(payload)) {
        state.profile[key as keyof Profile] = value
      }
    },
    oauthApp: (state, payload) => {
      state.oauth.clientId = payload.client_id
      state.oauth.clientSecret = payload.client_secret
    },
    oauthToken: (state, payload) => {
      state.oauth.accessToken = payload.access_token
      state.oauth.refreshToken = payload.refresh_token
    }
  },
  actions: {
    // Send a request to the login URL and save the returned JWT
    login ({ dispatch }, { next, credentials, onError }) {
      const form = useFormData(credentials)
      return axios.post('users/login', form).then(() => {
        logger.info('Successfully logged in as', credentials.username)
        dispatch('fetchProfile').then(() => {
          // Redirect to a specified route
          import('~/router').then((router) => {
            return router.default.push(next)
          })
        })
      }, response => {
        logger.error('Error while logging in', response.data)
        onError(response)
      })
    },
    async logout ({ commit }) {
      try {
        await axios.post('users/logout')
      } catch (error) {
        console.log('Error while logging out, probably logged in via oauth')
      }
      const modules = [
        'auth',
        'favorites',
        'player',
        'playlists',
        'queue',
        'radios'
      ]
      modules.forEach(m => {
        commit(`${m}/reset`, null, { root: true })
      })
      logger.info('Log out, goodbye!')
    },
    fetchProfile ({ dispatch }) {
      return new Promise((resolve, reject) => {
        axios.get('users/me/').then((response) => {
          logger.info('Successfully fetched user profile')
          dispatch('updateProfile', response.data)
          dispatch('ui/fetchUnreadNotifications', null, { root: true })
          if (response.data.permissions.library) {
            dispatch('ui/fetchPendingReviewEdits', null, { root: true })
          }
          if (response.data.permissions.moderation) {
            dispatch('ui/fetchPendingReviewReports', null, { root: true })
            dispatch('ui/fetchPendingReviewRequests', null, { root: true })
          }
          dispatch('favorites/fetch', null, { root: true })
          dispatch('channels/fetchSubscriptions', null, { root: true })
          dispatch('libraries/fetchFollows', null, { root: true })
          dispatch('moderation/fetchContentFilters', null, { root: true })
          dispatch('playlists/fetchOwn', null, { root: true })
          resolve(response.data)
        }, () => {
          logger.info('Error while fetching user profile')
          reject(new Error('Error while fetching user profile'))
        })
      })
    },
    updateProfile ({ commit }, data) {
      commit('authenticated', true)
      commit('profile', data)
      commit('username', data.username)
      commit('fullUsername', data.full_username)
      if (data.tokens) {
        commit('scopedTokens', data.tokens)
      }

      for (const [permission, hasPermission] of Object.entries(data.permissions)) {
        // this makes it easier to check for permissions in templates
        commit('permission', { key: permission, status: hasPermission })
      }
    },
    async oauthLogin ({ state, rootState, commit }, next) {
      const app = await createOauthApp()
      commit('oauthApp', app)
      const redirectUri = encodeURIComponent(`${location.origin}/auth/callback`)
      const params = `response_type=code&scope=${encodeURIComponent(NEEDED_SCOPES)}&redirect_uri=${redirectUri}&state=${next}&client_id=${state.oauth.clientId}`
      const authorizeUrl = `${rootState.instance.instanceUrl}authorize?${params}`
      console.log('Redirecting user...', authorizeUrl)
      window.location.href = authorizeUrl
    },
    async handleOauthCallback ({ state, commit, dispatch }, authorizationCode) {
      console.log('Fetching token...')
      const payload = {
        client_id: state.oauth.clientId,
        client_secret: state.oauth.clientSecret,
        grant_type: 'authorization_code',
        code: authorizationCode,
        redirect_uri: `${location.origin}/auth/callback`
      }
      const response = await axios.post(
        'oauth/token/',
        useFormData(payload),
        { headers: { 'Content-Type': 'multipart/form-data' } }
      )
      commit('oauthToken', response.data)
      await dispatch('fetchProfile')
    },
    async refreshOauthToken ({ state, commit }) {
      const payload = {
        client_id: state.oauth.clientId,
        client_secret: state.oauth.clientSecret,
        grant_type: 'refresh_token',
        refresh_token: state.oauth.refreshToken
      }
      const response = await axios.post(
        'oauth/token/',
        useFormData(payload),
        { headers: { 'Content-Type': 'multipart/form-data' } }
      )
      commit('oauthToken', response.data)
    }
  }
}

export default store
