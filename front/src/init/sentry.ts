import type { InitModule } from '~/types'
import type { RootState } from '~/store'
import type { Router } from 'vue-router'
import type { Store } from 'vuex'
import { watchEffect, type App } from 'vue'
import useErrorHandler from '~/composables/useErrorHandler'

export const COOKIE = 'allow-tracing'

const initSentry = async (app: App, router: Router, store: Store<RootState>) => {
  const [{ default: useLogger }, { BrowserTracing }, Sentry] = await Promise.all([
    import('~/composables/useLogger'),
    import('@sentry/tracing'),
    import('@sentry/vue')
  ])

  const logger = useLogger()
  logger.info('Initializing Sentry')

  Sentry.init({
    app,
    dsn: import.meta.env.FUNKWHALE_SENTRY_DSN,
    logErrors: true,
    trackComponents: true,
    integrations: [
      new BrowserTracing({
        routingInstrumentation: Sentry.vueRouterInstrumentation(router)
      })
    ],
    debug: import.meta.env.DEV,
    environment: 'front',
    beforeSend: (event, hint) => {
      if (event.exception?.values?.some(exception => exception.mechanism?.handled === false) && hint.originalException instanceof Error) {
        useErrorHandler(hint.originalException, hint.event_id)
      }

      return event
    },
    tracesSampleRate: import.meta.env.FUNKWHALE_SENTRY_SR,
    ignoreErrors: [
      // vue3-lazyload throws an error whenever there is a 404
      'Image failed to load!'
    ]
  })

  Sentry.setTag('mode', import.meta.env.MODE)

  watchEffect(() => {
    const url = store.getters['instance/domain']
    Sentry.setTag('instance', url)
  })

  const setUser = (user: { username: string, [key: string]: any } | null) => {
    Sentry.setUser(user)
    Sentry.setContext('user', user)
  }

  watchEffect(() => {
    if (store.state.auth.authenticated) {
      return setUser({
        username: store.state.auth.username,
        canPublish: store.state.auth.availablePermissions.library,
        canModerate: store.state.auth.availablePermissions.moderation,
        isAdmin: store.state.auth.availablePermissions.settings
      })
    }

    setUser(null)
  })
}

export const install: InitModule = async ({ app, router, store }) => {
  if (import.meta.env.FUNKWHALE_SENTRY_DSN) {
    // @ts-expect-erro type unknown but it has all the required functions
    const [{ useCookies }, { i18n: { global: { t } } }] = await Promise.all([
      import('@vueuse/integrations/useCookies'),
      import('~/init/locale')
    ])

    const { get, set } = useCookies()

    const allowed = get(COOKIE)

    if (allowed === 'yes') {
      return initSentry(app, router, store)
    }

    if (allowed === undefined) {
      const { hostname, origin } = new URL(import.meta.env.FUNKWHALE_SENTRY_DSN)

      const message = t('init.sentry.message', [
        `<a href="${origin}">${hostname === 'am.funkwhale.audio' ? t('init.sentry.funkwhaleInstance') : hostname}</a>`
      ])

      const content = `${t('init.sentry.title')}<br><sub>${message}</sub>`

      return store.commit('ui/addMessage', {
        content,
        date: new Date(),
        key: 'allowSentryTracing',
        displayTime: 0,
        classActions: 'bottom attached opaque',
        actions: [
          {
            text: t('init.sentry.allow'),
            class: 'primary',
            click: () => {
              set(COOKIE, 'yes')
              return initSentry(app, router, store)
            }
          },
          {
            text: t('init.sentry.deny'),
            class: 'basic',
            click: () => set(COOKIE, 'no')
          }
        ]
      })
    }
  }
}
