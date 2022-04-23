import Vue from 'vue'
import GetText from 'vue-gettext'
import locales from '~/locales.json'
import { usePreferredLanguages } from '@vueuse/core'
import { watch } from '@vue/composition-api'
import { InitModule } from '~/types'

export const install: InitModule = ({ store, app }) => {
  const defaultLanguage = store.state.ui.currentLanguage ?? 'en_US'
  const availableLanguages = locales.reduce((map: { [key: string]: string }, locale) => {
    map[locale.code] = locale.label
    return map
  }, {})

  app.use(GetText, {
    availableLanguages,
    defaultLanguage,

    // cf https://github.com/Polyconseil/vue-gettext#configuration
    // not recommended but this is fixing weird bugs with translation nodes
    // not being updated when in v-if/v-else clauses
    autoAddKeyAttributes: true,
    languageVmMixin: {
      computed: {
        currentKebabCase (): string {
          // @ts-ignore
          return this.current.toLowerCase().replace('_', '-')
        }
      }
    },
    translations: {},
    silent: true
  })

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
      Vue.config.language = locale
      store.commit('ui/momentLocale', 'en')
    }
  }, { immediate: true })
}
