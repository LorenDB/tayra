import { RouteRecordRaw } from 'vue-router'

export default [
  { suffix: '.full', path: '/@:username@:domain' }, 
  { suffix: '', path: '/@:username' }
].map((route) => {
  return {
    path: route.path,
    name: `profile${route.suffix}`,
    component: () => import('~/views/auth/ProfileBase.vue'),
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