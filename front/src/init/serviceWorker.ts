import type { InitModule } from '~/types'

import { registerSW } from 'virtual:pwa-register'
import { i18n } from '~/init/locale'

import useLogger from '~/composables/useLogger'

const { t } = i18n.global
const logger = useLogger()

export const install: InitModule = ({ store }) => {
  const updateSW = registerSW({
    onRegisterError (error) {
      const importStatementsSupported = navigator.userAgent.includes('Chrome')
        || navigator.userAgent.includes('Chromium')
        || navigator.userAgent.includes('Opera')
        || navigator.userAgent.includes('Brave')

      if (import.meta.env.DEV && !importStatementsSupported) {
        logger.warn(
          'Service Worker is not supported in your browser in development mode.\n',
          'For more information, please refer to \'Support for ECMAScript modules\' section at:\n',
          'https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorker#browser_compatibility'
        )
      }

      logger.error('Service Worker install error:', error)
    },
    onOfflineReady () {
      logger.info('Funkwhale is being served from cache by a service worker.')
    },
    onRegistered () {
      logger.info('Service worker has been registered.')
    },
    onNeedRefresh () {
      store.commit('ui/addMessage', {
        content: t('init.serviceWorker.newAppVersion'),
        date: new Date(),
        key: 'refreshApp',
        displayTime: 0,
        classActions: 'bottom attached opaque',
        actions: [
          {
            text: t('init.serviceWorker.actions.update'),
            class: 'primary',
            click: () => updateSW()
          },
          {
            text: t('init.serviceWorker.actions.later'),
            class: 'basic'
          }
        ]
      })
    }
  })
}
