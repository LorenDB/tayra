import { watch } from 'vue'
import { locales } from '~/locales'
import { usePreferredLanguages } from '@vueuse/core'
import { createGettext } from 'vue3-gettext'
import { InitModule } from '~/types'
import store from '~/store'

const defaultLanguage = store.state.ui.currentLanguage ?? 'en_US'
const availableLanguages = locales.reduce((map: { [key: string]: string }, locale) => {
  map[locale.code] = locale.label
  return map
}, {})

export const gettext = createGettext({
  availableLanguages,
  defaultLanguage,
  silent: true
})

export const install: InitModule = ({ store, app }) => {
  app.use(gettext)

  // Set default language
  if (!store.state.ui.selectedLanguage) {
    // NOTE: We're selecting the language only once, hence we don't need to make it reactive
    const languages = usePreferredLanguages().value.map((code) => {
      return code.replace(/-/g, '_')
    })

    let language = Object.keys(availableLanguages).find(code => {
      return languages.includes(code)
    })

    if (!language) {
      language = Object.keys(availableLanguages).find(code => {
        return languages.map(lang => lang.split('_')[0]).includes(code.split('_')[0])
      })
    }

    store.commit('ui/currentLanguage', language ?? defaultLanguage)
  }

  // Handle language change
  watch(() => store.state.ui.currentLanguage, (locale) => {
    const htmlLocale = locale.toLowerCase().replace('_', '-')
    document.documentElement.setAttribute('lang', htmlLocale)

    if (locale === 'en_US') {
      gettext.current = locale
      store.commit('ui/momentLocale', 'en')
    }
  }, { immediate: true })
}
