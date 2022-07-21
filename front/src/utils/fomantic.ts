/// <reference types="semantic-ui" />

import $ from 'jquery'
import { tryOnMounted, useCurrentElement } from '@vueuse/core'

export const getDropdown = (selector = '.ui.dropdown'): JQuery => {
  const el = useCurrentElement()
  return $(el.value).find(selector)
}

export const setupDropdown = (selector: string | HTMLElement = '.ui.dropdown') => tryOnMounted(() => {
  const el = useCurrentElement()
  const $dropdown = typeof selector === 'string'
    ? $(el.value).find(selector)
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
}, false)
