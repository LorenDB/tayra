import { AppModule } from '~/types'
import jQuery from '~/jquery'

export const install: AppModule = ({ app, store }) => {
  app.directive('title', function (el, binding) {
    store.commit('ui/pageTitle', binding.value)
  })

  app.directive('dropdown', function (el, binding) {
    // @ts-ignore
    jQuery(el).dropdown({
      selectOnKeydown: false,
      action (text: string, value: string, $el: JQuery<HTMLElement>) {
        // used to ensure focusing the dropdown and clicking via keyboard
        // works as expected
        const button = $el[0]
        button.click()
        // @ts-ignore
        jQuery(el).find('.ui.dropdown').dropdown('hide')
      },
      ...(binding.value || {})
    })
  })
}
