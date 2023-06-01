import type { APIErrorResponse, BackendError, InitModule, RateLimitStatus } from '~/types'
import type { AxiosError } from 'axios'

import { parseAPIErrors } from '~/utils'
import { i18n } from './locale'

import createAuthRefreshInterceptor from 'axios-auth-refresh'
import moment from 'moment'
import axios from 'axios'

import useLogger from '~/composables/useLogger'

const { t } = i18n.global
const logger = useLogger()

export const install: InitModule = ({ store, router }) => {
  axios.defaults.xsrfCookieName = 'csrftoken'
  axios.defaults.xsrfHeaderName = 'X-CSRFToken'
  axios.interceptors.request.use(function (config) {
    // Do something before request is sent
    if (store.state.auth.oauth.accessToken) {
      config.headers.Authorization = store.getters['auth/header']
    }
    return config
  }, function (error) {
    // Do something with request error
    return Promise.reject(error)
  })

  // Add a response interceptor
  axios.interceptors.response.use(function (response) {
    return response
  }, async (error: BackendError) => {
    error.backendErrors = []
    error.isHandled = false

    if (store.state.auth.authenticated && !store.state.auth.oauth.accessToken && error.response?.status === 401) {
      store.commit('auth/authenticated', false)
      logger.warn('Received 401 response from API, redirecting to login form', router.currentRoute.value.fullPath)
      await router.push({ name: 'login', query: { next: router.currentRoute.value.fullPath } })
    }

    switch (error.response?.status) {
      case 404:
        if (error.response?.data === 'Radio doesn\'t have more candidates') {
          error.backendErrors.push(error.response.data)
          break
        }

        error.backendErrors.push('Resource not found')
        error.isHandled = true
        store.commit('ui/addMessage', {
          // @ts-expect-error TS does not know about .data structure
          content: error.response?.data?.detail ?? error.response?.data ?? 'Resource not found',
          class: 'error'
        })
        break

      case 403:
        error.backendErrors.push('Permission denied')
        break

      case 429: {
        let message
        const rateLimitStatus: RateLimitStatus = {
          limit: error.response?.headers['x-ratelimit-limit'],
          scope: error.response?.headers['x-ratelimit-scope'],
          remaining: error.response?.headers['x-ratelimit-remaining'],
          duration: error.response?.headers['x-ratelimit-duration'],
          availableSeconds: parseInt(error.response?.headers['retry-after'] ?? '60'),
          reset: error.response?.headers['x-ratelimit-reset'],
          resetSeconds: error.response?.headers['x-ratelimit-resetseconds']
        }

        if (rateLimitStatus.availableSeconds) {
          const tryAgain = moment().add(rateLimitStatus.availableSeconds, 's').toNow(true)
          message = t('init.axios.rateLimitDelay', { delay: tryAgain })
        } else {
          message = t('init.axios.rateLimitLater')
        }

        error.backendErrors.push(message)
        error.isHandled = true
        store.commit('ui/addMessage', {
          content: message,
          date: new Date(),
          class: 'error'
        })

        logger.error('This client is rate-limited!', rateLimitStatus)
        break
      }

      case 500:
        error.backendErrors.push('A server error occurred')
        break

      default:
        if (error.response?.data as object) {
          const data = error.response?.data as Record<string, unknown>
          if (data?.detail) {
            error.backendErrors.push(data.detail as string)
          } else {
            error.rawPayload = data as APIErrorResponse
            const parsedErrors = parseAPIErrors(data as APIErrorResponse)
            error.backendErrors = [...error.backendErrors, ...parsedErrors]
          }
        }
    }

    if (error.backendErrors.length === 0) {
      error.backendErrors.push('An unknown error occurred, ensure your are connected to the internet and your funkwhale instance is up and running')
    }

    // Do something with response error
    return Promise.reject(error)
  })

  const refreshAuth = async (failedRequest: AxiosError) => {
    if (store.state.auth.oauth.accessToken) {
      console.log('Failed request, refreshing auth…')

      try {
        // maybe the token was expired, let's try to refresh it
        await store.dispatch('auth/refreshOauthToken')
      } catch (error) {
        if ((error as BackendError).backendErrors.includes('invalid_grant')) {
          setTimeout(() => store.dispatch('auth/logout'), 0)
        }

        return Promise.reject(error)
      }

      if (failedRequest.response) {
        failedRequest.response.config.headers.Authorization = store.getters['auth/header']
      }

      return Promise.resolve()
    }

    return Promise.resolve()
  }

  createAuthRefreshInterceptor(axios, refreshAuth)
}
