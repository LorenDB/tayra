import { MaybeRef, reactiveComputed, toRefs } from '@vueuse/core'
import { computed, unref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useStore } from '~/store'
import { OrderingDirection, OrderingField, RouteWithPreferences } from '~/store/ui'

export interface OrderingProps {
  orderingConfigName: RouteWithPreferences | null
}

export default (orderingConfigName: MaybeRef<RouteWithPreferences | null>, defaultPaginateBy?: MaybeRef<number>) => {
  const store = useStore()
  const route = useRoute()

  const config = reactiveComputed(() => {
    const name = unref(orderingConfigName) ?? route.name as RouteWithPreferences
    return store.state.ui.routePreferences[name]
  })

  const { paginateBy, ordering, orderingDirection } = toRefs(config)
  if (defaultPaginateBy !== undefined) {
    paginateBy.value = unref(defaultPaginateBy)
  }

  const orderingString = computed(() => {
    if (orderingDirection.value === '-') return `-${ordering.value}`
    return ordering.value
  })

  const getOrderingFromString = (str: string) => ({
    direction: (str[0] === '-' ? '-' : '+') as OrderingDirection,
    field: (str[0] === '-' || str[0] === '+' ? str.slice(1) : str) as OrderingField
  })

  const onOrderingUpdate = (fn: () => void) => watch(config, fn)

  return {
    paginateBy,
    ordering,
    orderingDirection,
    orderingString,
    getOrderingFromString,
    onOrderingUpdate
  }
}
