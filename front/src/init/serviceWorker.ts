import { InitModule } from '~/types'
import { registerSW } from 'virtual:pwa-register'
import useLogger from '~/composables/useLogger'
import Vue from 'vue'

const logger = useLogger()

const { $pgettext } = Vue.prototype

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
        content: $pgettext('App/Message/Paragraph', 'A new version of the app is available.'),
        date: new Date(),
        key: 'refreshApp',
        displayTime: 0,
        classActions: 'bottom attached opaque',
        actions: [
          {
            text: $pgettext('App/Message/Paragraph', 'Update'),
            class: 'primary',
            click: () => updateSW()
          },
          {
            text: $pgettext('App/Message/Paragraph', 'Later'),
            class: 'basic'
          }
        ]
      })
    }
  })
}
