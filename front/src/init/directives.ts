import { InitModule } from '~/types'
import jQuery from '~/jquery'

export const install: InitModule = ({ app, store }) => {
  app.directive('title', function (el, binding) {
    store.commit('ui/pageTitle', binding.value)
  })

  app.directive('dropdown', function (el, binding) {
    // @ts-expect-error
    jQuery(el).dropdown({
      selectOnKeydown: false,
      action (text: string, value: string, $el: JQuery<HTMLElement>) {
        // used to ensure focusing the dropdown and clicking via keyboard
        // works as expected
        $el[0]?.click()
        // @ts-expect-error
        jQuery(el).find('.ui.dropdown').dropdown('hide')
      },
      ...(binding.value || {})
    })
  })
}
