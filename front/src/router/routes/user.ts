import type { RouteRecordRaw } from 'vue-router'

import store from '~/store'

export default [
  { suffix: '.full', path: '/@:username@:domain' },
  { suffix: '', path: '/@:username' }
].map((route) => {
  return {
    path: route.path,
    name: `profile${route.suffix}`,
    component: () => import('~/views/auth/ProfileBase.vue'),
    beforeEnter (to, from, next) {
      if (!store.state.auth.authenticated && to.query.domain && store.getters['instance/domain'] !== to.query.domain) {
        return next({ name: 'login', query: { next: to.fullPath } })
      }

      next()
    },
    props: true,
    children: [
      {
        path: '',
        name: `profile${route.suffix}.overview`,
        component: () => import('~/views/auth/ProfileOverview.vue')
      },
      {
        path: 'activity',
        name: `profile${route.suffix}.activity`,
        component: () => import('~/views/auth/ProfileActivity.vue')
      }
    ]
  }
}) as RouteRecordRaw[]
