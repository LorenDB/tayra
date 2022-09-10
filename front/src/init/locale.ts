import type { InitModule } from '~/types'

import { usePreferredLanguages } from '@vueuse/core'
import { nextTick, watch } from 'vue'
import { createI18n } from 'vue-i18n'

import locales from '~/locales.json'
import store from '~/store'

import useLogger from '~/composables/useLogger'

const logger = useLogger()

const defaultLanguage = store.state.ui.currentLanguage ?? 'en_US'
export const SUPPORTED_LOCALES = locales.reduce((map: Record<string, string>, locale) => {
  map[locale.code] = locale.label
  return map
}, {})

export const i18n = createI18n<false>({
  formatFallbackMessages: true,
  globalInjection: true,
  fallbackLocale: 'en',
  legacy: false,
  locale: 'en'
})

export const setI18nLanguage = async (locale: string) => {
  if (!Object.keys(SUPPORTED_LOCALES).includes(locale)) {
    throw new Error(`Unsupported locale: ${locale}`)
  }

  // load locale messages
  if (!i18n.global.availableLocales.includes(locale)) {
    try {
      const { default: messages } = await import(`./locales/${locale}.json`)
      i18n.global.setLocaleMessage(locale, messages)
      await nextTick()
    } catch (error) {
      logger.warn(`Unsupported locale: ${locale}`)
    }
  }

  // set locale
  i18n.global.locale.value = locale
  document.querySelector('html')?.setAttribute('lang', locale)
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

  // Handle language change
  watch(() => store.state.ui.currentLanguage, async (locale) => {
    await store.dispatch('ui/currentLanguage', locale)
    await setI18nLanguage(locale)
    // TODO (wvffle): Set moment locale
    // store.commit('ui/momentLocale', 'en')
  }, { immediate: true })
}
