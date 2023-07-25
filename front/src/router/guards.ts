import type { NavigationGuardNext, RouteLocationNamedRaw, RouteLocationNormalized } from 'vue-router'
import type { Permission } from '~/store/auth'

import useLogger from '~/composables/useLogger'
import store from '~/store'

const logger = useLogger()

export const hasPermissions = (permission: Permission) => (to: RouteLocationNormalized, from: RouteLocationNormalized, next: NavigationGuardNext) => {
  if (store.state.auth.authenticated && store.state.auth.availablePermissions[permission]) {
    return next()
  }

  logger.warn('Not authenticated. Redirecting to library.')
  next({ name: 'library.index' })
}

export const requireLoggedIn = (fallbackLocation?: RouteLocationNamedRaw) => (to: RouteLocationNormalized, from: RouteLocationNormalized, next: NavigationGuardNext) => {
  if (store.state.auth.authenticated) return next()
  logger.debug('!', to)
  return next(fallbackLocation ?? { name: 'login', query: { next: to.fullPath } })
}

export const requireLoggedOut = (fallbackLocation: RouteLocationNamedRaw) => (to: RouteLocationNormalized, from: RouteLocationNormalized, next: NavigationGuardNext) => {
  if (!store.state.auth.authenticated) return next()
  return next(fallbackLocation)
}
