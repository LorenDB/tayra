import type { InitModule } from '~/types'

import { registerSW } from 'virtual:pwa-register'
import { i18n } from '~/init/locale'

import useLogger from '~/composables/useLogger'

const { t } = i18n.global
const logger = useLogger()

export const install: InitModule = ({ store }) => {
  const updateSW = registerSW({
    onRegisterError () {
      logger.error('SW install error')
    },
    onOfflineReady () {
      logger.info('Funkwhale is being served from cache by a service worker.')
    },
    onRegistered () {
      logger.info('Service worker has been registered.')
    },
    onNeedRefresh () {
      store.commit('ui/addMessage', {
        content: t('A new version of the app is available.'),
        date: new Date(),
        key: 'refreshApp',
        displayTime: 0,
        classActions: 'bottom attached opaque',
        actions: [
          {
            text: t('Update'),
            class: 'primary',
            click: () => updateSW()
          },
          {
            text: t('Later'),
            class: 'basic'
          }
        ]
      })
    }
  })
}
