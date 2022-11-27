import type { VueI18nOptions } from 'vue-i18n'

export type SupportedLanguages = 'ar' | 'ca' | 'cs' | 'de' | 'en_GB' | 'en_US' | 'eo' | 'es' | 'eu' | 'fr_FR'
  | 'gl' | 'hu' | 'it' | 'ja_JP' | 'kab_DZ' | 'ko_KR' | 'nb_NO' | 'nl' | 'oc' | 'pl' | 'pt_BR' | 'pt_PT'
  | 'ru' | 'sq' | 'zh_Hans' | 'zh_Hant' | 'fa_IR' | 'ml' | 'sv' | 'el' | 'nn_NO'

export interface Locale {
  label: string
  pluralizationRule?: Exclude<VueI18nOptions['pluralizationRules'], undefined>[string]
}

export const locales: Record<SupportedLanguages, Locale> = {
  ar: {
    label: 'العربية'
  },
  ca: {
    label: 'Català'
  },
  cs: {
    label: 'Čeština'
  },
  de: {
    label: 'Deutsch'
  },
  en_GB: {
    label: 'English (UK)'
  },
  en_US: {
    label: 'English (United-States)'
  },
  eo: {
    label: 'Esperanto'
  },
  es: {
    label: 'Español'
  },
  eu: {
    label: 'Euskara'
  },
  fr_FR: {
    label: 'Français'
  },
  gl: {
    label: 'Galego'
  },
  hu: {
    label: 'Magyar'
  },
  it: {
    label: 'Italiano'
  },
  ja_JP: {
    label: '日本語'
  },
  kab_DZ: {
    label: 'Taqbaylit'
  },
  ko_KR: {
    label: '한국어'
  },
  nb_NO: {
    label: 'Bokmål'
  },
  nn_NO: {
    label: 'Nynorsk'
  },
  nl: {
    label: 'Nederlands'
  },
  oc: {
    label: 'Occitan'
  },
  pl: {
    label: 'Polski',
    pluralizationRule: (n, choices) => {
      // 0 rowerow | 1 rower | 2-4 rowery | 5-21 rowerow
      // 1 rower | 2-4 rowery | 5-21 rowerow

      const isFew = (n % 10 >= 2 && n % 10 <= 4) && (n % 100 < 10 || n % 100 >= 20)

      if (choices === 3) {
        if (n === 0) return 2
        if (n === 1) return 0
        return isFew ? 1 : 2
      }

      if (n === 0 || n === 1) return n
      return isFew ? 2 : 3
    }
  },
  pt_BR: {
    label: 'Português (Brasil)'
  },
  pt_PT: {
    label: 'Português (Portugal)'
  },
  ru: {
    label: 'Русский'
  },
  sq: {
    label: 'Shqip'
  },
  zh_Hans: {
    label: '中文(简体)'
  },
  zh_Hant: {
    label: '中文(繁體)'
  },
  fa_IR: {
    label: 'فارسی'
  },
  ml: {
    label: 'മലയാളം'
  },
  sv: {
    label: 'Svenska'
  },
  el: {
    label: 'Ελληνικά'
  }
}
