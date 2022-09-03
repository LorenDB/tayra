import { useRouteQuery } from '@vueuse/router'
import { syncRef } from '@vueuse/core'
import { ref } from 'vue'

export default () => {
  const pageQuery = useRouteQuery<string>('page', '1')
  const page = ref()
  syncRef(pageQuery, page, {
    transform: {
      ltr: (left) => +left,
      rtl: (right) => right.toString()
    }
  })

  return page
}
