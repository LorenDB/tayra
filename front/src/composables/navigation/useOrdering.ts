import type { RouteRecordName } from 'vue-router'

import { toRefs, useStorage, syncRef } from '@vueuse/core'
import { useRouteQuery } from '@vueuse/router'
import { useRoute } from 'vue-router'
import { watch, readonly } from 'vue'

export interface OrderingProps {
  orderingConfigName?: RouteRecordName
}

export default <T extends string = string>(props: OrderingProps) => {
  const route = useRoute()

  interface Preferences {
    orderingDirection: '-' | '+'
    ordering: T
    paginateBy: number
  }

  const preferences = useStorage<Preferences>(`route-preferences:${props.orderingConfigName?.toString() ?? route.name?.toString() ?? '*'}`, () => ({
    orderingDirection: route.meta.orderingDirection ?? '-',
    ordering: route.meta.ordering ?? 'creation_date',
    paginateBy: route.meta.paginateBy ?? 50
  }))

  const {
    orderingDirection: prefOrderingDirection,
    paginateBy: prefPaginateBy,
    ordering: prefOrdering
  } = toRefs(preferences, {
    replaceRef: false
  })

  const normalizeDirection = (direction: string) => direction === '+' ? '' : '-'

  const queryOrdering = useRouteQuery(
    'ordering',
    normalizeDirection(prefOrderingDirection.value) + prefOrdering.value,
    { transform: (value) => value.trim() }
  )

  const queryPaginateBy = useRouteQuery('paginateBy', prefPaginateBy.value, {
    transform: Number
  })

  // NOTE: Sync paginateBy in query string and preferences. We're using `flush: 'post'` to make sure that we sync after all updates are done
  syncRef(queryPaginateBy, prefPaginateBy, {
    flush: 'post'
  })

  // NOTE: Sync ordering from preferences to query string
  watch([prefOrderingDirection, prefOrdering], () => {
    queryOrdering.value = normalizeDirection(prefOrderingDirection.value) + prefOrdering.value.trim()
  })

  // NOTE: Sync ordering from query string to preferences
  watch(queryOrdering, (ordering) => {
    prefOrderingDirection.value = ordering[0] === '-' ? '-' : '+'
    prefOrdering.value = ordering.replace(/^[+-]/, '')
  }, { immediate: true })

  // NOTE: We're using `flush: 'post'` to make sure that the `onOrderingUpdate` callback is called after all updates are done
  const onOrderingUpdate = (fn: () => void) => watch(preferences, fn, {
    flush: 'post'
  })

  return {
    paginateBy: prefPaginateBy,
    ordering: prefOrdering,
    orderingDirection: prefOrderingDirection,
    orderingString: readonly(queryOrdering),
    onOrderingUpdate
  }
}
