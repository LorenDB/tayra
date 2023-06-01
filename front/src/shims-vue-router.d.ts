import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    orderingDirection?: '-' | '+'
    ordering?: OrderingField
    paginateBy?: number
  }
 }
