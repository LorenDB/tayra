import { AppModule } from '~/types'
import { registerSW } from 'virtual:pwa-register'
import logger from '~/logging'
import Vue from 'vue'

const { $pgettext } = Vue.prototype

export const install: AppModule = ({ store }) => {
  const updateSW = registerSW({
    onRegisterError () {
      logger.default.error('SW install error')
    },
    onOfflineReady () {
      logger.default.info('Funkwhale is being served from cache by a service worker.')
    },
    onRegistered () {
      logger.default.info('Service worker has been registered.')
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
