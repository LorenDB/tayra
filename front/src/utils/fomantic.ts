/// <reference types="semantic-ui" />

import $ from 'jquery'

export const setupDropdown = (selector: string | HTMLElement = '.ui.dropdown', el: Element = document.body) => {
  const $dropdown = typeof selector === 'string'
    ? $(el).find(selector)
    : $(selector)

  $dropdown.dropdown({
    selectOnKeydown: false,
    action (text: unknown, value: unknown, $el: JQuery) {
      // used to ensure focusing the dropdown and clicking via keyboard
      // works as expected
      $el[0]?.click()

      $dropdown.dropdown('hide')
    }
  })

  return $dropdown
}
