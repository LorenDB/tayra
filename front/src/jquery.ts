import jQuery from 'jquery'

// NOTE: Workaround for fomantic-ui-css
if (import.meta.env.DEV) {
  window.$ = window.jQuery = jQuery
}

export default jQuery
