import type { InitModule } from '~/types'

import { setupDropdown } from '~/utils/fomantic'

export const install: InitModule = ({ app, store }) => {
  app.directive('title', function (el, binding) {
    store.commit('ui/pageTitle', binding.value)
  })

  app.directive('dropdown', setupDropdown)
}
