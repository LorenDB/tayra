import type { RouteRecordName } from 'vue-router'

import { toRefs, useStorage, syncRef } from '@vueuse/core'
import { useRouteQuery } from '@vueuse/router'
import { useRoute } from 'vue-router'
import { ref, watch } from 'vue'

export interface OrderingProps {
  orderingConfigName?: RouteRecordName
}

export default (props: OrderingProps) => {
  const route = useRoute()

  const preferences = useStorage(`route-preferences:${props.orderingConfigName?.toString() ?? route.name?.toString() ?? '*'}`, {
    orderingDirection: route.meta.orderingDirection ?? '-',
    ordering: route.meta.ordering ?? 'creation_date',
    paginateBy: route.meta.paginateBy ?? 50
  })

  const {
    orderingDirection: perfOrderingDirection,
    paginateBy: perfPaginateBy,
    ordering: perfOrdering
  } = toRefs(preferences)

  const queryPaginateBy = useRouteQuery<string>('paginateBy', perfPaginateBy.value.toString())
  const paginateBy = ref()
  syncRef(queryPaginateBy, paginateBy, {
    transform: {
      ltr: (left) => +left,
      rtl: (right) => right.toString()
    }
  })

  const queryOrdering = useRouteQuery('ordering', perfOrderingDirection.value + perfOrdering.value)
  console.log(queryOrdering.value)

  watch(queryOrdering, (ordering) => {
    perfOrderingDirection.value = ordering[0] === '-' ? '-' : '+'
    perfOrdering.value = ordering[0] === '-' || ordering[0] === '+'
      ? ordering.slice(1)
      : ordering
  })

  watch(perfOrderingDirection, (direction) => {
    if (direction === '-') {
      queryOrdering.value = direction + perfOrdering.value
      return
    }

    queryOrdering.value = perfOrdering.value
  })

  watch(perfOrdering, (field) => {
    const direction = perfOrderingDirection.value
    queryOrdering.value = (direction === '-' ? '-' : '') + field
  })

  watch(queryPaginateBy, (paginateBy) => {
    perfPaginateBy.value = +paginateBy
  })

  const onOrderingUpdate = (fn: () => void) => watch(preferences, fn)

  return {
    paginateBy,
    ordering: perfOrdering,
    orderingDirection: perfOrderingDirection,
    orderingString: queryOrdering,
    onOrderingUpdate
  }
}
