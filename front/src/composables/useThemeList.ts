import type { ThemeEntry } from '~/types'

import { i18n } from '~/init/locale'

const { t } = i18n.global

const themeList: ThemeEntry[] = [
  {
    icon: 'palette icon',
    name: t('composables.useThemeList.browserDefault'),
    key: 'auto'
  },
  {
    icon: 'sun icon',
    name: t('composables.useThemeList.lightTheme'),
    key: 'light'
  },
  {
    icon: 'moon icon',
    name: t('composables.useThemeList.darkTheme'),
    key: 'dark'
  }
]

export default () => themeList
