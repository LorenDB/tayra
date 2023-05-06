import { config } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import en from '~/locales/en_US.json'

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: {
    en
  }
})

config.global.plugins ??= []
config.global.plugins.push(i18n)
