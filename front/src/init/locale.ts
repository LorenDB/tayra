import type { InitModule } from '~/types'
import type { SupportedLanguages } from '~/locales'

import { usePreferredLanguages } from '@vueuse/core'
import { createI18n } from 'vue-i18n'
import { nextTick } from 'vue'

import { locales } from '~/locales'
import store from '~/store'

import useLogger from '~/composables/useLogger'

import en from '../locales/en_US.json'

const localeFactory = import.meta.glob('../locales/*.json') as Record<string, () => Promise<{ default: typeof en }>>

const logger = useLogger()

const defaultLanguage = store.state.ui.currentLanguage ?? 'en'

export const SUPPORTED_LOCALES = Object.fromEntries(
  Object.entries(locales)
    .map(([key, value]) => [key, value.label])
) as Record<SupportedLanguages, string>

export const i18n = createI18n<false>({
  formatFallbackMessages: true,
  globalInjection: true,
  fallbackLocale: 'en_US',
  legacy: false,
  locale: 'en_US',
  messages: { en_US: en },
  pluralizationRules: Object.fromEntries(
    Object.entries(locales)
      .map(([key, value]) => [key, value.pluralizationRule])
      .filter(i => i[1])
  )
})

export const setI18nLanguage = async (locale: string) => {
  if (!(locale in locales)) {
    throw new Error(`Unsupported locale: ${locale}`)
  }

  // load locale messages
  if (!i18n.global.availableLocales.includes(locale)) {
    try {
      const { default: messages } = await localeFactory[`../locales/${locale}.json`]()
      i18n.global.setLocaleMessage(locale, messages)
      await nextTick()
    } catch (error) {
      logger.warn(`Unsupported locale: ${locale}`)
      logger.debug(error)
    }
  }

  // set locale
  i18n.global.locale.value = locale
  document.querySelector('html')?.setAttribute('lang', locale)
  await store.dispatch('ui/currentLanguage', locale)
  store.commit('ui/momentLocale', locale.replace(/_/g, '-'))
}

export const install: InitModule = async ({ store, app }) => {
  app.use(i18n)

  // Set default language
  if (!store.state.ui.selectedLanguage) {
    // NOTE: We're selecting the language only once, hence we don't need to make it reactive
    const languages = usePreferredLanguages().value.map((code) => {
      return code.replace(/-/g, '_')
    })

    let language = Object.keys(SUPPORTED_LOCALES).find(code => {
      return languages.includes(code)
    })

    if (!language) {
      language = Object.keys(SUPPORTED_LOCALES).find(code => {
        return languages.map(lang => lang.split('_')[0]).includes(code.split('_')[0])
      })
    }

    await store.dispatch('ui/currentLanguage', language ?? defaultLanguage)
    await setI18nLanguage(language ?? defaultLanguage)
  }

  setI18nLanguage(store.state.ui.currentLanguage)
}
