import type { ThemeEntry } from '~/types'
import { gettext } from '~/init/locale'

const { $pgettext } = gettext

const themeList: ThemeEntry[] = [
  {
    icon: 'palette icon',
    name: $pgettext('*/Settings/Dropdown.Label/Theme name', 'Browser default'),
    key: 'auto'
  },
  {
    icon: 'sun icon',
    name: $pgettext('*/Settings/Dropdown.Label/Theme name', 'Light'),
    key: 'light'
  },
  {
    icon: 'moon icon',
    name: $pgettext('*/Settings/Dropdown.Label/Theme name', 'Dark'),
    key: 'dark'
  }
]

export default () => themeList
