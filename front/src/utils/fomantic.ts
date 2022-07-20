/// <reference types="semantic-ui" />

import $ from 'jquery'
import { nextTick } from 'vue'
import { useCurrentElement } from '@vueuse/core'

const el = useCurrentElement()

export const getDropdown = (selector = '.ui.dropdown'): JQuery => {
  return $(el.value).find(selector)
}

export const setupDropdown = async (selector: string | HTMLElement = '.ui.dropdown') => {
  if (typeof selector === 'string') {
    await nextTick()
  }

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

  return $dropdown
}
