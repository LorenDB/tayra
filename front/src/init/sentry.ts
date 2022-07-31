import type { InitModule } from '~/types'

import * as Sentry from '@sentry/vue'
import { BrowserTracing } from '@sentry/tracing'

export const install: InitModule = ({ app, router }) => {
  if (import.meta.env.VUE_SENTRY_DSN) {
    if (import.meta.env.DEV) {
      if (!document.cookie.split(';').map(cookie => cookie.split('=')[0].trim()).includes('sentry_dev')) {
        alert(`This instance uses ${new URL(import.meta.env.VUE_SENTRY_DSN).hostname} to collect information about crashes and stack traces.\n\nPlease unlock the domain in your adblock to allow us debug the branch.\n\nIf you do not want to share the data with us, please delete \`x-test-server\` cookie.`)

        const expires = new Date()
        expires.setTime(expires.getTime() + (100 * 24 * 60 * 60 * 1000))
        document.cookie = `sentry_dev=1;expires=${expires.toUTCString()}`
      }
    }

    Sentry.init({
      app,
      dsn: import.meta.env.VUE_SENTRY_DSN,
      logErrors: true,
      trackComponents: true,
      integrations: [
        new BrowserTracing({
          routingInstrumentation: Sentry.vueRouterInstrumentation(router)
        })
      ],
      // Set tracesSampleRate to 1.0 to capture 100%
      // of transactions for performance monitoring.
      // We recommend adjusting this value in production
      tracesSampleRate: 1.0
    })
  }
}
