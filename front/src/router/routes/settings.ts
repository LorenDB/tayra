import { RouteRecordRaw } from 'vue-router'

export default [
  {
    path: '/settings',
    name: 'settings',
    component: () => import('~/components/auth/Settings.vue')
  },
  {
    path: '/settings/applications/new',
    name: 'settings.applications.new',
    props: route => ({
      scopes: route.query.scopes,
      name: route.query.name,
      redirect_uris: route.query.redirect_uris
    }),
    component: () => import('~/components/auth/ApplicationNew.vue')
  },
  {
    path: '/settings/plugins',
    name: 'settings.plugins',
    component: () => import('~/views/auth/Plugins.vue')
  },
  {
    path: '/settings/applications/:id/edit',
    name: 'settings.applications.edit',
    component: () => import('~/components/auth/ApplicationEdit.vue'),
    props: true
  },
] as RouteRecordRaw[]