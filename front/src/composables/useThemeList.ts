import type { ThemeEntry } from '~/types'

import { i18n } from '~/init/locale'

const { t } = i18n.global

const themeList: ThemeEntry[] = [
  {
    icon: 'palette icon',
    name: t('Browser default'),
    key: 'auto'
  },
  {
    icon: 'sun icon',
    name: t('Light'),
    key: 'light'
  },
  {
    icon: 'moon icon',
    name: t('Dark'),
    key: 'dark'
  }
]

export default () => themeList
