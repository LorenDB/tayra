import { AppModule } from '~/types'

import createAuthRefreshInterceptor from 'axios-auth-refresh'
import axios, { AxiosError } from 'axios'
import moment from 'moment'
import logger from '~/logging'
import { parseAPIErrors } from '~/utils'
import Vue from 'vue'

export const install: AppModule = ({ app, store, router }) => {
  axios.defaults.xsrfCookieName = 'csrftoken'
  axios.defaults.xsrfHeaderName = 'X-CSRFToken'
  axios.interceptors.request.use(function (config) {
    // Do something before request is sent
    if (store.state.auth.oauth.accessToken) {
      config.headers ??= {}
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
  }, async (error) => {
    error.backendErrors = []
    if (store.state.auth.authenticated && !store.state.auth.oauth.accessToken && error.response.status === 401) {
      store.commit('auth/authenticated', false)
      logger.default.warn('Received 401 response from API, redirecting to login form', router.currentRoute.fullPath)
      await router.push({ name: 'login', query: { next: router.currentRoute.fullPath } })
    }

    if (error.response.status === 404) {
      error.backendErrors.push('Resource not found')
      const message = error.response.data
      store.commit('ui/addMessage', {
        content: message,
        class: 'error'
      })
    } else if (error.response.status === 403) {
      error.backendErrors.push('Permission denied')
    } else if (error.response.status === 429) {
      let message
      const rateLimitStatus = {
        limit: error.response.headers['x-ratelimit-limit'],
        scope: error.response.headers['x-ratelimit-scope'],
        remaining: error.response.headers['x-ratelimit-remaining'],
        duration: error.response.headers['x-ratelimit-duration'],
        availableSeconds: error.response.headers['retry-after'],
        reset: error.response.headers['x-ratelimit-reset'],
        resetSeconds: error.response.headers['x-ratelimit-resetseconds']
      }
      if (rateLimitStatus.availableSeconds) {
        rateLimitStatus.availableSeconds = parseInt(rateLimitStatus.availableSeconds)
        const tryAgain = moment().add(rateLimitStatus.availableSeconds, 's').toNow(true)
        message = Vue.prototype.$pgettext('*/Error/Paragraph', 'You sent too many requests and have been rate limited, please try again in %{ delay }')
        message = Vue.prototype.$gettextInterpolate(message, { delay: tryAgain })
      } else {
        message = Vue.prototype.$pgettext('*/Error/Paragraph', 'You sent too many requests and have been rate limited, please try again later')
      }
      error.backendErrors.push(message)
      store.commit('ui/addMessage', {
        content: message,
        date: new Date(),
        class: 'error'
      })
      logger.default.error('This client is rate-limited!', rateLimitStatus)
    } else if (error.response.status === 500) {
      error.backendErrors.push('A server error occured')
    } else if (error.response.data) {
      if (error.response.data.detail) {
        error.backendErrors.push(error.response.data.detail)
      } else {
        error.rawPayload = error.response.data
        const parsedErrors = parseAPIErrors(error.response.data)
        error.backendErrors = [...error.backendErrors, ...parsedErrors]
      }
    }

    if (error.backendErrors.length === 0) {
      error.backendErrors.push('An unknown error occured, ensure your are connected to the internet and your funkwhale instance is up and running')
    }

    // Do something with response error
    return Promise.reject(error)
  })

  const refreshAuth = (failedRequest: AxiosError) => {
    if (store.state.auth.oauth.accessToken) {
      console.log('Failed request, refreshing auth…')
      // maybe the token was expired, let's try to refresh it
      return store.dispatch('auth/refreshOauthToken').then(() => {
        if (failedRequest.response) {
          failedRequest.response.config.headers ??= {}
          failedRequest.response.config.headers.Authorization = store.getters['auth/header']
        }

        return Promise.resolve()
      })
    }

    return Promise.resolve()
  }

  createAuthRefreshInterceptor(axios, refreshAuth)
}
